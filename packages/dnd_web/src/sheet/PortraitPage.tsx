import { useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ArrowLeft, Check, History, Trash2, Upload } from 'lucide-react';
import { ApiError } from '../api/client';
import { deletePortrait, fetchPortraitProviders, uploadPortrait } from '../api/portraits';
import { useTexts } from '../i18n/context';
import { nameOf } from '../api/catalog';
import { characterHref, Link } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { Medallion } from '../ui/Medallion';
import { portraitUrl, thumbnailUrl } from '../ui/portrait';
import { AppBusyLabel, AppErrorView } from '../ui/status';
import { Button } from '../ui/Button';
import { SpellTabs } from '../ui/wizard';
import { accentFor, classesOf, type SheetModel } from './model';
import type { SheetWriter } from './writer';

/** El retrato que el servidor acepta al subir: lo mismo que el `accept` de
 *  Flutter. El servidor valida el contenido de verdad (`sniffPortraitImageType`);
 *  esto solo filtra el selector. */
const IMPORT_ACCEPT = '.png,.jpg,.jpeg,.webp,.gif';

/** Una de las cuatro escuadras doradas del retrato. */
function Corner({ at }: { at: 'tl' | 'tr' | 'bl' | 'br' }) {
  const position = {
    tl: 'top-[9px] left-[9px] border-t-2 border-l-2',
    tr: 'top-[9px] right-[9px] border-t-2 border-r-2',
    bl: 'bottom-[9px] left-[9px] border-b-2 border-l-2',
    br: 'right-[9px] bottom-[9px] border-r-2 border-b-2',
  }[at];
  return <i aria-hidden="true" className={cx('absolute h-[18px] w-[18px] border-gold', position)} />;
}

/**
 * Una tira horizontal de miniaturas de 57×76. Tocar una **solo la mira**: no
 * guarda ni cambia nada (el retrato del personaje se compromete con «Usar» o
 * «Volver»). Una imagen que no carga deja la celda vacía —la clave puede ser
 * de un retrato borrado— en vez de un ícono roto.
 */
function ThumbStrip({
  label,
  items,
  onSelect,
}: {
  label: string;
  items: { id: string; src: string; label: string; selected: boolean; current?: boolean }[];
  onSelect: (id: string) => void;
}) {
  const [failed, setFailed] = useState<ReadonlySet<string>>(new Set());
  return (
    <ul aria-label={label} className="m-0 flex list-none gap-2 overflow-x-auto p-0 pb-1">
      {items.map((item) => (
        <li key={item.id} className="shrink-0">
          <button
            type="button"
            aria-label={item.label}
            aria-pressed={item.selected}
            data-thumb={item.id}
            onClick={() => onSelect(item.id)}
            className={cx(
              'relative block h-[76px] w-[57px] cursor-pointer overflow-hidden rounded-[8px] bg-plaque p-0',
              item.selected ? 'border-2 border-gold' : 'border border-hairline',
            )}
          >
            {!failed.has(item.src) && (
              <img
                src={thumbnailUrl(item.src, 57)}
                alt=""
                onError={() => setFailed((prev) => new Set(prev).add(item.src))}
                className="h-full w-full object-cover"
              />
            )}
            {item.current && (
              <span
                aria-hidden="true"
                className="absolute top-[3px] right-[3px] flex h-[15px] w-[15px] items-center justify-center rounded-full bg-gold text-on-primary"
              >
                <Check size={10} strokeWidth={3} />
              </span>
            )}
          </button>
        </li>
      ))}
    </ul>
  );
}

/**
 * Los retratos de la ficha propia (`PortraitScreen` de Flutter): subir un
 * archivo, volver a un retrato guardado y borrarlo. Cada acción **deja la
 * pantalla abierta** y avisa: Flutter cerraba sola al terminar, y acá nada
 * avanza solo (ver las reglas de `diseno-web-react.md`). Lo que se escribe en
 * la ficha pasa por el motor (`addPortrait`, `restorePortrait`,
 * `removePortrait`); este archivo no decide nada del orden.
 */
