import { useMemo, useState } from 'react';
import { ExternalLink, Feather, Image as ImageIcon, Link2, NotebookText, ScrollText, type LucideIcon } from 'lucide-react';
import type { DiaryEntry } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Card } from '../ui/Card';
import { MarkdownText } from '../ui/MarkdownText';
import { portraitUrl } from '../ui/portrait';
import { AppEmptyState } from '../ui/status';
import type { SheetModel } from './model';

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
      <Card id="background" title={t.diaryBackground} icon={ScrollText}>
        {background ? (
          // Medida de lectura: unos 66 caracteres, como el cuerpo de un
          // diálogo; la prosa estirada a todo el ancho no se lee.
          <MarkdownText text={background} className="max-w-[620px] text-[15px] leading-[1.65] text-on-surface" />
        ) : (
          <div className="max-w-[620px]">
            <p className="font-display text-[16px] text-on-surface">{t.diaryUnknownOrigin}</p>
            <p className="mt-1 text-on-surface-variant">{t.diaryUnknownOriginBody(character.name)}</p>
          </div>
        )}
      </Card>
      <DiaryEntries entries={character.diary ?? []} title={t.diaryEntries} emptyMessage={t.diaryEmpty(character.name)} />
    </div>
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
