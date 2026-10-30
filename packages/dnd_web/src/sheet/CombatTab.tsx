import { Bed, BookOpen, Check, Coffee, Crosshair, Dices, Heart, Minus, Plus, RefreshCw, Shield, ShieldHalf, Zap } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import { nameOf } from '../api/catalog';
import type { CharacterResource, InnateSpell, SpellcastingBlock } from '../engine';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { Eyebrow, hpTone, Pill, Pips, ShieldBadge, SpendRecoverButtons, StatPlaque, ThinBar } from '../ui/data';
import { SheetColumns } from './CharacterTab';
import { resourceKey, signed } from './format';
import { SpellList } from './SpellList';
import { resourceLeft, type SheetModel } from './model';
import type { SheetWriter } from './writer';
import { ProficiencyRow } from './rows';
import { ABILITIES, isReactionSpell } from './vocabulary';

/**
 * Pestaña Combate: lo que se consulta en el turno y, en la ficha propia
 * (`model.write`), lo que se anota en él: daño, curación, PG temporales,
 * salvaciones de muerte, dados de golpe, espacios de conjuro, usos de
 * recursos y los descansos. Cada acción la hace el motor (`actOn`); acá no se
 * suma ni se resta nada. Preparar conjuros y el resto de la edición siguen en
 * Flutter. Los números son del motor; de la mesa (lo crudo) solo los PG
 * actuales, lo gastado y las condiciones.
 */
export function CombatTab({ model }: { model: SheetModel }) {
  return (
    <SheetColumns>
      <div className="flex min-w-0 flex-col gap-4">
        <HitPointsCard model={model} />
        <DefenseCard model={model} />
      </div>
      <div className="flex min-w-0 flex-col gap-4">
        <AttacksCard model={model} />
        <SpellsCard model={model} />
      </div>
      <div className="flex min-w-0 flex-col gap-4">
        <SavesCard model={model} />
        <ConditionsCard model={model} />
        <ResourcesCard model={model} />
      </div>
    </SheetColumns>
  );
}

function HitPointsCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, sheet } = model;
  const current = character.combat?.currentHp ?? 0;
  const temp = character.combat?.tempHp ?? 0;
  const ratio = sheet.maxHp <= 0 ? 0 : Math.min(1, Math.max(0, current / sheet.maxHp));
  const tone = hpTone(ratio);
  const used = character.combat?.hitDiceUsed ?? {};
  return (
    <Card id="hit-points" title={t.hitPoints} icon={Heart}>
      <p className="flex items-baseline gap-1.5">
        <span className={`num text-[34px] leading-none ${tone.text}`}>{current}</span>
        <span className="text-[15px] text-text-muted">{t.hpMaxSuffix(sheet.maxHp)}</span>
      </p>
      <div className="mt-3">
        <ThinBar
          value={current}
          max={sheet.maxHp}
          label={t.hitPoints}
          valueText={t.hpValueText(current, sheet.maxHp)}
          colorClassName={tone.bar}
          height={6}
        />
      </div>
      {temp > 0 && <p className="mt-2 text-[13px] text-on-surface-variant">{t.tempHp(temp)}</p>}
      {model.write && <HitPointControls model={model} />}
      {current <= 0 && <DeathSaves model={model} />}
      <dl className="mt-3 divide-y divide-hairline border-t border-hairline text-[13px]">
        {Object.entries(sheet.hitDiceBySize).map(([size, total]) => (
          <Line key={size} label={t.hitDice}>
            {t.hitDiceValue(Math.max(0, total - (used[size] ?? 0)), total, size)}
          </Line>
        ))}
        {character.combat?.heroicInspiration && (
          <Line label={t.heroicInspiration}>
            <Check size={16} aria-hidden="true" className="inline text-gold" />
            <span className="sr-only">{t.yes}</span>
          </Line>
        )}
      </dl>
      {model.write && <HitDieButton model={model} />}
    </Card>
  );
}

/** Gastar un dado de golpe para curarse: la tirada y el mod. de CON los pone
 *  el motor, que dice cuánto curó. Sin dados, deshabilitado (como Flutter). */
