import { useMemo, useState } from 'react';
import { Search, X } from 'lucide-react';
import { useCampaignChapters, useCampaignNotebook, useSheetCatalog } from '../api/queries';
import type { DmCampaign } from '../api/client';
import { useLang, useTexts } from '../i18n/context';
import { cx } from '../ui/cx';
import { MarkdownText } from '../ui/MarkdownText';
import { Tooltip } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { stateLabel, stateOf } from './campaigns';
import { DmHeader } from './DmHeader';
import { buildEntries, matches, stamp, type EntryKind } from './notebook';

/** Sin capítulo: el valor de la pill que junta lo que no cuelga de ninguno. */
const LOOSE = '';

/** El color del borde izquierdo de cada tipo de entrada: oro la nota, carmesí
 *  el combate, verde la subida de nivel. */
const ACCENT: Record<EntryKind, { border: string; text: string }> = {
  note: { border: 'border-l-gold', text: 'text-gold' },
  fight: { border: 'border-l-crimson', text: 'text-crimson' },
  levelUp: { border: 'border-l-verdant', text: 'text-verdant' },
};

/**
 * El Cuaderno de la campaña, de solo lectura: las notas del DM, los combates
 * cerrados y las subidas de nivel, por capítulo. Una pill por capítulo (más
 * «Sin capítulo» para lo que no cuelga de ninguno) y un buscador. Escribir,
 * editar o borrar una nota vive en Flutter; también las menciones `@Nombre`,
 * que acá se leen como texto. Es del DM: ninguna cuenta de jugador recibe nada
 * de esto (`modo-dm.md`).
 */
