import { useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { EllipsisVertical, Eye, FolderInput, Lock, Pencil, Plus, Search, Trash2, X } from 'lucide-react';
import {
  queryKeys,
  useCampaignChapters,
  useCampaignMembers,
  useCampaignNotebook,
  useCampaignNpcs,
  useSheetCatalog,
} from '../api/queries';
import {
  assignEntryChapter,
  createNote,
  deleteNote,
  saveEntryOrder,
  saveNote,
  type DmCampaign,
  type DmChapter,
  type DmNote,
} from '../api/client';
import { movedOrder } from '../dashboard/roster';
import { useHoldDrag } from '../ui/holdDrag';
import { Toast, type ToastTone } from '../ui/primitives';
import { MoveToChapterDialog } from './MoveToChapterDialog';
import { useLang, useTexts } from '../i18n/context';
import { Button, ButtonLink } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { cx } from '../ui/cx';
import { MarkdownText } from '../ui/MarkdownText';
import { withMentions, type Mentions } from '../ui/mentions';
import { dmCampaignHref, dmMemberHref, dmNpcsHref, Link } from '../router';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Tooltip } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { stateLabel, stateOf } from './campaigns';
import { CampaignMenu } from './CampaignMenu';
import { DmHeader } from './DmHeader';
import { NoteEditorDialog } from './NoteEditorDialog';
import { buildEntries, inChapterOrder, matches, stamp, type Entry, type EntryKind } from './notebook';

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
  const [query, setQuery] = useState('');
  const [picked, setPicked] = useState<string | null>(() => new URLSearchParams(window.location.search).get('capitulo'));
  const client = useQueryClient();
  const [editing, setEditing] = useState<DmNote | 'new' | null>(null);
  const [deleting, setDeleting] = useState<DmNote | null>(null);
  const [moving, setMoving] = useState<Entry | null>(null);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string } | null>(null);
  const notify = (tone: ToastTone, message: string) => setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone, message }));
  const refresh = () => client.invalidateQueries({ queryKey: queryKeys.campaignNotebook(campaign.id) });
  // A quiénes enlaza una mención: los personajes de la mesa y los PNJ de la
  // campaña. Si no cargan, las menciones se leen como texto y el Cuaderno no
  // se cae por eso.
  const members = useCampaignMembers(campaign.id);
  const npcs = useCampaignNpcs(campaign.id);

  const mentions = useMemo((): Mentions => {
    const players = (members.data ?? []).map((m) => ({ name: String(m.character.name ?? ''), href: dmMemberHref(campaign.id, m.memberId) }));
    const people = (npcs.data ?? []).map((e) => ({ name: e.npc.name ?? '', href: dmNpcsHref(e.npc.id) }));
    // Un jugador y un PNJ con el mismo nombre: gana el jugador, que es de la
    // mesa. Entre dos del mismo tipo, el primero, igual que en la lista.
    const target = (name: string) => players.find((p) => p.name === name) ?? people.find((p) => p.name === name);
    return {
      names: [...players, ...people].map((p) => p.name),
      render: (name, key) => {
        const player = players.some((p) => p.name === name);
        return (
          <Tooltip key={key} content={player ? t.dmOpenSheet(name) : t.dmViewNpc(name)}>
            <Link
              href={target(name)!.href}
              data-mention={player ? 'player' : 'npc'}
              className="font-semibold text-gold underline decoration-gold underline-offset-2"
            >
              {name}
            </Link>
          </Tooltip>
        );
      },
    };
  }, [members.data, npcs.data, campaign.id, t]);

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
  const searching = query.trim() !== '';
  const visible = (entries ?? []).filter((e) => matches(e, query));
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
  const reorder = useHoldDrag({ ids, axis: 'y', canDrop: () => arrangeable, onMove: moveEntry });

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
                  onClick={() => setPicked(p.id)}
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
          <ol aria-label={pills.find((p) => p.id === current)?.label} className="flex flex-col gap-2.5">
            {shown.map((e) => (
              <li
                key={e.key}
                data-entry={e.kind}
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
              >
                <div className="flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
                  <span className={cx('text-[11.5px] font-medium', ACCENT[e.kind].text)}>
                    {e.kind === 'note' ? t.dmEntryNote : e.kind === 'fight' ? t.dmEntryFight : t.dmEntryLevelUp}
                  </span>
                  <h2 className="font-display min-w-0 flex-1 text-[17px] break-words text-on-surface">{e.title}</h2>
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
        )}
      </>
    );
  }

  // La nota nace en el capítulo en marcha o, si no hay, en el primero.
  const bornIn = initial;

  const submit = async (note: DmNote) => {
    if (editing === 'new') await createNote(campaign.id, note);
    else await saveNote(campaign.id, note);
    await refresh();
    setPicked(note.chapterId);
  };

  return (
    <div className="flex flex-col gap-5">
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
            await refresh();
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
            await refresh();
          }}
          onClose={() => setMoving(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} open onOpenChange={(open) => !open && setToast(null)} />}
    </div>
  );
}
