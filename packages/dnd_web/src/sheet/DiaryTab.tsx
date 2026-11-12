import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Check,
  Download,
  Feather,
  GripVertical,
  Link2,
  Pencil,
  Plus,
  ScrollText,
  TriangleAlert,
  Upload,
} from 'lucide-react';
import { ApiError } from '../api/client';
import { deletePortrait, uploadPortrait } from '../api/portraits';
import type { DiaryEntry } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { cx } from '../ui/cx';
import { MarkdownText } from '../ui/MarkdownText';
import { PortraitViewer } from '../ui/PortraitViewer';
import { ScrollArea, Tooltip } from '../ui/primitives';
import { portraitUrl, thumbnailUrl } from '../ui/portrait';
import { useReorder } from '../ui/reorder';
import { AppBusyLabel, AppEmptyState } from '../ui/status';
import type { SheetModel } from './model';
import type { SheetNotify } from './writer';

/** La imagen de una entrada vive en el almacén de retratos (`imageKey` es
 *  `<personaje>/<archivo>`), que se sirve con la misma cookie de sesión. */
const imageUrl = portraitUrl;

/** Solo se enlaza lo que es web: un `javascript:` escrito en una entrada no
 *  puede volverse un enlace que se ejecute al tocarlo. */
const safeUrl = (url: string | null | undefined): string | null =>
  url && /^https?:\/\//i.test(url.trim()) ? url.trim() : null;

/** El dominio que acompaña al nombre del enlace en su pill. Una URL que no se
 *  puede leer se muestra tal cual. */
const domainOf = (url: string): string => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
};

/**
 * Pestaña Diario: el lado creativo del personaje. El **trasfondo** está
 * siempre (vacío, dice «Origen desconocido»): todo personaje viene de algún
 * lado. Las **entradas** son opcionales; van en el orden en que el jugador
 * las acomodó, no por fecha. En la ficha propia (con `model.write`) se
 * escribe todo; en la de un miembro de la Mesa no hay ni un control.
 *
 * Nada de acá es una regla: no llega a `ComputedSheet` ni cambia un número.
 */
export function DiaryTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character } = model;
  const background = character.background?.trim() ?? '';
  const write = model.write;
  const edit = useMemo<DiaryEditor | undefined>(
    () =>
      write && {
        // `at` lo pone esta capa y no el motor, para que el motor no dependa del
        // reloj.
        save: (input) => write.act({ type: 'saveDiaryEntry', ...input, at: new Date().toISOString() }),
        remove(entry) {
          const r = write.act({ type: 'removeDiaryEntry', entry: entry.entryId });
          if (!r) return;
          if (hasImage(entry)) {
            // Con imagen no se ofrece deshacer: el archivo se va y volvería roto.
            // La entrada ya salió del documento, que es lo que se pidió; un
            // archivo que queda es basura barata que se lleva la cascada de
            // borrar al dueño.
            void deletePortrait(entry.imageKey!).catch(() => undefined);
            return;
          }
          write.notify(t.diaryDeleted(entry.title || t.diaryUntitled), { undo: () => write.restore(r.before) });
        },
        move: (from, to) => void write.act({ type: 'moveDiaryEntry', entry: from, to }),
        upload: (file) => uploadPortrait(character.id, file),
      },
    [write, character.id, t],
  );

  return (
    <div className="flex flex-col gap-4">
      {model.write ? (
        <BackgroundEditor
          saved={character.background ?? ''}
          ownerName={character.name}
          onSave={(text) => void model.write?.act({ type: 'setBackground', text })}
          notify={model.write.notify}
        />
      ) : (
        <Card id="background" title={t.diaryBackground} icon={ScrollText}>
          {background ? (
            <BackgroundText text={background} label={t.diaryBackground} />
          ) : (
            <div className="max-w-[620px]">
              <p className="font-display text-[16px] text-on-surface">{t.diaryUnknownOrigin}</p>
              <p className="mt-1 text-on-surface-variant">{t.diaryUnknownOriginBody(character.name)}</p>
            </div>
          )}
        </Card>
      )}
      <DiaryEntries
        entries={character.diary ?? []}
        title={t.diaryEntries}
        emptyMessage={t.diaryEmpty(character.name)}
        edit={edit}
      />
    </div>
  );
}

const ICON_BUTTON =
  'inline-flex h-9 w-9 items-center justify-center rounded-[var(--radius-nav)] hover:bg-plaque disabled:pointer-events-none disabled:opacity-40';

