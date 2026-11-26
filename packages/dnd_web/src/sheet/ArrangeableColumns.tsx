import { Fragment, useContext, useEffect, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { ArrowDown, ArrowLeft, ArrowRight, ArrowUp, GripVertical, SlidersHorizontal, type LucideIcon } from 'lucide-react';
import { useRosterSettings } from '../api/queries';
import { useTexts } from '../i18n/context';
import { cx } from '../ui/cx';
import { useHoldDrag } from '../ui/holdDrag';
import { Tooltip } from '../ui/primitives';
import { moveCard, resolveLayout, type CardLayout } from './cardLayout';
import { CustomizePanel } from './CustomizePanel';
import type { SheetModel } from './model';
import { SheetCustomizeContext } from './sheetCustomize';
import { useCardLayoutSaver } from './useCardLayoutSaver';

type Tab = 'combate' | 'personaje';

const FIN = '__fin-';
const isEnd = (id: string) => id.startsWith(FIN);
const AT_END = Number.MAX_SAFE_INTEGER;

const PILL_SHAPE =
  'inline-flex min-h-7 items-center gap-1.5 rounded-[var(--radius-pill)] border border-gold px-3 text-[12.5px] font-medium transition-colors duration-[120ms] ease-out';
/** La pill dorada chica de la barra de la pestaña («Personalizar ficha»,
 *  «Cambiar elecciones»). Sin `Button`: su alto mínimo de 36 px no se puede
 *  achicar con una clase más (`cx` no las combina). */
export const SHEET_PILL = cx(PILL_SHAPE, 'bg-gold-soft text-gold hover:bg-plaque');
/** La misma, apretada: el panel está abierto. */
const SHEET_PILL_PRESSED = cx(PILL_SHAPE, 'bg-gold text-on-primary');

/**
 * Las tres columnas de una pestaña de la ficha, con «Personalizar ficha»:
 * abierto, se dibuja su panel y las tarjetas se acomodan. El orden es una
 * preferencia de **quien mira** (los ajustes de la cuenta, `sheetLayout`) y
 * nunca del personaje: vale para toda ficha que esa cuenta abra, propia, ajena
 * o de PNJ, y no escribe ninguna.
 *
 * [cards] lleva solo las tarjetas presentes en esta ficha. Acomodando, el
 * contenido no se dibuja: cada tarjeta es una barra con su título.
 */
export function ArrangeableColumns({
  model,
  tab,
  defaults,
  cards,
  leading,
}: {
  model: SheetModel;
  tab: Tab;
  defaults: CardLayout;
  cards: Record<string, { title: string; node: ReactNode }>;
  /** Otra pill de la barra, en la otra punta (izquierda) de «Personalizar». */
  leading?: ReactNode;
}) {
  const t = useTexts();
  const settings = useRosterSettings();
  const { open, setOpen, slot } = useContext(SheetCustomizeContext);
  const { save, toast } = useCardLayoutSaver(tab);
  // Cambiar de pestaña (o salir de la ficha) cierra el panel.
  useEffect(() => () => setOpen(false), [setOpen]);

  const layout = resolveLayout(settings.data?.sheetLayout?.[tab], defaults, Object.keys(cards));
  const last = layout.length - 1;

  const place = (id: string, col: number, index: number) => void save(moveCard(layout, id, col, index));

  const drag = useHoldDrag({
    ids: layout.flatMap((col, c) => [...col, `${FIN}${c}`]),
    shift: false,
    canDrop: (from, to) => !isEnd(from) && to !== from,
    // Soltar sobre una tarjeta la deja **antes** de ella, venga de arriba o de
    // abajo: es lo que dibuja la línea dorada. Por eso el índice se cuenta en
    // la columna ya sin la que se mueve. Al final de la columna, su `__fin`.
    onMove: (from, to) => {
      if (isEnd(to)) return place(from, Number(to.slice(FIN.length)), AT_END);
      const col = layout.findIndex((c) => c.includes(to));
      place(from, col, layout[col]!.filter((x) => x !== from).indexOf(to));
    },
  });

  const arrow = (label: string, Icon: LucideIcon, onClick: () => void, disabled = false, className?: string) => (
    <Tooltip content={label}>
      <button
        type="button"
        aria-label={label}
        disabled={disabled}
        onClick={onClick}
        className={cx(
          'arrange-arrow inline-flex shrink-0 items-center justify-center rounded-[var(--radius-nav)] border border-hairline bg-plaque text-text-muted hover:text-on-surface disabled:opacity-35',
          className,
        )}
      >
        <Icon size={14} aria-hidden="true" />
      </button>
    </Tooltip>
  );

  return (
    <>
      {/* Pills doradas chicas y pegadas a la regla: son opcionales y no tienen
          que robarle alto a las tarjetas. «Personalizar» siempre a la derecha. */}
      <div className="-mt-2 mb-2 flex flex-wrap items-center justify-between gap-2">
        {leading ?? <span />}
        <button type="button" aria-pressed={open} onClick={() => setOpen(!open)} className={open ? SHEET_PILL_PRESSED : SHEET_PILL}>
          <SlidersHorizontal size={14} aria-hidden="true" />
          {t.customizeSheet}
        </button>
      </div>
      {open && (
        <>
          {/* Desde 1280 px el panel es la columna derecha del `Shell`; debajo,
              va acá, arriba de las tarjetas. */}
          <div className="card mb-4 p-6 min-[1280px]:hidden">
            <CustomizePanel model={model} tab={tab} />
          </div>
          {slot && createPortal(<CustomizePanel model={model} tab={tab} />, slot)}
        </>
      )}
      {!open ? (
        <div className="sheet-columns">
          <div>
            {layout.map((col, c) => (
              <div key={c} className="flex min-w-0 flex-col gap-4">
                {col.map((id) => (
                  <Fragment key={id}>{cards[id]!.node}</Fragment>
                ))}
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="sheet-columns">
          <div>
            {layout.map((col, c) => (
              <div key={c} className="arrange-col flex min-w-0 flex-col gap-2.5 rounded-[var(--radius-card)] bg-plaque p-2">
                {col.map((id, index) => {
                  const title = cards[id]!.title;
                  const item = drag.item(id);
                  const held = drag.dragging === id;
                  return (
                    <div
                      key={id}
                      {...item}
                      tabIndex={0}
                      data-arrange-card={id}
                      style={
                        held && drag.animated && item.style?.transform
                          ? { ...item.style, transform: `${item.style.transform} rotate(-1.5deg)` }
                          : item.style
                      }
                      className={cx(
                        'arrange-bar relative box-border flex touch-manipulation items-center gap-1.5 rounded-[var(--radius-card)] bg-surface py-1.5 pr-1.5 pl-2.5 select-none',
                        held ? 'cursor-grabbing border-2 border-gold' : 'cursor-grab border border-hairline',
                      )}
                    >
                      {/* Dónde cae: una línea en el hueco de arriba, porque se
                          inserta antes de esta tarjeta (no se intercambia). */}
                      {drag.over === id && (
                        <span aria-hidden="true" className="absolute inset-x-1 -top-[7px] h-0.5 rounded-full bg-gold" />
                      )}
                      <GripVertical size={16} aria-hidden="true" className="shrink-0 text-text-muted" />
                      <span className="font-display min-w-0 flex-1 text-[15px] break-words">{title}</span>
                      {c > 0 && arrow(t.moveCardLeft(title), ArrowLeft, () => place(id, c - 1, index), false, 'arrange-side')}
                      {arrow(
                        t.moveCardUp(title),
                        ArrowUp,
                        () => (index > 0 ? place(id, c, index - 1) : place(id, c - 1, AT_END)),
                        c === 0 && index === 0,
                      )}
                      {arrow(
                        t.moveCardDown(title),
                        ArrowDown,
                        () => (index < col.length - 1 ? place(id, c, index + 1) : place(id, c + 1, 0)),
                        c === last && index === col.length - 1,
                      )}
                      {c < last && arrow(t.moveCardRight(title), ArrowRight, () => place(id, c + 1, index), false, 'arrange-side')}
                    </div>
                  );
                })}
                {/* El espacio que queda bajo la última barra: dónde soltar al final
                    de la columna, también si está vacía. */}
                <div
                  {...drag.item(`${FIN}${c}`)}
                  className={cx(
                    // Sin `grow`: el destino se elige por el centro más cercano, y
                    // un hueco alto tendría el centro lejos de la última barra.
                    'box-border min-h-12 rounded-[var(--radius-card)]',
                    drag.over === `${FIN}${c}` && 'border-2 border-dashed border-gold',
                  )}
                />
              </div>
            ))}
          </div>
        </div>
      )}
      {toast}
    </>
  );
}
