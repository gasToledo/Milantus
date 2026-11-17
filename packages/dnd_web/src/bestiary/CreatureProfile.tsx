import type { ReactNode } from 'react';
import { abilityModifier, catalogLabel, type BestiaryRow, type Catalog } from '../engine';
import { useTexts } from '../i18n/context';
import { codexHref, Link } from '../router';
import { signed } from '../sheet/format';
import { Pill, READ_BLOCK, READ_PROSE, SectionHeading, SectionRule } from '../ui/data';
import { cx } from '../ui/cx';
import { ABILITY_KEYS, type CreatureAction, type CreatureProfile as Profile } from './creature';

/** Los bloques del perfil (datos, rasgos, acciones) comparten el ancho de
 *  lectura del Códice. */
const BLOCK = READ_BLOCK;
/** La prosa de rasgos y acciones: el gris de lectura y no el tenue. */
const PROSE = `${READ_PROSE} text-[13.5px] leading-[1.55] text-on-surface-variant`;

/**
 * El perfil de una criatura, como `creatureProfileStats` y
 * `creatureProfileActions` de Flutter: encabezado, banda de cifras,
 * características, datos de línea, rasgos y acciones agrupadas por tipo y en
 * el orden del libro. Ninguna regla se calcula acá: el modificador es de
 * `abilityModifier`, y la iniciativa, el desafío y la percepción pasiva llegan
 * en [row], ya derivados por el motor.
 */
export function CreatureProfile({
  profile,
  row,
  catalog,
  compact = false,
  summary = false,
  kindNote,
  headerAction,
}: {
  profile: Profile;
  row: BestiaryRow;
  catalog: Catalog;
  /** La misma ficha dentro de otra superficie (el diálogo de Forma Salvaje):
   *  sin tarjeta propia ni píldoras, y con un título de panel. No es otra
   *  ficha, así que una criatura nueva sale igual en las dos. */
  compact?: boolean;
  /** La vista resumida de un compañero (con `compact`): título, tipo, CA, PG y
   *  ataque, velocidad, rasgos y acciones; sin características, salvaciones ni
   *  líneas de datos. */
  summary?: boolean;
  /** Se suma a la línea de tipo («con espacio de nivel 5»). */
  kindNote?: string;
  headerAction?: ReactNode;
}) {
  const t = useTexts();
  const source = (t.sources as Record<string, string>)[profile.source ?? ''];
  return (
    <article
      aria-labelledby="creature-title"
      // `@container`: el perfil se mide contra su lugar y no contra la ventana.
      // Montado en una columna angosta (el turno del combate, 300 px) en una
      // pantalla ancha, las seis características se apretaban en una fila.
      className={compact ? '@container' : '@container card px-5 py-6 sm:px-8 sm:py-7'}
      data-field="creature-detail"
    >
      {!compact && (source || headerAction) && (
        <div className="mb-3.5 flex flex-wrap items-center gap-2">
          {source && (
            <Pill highlighted={false}>
              <span aria-hidden="true">{source}</span>
              <span className="sr-only">{t.sourceLabel(source)}</span>
            </Pill>
          )}
          {headerAction && <div className="ml-auto">{headerAction}</div>}
        </div>
      )}
      {/* Como el encabezado de un bloque de estadísticas: nombre y tipo (en
          cursiva, como en el libro) a la izquierda y el desafío a la derecha,
          en su placa. Compacto, el desafío queda en la banda de cifras. */}
      <div className="flex items-start gap-4">
        <div className="min-w-0 flex-1">
          <h2
            id="creature-title"
            className={cx('font-display break-words text-on-surface', compact ? 'text-[16px]' : 'text-[34px] leading-[1.1] text-balance')}
          >
            {profile.name}
          </h2>
          <p className={cx('text-on-surface-variant italic', compact ? 'mt-1 text-[13px]' : 'mt-1.5 text-[15px]')}>
            {kindNote ? `${row.kind} · ${kindNote}` : row.kind}
          </p>
        </div>
        {!compact && row.crText !== null && (
          <div className="plaque shrink-0 px-4 py-2.5 text-center" data-field="creature-cr">
            <p className="plaque-label">{t.creatureCr}</p>
            <p className="num mt-1.5 text-[26px] leading-none text-gold">{row.crText}</p>
          </div>
        )}
      </div>
      <SectionRule className={compact ? 'my-4' : 'my-[22px]'} />

      <Numbers profile={profile} row={row} summary={summary} withCr={compact} />
      {summary ? (
        profile.speed && <p className="mt-3 text-[12.5px] text-on-surface-variant">{profile.speed}</p>
      ) : (
        <>
          <Abilities profile={profile} />
          <Lines profile={profile} hasPassive={row.passivePerception !== null} />
        </>
      )}
      <Traits profile={profile} />
      <Actions profile={profile} row={row} catalog={catalog} />
    </article>
  );
}

