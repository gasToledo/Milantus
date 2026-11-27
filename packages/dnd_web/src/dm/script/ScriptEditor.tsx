import { useCallback, useEffect, useMemo, useState, type CSSProperties, type ReactNode } from 'react';
import { Check, Copy, GitFork, Info, Pencil, Plus, Trash2 } from 'lucide-react';
import type {
  DmChapter,
  DmMilestone,
  DmMilestoneState,
  DmScript,
  DmScriptLink,
  DmScriptStep,
  DmScriptView,
  MusicScene,
  ScriptNoteKind,
} from '../../api/client';
import { duplicateScript } from '../../api/client';
import { useCatalog, useSheetCatalog } from '../../api/queries';
import { flushScriptSave } from '../../api/scriptSave';
import { scriptView, type Catalog, type ScriptAction } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { codexHref, dmNpcsHref, dmScenariosHref, navigate } from '../../router';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { ConfirmDialog } from '../../ui/ConfirmDialog';
import { cx } from '../../ui/cx';
import { useDeferredFocus } from '../../ui/focus';
import { useHoldDrag } from '../../ui/holdDrag';
import { Toast } from '../../ui/primitives';
import { AppBusyLabel, AppEmptyState } from '../../ui/status';
import { ItemPicker } from '../ItemPicker';
import { NoteEditorDialog } from '../NoteEditorDialog';
import { milestoneLabels } from './labels';
import type { ScriptLinkType } from './kinds';
import { MilestoneCard, MoreMenu, type MenuEntry, type MilestoneApi } from './MilestoneCard';
import { forkAhead, usePlay, type Notify } from './play';
import {
  ChoosePathDialog,
  MilestoneDialog,
  MusicLinkDialog,
  NpcLinkDialog,
  PreparedCombatDialog,
  PreparedCombatPreview,
  ScenarioLinkDialog,
  ScriptNoteDialog,
} from './ScriptDialogs';
import { useScriptWriter } from './scriptWriter';

/** Lo que el guion toma del capítulo desde el que se edita; en la Biblioteca no
 *  hay ninguno. */
export interface ScriptChapter {
  campaignId: string;
  chapterId: string;
  chapters: readonly DmChapter[];
  scenes: readonly MusicScene[];
  npcHp: ReadonlyMap<string, string>;
  notify: Notify;
  onMusicOffer: (campaignId: string, show: boolean) => void;
}

export type ScriptMode = 'edit' | 'play';

type Open =
  | { kind: 'milestone'; id: string; path: boolean; isNew: boolean }
  | { kind: 'note'; milestone: string; note: ScriptNoteKind; existing?: string }
  | { kind: 'link'; milestone: string; type: ScriptLinkType; existing?: DmScriptLink }
  | { kind: 'confirm'; title: string; body: string; action: ScriptAction }
  /** Elegir por dónde se sigue, al alcanzar [milestone] o sin hito actual. */
  | { kind: 'choose'; milestone?: string }
  | { kind: 'logNote'; id: string }
  | { kind: 'combat'; milestone: string; link: Extract<DmScriptLink, { type: 'encounter' }> };

const ANCHOR = '#hito-';
/** El hito al que apunta la URL (un separador del Registro), si apunta a uno. */
function anchoredMilestone(): string | null {
  const { hash } = window.location;
  if (!hash.startsWith(ANCHOR)) return null;
  try {
    return decodeURIComponent(hash.slice(ANCHOR.length));
  } catch {
    return null;
  }
}

/** A dónde lleva un ítem en el Códice, o `null` si el catálogo no lo tiene. */
function itemHref(catalog: Catalog | undefined, itemId: string, category: 'weapons' | 'armor' | 'items'): string | null {
  const found = catalog?.[category].find((i) => i.id === itemId);
  if (!found) return null;
  const to = category === 'items' ? (typeof found.rarity === 'string' ? 'magicItems' : 'gear') : category;
  return codexHref(to, itemId);
}

/** El estado de un paso en el riel. Una bifurcación es una sola parada: la del
 *  camino por el que se va. */
function stepState(step: DmScriptStep, view: DmScriptView | null): DmMilestoneState {
  const states = (step.type === 'fork' ? step.paths : [step]).map((m) => view?.states[m.id] ?? 'pending');
  return states.includes('current') ? 'current' : states.includes('reached') ? 'reached' : 'pending';
}