export function PortraitPage({ model, write }: { model: SheetModel; write: SheetWriter }) {
  const t = useTexts();
  const { character, catalog } = model;
  const paths = character.portraitPaths ?? [];
  const prompts = character.portraitPrompts ?? {};

  const providers = useQuery({
    queryKey: ['portrait-providers'],
    queryFn: ({ signal }) => fetchPortraitProviders(signal),
  });
  const noProviders = providers.isSuccess && providers.data.length === 0;

  // Qué vía está abierta. Sin proveedores no hay nada que generar: la única
  // vía es el archivo, así que se abre ahí en vez de mostrar una pestaña vacía.
  const [mode, setMode] = useState<'ai' | 'upload'>('ai');
  const shownMode = noProviders ? 'upload' : mode;

  // El retrato guardado que se está mirando; `null` es el actual.
  const [viewKey, setViewKey] = useState<string | null>(null);
  const [heroFailed, setHeroFailed] = useState<string | null>(null);
  const [importing, setImporting] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const busy = importing || deleting;

  const shownKey = viewKey ?? paths[0] ?? null;
  const heroSrc = shownKey ? portraitUrl(shownKey) : null;
  const shownPrompt = shownKey ? prompts[shownKey] : undefined;

  const classes = classesOf(model);
  const caption = [
    nameOf(catalog.races, character.raceId),
    classes.map((c) => t.classLevel(c.name, c.level)).join(' / '),
    classes.flatMap((c) => (c.subclass ? [c.subclass] : [])).join(' / '),
  ]
    .filter(Boolean)
    .join(' · ');

  const onFile = async (file: File | undefined) => {
    if (fileInput.current) fileInput.current.value = '';
    if (!file) return;
    setImporting(true);
    setError(null);
    try {
      const key = await uploadPortrait(character.id, file);
      write.act({ type: 'addPortrait', key });
      setViewKey(null);
      write.notify(t.portraitSaved, { tone: 'success' });
    } catch (e) {
      // El servidor rechaza con 400 (tipo) o 413 (tamaño) sin decir cuál.
      setError(e instanceof ApiError && (e.status === 400 || e.status === 413) ? t.diaryUploadRejected : t.portraitImportError);
    } finally {
      setImporting(false);
    }
  };

  // Vuelve a un retrato ya guardado: no sube nada, solo pasa adelante.
  const restore = (key: string) => {
    write.act({ type: 'restorePortrait', key });
    setViewKey(null);
    write.notify(t.portraitRestored, { tone: 'success' });
  };

  // Primero el almacén y después la ficha: si el borrado falla no se toca
  // nada, y si fallara el guardado de la ficha lo que queda es una clave que
  // no resuelve, que ya se dibuja vacía en todos lados. Al revés quedaría un
  // archivo huérfano ocupando el disco, que es justo lo que se vino a evitar.
  const remove = async (key: string) => {
    setDeleting(true);
    setError(null);
    try {
      await deletePortrait(key);
    } catch {
      setError(t.portraitDeleteError);
      setDeleting(false);
      return;
    }
    write.act({ type: 'removePortrait', key });
    setViewKey(null);
    setDeleting(false);
    write.notify(t.portraitDeleted, { tone: 'success' });
  };

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="portrait">
      <header className="flex flex-col gap-1">
        <Link
          href={characterHref(character.id)}
          className="inline-flex min-h-9 items-center gap-1.5 self-start text-[13px] text-gold no-underline hover:text-on-surface"
        >
          <ArrowLeft size={16} aria-hidden="true" />
          {t.chBack}
        </Link>
        <h1 className="font-display text-[28px] leading-[1.1] text-on-surface">{t.actionPortrait}</h1>
      </header>

      <div className="grid items-start gap-6 lg:grid-cols-[320px_minmax(0,1fr)]">
        <div className="flex min-w-0 flex-col gap-3">
          <figure className="m-0 flex flex-col gap-2">
            <div className="relative flex aspect-[3/4] items-center justify-center overflow-hidden rounded-[var(--radius-card)] border border-hairline bg-plaque">
              {heroSrc && heroFailed !== heroSrc ? (
                <img
                  src={heroSrc}
                  alt={t.portraitOf(character.name)}
                  data-portrait
                  onError={() => setHeroFailed(heroSrc)}
                  className="h-full w-full object-cover"
                />
              ) : (
                <Medallion name={character.name} accent={accentFor(model)} size={120} />
              )}
              <Corner at="tl" />
              <Corner at="tr" />
              <Corner at="bl" />
              <Corner at="br" />
            </div>
            <figcaption className="flex flex-col gap-0.5">
              <b className="font-display text-[18px] font-normal text-on-surface">{character.name}</b>
              <span className="text-[13px] text-on-surface-variant">{caption}</span>
            </figcaption>
          </figure>

          {paths.length > 0 && (
            <>
              <Eyebrow>{t.portraitSavedTitle}</Eyebrow>
              <ThumbStrip
                label={t.portraitSavedTitle}
                items={paths.map((key, i) => ({
                  id: key,
                  src: portraitUrl(key),
                  label: i === 0 ? t.portraitCurrent : t.portraitPrevious(i),
                  selected: key === shownKey,
                  current: i === 0,
                }))}
                onSelect={(key) => setViewKey(key === paths[0] ? null : key)}
              />
            </>
          )}

          {shownKey && (
            <>
              {viewKey && (
                <Button
                  icon={History}
                  data-action="restore-portrait"
                  disabled={busy}
                  onClick={() => restore(viewKey)}
                  className="min-h-11 w-full"
                >
                  {t.portraitBackToThis}
                </Button>
              )}
              {shownPrompt && (
                <section className="plaque px-3.5 py-3">
                  <Eyebrow>{t.portraitUsedPrompt}</Eyebrow>
                  <p className="mt-[7px] text-[12.5px] leading-[1.5] break-words text-on-surface-variant select-text">
                    {shownPrompt}
                  </p>
                </section>
              )}
              <button
                type="button"
                data-action="delete-portrait"
                disabled={busy}
                onClick={() => setConfirmDelete(true)}
                className="inline-flex min-h-9 items-center gap-2 self-start px-1 text-[14px] text-crimson disabled:pointer-events-none disabled:opacity-40"
              >
                <Trash2 size={16} aria-hidden="true" />
                {t.portraitDeleteThis}
              </button>
            </>
          )}
        </div>

        <div className="flex min-w-0 flex-col gap-3">
          {providers.isPending ? (
            <AppBusyLabel label={t.portraitLoadingSettings} />
          ) : providers.isError ? (
            <AppErrorView title={t.errorTitle} message={t.errorBody} onRetry={() => void providers.refetch()} />
          ) : (
            <>
              {!noProviders && (
                <SpellTabs
                  plain
                  label={t.actionPortrait}
                  current={shownMode}
                  onSelect={(key) => setMode(key as 'ai' | 'upload')}
                  t={t}
                  tabs={[
                    { key: 'ai', title: t.portraitGenerateAi, ready: false },
                    { key: 'upload', title: t.portraitUpload, ready: false },
                  ]}
                />
              )}
              {shownMode === 'upload' && (
                <section className="card flex flex-col gap-3 p-4">
                  {noProviders && <p className="text-[13.5px] text-on-surface-variant">{t.portraitNoProviders}</p>}
                  <input
                    ref={fileInput}
                    type="file"
                    hidden
                    data-field="portrait-file"
                    accept={IMPORT_ACCEPT}
                    onChange={(e) => void onFile(e.target.files?.[0])}
                  />
                  {importing ? (
                    <AppBusyLabel label={t.portraitImporting} />
                  ) : (
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => fileInput.current?.click()}
                      className="plaque flex min-h-[210px] w-full cursor-pointer flex-col items-center justify-center gap-2 p-6 text-center"
                    >
                      <Upload size={34} aria-hidden="true" className="text-gold" />
                      <b className="font-display text-[16px] font-normal text-on-surface">{t.portraitImportTitle}</b>
                      <span className="text-[12.5px] text-on-surface-variant">{t.portraitImportHint}</span>
                    </button>
                  )}
                </section>
              )}
            </>
          )}
          {error && (
            <p role="alert" className="rounded-[var(--radius-card)] border border-crimson px-3.5 py-2.5 text-[13.5px] text-on-surface">
              {error}
            </p>
          )}
        </div>
      </div>

      <AppDialog
        open={confirmDelete}
        onOpenChange={setConfirmDelete}
        title={t.portraitDeleteTitle}
        icon={Trash2}
        iconClassName="text-crimson"
        actions={[
          { label: t.cancel },
          {
            label: t.diaryDeleteAction,
            primary: true,
            tone: 'crimson',
            onSelect: () => shownKey && void remove(shownKey),
          },
        ]}
      >
        <p>{t.portraitDeleteBody}</p>
      </AppDialog>
    </div>
  );
}
