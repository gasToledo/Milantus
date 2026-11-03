import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Check,
  Download,
  ExternalLink,
  Feather,
  GripVertical,
  Image as ImageIcon,
  Link2,
  NotebookText,
  Pencil,
  Plus,
  ScrollText,
  TriangleAlert,
  Upload,
  type LucideIcon,
} from 'lucide-react';
import { ApiError } from '../api/client';
import { deletePortrait, uploadPortrait } from '../api/portraits';
import type { DiaryEntry } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { MarkdownText } from '../ui/MarkdownText';
import { PortraitViewer } from '../ui/PortraitViewer';
import { ScrollArea, Tooltip } from '../ui/primitives';
import { portraitUrl, thumbnailUrl } from '../ui/portrait';
import { useReorder } from '../ui/reorder';
import { AppBusyLabel, AppEmptyState } from '../ui/status';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

/** Un tipo desconocido se lee como texto, igual que `DiaryEntryKind.fromJson`. */
type Kind = 'text' | 'image' | 'link';
const kindOf = (e: DiaryEntry): Kind => (e.kind === 'image' || e.kind === 'link' ? e.kind : 'text');
const KIND_ICON: Record<Kind, LucideIcon> = { text: NotebookText, image: ImageIcon, link: Link2 };

/** La imagen de una entrada vive en el almacén de retratos (`imageKey` es
 *  `<personaje>/<archivo>`), que se sirve con la misma cookie de sesión. */
const imageUrl = portraitUrl;

/** Solo se enlaza lo que es web: un `javascript:` escrito en una entrada no
 *  puede volverse un enlace que se ejecute al tocarlo. */
const safeUrl = (body: string | undefined): string | null =>
  body && /^https?:\/\//i.test(body.trim()) ? body.trim() : null;

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
        <BackgroundCard model={model} write={model.write} />
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
 * El trasfondo de la ficha **propia**: lectura con Markdown, editor, importar y
 * exportar un `.md` (`DiaryBackgroundCard` de Flutter).
 *
 * El borrador vive en estado local y la acción `setBackground` se manda
 * espaciada: cada acción recompila la ficha entera, y no puede pasar por
 * tecla. Se manda igual de inmediato al terminar de editar, al salir del campo
 * y al desmontar, para que lo escrito a medias no se pierda.
 */
