import type { ReactNode } from 'react';
import { catalogLabel, type AbilityId } from '../engine';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { AppDialog } from '../ui/AppDialog';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { signed } from './format';
import type { SheetModel } from './model';
import { advantageSources } from './rows';
import { SKILL_ABILITY } from './vocabulary';

/**
 * De dónde sale una cifra de la ficha (`_showAbilityBreakdown` y
 * `_showInitiativeBreakdown` de Flutter): cada renglón es lo que ya trae
 * `sheet`, y el diálogo no suma nada. Nació de una pregunta de mesa («¿por qué
 * Inteligencia da +7?»): el resultado estaba y el camino no. Es de lectura, así
 * que se abre también en la ficha ajena.
 */
export function BreakdownDialog({
  model,
  target,
  onClose,
}: {
  model: SheetModel;
  target: AbilityId | 'initiative';
  onClose: () => void;
}) {
  const t = useTexts();
  const title = target === 'initiative' ? t.initiative : t.abilities[target];
  return (
    <AppDialog open onOpenChange={(open) => !open && onClose()} title={title} actions={[{ label: t.close, primary: true }]}>
      {target === 'initiative' ? (
        <InitiativeBreakdown model={model} />
      ) : (
        <AbilityBreakdown model={model} ability={target} />
      )}
    </AppDialog>
  );
}

/** Un renglón: rótulo a la izquierda y cifra a la derecha. `strong` es el
 *  total; `indent` cuelga un renglón de explicación de la cifra de arriba. */
function Line({ label, value, strong = false, indent = false }: { label: string; value?: ReactNode; strong?: boolean; indent?: boolean }) {
  return (
    <div
      className={cx(
        'flex justify-between gap-3 py-1 text-[13.5px]',
        strong ? 'font-bold text-on-surface' : 'text-on-surface-variant',
        indent && 'pl-3.5',
      )}
    >
      <span className="min-w-0">{label}</span>
      {value !== undefined && <b className={cx('num shrink-0 tabular-nums', strong ? 'font-bold' : 'font-medium text-on-surface')}>{value}</b>}
    </div>
  );
}

const Rule = () => <div aria-hidden="true" className="my-2 h-px bg-hairline" />;

function AbilityBreakdown({ model, ability }: { model: SheetModel; ability: AbilityId }) {
  const t = useTexts();
  const { sheet, character } = model;
  const exhaustion = character.combat?.exhaustion ?? 0;
  const check = sheet.abilityChecks[ability] ?? 0;
  // Solo las habilidades que no tiran con la prueba pelada, que ya está abajo:
  // listarlas todas repetía el mismo número. Se compara contra la ficha y no
  // contra una lista de motivos, así un motivo nuevo del motor aparece solo.
  const skills = Object.entries(sheet.skillModifiers).filter(
    ([skill, mod]) => SKILL_ABILITY[skill] === ability && mod !== check,
  );
  const casting = sheet.spellcasting?.ability === ability ? sheet.spellcasting : null;
  return (
    <>
      <p className="mb-3 text-[13px] text-on-surface-variant">{catalogLabel('abilityRule', ability)}</p>
      <Eyebrow>{t.breakdownWhereFrom}</Eyebrow>
      <Line label={t.breakdownAssigned} value={sheet.baseAbilityScores[ability]} />
      {sheet.abilityBonuses
        .filter((b) => b.ability === ability)
        .map((b, i) => (
          <Line key={i} label={b.source || t.advantageOtherTrait} value={b.amount >= 0 ? `+${b.amount}` : `−${-b.amount}`} />
        ))}
      <Rule />
      <Line strong label={t.breakdownScore} value={sheet.abilityScores[ability]} />
      <Line strong label={t.breakdownModifier} value={signed(sheet.abilityModifiers[ability] ?? 0)} />

      <div className="mt-3.5">
        <Eyebrow>{t.breakdownWhatToRoll}</Eyebrow>
      </div>
      <Line
        label={sheet.savingThrowProficiencies.includes(ability) ? t.breakdownSaveProficient : t.breakdownSave}
        value={signed(sheet.savingThrows[ability] ?? 0)}
      />
      {skills.map(([skill, mod]) => {
        const name = labelOf(t.skills, skill);
        return (
          <div key={skill}>
            <Line label={sheet.expertiseSkills.includes(skill) ? t.breakdownSkillExpertise(name) : name} value={signed(mod)} />
            {(sheet.skillBonuses[skill] ?? []).map((b, i) => (
              <Line key={i} indent label={t.breakdownIncludes(signed(b.amount), b.source)} />
            ))}
          </div>
        );
      })}
      {/* Siempre, y no solo cuando no hay habilidades: bajo Cansancio la prueba
          deja de coincidir con el modificador y esta es la cifra que se tira. */}
      <Line label={t.breakdownAbilityChecks} value={signed(check)} />
      {(sheet.abilityCheckBonuses[ability] ?? []).map((b, i) => (
        <Line key={i} indent label={t.breakdownIncludes(signed(b.amount), b.source)} />
      ))}
      {exhaustion > 0 && <Line indent label={t.breakdownExhaustion(Math.abs(sheet.d20Modifier), exhaustion)} />}
      {casting && (
        <>
          <Line label={t.breakdownSpellAttack} value={signed(casting.attackBonus)} />
          <Line label={t.breakdownSaveDc} value={casting.saveDc} />
        </>
      )}
    </>
  );
}

function InitiativeBreakdown({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { sheet, character } = model;
  return (
    <>
      <Eyebrow>{t.breakdownWhereFrom}</Eyebrow>
      <Line label={t.breakdownDexModifier} value={signed(sheet.abilityModifiers.dexterity ?? 0)} />
      {sheet.initiativeBonuses.map((b, i) => (
        <Line key={i} label={b.source || t.advantageOtherTrait} value={signed(b.amount)} />
      ))}
      {sheet.d20Modifier !== 0 && (
        <Line label={t.exhaustionLevelName(character.combat?.exhaustion ?? 0)} value={signed(sheet.d20Modifier)} />
      )}
      <Rule />
      <Line strong label={t.initiative} value={signed(sheet.initiative)} />
      {sheet.initiativeAdvantages.length > 0 && (
        <Line label={advantageSources(sheet.initiativeAdvantages, t)} value={t.advantageWith} />
      )}
    </>
  );
}