function Dot({ state, number }: { state: DmMilestoneState; number: number }) {
  const t = useTexts();
  return (
    <span
      data-state={state}
      className={cx(
        'num flex size-8 shrink-0 items-center justify-center rounded-full text-[13px]',
        state === 'reached' && 'border-2 border-verdant text-verdant',
        state === 'current' && 'bg-gold text-on-primary',
        (state === 'pending' || state === 'notTaken') && 'border-2 border-hairline text-text-muted',
      )}
    >
      {state === 'reached' ? (
        <>
          <Check size={14} aria-hidden="true" />
          <span className="sr-only">{t.scReached}</span>
        </>
      ) : (
        <span aria-hidden="true">{number}</span>
      )}
    </span>
  );
}

/**
 * La línea de hitos y bifurcaciones del guion, con sus notas y vínculos. Lo usan
 * la pestaña Guion de un capítulo y la Biblioteca. En `edit` cada cambio es una
 * acción del motor (`useScriptWriter`); en `play` el guion es de solo lectura y
 * lo que avanza es el progreso del capítulo (`play.ts`). Acá no se arma ningún
 * documento.
 *
 * [view] es el progreso del capítulo, solo para mostrarlo: `null` en la
 * Biblioteca, donde todo es neutro y nada arranca desplegado. [layout] ubica los
 * botones de la cabecera y el cuerpo, que cambian entre las dos pantallas.
 */
