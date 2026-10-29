import { IdCard, Landmark, ScrollText, Shield, Sparkles } from 'lucide-react';
import { nameOf } from '../api/catalog';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { Card } from '../ui/Card';
import { Pill } from '../ui/data';
import { Accordion } from '../ui/disclosure';
import { signed } from './format';
import type { SheetModel } from './model';
import { ProficiencyRow } from './rows';
import { ABILITIES, SKILL_ABILITY } from './vocabulary';

/** Tres columnas fluidas: tantas como entren de 300 px, y una sola en un
 *  teléfono. `items-start`: cada columna tiene su alto y no se estira. */
export const COLUMNS =
  'grid items-start gap-4 [grid-template-columns:repeat(auto-fit,minmax(min(300px,100%),1fr))]';

/**
 * Pestaña Personaje: quién es (identidad y características), qué sabe hacer
 * (habilidades) y qué lo hace distinto (rasgos y dotes). Todo número es del
 * motor; los nombres, del catálogo.
 */
export function CharacterTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const { character, sheet, catalog } = model;

  const race = catalog.races.find((r) => r.id === character.raceId);
  const creatureType = typeof race?.creatureType === 'string' ? race.creatureType : null;
  const identity = [
    { label: t.alignmentLabel, value: character.alignment ? labelOf(t.alignments, character.alignment) : null },
    { label: t.creatureTypeLabel, value: creatureType ? labelOf(t.creatureTypes, creatureType) : null },
    { label: t.sizeLabel, value: labelOf(t.sizes, sheet.size) },
    { label: t.backgroundLabel, value: nameOf(catalog.backgrounds, character.backgroundId) },
    { label: t.personalityLabel, value: character.personalityTrait?.trim() || null },
  ].filter((row): row is { label: string; value: string } => Boolean(row.value));

  return (
    <div className={COLUMNS}>
      <div className="flex min-w-0 flex-col gap-4">
        <Card id="identity" title={t.identityHeading} icon={IdCard} collapsible>
          <dl className="divide-y divide-hairline border-t border-hairline">
            {identity.map((row) => (
              <div key={row.label} className="py-2">
                <dt className="text-[11px] text-text-muted">{row.label}</dt>
                <dd className="mt-0.5 break-words">{row.value}</dd>
              </div>
            ))}
          </dl>
        </Card>

        <Card id="abilities" title={t.abilitiesHeading} icon={Landmark}>
          <ul className="grid grid-cols-3 gap-2">
            {ABILITIES.map((ability) => {
              const save = sheet.savingThrowProficiencies.includes(ability);
              return (
                <li
                  key={ability}
                  data-ability={ability}
                  className="plaque flex min-w-0 flex-col items-center px-1 py-2.5 text-center"
                >
                  {/* La abreviatura se ve; el nombre completo se lee. */}
                  <span className="plaque-label" aria-hidden="true">
                    {t.abilityAbbr[ability]}
                  </span>
                  <span className="sr-only">{t.abilities[ability]}</span>
                  <span className="stat-value mt-1.5" data-field="modifier">
                    {signed(sheet.abilityModifiers[ability] ?? 0)}
                  </span>
                  <span className="mt-1.5 text-[11.5px] text-on-surface-variant tabular-nums" data-field="score">
                    {t.scoreLabel(sheet.abilityScores[ability] ?? 0)}
                  </span>
                  {/* Reserva el alto de la marca aunque no haya competencia,
                      para que las seis placas alineen. */}
                  <span className="mt-1 flex h-3 items-center gap-1 text-[9px] tracking-[1px] text-gold">
                    {save && (
                      <>
                        <Shield size={9} aria-hidden="true" />
                        <span aria-hidden="true">{t.save}</span>
                        <span className="sr-only">{t.saveProficient}</span>
                      </>
                    )}
                  </span>
                </li>
              );
            })}
          </ul>
        </Card>
      </div>

      <Card id="skills" title={t.skillsHeading} icon={ScrollText} collapsible>
        <ul className="flex flex-col gap-0.5">
          {Object.entries(sheet.skillModifiers).map(([skill, modifier]) => {
            const ability = SKILL_ABILITY[skill];
            return (
              <ProficiencyRow
                key={skill}
                id={skill}
                kind="skill"
                label={labelOf(t.skills, skill)}
                abbr={ability ? t.abilityAbbr[ability] : undefined}
                modifier={modifier}
                proficient={sheet.skillProficiencies.includes(skill)}
                expertise={sheet.expertiseSkills.includes(skill)}
              />
            );
          })}
        </ul>
        <p className="mt-3 flex items-baseline justify-between gap-3 border-t border-hairline pt-3 text-[13px] text-on-surface-variant" data-stat="passive-perception">
          <span>{t.passivePerception}</span>
          <span className="num text-[16px] text-on-surface" data-field="value">
            {sheet.passivePerception}
          </span>
        </p>
      </Card>

      <Card
        id="features"
        title={t.featuresAndFeats}
        icon={Sparkles}
        collapsible
        trailing={
          <Pill>
            <span aria-hidden="true">{sheet.passives.length}</span>
            <span className="sr-only">{t.featuresCount(sheet.passives.length)}</span>
          </Pill>
        }
      >
        {sheet.passives.length === 0 ? (
          <p className="text-[13px] text-text-muted">{t.noFeatures}</p>
        ) : (
          <Accordion
            items={sheet.passives.map((p, i) => ({
              id: `${i}-${p.name}`,
              title: p.name,
              content: p.description,
            }))}
          />
        )}
      </Card>
    </div>
  );
}
