import { Flame } from 'lucide-react';
import { useState } from 'react';
import type { ActiveMode } from '../engine';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { AppDialog } from '../ui/AppDialog';
import { cx } from '../ui/cx';
import { resourceKey } from './format';
import { resourceLeft, type SheetModel } from './model';
import { ABILITIES } from './vocabulary';

/**
 * Lo que el estado activo le suma a la ficha, dicho en una línea
 * (`_activeModeSummary` de Flutter): las resistencias que trajo, el daño, las
 * ventajas. Todo sale del `ActiveMode` que arma el motor; acá no se deduce.
 */
function summaryOf(t: ReturnType<typeof useTexts>, m: ActiveMode): string {
  const types = m.resistances.map((r) => labelOf(t.damageTypes, r).toLowerCase());
  const abilities = new Set(m.advantages.flatMap((a) => a.abilities));
  return [
    types.length > 0 ? t.modeResistance(types.join(', ')) : null,
    m.conditionImmunities.length > 0
      ? t.modeConditionImmunity(m.conditionImmunities.map((id) => labelOf(t.conditions, id).toLowerCase()).join(', '))
      : null,
    m.damageAbility && m.damageBonus > 0 ? t.modeDamage(m.damageBonus, t.abilityAbbr[m.damageAbility]) : null,
    abilities.size > 0
      ? t.modeAdvantage(ABILITIES.filter((a) => abilities.has(a)).map((a) => t.abilityAbbr[a]).join(', '))
      : null,
    m.noSpellcasting ? t.modeNoSpells : null,
  ]
    .filter(Boolean)
    .join(' · ');
}

/** Con la variante al lado («Furia · Oso») dice de dónde salen las
 *  resistencias de la línea de abajo. */
function titleOf(m: ActiveMode): string {
  const chosen = (m.activeVariant ?? '').split(',');
  return [m.name, ...m.variants.filter((v) => chosen.includes(v.id)).map((v) => v.name)].join(' · ');
}

/** La franja de un estado activable en la banda táctica: los usos que quedan
 *  y «Activar», o «En curso · Terminar». Sin escritura solo se muestra el que
 *  está en curso. La regla (gastar el uso, la armadura pesada) es del motor;
 *  acá solo se dice por qué no se puede. */
