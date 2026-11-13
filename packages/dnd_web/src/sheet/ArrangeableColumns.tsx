import { Fragment, useState, type ReactNode } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ArrowDown, ArrowLeft, ArrowRight, ArrowUp, GripVertical, LayoutDashboard, type LucideIcon } from 'lucide-react';
import { patchSettings } from '../api/settingsSave';
import { queryKeys, useRosterSettings } from '../api/queries';
import type { RosterSettings } from '../api/client';
import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { useHoldDrag } from '../ui/holdDrag';
import { Toast, Tooltip } from '../ui/primitives';
import { moveCard, resolveLayout, type CardLayout } from './cardLayout';
import { tabLabel } from './SheetPanel';

type Tab = 'combate' | 'personaje';

const FIN = '__fin-';
const isEnd = (id: string) => id.startsWith(FIN);
const AT_END = Number.MAX_SAFE_INTEGER;

/**
 * Las tres columnas de una pestaña de la ficha, con su modo «Acomodar
 * tarjetas». El orden es una preferencia de **quien mira** (los ajustes de la
 * cuenta, `sheetLayout`) y nunca del personaje: vale para toda ficha que esa
 * cuenta abra, propia, ajena o de PNJ, y no escribe ninguna.
 *
 * [cards] lleva solo las tarjetas presentes en esta ficha. Acomodando, el
 * contenido no se dibuja: cada tarjeta es una barra con su título.
 */
export function ArrangeableColumns({
  tab,
  defaults,
  cards,
}: {
  tab: Tab;
  defaults: CardLayout;
  cards: Record<string, { title: string; node: ReactNode }>;
}) {
  const t = useTexts();
  const client = useQueryClient();
  const settings = useRosterSettings();
  const [arranging, setArranging] = useState(false);
  const [toast, setToast] = useState<number | null>(null);

  const layout = resolveLayout(settings.data?.sheetLayout?.[tab], defaults, Object.keys(cards));
  const last = layout.length - 1;

  // Cada movimiento se guarda en el momento. Siempre viaja el objeto entero
  // (las dos pestañas): el servidor combina solo el primer nivel de los ajustes.
  const save = async (next: CardLayout | null) => {
    await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
    const current = client.getQueryData<RosterSettings>(queryKeys.rosterSettings)?.sheetLayout ?? {};
    const sheetLayout = { combate: current.combate ?? null, personaje: current.personaje ?? null, [tab]: next };
    client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (old) => old && { ...old, sheetLayout });
    try {
      await patchSettings({ sheetLayout });
    } catch {
      // Vuelve lo que quedó en el servidor. Sin `write.notify`: en la ficha
      // ajena no existe.
      void client.invalidateQueries({ queryKey: queryKeys.rosterSettings });
      setToast((n) => (n ?? 0) + 1);
    }
  };

  const place = (id: string, col: number, index: number) => void save(moveCard(layout, id, col, index));

  const drag = useHoldDrag({
    ids: layout.flatMap((col, c) => [...col, `${FIN}${c}`]),
    canDrop: (from, to) => !isEnd(from) && to !== from,
    onMove: (from, to) => {
      if (isEnd(to)) return place(from, Number(to.slice(FIN.length)), AT_END);
      const col = layout.findIndex((c) => c.includes(to));
      place(from, col, layout[col]!.indexOf(to));
    },
  });

  const toastNode = toast !== null && (
    <Toast key={toast} tone="error" message={t.layoutSaveFailed} open onOpenChange={(open) => !open && setToast(null)} />
  );

  if (!arranging) {
    return (
      <>
        <div className="mb-4 flex justify-end">
          <Button tone="secondary" shape="pill" icon={LayoutDashboard} onClick={() => setArranging(true)}>
            {t.arrangeCards}
          </Button>
        </div>
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
        {toastNode}
      </>
    );
  }

  const name = tabLabel(t, tab);
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
      <div className="card mb-4 flex items-center gap-2 py-2.5 pr-2.5 pl-4 sm:gap-3">
        <p className="min-w-0 flex-1 text-[14px]">
          <span className="sm:hidden">{t.arrangingTitleShort(name)}</span>
          <span className="hidden sm:inline">{t.arrangingTitle(name)}</span>
        </p>
        <Button tone="secondary" shape="pill" className="max-sm:min-h-11" onClick={() => void save(null)}>
          {t.arrangeRestore}
        </Button>
        <Button tone="primary" shape="pill" className="max-sm:min-h-11" onClick={() => setArranging(false)}>
          {t.arrangeDone}
        </Button>
      </div>
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
                      held
                        ? 'cursor-grabbing border-2 border-gold'
                        : drag.over === id
                          ? 'cursor-grab border-2 border-dashed border-gold'
                          : 'cursor-grab border border-hairline',
                    )}
                  >
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
                  'box-border min-h-12 grow rounded-[var(--radius-card)]',
                  drag.over === `${FIN}${c}` && 'border-2 border-dashed border-gold',
                )}
              />
            </div>
          ))}
        </div>
      </div>
      {toastNode}
    </>
  );
}
