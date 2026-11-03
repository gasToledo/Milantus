import { useMemo, useState } from 'react';
import { ChevronDown, PawPrint } from 'lucide-react';
import { asProfile } from '../bestiary/creature';
import { CreatureProfile } from '../bestiary/CreatureProfile';
import { companionsView, type CharacterJson, type CompanionInstanceView } from '../engine';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { cx } from '../ui/cx';
import { hpTone, Pill, ThinBar } from '../ui/data';
import { AmountControls, ConditionToggleList } from './CombatTab';
import type { SheetModel } from './model';
import { Tag } from './SpellList';

const ROW = 'rounded-[var(--radius-card)] border border-hairline bg-plaque px-3 py-2';

/**
 * Compañeros: los que la ficha tiene en juego (el familiar, el cañón, el
 * corcel), cada uno con sus PG, sus estados y su perfil, plegados de entrada.
 * Qué hay, con qué PG y con qué CA lo dice el motor (`companionsView`); acá
 * solo se pinta y se anota daño, curación, estados y «Despedir». Sin escritura
 * (la ficha de un miembro, la de un PNJ) no hay ningún control.
 */
export function CompanionsCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, catalog, write } = model;
  const view = useMemo(() => companionsView(character as unknown as CharacterJson, catalog), [character, catalog]);
  // Las filas abiertas, por índice. Varias a la vez, y nada se abre ni se cierra
  // solo; lo único que se corrige es el corrimiento cuando una sale de la lista.
  const [open, setOpen] = useState<ReadonlySet<number>>(new Set());
  const toggle = (index: number) =>
    setOpen((cur) => {
      const next = new Set(cur);
      if (!next.delete(index)) next.add(index);
      return next;
    });
  const forget = (index: number) =>
    setOpen((cur) => new Set([...cur].filter((i) => i !== index).map((i) => (i > index ? i - 1 : i))));

  const { instances, orphans, options } = view;
  const any = instances.length > 0 || orphans.length > 0;
  if (!any && (!write || options.length === 0)) return null;

  // El índice es el lugar en `combat.companions`: las instancias y las huérfanas
  // comparten esa numeración, así que se muestran juntas y en orden.
  const rows = [
    ...instances.map((i) => ({ index: i.index, instance: i, orphan: null as string | null })),
    ...orphans.map((o) => ({ index: o.index, instance: null, orphan: o.name as string | null })),
  ].sort((a, b) => a.index - b.index);

  const dismiss = (index: number, fallback: string) => {
    const r = write!.act({ type: 'dismissCompanion', index });
    if (!r) return;
    forget(index);
    write!.notify(t.compDismissed(r.outcome.name ?? fallback), { undo: () => write!.restore(r.before) });
  };

  return (
    <Card id="companions" title={t.compTitle} icon={PawPrint}>
      {rows.length === 0 ? (
        <p className="text-[13px] text-text-muted">{t.compNone}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {rows.map((row) =>
            row.instance ? (
              <CompanionRow
                key={row.index}
                model={model}
                c={row.instance}
                open={open.has(row.index)}
                onToggle={() => toggle(row.index)}
                onDismiss={() => dismiss(row.index, row.instance!.name)}
                onGone={() => forget(row.index)}
              />
            ) : (
              <li key={row.index} data-companion={row.index} className={ROW}>
                <p className="font-medium break-words">{row.orphan}</p>
                <p className="mt-0.5 text-[12.5px] text-text-muted">{t.compOrphan}</p>
                {write && (
                  <Button tone="secondary" className="mt-2" onClick={() => dismiss(row.index, row.orphan!)}>
                    {t.compDismiss}
                  </Button>
                )}
              </li>
            ),
          )}
        </ul>
      )}
    </Card>
  );
}

