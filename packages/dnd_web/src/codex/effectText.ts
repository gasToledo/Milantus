// La frase de un efecto. El motor resuelve qué es cada efecto y nombra lo que
// menciona (`effectParts`: la habilidad, el conjuro o la dote por su nombre, o
// el id crudo si ya no existe); acá solo se arma la frase con los textos de
// este cliente. Es la traducción literal de `describeEffect` de Flutter, y los
// dos tienen que moverse juntos.
import type { EffectParts } from '../engine';
import type { Texts } from '../i18n/texts';

/** Un efecto en una línea legible. `parts` null (el motor no lo describe) no
 *  tiene frase: quien lo lista decide qué mostrar en su lugar. */
export function describeEffectParts(p: EffectParts, t: Texts): string | null {
  const e = t.effect;
  const n = (v: number | undefined) => v ?? 0;
  const name = p.name ?? '';
  switch (p.type) {
    // El signo adelante («+1 CAR») se lee como un aumento; «CAR +1» parecía una
    // cuenta a medio escribir.
    case 'abilityScoreBonus':
      return `${n(p.amount) >= 0 ? `+${n(p.amount)}` : n(p.amount)} ${p.ability ?? ''}`;
    case 'setAbilityScore':
      return `${p.ability ?? ''} = ${n(p.score)}`;
    case 'skillProficiency':
    case 'weaponProficiency':
    case 'armorProficiency':
    case 'toolProficiency':
      return e.proficiency(name);
    case 'savingThrowProficiency':
      return e.save(p.ability ?? '');
    case 'savingThrowBonus':
      return e.saves(
        [n(p.amount) !== 0 || !p.fromAbility ? `+${n(p.amount)}` : '', p.fromAbility ? e.modOf(p.fromAbility) : '']
          .filter(Boolean)
          .join(' '),
      );
    case 'language':
      return e.language(name);
    case 'resistance':
      return e.resistance(name);
    case 'immunity':
      return e.immunity(name);
    case 'conditionImmunity':
      return e.conditionImmunity(name);
    case 'abilityCheckBonus':
      return e.checkBonus(p.ability ?? '', p.fromAbility ?? '');
    case 'darkvision':
      return e.darkvision(n(p.range));
    case 'speedBonus':
      return e.speedBonus(n(p.feet));
    case 'setSpeed':
      return e.speedSet(n(p.feet));
    case 'armorClassBonus':
      return e.acBonus(n(p.amount));
    case 'initiativeBonus':
      return e.initiative(
        [
          n(p.amount) !== 0 ? `+${n(p.amount)}` : '',
          p.addProficiency ? e.proficiencyBonusPart : '',
          p.fromAbility ? e.modOf(p.fromAbility) : '',
        ]
          .filter(Boolean)
          .join(' '),
      );
    case 'bonusMaxHpPerLevel':
      return e.maxHpPerLevel(n(p.amount));
    case 'bonusMaxHpFlat':
      return e.maxHpFlat(n(p.amount));
    case 'passiveTrait':
      return e.passive(name);
    case 'weaponMasterySlots':
      return e.weaponMastery(n(p.count));
    case 'extraAttack':
      return e.extraAttack(n(p.extra));
    case 'grantFeat':
      return e.feat(p.choice ? e.featChoice : name);
    case 'grantSpell':
      return e.spell(name, t.effInnate[p.use ?? ''] ?? p.use ?? '');
    case 'alwaysPreparedSpell':
      return e.alwaysPrepared(name);
    case 'spellListAddition':
      return e.addedToList(name);
    default:
      return null;
  }
}
