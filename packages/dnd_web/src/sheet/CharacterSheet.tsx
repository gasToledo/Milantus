import type { CSSProperties, ReactNode } from 'react';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import type {
  AbilityId,
  Catalog,
  CharacterFields,
  ComputedSheet,
  JsonObject,
} from '../engine';
import { signed } from './format';

const ABILITIES: AbilityId[] = [
  'strength',
  'dexterity',
  'constitution',
  'intelligence',
  'wisdom',
  'charisma',
];

/** Nombre de una entrada del catálogo (ya en el idioma activo), o su id. */
function nameOf(list: JsonObject[], id: string | null | undefined): string | null {
  if (!id) return null;
  const entry = list.find((e) => e.id === id);
  return typeof entry?.name === 'string' ? entry.name : id;
}

/**
 * La ficha de solo lectura. Todo número sale de [sheet] (`ComputedSheet`); lo
 * único que se lee del personaje crudo es lo que no es un resultado de reglas:
 * los PG actuales y los usos gastados.
 */
export function CharacterSheet({
  character,
  sheet,
  catalog,
}: {
  character: CharacterFields;
  sheet: ComputedSheet;
  catalog: Catalog;
}) {
  const t = useTexts();

  const classEntry = catalog.classes.find((c) => c.id === character.classId);
  // El acento de clase viene del JSON del catálogo (`accentColor`), no del
  // código: así el homebrew usa el mismo mecanismo (`diseno-web.md` §3.3). Es
  // un dato y no un color de diseño; cae al oro si falta.
  const accent = typeof classEntry?.accentColor === 'string' ? classEntry.accentColor : null;

  const classes = Object.entries(sheet.classLevels)
    .map(([id, level]) => t.levelOf(nameOf(catalog.classes, id) ?? id, level))
    .join(' / ');
  const subtitle = [
    nameOf(catalog.races, character.raceId),
    classes,
    nameOf(catalog.backgrounds, character.backgroundId),
  ]
    .filter(Boolean)
    .join(' · ');
  const pills = [nameOf(catalog.subclasses, character.subclassId), labelOf(t.sizes, sheet.size)].filter(
    (p): p is string => Boolean(p),
  );

  const currentHp = character.combat?.currentHp ?? 0;
  const tempHp = character.combat?.tempHp ?? 0;

  return (
    <div className="flex flex-col gap-4">
      <header className="card flex items-center gap-4 p-4">
        <Medallion name={character.name} accent={accent} />
        <div className="min-w-0">
          <h1 className="font-display text-[24px] leading-tight break-words text-on-surface">
            {character.name}
          </h1>
          <p className="mt-1 text-[14px] text-on-surface-variant">{subtitle}</p>
          {pills.length > 0 && (
            <ul className="mt-2 flex flex-wrap gap-2">
              {pills.map((p) => (
                <li key={p} className="pill">
                  {p}
                </li>
              ))}
            </ul>
          )}
        </div>
      </header>

      <section aria-label={t.tacticalBand}>
        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <StatTile id="hp" label={t.hp} valueClass="text-crimson">
            {currentHp}
            <span className="text-[16px] font-normal text-on-surface-variant">
              {' / '}
              {sheet.maxHp}
            </span>
            {tempHp > 0 && (
              <span className="block text-[11px] font-normal text-on-surface-variant">
                {t.tempHp(tempHp)}
              </span>
            )}
          </StatTile>
          <StatTile id="ac" label={t.ac} valueClass="text-gold">
            {sheet.armorClass}
          </StatTile>
          <StatTile id="initiative" label={t.initiative}>
            {signed(sheet.initiative)}
          </StatTile>
          <StatTile id="speed" label={t.speed}>
            {sheet.speed}
            <span className="text-[14px] font-normal text-on-surface-variant"> {t.feet}</span>
          </StatTile>
          <StatTile id="proficiency" label={t.proficiency}>
            {signed(sheet.proficiencyBonus)}
          </StatTile>
          <StatTile id="passive-perception" label={t.passivePerception}>
            {sheet.passivePerception}
          </StatTile>
        </dl>
      </section>

      <section aria-labelledby="h-abilities">
        <h2 id="h-abilities" className="sr-only">
          {t.abilitiesHeading}
        </h2>
        <ul className="grid grid-cols-3 gap-3 lg:grid-cols-6">
          {ABILITIES.map((ability) => (
            <li
              key={ability}
              data-ability={ability}
              className="plaque flex flex-col items-center gap-1 px-2 py-3 text-center"
            >
              <span className="plaque-label" title={t.abilities[ability]}>
                {t.abilityAbbr[ability]}
              </span>
              <span className="stat-value" data-field="modifier">
                {signed(sheet.abilityModifiers[ability] ?? 0)}
              </span>
              <span className="text-[12px] text-on-surface-variant" data-field="score">
                {t.scoreLabel(sheet.abilityScores[ability] ?? 0)}
              </span>
              {/* Reserva el alto de la marca aunque no haya competencia, para
                  que las seis placas alineen. */}
              <span className="plaque-label min-h-[1em] text-gold">
                {sheet.savingThrowProficiencies.includes(ability) ? t.save : ''}
              </span>
            </li>
          ))}
        </ul>
      </section>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="flex min-w-0 flex-col gap-4">
          <Card title={t.attacksHeading} id="attacks">
            {sheet.attacks.length === 0 ? (
              <Empty>{t.noAttacks}</Empty>
            ) : (
              <ul className="divide-y divide-hairline">
                {sheet.attacks.map((a) => (
                  <li
                    key={`${a.weaponId}-${a.sourceEntryId ?? ''}-${a.offHand}`}
                    className="flex items-baseline justify-between gap-3 py-2"
                  >
                    <div className="min-w-0">
                      <p className="font-medium break-words">{a.name}</p>
                      <p className="text-[13px] text-on-surface-variant">
                        {a.damage} {labelOf(t.damageTypes, a.damageType)}
                      </p>
                    </div>
                    <span className="stat-value shrink-0" data-field="attack-bonus">
                      {signed(a.attackBonus)}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card title={t.resourcesHeading} id="resources">
            {sheet.resources.length === 0 ? (
              <Empty>{t.noResources}</Empty>
            ) : (
              <ul className="divide-y divide-hairline">
                {sheet.resources.map((r) => {
                  // Misma clave que `CharacterResource.key` del motor: los
                  // usos gastados se guardan por ella.
                  const key = r.classId ? `${r.classId}:${r.id}` : r.id;
                  const spent = character.combat?.resourceUsage?.[key] ?? 0;
                  return (
                    <li key={key} className="flex items-center justify-between gap-3 py-2">
                      <span className="min-w-0 break-words">{r.name}</span>
                      <Pips
                        max={r.max}
                        left={Math.max(0, r.max - spent)}
                        label={t.pipsLabel(r.name, Math.max(0, r.max - spent), r.max)}
                      />
                    </li>
                  );
                })}
              </ul>
            )}
          </Card>

          <Card title={t.featuresHeading} id="features">
            {sheet.passives.length === 0 ? (
              <Empty>{t.noFeatures}</Empty>
            ) : (
              <ul className="divide-y divide-hairline">
                {sheet.passives.map((p, i) => (
                  <li key={`${p.name}-${i}`} className="py-2">
                    <details>
                      <summary className="cursor-pointer font-medium">{p.name}</summary>
                      <p className="mt-1 text-[13px] whitespace-pre-line text-on-surface-variant">
                        {p.description}
                      </p>
                    </details>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <div className="flex min-w-0 flex-col gap-4">
          <Card title={t.savesHeading} id="saves">
            <ul>
              {ABILITIES.map((ability) => (
                <ProficiencyRow
                  key={ability}
                  id={ability}
                  kind="save"
                  label={t.abilities[ability]}
                  modifier={sheet.savingThrows[ability] ?? 0}
                  proficient={sheet.savingThrowProficiencies.includes(ability)}
                  expertise={false}
                />
              ))}
            </ul>
          </Card>

          <Card title={t.skillsHeading} id="skills">
            <ul>
              {Object.entries(sheet.skillModifiers).map(([skill, modifier]) => (
                <ProficiencyRow
                  key={skill}
                  id={skill}
                  kind="skill"
                  label={labelOf(t.skills, skill)}
                  modifier={modifier}
                  proficient={sheet.skillProficiencies.includes(skill)}
                  expertise={sheet.expertiseSkills.includes(skill)}
                />
              ))}
            </ul>
          </Card>
        </div>
      </div>
    </div>
  );
}

function Medallion({ name, accent }: { name: string; accent: string | null }) {
  // `--accent` es el único color que no sale de los tokens: viene del catálogo.
  const style = { '--accent': accent ?? 'var(--gold)' } as CSSProperties;
  return (
    <div
      aria-hidden="true"
      style={style}
      className="font-display flex h-16 w-16 shrink-0 items-center justify-center rounded-full border-[3px] border-[var(--accent)] bg-plaque text-[28px] text-gold"
    >
      {Array.from(name)[0]?.toUpperCase()}
    </div>
  );
}

function StatTile({
  id,
  label,
  valueClass = 'text-on-surface',
  children,
}: {
  id: string;
  label: string;
  valueClass?: string;
  children: ReactNode;
}) {
  return (
    <div className="plaque p-3" data-stat={id}>
      <dt className="eyebrow">{label}</dt>
      <dd className={`num stat-tile-value mt-1 ${valueClass}`}>{children}</dd>
    </div>
  );
}

function Card({ title, id, children }: { title: string; id: string; children: ReactNode }) {
  return (
    <section className="card p-4" aria-labelledby={`h-${id}`}>
      <h2 id={`h-${id}`} className="font-display mb-2 text-[16px] text-on-surface">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Empty({ children }: { children: ReactNode }) {
  return <p className="text-[13px] text-text-muted">{children}</p>;
}

/** Usos restantes: llenos en oro, gastados en `text-muted` (`UsagePips`). El
 *  texto de `aria-label` dice la cuenta, porque el color solo no alcanza. */
function Pips({ max, left, label }: { max: number; left: number; label: string }) {
  return (
    <span role="img" aria-label={label} className="flex flex-wrap justify-end gap-1">
      {Array.from({ length: max }, (_, i) => (
        <span
          key={i}
          className={`h-3 w-3 rounded-full ${i < left ? 'bg-gold' : 'bg-text-muted opacity-50'}`}
        />
      ))}
    </span>
  );
}

function ProficiencyRow({
  id,
  kind,
  label,
  modifier,
  proficient,
  expertise,
}: {
  id: string;
  kind: 'save' | 'skill';
  label: string;
  modifier: number;
  proficient: boolean;
  expertise: boolean;
}) {
  const t = useTexts();
  const state = expertise ? t.expertise : proficient ? t.proficient : t.notProficient;
  return (
    <li data-row={`${kind}-${id}`} className="flex items-center gap-3 py-1">
      {/* Pip de competencia: punto lleno; pericia, anillo dorado más grande
          (como `_skillDot` en Flutter). El color no es el único portador del
          significado: `aria-label` lo dice. */}
      <span
        role="img"
        aria-label={state}
        className="flex h-3 w-3 shrink-0 items-center justify-center"
      >
        <span
          className={
            expertise
              ? 'h-3 w-3 rounded-full border-[3px] border-gold'
              : `h-2 w-2 rounded-full ${proficient ? 'bg-gold' : 'bg-hairline'}`
          }
        />
      </span>
      <span className="num w-9 text-right text-[16px]" data-field="modifier">
        {signed(modifier)}
      </span>
      <span className="min-w-0 break-words">{label}</span>
    </li>
  );
}
