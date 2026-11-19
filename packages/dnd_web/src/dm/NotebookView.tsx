import { useEffect, useLayoutEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { EllipsisVertical, Eye, FolderInput, Lock, Pencil, Plus, Search, Trash2, X } from 'lucide-react';
import {
  queryKeys,
  useCampaignChapters,
  useCampaignNotebook,
  useSheetCatalog,
} from '../api/queries';
import {
  assignEntryChapter,
  createNote,
  deleteNote,
  fetchCampaignNotebook,
  saveEntryOrder,
  saveNote,
  type DmCampaign,
  type DmChapter,
  type DmNote,
} from '../api/client';
import { movedOrder } from '../dashboard/roster';
import { useHoldDrag } from '../ui/holdDrag';
import { useListTransition } from '../ui/listTransition';
import { Toast, type ToastTone } from '../ui/primitives';
import { MoveToChapterDialog } from './MoveToChapterDialog';
import { useLang, useTexts } from '../i18n/context';
import { Button, ButtonLink } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { cx } from '../ui/cx';
import { MarkdownText } from '../ui/MarkdownText';
import { withMentions } from '../ui/mentions';
import { dmCampaignHref } from '../router';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Tooltip } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { stateLabel, stateOf } from './campaigns';
import { CampaignMenu } from './CampaignMenu';
import { DmHeader } from './DmHeader';
import { NoteEditorDialog } from './NoteEditorDialog';
import { useMentionReader } from './mentions/reader';
import { buildEntries, inChapterOrder, matches, stamp, type Entry, type EntryKind } from './notebook';
import { prefersReducedMotion } from '../ui/motion';

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
 * El Cuaderno de la campaña: las notas del DM, los combates cerrados y las
 * subidas de nivel, por capítulo. Una pill por capítulo (más «Sin capítulo»
 * para lo que no cuelga de ninguno) y un buscador. Solo las notas se escriben,
 * editan y borran; lo demás lo registra la app. Se abre en el capítulo de
 * `?capitulo=` (el enlace «Ver en el Cuaderno» de Capítulos). Al guardar una
 * nota la vista pasa a su capítulo, o una nota escrita en otro parecería
 * perdida. Las menciones `@Nombre` de una nota y quienes pelearon en un combate
 * enlazan a su ficha. Es del DM: ninguna cuenta de jugador recibe nada de esto
 * (`modo-dm.md`).
 */
