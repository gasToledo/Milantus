import { ChevronDown, ChevronUp, EllipsisVertical, Pencil, Plus, Trash2, type LucideIcon } from 'lucide-react';
import { SCRIPT_NOTE_KINDS, type DmMilestone, type DmScriptLink, type DmScriptNote, type MusicScene, type ScriptNoteKind } from '../../api/client';
import { useTexts } from '../../i18n/context';
import { Button } from '../../ui/Button';
import { cx } from '../../ui/cx';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Tooltip,
} from '../../ui/primitives';
import { LINK_ICONS, NOTE_STYLE, type ScriptLinkType } from './kinds';

/** El campo de [type] en el menú «Agregar al hito», sin la música fuera de una
 *  campaña. */
const LINK_TYPES = Object.keys(LINK_ICONS) as ScriptLinkType[];

/** Lo que una tarjeta necesita de su editor: qué mostrar y qué pedirle. */
export interface MilestoneApi {
  /** Id de nota → rótulo de su tirada, ya armado por el motor. */
  checkLabels: Record<string, string>;
  /** Las escenas de la campaña; `null` en la Biblioteca. */
  scenes: readonly MusicScene[] | null;
  /** Id de PNJ → «9/9 PG», solo los que están en la campaña. */
  npcHp: ReadonlyMap<string, string>;
  /** A dónde lleva «Abrir», o `null` si el vínculo no lleva a ningún lado. */
  openLink: (link: DmScriptLink) => (() => void) | null;
  toggle: (id: string) => void;
  addNote: (milestone: string, kind: ScriptNoteKind) => void;
  editNote: (milestone: string, note: DmScriptNote) => void;
  removeNote: (milestone: string, note: DmScriptNote) => void;
  addLink: (milestone: string, type: ScriptLinkType) => void;
  replaceLink: (milestone: string, link: DmScriptLink) => void;
  removeLink: (milestone: string, link: string) => void;
}

export interface MenuEntry {
  label: string;
  icon: LucideIcon;
  onSelect: () => void;
  danger?: boolean;
  /** Se ve y se anuncia apagada, pero sigue en el menú. */
  blocked?: boolean;
}