/** [withCr]: el desafío va en la banda solo donde el encabezado no tiene su
 *  placa (compacto). */
function Numbers({ profile, row, summary, withCr }: { profile: Profile; row: BestiaryRow; summary: boolean; withCr: boolean }) {
  const t = useTexts();
  const cells: { label: string; value: string; suffix?: string; gold?: boolean; crimson?: boolean }[] = [
    { label: t.creatureAc, value: profile.ac },
    { label: t.creatureHp, value: profile.hp, suffix: summary ? undefined : profile.hitDice, crimson: true },
  ];
  if (summary) {
    // El primer ataque, con signo; sin ninguno no hay celda.
    const bonus = profile.actions?.find((a) => a.attackBonus != null)?.attackBonus;
    if (bonus != null) cells.push({ label: t.compAttack, value: signed(Number(bonus)), gold: true });
  } else {
    cells.push({ label: t.creatureInitiative, value: signed(row.initiative) });
    if (withCr && row.crText !== null) cells.push({ label: t.creatureCr, value: row.crText, gold: true });
    if (row.passivePerception !== null) cells.push({ label: t.creaturePassive, value: String(row.passivePerception) });
  }
  return (
    <dl className="grid gap-2.5 [grid-template-columns:repeat(auto-fill,minmax(min(120px,100%),1fr))]">
      {cells.map((c) => (
        <div key={c.label} className="plaque min-w-0 px-3.5 py-[11px]">
          <dt className="plaque-label">{c.label}</dt>
          <dd className="mt-1.5 flex flex-wrap items-baseline gap-x-1.5">
            <span className={cx('num text-[24px] leading-none', c.gold && 'text-gold', c.crimson && 'text-crimson')}>
              {c.value}
            </span>
            {c.suffix && <span className="text-[12px] text-text-muted">{c.suffix}</span>}
          </dd>
        </div>
      ))}
    </dl>
  );
}

