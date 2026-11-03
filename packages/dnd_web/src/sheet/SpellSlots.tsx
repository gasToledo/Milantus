import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Pips } from '../ui/data';
import type { SheetWriter } from './writer';

export interface SlotCell {
  /** `normal-3` o `pact-5`: el mismo `data-slot` que tenían las filas. */
  key: string;
  level: number;
  pact: boolean;
  max: number;
  used: number;
}

/**
 * Las celdas de la grilla, sin React. Una por nivel con espacios o con algún
 * conjuro elegido (o siempre preparado) de ese nivel —un multiclase puede
 * tener un conjuro de un nivel sin espacios—, y al final la del pacto. El
 * pacto va aparte: sus conjuros no generan celdas normales, así el brujo ve
 * solo la suya. Los espacios los da el motor; acá no se calcula nada.
 */
export function spellSlotCells({
  normal,
  pact,
  normalUsed,
  pactUsed,
  spellLevels,
}: {
  normal: Record<string, number>;
  pact: Record<string, number>;
  normalUsed: Record<string, number> | undefined;
  pactUsed: Record<string, number> | undefined;
  /** Nivel de cada conjuro elegido o siempre preparado (los trucos no gastan). */
  spellLevels: number[];
}): SlotCell[] {
  const levels = new Set<number>(spellLevels.filter((l) => l > 0));
  for (const [level, max] of Object.entries(normal)) if (max > 0) levels.add(Number(level));
  const cells: SlotCell[] = [...levels]
    .sort((a, b) => a - b)
    .map((level) => ({
      key: `normal-${level}`,
      level,
      pact: false,
      max: normal[String(level)] ?? 0,
      used: normalUsed?.[String(level)] ?? 0,
    }));
  const pactEntry = Object.entries(pact).find(([, max]) => max > 0);
  if (pactEntry) {
    const [level, max] = pactEntry;
    cells.push({ key: `pact-${level}`, level: Number(level), pact: true, max, used: pactUsed?.[level] ?? 0 });
  }
  return cells;
}

const left = (c: SlotCell) => Math.max(0, c.max - c.used);

/** La grilla que elige el nivel: filtra la lista de abajo y decide qué espacio
 *  gasta la fila de acción. Solo elige, así que responde también en la ficha
 *  ajena. */
export function SpellSlotGrid({
  cells,
  selected,
  onSelect,
}: {
  cells: SlotCell[];
  selected: string | null;
  onSelect: (key: string) => void;
}) {
  const t = useTexts();
  if (cells.length === 0) return null;
  return (
    <div className={cx('grid gap-1.5', cells.length === 1 ? 'grid-cols-1' : 'grid-cols-3')}>
      {cells.map((c) => {
        const on = c.key === selected;
        const n = left(c);
        return (
          <button
            key={c.key}
            type="button"
            data-slot={c.key}
            aria-pressed={on}
            onClick={() => onSelect(c.key)}
            className={cx(
              'flex min-h-12 items-center justify-between gap-2 rounded-[var(--radius-card)] border px-2.5 py-1.5 text-left',
              on ? 'border-gold bg-gold-soft' : 'border-hairline bg-plaque',
            )}
          >
            <b
              className={cx(
                'text-[14px] font-bold tabular-nums',
                on ? 'text-gold' : n === 0 && c.max > 0 && 'text-text-muted',
              )}
            >
              {c.pact ? t.slotCellPact(c.level) : c.level}
            </b>
            {c.max > 0 ? (
              <Pips max={c.max} left={n} label={t.slotsLabel(n, c.max, String(c.level))} />
            ) : (
              <span className="text-[10.5px] text-text-muted">{t.slotCellNone}</span>
            )}
          </button>
        );
      })}
    </div>
  );
}

/** Lo que queda del espacio elegido y, en la ficha propia, gastarlo o
 *  recuperarlo: las mismas acciones del motor que tenían las filas. */
export function SpellSlotAction({ cell, write }: { cell: SlotCell | undefined; write?: SheetWriter }) {
  const t = useTexts();
  if (!cell) return null;
  const n = left(cell);
  const act = (type: 'spendSlot' | 'recoverSlot') => () =>
    write!.act({ type, level: cell.level, pact: cell.pact });
  return (
    <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-2">
      <span className="text-[13px] tabular-nums">{t.slotCellLeft(cell.level, n, cell.max, cell.pact)}</span>
      {write && (
        <span data-controls="spend-recover" className="flex gap-2">
          <Button
            tone="secondary"
            aria-label={t.spendSlot(String(cell.level))}
            disabled={n === 0 || cell.max === 0}
            onClick={act('spendSlot')}
          >
            {t.spendPoints}
          </Button>
          <Button
            tone="secondary"
            aria-label={t.recoverSlot(String(cell.level))}
            disabled={cell.used === 0 || cell.max === 0}
            onClick={act('recoverSlot')}
          >
            {t.recoverPoints}
          </Button>
        </span>
      )}
    </div>
  );
}
