import { useState, type ReactNode } from 'react';
import { BadgeCheck, IdCard, Landmark, ScrollText, Shield, Sparkles } from 'lucide-react';
import { nameOf } from '../api/catalog';
import { catalogLabel, vocabularyLabel, type AbilityId } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { Card } from '../ui/Card';
import { Eyebrow, Pill } from '../ui/data';
import { Accordion } from '../ui/disclosure';
import { BreakdownDialog } from './BreakdownDialog';
import { signed } from './format';
import type { SheetModel } from './model';
import { ChangeChoicesButton, useChoicesView } from './Choices';
import { ProficiencyRow } from './rows';
import { ABILITIES, SKILL_ABILITY } from './vocabulary';

/** Tres columnas de 300 px como mínimo, dos o una según el ancho; el porqué
 *  de la ubicación a dos columnas está en `.sheet-columns` (`index.css`). */
export function SheetColumns({ children }: { children: ReactNode }) {
  return (
    <div className="sheet-columns">
      <div>{children}</div>
    </div>
  );
}

/**
 * Pestaña Personaje: quién es (identidad y características), qué sabe hacer
 * (habilidades) y qué lo hace distinto (rasgos y dotes). Todo número es del
 * motor; los nombres, del catálogo.
 */
export function CharacterTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const lang = useLang();
  // La característica cuyo desglose está abierto. Es lectura: se abre también
  // en la ficha ajena.
  const [breakdown, setBreakdown] = useState<AbilityId | null>(null);
  const { character, sheet, catalog } = model;
  // Los avisos y las elecciones son de la ficha propia; la ajena no los pide.
  const choices = useChoicesView(model);

  const race =catalog.races.find((r) => r.id === character.raceId);
  const creatureType = typeof race?.creatureType === 'string' ? race.creatureType : null;
  const identity = [
    { label: t.alignmentLabel, value: character.alignment ? labelOf(t.alignments, character.alignment) : null },
    // Tipo y tamaño son vocabulario del catálogo en español: los traduce el
    // motor, igual que en Flutter.
    { label: t.creatureTypeLabel, value: creatureType ? vocabularyLabel('creatureType', creatureType) : null },
    { label: t.sizeLabel, value: vocabularyLabel('size', sheet.size) },
    { label: t.backgroundLabel, value: nameOf(catalog.backgrounds, character.backgroundId) },
    { label: t.personalityLabel, value: character.personalityTrait?.trim() || null },
  ].filter((row): row is { label: string; value: string } => Boolean(row.value));

  // Visión en la oscuridad y después los demás sentidos, con su alcance en pies.
  const senses: [string, number][] = [
    ...(sheet.darkvision != null ? ([[t.sheetDarkvision, sheet.darkvision]] as [string, number][]) : []),
    ...Object.entries(sheet.senses).map(([sense, range]): [string, number] => [labelOf(t.senseNames, sense), range]),
  ];

  // Competencias. Las armas se nombran por el catálogo si son un arma concreta
  // y por la categoría del motor si no («Armas simples»). Los idiomas llevan
  // Común primero, que lo sabe todo personaje, y el resto por nombre
  // (`_languagesCard` de Flutter).
  // `nameOf` cae al id cuando no hay arma, así que el `??` no alcanza para
  // llegar a la categoría: se pregunta si el arma existe.
  const weaponName = (id: string) =>
    catalog.weapons.some((w) => w.id === id) ? nameOf(catalog.weapons, id)! : catalogLabel('weaponProficiency', id);
  const languages = sheet.languages
    .filter((id) => id !== 'common')
    .map((id) => catalogLabel('language', id))
    .sort((a, b) => a.localeCompare(b, lang));
  const proficiencyGroups = [
    { label: t.armor, chips: sheet.armorProficiencies.map((id) => catalogLabel('armorTraining', id)) },
    { label: t.profsWeapons, chips: sheet.weaponProficiencies.map(weaponName) },
    { label: t.profsTools, chips: sheet.toolProficiencies.map((id) => catalogLabel('tool', id)) },
    { label: t.creatureLanguages, chips: [catalogLabel('language', 'common'), ...languages] },
  ].filter((g) => g.chips.length > 0);

  return (
    <>
    <SheetColumns>
      <div className="flex min-w-0 flex-col gap-4">
        <Card
          id="identity"
          title={t.identityHeading}
          icon={IdCard}
          collapsible
          trailing={choices?.replaceable ? <ChangeChoicesButton href={model.write!.routes.choices()} /> : undefined}
        >
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
                <li key={ability} className="flex">
                <button
                  type="button"
                  data-ability={ability}
                  onClick={() => setBreakdown(ability)}
                  className="plaque flex w-full min-w-0 cursor-pointer flex-col items-center px-1 py-2.5 text-center"
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
                </button>
                </li>
              );
            })}
          </ul>
          {breakdown && <BreakdownDialog model={model} target={breakdown} onClose={() => setBreakdown(null)} />}
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
                advantage={sheet.skillAdvantages[skill]}
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
        {/* Los sentidos no tienen tarjeta: responden la misma pregunta que la
            Percepción pasiva (qué nota el personaje sin buscarlo) y van debajo
            con su formato. */}
        {senses.map(([label, range]) => (
          <p key={label} className="mt-1.5 flex items-baseline justify-between gap-3 text-[13px] text-on-surface-variant">
            <span>{label}</span>
            <span className="num text-[16px] text-on-surface">
              {range} <small className="text-[12px] font-normal text-text-muted">{t.feet}</small>
            </span>
          </p>
        ))}
      </Card>

      {/* Un solo hijo para la tercera columna: la grilla de dos columnas
          ubica por posición (`.sheet-columns`). */}
      <div className="flex min-w-0 flex-col gap-4">
      <Card id="proficiencies" title={t.profsHeading} icon={BadgeCheck} collapsible>
        <div className="flex flex-col gap-2.5">
          {proficiencyGroups.map((g) => (
            <div key={g.label}>
              <Eyebrow>{g.label}</Eyebrow>
              <ul className="mt-1.5 flex flex-wrap gap-1">
                {g.chips.map((chip, i) => (
                  <li
                    key={`${chip}-${i}`}
                    className="rounded-[var(--radius-pill)] border border-hairline px-[9px] py-[3px] text-[12px] text-on-surface-variant"
                  >
                    {chip}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
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
    </SheetColumns>
    </>
  );
}
