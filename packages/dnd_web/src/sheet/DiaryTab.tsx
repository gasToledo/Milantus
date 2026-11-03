import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Check,
  Download,
  ExternalLink,
  Feather,
  Image as ImageIcon,
  Link2,
  NotebookText,
  Pencil,
  ScrollText,
  TriangleAlert,
  Upload,
  type LucideIcon,
} from 'lucide-react';
import type { DiaryEntry } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { MarkdownText } from '../ui/MarkdownText';
import { ScrollArea, Tooltip } from '../ui/primitives';
import { portraitUrl } from '../ui/portrait';
import { AppEmptyState } from '../ui/status';
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
 * las acomodó, no por fecha. Solo lectura: escribir sigue en Flutter.
 *
 * Nada de acá es una regla: no llega a `ComputedSheet` ni cambia un número.
 */
export function DiaryTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character } = model;
  const background = character.background?.trim() ?? '';

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
      <DiaryEntries entries={character.diary ?? []} title={t.diaryEntries} emptyMessage={t.diaryEmpty(character.name)} />
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

/**
 * Las entradas del Diario: tarjetas en columnas que se abren en un diálogo.
 * Son las mismas que usan las notas de un PNJ, como en Flutter
 * (`DiaryEntriesCard`): un segundo molde obligaría a mantener dos.
 */
export function DiaryEntries({
  entries,
  title,
  emptyMessage,
  columns = '[columns:3_280px]',
}: {
  entries: DiaryEntry[];
  title: string;
  emptyMessage: string;
  /** Cuántas columnas y de qué ancho mínimo: una columna lateral pide menos. */
  columns?: string;
}) {
  const t = useTexts();
  const lang = useLang();
  const [open, setOpen] = useState<DiaryEntry | null>(null);
  const date = useMemo(() => new Intl.DateTimeFormat(lang, { day: 'numeric', month: 'long', year: 'numeric' }), [lang]);
  const when = (e: DiaryEntry) => {
    // Sin fecha (la entrada que salió de las notas viejas) no se inventa una.
    const iso = e.updatedAt ?? e.createdAt;
    const d = iso ? new Date(iso) : null;
    return d && !Number.isNaN(d.getTime()) ? date.format(d) : null;
  };

  return (
    <section aria-labelledby="h-entries" data-card="entries">
      <div className="mx-0.5 mb-2.5 flex items-center gap-2">
        <h2 id="h-entries" className="flex flex-1 items-center gap-2">
          <Feather size={18} aria-hidden="true" className="shrink-0 text-gold" />
          <span className="font-display text-[16px] text-on-surface">{title}</span>
        </h2>
        {entries.length > 0 && <span className="text-[12px] text-text-muted tabular-nums">{entries.length}</span>}
      </div>
      {entries.length === 0 ? (
        <AppEmptyState kind="empty" message={emptyMessage} />
      ) : (
        // Columnas y no grilla: cada tarjeta mide lo que su contenido, sin
        // filas igualadas a la más alta.
        <ul className={`[column-gap:14px] ${columns}`}>
          {entries.map((e) => (
            <li key={e.entryId} className="mb-3.5 break-inside-avoid">
              <EntryCard entry={e} date={when(e)} onOpen={() => setOpen(e)} />
            </li>
          ))}
        </ul>
      )}

      {open && (
        <AppDialog
          open
          onOpenChange={(v) => !v && setOpen(null)}
          title={open.title}
          icon={KIND_ICON[kindOf(open)]}
          actions={[{ label: t.close, primary: true }]}
        >
          <EntryBody entry={open} />
        </AppDialog>
      )}
    </section>
  );
}

function EntryCard({ entry, date, onOpen }: { entry: DiaryEntry; date: string | null; onOpen: () => void }) {
  const t = useTexts();
  const kind = kindOf(entry);
  const Icon = KIND_ICON[kind];
  return (
    <button
      type="button"
      onClick={onOpen}
      className="card block w-full overflow-hidden text-left hover:border-gold"
      data-entry={entry.entryId}
    >
      {kind === 'image' && entry.imageKey && (
        <img
          src={imageUrl(entry.imageKey)}
          alt={t.diaryImageAlt(entry.title)}
          loading="lazy"
          className="block max-h-[220px] w-full border-b border-hairline bg-plaque object-cover"
        />
      )}
      <span className="block px-[15px] pt-[13px] pb-3.5">
        <span className="flex items-center gap-2">
          <Icon size={15} aria-hidden="true" className="shrink-0 text-gold" />
          <span className="sr-only">{t.diaryKinds[kind]}: </span>
          <span className="min-w-0 flex-1 text-[14.5px] font-medium break-words text-on-surface">{entry.title}</span>
        </span>
        {kind !== 'image' && entry.body && (
          <span className="mt-[7px] line-clamp-4 block text-[13px] leading-[1.5] break-words text-on-surface-variant">
            {entry.body}
          </span>
        )}
        {date && <span className="mt-[9px] block text-[11.5px] text-text-muted">{date}</span>}
      </span>
    </button>
  );
}

/** La entrada completa, en el diálogo. */
function EntryBody({ entry }: { entry: DiaryEntry }) {
  const t = useTexts();
  const kind = kindOf(entry);
  if (kind === 'image') {
    return entry.imageKey ? (
      <img src={imageUrl(entry.imageKey)} alt={t.diaryImageAlt(entry.title)} className="w-full rounded-[var(--radius-card)]" />
    ) : null;
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