export function ActiveModeTile({ model, mode: m }: { model: SheetModel; mode: ActiveMode }) {
  const t = useTexts();
  const { sheet, write } = model;
  const [choosing, setChoosing] = useState(false);
  const resource = m.resourceKey ? sheet.resources.find((r) => resourceKey(r) === m.resourceKey) : null;
  const left = resource ? resourceLeft(model, resource) : null;
  const noUses = !m.active && left === 0;
  const blocked =
    m.blockedBy === 'heavyArmor'
      ? t.modeHeavyArmor
      : m.blockedBy === 'incapacitated'
        ? labelOf(t.conditions, 'incapacitated')
        : m.blockedBy === 'needsMode'
          ? t.modeRequires(sheet.activeModes.find((o) => o.id === m.requiresMode)?.name ?? '')
          : noUses
            ? t.modeNoUses
            : null;
  const activate = () => {
    if (m.variants.length > 0) setChoosing(true);
    else activateWith({});
  };
  const activateWith = (choice: { variant?: string; variants?: string[] }) => {
    setChoosing(false);
    const r = write!.act({ type: 'activateMode', mode: m.id, ...choice });
    if (r && r.outcome.activated === false) write!.notify(t.modeFailed, { tone: 'error' });
  };
  const action = m.active ? `${t.modeOn} · ${t.modeEnd}` : (blocked ?? t.modeActivate);
  const off = !m.active && blocked !== null;
  // Los usos y, con el modo en curso, lo que le suma a la ficha (resistencias,
  // ventajas): la franja es el único cartel, no hay otra barra que lo repita.
  const meta = [resource ? t.modeUses(left ?? 0, resource.max) : null, m.active ? summaryOf(t, m) : null]
    .filter(Boolean)
    .join(' · ');
  const body = (
    <>
      <Flame size={22} aria-hidden="true" className={cx('shrink-0', off ? 'text-text-muted' : 'text-gold')} />
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className={cx('text-[15px] font-semibold', m.active ? 'text-gold' : 'text-on-surface')}>{titleOf(m)}</span>
        {meta && <span className="text-[12.5px] text-on-surface-variant">{meta}</span>}
      </span>
      <span className={cx('text-right text-[13px] font-semibold', off ? 'text-text-muted' : 'text-gold')}>{action}</span>
    </>
  );
  // Una franja a todo el ancho de la banda y no una quinta placa: con las
  // cuatro de arriba, quedaba sola en la segunda fila. Toda ella es el botón.
  const strip = cx(
    'plaque flex min-h-[60px] w-full items-center gap-3.5 px-4 py-2.5 text-left font-[family-name:var(--font-body)]',
    m.active && '!border-gold bg-gold-soft',
    off && 'opacity-60',
  );
  return (
    <div data-stat={`mode-${m.id}`} data-mode className="min-w-0">
      <dt className="sr-only">{m.name}</dt>
      <dd>
        {write ? (
          <button
            type="button"
            disabled={off}
            onClick={m.active ? () => write.act({ type: 'deactivateMode', mode: m.id }) : activate}
            className={cx(strip, off ? 'cursor-not-allowed' : 'cursor-pointer')}
          >
            {body}
          </button>
        ) : (
          <div className={strip}>{body}</div>
        )}
      </dd>
      {choosing && <VariantDialog mode={m} onClose={() => setChoosing(false)} onChoose={activateWith} />}
    </div>
  );
}

/** Cuál variante (Oso, Águila, Lobo) antes de prender: la regla dice «cada vez
 *  que activás, elegís una», así que no se recuerda la de la vez anterior.
 *  Un estado de varias (Revelación en Carne) las marca y gasta un uso por
 *  cada una al confirmar. Cada variante muestra lo que hace. */
function VariantDialog({
  mode: m,
  onClose,
  onChoose,
}: {
  mode: ActiveMode;
  onClose: () => void;
  onChoose: (choice: { variant?: string; variants?: string[] }) => void;
}) {
  const t = useTexts();
  const [picked, setPicked] = useState<string[]>([]);
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={m.name}
      icon={Flame}
      actions={[
        { label: t.cancel },
        ...(m.multiSelect
          ? [{ label: t.modeActivate, primary: true, disabled: picked.length === 0, onSelect: () => onChoose({ variants: picked }) }]
          : []),
      ]}
    >
      <ul className="flex flex-col gap-2">
        {m.variants.map((v) => (
          <li key={v.id}>
            {m.multiSelect ? (
              <label className="flex cursor-pointer items-start gap-3 rounded-[var(--radius-nav)] p-2 hover:bg-plaque">
                <input
                  type="checkbox"
                  checked={picked.includes(v.id)}
                  onChange={(e) => setPicked(e.target.checked ? [...picked, v.id] : picked.filter((id) => id !== v.id))}
                  className="mt-1"
                />
                <VariantText name={v.name} description={v.description} />
              </label>
            ) : (
              <button
                type="button"
                data-variant={v.id}
                onClick={() => onChoose({ variant: v.id })}
                className="w-full rounded-[var(--radius-nav)] p-2 text-left hover:bg-plaque"
              >
                <VariantText name={v.name} description={v.description} />
              </button>
            )}
          </li>
        ))}
      </ul>
    </AppDialog>
  );
}

function VariantText({ name, description }: { name: string; description?: string }) {
  return (
    <span className="block">
      <span className="block font-semibold">{name}</span>
      {description && <span className="mt-0.5 block text-[13px] text-on-surface-variant">{description}</span>}
    </span>
  );
}