function Abilities({ profile }: { profile: Profile }) {
  const t = useTexts();
  return (
    <section aria-label={t.creatureAbilities} className="mt-3">
      <ul className="grid grid-cols-3 gap-2.5 @[520px]:grid-cols-6">
        {ABILITY_KEYS.map(([key, id]) => {
          const score = profile.abilityScores?.[key] ?? 10;
          const save = profile.savingThrows?.[key];
          return (
            <li key={key} className="plaque min-w-0 px-2 py-2.5 text-center" data-ability={key}>
              <p className="plaque-label">{catalogLabel('ability', id)}</p>
              <p className="num mt-1.5 text-[22px] leading-none">{signed(abilityModifier(score))}</p>
              <p className="mt-1 text-[10.5px] text-text-muted tabular-nums">{t.creatureScore(score)}</p>
              {/* Reserva el alto aunque no haya salvación: seis celdas a
                  distinta altura son ruido, no dato. */}
              <p className="mt-0.5 h-4 text-[10px] tracking-[0.4px] text-gold tabular-nums">
                {save !== undefined && t.creatureSave(signed(save))}
              </p>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

/** Los sentidos sin la percepción pasiva, que ya tiene su placa: el patrón es
 *  el de `_sensesWithoutPassive` de Flutter, sobre el texto del catálogo. */
function sensesWithoutPassive(senses: string, hasPassive: boolean): string {
  if (!hasPassive) return senses;
  return senses
    .replace(/[;,]?\s*(?:Percepción pasiva|Passive Perception) \d+/, '')
    .trim()
    .replace(/[;,]$/, '')
    .trim();
}

function Lines({ profile, hasPassive }: { profile: Profile; hasPassive: boolean }) {
  const t = useTexts();
  const senses = sensesWithoutPassive(profile.senses ?? '', hasPassive);
  const skills = Object.entries(profile.skills ?? {}).map(([id, bonus]) => `${catalogLabel('skill', id)} ${signed(bonus)}`);
  const defenses = (profile.defenses ?? '').split(';').map((d) => d.trim()).filter(Boolean);
  const rows: [string, ReactNode][] = [];
  if (profile.speed) rows.push([t.creatureSpeed, profile.speed]);
  if (skills.length > 0) rows.push([t.creatureSkills, skills.join(', ')]);
  if (senses) rows.push([t.creatureSenses, senses]);
  if (profile.languages) rows.push([t.creatureLanguages, profile.languages]);
  if (defenses.length > 0) {
    rows.push([
      t.creatureDefenses,
      <ul key="d" className="flex flex-wrap gap-1.5">
        {defenses.map((d) => (
          <li key={d}>
            <Pill highlighted={false}>{d}</Pill>
          </li>
        ))}
      </ul>,
    ]);
  }
  if (rows.length === 0) return null;
  return (
    <dl className={cx('mt-4', BLOCK)}>
      {rows.map(([label, value]) => (
        <div key={label} className="flex flex-col gap-1 border-t border-hairline py-2.5 first:border-t-0 @[440px]:flex-row @[440px]:gap-4">
          <dt className="plaque-label pt-0.5 @[440px]:w-[104px] @[440px]:shrink-0 @[440px]:text-right">{label}</dt>
          <dd className="min-w-0 text-[13.5px] leading-[1.45] text-on-surface">{value}</dd>
        </div>
      ))}
    </dl>
  );
}

function Traits({ profile }: { profile: Profile }) {
  const t = useTexts();
  if (!profile.traits?.length) return null;
  return (
    <section className={cx('mt-6', BLOCK)}>
      <SectionHeading>{t.creatureTraits}</SectionHeading>
      <ul>
        {profile.traits.map((tr, i) => (
          <li key={`${tr.name}-${i}`} className="py-1.5">
            <p className="font-medium text-gold">{tr.name}</p>
            {tr.description && <p className={cx('mt-0.5', PROSE)}>{tr.description}</p>}
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Los tipos de acción, en el orden del libro. */
export const ACTION_KINDS = ['action', 'bonus', 'reaction', 'legendary'] as const;

/** El rótulo de cada grupo de acciones. Lo comparte el turno del combate. */
export function actionKindLabel(t: ReturnType<typeof useTexts>, profile: Profile, kind: (typeof ACTION_KINDS)[number]): string {
  switch (kind) {
    case 'action':
      return t.creatureActions;
    case 'bonus':
      return t.creatureBonusActions;
    case 'reaction':
      return t.creatureReactions;
    case 'legendary':
      return profile.legendaryActionsPerRound === undefined ? t.creatureLegendary : t.creatureLegendaryPerRound(profile.legendaryActionsPerRound);
  }
}

function Actions({ profile, row, catalog }: { profile: Profile; row: BestiaryRow; catalog: Catalog }) {
  const t = useTexts();
  const actions = (profile.actions ?? []).map((a, i) => ({ a, melee: row.meleeReach[i] ?? true }));
  const label = (kind: (typeof ACTION_KINDS)[number]): string => actionKindLabel(t, profile, kind);
  return (
    <>
      {ACTION_KINDS.map((kind) => {
        const group = actions.filter(({ a }) => (a.kind ?? 'action') === kind);
        if (group.length === 0) return null;
        return (
          <section key={kind} className={cx('mt-6', BLOCK)} data-actions={kind}>
            <SectionHeading>{label(kind)}</SectionHeading>
            {/* Dos columnas compartidas (`subgrid`): las placas de todas las
                acciones del grupo arrancan en la misma columna y se comparan
                de un vistazo. Angosto, van debajo del texto. */}
            <ul className="grid grid-cols-1 gap-x-5 divide-y divide-hairline @[560px]:grid-cols-[minmax(0,1fr)_auto]">
              {group.map(({ a, melee }, i) => (
                <ActionRow key={`${a.name}-${i}`} action={a} melee={melee} catalog={catalog} />
              ))}
            </ul>
          </section>
        );
      })}
    </>
  );
}

/** Una acción, con lo que se tira sacado de la prosa: acierto o salvación,
 *  daño (o PG temporales, o curación) y alcance en placas rotuladas, del
 *  mismo tamaño. Un ataque múltiple, sin nada de eso cargado, es solo prosa. */
function ActionRow({ action: a, melee, catalog }: { action: CreatureAction; melee: boolean; catalog: Catalog }) {
  const t = useTexts();
  const damageType = a.damageType ? catalogLabel('damageType', a.damageType) : null;
  const plaques: [string, string, boolean?][] = [];
  const attack = a.attackBonus != null;
  if (attack) plaques.push([t.creatureToHit, `+${a.attackBonus}`, true]);
  // La salvación ocupa el lugar del acierto, en oro: es lo que define quién
  // tira. Sin ataque ni salvación no hay placas, como antes: la prosa de un
  // monstruo sin datos sueltos no se parte.
  if (a.save) plaques.push([t.creatureSaveLabel, `${t.abilityAbbr[a.save.ability]} ${a.save.dc}`, true]);
  if (attack || a.save || a.tempHp || a.healing) {
    const damage = a.damage ?? damageType ?? '';
    if (damage) plaques.push([t.creatureDamage, damage]);
    if (a.tempHp) plaques.push([t.creatureTempHp, a.tempHp]);
    if (a.healing) plaques.push([t.creatureHealing, a.healing]);
    // Que el alcance sea un área (cono, radio desde el cañón) lo dice el dato.
    if (a.reach) plaques.push([a.area ? t.creatureArea : melee ? t.creatureReach : t.creatureRange, a.reach]);
  }
  return (
    <li className="col-span-full grid grid-cols-subgrid items-start gap-y-2 py-3">
      <div className="min-w-0">
        <p className="font-medium text-on-surface">{a.name}</p>
        {a.description && !a.spellcasting && <p className={cx('mt-0.5', PROSE)}>{a.description}</p>}
        {a.spellcasting && <Spellcasting spellcasting={a.spellcasting} catalog={catalog} />}
      </div>
      {plaques.length > 0 && (
        <dl className="flex flex-wrap gap-2">
          {plaques.map(([label, value, gold]) => (
            <div key={label} className="plaque px-2.5 py-1.5 text-center">
              <dt className="plaque-label">{label}</dt>
              <dd className={cx('num mt-1 text-[16px] leading-none', gold && 'text-gold')}>{value}</dd>
              {label === t.creatureDamage && damageType && a.damage && (
                <dd className="mt-1 text-[11.5px] text-text-muted">{damageType}</dd>
              )}
            </div>
          ))}
        </dl>
      )}
    </li>
  );
}

export function Spellcasting({
  spellcasting: sc,
  catalog,
}: {
  spellcasting: NonNullable<CreatureAction['spellcasting']>;
  catalog: Catalog;
}) {
  const t = useTexts();
  const summary = [
    catalogLabel('ability', sc.ability),
    sc.saveDc !== undefined ? t.creatureSpellSaveDc(sc.saveDc) : null,
    sc.attackBonus !== undefined ? t.creatureSpellAttack(signed(sc.attackBonus)) : null,
  ]
    .filter(Boolean)
    .join(' · ');
  const nameOf = (id: string): string | null => {
    const found = catalog.spells.find((s) => s.id === id)?.name;
    return typeof found === 'string' ? found : null;
  };
  return (
    <div className="mt-1.5 text-[12.5px] text-text-muted">
      <p>{summary}</p>
      {sc.componentRule && <p>{sc.componentRule}</p>}
      {sc.groups.map((g, i) => (
        <div key={i} className="mt-2.5">
          <p className="text-[12px] font-bold text-on-surface">
            {g.usesPerDay === undefined ? t.creatureAtWill : t.creatureUsesPerDay(g.usesPerDay)}
          </p>
          <ul>
            {g.spells.map((s) => {
              const name = nameOf(s.spellId);
              const detail = [s.castAtLevel !== undefined ? t.creatureCastAtLevel(s.castAtLevel) : null, s.note]
                .filter(Boolean)
                .join(' · ');
              return (
                <li key={s.spellId} className="py-0.5">
                  {/* Un conjuro que el catálogo no tiene (homebrew sin cargar)
                      se ve igual, sin enlace, antes que desaparecer. */}
                  {name ? (
                    <Link href={codexHref('spells', s.spellId)} className="text-on-surface transition-colors duration-[120ms] ease-out hover:text-gold">
                      {name}
                    </Link>
                  ) : (
                    <span className="text-on-surface">{s.spellId}</span>
                  )}
                  {detail && <span> · {detail}</span>}
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </div>
  );
}
