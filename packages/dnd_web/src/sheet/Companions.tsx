import { useMemo, useState } from 'react';
import { ChevronDown, Info, PawPrint } from 'lucide-react';
import { asProfile } from '../bestiary/creature';
import { CreatureProfile } from '../bestiary/CreatureProfile';
import {
  companionPreview,
  companionsView,
  type CharacterJson,
  type CompanionInstanceView,
  type CompanionOptionView,
  type CompanionsView,
} from '../engine';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { cx } from '../ui/cx';
import { Eyebrow, hpTone, Pill, ThinBar } from '../ui/data';
import { Select } from '../ui/primitives';
import { Option, SearchableList } from '../ui/wizard';
import { AmountControls, ConditionToggleList } from './CombatTab';
import type { SheetModel } from './model';
import { SpellSlotGrid, type SlotCell } from './SpellSlots';
import { Tag } from './SpellList';
import type { SheetWriter } from './writer';

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
  const [summoning, setSummoning] = useState(false);
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
    <Card
      id="companions"
      title={t.compTitle}
      icon={PawPrint}
      trailing={
        write &&
        options.length > 0 && (
          <Button tone="primary" data-action="summon" onClick={() => setSummoning(true)}>
            {t.compSummon}
          </Button>
        )
      }
    >
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
      {summoning && write && <SummonDialog model={model} write={write} view={view} onClose={() => setSummoning(false)} />}
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
        <span className="min-w-0 flex-1">
          <span className="block font-medium break-words">{c.name}</span>
          {(c.spellLevel > 0 || c.concentration || c.conditions.length > 0) && (
            <span className="mt-0.5 flex flex-wrap items-center gap-1">
              {c.spellLevel > 0 && <Tag>{t.compSlotLevel(c.spellLevel)}</Tag>}
              {c.concentration && <Tag>{t.compConcentration}</Tag>}
              {c.conditions.map((id) => (
                <Pill key={id} highlighted={false}>
                  {labelOf(t.conditions, id)}
                </Pill>
              ))}
            </span>
          )}
        </span>
        <span className="shrink-0 text-[12.5px] text-on-surface-variant">{t.compAc(c.armorClass ?? '')}</span>
        <span className="shrink-0 whitespace-nowrap tabular-nums">
          <b className={cx('num text-[18px]', tone.text)}>{c.currentHp}</b>
          <small className="ml-1 text-[12px] text-text-muted">{t.compHpMax(max)}</small>
        </span>
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
          {c.profile && c.row && <CreatureProfile profile={asProfile(c.profile)} row={c.row} catalog={catalog} compact summary />}
        </div>
      )}
    </li>
  );
}

/** Los espacios que paga una opción, como celdas de la grilla. */
const cellsOf = (o: CompanionOptionView): SlotCell[] =>
  o.slots.map((c) => ({ key: `${c.pact ? 'pact' : 'normal'}-${c.level}`, ...c }));

/** Cómo arranca una opción: la primera forma y, si escala, el uso gratis (si
 *  queda) o el primer espacio. Cambiar de opción vuelve a empezar de acá. */
const startOf = (o: CompanionOptionView) => ({
  option: o.id,
  form: o.forms[0]?.id ?? '',
  pay: o.free && o.free.left > 0 ? 'free' : (cellsOf(o)[0]?.key ?? null),
});

/**
 * Invocar un compañero: opción, forma y con qué se paga (un espacio o el uso
 * gratis del conjuro), con el perfil resuelto al lado para ver los números
 * antes de gastar. Elegir no gasta: lo hace «Invocar». Qué espacios alcanzan,
 * a quién reemplaza y qué concentración se corta lo dice el motor; el pago y
 * los PG los resuelve `summonCompanion`.
 */