function CompanionRow({
  model,
  c,
  open,
  onToggle,
  onDismiss,
  onGone,
}: {
  model: SheetModel;
  c: CompanionInstanceView;
  open: boolean;
  onToggle: () => void;
  onDismiss: () => void;
  /** La fila salió de la lista (la destruyó el daño): los índices corren. */
  onGone: () => void;
}) {
  const t = useTexts();
  const { catalog, write } = model;

  if (c.gone) {
    return (
      <li data-companion={c.index} className={ROW}>
        <p className="font-medium break-words">{c.name}</p>
        <p className="mt-0.5 text-[12.5px] text-text-muted">{t.compGone}</p>
        {write && (
          <Button tone="secondary" className="mt-2" onClick={onDismiss}>
            {t.compDismiss}
          </Button>
        )}
      </li>
    );
  }

  const max = c.maxHp ?? 0;
  const ratio = max <= 0 ? 0 : Math.min(1, Math.max(0, c.currentHp / max));
  const tone = hpTone(ratio);
  const bodyId = `companion-${c.index}-body`;

  const run = (type: 'damage' | 'heal' | 'tempHp', amount: number) => {
    const action = { damage: 'damageCompanion', heal: 'healCompanion', tempHp: 'companionTempHp' } as const;
    const r = write!.act({ type: action[type], index: c.index, amount });
    if (r?.outcome.destroyed) {
      onGone();
      write!.notify(t.compDestroyed(r.outcome.name ?? c.name), { undo: () => write!.restore(r.before) });
    }
  };

  return (
    <li data-companion={c.index} className={ROW}>
      <button
        type="button"
        aria-expanded={open}
        aria-controls={bodyId}
        onClick={onToggle}
        className="flex w-full items-center gap-2 text-left"
      >
        <span className="flex min-w-0 flex-1 flex-wrap items-center gap-x-2 gap-y-1">
          <span className="font-medium break-words">{c.name}</span>
          {c.spellLevel > 0 && <Tag>{t.compSlotLevel(c.spellLevel)}</Tag>}
          {c.concentration && <Tag>{t.compConcentration}</Tag>}
          {c.conditions.map((id) => (
            <Pill key={id} highlighted={false}>
              {labelOf(t.conditions, id)}
            </Pill>
          ))}
        </span>
        <span className="shrink-0 text-[12.5px] text-on-surface-variant">{t.compAc(c.armorClass ?? '')}</span>
        <b className={cx('num shrink-0 text-[14px] tabular-nums', tone.text)}>{t.compHp(c.currentHp, max)}</b>
        <ChevronDown
          size={16}
          aria-hidden="true"
          className={cx('shrink-0 text-text-muted transition-transform', open && 'rotate-180')}
        />
      </button>
      <div className="mt-1.5">
        <ThinBar
          value={c.currentHp}
          max={max}
          label={t.compHpLabel(c.name)}
          valueText={t.hpValueText(c.currentHp, max)}
          colorClassName={tone.bar}
        />
      </div>
      {c.tempHp > 0 && <p className="mt-1 text-[12.5px] text-on-surface-variant">{t.tempHp(c.tempHp)}</p>}
      {open && (
        <div id={bodyId} className="mt-3 flex flex-col gap-3">
          {write && (
            <>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <AmountControls
                  id={`companion-${c.index}-amount`}
                  dataControls="companion-hp"
                  className=""
                  onRun={run}
                />
                <Button tone="secondary" onClick={onDismiss}>
                  {t.compDismiss}
                </Button>
              </div>
              <div role="group" aria-label={t.compConditionsOf(c.name)}>
                <ConditionToggleList
                  controls="companion-conditions"
                  attr="data-companion-condition"
                  active={c.conditions}
                  onToggle={(id, value) =>
                    write.act({ type: 'setCompanionCondition', index: c.index, condition: id, value })
                  }
                />
              </div>
            </>
          )}
          {c.profile && c.row && <CreatureProfile profile={asProfile(c.profile)} row={c.row} catalog={catalog} compact />}
        </div>
      )}
    </li>
  );
}