/** Un ⋮ con sus opciones. */
export function MoreMenu({ label, action, items, className }: { label: string; action: string; items: MenuEntry[]; className?: string }) {
  return (
    <DropdownMenu>
      <Tooltip content={label}>
        <DropdownMenuTrigger asChild>
          <button
            type="button"
            aria-label={label}
            data-action={action}
            className={cx(
              'inline-flex size-9 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold',
              className,
            )}
          >
            <EllipsisVertical size={18} aria-hidden="true" />
          </button>
        </DropdownMenuTrigger>
      </Tooltip>
      <DropdownMenuContent align="end">
        {items.map(({ label: text, icon: Icon, onSelect, danger, blocked }) => (
          <DropdownMenuItem
            key={text}
            aria-disabled={blocked || undefined}
            onSelect={(e) => (blocked ? e.preventDefault() : onSelect())}
            className={cx(danger && 'text-crimson', blocked && 'opacity-45')}
          >
            <Icon size={15} aria-hidden="true" className={danger ? undefined : 'text-text-muted'} />
            {text}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

const linkName = (link: DmScriptLink) => (link.type === 'item' ? link.item.name : link.name);

/** Un vínculo del hito. Tocarlo abre su menú. */
function LinkChip({ milestone, link, api }: { milestone: string; link: DmScriptLink; api: MilestoneApi }) {
  const t = useTexts();
  const Icon = LINK_ICONS[link.type];
  // Una escena vive en la campaña y el guion no: puede faltar en esta.
  const missing = link.type === 'music' && api.scenes !== null && !api.scenes.some((s) => s.id === link.sceneId);
  const open = api.openLink(link);
  const hp = link.type === 'npc' ? api.npcHp.get(link.npcId) : undefined;
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          data-link={link.type}
          className={cx(
            // Encima del enlace estirado de la tarjeta de un camino plegado.
            'pick relative z-10 inline-flex min-h-7 max-w-full items-center gap-1.5 rounded-[var(--radius-pill)] border px-2.5 py-0.5 text-left text-[12.5px]',
            missing ? 'border-dashed border-hairline text-text-muted' : 'border-hairline bg-plaque text-on-surface-variant',
          )}
        >
          <Icon size={14} aria-hidden="true" className="shrink-0" />
          <span className="min-w-0 break-words">{missing ? t.scLinkMissing(linkName(link)) : linkName(link)}</span>
          {hp && <span className="num whitespace-nowrap text-verdant">{hp}</span>}
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        {missing ? (
          <DropdownMenuItem onSelect={() => api.replaceLink(milestone, link)}>{t.scLinkPickOther}</DropdownMenuItem>
        ) : (
          open && <DropdownMenuItem onSelect={open}>{t.scLinkOpen}</DropdownMenuItem>
        )}
        <DropdownMenuItem onSelect={() => api.removeLink(milestone, link.id)}>{t.scLinkRemove}</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function Chips({ milestone, api }: { milestone: DmMilestone; api: MilestoneApi }) {
  if (milestone.links.length === 0) return null;
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {milestone.links.map((link) => (
        <LinkChip key={link.id} milestone={milestone.id} link={link} api={api} />
      ))}
    </div>
  );
}

/** El título en negrita antes del cuerpo se lee como una frase: se cierra con
 *  punto si no trae signo propio. */
const sentence = (title: string) => (/[.:!?…]$/.test(title) ? title : `${title}.`);

function NoteCard({ milestone, note, api }: { milestone: string; note: DmScriptNote; api: MilestoneApi }) {
  const t = useTexts();
  const { icon: Icon, text, border } = NOTE_STYLE[note.kind];
  const check = api.checkLabels[note.id];
  return (
    <li className={cx('plaque flex min-w-0 flex-col gap-1.5 p-3', border)} data-note={note.kind}>
      <div className={cx('flex items-center gap-1.5', text)}>
        <Icon size={14} aria-hidden="true" className="shrink-0" />
        <span className="eyebrow min-w-0 !text-current">{t.scNoteKinds[note.kind]}</span>
        <MoreMenu
          label={t.scNoteOptions}
          action="note-menu"
          className="-my-2 -mr-2 ml-auto"
          items={[
            { label: t.commonEdit, icon: Pencil, onSelect: () => api.editNote(milestone, note) },
            { label: t.commonDelete, icon: Trash2, danger: true, onSelect: () => api.removeNote(milestone, note) },
          ]}
        />
      </div>
      {check && (
        <div>
          <span className="inline-block rounded-[var(--radius-pill)] border border-hairline bg-plaque px-2 py-0.5 text-[11px] text-text-muted tabular-nums">
            {check}
          </span>
        </div>
      )}
      {note.kind === 'readAloud' ? (
        note.body && (
          <p className="font-display text-[14px] leading-[1.45] break-words whitespace-pre-line text-on-surface italic">
            {t.scQuote(note.body)}
          </p>
        )
      ) : (
        (note.title || note.body) && (
          <p className="text-[13px] leading-[1.45] break-words whitespace-pre-line text-on-surface-variant">
            {note.title && <b className="font-medium text-on-surface">{sentence(note.title)} </b>}
            {note.body}
          </p>
        )
      )}
    </li>
  );
}

/** El menú «Agregar al hito»: las seis clases de nota y lo que se puede vincular. */
function AddMenu({ milestone, api }: { milestone: string; api: MilestoneApi }) {
  const t = useTexts();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          tone="secondary"
          icon={Plus}
          data-action="add-to-milestone"
          aria-label={t.scAddToMilestone}
          className="!min-h-10 !px-3 text-[13.5px] !text-on-surface-variant"
        >
          {t.scAdd}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" aria-label={t.scAddToMilestone} className="w-[300px] p-1.5">
        <DropdownMenuLabel>{t.scNoteGroup}</DropdownMenuLabel>
        {SCRIPT_NOTE_KINDS.map((kind) => {
          const { icon: Icon, text } = NOTE_STYLE[kind];
          return (
            <DropdownMenuItem key={kind} onSelect={() => api.addNote(milestone, kind)} className="min-h-10 !gap-3">
              <Icon size={16} aria-hidden="true" className={text} />
              {t.scNoteKinds[kind]}
            </DropdownMenuItem>
          );
        })}
        <DropdownMenuSeparator />
        <DropdownMenuLabel>{t.scLinkGroup}</DropdownMenuLabel>
        {LINK_TYPES.filter((type) => type !== 'music' || api.scenes !== null).map((type) => {
          const Icon = LINK_ICONS[type];
          return (
            <DropdownMenuItem key={type} onSelect={() => api.addLink(milestone, type)} className="min-h-10 !gap-3">
              <Icon size={16} aria-hidden="true" className="text-text-muted" />
              {t.scLinkKinds[type]}
              <span aria-hidden="true" className="ml-auto text-[12px] text-text-muted">
                ›
              </span>
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function EndsHerePill() {
  const t = useTexts();
  return (
    <span className="rounded-[var(--radius-pill)] border border-hairline bg-plaque px-2 py-0.5 text-[11px] text-text-muted">
      {t.scEndsHere}
    </span>
  );
}

/**
 * Un hito, o un camino de una bifurcación ([path]), plegado o desplegado.
 * El título es el botón que pliega: nada se pliega ni se despliega solo. Los
 * botones del título llevan `data-reorder-grab` para que tomarlos mueva el paso
 * (`useHoldDrag`), como el resto de la tarjeta.
 */
export function MilestoneCard({
  milestone,
  number,
  current,
  expanded,
  path,
  menu,
  api,
}: {
  milestone: DmMilestone;
  /** «3» o «4a». */
  number: string;
  current: boolean;
  expanded: boolean;
  path: boolean;
  menu: { label: string; items: MenuEntry[] };
  api: MilestoneApi;
}) {
  const t = useTexts();
  const name = `${number}. ${milestone.title || t.scUntitled}`;
  const counts = [
    milestone.notes.length > 0 && t.dmNotesCount(milestone.notes.length),
    // En un camino plegado los vínculos ya se ven como chips.
    !path && milestone.links.length > 0 && t.scLinksCount(milestone.links.length),
  ]
    .filter(Boolean)
    .join(' · ');
  const toggle = () => api.toggle(milestone.id);
  const shared = { id: `hito-${milestone.id}`, 'data-milestone': milestone.id };
  const options = <MoreMenu label={menu.label} action="milestone-menu" items={menu.items} className="relative z-10 -mt-1 -mr-1" />;

  if (!expanded && !path) {
    return (
      <h2 {...shared}>
        <button
          type="button"
          aria-expanded={false}
          data-reorder-grab
          onClick={toggle}
          className="card pick flex min-h-12 w-full flex-wrap items-center gap-x-3 px-3.5 py-1.5 text-left"
        >
          <span className="font-display min-w-0 flex-1 text-[16px] break-words text-on-surface-variant">{name}</span>
          {counts && <span className="text-[12.5px] text-text-muted">{counts}</span>}
          <ChevronDown size={14} aria-hidden="true" className="shrink-0 text-text-muted" />
        </button>
      </h2>
    );
  }
  if (!expanded) {
    return (
      <article {...shared} className="card relative flex h-full flex-col gap-2 px-4 py-3.5">
        <div className="flex items-start gap-2">
          <div className="flex min-w-0 flex-1 flex-col gap-2">
            {milestone.condition && <span className="text-[12.5px] break-words text-text-muted">{milestone.condition}</span>}
            <h2 className="font-display text-[16px] break-words text-on-surface">
              {/* El `::after` estira el botón a toda la tarjeta. */}
              <button type="button" aria-expanded={false} data-reorder-grab onClick={toggle} className="text-left after:absolute after:inset-0">
                {name}
              </button>
            </h2>
          </div>
          {options}
        </div>
        {milestone.endsHere && (
          <div>
            <EndsHerePill />
          </div>
        )}
        <Chips milestone={milestone} api={api} />
        {counts && <span className="text-[12.5px] text-text-muted">{counts}</span>}
      </article>
    );
  }
  return (
    <article
      {...shared}
      aria-current={current ? 'step' : undefined}
      className={cx('card flex min-w-0 flex-col gap-3.5', current ? 'border-2 border-gold p-[15px]' : 'p-4')}
    >
      <div className="flex items-start gap-2.5">
        <div className="min-w-0 flex-1">
          {current && <p className="text-[12px] font-medium text-gold">{t.scNow}</p>}
          {path && milestone.condition && <p className="text-[12.5px] break-words text-text-muted">{milestone.condition}</p>}
          <h2 className={cx('font-display text-[18px] break-words text-on-surface', (current || (path && milestone.condition)) && 'mt-1.5')}>
            <button type="button" aria-expanded data-reorder-grab onClick={toggle} className="flex items-center gap-2 text-left">
              <span className="min-w-0 break-words">{name}</span>
              <ChevronUp size={14} aria-hidden="true" className="shrink-0 text-text-muted" />
            </button>
          </h2>
          {path && milestone.endsHere && (
            <div className="mt-2">
              <EndsHerePill />
            </div>
          )}
        </div>
        {options}
      </div>
      {milestone.description && (
        <p className="text-[14px] leading-[1.55] break-words whitespace-pre-line text-on-surface-variant">{milestone.description}</p>
      )}
      <Chips milestone={milestone} api={api} />
      {milestone.notes.length > 0 && (
        <ul className="grid grid-cols-[repeat(auto-fill,minmax(min(200px,100%),1fr))] items-start gap-2.5">
          {milestone.notes.map((note) => (
            <NoteCard key={note.id} milestone={milestone.id} note={note} api={api} />
          ))}
        </ul>
      )}
      <div className="flex flex-wrap items-center gap-3 border-t border-hairline pt-3.5">
        <AddMenu milestone={milestone.id} api={api} />
      </div>
    </article>
  );
}
