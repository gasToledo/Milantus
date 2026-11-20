import { useId, useLayoutEffect, useMemo, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';
import * as PopoverPrimitive from '@radix-ui/react-popover';
import { MapPin, Plus } from 'lucide-react';
import { fold } from '../../codex/entries';
import { useTexts } from '../../i18n/context';
import { cx } from '../../ui/cx';
import { Medallion } from '../../ui/Medallion';
import { mentionedNames } from '../../ui/mentions';
import { Popover, PopoverContent } from '../../ui/primitives';
import { NewNpcDialog } from '../npcs/NewNpcDialog';
import { ScenarioEditorDialog } from '../scenarios/ScenarioEditorDialog';
import type { MentionTarget } from './targets';

/** Cuántos se ofrecen por grupo: el selector es para nombrar, no para hojear. */
const PER_GROUP = 6;
/** Una `@` más lejos que esto del cursor ya no es una mención a medio escribir. */
const MAX_QUERY = 40;

/** La `@` que se está escribiendo: dónde empieza y lo que va tecleado después. */
interface Open {
  at: number;
  end: number;
  query: string;
}

/**
 * Lo que se escribe entre la `@` y el cursor, si es una mención a medio
 * escribir: la `@` abre una palabra (la de un correo no), no hay salto de
 * línea en el medio y todavía no completa un nombre seguido de espacio.
 */
function openMention(text: string, caret: number, names: readonly string[]): Open | null {
  const at = text.lastIndexOf('@', caret - 1);
  if (at < 0 || caret - at - 1 > MAX_QUERY) return null;
  if (at > 0 && /[\p{L}\p{N}]/u.test(text[at - 1]!)) return null;
  const query = text.slice(at + 1, caret);
  if (query.includes('\n')) return null;
  const typed = fold(query);
  if (names.some((n) => typed.startsWith(fold(n) + ' '))) return null;
  return { at, end: caret, query };
}

/** Dónde queda el cursor dentro del campo, para abrir el selector ahí y no
 *  debajo de todo el texto. Un espejo invisible con la misma tipografía. */
function caretPoint(area: HTMLTextAreaElement, index: number): { top: number; left: number } {
  const style = getComputedStyle(area);
  const mirror = document.createElement('div');
  for (const p of ['boxSizing', 'width', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'borderTopWidth', 'borderLeftWidth', 'fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing'] as const) {
    mirror.style[p] = style[p];
  }
  Object.assign(mirror.style, { position: 'absolute', visibility: 'hidden', whiteSpace: 'pre-wrap', overflowWrap: 'break-word', top: '0', left: '0' });
  mirror.textContent = area.value.slice(0, index);
  const mark = document.createElement('span');
  mark.textContent = '​';
  mirror.appendChild(mark);
  document.body.appendChild(mirror);
  const lineHeight = parseFloat(style.lineHeight) || parseFloat(style.fontSize) * 1.5;
  const point = { top: mark.offsetTop - area.scrollTop + lineHeight, left: Math.min(mark.offsetLeft, area.clientWidth - 24) };
  mirror.remove();
  return point;
}

type Row =
  | { type: 'target'; target: MentionTarget }
  | { type: 'create'; kind: 'npc' | 'scene' };

/**
 * Un `textarea` que nombra con `@`: al escribirla se abre, junto al cursor, la
 * lista de lo que se puede mencionar (primero lo de la campaña, después el
 * resto de la Biblioteca). Las flechas eligen, Enter o Tab insertan `@Nombre `
 * y Esc la cierra; el foco nunca sale del texto. Si nadie se llama así, ofrece
 * crear un PNJ o un escenario con ese nombre: al guardarlo entra la mención y
 * el foco vuelve al texto, donde estaba.
 *
 * Debajo van las menciones del borrador como pills: tocarlas abre el panel
 * ([onOpenMention]) sin cerrar el editor.
 */
export function MentionTextarea({
  value,
  onChange,
  targets,
  campaignId,
  onOpenMention,
  openKey,
  hint,
  className,
  ...rest
}: {
  value: string;
  onChange: (value: string) => void;
  targets: readonly MentionTarget[];
  campaignId: string;
  onOpenMention: (target: MentionTarget) => void;
  /** La mención con el panel abierto, que su pill marca. */
  openKey?: string | null;
  hint?: ReactNode;
  className?: string;
  placeholder?: string;
  'data-field'?: string;
  'aria-label'?: string;
  id?: string;
}) {
  const t = useTexts();
  const listId = useId();
  const area = useRef<HTMLTextAreaElement>(null);
  const [caret, setCaret] = useState<number | null>(null);
  const [active, setActive] = useState(0);
  // La `@` que se cerró con Esc no se vuelve a abrir sola hasta otra.
  const [dismissed, setDismissed] = useState<number | null>(null);
  const [creating, setCreating] = useState<{ kind: 'npc' | 'scene'; open: Open } | null>(null);
  // Después de insertar, el cursor va detrás de lo insertado.
  const pendingCaret = useRef<number | null>(null);

  const names = useMemo(() => targets.map((x) => x.name), [targets]);
  const open = caret === null || creating ? null : openMention(value, caret, names);
  const shown = open && open.at !== dismissed ? open : null;

  const rows = useMemo((): { near: Row[]; far: Row[]; create: Row[] } => {
    if (!shown) return { near: [], far: [], create: [] };
    const q = fold(shown.query.trim());
    const fits = (x: MentionTarget) => {
      const n = fold(x.name);
      return q === '' || n.startsWith(q) || n.split(/\s+/).some((w) => w.startsWith(q)) || (q.includes(' ') && n.includes(q));
    };
    const hits = targets.filter(fits);
    const exact = targets.some((x) => fold(x.name) === q);
    return {
      near: hits.filter((x) => x.near).slice(0, PER_GROUP).map((target) => ({ type: 'target', target })),
      far: hits.filter((x) => !x.near).slice(0, PER_GROUP).map((target) => ({ type: 'target', target })),
      create: q !== '' && !exact ? [{ type: 'create', kind: 'npc' }, { type: 'create', kind: 'scene' }] : [],
    };
  }, [shown, targets]);
  const flat = [...rows.near, ...rows.far, ...rows.create];
  const current = Math.min(active, Math.max(0, flat.length - 1));

  // En cada commit: el cursor pendiente vive en un ref (no rearma un efecto) y
  // se escribe en el mismo turno que el texto o el diálogo. Con dependencias
  // vacías no se movería al insertar; las corridas de más no hacen nada.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useLayoutEffect(() => {
    const at = pendingCaret.current;
    if (at === null || !area.current) return;
    pendingCaret.current = null;
    area.current.focus();
    area.current.setSelectionRange(at, at);
    setCaret(at);
  });

  const insert = (name: string, range: Open) => {
    const piece = `@${name} `;
    onChange(value.slice(0, range.at) + piece + value.slice(range.end));
    pendingCaret.current = range.at + piece.length;
    setActive(0);
    // Lo recién creado todavía no está en la lista: sin esto, el selector se
    // reabriría ofreciendo crearlo otra vez.
    setDismissed(range.at);
  };

  const choose = (row: Row) => {
    if (!shown) return;
    if (row.type === 'target') insert(row.target.name, shown);
    else setCreating({ kind: row.kind, open: shown });
  };

  const onKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (!shown || flat.length === 0) return;
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const step = event.key === 'ArrowDown' ? 1 : -1;
      setActive((current + step + flat.length) % flat.length);
    } else if (event.key === 'Enter' || event.key === 'Tab') {
      event.preventDefault();
      choose(flat[current]!);
    } else if (event.key === 'Escape') {
      // Cierra el selector y no el diálogo que lo contiene.
      event.preventDefault();
      event.stopPropagation();
      setDismissed(shown.at);
    }
  };

  const track = () => {
    const el = area.current;
    if (el) setCaret(el.selectionStart === el.selectionEnd ? el.selectionStart : null);
  };

  const point = shown && area.current ? caretPoint(area.current, shown.at) : { top: 0, left: 0 };
  const optionId = (i: number) => `${listId}-${i}`;
  const mentioned = mentionedNames(value, names)
    .map((name) => targets.find((x) => x.name === name))
    .filter((x): x is MentionTarget => x !== undefined);

  let index = -1;
  const renderRow = (row: Row) => {
    index += 1;
    const i = index;
    const on = i === current;
    const label = row.type === 'target' ? row.target.name : row.kind === 'npc' ? t.mentionCreateNpc(shown!.query.trim()) : t.mentionCreateScene(shown!.query.trim());
    return (
      <div
        key={row.type === 'target' ? row.target.key : `create-${row.kind}`}
        id={optionId(i)}
        role="option"
        aria-selected={on}
        // `mousedown` y no `click`: así el foco no sale del texto.
        onMouseDown={(event) => {
          event.preventDefault();
          choose(row);
        }}
        onMouseEnter={() => setActive(i)}
        className={cx('flex min-h-11 cursor-pointer items-center gap-2.5 rounded-[var(--radius-nav)] px-2 py-1', on ? 'bg-gold-soft' : 'hover:bg-plaque')}
      >
        {row.type === 'target' ? (
          row.target.kind === 'scene' ? (
            <span className="flex h-[30px] w-10 shrink-0 items-center justify-center overflow-hidden rounded-[6px] border border-hairline bg-plaque text-text-muted">
              <MapPin size={16} strokeWidth={1.8} aria-hidden="true" />
            </span>
          ) : (
            <Medallion name={row.target.name} accent={null} size={30} portrait={row.target.portrait} />
          )
        ) : (
          <span className={cx('flex h-[30px] shrink-0 items-center justify-center border border-hairline bg-plaque text-gold', row.kind === 'npc' ? 'w-[30px] rounded-full' : 'w-10 rounded-[6px]')}>
            <Plus size={16} strokeWidth={2.2} aria-hidden="true" />
          </span>
        )}
        <span className="min-w-0 flex-1">
          <span className={cx('block truncate text-[14px]', on ? 'text-gold' : 'text-on-surface')}>{label}</span>
          {row.type === 'target' && <span className="block truncate text-[12px] text-text-muted">{row.target.sub}</span>}
        </span>
      </div>
    );
  };

  const created = (name: string) => {
    if (!creating) return;
    const range = creating.open;
    setCreating(null);
    insert(name, range);
  };

  return (
    <>
      <Popover open={shown !== null && flat.length > 0}>
        <div className="relative">
          <PopoverPrimitive.Anchor asChild>
            <span aria-hidden="true" className="pointer-events-none absolute h-0 w-0" style={{ top: point.top, left: point.left }} />
          </PopoverPrimitive.Anchor>
          <textarea
            ref={area}
            value={value}
            onChange={(event) => {
              onChange(event.target.value);
              if (dismissed !== null && event.target.value[dismissed] !== '@') setDismissed(null);
              setCaret(event.target.selectionStart);
              setActive(0);
            }}
            onSelect={track}
            onClick={track}
            onKeyUp={(event) => {
              if (!['ArrowDown', 'ArrowUp', 'Enter', 'Tab', 'Escape'].includes(event.key)) track();
            }}
            onBlur={() => setCaret(null)}
            onKeyDown={onKeyDown}
            role="combobox"
            aria-autocomplete="list"
            aria-expanded={shown !== null && flat.length > 0}
            aria-controls={listId}
            aria-activedescendant={shown && flat.length > 0 ? optionId(current) : undefined}
            className={className}
            {...rest}
          />
        </div>
        <PopoverContent
          side="bottom"
          align="start"
          sideOffset={4}
          onOpenAutoFocus={(event) => event.preventDefault()}
          onCloseAutoFocus={(event) => event.preventDefault()}
          onEscapeKeyDown={() => shown && setDismissed(shown.at)}
          onInteractOutside={(event) => {
            if (event.target === area.current) event.preventDefault();
            else setCaret(null);
          }}
          className="w-[380px] p-1.5"
        >
          <div id={listId} role="listbox" aria-label={t.mentionListLabel} className="max-h-[min(360px,50vh)] overflow-y-auto">
            {rows.near.length > 0 && (
              <div role="group" aria-label={t.mentionGroupCampaign}>
                <div className="eyebrow px-2 pt-2 pb-1">{t.mentionGroupCampaign}</div>
                {rows.near.map(renderRow)}
              </div>
            )}
            {rows.far.length > 0 && (
              <div role="group" aria-label={t.mentionGroupLibrary}>
                <div className="eyebrow px-2 pt-2 pb-1">{t.mentionGroupLibrary}</div>
                {rows.far.map(renderRow)}
              </div>
            )}
            {rows.create.length > 0 && (
              <div className={cx(rows.near.length + rows.far.length > 0 && 'mt-1 border-t border-hairline pt-1')}>{rows.create.map(renderRow)}</div>
            )}
          </div>
        </PopoverContent>
      </Popover>
      {hint}
      {mentioned.length > 0 && (
        <div className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.mentionsLabel}</span>
          <ul className="flex flex-wrap gap-1.5">
            {mentioned.map((target) => {
              const on = openKey === target.key;
              return (
                <li key={target.key}>
                  <button
                    type="button"
                    aria-pressed={on}
                    onClick={() => onOpenMention(target)}
                    className={cx(
                      'pick inline-flex h-[30px] items-center rounded-[var(--radius-pill)] border px-3 text-[13px] text-gold',
                      on ? 'border-gold-soft bg-gold-soft font-semibold' : 'border-hairline bg-plaque hover:border-gold',
                    )}
                  >
                    {target.name}
                  </button>
                </li>
              );
            })}
          </ul>
        </div>
      )}
      {creating?.kind === 'npc' && (
        <NewNpcDialog
          campaignId={campaignId}
          initialName={creating.open.query.trim()}
          onCreated={created}
          onClose={() => {
            setCreating(null);
            pendingCaret.current = creating.open.end;
          }}
        />
      )}
      {creating?.kind === 'scene' && (
        <ScenarioEditorDialog
          initialName={creating.open.query.trim()}
          onSaved={(scenario) => created(scenario.name)}
          onClose={() => {
            if (creating) pendingCaret.current = creating.open.end;
            setCreating(null);
          }}
        />
      )}
    </>
  );
}
