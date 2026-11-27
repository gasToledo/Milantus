import { Check, ChevronDown, ChevronUp, EllipsisVertical, Pencil, Plus, Trash2, type LucideIcon } from 'lucide-react';
import {
  SCRIPT_NOTE_KINDS,
  type DmMilestone,
  type DmMilestoneState,
  type DmScriptLink,
  type DmScriptNote,
  type MusicScene,
  type ScriptNoteKind,
} from '../../api/client';
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
import { LINK_ICONS, NOTE_STYLE, SHAREABLE_NOTES, type ScriptLinkType } from './kinds';

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
  /** Compartir una nota con los jugadores; `null` en la Biblioteca. */
  share: { done: ReadonlySet<string>; run: (milestone: string, note: DmScriptNote) => void } | null;
  /** El modo En juego: todo de solo lectura salvo lo que trae acá. `null` es
   *  el modo Editar. */
  play: { busy: boolean; reach: () => void; writeNote: () => void } | null;
}

export interface MenuEntry {
  label: string;
  icon?: LucideIcon;
  /** En `data-action`. */
  action?: string;
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
        {items.map(({ label: text, icon: Icon, action: itemAction, onSelect, danger, blocked }) => (
          <DropdownMenuItem
            key={text}
            data-action={itemAction}
            aria-disabled={blocked || undefined}
            onSelect={(e) => (blocked ? e.preventDefault() : onSelect())}
            className={cx(danger && 'text-crimson', blocked && 'opacity-45')}
          >
            {Icon && <Icon size={15} aria-hidden="true" className={danger ? undefined : 'text-text-muted'} />}
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
  const className = cx(
    // Encima del enlace estirado de la tarjeta de un camino plegado.
    'relative z-10 inline-flex min-h-7 max-w-full items-center gap-1.5 rounded-[var(--radius-pill)] border px-2.5 py-0.5 text-left text-[12.5px]',
    missing ? 'border-dashed border-hairline text-text-muted' : 'border-hairline bg-plaque text-on-surface-variant',
  );
  const content = (
    <>
      <Icon size={14} aria-hidden="true" className="shrink-0" />
      <span className="min-w-0 break-words">{missing ? t.scLinkMissing(linkName(link)) : linkName(link)}</span>
      {hp && <span className="num whitespace-nowrap text-verdant">{hp}</span>}
    </>
  );
  // En juego tocar el chip abre lo vinculado: no hay nada que editar.
  if (api.play) {
    // ponytail: el chip de música no hace nada en juego. La escena actual vive
    // adentro de `MusicPlayer`; para ponerla desde acá hay que subir ese estado.
    return open && !missing ? (
      <button type="button" data-link={link.type} onClick={open} className={cx('pick', className)}>
        {content}
      </button>
    ) : (
      <span data-link={link.type} className={className}>
        {content}
      </span>
    );
  }
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button type="button" data-link={link.type} className={cx('pick', className)}>
          {content}
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

/** [npcRows]: en el teléfono los PNJ van aparte, como filas (`NpcRows`). */
function Chips({ milestone, api, npcRows = false }: { milestone: DmMilestone; api: MilestoneApi; npcRows?: boolean }) {
  const { links } = milestone;
  if (links.length === 0) return null;
  return (
    <div className={cx('flex flex-wrap items-center gap-1.5', npcRows && links.every((l) => l.type === 'npc') && 'max-shell:hidden')}>
      {links.map((link) => (
        <span key={link.id} className={cx('contents', npcRows && link.type === 'npc' && 'max-shell:hidden')}>
          <LinkChip milestone={milestone.id} link={link} api={api} />
        </span>
      ))}
    </div>
  );
}

/** Los PNJ del hito actual en el teléfono: filas fáciles de tocar. */
function NpcRows({ milestone, api }: { milestone: DmMilestone; api: MilestoneApi }) {
  return milestone.links.map((link) => {
    if (link.type !== 'npc') return null;
    const hp = api.npcHp.get(link.npcId);
    return (
      <button
        key={link.id}
        type="button"
        data-npc-row
        onClick={api.openLink(link) ?? undefined}
        className="plaque pick flex min-h-12 items-center gap-2.5 px-3 text-left shell:hidden"
      >
        <span
          aria-hidden="true"
          className="font-display flex size-8 shrink-0 items-center justify-center rounded-full border-2 border-gold text-on-surface-variant"
        >
          {link.name.charAt(0).toUpperCase()}
        </span>
        <span className="min-w-0 flex-1 break-words text-on-surface">{link.name}</span>
        {hp && <span className="num font-bold whitespace-nowrap text-verdant">{hp}</span>}
      </button>
    );
  });
}

/** El título en negrita antes del cuerpo se lee como una frase: se cierra con
 *  punto si no trae signo propio. */
const sentence = (title: string) => (/[.:!?…]$/.test(title) ? title : `${title}.`);

function NoteCard({ milestone, note, api }: { milestone: string; note: DmScriptNote; api: MilestoneApi }) {
  const t = useTexts();
  const { icon: Icon, text, border } = NOTE_STYLE[note.kind];
  const check = api.checkLabels[note.id];
  const { share } = api;
  const shared = share?.done.has(note.id) ?? false;
  const shareEntry: MenuEntry[] =
    share && !shared && SHAREABLE_NOTES.has(note.kind)
      ? [{ label: t.scShare, action: 'share-note', onSelect: () => share.run(milestone, note) }]
      : [];
  // En juego compartir es lo único que se le hace a una nota.
  const items: MenuEntry[] = api.play
    ? shareEntry
    : [
        { label: t.commonEdit, icon: Pencil, onSelect: () => api.editNote(milestone, note) },
        ...shareEntry,
        { label: t.commonDelete, icon: Trash2, danger: true, onSelect: () => api.removeNote(milestone, note) },
      ];
  return (
    <li className={cx('plaque flex min-w-0 flex-col gap-1.5 p-3', border)} data-note={note.kind}>
      <div className={cx('flex items-center gap-1.5', text)}>
        <Icon size={14} aria-hidden="true" className="shrink-0" />
        <span className="eyebrow min-w-0 !text-current">{t.scNoteKinds[note.kind]}</span>
        <span className="ml-auto flex items-center gap-1">
          {shared && (
            <span className="rounded-[var(--radius-pill)] border border-gold bg-gold-soft px-2 py-px text-[11px] text-gold">
              {t.scSharedPill}
            </span>
          )}
          {items.length > 0 && <MoreMenu label={t.scNoteOptions} action="note-menu" className="-my-2 -mr-2" items={items} />}
        </span>
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
  state,
  expanded,
  path,
  menu,
  api,
}: {
  milestone: DmMilestone;
  /** «3» o «4a». */
  number: string;
  state: DmMilestoneState;
  expanded: boolean;
  path: boolean;
  /** `null`: sin ⋮. */
  menu: { label: string; items: MenuEntry[] } | null;
  api: MilestoneApi;
}) {
  const t = useTexts();
  const { play } = api;
  const current = state === 'current';
  // En juego, lo que no se tomó queda apagado y punteado.
  const dropped = play !== null && state === 'notTaken';
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
  const options = (className: string) =>
    menu && <MoreMenu label={menu.label} action="milestone-menu" items={menu.items} className={cx('relative z-10', className)} />;
  const surface = dropped ? 'rounded-[var(--radius-card)] border border-dashed border-hairline' : 'card';
  const notTaken = dropped && <span className="block text-[12px] text-text-muted">{t.scNotTaken}</span>;
  // En el teléfono no hay riel: el ✓ de un alcanzado va en la fila.
  const check = play && state === 'reached' && (
    <span className="shrink-0 text-verdant shell:hidden">
      <Check size={14} aria-hidden="true" />
      <span className="sr-only">{t.scReached}</span>
    </span>
  );

  if (!expanded && !path) {
    return (
      <div {...shared} className={cx(surface, 'pick flex min-h-12 items-center', play && menu && 'pr-1.5')}>
        <h2 className="min-w-0 flex-1">
          <button
            type="button"
            aria-expanded={false}
            data-reorder-grab
            onClick={toggle}
            className={cx('flex min-h-12 w-full flex-wrap items-center gap-x-3 px-3.5 py-1.5 text-left', play && 'max-shell:flex-nowrap')}
          >
            {check}
            <span className={cx('min-w-0 flex-1', dropped ? 'text-text-muted' : 'text-on-surface-variant')}>
              {notTaken}
              <span
                className={cx(
                  'block text-[16px] break-words',
                  // En el teléfono la fila va en la letra de cuerpo (la lámina).
                  play ? 'shell:font-[family-name:var(--font-display)] max-shell:truncate max-shell:text-[14px]' : 'font-display',
                )}
              >
                {name}
              </span>
            </span>
            {counts && !dropped && <span className={cx('text-[12.5px] text-text-muted', play && 'max-shell:hidden')}>{counts}</span>}
            <ChevronDown size={14} aria-hidden="true" className={cx('shrink-0 text-text-muted', play && 'max-shell:hidden')} />
          </button>
        </h2>
        {play && options('')}
      </div>
    );
  }
  if (!expanded) {
    // En juego y en el teléfono, un camino por venir o alcanzado es una fila.
    const row = play !== null && !dropped && !current;
    const detail = row ? 'max-shell:hidden' : undefined;
    return (
      <article
        {...shared}
        className={cx(
          surface,
          'relative flex h-full flex-col gap-2 px-4 py-3.5',
          row && 'max-shell:min-h-12 max-shell:justify-center max-shell:py-2',
          play && current && '!border-2 !border-gold',
        )}
      >
        <div className={cx('flex items-start gap-2', row && 'max-shell:items-center')}>
          {check}
          <div className="flex min-w-0 flex-1 flex-col gap-2">
            {notTaken}
            {play && current && <span className="text-[12px] font-medium text-gold">{t.scNow}</span>}
            {!dropped && milestone.condition && (
              <span className={cx('text-[12.5px] break-words text-text-muted', detail)}>{milestone.condition}</span>
            )}
            <h2
              className={cx(
                'text-[16px] break-words',
                dropped ? 'text-text-muted' : 'text-on-surface',
                row ? 'shell:font-[family-name:var(--font-display)] max-shell:text-[14px]' : 'font-display',
              )}
            >
              {/* El `::after` estira el botón a toda la tarjeta. */}
              <button type="button" aria-expanded={false} data-reorder-grab onClick={toggle} className="text-left after:absolute after:inset-0">
                {row && state === 'pending' ? (
                  <>
                    <span className="eyebrow mr-2.5 shell:hidden">{number}</span>
                    <span className="max-shell:hidden">{number}. </span>
                    {milestone.title || t.scUntitled}
                  </>
                ) : (
                  name
                )}
              </button>
            </h2>
          </div>
          {options('-mt-1 -mr-1')}
        </div>
        {!dropped && (
          <>
            {milestone.endsHere && (
              <div className={detail}>
                <EndsHerePill />
              </div>
            )}
            {milestone.links.length > 0 && (
              <div className={detail}>
                <Chips milestone={milestone} api={api} />
              </div>
            )}
            {counts && <span className={cx('text-[12.5px] text-text-muted', detail)}>{counts}</span>}
          </>
        )}
      </article>
    );
  }
  const npcRows = play !== null && current;
  return (
    <article
      {...shared}
      aria-current={current ? 'step' : undefined}
      className={cx(
        surface,
        'flex min-w-0 flex-col gap-3.5',
        current ? '!border-2 !border-gold p-[15px]' : 'p-4',
        play && current && 'max-shell:gap-2.5 max-shell:p-[13px]',
      )}
    >
      <div className="flex items-start gap-2.5">
        <div className="min-w-0 flex-1">
          {current && <p className="text-[12px] font-medium text-gold">{t.scNow}</p>}
          {notTaken}
          {path && milestone.condition && <p className="text-[12.5px] break-words text-text-muted">{milestone.condition}</p>}
          <h2
            className={cx(
              'font-display text-[18px] break-words',
              dropped ? 'text-text-muted' : 'text-on-surface',
              (current || dropped || (path && milestone.condition)) && 'mt-1.5',
              play && 'max-shell:text-[17px]',
            )}
          >
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
        {options('-mt-1 -mr-1')}
      </div>
      {milestone.description && (
        <p
          className={cx(
            'text-[14px] leading-[1.55] break-words whitespace-pre-line text-on-surface-variant',
            play && 'max-shell:text-[13.5px] max-shell:leading-normal',
          )}
        >
          {milestone.description}
        </p>
      )}
      <Chips milestone={milestone} api={api} npcRows={npcRows} />
      {milestone.notes.length > 0 && (
        <ul className="grid grid-cols-[repeat(auto-fill,minmax(min(200px,100%),1fr))] items-start gap-2.5">
          {milestone.notes.map((note) => (
            <NoteCard key={note.id} milestone={milestone.id} note={note} api={api} />
          ))}
        </ul>
      )}
      {npcRows && <NpcRows milestone={milestone} api={api} />}
      {play === null ? (
        <div className="flex flex-wrap items-center gap-3 border-t border-hairline pt-3.5">
          <AddMenu milestone={milestone.id} api={api} />
        </div>
      ) : (
        current && (
          <div className="flex flex-wrap items-center gap-3 border-t border-hairline pt-3.5 max-shell:gap-2 max-shell:border-t-0 max-shell:pt-0">
            <Button
              tone="secondary"
              icon={Pencil}
              data-action="milestone-note"
              onClick={play.writeNote}
              className="!min-h-10 !px-3 text-[13.5px] !text-on-surface-variant max-shell:!min-h-12"
            >
              {t.dmWriteNote}
            </Button>
            <Button
              icon={Check}
              data-action="reach-milestone"
              disabled={play.busy}
              aria-busy={play.busy}
              onClick={play.reach}
              className="ml-auto !min-h-11 !bg-verdant !px-[18px] max-shell:!min-h-12 max-shell:flex-1"
            >
              {t.scMarkReached}
            </Button>
          </div>
        )
      )}
    </article>
  );
}
