import { useLayoutEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { CheckCheck, EllipsisVertical, Eye, FolderInput, Lock, Pencil, Plus, Search, Trash2, X } from 'lucide-react';
import {
  queryKeys,
  useCampaignChapters,
  useCampaignNotebook,
  useChapterScript,
  useSheetCatalog,
} from '../api/queries';
import {
  assignEntryChapter,
  createNote,
  deleteNote,
  fetchCampaignNotebook,
  saveChapter,
  saveEntryOrder,
  saveNote,
  type DmCampaign,
  type DmChapter,
  type DmNote,
} from '../api/client';
import { movedOrder } from '../dashboard/roster';
import { useHoldDrag } from '../ui/holdDrag';
import { useDeferredFocus } from '../ui/focus';
import { useListTransition, vtName } from '../ui/listTransition';
import { Toast, type ToastTone } from '../ui/primitives';
import { MoveToChapterDialog } from './MoveToChapterDialog';
import { useLang, useTexts } from '../i18n/context';
import { Button, ButtonLink } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { cx } from '../ui/cx';
import { MarkdownText } from '../ui/MarkdownText';
import { withMentions } from '../ui/mentions';
import { dmCampaignHref, dmChapterHref, Link, navigate } from '../router';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Tooltip } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { ChapterEditorDialog } from './ChapterEditorDialog';
import { CloseChapterDialog } from './CloseChapterDialog';
import { DmHeader } from './DmHeader';
import { NoteEditorDialog } from './NoteEditorDialog';
import { useMentionReader } from './mentions/reader';
import { buildEntries, groupByMilestone, inChapterOrder, matches, stamp, type Entry, type EntryKind, type MilestoneGroup } from './notebook';
import { milestoneLabels } from './script/labels';

/** El color del borde izquierdo de cada tipo de entrada: oro la nota, carmesí
 *  el combate, verde la subida de nivel. */
const ACCENT: Record<EntryKind, { border: string; text: string }> = {
  note: { border: 'border-l-gold', text: 'text-gold' },
  fight: { border: 'border-l-crimson', text: 'text-crimson' },
  levelUp: { border: 'border-l-verdant', text: 'text-verdant' },
};

/**
 * El Registro de un capítulo: las notas del DM, los combates cerrados y las
 * subidas de nivel, agrupados por el hito del guion en que pasaron (sin guion,
 * una sola lista). Con `chapterId: null` es «Sin capítulo», la bandeja de lo
 * que quedó suelto. Solo las notas se escriben, editan y borran; lo demás lo
 * registra la app. Si al guardar una nota el DM la pasó a otro capítulo, la
 * página va a ese capítulo, o parecería perdida. Las menciones `@Nombre` de una
 * nota y quienes pelearon en un combate enlazan a su ficha. Es del DM: ninguna
 * cuenta de jugador recibe nada de esto (`modo-dm.md`).
 */