function HitDieButton({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, sheet, write } = model;
  const total = Object.values(sheet.hitDiceBySize).reduce((a, b) => a + b, 0);
  const spent = Object.values(character.combat?.hitDiceUsed ?? {}).reduce((a, b) => a + b, 0);
  const left = Math.max(0, total - spent);
  return (
    <Button
      tone="secondary"
      icon={Dices}
      className="mt-3"
      disabled={left <= 0}
      onClick={() => {
        const r = write!.act({ type: 'spendHitDie' });
        if (r) write!.notify(t.hitDieHealed(r.outcome.healed ?? 0), { tone: 'success' });
      }}
    >
      {t.hitDieButton(left, total)}
    </Button>
  );
}

/** Cantidad, Daño, Curar y PG temp, como `_hpControls` de Flutter: un campo
 *  y tres verbos. Un campo vacío o inválido cuenta 0, como allá. */
function HitPointControls({ model }: { model: SheetModel }) {
  const t = useTexts();
  const [amount, setAmount] = useState('');
  const run = (type: 'damage' | 'heal' | 'tempHp') => {
    model.write!.act({ type, amount: Number.parseInt(amount, 10) || 0 });
    setAmount('');
  };
  return (
    <div className="mt-3 flex flex-wrap items-center gap-2" data-controls="hit-points">
      <label htmlFor="hp-amount" className="sr-only">
        {t.hpAmount}
      </label>
      <input
        id="hp-amount"
        type="number"
        inputMode="numeric"
        min={0}
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        placeholder={t.hpAmount}
        className="num h-9 w-[110px] rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 text-[14px] text-on-surface placeholder:font-normal placeholder:text-text-muted"
      />
      <Button tone="danger" icon={Minus} onClick={() => run('damage')}>
        {t.hpDamage}
      </Button>
      <Button tone="secondary" icon={Plus} onClick={() => run('heal')}>
        {t.hpHeal}
      </Button>
      <Button tone="secondary" onClick={() => run('tempHp')}>
        {t.hpTemp}
      </Button>
    </div>
  );
}

/** A 0 PG, los éxitos y fallos (`_deathSaves` de Flutter). Se leen en
 *  cualquier ficha; marcarlos, solo en la propia. Que tres éxitos estabilicen
 *  y tres fallos maten lo dice el motor. */
function DeathSaves({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, write } = model;
  const successes = character.combat?.deathSuccesses ?? 0;
  const failures = character.combat?.deathFailures ?? 0;
  const mark = (success: boolean) => {
    const r = write!.act({ type: 'deathSave', success });
    if (r?.outcome.deathSave === 'stable') write!.notify(t.stabilized, { tone: 'success' });
    if (r?.outcome.deathSave === 'dead') write!.notify(t.characterDied, { tone: 'error' });
  };
  return (
    <div className="mt-4" data-death-saves>
      <Eyebrow>{t.deathSaves}</Eyebrow>
      <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-2">
        <span className="flex items-center gap-2" data-field="death-successes">
          <Pips max={3} left={successes} label={t.deathSuccesses(successes)} />
          {write && (
            <Button tone="secondary" onClick={() => mark(true)}>
              {t.deathSuccessPlus}
            </Button>
          )}
        </span>
        <span className="flex items-center gap-2" data-field="death-failures">
          <Pips max={3} left={failures} label={t.deathFailures(failures)} tone="crimson" />
          {write && (
            <Button tone="secondary" onClick={() => mark(false)}>
              {t.deathFailurePlus}
            </Button>
          )}
        </span>
      </div>
    </div>
  );
}

function DefenseCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, sheet, catalog } = model;
  const armor = character.equippedArmorId
    ? nameOf(catalog.armor, character.equippedArmorId)
    : t.noArmor;
  const line = [armor, character.shieldEquipped ? t.shield : null].filter(Boolean).join(' + ');
  const damage = (ids: string[]) => ids.map((id) => labelOf(t.damageTypes, id)).sort().join(', ');
  return (
    <Card id="defense" title={t.defenseHeading} icon={Shield}>
      <div className="flex items-center gap-3.5">
        <span data-stat="defense-ac">
          <ShieldBadge value={sheet.armorClass} label={t.acLabel(sheet.armorClass)} height={60} />
        </span>
        <div className="min-w-0">
          <Eyebrow className="!text-[10px] !tracking-[1.2px]">{t.armor}</Eyebrow>
          <p className="mt-0.5 break-words">{line}</p>
          {sheet.resistances.length > 0 && (
            <p className="mt-1.5 text-[12.5px] text-text-muted">{t.resistances(damage(sheet.resistances))}</p>
          )}
          {sheet.immunities.length > 0 && (
            <p className="mt-1 text-[12.5px] text-text-muted">{t.immunities(damage(sheet.immunities))}</p>
          )}
        </div>
      </div>
    </Card>
  );
}

function AttacksCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { sheet } = model;
  return (
    <Card id="attacks" title={t.attacksHeading} icon={Crosshair}>
      {sheet.attacks.length === 0 ? (
        <p className="text-[13px] text-text-muted">{t.noAttacks}</p>
      ) : (
        <ul className="divide-y divide-hairline border-t border-hairline">
          {sheet.attacks.map((a) => {
            const note = [
              `${a.damage} ${labelOf(t.damageTypes, a.damageType)}`,
              ...(a.extraDamage ?? []).map((x) => `${x.dice} ${labelOf(t.damageTypes, x.type)}`),
              a.range ? t.attackRange(a.range[0], a.range[1]) : null,
            ]
              .filter(Boolean)
              .join(' · ');
            return (
              <li
                key={`${a.weaponId}-${a.sourceEntryId ?? ''}-${a.offHand}`}
                data-attack={a.weaponId}
                className="flex items-center gap-3 py-2.5"
              >
                <div className="min-w-0 flex-1">
                  <p className="font-medium break-words">{a.name}</p>
                  <p className="mt-0.5 text-[12px] text-text-muted">{note}</p>
                </div>
                <span className="num shrink-0 text-[18px] text-gold" data-field="attack-bonus">
                  <span aria-hidden="true">{signed(a.attackBonus)}</span>
                  <span className="sr-only">{t.attackBonusLabel(signed(a.attackBonus))}</span>
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}

/**
 * Conjuros: por cada fuente de lanzamiento (una por clase lanzadora) la CD,
 * el ataque y la aptitud, cuántos hay preparados y los trucos; después los
 * espacios con lo que queda, y las reacciones. Si el personaje no lanza nada,
 * la tarjeta no aparece.
 */
function SpellsCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, sheet, catalog, write } = model;
  const blocks: SpellcastingBlock[] =
    sheet.spellcastingBlocks.length > 0
      ? sheet.spellcastingBlocks
      : sheet.spellcasting
        ? [{ classId: character.classId, classLevel: sheet.level, spellcasting: sheet.spellcasting }]
        : [];
  if (blocks.length === 0 && sheet.innateSpells.length === 0) return null;

  // Lo elegido, como lo junta Flutter (`_spellsCard`): la lista vieja y las de
  // cada clase, sin repetir. Contar lo elegido no es una regla; el tope sí, y
  // ese es del motor (`preparedCount`, `cantripsKnown`).
  const spellIdsFor = (classId: string) =>
    new Set([...(character.classSpellIds?.[classId] ?? (blocks.length === 1 ? (character.spellIds ?? []) : []))]);
  const cantripIdsFor = (classId: string) =>
    new Set([...(character.classCantripIds?.[classId] ?? (blocks.length === 1 ? (character.cantripIds ?? []) : []))]);

  const slots = (byLevel: Record<string, number>, used: Record<string, number> | undefined, pact: boolean) =>
    Object.entries(byLevel)
      .filter(([, max]) => max > 0)
      .sort(([a], [b]) => Number(a) - Number(b))
      .map(([level, max]) => {
        const spent = used?.[level] ?? 0;
        const left = Math.max(0, max - spent);
        const act = (type: 'spendSlot' | 'recoverSlot') => () =>
          write!.act({ type, level: Number(level), pact });
        return (
          <li
            key={`${pact ? 'p' : 'n'}-${level}`}
            className="flex items-center justify-between gap-3"
            data-slot={`${pact ? 'pact' : 'normal'}-${level}`}
          >
            <span className="text-[13px]">{pact ? t.pactSlotLevel(level) : t.slotLevel(level)}</span>
            <span className="flex items-center gap-2">
              <Pips max={max} left={left} label={t.slotsLabel(left, max, level)} />
              {write && (
                <SpendRecoverButtons
                  spendLabel={t.spendSlot(level)}
                  recoverLabel={t.recoverSlot(level)}
                  onSpend={left > 0 ? act('spendSlot') : undefined}
                  onRecover={spent > 0 ? act('recoverSlot') : undefined}
                />
              )}
            </span>
          </li>
        );
      });
  const slotRows = [
    ...slots(sheet.normalSpellSlotsByLevel, character.combat?.spellSlotsUsed, false),
    ...slots(sheet.pactSlotsByLevel, character.combat?.pactSlotsUsed, true),
  ];

  // Reacciones: los conjuros de rasgo (con su uso, CD y ataque ya calculados)
  // y los elegidos de clase cuyo tiempo de lanzamiento es una reacción.
  const spell = (id: string) => catalog.spells.find((s) => s.id === id);
  const innateReactions = sheet.innateSpells.filter((s) => isReactionSpell(spell(s.spellId)));
  const chosen = new Set([
    ...blocks.flatMap((b) => [...spellIdsFor(b.classId)]),
    ...sheet.alwaysPreparedSpellIds,
  ]);
  const innateIds = new Set(sheet.innateSpells.map((s) => s.spellId));
  const classReactions = [...chosen]
    .filter((id) => !innateIds.has(id) && isReactionSpell(spell(id)))
    .map((id) => ({ id, name: nameOf(catalog.spells, id) ?? id, level: Number(spell(id)?.level ?? 0) }));

  return (
    <Card id="spells" title={t.spellsHeading} icon={BookOpen}>
      <div className="flex flex-col gap-4">
        {blocks.map((b) => {
          const sc = b.spellcasting;
          const prepared = spellIdsFor(b.classId).size;
          const cantrips = cantripIdsFor(b.classId).size;
          return (
            <div key={b.classId} data-spellcasting={b.classId}>
              {blocks.length > 1 && (
                <Eyebrow className="mb-2">{t.classLevel(nameOf(catalog.classes, b.classId) ?? b.classId, b.classLevel)}</Eyebrow>
              )}
              <dl className="grid grid-cols-3 gap-2">
                <StatPlaque id="spell-dc" label={t.spellSaveDc} value={sc.saveDc} />
                <StatPlaque id="spell-attack" label={t.spellAttack} value={signed(sc.attackBonus)} />
                <StatPlaque
                  id="spell-ability"
                  label={t.spellAbility}
                  value={
                    <>
                      <span aria-hidden="true">{t.abilityAbbr[sc.ability]}</span>
                      <span className="sr-only">{t.abilities[sc.ability]}</span>
                    </>
                  }
                />
              </dl>
              <p className="mt-2.5 text-[13px] text-on-surface-variant tabular-nums">
                {[
                  sc.preparation === 'prepared' ? t.spellsPrepared(prepared, sc.preparedCount) : t.spellsKnown(prepared),
                  sc.cantripsKnown > 0 ? t.spellsCantrips(cantrips, sc.cantripsKnown) : null,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
            </div>
          );
        })}

        {slotRows.length > 0 && <ul className="flex flex-col gap-2">{slotRows}</ul>}

        <div className="border-t border-hairline pt-3">
          <SpellList
            cantripIds={[...(character.cantripIds ?? []), ...Object.values(character.classCantripIds ?? {}).flat()]}
            spellIds={[...(character.spellIds ?? []), ...Object.values(character.classSpellIds ?? {}).flat()]}
            alwaysPreparedIds={sheet.alwaysPreparedSpellIds}
            innate={sheet.innateSpells}
            preparation={sheet.spellcasting?.preparation ?? null}
            catalog={catalog.spells}
            innateNote={(s) => innateNote(s, t)}
          />
        </div>

        {(innateReactions.length > 0 || classReactions.length > 0) && (
          <div className="border-t border-hairline pt-3">
            <Eyebrow className="!text-[10px] !tracking-[1.2px]">{t.reactionsHeading}</Eyebrow>
            <ul className="mt-1.5 flex flex-col gap-2.5">
              {innateReactions.map((s) => (
                <li key={`i-${s.spellId}`}>
                  <p className="font-medium">{s.name}</p>
                  <p className="mt-0.5 text-[12px] text-text-muted">{innateNote(s, t)}</p>
                </li>
              ))}
              {classReactions.map((s) => (
                <li key={`c-${s.id}`}>
                  <p className="font-medium">{s.name}</p>
                  <p className="mt-0.5 text-[12px] text-text-muted">
                    {s.level === 0 ? t.cantrip : t.spellLevelShort(s.level)}
                  </p>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </Card>
  );
}

function innateNote(s: InnateSpell, t: ReturnType<typeof useTexts>): string {
  return [
    labelOf(t.innateUses, s.use),
    t.abilityAbbr[s.ability],
    t.dcValue(s.saveDc),
    t.attackValue(signed(s.attackBonus)),
  ].join(' · ');
}

function SavesCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { sheet } = model;
  return (
    <Card id="saves" title={t.savesHeading} icon={ShieldHalf}>
      <ul className="flex flex-col gap-0.5">
        {ABILITIES.map((ability) => (
          <ProficiencyRow
            key={ability}
            id={ability}
            kind="save"
            label={t.abilities[ability]}
            modifier={sheet.savingThrows[ability] ?? 0}
            proficient={sheet.savingThrowProficiencies.includes(ability)}
          />
        ))}
      </ul>
    </Card>
  );
}

function ConditionsCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, catalog } = model;
  const conditions = character.combat?.conditions ?? [];
  const exhaustion = character.combat?.exhaustion ?? 0;
  const concentrating = character.combat?.concentratingOn;
  const any = conditions.length > 0 || exhaustion > 0 || Boolean(concentrating);
  return (
    <Card id="conditions" title={t.conditionsHeading} icon={Zap}>
      {any ? (
        <ul className="flex flex-wrap gap-1.5">
          {conditions.map((c) => (
            <Pill as="li" key={c}>
              {labelOf(t.conditions, c)}
            </Pill>
          ))}
          {exhaustion > 0 && <Pill as="li">{t.exhaustion(exhaustion)}</Pill>}
          {concentrating && (
            <Pill as="li" highlighted={false}>
              {t.concentrating(nameOf(catalog.spells, concentrating) ?? concentrating)}
            </Pill>
          )}
        </ul>
      ) : (
        <p className="text-[13px] text-text-muted">{t.noConditions}</p>
      )}
    </Card>
  );
}

/** El recurso de reserva (Imposición de Manos, Puntos de Concentración) cuyo
 *  diálogo de puntos está abierto, y si es para gastar o recuperar. */
interface PointsAsk {
  resource: CharacterResource;
  spend: boolean;
  limit: number;
}

function ResourcesCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { sheet, write, character } = model;
  const [ask, setAsk] = useState<PointsAsk | null>(null);
  // Una reserva pide cuántos puntos (como `_askPoints` de Flutter); lo demás
  // gasta de a uno. Pasarse de lo que queda no es un error: el motor lo
  // deja entre cero y el máximo.
  const controls = (r: CharacterResource, left: number) => {
    const used = character.combat?.resourceUsage?.[resourceKey(r)] ?? 0;
    const go = (spend: boolean, limit: number) => () =>
      r.pool
        ? setAsk({ resource: r, spend, limit })
        : write!.act({ type: spend ? 'spendResource' : 'recoverResource', resource: resourceKey(r) });
    return (
      <SpendRecoverButtons
        spendLabel={t.spendResource(r.name)}
        recoverLabel={t.recoverResource(r.name)}
        onSpend={left > 0 ? go(true, left) : undefined}
        onRecover={used > 0 ? go(false, used) : undefined}
      />
    );
  };
  return (
    <Card id="resources" title={t.resourcesAndRests} icon={RefreshCw}>
      {write && <RestButtons write={write} />}
      {sheet.resources.length === 0 ? (
        <p className="text-[13px] text-text-muted">{t.noResources}</p>
      ) : (
        <ul className="divide-y divide-hairline border-t border-hairline">
          {sheet.resources.map((r) => {
            const left = resourceLeft(model, r);
            const label = t.pipsLabel(r.name, left, r.max);
            return (
              <li key={`${r.classId ?? ''}:${r.id}`} className="flex items-center justify-between gap-3 py-2.5" data-resource={r.id}>
                <div className="min-w-0">
                  <p className="break-words">{r.name}</p>
                  {t.recharge[r.recharge] && <p className="text-[11.5px] text-text-muted">{t.recharge[r.recharge]}</p>}
                </div>
                {/* Una reserva grande (Imposición de Manos: 25) en puntos no
                    se lee: va como cifra. */}
                <span className="flex shrink-0 items-center gap-2">
                  {r.pool || r.max > 8 ? (
                    <span className="num text-[15px]" role="img" aria-label={label}>
                      {t.poolValue(left, r.max)}
                    </span>
                  ) : (
                    <Pips max={r.max} left={left} label={label} />
                  )}
                  {write && controls(r, left)}
                </span>
              </li>
            );
          })}
        </ul>
      )}
      {ask && <PointsDialog ask={ask} onClose={() => setAsk(null)} model={model} />}
    </Card>
  );
}

/**
 * Los descansos, con el aviso de Flutter y su «Deshacer»: un toque de más en
 * plena sesión devuelve PG, espacios y recursos ya gastados, y volver a
 * marcarlos a mano es justo lo que nadie recuerda bien. Deshacer vuelve a
 * guardar la ficha entera de antes, con la mochila de antes del amanecer.
 * Qué recupera cada uno y qué cuenta el aviso lo dice el motor.
 */
function RestButtons({ write }: { write: SheetWriter }) {
  const t = useTexts();
  const short = () => {
    const r = write.act({ type: 'shortRest' });
    if (!r) return;
    const restored = r.outcome.restored ?? [];
    write.notify(restored.length === 0 ? t.shortRestNoRestore : t.shortRestRestored(restored.join(', ')), {
      undo: () => write.restore(r.before),
    });
  };
  const long = () => {
    const r = write.act({ type: 'longRest' });
    if (!r) return;
    const { exhaustion, inspirationGained, itemsRecharged = 0 } = r.outcome;
    const parts = [
      t.longRestBase,
      exhaustion != null ? t.longRestExhaustion(exhaustion) : null,
      inspirationGained ? t.longRestInspiration : null,
      itemsRecharged > 0 ? t.longRestItemsRecharged(itemsRecharged) : null,
    ].filter(Boolean);
    write.notify(t.longRestSummary(parts.join('; ')), { undo: () => write.restore(r.before) });
  };
  return (
    <div className="mb-3 flex flex-wrap gap-2" data-controls="rests">
      <Button tone="secondary" icon={Coffee} onClick={short}>
        {t.restShort}
      </Button>
      <Button tone="primary" icon={Bed} onClick={long}>
        {t.restLong}
      </Button>
    </div>
  );
}

/** Cuántos puntos de una reserva gastar o recuperar. Un número vacío o que no
 *  es positivo no hace nada, como en Flutter. */
function PointsDialog({ ask, onClose, model }: { ask: PointsAsk; onClose: () => void; model: SheetModel }) {
  const t = useTexts();
  const [value, setValue] = useState('');
  const confirm = () => {
    const n = Number.parseInt(value, 10);
    if (n > 0) {
      model.write!.act({
        type: ask.spend ? 'spendResource' : 'recoverResource',
        resource: resourceKey(ask.resource),
        amount: n,
      });
    }
    onClose();
  };
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={ask.resource.name}
      actions={[
        { label: t.cancel },
        { label: ask.spend ? t.spendPoints : t.recoverPoints, primary: true, onSelect: confirm },
      ]}
    >
      <form
        onSubmit={(e) => {
          e.preventDefault();
          confirm();
        }}
      >
        <label htmlFor="points-amount" className="text-[13px] text-on-surface-variant">
          {t.pointsPrompt(ask.spend, ask.limit)}
        </label>
        <input
          id="points-amount"
          type="number"
          inputMode="numeric"
          min={1}
          max={ask.limit}
          autoFocus
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="num mt-2 h-9 w-full rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 text-[14px] text-on-surface"
        />
      </form>
    </AppDialog>
  );
}

function Line({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-3 py-2">
      <dt className="text-on-surface-variant">{label}</dt>
      <dd className="num tabular-nums">{children}</dd>
    </div>
  );
}