export function NotebookView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const lang = useLang();
  const notebook = useCampaignNotebook(campaign.id);
  const chapters = useCampaignChapters(campaign.id);
  const catalog = useSheetCatalog(lang);
  // El buscador escribe en `query` al instante y la lista filtra con
  // `listQuery`, que cambia dentro de la transición (como en el dashboard: un
  // input controlado que esperara al cuadro siguiente perdería teclas).
  const [query, setQuery] = useState('');
  const [listQuery, setListQuery] = useState('');
  const [picked, setPicked] = useState<string | null>(() => new URLSearchParams(window.location.search).get('capitulo'));
  const client = useQueryClient();
  const [editing, setEditing] = useState<DmNote | 'new' | null>(null);
  const [deleting, setDeleting] = useState<DmNote | null>(null);
  const [moving, setMoving] = useState<Entry | null>(null);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string } | null>(null);
  const notify = (tone: ToastTone, message: string) => setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone, message }));
  // A quiénes enlaza una mención: la mesa, los PNJ y los escenarios (ver
  // `useMentionTargets`). Tocar una abre el panel lateral sin dejar el
  // Cuaderno. Si no cargan, las menciones se leen como texto.
  const { mentions, panel, readingClass } = useMentionReader(campaign.id);

  const entries = useMemo(
    () =>
      notebook.data && chapters.data && catalog.data
        ? buildEntries(notebook.data, chapters.data, t, catalog.data, (name) => (mentions.names.includes(name) ? `@${name}` : name))
        : null,
    [notebook.data, chapters.data, catalog.data, t, mentions],
  );

  const chapterList = chapters.data ?? [];
  // Se abre en el capítulo en marcha; sin uno, en el primero.
  const initial = chapterList.find((c) => c.state === 'active') ?? chapterList[0];
  const current = picked ?? initial?.id ?? LOOSE;
  const searching = listQuery.trim() !== '';
  const visible = (entries ?? []).filter((e) => matches(e, listQuery));
  const currentChapter = chapterList.find((c) => c.id === current);
  const shown = inChapterOrder(
    visible.filter((e) => (e.chapterId ?? LOOSE) === current),
    currentChapter?.entryOrder,
  );
  // Se ordena dentro de un capítulo y sin búsqueda: con la lista filtrada,
  // soltar «entre» dos resultados no dice dónde queda respecto de lo oculto
  // (la misma regla del Dashboard). «Sin capítulo» es una bandeja para
  // vaciar, y va por fecha.
  const arrangeable = currentChapter !== undefined && !searching && shown.length > 1;
  const ids = arrangeable ? shown.map((e) => e.orderKey) : [];

  // Cambiar de capítulo, buscar, guardar, borrar o mover anima la lista
  // (`useListTransition`). Se le pasan las claves y no `shown`, que es otro
  // arreglo en cada dibujo y soltaría la transición antes de tiempo. Arrastrar
  // no pasa por acá: `useHoldDrag` ya anima lo suyo.
  const animateList = useListTransition(shown.map((e) => e.key).join('\n'));
  const search = (value: string) => {
    setQuery(value);
    animateList(() => setListQuery(value));
  };
  const pick = (id: string) => animateList(() => setPicked(id));
  // La red queda afuera de la transición, que congela la pantalla: el
  // Cuaderno se relee antes y la caché cambia adentro.
  const notebookKey = queryKeys.campaignNotebook(campaign.id);
  const reloadAnimated = async (alsoInside?: () => void) => {
    await client.cancelQueries({ queryKey: notebookKey });
    const fresh = await fetchCampaignNotebook(campaign.id, new AbortController().signal);
    animateList(() => {
      client.setQueryData(notebookKey, fresh);
      alsoInside?.();
    });
  };

  // Borrar una nota o mover una entrada se lleva su ⋮ (la entrada deja la
  // vista): el foco va al título de la sección. Una nota guardada lo recibe
  // ella, y la vista baja hasta donde quedó. Se mueve cuando la lista nueva
  // se dibujó y el diálogo terminó de devolver el foco a su botón.
  const [focusTarget, setFocusTarget] = useState<string | null>(null);
  useEffect(() => {
    if (!focusTarget) return;
    const id = window.setTimeout(() => {
      const el = document.querySelector<HTMLElement>(focusTarget);
      if (!el) return;
      const reduce = prefersReducedMotion();
      el.scrollIntoView({ block: 'nearest', behavior: reduce ? 'auto' : 'smooth' });
      el.focus({ preventScroll: true });
      setFocusTarget(null);
    }, 0);
    return () => window.clearTimeout(id);
  }, [focusTarget, entries]);

  const moveEntry = (from: string, to: string) => {
    if (!currentChapter) return;
    const chapterId = currentChapter.id;
    const order = movedOrder(ids, from, to);
    void (async () => {
      const key = queryKeys.campaignChapters(campaign.id);
      await client.cancelQueries({ queryKey: key });
      client.setQueryData<DmChapter[]>(key, (old) => old?.map((c) => (c.id === chapterId ? { ...c, entryOrder: order } : c)));
      try {
        await saveEntryOrder(campaign.id, chapterId, order);
      } catch {
        notify('error', t.dmOrderSaveError);
        void client.invalidateQueries({ queryKey: key });
      }
    })();
  };
  // La página queda fija y solo las entradas scrollean: con un capítulo largo,
  // bajar se llevaba las pills, el buscador y el objetivo. El alto se cuenta
  // desde donde empieza la lista, que cambia con el objetivo del capítulo y con
  // el ancho (las pills se parten); los 24 px son el relleno de abajo de `main`,
  // como en el Códice (`useListFitsViewport`).
  const listRef = useRef<HTMLDivElement>(null);
  const [listTop, setListTop] = useState(0);
  const hasList = shown.length > 0;
  useLayoutEffect(() => {
    const el = listRef.current;
    if (!el) return;
    const measure = () => setListTop(el.getBoundingClientRect().top + window.scrollY);
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [hasList, current, searching, currentChapter?.summary, chapters.data, entries === null]);

  const reorder = useHoldDrag({ ids, axis: 'y', scroller: listRef, canDrop: () => arrangeable, onMove: moveEntry });

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
    body = (
      <AppEmptyState
        kind="empty"
        message={t.dmNotebookNeedsChapter}
        actions={
          <ButtonLink internal tone="secondary" href={dmCampaignHref(campaign.id, 'capitulos')}>
            {t.dmGoToChapters}
          </ButtonLink>
        }
      />
    );
  } else {
    const pills = [
      ...chapters.data.map((c) => ({ id: c.id, label: c.name })),
      { id: LOOSE, label: t.dmNoChapter },
    ];
    const countIn = (id: string) => visible.filter((e) => (e.chapterId ?? LOOSE) === id).length;
    const count = (k: EntryKind) => shown.filter((e) => e.kind === k).length;
    const now = Date.now();

    body = (
      <>
        <div className="flex flex-wrap items-center gap-2.5">
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
                  onClick={() => pick(p.id)}
                  className={cx(
                    'pick rounded-[var(--radius-pill)] border px-3.5 py-1.5 text-[13px]',
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
              onChange={(e) => search(e.target.value)}
              placeholder={t.dmSearchNotebook}
              className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-8 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
            />
            {query !== '' && (
              <Tooltip content={t.rosterClearSearch}>
                <button
                  type="button"
                  aria-label={t.rosterClearSearch}
                  onClick={() => search('')}
                  className="absolute inset-y-0 right-1 flex w-7 items-center justify-center text-text-muted hover:text-on-surface"
                >
                  <X size={14} aria-hidden="true" />
                </button>
              </Tooltip>
            )}
          </div>
        </div>

        {/* El objetivo del capítulo abierto, con sus menciones: lo que la mesa
            tiene que lograr se lee junto a lo que va pasando. */}
        {currentChapter?.summary?.trim() && !searching && (
          <section aria-labelledby="notebook-goal" className="flex flex-col gap-1.5">
            <h2 id="notebook-goal" className="font-display text-[20px] break-words text-on-surface">{currentChapter.name}</h2>
            <p className="text-[13.5px] leading-[1.55] whitespace-pre-line text-on-surface-variant" data-field="chapter-goal">
              {withMentions(currentChapter.summary, mentions)}
            </p>
          </section>
        )}

        <p className="flex flex-wrap gap-x-[18px] text-[12.5px] text-text-muted" data-field="counts">
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
            <div>
              <AppEmptyState kind="no-match" message={t.dmNoEntriesMatch} />
            </div>
          )
        ) : (
          // El relleno de 4 px deja ver el contorno del destino al arrastrar,
          // que `overflow` recortaría. `min-h-60`: en un teléfono la cabecera
          // ocupa casi todo, y una lista de dos dedos no se puede leer.
          <div
            ref={listRef}
            data-field="notebook-list"
            className="-m-1 min-h-60 overflow-y-auto p-1"
            style={{ maxHeight: `calc(100dvh - ${listTop}px - 24px)` }}
          >
            <ol aria-label={pills.find((p) => p.id === current)?.label} className="flex flex-col gap-2.5">
              {shown.map((e) => (
                <li
                  key={e.key}
                  data-entry={e.kind}
                  data-entry-key={e.key}
                  data-vt-card
                  className={cx(
                    'card border-l-[3px] px-[18px] py-3.5',
                    ACCENT[e.kind].border,
                    // Sostenerla no puede seleccionar el texto ni abrir el menú
                    // del teléfono. Las clases del arrastre son las de la Mesa.
                    arrangeable && 'select-none [-webkit-touch-callout:none]',
                    reorder.dragging === e.orderKey &&
                      (reorder.animated ? 'cursor-grabbing border-gold [&_*]:cursor-grabbing' : 'opacity-40'),
                    reorder.over === e.orderKey && !reorder.animated && 'outline-2 outline-offset-1 outline-gold',
                  )}
                  {...(arrangeable ? reorder.item(e.orderKey) : {})}
                  // Después del `item`, que trae su `style` para el arrastre. El
                  // nombre identifica la entrada en las transiciones de la lista.
                  style={{
                    viewTransitionName: `nb-${e.key.replace(/[^\w-]/g, '_')}`,
                    ...(arrangeable ? (reorder.item(e.orderKey).style as CSSProperties | undefined) : undefined),
                  }}
                >
                  <div className="flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
                    <span className={cx('text-[11.5px] font-medium', ACCENT[e.kind].text)}>
                      {e.kind === 'note' ? t.dmEntryNote : e.kind === 'fight' ? t.dmEntryFight : t.dmEntryLevelUp}
                    </span>
                    {/* `tabIndex`: el foco viene acá al guardar la nota. */}
                    <h2 tabIndex={-1} className="font-display min-w-0 flex-1 text-[17px] break-words text-on-surface outline-none">
                      {e.title}
                    </h2>
                    {e.note && (
                      // Quién la ve: solo las notas llevan visibilidad; los
                      // combates y las subidas de nivel los escribe la app.
                      <span
                        data-visibility={e.note.shared ? 'shared' : 'private'}
                        className={cx(
                          'inline-flex items-center gap-[5px] rounded-[var(--radius-pill)] border px-2.5 py-0.5 text-[11.5px]',
                          e.note.shared ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-text-muted',
                        )}
                      >
                        {e.note.shared ? <Eye size={13} aria-hidden="true" /> : <Lock size={13} aria-hidden="true" />}
                        {e.note.shared ? t.dmNoteDmAndPlayers : t.dmNoteDmOnly}
                      </span>
                    )}
                    <span className="text-[12px] text-text-muted tabular-nums">
                      {[stamp(e.at, now, t), e.rounds !== undefined && t.roundsCount(e.rounds)].filter(Boolean).join(' · ')}
                    </span>
                    {e.note && (
                      // Solo las notas se tocan: lo demás lo escribió la app.
                      <DropdownMenu>
                        <Tooltip content={t.dmNoteActions}>
                          <DropdownMenuTrigger asChild>
                            <button
                              type="button"
                              aria-label={t.dmNoteActions}
                              data-action="note-actions"
                              className="-my-2 -mr-2 inline-flex size-10 shrink-0 items-center justify-center self-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
                            >
                              <EllipsisVertical size={18} aria-hidden="true" />
                            </button>
                          </DropdownMenuTrigger>
                        </Tooltip>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onSelect={() => setEditing(e.note!)}>
                            <Pencil size={15} aria-hidden="true" className="text-text-muted" />
                            {t.commonEdit}
                          </DropdownMenuItem>
                          <DropdownMenuItem onSelect={() => setDeleting(e.note!)} className="text-crimson">
                            <Trash2 size={15} aria-hidden="true" />
                            {t.commonDelete}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    )}
                    {!e.note && e.chapterId === null && e.entryId !== '' && chapterList.length > 0 && (
                      // Lo suelto se cuelga de un capítulo; lo que ya tiene uno
                      // no se mueve (el servidor tampoco lo acepta).
                      <DropdownMenu>
                        <Tooltip content={e.kind === 'fight' ? t.dmFightActions : t.dmLevelUpActions}>
                          <DropdownMenuTrigger asChild>
                            <button
                              type="button"
                              aria-label={e.kind === 'fight' ? t.dmFightActions : t.dmLevelUpActions}
                              data-action="entry-actions"
                              className="-my-2 -mr-2 inline-flex size-10 shrink-0 items-center justify-center self-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
                            >
                              <EllipsisVertical size={18} aria-hidden="true" />
                            </button>
                          </DropdownMenuTrigger>
                        </Tooltip>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onSelect={() => setMoving(e)}>
                            <FolderInput size={15} aria-hidden="true" className="text-text-muted" />
                            {t.dmMoveToChapterItem}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    )}
                  </div>
                  <div className="mt-1.5 text-[13.5px] leading-relaxed text-on-surface-variant">
                    {e.markdown ? (
                      <MarkdownText text={e.body} mentions={mentions} />
                    ) : (
                      e.body.split('\n\n').map((p, i) => (
                        <p key={i} className="mb-2 last:mb-0">
                          {withMentions(p, mentions)}
                        </p>
                      ))
                    )}
                  </div>
                </li>
              ))}
            </ol>
          </div>
        )}
      </>
    );
  }

  // La nota nace en el capítulo en marcha o, si no hay, en el primero.
  const bornIn = initial;

  const submit = async (note: DmNote) => {
    if (editing === 'new') await createNote(campaign.id, note);
    else await saveNote(campaign.id, note);
    await reloadAnimated(() => setPicked(note.chapterId));
    setFocusTarget(`[data-entry-key="${CSS.escape(`note-${note.id}`)}"] h2`);
  };

  return (
    <div className={cx('flex flex-col gap-5', readingClass)}>
      <DmHeader
        title={t.dmSectionNotebook}
        kicker={state}
        actions={
          <>
            <CampaignMenu campaign={campaign} />
            <Button
              icon={Plus}
              data-action="write-note"
              disabled={!bornIn}
              onClick={() => setEditing('new')}
              className="min-h-11"
            >
              {t.dmWriteNote}
            </Button>
          </>
        }
      />
      <p className="-mt-2 text-[13px] text-text-muted">{campaign.name}</p>
      {body}
      {editing && bornIn && (
        <NoteEditorDialog
          title={editing === 'new' ? t.dmWriteNote : t.dmEditNote}
          campaignId={campaign.id}
          initial={editing === 'new' ? { id: `note-${Date.now()}`, chapterId: bornIn.id, title: '' } : editing}
          chapters={chapterList}
          onSubmit={submit}
          onClose={() => setEditing(null)}
        />
      )}
      {deleting && (
        <ConfirmDialog
          title={t.dmDeleteNote}
          body={t.dmDeleteNoteBody(deleting.title)}
          confirmLabel={t.dmDeleteNote}
          errorText={t.dmNoteDeleteError}
          onConfirm={async () => {
            await deleteNote(campaign.id, deleting.id);
            await reloadAnimated();
            setFocusTarget('[data-dm-title]');
          }}
          onClose={() => setDeleting(null)}
        />
      )}
      {moving && (
        <MoveToChapterDialog
          entryTitle={moving.title}
          chapters={chapterList}
          onMove={async (chapterId) => {
            await assignEntryChapter(campaign.id, moving.kind === 'fight' ? 'fight' : 'levelUp', moving.entryId, chapterId);
            // Llega al final del capítulo: no figura en su orden. Se queda en
            // «Sin capítulo» para seguir vaciando la bandeja.
            await reloadAnimated();
            setFocusTarget('[data-dm-title]');
          }}
          onClose={() => setMoving(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} open onOpenChange={(open) => !open && setToast(null)} />}
      {panel}
    </div>
  );
}