export function ChapterLogView({ campaign, chapterId }: { campaign: DmCampaign; chapterId: string | null }) {
  const t = useTexts();
  const lang = useLang();
  const notebook = useCampaignNotebook(campaign.id);
  const chapters = useCampaignChapters(campaign.id);
  const chapterScript = useChapterScript(campaign.id, chapterId);
  const catalog = useSheetCatalog(lang);
  // El buscador escribe en `query` al instante y la lista filtra con
  // `listQuery`, que cambia dentro de la transición (como en el dashboard: un
  // input controlado que esperara al cuadro siguiente perdería teclas).
  const [query, setQuery] = useState('');
  const [listQuery, setListQuery] = useState('');
  const client = useQueryClient();
  const [editing, setEditing] = useState<DmNote | 'new' | null>(null);
  const [deleting, setDeleting] = useState<DmNote | null>(null);
  const [moving, setMoving] = useState<Entry | null>(null);
  const [editingChapter, setEditingChapter] = useState(false);
  const [closing, setClosing] = useState(false);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string } | null>(null);
  const notify = (tone: ToastTone, message: string) => setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone, message }));
  // A quiénes enlaza una mención: la mesa, los PNJ y los escenarios (ver
  // `useMentionTargets`). Tocar una abre el panel lateral sin dejar el
  // Registro. Si no cargan, las menciones se leen como texto.
  const { mentions, panel, readingClass } = useMentionReader(campaign.id);

  const entries = useMemo(
    () =>
      notebook.data && chapters.data && catalog.data
        ? buildEntries(notebook.data, chapters.data, t, catalog.data, (name) => (mentions.names.includes(name) ? `@${name}` : name))
        : null,
    [notebook.data, chapters.data, catalog.data, t, mentions],
  );

  const chapterList = chapters.data ?? [];
  const chapter = chapterList.find((c) => c.id === chapterId);
  const missing = chapterId !== null && chapters.data !== undefined && !chapter;
  const searching = listQuery.trim() !== '';
  const script = chapterScript.data?.script ?? null;
  const activeId = chapterScript.data?.view?.activeId ?? null;
  const inChapter = inChapterOrder(
    (entries ?? []).filter((e) => e.chapterId === chapterId && matches(e, listQuery)),
    chapter?.entryOrder,
  );
  // Sin guion es la lista de siempre: un solo grupo sin separador.
  const groups: MilestoneGroup[] = script
    ? groupByMilestone(inChapter, script, milestoneLabels(script))
    : [{ id: null, heading: null, entries: inChapter }];
  const shown = groups.flatMap((g) => g.entries);
  const groupOf = new Map(groups.flatMap((g) => g.entries.map((e) => [e.orderKey, g.id] as const)));
  // Se ordena dentro de un capítulo y sin búsqueda: con la lista filtrada,
  // soltar «entre» dos resultados no dice dónde queda respecto de lo oculto
  // (la misma regla del Dashboard). «Sin capítulo» es una bandeja para
  // vaciar, y va por fecha.
  const arrangeable = chapter !== undefined && !searching && shown.length > 1;
  const ids = arrangeable ? shown.map((e) => e.orderKey) : [];
  const shownKeys = shown.map((e) => e.key).join('\n');

  // Buscar, guardar, borrar o mover anima la lista (`useListTransition`). Se
  // le pasan las claves y no `shown`, que es otro arreglo en cada dibujo y
  // soltaría la transición antes de tiempo. Arrastrar no pasa por acá:
  // `useHoldDrag` ya anima lo suyo.
  const animateList = useListTransition(shownKeys);
  const search = (value: string) => {
    setQuery(value);
    animateList(() => setListQuery(value));
  };
  // La red queda afuera de la transición, que congela la pantalla: el
  // Registro se relee antes y la caché cambia adentro. El guion de lo tocado
  // se vuelve a pedir: de él sale en qué grupo cae.
  const notebookKey = queryKeys.campaignNotebook(campaign.id);
  const reloadAnimated = async (...touched: string[]) => {
    await client.cancelQueries({ queryKey: notebookKey });
    const fresh = await fetchCampaignNotebook(campaign.id, new AbortController().signal);
    for (const id of touched) void client.invalidateQueries({ queryKey: queryKeys.chapterScript(campaign.id, id) });
    animateList(() => client.setQueryData(notebookKey, fresh));
  };

  // Borrar una nota o mover una entrada se lleva su ⋮ (la entrada deja la
  // vista): el foco va al título de la pantalla. Una nota guardada lo recibe
  // ella, y la vista baja hasta donde quedó. Se mueve cuando la lista nueva
  // se dibujó y el diálogo terminó de devolver el foco a su botón.
  // Se reintenta también cuando llega el guion: hasta entonces la lista de un
  // capítulo recién abierto no está dibujada.
  const setFocusTarget = useDeferredFocus(`${chapterScript.data !== undefined}
${shownKeys}`, { retry: true, scroll: true });

  const moveEntry = (from: string, to: string) => {
    if (!chapter) return;
    const id = chapter.id;
    const order = movedOrder(ids, from, to);
    void (async () => {
      const key = queryKeys.campaignChapters(campaign.id);
      await client.cancelQueries({ queryKey: key });
      client.setQueryData<DmChapter[]>(key, (old) => old?.map((c) => (c.id === id ? { ...c, entryOrder: order } : c)));
      try {
        await saveEntryOrder(campaign.id, id, order);
      } catch {
        notify('error', t.dmOrderSaveError);
        void client.invalidateQueries({ queryKey: key });
      }
    })();
  };
  // La página queda fija y solo las entradas scrollean: con un capítulo largo,
  // bajar se llevaba el título, el buscador y el objetivo. El alto se cuenta
  // desde donde empieza la lista, que cambia con el objetivo del capítulo y con
  // el ancho (la cabecera se parte); los 24 px son el relleno de abajo de `main`,
  // como en el Códice (`useListFitsViewport`).
  const listRef = useRef<HTMLDivElement>(null);
  const [listTop, setListTop] = useState(0);
  const hasList = shown.length > 0;
  const entriesMissing = entries === null;
  useLayoutEffect(() => {
    const el = listRef.current;
    if (!el) return;
    const measure = () => setListTop(el.getBoundingClientRect().top + window.scrollY);
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [hasList, chapterId, searching, chapter?.summary, chapters.data, entriesMissing, script]);

  // Solo dentro de un grupo: arrastrar no cambia el hito de una entrada.
  const reorder = useHoldDrag({
    ids,
    axis: 'y',
    scroller: listRef,
    canDrop: (from, to) => arrangeable && groupOf.get(from) === groupOf.get(to),
    onMove: moveEntry,
  });

  const failed = [notebook, chapters, chapterScript, ...catalog.queries].filter((q) => q.isError);
  let body;
  if (missing) {
    // Antes que los errores: el guion de un capítulo que no existe da 404.
    body = (
      <AppEmptyState
        kind="empty"
        message={t.dmChapterNotFound}
        actions={
          <ButtonLink internal tone="secondary" href={dmCampaignHref(campaign.id, 'capitulos')}>
            {t.dmBackToChapters}
          </ButtonLink>
        }
      />
    );
  } else if (failed.length > 0) {
    body = (
      <AppErrorView title={t.dmNotebookReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
    );
  } else if (!entries || !chapters.data || (chapterId !== null && !chapterScript.data)) {
    body = <AppBusyLabel label={t.dmNotebookLoading} />;
  } else {
    const count = (k: EntryKind) => shown.filter((e) => e.kind === k).length;
    const now = Date.now();

    body = (
      <>
        {/* El objetivo del capítulo, con sus menciones: lo que la mesa tiene
            que lograr se lee junto a lo que va pasando. */}
        {chapter?.summary?.trim() && !searching && (
          <p className="text-[13.5px] leading-[1.55] whitespace-pre-line text-on-surface-variant" data-field="chapter-goal">
            {withMentions(chapter.summary, mentions)}
          </p>
        )}

        <div role="search" className="relative w-full max-w-[260px]">
          <label htmlFor="log-search" className="sr-only">
            {t.dmSearchLog}
          </label>
          <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
          <input
            id="log-search"
            type="search"
            autoComplete="off"
            value={query}
            onChange={(e) => search(e.target.value)}
            placeholder={t.dmSearchLog}
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
          // `overflow` recorta lo que sale de la lista, y al arrastrar la
          // tarjeta crece un 2 % (`useHoldDrag`) y se marca el destino: los
          // 16 px de los costados, más angostos que la cabecera, le dejan lugar
          // hasta unos 1600 px de ancho. `min-h-60`: en un teléfono la cabecera
          // ocupa casi todo, y una lista de dos dedos no se puede leer.
          <div
            ref={listRef}
            data-field="notebook-list"
            data-vt-clip
            className="-m-1 min-h-60 overflow-y-auto px-4 py-1"
            style={{ maxHeight: `calc(100dvh - ${listTop}px - 24px)` }}
          >
            <ol aria-label={chapter?.name ?? t.dmNoChapter} className="flex flex-col gap-2.5">
              {groups.flatMap((g) => [
                script && (
                  <li key={`group-${g.id ?? ''}`} data-milestone={g.id ?? 'before'} className="mt-2 flex items-center gap-3">
                    <span aria-hidden="true" className="h-px min-w-3 flex-1 bg-hairline" />
                    <span aria-hidden="true" className="h-[7px] w-[7px] shrink-0 rotate-45 bg-gold" />
                    <span className={cx('font-display min-w-0 text-[15px] break-words', g.id !== null && g.id === activeId ? 'text-gold' : 'text-on-surface-variant')}>
                      {g.heading ?? t.dmBeforeScript}
                      {g.id !== null && g.id === activeId && ` · ${t.dmMilestoneNow}`}
                    </span>
                    <span aria-hidden="true" className="h-px min-w-3 flex-1 bg-hairline" />
                  </li>
                ),
                ...g.entries.map((e) => (
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
                      viewTransitionName: vtName('nb', e.key),
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
                )),
              ])}
            </ol>
          </div>
        )}
      </>
    );
  }

  const submit = async (note: DmNote) => {
    if (editing === 'new') await createNote(campaign.id, note);
    else await saveNote(campaign.id, note);
    await reloadAnimated(...new Set([chapterId ?? note.chapterId, note.chapterId]));
    // Sin fundido: llevaría el foco al título, y acá va a la nota.
    if (note.chapterId !== chapterId && chapterList.some((c) => c.id === note.chapterId)) navigate(dmChapterHref(campaign.id, note.chapterId), { fade: false });
    setFocusTarget(`[data-entry-key="${CSS.escape(`note-${note.id}`)}"] h2`);
  };

  const status =
    chapter?.state === 'completed' ? t.dmChapterClosed : chapter?.state === 'active' ? t.dmChapterOpen : t.dmChapterPending;

  return (
    <div className={cx('flex flex-col gap-5', readingClass)}>
      {chapterId !== null && (
        <Link href={dmCampaignHref(campaign.id, 'capitulos')} className="-mb-3 self-start text-[13px] text-text-muted hover:text-gold">
          {t.dmSectionChapters}
        </Link>
      )}
      <DmHeader
        title={chapterId === null ? t.dmNoChapter : (chapter?.name ?? t.dmSectionChapters)}
        kicker={chapter ? status : undefined}
        actions={
          chapter && (
            <>
              <Button icon={Plus} data-action="write-note" onClick={() => setEditing('new')} className="min-h-11">
                {t.dmWriteNote}
              </Button>
              {/* Un capítulo cerrado no se edita ni se cierra: sin menú. */}
              {chapter.state !== 'completed' && (
                <DropdownMenu>
                  <Tooltip content={t.dmChapterActions}>
                    <DropdownMenuTrigger asChild>
                      <button
                        type="button"
                        aria-label={t.dmChapterActions}
                        data-action="chapter-menu"
                        className="inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-card)] border border-hairline text-on-surface-variant hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
                      >
                        <EllipsisVertical size={18} aria-hidden="true" />
                      </button>
                    </DropdownMenuTrigger>
                  </Tooltip>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onSelect={() => setEditingChapter(true)}>
                      <Pencil size={15} aria-hidden="true" className="text-text-muted" />
                      {t.dmEditChapter}
                    </DropdownMenuItem>
                    {chapter.state === 'active' && (
                      <DropdownMenuItem onSelect={() => setClosing(true)}>
                        <CheckCheck size={15} aria-hidden="true" className="text-text-muted" />
                        {t.dmCloseChapter}
                      </DropdownMenuItem>
                    )}
                  </DropdownMenuContent>
                </DropdownMenu>
              )}
            </>
          )
        }
      />
      {body}
      {editing && chapterList.length > 0 && (
        <NoteEditorDialog
          title={editing === 'new' ? t.dmWriteNote : t.dmEditNote}
          campaignId={campaign.id}
          initial={editing === 'new' ? { id: `note-${Date.now()}`, chapterId: chapterId!, title: '' } : editing}
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
            await reloadAnimated(deleting.chapterId);
            setFocusTarget('[data-dm-title]');
          }}
          onClose={() => setDeleting(null)}
        />
      )}
      {moving && (
        <MoveToChapterDialog
          entryTitle={moving.title}
          chapters={chapterList}
          onMove={async (to) => {
            await assignEntryChapter(campaign.id, moving.kind === 'fight' ? 'fight' : 'levelUp', moving.entryId, to);
            // Llega al final del capítulo: no figura en su orden. Se queda en
            // «Sin capítulo» para seguir vaciando la bandeja.
            await reloadAnimated(to);
            setFocusTarget('[data-dm-title]');
          }}
          onClose={() => setMoving(null)}
        />
      )}
      {editingChapter && chapter && (
        <ChapterEditorDialog
          title={t.dmEditChapter}
          campaignId={campaign.id}
          initial={chapter}
          onSubmit={async (next) => {
            await saveChapter(campaign.id, next);
            await client.invalidateQueries({ queryKey: queryKeys.campaignChapters(campaign.id) });
          }}
          onClose={() => setEditingChapter(false)}
        />
      )}
      {closing && chapter && (
        <CloseChapterDialog
          campaignId={campaign.id}
          chapter={chapter}
          onClosed={(name) => {
            notify('success', t.dmChapterCloseDone(name));
            // El menú que lo cerró desaparece con el capítulo.
            setFocusTarget('[data-dm-title]');
          }}
          onClose={() => setClosing(false)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} open onOpenChange={(open) => !open && setToast(null)} />}
      {panel}
    </div>
  );
}
