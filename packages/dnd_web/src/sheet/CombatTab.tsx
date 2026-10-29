import { BookOpen, Check, Crosshair, Heart, RefreshCw, Shield, ShieldHalf, Zap } from 'lucide-react';
import type { ReactNode } from 'react';
import { nameOf } from '../api/catalog';
import type { InnateSpell, SpellcastingBlock } from '../engine';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { Card } from '../ui/Card';
import { Eyebrow, hpTone, Pill, Pips, ShieldBadge, StatPlaque, ThinBar } from '../ui/data';
import { COLUMNS } from './CharacterTab';
import { signed } from './format';
import { SpellList } from './SpellList';
import { resourceLeft, type SheetModel } from './model';
import { ProficiencyRow } from './rows';
import { ABILITIES, isReactionSpell } from './vocabulary';

/**
 * Pestaña Combate, de **solo lectura**: lo que se consulta en el turno. No hay
 * daño, curación, gastar espacios ni preparar conjuros: eso es escribir la
 * ficha y sigue en Flutter. Los números son del motor; de la mesa (lo crudo)
 * solo los PG actuales, lo gastado y las condiciones.
 */
export function CombatTab({ model }: { model: SheetModel }) {
  return (
    <div className={COLUMNS}>
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
    </div>
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
    </Card>
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
  const { character, sheet, catalog } = model;
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
        const left = Math.max(0, max - (used?.[level] ?? 0));
        return (
          <li key={`${pact ? 'p' : 'n'}-${level}`} className="flex items-center justify-between gap-3">
            <span className="text-[13px]">{pact ? t.pactSlotLevel(level) : t.slotLevel(level)}</span>
            <Pips max={max} left={left} label={t.slotsLabel(left, max, level)} />
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

function ResourcesCard({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { sheet } = model;
  return (
    <Card id="resources" title={t.resourcesAndRests} icon={RefreshCw}>
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
                {r.pool || r.max > 8 ? (
                  <span className="num shrink-0 text-[15px]" role="img" aria-label={label}>
                    {t.poolValue(left, r.max)}
                  </span>
                ) : (
                  <Pips max={r.max} left={left} label={label} />
                )}
              </li>
            );
          })}
        </ul>
      )}
    </Card>
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