function BackgroundCard({ model, write }: { model: SheetModel; write: SheetWriter }) {
  const t = useTexts();
  const { character } = model;
  const saved = character.background ?? '';
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [replacing, setReplacing] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const timer = useRef<number | undefined>(undefined);
  const pending = useRef<string | null>(null);
  // El escritor se rearma cuando cambia la ficha; el vaciado al desmontar tiene
  // que usar el último, no el de cuando se montó.
  const writeRef = useRef(write);
  writeRef.current = write;

  const flush = useCallback(() => {
    window.clearTimeout(timer.current);
    const text = pending.current;
    pending.current = null;
    if (text !== null) writeRef.current.act({ type: 'setBackground', text });
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
    write.act({ type: 'setBackground', text });
    setEditing(false);
    write.notify(t.diaryImported);
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
      write.notify(t.diaryNotUtf8, { tone: 'error' });
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
    a.download = `${fileSlug(character.name, t.diaryFileFallback)}-${t.diaryFileSuffix}.md`;
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
          <p className="mt-1 text-on-surface-variant">{t.diaryUnknownOriginBody(character.name)}</p>
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

/** Lo que la ficha propia puede hacer con sus entradas. Lo arma `DiaryTab` con
 *  `model.write`; `DiaryEntries` no lo toca directamente porque las notas del
 *  PNJ (paso 6) van a tener otro dueño. Sin él, la tarjeta es de solo lectura:
 *  sin «+», sin ícono de mover y sin «Editar». */
export interface DiaryEditor {
  /** Alta (un `entry` nuevo) o edición. El motor recorta y limpia por tipo. */
  save(input: { entry: string; kind: Kind; title: string; body: string; imageKey: string | null }): void;
  /** Borra, avisa y, sin imagen, ofrece deshacer. */
  remove(entry: DiaryEntry): void;
  move(from: string, to: string): void;
  /** Sube una imagen al almacén bajo el dueño y devuelve su clave. */
  upload(file: File): Promise<string>;
}

const hasImage = (e: DiaryEntry) => kindOf(e) === 'image' && !!e.imageKey;

/**
 * Las entradas del Diario: una grilla de tarjetas que se abren en un diálogo.
 * Son las mismas que usan las notas de un PNJ, como en Flutter
 * (`DiaryEntriesCard`): un segundo molde obligaría a mantener dos.
 */
export function DiaryEntries({
  entries,
  title,
  emptyMessage,
  minWidth = 280,
  edit,
}: {
  entries: DiaryEntry[];
  title: string;
  emptyMessage: string;
  /** Ancho mínimo de una tarjeta: una columna lateral pide menos. */
  minWidth?: number;
  edit?: DiaryEditor;
}) {
  const t = useTexts();
  const lang = useLang();
  const [open, setOpen] = useState<DiaryEntry | null>(null);
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
        // Grilla y no columnas: al reordenar, el orden tiene que leerse de
        // izquierda a derecha, y en columnas la tarjeta siguiente quedaba
        // abajo. Las de una misma fila miden lo mismo.
        <ul
          className="grid gap-3"
          style={{ gridTemplateColumns: `repeat(auto-fill, minmax(min(${minWidth}px, 100%), 1fr))` }}
        >
          {entries.map((e) => (
            <EntryCard
              key={e.entryId}
              entry={e}
              dates={dates(e)}
              onOpen={() => setOpen(e)}
              reorder={edit ? reorder : undefined}
            />
          ))}
        </ul>
      )}

      {open && (
        <EntryReader
          entry={open}
          dates={dates(open)}
          onClose={() => setOpen(null)}
          onEdit={edit ? () => setEditing(open) : undefined}
        />
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
  onOpen,
  reorder,
}: {
  entry: DiaryEntry;
  dates: string;
  onOpen: () => void;
  reorder?: ReturnType<typeof useReorder>;
}) {
  const t = useTexts();
  const kind = kindOf(entry);
  const Icon = KIND_ICON[kind];
  const title = entry.title || t.diaryUntitled;
  const link = kind === 'link' ? safeUrl(entry.body) : null;
  const id = entry.entryId;
  return (
    // Un `<li>` con el botón que abre y, como hermano, el pie con el ícono de
    // mover: un botón no puede ir adentro de otro.
    <li
      {...reorder?.item(id)}
      className={cx(
        'flex min-w-0 flex-col overflow-hidden rounded-[var(--radius-card)] border-2 bg-plaque',
        reorder?.over === id ? 'border-gold' : 'border-hairline',
        reorder?.dragging === id && 'opacity-30',
      )}
    >
      <button
        type="button"
        onClick={onOpen}
        aria-label={t.diaryOpenEntry(title)}
        className="flex w-full flex-1 flex-col justify-start text-left"
        data-entry={id}
      >
        {kind === 'image' && entry.imageKey && (
          <img
            src={thumbnailUrl(imageUrl(entry.imageKey), 512)}
            alt=""
            loading="lazy"
            className="block h-[120px] w-full object-cover"
          />
        )}
        <span className="block px-[13px] pt-3">
          <span className="flex items-center gap-[7px]">
            <Icon size={15} aria-hidden="true" className="shrink-0 text-gold" />
            <span className="font-display min-w-0 flex-1 text-[15px] leading-[1.3] break-words text-on-surface">{title}</span>
          </span>
          {kind === 'image' && !entry.imageKey && (
            <span className="mt-[7px] block text-[12.5px] text-on-surface-variant">{t.diaryNoImage}</span>
          )}
          {kind !== 'image' && entry.body && (
            <span
              className={cx(
                'mt-[7px] line-clamp-4 block text-[12.5px] leading-[1.6] [overflow-wrap:anywhere] whitespace-pre-line',
                link ? 'text-gold' : 'text-on-surface-variant',
              )}
            >
              {entry.body}
            </span>
          )}
        </span>
      </button>
      <div className="flex min-h-9 items-center justify-between pr-1 pl-[13px] text-[11.5px] text-text-muted tabular-nums">
        <span>{dates}</span>
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
      </div>
    </li>
  );
}

/** Leer una entrada. Editar sale de acá y no de la tarjeta: es chica y un lápiz
 *  ahí competiría con el toque que abre la entrada. */
function EntryReader({
  entry,
  dates,
  onClose,
  onEdit,
}: {
  entry: DiaryEntry;
  dates: string;
  onClose: () => void;
  onEdit?: () => void;
}) {
  const t = useTexts();
  return (
    <AppDialog
      open
      onOpenChange={(v) => !v && onClose()}
      title={entry.title || t.diaryUntitled}
      icon={KIND_ICON[kindOf(entry)]}
      // 560 y no 480: el cuerpo puede ser una imagen.
      width={560}
      actions={[
        { label: t.close },
        ...(onEdit ? [{ label: t.diaryEditAction, primary: true, onSelect: onEdit }] : []),
      ]}
    >
      <div className="flex flex-col gap-3">
        {dates && <p className="text-[12px] text-text-muted tabular-nums">{dates}</p>}
        <EntryBody entry={entry} />
      </div>
    </AppDialog>
  );
}

/** La entrada completa, en el diálogo. */
function EntryBody({ entry }: { entry: DiaryEntry }) {
  const t = useTexts();
  const kind = kindOf(entry);
  const [viewing, setViewing] = useState(false);
  const [gone, setGone] = useState(false);
  if (kind === 'image') {
    if (!entry.imageKey) return <p>{t.diaryEntryNoImage}</p>;
    if (gone) return <p>{t.diaryImageGone}</p>;
    const src = imageUrl(entry.imageKey);
    return (
      <>
        <button type="button" aria-label={t.diarySeeFullImage} onClick={() => setViewing(true)} className="block cursor-zoom-in">
          <img
            src={src}
            alt={t.diaryImageAlt(entry.title)}
            onError={() => setGone(true)}
            className="w-full rounded-[var(--radius-nav)]"
          />
        </button>
        <PortraitViewer src={src} name={entry.title} open={viewing} onOpenChange={setViewing} />
      </>
    );
  }
  if (kind === 'link') {
    const url = safeUrl(entry.body);
    return url ? (
      <a
        href={url}
        target="_blank"
        rel="noopener noreferrer"
        className="inline-flex items-center gap-1.5 break-all text-gold underline underline-offset-2"
      >
        {url}
        <ExternalLink size={14} aria-hidden="true" className="shrink-0" />
        <span className="sr-only">{` (${t.diaryOpenLink})`}</span>
      </a>
    ) : (
      <p className="break-words">{entry.body}</p>
    );
  }
  return <MarkdownText text={entry.body ?? ''} className="text-[14px] leading-[1.6] text-on-surface" />;
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
  const [kind, setKind] = useState<Kind>(entry ? kindOf(entry) : 'text');
  // Un solo cuerpo para texto y enlace, como en Flutter: ninguna entrada usa
  // los dos a la vez.
  const [body, setBody] = useState(entry?.body ?? '');
  const [imageKey, setImageKey] = useState<string | null>(entry?.imageKey ?? null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const canSave = !uploading && title.trim() !== '' && (kind !== 'image' || imageKey !== null);

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
      kind,
      title,
      body,
      imageKey: kind === 'image' ? imageKey : null,
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
        <div>
          <Eyebrow>{t.diaryEntryType}</Eyebrow>
          <div role="radiogroup" aria-label={t.diaryEntryType} className="mt-2 flex flex-wrap gap-2">
            {(['text', 'image', 'link'] as const).map((k) => {
              const Icon = KIND_ICON[k];
              return (
                <button
                  key={k}
                  type="button"
                  role="radio"
                  aria-checked={kind === k}
                  onClick={() => setKind(k)}
                  className={cx(
                    'inline-flex min-h-9 items-center gap-1.5 rounded-[var(--radius-pill)] border px-3.5 text-[13px]',
                    kind === k ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface',
                  )}
                >
                  <Icon size={15} aria-hidden="true" />
                  {t.diaryKinds[k]}
                </button>
              );
            })}
          </div>
        </div>
        {kind === 'image' ? (
          <div className="flex flex-col gap-3">
            {imageKey && (
              <img
                src={thumbnailUrl(imageUrl(imageKey), 512)}
                alt=""
                className="block h-[150px] w-full rounded-[var(--radius-nav)] object-cover"
              />
            )}
            <input
              ref={fileInput}
              type="file"
              accept=".png,.jpg,.jpeg,.webp,.gif"
              hidden
              onChange={(e) => void choose(e.target.files?.[0])}
            />
            {uploading ? (
              <AppBusyLabel label={t.diaryUploading} />
            ) : (
              <div>
                <Button tone="secondary" icon={Upload} onClick={() => fileInput.current?.click()}>
                  {imageKey ? t.diaryChangeImage : t.diaryChooseImage}
                </Button>
              </div>
            )}
            <p className="text-[12px] text-text-muted">{t.diaryImageFormats}</p>
          </div>
        ) : kind === 'link' ? (
          <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
            <span>{t.diaryKinds.link}</span>
            <input
              type="url"
              data-field="entry-body"
              value={body}
              placeholder="https://…"
              onChange={(e) => setBody(e.target.value)}
              className={FIELD}
            />
          </label>
        ) : (
          <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
            <span>{t.diaryKinds.text}</span>
            <textarea
              data-field="entry-body"
              rows={6}
              value={body}
              placeholder={t.diaryBodyHint}
              onChange={(e) => setBody(e.target.value)}
              className={`${FIELD} resize-y`}
            />
          </label>
        )}
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
      <div className="max-w-[620px] pr-3" data-field="background">
        <MarkdownText text={text} className="text-[15px] leading-[1.65] text-on-surface" />
      </div>
    </ScrollArea>
  );
}