export function ScriptEditor({
  script,
  campaigns,
  view,
  mode = 'edit',
  chapter,
  onDuplicated,
  layout,
}: {
  script: DmScript;
  /** En cuántas campañas se usa: con más de una se avisa. */
  campaigns: number;
  view: DmScriptView | null;
  /** `play` solo dentro de un capítulo: en la Biblioteca no hay partida. */
  mode?: ScriptMode;
  chapter: ScriptChapter | null;
  onDuplicated: (copy: DmScript) => Promise<void>;
  layout: (actions: ReactNode, body: ReactNode) => ReactNode;
}) {
  const t = useTexts();
  const lang = useLang();
  const official = useCatalog(lang);
  const [failures, setFailures] = useState<{ n: number; message: string } | null>(null);
  const fail = useCallback((message: string) => setFailures((old) => ({ n: (old?.n ?? 0) + 1, message })), []);
  const writer = useScriptWriter(
    script.id,
    useCallback(() => fail(t.scSaveError), [fail, t]),
  );
  const [open, setOpen] = useState<Open | null>(null);
  const [duplicating, setDuplicating] = useState(false);
  // Al abrir solo está desplegado el hito actual, y el del ancla si se llegó con
  // una. Después lo decide quien usa la pantalla.
  const [anchor] = useState(anchoredMilestone);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(
    () => new Set([view?.currentId, anchor].filter((id): id is string => !!id)),
  );
  useEffect(() => {
    if (anchor) document.getElementById(`hito-${anchor}`)?.scrollIntoView({ block: 'start' });
  }, [anchor]);
  // Borrar se lleva el ⋮ que tenía el foco, y avanzar se lleva el botón. Con
  // `retry` espera a que la tarjeta nueva esté dibujada.
  const setFocusTarget = useDeferredFocus(view ?? script, { retry: true });
  const playing = mode === 'play' && chapter !== null;
  const play = usePlay(chapter, script.id);
  // En juego el hito actual tiene que estar desplegado: al cambiar de modo y
  // cuando el actual cambia, que solo pasa porque alguien tocó «Marcar
  // alcanzado» o «Volver a este hito». Solo suma: plegar sigue siendo de quien
  // usa la pantalla.
  const currentId = view?.currentId;
  useEffect(() => {
    if (playing && currentId) setExpanded((old) => new Set(old).add(currentId));
  }, [playing, currentId]);

  const labels = useMemo(() => milestoneLabels(script), [script]);
  // Los rótulos de las tiradas no dependen del progreso.
  const checkLabels = useMemo(() => scriptView(script, {}).checkLabels, [script]);
  const milestones = useMemo(
    () => new Map(script.steps.flatMap((s) => (s.type === 'fork' ? s.paths : [s])).map((m) => [m.id, m] as const)),
    [script],
  );
  const act = writer.edit;

  const ids = script.steps.map((s) => s.id);
  const reorder = useHoldDrag({
    ids,
    axis: 'y',
    canDrop: () => true,
    onMove: (from, to) => void act({ type: 'moveStep', step: from, to: ids.indexOf(to) }),
  });

  const confirm = (title: string, body: string, action: ScriptAction) => setOpen({ kind: 'confirm', title, body, action });

  /** Después de avanzar o volver: se despliega el actual nuevo, se pliega el
   *  anterior y el foco va a su título. */
  const move = async (action: Parameters<typeof play.advance>[0]) => {
    const next = await play.advance(action);
    if (!next?.view) return;
    const { currentId: now, awaitingFork } = next.view;
    setOpen(null);
    setExpanded((old) => {
      const ids = new Set(old);
      if (currentId) ids.delete(currentId);
      if (now) ids.add(now);
      return ids;
    });
    setFocusTarget(
      now
        ? `[data-milestone="${CSS.escape(now)}"][aria-current="step"] h2 button`
        : awaitingFork
          ? '[data-action="choose-path"]'
          : '[data-dm-title]',
    );
  };
  const reach = () => {
    const milestone = currentId ?? undefined;
    if (view && forkAhead(script, view)) setOpen({ kind: 'choose', milestone });
    else if (milestone) void move({ type: 'reach', milestone });
  };

  const api: MilestoneApi = {
    checkLabels,
    scenes: chapter?.scenes ?? null,
    npcHp: chapter?.npcHp ?? new Map(),
    openLink: (link) => {
      const go = (href: string | null) => (href ? () => navigate(href) : null);
      switch (link.type) {
        case 'npc':
          return go(dmNpcsHref(link.npcId));
        case 'scenario':
          return go(dmScenariosHref(link.scenarioId));
        case 'item':
          return go(itemHref(official.data, link.item.itemId, link.item.category));
        case 'encounter':
          return () => {
            const owner = [...milestones.values()].find((m) => m.links.some((l) => l.id === link.id));
            if (!owner) return;
            setOpen(
              playing
                ? { kind: 'combat', milestone: owner.id, link }
                : { kind: 'link', milestone: owner.id, type: 'encounter', existing: link },
            );
          };
        case 'music':
          return null;
      }
    },
    toggle: (id) =>
      setExpanded((old) => {
        const next = new Set(old);
        if (!next.delete(id)) next.add(id);
        return next;
      }),
    addNote: (milestone, note) => setOpen({ kind: 'note', milestone, note }),
    editNote: (milestone, note) => setOpen({ kind: 'note', milestone, note: note.kind, existing: note.id }),
    removeNote: (milestone, note) => confirm(t.scDeleteNote, t.scDeleteNoteBody, { type: 'removeNote', milestone, note: note.id }),
    addLink: (milestone, type) => setOpen({ kind: 'link', milestone, type }),
    replaceLink: (milestone, link) => setOpen({ kind: 'link', milestone, type: link.type, existing: link }),
    removeLink: (milestone, link) => void act({ type: 'removeLink', milestone, link }),
    share:
      chapter && view
        ? {
            done: new Set(view.shared),
            run: (milestone, note) =>
              void play.share(note, milestones.get(milestone)!).then((done) => {
                // El ⋮ que se tocó puede irse con la nota ya compartida.
                if (done) setFocusTarget(`[data-milestone="${CSS.escape(milestone)}"] h2 button`);
              }),
          }
        : null,
    play: playing ? { busy: play.busy, reach, writeNote: () => setOpen({ kind: 'logNote', id: `note-${Date.now()}` }) } : null,
  };

  const addMilestone = () => {
    const id = crypto.randomUUID();
    if (act({ type: 'addMilestone', id, title: '' })) setOpen({ kind: 'milestone', id, path: false, isNew: true });
  };
  const addFork = () => {
    const paths: [string, string] = [crypto.randomUUID(), crypto.randomUUID()];
    if (act({ type: 'addFork', id: crypto.randomUUID(), paths })) setOpen({ kind: 'milestone', id: paths[0], path: true, isNew: true });
  };

  const duplicate = async () => {
    if (duplicating) return;
    setDuplicating(true);
    try {
      // La copia sale de lo guardado: lo pendiente tiene que llegar antes.
      await flushScriptSave(script.id);
      const copy = await duplicateScript(script.id, {
        id: crypto.randomUUID(),
        name: t.scCopyName(script.name),
        ...(chapter ? { campaignId: chapter.campaignId, chapterId: chapter.chapterId } : {}),
      });
      await onDuplicated(copy);
    } catch {
      fail(t.scActionError);
    }
    setDuplicating(false);
  };

  const addMilestoneButton = (
    <Button icon={Plus} data-action="add-milestone" onClick={addMilestone} className="min-h-11">
      {t.scMilestone}
    </Button>
  );
  const empty = script.steps.length === 0;
  // Con el guion vacío «+ Hito» está en el estado vacío, no arriba.
  const actions = empty || playing ? null : (
    <>
      <Button tone="soft" icon={GitFork} data-action="add-fork" onClick={addFork} className="min-h-11">
        {t.scFork}
      </Button>
      {addMilestoneButton}
    </>
  );

  /** El ⋮ en juego: volver a un alcanzado, o a un camino que no se tomó en la
   *  elección vigente. Lo que quedó detrás de un «Termina acá» no se ofrece: el
   *  motor lo rechaza. */
  const backMenu = (id: string, fork?: DmMilestone[]): Parameters<typeof MilestoneCard>[0]['menu'] => {
    const state = view?.states[id];
    const chosen = fork?.some((p) => view?.states[p.id] === 'reached' || view?.states[p.id] === 'current');
    if (state !== 'reached' && !(state === 'notTaken' && chosen)) return null;
    const items: MenuEntry[] = [{ label: t.scGoBack, action: 'go-back', onSelect: () => void move({ type: 'goBack', milestone: id }) }];
    return { label: fork ? t.scPathOptions : t.scMilestoneOptions, items };
  };

  const card = (milestone: DmMilestone, path: boolean, menu: Parameters<typeof MilestoneCard>[0]['menu']) => (
    <MilestoneCard
      milestone={milestone}
      number={labels.get(milestone.id)!}
      state={view?.states[milestone.id] ?? 'pending'}
      expanded={expanded.has(milestone.id)}
      path={path}
      menu={menu}
      api={api}
    />
  );
  const editMilestone = (id: string, path: boolean) => setOpen({ kind: 'milestone', id, path, isNew: false });

  const body = (
    <>
      {campaigns > 1 && !playing && (
        <div role="status" className="card flex flex-wrap items-center gap-x-4 gap-y-3 !border-gold px-4 py-3.5" data-field="shared-script">
          <Info size={18} aria-hidden="true" className="shrink-0 text-gold" />
          <span className="min-w-0 flex-[1_1_220px] leading-[1.45]">{t.scShared(campaigns)}</span>
          <Button tone="soft" icon={Copy} disabled={duplicating} data-action="duplicate-script" onClick={() => void duplicate()}>
            {t.scDuplicate}
          </Button>
        </div>
      )}
      {empty ? (
        <AppEmptyState kind="empty" message={t.scEmpty} actions={playing ? undefined : addMilestoneButton} />
      ) : (
        <ol aria-label={t.scTimeline} className="flex flex-col">
          {script.steps.map((step, i) => (
            <li
              key={step.id}
              data-step={step.type}
              {...(playing ? {} : reorder.item(step.id))}
              style={playing ? undefined : (reorder.item(step.id).style as CSSProperties | undefined)}
              className={cx(
                'grid',
                playing
                  ? 'grid-cols-1 gap-x-4 shell:grid-cols-[36px_minmax(0,1fr)]'
                  : 'grid-cols-[32px_minmax(0,1fr)] gap-x-3 select-none [-webkit-touch-callout:none] sm:grid-cols-[36px_minmax(0,1fr)] sm:gap-x-4',
                reorder.dragging === step.id && (reorder.animated ? 'cursor-grabbing [&_*]:cursor-grabbing' : 'opacity-40'),
                reorder.over === step.id && !reorder.animated && 'outline-2 outline-offset-1 outline-gold',
              )}
            >
              <div className={cx('flex flex-col items-center', playing && 'max-shell:hidden')}>
                <Dot state={stepState(step, view)} number={i + 1} />
                {i < script.steps.length - 1 && <span aria-hidden="true" className="min-h-4 w-0.5 flex-1 bg-hairline" />}
              </div>
              <div className={cx('min-w-0 pb-3', playing && 'max-shell:pb-2')}>
                {step.type === 'milestone' ? (
                  card(step, false, playing ? backMenu(step.id) : {
                    label: t.scMilestoneOptions,
                    items: [
                      { label: t.scEditMilestone, icon: Pencil, onSelect: () => editMilestone(step.id, false) },
                      {
                        label: t.scDeleteMilestone,
                        icon: Trash2,
                        danger: true,
                        onSelect: () =>
                          confirm(t.scDeleteMilestone, t.scDeleteMilestoneBody(step.title || t.scUntitled), {
                            type: 'removeStep',
                            step: step.id,
                          }),
                      },
                    ],
                  })
                ) : (
                  <div className="flex flex-col gap-2">
                    <div className={cx('flex min-h-8 items-center gap-2', playing && view?.awaitingFork !== step.id && 'max-shell:hidden')}>
                      <p className={cx('eyebrow', playing && 'max-shell:hidden')}>{t.scForkEyebrow}</p>
                      {!playing ? (
                        <MoreMenu
                          label={t.scForkOptions}
                          action="fork-menu"
                          items={[
                            {
                              label: t.scAddPath,
                              icon: Plus,
                              // El tope es del motor: con cuatro, `addPath` no cambia nada.
                              blocked: step.paths.length >= 4,
                              onSelect: () => {
                                const id = crypto.randomUUID();
                                if (act({ type: 'addPath', fork: step.id, id })) setOpen({ kind: 'milestone', id, path: true, isNew: true });
                              },
                            },
                            {
                              label: t.scDeleteFork,
                              icon: Trash2,
                              danger: true,
                              onSelect: () => confirm(t.scDeleteFork, t.scDeleteForkBody, { type: 'removeStep', step: step.id }),
                            },
                          ]}
                        />
                      ) : (
                        view?.awaitingFork === step.id && (
                          <Button
                            data-action="choose-path"
                            disabled={play.busy}
                            onClick={() => setOpen({ kind: 'choose' })}
                            className="ml-auto min-h-11 max-shell:flex-1"
                          >
                            {t.scChoosePath}
                          </Button>
                        )
                      )}
                    </div>
                    <div
                      className={cx(
                        'grid grid-cols-[repeat(auto-fit,minmax(min(260px,100%),1fr))] items-start gap-3',
                        playing && 'max-shell:gap-2',
                      )}
                    >
                      {step.paths.map((path) => (
                        <div key={path.id} className="min-w-0">
                          {card(path, true, playing ? backMenu(path.id, step.paths) : {
                            label: t.scPathOptions,
                            items: [
                              { label: t.scEditPath, icon: Pencil, onSelect: () => editMilestone(path.id, true) },
                              {
                                label: t.scDeletePath,
                                icon: Trash2,
                                danger: true,
                                blocked: step.paths.length <= 2,
                                onSelect: () =>
                                  confirm(t.scDeletePath, t.scDeletePathBody(path.title || t.scUntitled), {
                                    type: 'removePath',
                                    fork: step.id,
                                    path: path.id,
                                  }),
                              },
                            ],
                          })}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </li>
          ))}
        </ol>
      )}
      {playing && view?.finished && <p className="text-text-muted">{t.scFinished}</p>}
    </>
  );

  const close = () => setOpen(null);
  let dialog: ReactNode = null;
  if (open?.kind === 'milestone') {
    const milestone = milestones.get(open.id);
    if (milestone) {
      const heading = open.isNew
        ? open.path
          ? t.scNewPath
          : t.scNewMilestone
        : open.path
          ? t.scEditPath
          : t.scEditMilestone;
      dialog = (
        <MilestoneDialog
          key={open.id}
          heading={heading}
          milestone={milestone}
          path={open.path}
          onSave={(fields) => void act({ type: 'setMilestone', milestone: open.id, ...fields })}
          onClose={close}
        />
      );
    }
  } else if (open?.kind === 'note') {
    dialog = (
      <ScriptNoteDialog
        kind={open.note}
        note={milestones.get(open.milestone)?.notes.find((n) => n.id === open.existing)}
        onSave={(note) => void act({ type: 'saveNote', milestone: open.milestone, note })}
        onClose={close}
      />
    );
  } else if (open?.kind === 'link') {
    const id = open.existing?.id ?? crypto.randomUUID();
    const save = (link: DmScriptLink) => {
      act({ type: 'saveLink', milestone: open.milestone, link });
      close();
    };
    if (open.type === 'npc') dialog = <NpcLinkDialog id={id} onSave={save} onClose={close} />;
    else if (open.type === 'scenario') dialog = <ScenarioLinkDialog id={id} onSave={save} onClose={close} />;
    else if (open.type === 'music') dialog = <MusicLinkDialog id={id} scenes={chapter?.scenes ?? []} onSave={save} onClose={close} />;
    else if (open.type === 'encounter') {
      dialog = (
        <PreparedCombatDialog
          id={id}
          link={open.existing?.type === 'encounter' ? open.existing : undefined}
          onSave={save}
          onClose={close}
        />
      );
    } else {
      dialog = (
        <ItemLinkPicker
          chosen={(milestones.get(open.milestone)?.links ?? []).flatMap((l) => (l.type === 'item' ? [l.item] : []))}
          // Agregar no cierra: se suelen sumar varios.
          onAdd={(item) => void act({ type: 'saveLink', milestone: open.milestone, link: { type: 'item', id: crypto.randomUUID(), item } })}
          onClose={close}
        />
      );
    }
  } else if (open?.kind === 'choose' && view) {
    const fork = forkAhead(script, view);
    if (fork) {
      dialog = (
        <ChoosePathDialog
          paths={fork.paths}
          labels={labels}
          busy={play.busy}
          onConfirm={(path) => void move({ type: 'reach', milestone: open.milestone, path })}
          onClose={close}
        />
      );
    }
  } else if (open?.kind === 'logNote' && chapter) {
    dialog = (
      <NoteEditorDialog
        title={t.dmWriteNote}
        campaignId={chapter.campaignId}
        initial={{ id: open.id, chapterId: chapter.chapterId, title: '' }}
        chapters={chapter.chapters}
        onSubmit={play.saveNote}
        onClose={close}
      />
    );
  } else if (open?.kind === 'combat' && chapter) {
    const milestone = milestones.get(open.milestone);
    if (milestone) {
      dialog = (
        <PreparedCombatPreview
          campaignId={chapter.campaignId}
          link={open.link}
          milestone={milestone}
          notify={chapter.notify}
          onMusicOffer={chapter.onMusicOffer}
          onClose={close}
        />
      );
    }
  } else if (open?.kind === 'confirm') {
    dialog = (
      <ConfirmDialog
        title={open.title}
        body={open.body}
        confirmLabel={open.title}
        errorText={t.scSaveError}
        onConfirm={async () => {
          if (!act(open.action)) throw new Error('El motor rechazó la acción');
          setFocusTarget('[data-dm-title]');
        }}
        onClose={close}
      />
    );
  }

  return (
    <>
      {layout(actions, body)}
      {dialog}
      {failures && (
        <Toast key={failures.n} tone="error" message={failures.message} open onOpenChange={(o) => !o && setFailures(null)} />
      )}
    </>
  );
}

/** El selector de objetos de siempre, con el catálogo de la cuenta. */
function ItemLinkPicker(props: Omit<Parameters<typeof ItemPicker>[0], 'catalog'>) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  if (catalog.data) return <ItemPicker catalog={catalog.data} {...props} />;
  const failed = catalog.queries.some((q) => q.isError);
  return (
    <AppDialog open onOpenChange={(o) => !o && props.onClose()} title={t.scLinkKinds.item} actions={[{ label: t.cancel }]}>
      {failed ? (
        <p role="alert" className="text-[13px] text-crimson">
          {t.scActionError}
        </p>
      ) : (
        <AppBusyLabel label={t.scLoading} />
      )}
    </AppDialog>
  );
}
