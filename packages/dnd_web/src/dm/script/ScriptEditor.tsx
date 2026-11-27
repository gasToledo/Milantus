import { useCallback, useEffect, useMemo, useState, type CSSProperties, type ReactNode } from 'react';
import { Check, Copy, GitFork, Info, Pencil, Plus, Trash2 } from 'lucide-react';
import type { DmMilestone, DmMilestoneState, DmScript, DmScriptLink, DmScriptStep, DmScriptView, MusicScene, ScriptNoteKind } from '../../api/client';
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
import { milestoneLabels } from './labels';
import type { ScriptLinkType } from './kinds';
import { MilestoneCard, MoreMenu, type MilestoneApi } from './MilestoneCard';
import {
  MilestoneDialog,
  MusicLinkDialog,
  NpcLinkDialog,
  PreparedCombatDialog,
  ScenarioLinkDialog,
  ScriptNoteDialog,
} from './ScriptDialogs';
import { useScriptWriter } from './scriptWriter';

/** Lo que el guion toma del capítulo desde el que se edita; en la Biblioteca no
 *  hay ninguno. */
export interface ScriptChapter {
  campaignId: string;
  chapterId: string;
  scenes: readonly MusicScene[];
  npcHp: ReadonlyMap<string, string>;
}

type Open =
  | { kind: 'milestone'; id: string; path: boolean; isNew: boolean }
  | { kind: 'note'; milestone: string; note: ScriptNoteKind; existing?: string }
  | { kind: 'link'; milestone: string; type: ScriptLinkType; existing?: DmScriptLink }
  | { kind: 'confirm'; title: string; body: string; action: ScriptAction };

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
 * El guion en modo Editar: la línea de hitos y bifurcaciones, con sus notas y
 * vínculos. Lo usan la pestaña Guion de un capítulo y la Biblioteca. Cada cambio
 * es una acción del motor (`useScriptWriter`); acá no se arma ningún documento.
 *
 * [view] es el progreso del capítulo, solo para mostrarlo: `null` en la
 * Biblioteca, donde todo es neutro y nada arranca desplegado. [layout] ubica los
 * botones de la cabecera y el cuerpo, que cambian entre las dos pantallas.
 */
export function ScriptEditor({
  script,
  campaigns,
  view,
  chapter,
  onDuplicated,
  layout,
}: {
  script: DmScript;
  /** En cuántas campañas se usa: con más de una se avisa. */
  campaigns: number;
  view: DmScriptView | null;
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
  // Borrar se lleva el ⋮ que tenía el foco.
  const setFocusTarget = useDeferredFocus(script);

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
            if (owner) setOpen({ kind: 'link', milestone: owner.id, type: 'encounter', existing: link });
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
  const actions = empty ? null : (
    <>
      <Button tone="soft" icon={GitFork} data-action="add-fork" onClick={addFork} className="min-h-11">
        {t.scFork}
      </Button>
      {addMilestoneButton}
    </>
  );

  const card = (milestone: DmMilestone, path: boolean, menu: Parameters<typeof MilestoneCard>[0]['menu']) => (
    <MilestoneCard
      milestone={milestone}
      number={labels.get(milestone.id)!}
      current={view?.currentId === milestone.id}
      expanded={expanded.has(milestone.id)}
      path={path}
      menu={menu}
      api={api}
    />
  );
  const editMilestone = (id: string, path: boolean) => setOpen({ kind: 'milestone', id, path, isNew: false });

  const body = (
    <>
      {campaigns > 1 && (
        <div role="status" className="card flex flex-wrap items-center gap-x-4 gap-y-3 !border-gold px-4 py-3.5" data-field="shared-script">
          <Info size={18} aria-hidden="true" className="shrink-0 text-gold" />
          <span className="min-w-0 flex-[1_1_220px] leading-[1.45]">{t.scShared(campaigns)}</span>
          <Button tone="soft" icon={Copy} disabled={duplicating} data-action="duplicate-script" onClick={() => void duplicate()}>
            {t.scDuplicate}
          </Button>
        </div>
      )}
      {empty ? (
        <AppEmptyState kind="empty" message={t.scEmpty} actions={addMilestoneButton} />
      ) : (
        <ol aria-label={t.scTimeline} className="flex flex-col">
          {script.steps.map((step, i) => (
            <li
              key={step.id}
              data-step={step.type}
              {...reorder.item(step.id)}
              style={reorder.item(step.id).style as CSSProperties | undefined}
              className={cx(
                'grid grid-cols-[32px_minmax(0,1fr)] gap-x-3 select-none [-webkit-touch-callout:none] sm:grid-cols-[36px_minmax(0,1fr)] sm:gap-x-4',
                reorder.dragging === step.id && (reorder.animated ? 'cursor-grabbing [&_*]:cursor-grabbing' : 'opacity-40'),
                reorder.over === step.id && !reorder.animated && 'outline-2 outline-offset-1 outline-gold',
              )}
            >
              <div className="flex flex-col items-center">
                <Dot state={stepState(step, view)} number={i + 1} />
                {i < script.steps.length - 1 && <span aria-hidden="true" className="min-h-4 w-0.5 flex-1 bg-hairline" />}
              </div>
              <div className="min-w-0 pb-3">
                {step.type === 'milestone' ? (
                  card(step, false, {
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
                    <div className="flex min-h-8 items-center gap-2">
                      <p className="eyebrow">{t.scForkEyebrow}</p>
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
                    </div>
                    <div className="grid grid-cols-[repeat(auto-fit,minmax(min(260px,100%),1fr))] items-start gap-3">
                      {step.paths.map((path) => (
                        <div key={path.id} className="min-w-0">
                          {card(path, true, {
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