function SummonDialog({
  model,
  write,
  view,
  onClose,
}: {
  model: SheetModel;
  write: SheetWriter;
  view: CompanionsView;
  onClose: () => void;
}) {
  const t = useTexts();
  const { character, catalog } = model;
  const [sel, setSel] = useState(() => startOf(view.options[0]!));
  // En teléfono el perfil de una forma reemplaza a la lista dentro del mismo
  // diálogo, sin anidar otro.
  const [peek, setPeek] = useState<string | null>(null);
  const o = view.options.find((x) => x.id === sel.option) ?? view.options[0]!;
  const cells = cellsOf(o);
  const freeLeft = o.free?.left ?? 0;
  const noPay = o.scales && freeLeft === 0 && cells.length === 0;
  const cell = cells.find((c) => c.key === sel.pay);
  const level = !o.scales ? 0 : sel.pay === 'free' ? o.minSpellLevel : (cell?.level ?? o.minSpellLevel);
  // El perfil de cada forma al nivel elegido: da el detalle de la lista (CA y
  // PG) y el panel del costado. Se recalcula al cambiar de opción o de nivel.
  const previews = useMemo(
    () =>
      new Map(
        o.forms.map((f) => [
          f.id,
          companionPreview(character as unknown as CharacterJson, catalog, o.id, f.id, level),
        ]),
      ),
    [character, catalog, o.id, o.forms, level],
  );
  const preview = previews.get(peek ?? sel.form) ?? null;
  // «con espacio de nivel n» solo cuando el pago es un espacio.
  const kindNote = o.scales && sel.pay !== 'free' && cell ? t.compWithSlot(cell.level) : undefined;

  const concentrating = character.combat?.concentratingOn ?? null;
  const leaving = view.instances.filter((i) => i.concentration).map((i) => i.name);

  const summon = () => {
    const r = write.act({
      type: 'summonCompanion',
      option: o.id,
      creature: sel.form,
      ...(o.scales ? (sel.pay === 'free' ? { free: true } : { level: cell?.level, pact: cell?.pact }) : {}),
    });
    if (!r) return;
    const out = r.outcome;
    if (!out.summoned) {
      write.notify(t.compFailed, { tone: 'error' });
      return;
    }
    const notes = [
      out.spentSlot != null ? t.compNoteSlot(out.spentSlot) : null,
      out.freeName ? t.compNoteFree(out.freeName) : null,
      out.brokeConcentration ? t.compNoteBroke : out.concentrates ? t.compNoteConcentrating : null,
    ].filter((n): n is string => Boolean(n));
    write.notify(t.compSummoned(out.name ?? '', notes), { undo: () => write.restore(r.before) });
  };

  const infoButton = (formId: string, name: string) => (
    <Button
      tone="secondary"
      className="shrink-0 lg:hidden"
      aria-label={t.compInfo(name)}
      title={t.compInfo(name)}
      onClick={() => setPeek(formId)}
    >
      <Info size={16} aria-hidden="true" />
    </Button>
  );
  const formDetail = (f: CompanionOptionView['forms'][number]) => {
    const p = previews.get(f.id);
    return p ? t.compFormDetail(asProfile(p.profile).ac, asProfile(p.profile).hp) : f.kind;
  };
  const formRow = (f: CompanionOptionView['forms'][number]) => (
    <div key={f.id} className="flex min-w-0 shrink-0 items-stretch gap-1.5">
      <div className="min-w-0 flex-1">
        <Option
          id={f.id}
          selected={f.id === sel.form}
          title={f.name}
          detail={formDetail(f)}
          onClick={() => setSel({ ...sel, form: f.id })}
        />
      </div>
      {infoButton(f.id, f.name)}
    </div>
  );
  const single = o.forms.length === 1 ? o.forms[0]! : null;

  const warnings = [
    o.going ? t.compReplaces(o.going) : null,
    o.concentrates && concentrating
      ? leaving.length > 0
        ? t.compBreaksWith(concentrating, leaving.join(', '))
        : t.compBreaks(concentrating)
      : null,
  ].filter((w): w is string => Boolean(w));

  const list = (
    <div className="flex min-w-0 flex-col gap-4">
      {view.options.length > 1 && (
        <Select
          label={t.compOption}
          value={o.id}
          onValueChange={(id) => setSel(startOf(view.options.find((x) => x.id === id)!))}
          options={view.options.map((x) => ({ value: x.id, label: x.name }))}
        />
      )}
      {!single && (
        <div className="flex flex-col gap-2">
          <Eyebrow>{t.compForm}</Eyebrow>
          {o.forms.length > 6 ? (
            <SearchableList items={o.forms} textOf={(f) => f.name} label={t.compForm} height="max-h-[280px]">
              {formRow}
            </SearchableList>
          ) : (
            <div
              role="radiogroup"
              aria-label={t.compForm}
              className="flex max-h-[420px] flex-col gap-2 overflow-y-auto pr-1"
            >
              {o.forms.map(formRow)}
            </div>
          )}
        </div>
      )}
      {o.scales && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between gap-2">
            <Eyebrow>{t.compSlot}</Eyebrow>
            {single && infoButton(single.id, single.name)}
          </div>
          {noPay ? (
            <p className="text-[13px] text-on-surface-variant">{t.compNoSlots(o.minSpellLevel)}</p>
          ) : (
            <>
              {o.free && (
                <div data-free>
                  <Option
                    selected={sel.pay === 'free'}
                    disabled={freeLeft === 0}
                    title={t.compFreeOption}
                    detail={t.compFreeLeft(o.free.name, o.free.left, o.free.max)}
                    onClick={() => setSel({ ...sel, pay: 'free' })}
                  />
                </div>
              )}
              <SpellSlotGrid cells={cells} selected={sel.pay} onSelect={(key) => setSel({ ...sel, pay: key })} />
            </>
          )}
        </div>
      )}
      {single && !o.scales && <div>{infoButton(single.id, single.name)}</div>}
    </div>
  );

  return (
    <AppDialog
      open
      onOpenChange={(v) => !v && onClose()}
      title={t.compSummon}
      icon={PawPrint}
      width={860}
      actions={[
        { label: t.cancel },
        { label: t.compSummon, primary: true, tone: 'gold', disabled: noPay || !sel.form, onSelect: summon },
      ]}
    >
      {peek && preview ? (
        <div className="flex flex-col gap-3 lg:hidden">
          <Button tone="secondary" className="self-start" onClick={() => setPeek(null)}>
            {t.compBack}
          </Button>
          <CreatureProfile
            profile={asProfile(preview.profile)}
            row={preview.row}
            catalog={catalog}
            compact
            summary
            kindNote={kindNote}
          />
        </div>
      ) : null}
      <div className={cx('gap-4 lg:grid lg:grid-cols-[minmax(0,1fr)_340px]', peek ? 'hidden' : 'grid')}>
        {list}
        <div className="hidden lg:block">
          {preview && <CreatureProfile
            profile={asProfile(preview.profile)}
            row={preview.row}
            catalog={catalog}
            compact
            summary
            kindNote={kindNote}
          />}
        </div>
      </div>
      {warnings.length > 0 && (
        <div className="mt-4 flex flex-col gap-1 border-t border-hairline pt-3">
          {warnings.map((w) => (
            <p key={w} className="text-[13px] text-gold">
              {w}
            </p>
          ))}
        </div>
      )}
    </AppDialog>
  );
}
