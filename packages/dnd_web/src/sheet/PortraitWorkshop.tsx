import { useMemo, useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Check, History, Image as ImageIcon, Sparkles, Trash2, Upload, X } from 'lucide-react';
import { ApiError } from '../api/client';
import {
  deletePortrait,
  fetchImageProvider,
  fetchPortraitProviders,
  generatePortraits,
  PortraitGenerateError,
  setImageProvider,
  toBase64,
} from '../api/portraits';
import { portraitStyles } from '../engine';
import { useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { Link } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { Medallion } from '../ui/Medallion';
import { portraitUrl, thumbnailUrl } from '../ui/portrait';
import { AppBusyLabel, AppErrorView } from '../ui/status';
import { Button } from '../ui/Button';
import { Select, Tooltip } from '../ui/primitives';
import { Option, SpellTabs } from '../ui/wizard';
import type { SheetNotify } from './writer';

/** El retrato que el servidor acepta al subir: lo mismo que el `accept` de
 *  Flutter. El servidor valida el contenido de verdad (`sniffPortraitImageType`);
 *  esto solo filtra el selector. */
const IMPORT_ACCEPT = '.png,.jpg,.jpeg,.webp,.gif';

/** La referencia no admite GIF: se le manda al proveedor de IA, que espera una
 *  imagen fija. */
const REFERENCE_ACCEPT = '.png,.jpg,.jpeg,.webp';

/** Los estilos son identificadores en español porque se guardan así y viajan
 *  al prompt tal cual (el motor los traduce a inglés); solo lo que se muestra
 *  se traduce. `CUSTOM_STYLE` es el estilo escrito por la persona. */
const CUSTOM_STYLE = 'Personalizado';
const styleLabel = (t: Texts, id: string): string =>
  ({
    'Arte digital de fantasía': t.styleDigitalFantasy,
    'Óleo clásico': t.styleClassicOil,
    'Ilustración de cómic': t.styleComic,
    'Realista cinematográfico': t.styleCinematic,
    Acuarela: t.styleWatercolor,
    'Pixel art': t.stylePixelArt,
    'Boceto a lápiz': t.stylePencilSketch,
    [CUSTOM_STYLE]: t.styleCustom,
  })[id] ?? id;

const FIELD =
  'w-full rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 py-2 text-[14px] text-on-surface';

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
  inline = false,
}: {
  label: string;
  items: { id: string; src: string; label: string; selected: boolean; current?: boolean }[];
  onSelect: (id: string) => void;
  /** Las imágenes son `data:` (resultados recién generados): no hay
   *  miniatura del servidor que pedir. */
  inline?: boolean;
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
                src={inline ? item.src : thumbnailUrl(item.src, 57)}
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

/** Quién es el dueño de los retratos: una ficha propia o un PNJ. El taller no
 *  sabe de fichas ni de PNJ; el dueño le dice dónde se guarda, cómo se arma el
 *  prompt y qué se escribe, y el motor decide el resto. */
export interface PortraitOwner {
  name: string;
  caption: string;
  accent: string | null;
  backHref: string;
  backLabel: string;
  paths: string[];
  prompts: Record<string, string>;
  detailsLabel: string;
  initialDetails: string;
  /** Al salir del campo. Solo el PNJ sin ficha guarda lo escrito. */
  commitDetails?: (text: string) => void;
  /** Debe estar memoizado: el taller lo usa para recalcular el prompt. */
  buildPrompt(style: string, details: string, includeWeapon: boolean): string;
  upload(file: File): Promise<string>;
  saveBase64(base64: string): Promise<string>;
  apply(action: { type: 'addPortrait'; key: string; prompt?: string } | { type: 'restorePortrait' | 'removePortrait'; key: string }): void;
  notify: SheetNotify;
}

/**
 * El taller de retratos (`PortraitScreen` de Flutter): subir un archivo, generar
 * con IA, volver a un retrato guardado y borrarlo. Cada acción **deja la
 * pantalla abierta** y avisa: Flutter cerraba sola al terminar, y acá nada
 * avanza solo (ver las reglas de `diseno-web-react.md`). Lo que se escribe pasa
 * por el motor (`addPortrait`, `restorePortrait`, `removePortrait`); este
 * archivo no decide nada del orden.
 */
export function PortraitWorkshop({ owner }: { owner: PortraitOwner }) {
  const t = useTexts();
  const { paths, prompts } = owner;

  const client = useQueryClient();
  const providers = useQuery({
    queryKey: ['portrait-providers'],
    queryFn: ({ signal }) => fetchPortraitProviders(signal),
  });
  const savedProvider = useQuery({
    queryKey: ['portrait-image-provider'],
    queryFn: ({ signal }) => fetchImageProvider(signal),
  });
  const noProviders = providers.isSuccess && providers.data.length === 0;
  const loadFailed = providers.isError || savedProvider.isError;
  const loading = !loadFailed && (providers.isPending || savedProvider.isPending);
  const list = providers.data ?? [];

  // Arranca en el motor que la cuenta dejó fijado, si sigue entre los
  // disponibles; si no, en el primero. Tocar uno lo fija (`selectProvider`).
  const [chosenProvider, setChosenProvider] = useState<string | null>(null);
  const providerId =
    chosenProvider ?? (list.some((p) => p.id === savedProvider.data) ? savedProvider.data! : (list[0]?.id ?? null));
  const provider = list.find((p) => p.id === providerId);

  const [style, setStyle] = useState<string>(() => portraitStyles()[0] ?? '');
  const [customStyle, setCustomStyle] = useState('');
  const [details, setDetails] = useState(owner.initialDetails);
  const [reference, setReference] = useState<{ name: string; base64: string } | null>(null);
  const referenceInput = useRef<HTMLInputElement>(null);
  const [generating, setGenerating] = useState(false);
  const [saving, setSaving] = useState(false);
  // Los candidatos recién generados, en base64, y cuál se mira. Se miran antes
  // de comprometer nada: usar uno es un paso aparte.
  const [results, setResults] = useState<string[]>([]);
  const [resultIndex, setResultIndex] = useState<number | null>(null);
  // El prompt con que se pidieron los [results], tomado **al pedirlos**: el
  // texto puede cambiar entre generar y elegir, y lo que se guarda tiene que
  // ser lo que de verdad produjo la imagen.
  const [resultsPrompt, setResultsPrompt] = useState<string | null>(null);

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
  const busy = importing || deleting || generating || saving;

  const effectiveStyle = style === CUSTOM_STYLE ? customStyle : style;
  // El motor arma el prompt. Azure rechaza los retratos que nombran un arma
  // (su filtro de contenido), así que con él se omite.
  const includeWeapon = providerId !== 'azure';
  const { buildPrompt } = owner;
  const prompt = useMemo(
    () => buildPrompt(effectiveStyle, details, includeWeapon),
    [buildPrompt, effectiveStyle, details, includeWeapon],
  );
  // El aporte propio se pinta en oro. Se busca dentro del prompt y no con
  // `startsWith` del prompt base: el base termina en otra frase («Bust/portrait
  // framing…»), así que el prompt nunca empieza con él y no coincidiría jamás.
  const extra = details.trim();
  const at = extra ? prompt.indexOf(', ' + extra) : -1;

  // Un resultado mirado no es de nadie todavía: no hay acciones de guardado.
  const resultSrc = resultIndex === null ? null : `data:image/png;base64,${results[resultIndex]}`;
  const shownKey = resultIndex !== null ? null : (viewKey ?? paths[0] ?? null);
  const heroSrc = resultSrc ?? (shownKey ? portraitUrl(shownKey) : null);
  const shownPrompt = shownKey ? prompts[shownKey] : undefined;

  const onFile = async (file: File | undefined) => {
    if (fileInput.current) fileInput.current.value = '';
    if (!file) return;
    setImporting(true);
    setError(null);
    try {
      const key = await owner.upload(file);
      owner.apply({ type: 'addPortrait', key });
      setViewKey(null);
      owner.notify(t.portraitSaved, { tone: 'success' });
    } catch (e) {
      // El servidor rechaza con 400 (tipo) o 413 (tamaño) sin decir cuál.
      setError(e instanceof ApiError && (e.status === 400 || e.status === 413) ? t.diaryUploadRejected : t.portraitImportError);
    } finally {
      setImporting(false);
    }
  };

  const selectProvider = async (id: string) => {
    setChosenProvider(id);
    try {
      await setImageProvider(id);
      client.setQueryData(['portrait-image-provider'], id);
    } catch {
      // La elección sigue valiendo en esta sesión aunque no quede guardada.
      owner.notify(t.portraitDefaultError, { tone: 'error' });
    }
  };

  const pickReference = async (file: File | undefined) => {
    if (referenceInput.current) referenceInput.current.value = '';
    if (!file) return;
    try {
      setReference({ name: file.name, base64: toBase64(new Uint8Array(await file.arrayBuffer())) });
    } catch {
      setError(t.portraitReferenceError);
    }
  };

  const generate = async () => {
    if (!provider) return;
    setGenerating(true);
    setError(null);
    setResults([]);
    setResultIndex(null);
    // Lo que llegue va a quedar a la vista: un guardado mirado de antes dejaría
    // dos cosas compitiendo por el mismo lienzo.
    setViewKey(null);
    const asked = prompt;
    try {
      const images = await generatePortraits({
        providerId: provider.id,
        prompt: asked,
        referenceBase64: provider.supportsReference ? reference?.base64 : undefined,
      });
      setResults(images);
      setResultsPrompt(asked);
      // El primero queda mirado: si vino uno solo, usarlo es un toque.
      setResultIndex(images.length ? 0 : null);
    } catch (e) {
      // Un `TypeError` de `fetch` es que no hay red.
      setError(
        e instanceof TypeError
          ? t.portraitOffline
          : e instanceof PortraitGenerateError
            ? t.portraitGenerateError(e.message)
            : t.portraitGenerateFailed,
      );
    } finally {
      setGenerating(false);
    }
  };

  // Guarda el resultado mirado como retrato, con el prompt que lo produjo. El
  // usado **sale de la tira**: dejarlo permitiría guardarlo dos veces.
  const useResult = async () => {
    if (resultIndex === null) return;
    const index = resultIndex;
    setSaving(true);
    setError(null);
    let key: string;
    try {
      key = await owner.saveBase64(results[index] ?? '');
    } catch {
      setError(t.portraitSaveError);
      setSaving(false);
      return;
    }
    owner.apply({ type: 'addPortrait', key, prompt: resultsPrompt ?? undefined });
    setResults((all) => all.filter((_, i) => i !== index));
    setResultIndex(null);
    setViewKey(null);
    setSaving(false);
    owner.notify(t.portraitSaved, { tone: 'success' });
  };

  // Vuelve a un retrato ya guardado: no sube nada, solo pasa adelante.
  const restore = (key: string) => {
    owner.apply({ type: 'restorePortrait', key });
    setViewKey(null);
    owner.notify(t.portraitRestored, { tone: 'success' });
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
    owner.apply({ type: 'removePortrait', key });
    setViewKey(null);
    setDeleting(false);
    owner.notify(t.portraitDeleted, { tone: 'success' });
  };

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="portrait">
      <header className="flex flex-col gap-1">
        <Link
          href={owner.backHref}
          className="inline-flex min-h-9 items-center gap-1.5 self-start text-[13px] text-gold no-underline hover:text-on-surface"
        >
          <ArrowLeft size={16} aria-hidden="true" />
          {owner.backLabel}
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
                  alt={t.portraitOf(owner.name)}
                  data-portrait
                  onError={() => setHeroFailed(heroSrc)}
                  className="h-full w-full object-cover"
                />
              ) : (
                <Medallion name={owner.name} accent={owner.accent} size={120} />
              )}
              {generating && (
                <div
                  role="status"
                  className="absolute inset-0 flex flex-col items-center justify-center gap-3 text-gold"
                  style={{ background: 'color-mix(in srgb, var(--scaffold) 78%, transparent)' }}
                >
                  <span
                    aria-hidden="true"
                    className="h-[30px] w-[30px] animate-spin rounded-full border-2 border-gold-soft border-t-gold"
                  />
                  <b className="eyebrow !text-gold">{t.portraitSummoning}</b>
                </div>
              )}
              <Corner at="tl" />
              <Corner at="tr" />
              <Corner at="bl" />
              <Corner at="br" />
            </div>
            <figcaption className="flex flex-col gap-0.5">
              <b className="font-display text-[18px] font-normal text-on-surface">{owner.name}</b>
              <span className="text-[13px] text-on-surface-variant">{owner.caption}</span>
            </figcaption>
          </figure>

          {results.length > 0 && (
            <>
              <ThumbStrip
                inline
                label={t.portraitResults}
                items={results.map((b64, i) => ({
                  id: String(i),
                  src: `data:image/png;base64,${b64}`,
                  label: t.portraitResult(i + 1),
                  selected: i === resultIndex,
                }))}
                onSelect={(id) => {
                  setResultIndex(Number(id));
                  setViewKey(null);
                }}
              />
              <Button
                icon={Check}
                data-action="use-portrait"
                disabled={busy || resultIndex === null}
                onClick={() => void useResult()}
                className="min-h-11 w-full"
              >
                {t.portraitUseThis}
              </Button>
            </>
          )}

          {paths.length > 0 && (
            <>
              <Eyebrow>{t.portraitSavedTitle}</Eyebrow>
              <ThumbStrip
                label={t.portraitSavedTitle}
                items={paths.map((key, i) => ({
                  id: key,
                  src: portraitUrl(key),
                  label: i === 0 ? t.portraitCurrent : t.portraitPrevious(i),
                  selected: resultIndex === null && key === shownKey,
                  current: i === 0,
                }))}
                onSelect={(key) => {
                  setResultIndex(null);
                  setViewKey(key === paths[0] ? null : key);
                }}
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

          {/* La lámina del guardado mirado no la lleva: ahí el panel es el del
              prompt usado, y dos prompts a la vez no se sabrían distinguir. */}
          {shownMode === 'ai' && !viewKey && (
            <section className="plaque px-3.5 py-3">
              <Eyebrow>{t.portraitBaseDescription}</Eyebrow>
              <p
                data-field="portrait-prompt"
                className="mt-[7px] text-[12.5px] leading-[1.5] break-words text-on-surface-variant select-text"
              >
                {at < 0 ? (
                  prompt
                ) : (
                  <>
                    {prompt.slice(0, at)}
                    <span className="text-gold">{prompt.slice(at, at + 2 + extra.length)}</span>
                    {prompt.slice(at + 2 + extra.length)}
                  </>
                )}
              </p>
            </section>
          )}
        </div>

        <div className="flex min-w-0 flex-col gap-3">
          {loading ? (
            <AppBusyLabel label={t.portraitLoadingSettings} />
          ) : loadFailed ? (
            <AppErrorView
              title={t.errorTitle}
              message={t.errorBody}
              onRetry={() => {
                void providers.refetch();
                void savedProvider.refetch();
              }}
            />
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
              {shownMode === 'ai' && provider && (
                <section className="card flex flex-col gap-3 p-4">
                  <Eyebrow>{t.portraitEngine}</Eyebrow>
                  <div role="radiogroup" aria-label={t.portraitEngine} className="grid gap-2 sm:grid-cols-3">
                    {list.map((p) => (
                      <Option
                        key={p.id}
                        id={p.id}
                        selected={p.id === providerId}
                        title={p.name}
                        detail={p.supportsReference ? t.portraitAcceptsReference : t.portraitTextOnly}
                        onClick={() => void selectProvider(p.id)}
                      />
                    ))}
                  </div>
                  <Select
                    label={t.portraitStyle}
                    value={style}
                    onValueChange={setStyle}
                    options={[...portraitStyles(), CUSTOM_STYLE].map((id) => ({ value: id, label: styleLabel(t, id) }))}
                  />
                  {style === CUSTOM_STYLE && (
                    <input
                      data-field="portrait-custom-style"
                      aria-label={t.portraitCustomStyle}
                      placeholder={t.portraitCustomStyle}
                      value={customStyle}
                      onChange={(e) => setCustomStyle(e.target.value)}
                      className={FIELD}
                    />
                  )}
                  <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
                    {owner.detailsLabel}
                    <textarea
                      data-field="portrait-details"
                      rows={3}
                      placeholder={t.portraitDetailsHint}
                      value={details}
                      onChange={(e) => setDetails(e.target.value)}
                      onBlur={() => owner.commitDetails?.(details)}
                      className={`${FIELD} resize-y leading-normal`}
                    />
                  </label>
                  {provider.supportsReference && (
                    <div className="flex flex-col gap-1.5 text-[12px] text-text-muted">
                      {t.portraitReference}
                      <input
                        ref={referenceInput}
                        type="file"
                        hidden
                        data-field="portrait-reference"
                        accept={REFERENCE_ACCEPT}
                        onChange={(e) => void pickReference(e.target.files?.[0])}
                      />
                      <div className="flex items-center gap-2">
                        <Button
                          tone="secondary"
                          icon={ImageIcon}
                          disabled={busy}
                          onClick={() => referenceInput.current?.click()}
                          className="min-w-0"
                        >
                          <span className="truncate">{reference?.name ?? t.portraitChooseImage}</span>
                        </Button>
                        {reference && (
                          <Tooltip content={t.portraitRemoveReference}>
                            <button
                              type="button"
                              aria-label={t.portraitRemoveReference}
                              onClick={() => setReference(null)}
                              className="flex h-9 w-9 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:bg-plaque"
                            >
                              <X size={18} aria-hidden="true" />
                            </button>
                          </Tooltip>
                        )}
                      </div>
                    </div>
                  )}
                  <Button
                    icon={generating ? undefined : Sparkles}
                    data-action="generate-portrait"
                    disabled={busy}
                    onClick={() => void generate()}
                    className="min-h-11 w-full"
                  >
                    {generating && (
                      <span
                        aria-hidden="true"
                        className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-on-primary/30 border-t-on-primary"
                      />
                    )}
                    {generating ? t.portraitGenerating : resultsPrompt !== null ? t.portraitGenerateAgain : t.portraitGenerate}
                  </Button>
                  {providerId === 'pollinations' && <p className="m-0 text-[12px] text-text-muted">{t.portraitFreeNote}</p>}
                </section>
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