/** Igual que `_fileSlug` de Flutter: lo que se baja tiene que poder guardarse
 *  en cualquier sistema de archivos. */
const fileSlug = (name: string, fallback: string) =>
  name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || fallback;

/**
 * El trasfondo de la ficha **propia** y el de un PNJ: lectura con Markdown,
 * editor, importar y exportar un `.md` (`DiaryBackgroundCard` de Flutter). No
 * sabe de quién es: recibe el texto guardado y `onSave`, y cada dueño lo
 * escribe a su manera.
 *
 * El borrador vive en estado local y `onSave` se llama espaciado: cada acción recompila la ficha entera, y no puede pasar por
 * tecla. Se manda igual de inmediato al terminar de editar, al salir del campo
 * y al desmontar, para que lo escrito a medias no se pierda.
 */
export function BackgroundEditor({
  saved,
  ownerName,
  onSave,
  notify,
}: {
  saved: string;
  ownerName: string;
  onSave: (text: string) => void;
  notify: SheetNotify;
}) {
  const t = useTexts();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [replacing, setReplacing] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const timer = useRef<number | undefined>(undefined);
  const pending = useRef<string | null>(null);
  // El escritor se rearma cuando cambia el documento; el vaciado al desmontar
  // tiene que usar el último, no el de cuando se montó.
  const onSaveRef = useRef(onSave);
  onSaveRef.current = onSave;

  const flush = useCallback(() => {
    window.clearTimeout(timer.current);
    const text = pending.current;
    pending.current = null;
    if (text !== null) onSaveRef.current(text);
  }, []);
  useEffect(() => flush, [flush]);

  const type = (text: string) => {
    setDraft(text);
    pending.current = text;
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(flush, 400);
  };
  const current = editing ? draft : saved;
  const empty = current.trim() === '';

  const startEditing = () => {
    setDraft(saved);
    setEditing(true);
  };
  const toggleEditing = () => {
    if (editing) {
      flush();
      setEditing(false);
    } else startEditing();
  };

  const apply = (text: string) => {
    // Lo escrito a medias queda pisado por el archivo: que no vuelva con el
    // vaciado pendiente.
    window.clearTimeout(timer.current);
    pending.current = null;
    onSave(text);
    setEditing(false);
    notify(t.diaryImported);
  };

  const onFile = async (file: File | undefined) => {
    if (fileInput.current) fileInput.current.value = '';
    if (!file) return;
    let text: string;
    try {
      // Un .md no es cualquier cosa renombrada: si no es UTF-8, meterlo en la
      // ficha dejaría el trasfondo ilegible y guardado.
      text = new TextDecoder('utf-8', { fatal: true }).decode(await file.arrayBuffer());
    } catch {
      notify(t.diaryNotUtf8, { tone: 'error' });
      return;
    }
    // Reemplazar lo escrito no se puede deshacer: se pregunta. Vacío no hay
    // nada que perder.
    if (current.trim() !== '') setReplacing(text);
    else apply(text);
  };

  const exportMd = () => {
    const url = URL.createObjectURL(new Blob([current], { type: 'text/markdown' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = `${fileSlug(ownerName, t.diaryFileFallback)}-${t.diaryFileSuffix}.md`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const trailing = (
    <div className="flex items-center">
      <Tooltip content={t.diaryImportMd}>
        <button
          type="button"
          aria-label={t.diaryImportMd}
          onClick={() => fileInput.current?.click()}
          className={`${ICON_BUTTON} text-on-surface-variant`}
          data-action="import-background"
        >
          <Upload size={18} aria-hidden="true" />
        </button>
      </Tooltip>
      <Tooltip content={t.diaryExportMd}>
        <button
          type="button"
          aria-label={t.diaryExportMd}
          // Sin trasfondo no hay archivo que bajar.
          disabled={empty}
          onClick={exportMd}
          className={`${ICON_BUTTON} text-on-surface-variant`}
          data-action="export-background"
        >
          <Download size={18} aria-hidden="true" />
        </button>
      </Tooltip>
      <Tooltip content={editing ? t.diaryFinishEditing : t.diaryEditBackground}>
        <button
          type="button"
          aria-label={editing ? t.diaryFinishEditing : t.diaryEditBackground}
          onClick={toggleEditing}
          className={`${ICON_BUTTON} text-gold`}
          data-action="edit-background"
        >
          {editing ? <Check size={18} aria-hidden="true" /> : <Pencil size={18} aria-hidden="true" />}
        </button>
      </Tooltip>
    </div>
  );

  return (
    <Card id="background" title={t.diaryBackground} icon={ScrollText} trailing={trailing}>
      <input
        ref={fileInput}
        type="file"
        accept=".md,text/markdown"
        hidden
        onChange={(e) => void onFile(e.target.files?.[0])}
      />
      {editing ? (
        <>
          <textarea
            data-field="background-input"
            aria-label={t.diaryBackground}
            rows={11}
            autoFocus
            value={draft}
            onChange={(e) => type(e.target.value)}
            onBlur={flush}
            className="w-full resize-y rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 py-2 text-[14px] text-on-surface"
          />
          <p className="mt-2 text-[12px] text-text-muted">{t.diaryMarkdownHint}</p>
        </>
      ) : saved.trim() ? (
        <BackgroundText text={saved.trim()} label={t.diaryBackground} />
      ) : (
        <div className="max-w-[620px]">
          <p className="font-display text-[16px] text-on-surface-variant italic">{t.diaryUnknownOrigin}</p>
          <p className="mt-1 text-on-surface-variant">{t.diaryUnknownOriginBody(ownerName)}</p>
          <div className="mt-4 flex flex-wrap gap-2.5">
            <Button tone="secondary" icon={Pencil} onClick={startEditing}>
              {t.diaryWriteBackground}
            </Button>
            <Button tone="secondary" icon={Upload} onClick={() => fileInput.current?.click()}>
              {t.diaryImportMdShort}
            </Button>
          </div>
        </div>
      )}
      {replacing !== null && (
        <AppDialog
          open
          onOpenChange={(v) => !v && setReplacing(null)}
          title={t.diaryReplaceTitle}
          icon={TriangleAlert}
          iconClassName="text-crimson"
          actions={[
            { label: t.cancel },
            { label: t.diaryReplace, primary: true, tone: 'crimson', onSelect: () => apply(replacing) },
          ]}
        >
          <p>{t.diaryReplaceBody}</p>
        </AppDialog>
      )}
    </Card>
  );
}

/** Lo que se puede hacer con una lista de entradas. Lo arma quien tiene el
 *  documento: `DiaryTab` con `model.write`, `NpcDetailView` con su escritor.
 *  Sin él, la tarjeta es de solo lectura:
 *  sin «+», sin ícono de mover y sin «Editar». */
export interface DiaryEditor {
  /** Alta (un `entry` nuevo) o edición. El motor recorta; un enlace o un nombre
   *  vacío se guardan como ausentes. */
  save(input: {
    entry: string;
    title: string;
    body: string;
    imageKey: string | null;
    url: string;
    linkLabel: string;
  }): void;
  /** Borra, avisa y, sin imagen, ofrece deshacer. */
  remove(entry: DiaryEntry): void;
  move(from: string, to: string): void;
  /** Sube una imagen al almacén bajo el dueño y devuelve su clave. */
  upload(file: File): Promise<string>;
}

const hasImage = (e: DiaryEntry) => !!e.imageKey;

/**
 * Las entradas del Diario: una columna de tarjetas que muestran todo su
 * contenido (texto, imagen y enlace). Son las mismas que usan las notas de un
 * PNJ: un segundo molde obligaría a mantener dos.
 */
export function DiaryEntries({
  entries,
  title,
  emptyMessage,
  edit,
}: {
  entries: DiaryEntry[];
  title: string;
  emptyMessage: string;
  edit?: DiaryEditor;
}) {
  const t = useTexts();
  const lang = useLang();
  // `null` es una entrada nueva; `undefined`, el editor cerrado.
  const [editing, setEditing] = useState<DiaryEntry | null | undefined>(undefined);
  const [deleting, setDeleting] = useState<DiaryEntry | null>(null);
  const reorder = useReorder({ ids: entries.map((e) => e.entryId), onMove: (from, to) => edit?.move(from, to) });
  const date = useMemo(() => new Intl.DateTimeFormat(lang, { day: 'numeric', month: 'numeric' }), [lang]);
  // «12/3», o «12/3 · editada 2/4» si se tocó después. Sin fecha (la entrada
  // que salió de las notas viejas) no se inventa una.
  const dates = (e: DiaryEntry): string => {
    const created = e.createdAt ? new Date(e.createdAt) : null;
    if (!created || Number.isNaN(created.getTime())) return '';
    const base = date.format(created);
    const touched = e.updatedAt ? new Date(e.updatedAt) : null;
    return touched && touched > created ? t.diaryEditedOn(base, date.format(touched)) : base;
  };

  const add = edit && (
    <Tooltip content={t.diaryAddEntryTooltip}>
      <button
        type="button"
        aria-label={t.diaryAddEntryTooltip}
        onClick={() => setEditing(null)}
        className={`${ICON_BUTTON} text-gold`}
        data-action="add-entry"
      >
        <Plus size={18} aria-hidden="true" />
      </button>
    </Tooltip>
  );

  return (
    <Card
      id="entries"
      title={title}
      icon={Feather}
      trailing={
        <div className="flex items-center gap-1">
          {entries.length > 0 && <span className="text-[12px] text-text-muted tabular-nums">{entries.length}</span>}
          {add}
        </div>
      }
    >
      {entries.length === 0 ? (
        <AppEmptyState
          kind="empty"
          message={emptyMessage}
          actions={
            edit && (
              <Button tone="secondary" icon={Plus} onClick={() => setEditing(null)}>
                {t.diaryAddEntry}
              </Button>
            )
          }
        />
      ) : (
        // Una sola columna: cada entrada muestra todo lo que lleva, y el orden
        // (que el jugador acomoda) se lee de arriba abajo.
        <ul className="flex flex-col gap-3">
          {entries.map((e) => (
            <EntryCard
              key={e.entryId}
              entry={e}
              dates={dates(e)}
              onEdit={edit ? () => setEditing(e) : undefined}
              reorder={edit ? reorder : undefined}
            />
          ))}
        </ul>
      )}

      {edit && editing !== undefined && (
        <EntryEditor
          entry={editing}
          edit={edit}
          onClose={() => setEditing(undefined)}
          onDelete={(e) => setDeleting(e)}
        />
      )}
      {edit && deleting && (
        <AppDialog
          open
          onOpenChange={(v) => !v && setDeleting(null)}
          title={t.diaryDeleteTitle}
          icon={TriangleAlert}
          iconClassName="text-crimson"
          actions={[
            { label: t.cancel },
            {
              label: t.diaryDeleteAction,
              primary: true,
              tone: 'crimson',
              onSelect: () => edit.remove(deleting),
            },
          ]}
        >
          <p>
            {/* Con imagen no hay vuelta atrás: el archivo se borra del servidor.
                Sin imagen sí, y el aviso de después lo deshace. */}
            {hasImage(deleting)
              ? t.diaryDeleteBodyImage(deleting.title || t.diaryUntitled)
              : t.diaryDeleteBody(deleting.title || t.diaryUntitled)}
          </p>
        </AppDialog>
      )}
    </Card>
  );
}

function EntryCard({
  entry,
  dates,
  onEdit,
  reorder,
}: {
  entry: DiaryEntry;
  dates: string;
  onEdit?: () => void;
  reorder?: ReturnType<typeof useReorder>;
}) {
  const t = useTexts();
  const [viewing, setViewing] = useState(false);
  const [gone, setGone] = useState(false);
  const title = entry.title || t.diaryUntitled;
  const id = entry.entryId;
  const body = entry.body?.trim() ?? '';
  const url = entry.url?.trim() ?? '';
  const link = safeUrl(url);
  const label = entry.linkLabel?.trim() ?? '';
  const showImage = !!entry.imageKey;
  const text = body !== '' && <MarkdownText text={body} className="text-[14px] leading-[1.55] text-on-surface" />;
  const linkNode =
    url !== '' &&
    (link ? (
      <a
        href={link}
        target="_blank"
        rel="noopener noreferrer"
        className="pick inline-flex h-[30px] max-w-full items-center gap-1.5 self-start rounded-[var(--radius-pill)] border border-hairline px-3 text-[12.5px] text-on-surface"
      >
        <Link2 size={14} aria-hidden="true" className="shrink-0 text-gold" />
        <span className="min-w-0 truncate">{label ? `${label} · ${domainOf(link)}` : domainOf(link)}</span>
        <span className="sr-only">{` (${t.diaryOpenLink})`}</span>
      </a>
    ) : (
      // Lo que no es web no se enlaza: se ve como texto, para poder copiarlo.
      <p className="text-[12.5px] break-all text-text-muted">{url}</p>
    ));
  const content = (text || linkNode) && <div className="flex min-w-0 flex-col gap-2.5">{text}{linkNode}</div>;
  return (
    // Un `<li>` y no un botón: la tarjeta tiene sus propios controles (editar,
    // abrir la imagen, el enlace) y un botón no puede ir adentro de otro.
    <li
      {...reorder?.item(id)}
      data-entry={id}
      className={cx(
        'plaque flex min-w-0 flex-col gap-2.5 border-2 px-4 py-3.5',
        reorder?.over === id ? 'border-gold' : 'border-hairline',
        reorder?.dragging === id && 'opacity-30',
      )}
    >
      <div className="flex items-baseline gap-2.5">
        <h3 className="font-display min-w-0 flex-1 text-[15px] leading-[1.3] break-words text-on-surface">{title}</h3>
        {dates && <span className="shrink-0 text-[12px] text-text-muted tabular-nums">{dates}</span>}
        {(onEdit || reorder) && (
          <span className="-my-1.5 -mr-2 flex shrink-0 items-center self-center">
            {onEdit && (
              <Tooltip content={t.diaryEditAction}>
                <button
                  type="button"
                  aria-label={`${t.diaryEditAction}: ${title}`}
                  data-action="edit-entry"
                  onClick={onEdit}
                  className={ICON_BUTTON}
                >
                  <Pencil size={16} aria-hidden="true" />
                </button>
              </Tooltip>
            )}
            {reorder && (
              <Tooltip content={t.diaryDragHint}>
                <button
                  type="button"
                  aria-label={t.diaryMoveEntry(title)}
                  className="inline-flex h-8 w-8 cursor-grab items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold"
                  {...reorder.grip(id)}
                >
                  <GripVertical size={16} aria-hidden="true" />
                </button>
              </Tooltip>
            )}
          </span>
        )}
      </div>
      {showImage ? (
        <div className="grid grid-cols-[150px_minmax(0,1fr)] items-start gap-3.5">
          {gone ? (
            <p className="text-[12.5px] text-text-muted">{t.diaryImageGone}</p>
          ) : (
            <button
              type="button"
              aria-label={t.diarySeeFullImage}
              onClick={() => setViewing(true)}
              className="block cursor-zoom-in overflow-hidden rounded-[var(--radius-nav)] border border-hairline"
            >
              <img
                src={thumbnailUrl(imageUrl(entry.imageKey!), 512)}
                alt={t.diaryImageAlt(entry.title)}
                loading="lazy"
                onError={() => setGone(true)}
                className="block h-[112px] w-full object-cover"
              />
            </button>
          )}
          {content}
        </div>
      ) : (
        content
      )}
      {showImage && !gone && (
        <PortraitViewer src={imageUrl(entry.imageKey!)} name={entry.title} open={viewing} onOpenChange={setViewing} />
      )}
    </li>
  );
}

const FIELD =
  'w-full rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 py-2 text-[14px] text-on-surface placeholder:text-text-muted';

/** Alta y edición. [entry] en null es una entrada nueva. */
function EntryEditor({
  entry,
  edit,
  onClose,
  onDelete,
}: {
  entry: DiaryEntry | null;
  edit: DiaryEditor;
  onClose: () => void;
  onDelete: (entry: DiaryEntry) => void;
}) {
  const t = useTexts();
  const [title, setTitle] = useState(entry?.title ?? '');
  const [body, setBody] = useState(entry?.body ?? '');
  const [imageKey, setImageKey] = useState<string | null>(entry?.imageKey ?? null);
  const [url, setUrl] = useState(entry?.url ?? '');
  const [linkLabel, setLinkLabel] = useState(entry?.linkLabel ?? '');
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fileName, setFileName] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  // Solo el título es obligatorio: texto, imagen y enlace se combinan o no.
  const canSave = !uploading && title.trim() !== '';

  const choose = async (file: File | undefined) => {
    if (fileInput.current) fileInput.current.value = '';
    if (!file) return;
    setUploading(true);
    setError(null);
    try {
      // ponytail: cambiar la imagen de una entrada, o cancelar después de
      // subir, deja la anterior en el almacén hasta que se borra el dueño (la
      // cascada se la lleva). Si algún día molesta el espacio, borrarla acá es
      // una llamada a `deletePortrait`.
      setImageKey(await edit.upload(file));
      setFileName(file.name);
    } catch (e) {
      // El servidor rechaza con 400 (tipo) o 413 (tamaño) sin decir cuál: el
      // aviso nombra las dos causas.
      setError(e instanceof ApiError && (e.status === 400 || e.status === 413) ? t.diaryUploadRejected : t.diaryUploadError);
    } finally {
      setUploading(false);
    }
  };

  const save = () =>
    edit.save({
      entry: entry?.entryId ?? `diary-${Date.now()}`,
      title,
      body,
      imageKey,
      url,
      linkLabel,
    });

  return (
    <AppDialog
      open
      onOpenChange={(v) => !v && onClose()}
      title={entry ? t.diaryEditEntry : t.diaryNewEntry}
      icon={entry ? Pencil : Plus}
      width={560}
      actions={[
        { label: t.cancel },
        ...(entry ? [{ label: t.diaryDeleteAction, tone: 'crimson' as const, onSelect: () => onDelete(entry) }] : []),
        { label: t.commonSave, primary: true, disabled: !canSave, onSelect: save },
      ]}
    >
      <div className="flex flex-col gap-4">
        <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
          <span>{t.diaryTitleLabel}</span>
          <input
            data-field="entry-title"
            value={title}
            autoFocus
            onChange={(e) => setTitle(e.target.value)}
            className={FIELD}
          />
        </label>
        <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
          <span>{t.diaryText}</span>
          <textarea
            data-field="entry-body"
            rows={4}
            value={body}
            placeholder={t.diaryBodyHint}
            onChange={(e) => setBody(e.target.value)}
            className={`${FIELD} resize-y`}
          />
        </label>
        <div className="flex flex-col gap-1.5" data-field="entry-image">
          <span className="text-[12px] text-text-muted">{t.diaryImageLabel}</span>
          <input
            ref={fileInput}
            type="file"
            accept=".png,.jpg,.jpeg,.webp,.gif"
            hidden
            onChange={(e) => void choose(e.target.files?.[0])}
          />
          {uploading ? (
            <AppBusyLabel label={t.diaryUploading} />
          ) : imageKey ? (
            <div className="plaque flex items-center gap-3 p-2.5">
              <img
                src={thumbnailUrl(imageUrl(imageKey), 512)}
                alt=""
                className="block h-16 w-[88px] shrink-0 rounded-[var(--radius-nav)] object-cover"
              />
              <span className="min-w-0 flex-1 truncate text-[13px] text-on-surface-variant">{fileName ?? ''}</span>
              <Button tone="secondary" onClick={() => fileInput.current?.click()}>
                {t.luChange}
              </Button>
              <Button tone="danger" onClick={() => setImageKey(null)}>
                {t.dmRemoveShort}
              </Button>
            </div>
          ) : (
            <div>
              <Button tone="secondary" icon={Upload} onClick={() => fileInput.current?.click()}>
                {t.diaryChooseImage}
              </Button>
            </div>
          )}
        </div>
        <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
          <span>{t.diaryLinkLabel}</span>
          <input
            type="url"
            data-field="entry-url"
            value={url}
            placeholder="https://…"
            onChange={(e) => setUrl(e.target.value)}
            className={FIELD}
          />
        </label>
        <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
          <span>{t.diaryLinkName}</span>
          <input
            data-field="entry-link-label"
            value={linkLabel}
            onChange={(e) => setLinkLabel(e.target.value)}
            className={FIELD}
          />
        </label>
        <p className="text-[12.5px] text-text-muted">{t.diaryOnlyTitleRequired}</p>
        {error && (
          <p role="alert" className="text-[12.5px] text-crimson">
            {error}
          </p>
        )}
      </div>
    </AppDialog>
  );
}

/**
 * Un trasfondo: la prosa a medida de lectura (unos 66 caracteres; estirada a
 * todo el ancho no se lee) y con un alto máximo. Uno de diez páginas no
 * empuja todo lo demás fuera de la pantalla: scrollea adentro de su tarjeta.
 * Lo comparten la ficha (Diario) y la ficha del PNJ.
 *
 * La zona que scrollea ocupa toda la tarjeta, así la barra va contra su borde
 * y no flota al lado del texto; la medida de lectura es del texto, adentro. Es
 * el `ScrollArea` del sistema (la barra del navegador es un bloque gris en el
 * tema oscuro), enfocable y con nombre para quien usa el teclado.
 */
export function BackgroundText({ text, label }: { text: string; label: string }) {
  return (
    <ScrollArea type="auto" label={label} viewportClassName="max-h-[min(420px,60vh)]">
      <div className="pr-3" data-field="background">
        <MarkdownText text={text} className="text-[15px] leading-[1.65] text-on-surface" />
      </div>
    </ScrollArea>
  );
}