export function NotebookView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const lang = useLang();
  const notebook = useCampaignNotebook(campaign.id);
  const chapters = useCampaignChapters(campaign.id);
  const catalog = useSheetCatalog(lang);
  const [query, setQuery] = useState('');
  const [picked, setPicked] = useState<string | null>(null);

  const entries = useMemo(
    () =>
      notebook.data && chapters.data && catalog.data
        ? buildEntries(notebook.data, chapters.data, t, catalog.data)
        : null,
    [notebook.data, chapters.data, catalog.data, t],
  );

  const failed = [notebook, chapters, ...catalog.queries].filter((q) => q.isError);
  const state = stateLabel(t, stateOf(campaign));
  let body;
  if (failed.length > 0) {
    body = (
      <AppErrorView title={t.dmNotebookReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
    );
  } else if (!entries || !chapters.data) {
    body = <AppBusyLabel label={t.dmNotebookLoading} />;
  } else if (chapters.data.length === 0) {
    // Sin capítulos no hay dónde colgar nada: el cuaderno se ordena por ellos.
    body = <AppEmptyState kind="empty" message={t.dmNotebookNeedsChapter} />;
  } else {
    // Se abre en el capítulo en marcha; sin uno, en el primero.
    const initial = chapters.data.find((c) => c.state === 'active') ?? chapters.data[0]!;
    const current = picked ?? initial.id;
    const searching = query.trim() !== '';
    const visible = entries.filter((e) => matches(e, query));
    const pills = [
      ...chapters.data.map((c) => ({ id: c.id, label: c.name })),
      { id: LOOSE, label: t.dmNoChapter },
    ];
    const countIn = (id: string) => visible.filter((e) => (e.chapterId ?? LOOSE) === id).length;
    const shown = visible.filter((e) => (e.chapterId ?? LOOSE) === current);
    const count = (k: EntryKind) => shown.filter((e) => e.kind === k).length;
    const now = Date.now();

    body = (
      <>
        <div className="flex max-w-[900px] flex-wrap items-center gap-2.5">
          <div role="group" aria-label={t.dmNotebookChapterGroup} className="flex min-w-[min(300px,100%)] flex-[1_1_300px] flex-wrap gap-1.5">
            {pills.map((p) => {
              const on = p.id === current;
              const n = countIn(p.id);
              return (
                <button
                  key={p.id}
                  type="button"
                  aria-pressed={on}
                  data-chapter={p.id === LOOSE ? 'loose' : p.id}
                  onClick={() => setPicked(p.id)}
                  className={cx(
                    'rounded-[var(--radius-pill)] border px-3.5 py-1.5 text-[13px]',
                    on ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface-variant hover:text-on-surface',
                    // Buscando, una pill sin coincidencias se apaga: no hay nada ahí.
                    searching && n === 0 && !on && 'opacity-50',
                  )}
                >
                  {p.label}
                  {searching && <span className="num ml-1.5 text-[12px] font-normal">{n}</span>}
                </button>
              );
            })}
          </div>
          <div role="search" className="relative min-w-[min(180px,100%)] max-w-[260px] flex-[1_1_180px]">
            <label htmlFor="notebook-search" className="sr-only">
              {t.dmSearchNotebook}
            </label>
            <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
            <input
              id="notebook-search"
              type="search"
              autoComplete="off"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t.dmSearchNotebook}
              className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-8 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
            />
            {query !== '' && (
              <Tooltip content={t.rosterClearSearch}>
                <button
                  type="button"
                  aria-label={t.rosterClearSearch}
                  onClick={() => setQuery('')}
                  className="absolute inset-y-0 right-1 flex w-7 items-center justify-center text-text-muted hover:text-on-surface"
                >
                  <X size={14} aria-hidden="true" />
                </button>
              </Tooltip>
            )}
          </div>
        </div>

        <p className="flex max-w-[900px] flex-wrap gap-x-[18px] text-[12.5px] text-text-muted" data-field="counts">
          {shown.length === 0 ? (
            <span>{t.dmNoEntries}</span>
          ) : (
            <>
              {count('note') > 0 && <span>{t.dmNotesCount(count('note'))}</span>}
              {count('fight') > 0 && <span>{t.dmFightsCount(count('fight'))}</span>}
              {count('levelUp') > 0 && <span>{t.dmLevelUpsCount(count('levelUp'))}</span>}
            </>
          )}
        </p>

        {shown.length === 0 ? (
          searching && (
            <div className="max-w-[900px]">
              <AppEmptyState kind="no-match" message={t.dmNoEntriesMatch} />
            </div>
          )
        ) : (
          <ol aria-label={pills.find((p) => p.id === current)?.label} className="flex max-w-[900px] flex-col gap-2.5">
            {shown.map((e) => (
              <li
                key={e.key}
                data-entry={e.kind}
                className={cx('card border-l-[3px] px-[18px] py-3.5', ACCENT[e.kind].border)}
              >
                <div className="flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
                  <span className={cx('text-[11.5px] font-medium', ACCENT[e.kind].text)}>
                    {e.kind === 'note' ? t.dmEntryNote : e.kind === 'fight' ? t.dmEntryFight : t.dmEntryLevelUp}
                  </span>
                  <h2 className="font-display min-w-0 flex-1 text-[17px] break-words text-on-surface">{e.title}</h2>
                  <span className="text-[12px] text-text-muted tabular-nums">
                    {[stamp(e.at, now, t), e.rounds !== undefined && t.roundsCount(e.rounds)].filter(Boolean).join(' · ')}
                  </span>
                </div>
                <div className="mt-1.5 text-[13.5px] leading-relaxed text-on-surface-variant">
                  {e.markdown ? (
                    <MarkdownText text={e.body} />
                  ) : (
                    e.body.split('\n\n').map((p, i) => (
                      <p key={i} className="mb-2 last:mb-0">
                        {p}
                      </p>
                    ))
                  )}
                </div>
              </li>
            ))}
          </ol>
        )}
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmSectionNotebook} kicker={state} />
      <p className="-mt-2 text-[13px] text-text-muted">{campaign.name}</p>
      {body}
    </div>
  );
}
