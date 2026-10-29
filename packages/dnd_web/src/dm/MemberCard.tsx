import { HP_CRITICAL_RATIO, hpTone, Pill, StatPlaque, ThinBar } from '../ui/data';
import { useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { Medallion } from '../ui/Medallion';
import { signed } from '../sheet/format';
import { isFallen, type RosterEntry } from '../dashboard/roster';
import { Link } from '../router';

/**
 * Un jugador de la mesa, para leerlo de un vistazo: identidad, PG, cuatro
 * placas y los estados que tiene encima. Es la **ficha real** del jugador
 * (`GET /api/campaigns/:id/members` la lee en vivo, no es una copia) y el DM no
 * la escribe: no hay ningún control, y la tarjeta lleva a su ficha completa
 * ([href]), también de solo lectura. Todo número sale de
 * `ComputedSheet`; de la ficha cruda solo lo que no es regla (PG actuales y
 * estados).
 *
 * Una cosa que el diseño traía y acá no está: el nombre del jugador. La API
 * de miembros devuelve la ficha y nada de la cuenta de su dueño, y sumarlo
 * sería abrir una puerta más entre cuentas (`modo-dm.md`); Flutter tampoco lo
 * muestra.
 */
export function MemberCard({ entry, href, portrait }: { entry: RosterEntry; href: string; portrait: string | null }) {
  const t = useTexts();
  const { character, sheet } = entry;
  const fallen = isFallen(entry);
  const hp = character.combat?.currentHp ?? 0;
  const maxHp = sheet?.maxHp ?? 0;
  const ratio = maxHp === 0 ? 0 : Math.min(1, Math.max(0, hp / maxHp));
  const critical = !fallen && ratio <= HP_CRITICAL_RATIO;
  const classes = entry.classes
    .map((c) => (entry.classes.length > 1 ? `${c.name} ${c.level}` : c.name))
    .join(' · ');

  // Con varias lanzadoras hay una CD por clase: se muestran todas, sin
  // repetir, y la placa no elige cuál es «la» del personaje.
  const dcs = sheet
    ? [
        ...new Set(
          (sheet.spellcastingBlocks.length > 0
            ? sheet.spellcastingBlocks.map((b) => b.spellcasting)
            : sheet.spellcasting
              ? [sheet.spellcasting]
              : []
          ).map((s) => s.saveDc),
        ),
      ]
    : [];

  const conditions = character.combat?.conditions ?? [];
  const exhaustion = character.combat?.exhaustion ?? 0;

  return (
    <li className="card relative flex min-w-0 flex-col p-4 hover:border-gold" data-member={character.id}>
      <div className="flex items-center gap-3">
        <Medallion name={character.name} accent={entry.accent} size={54} muted={fallen} portrait={portrait} />
        <div className="min-w-0 flex-1">
          <h2 className={`font-display truncate text-[18px] leading-tight ${fallen ? 'text-on-surface-variant' : 'text-on-surface'}`}>
            {/* El enlace cubre la tarjeta entera (como en el dashboard) y su
                nombre es el del personaje: se lee igual que antes. */}
            <Link href={href} className="after:absolute after:inset-0 after:rounded-[var(--radius-card)] after:content-['']">
              {character.name}
            </Link>
          </h2>
          <p className="mt-0.5 truncate text-[12.5px] text-on-surface-variant">
            {[entry.raceName, classes].filter(Boolean).join(' · ')}
          </p>
        </div>
        {sheet && (
          <div className="shrink-0 text-center">
            <p className="eyebrow">{t.levelWord}</p>
            <p className="stat-value mt-1" data-stat="level">
              {sheet.level}
            </p>
          </div>
        )}
      </div>

      {sheet && (
        <>
          <div className="mt-3.5 flex items-baseline justify-between gap-2">
            <p className={`min-w-0 truncate text-[10px] tracking-[1.2px] uppercase ${fallen || critical ? 'font-semibold text-crimson' : 'text-text-muted'}`}>
              {fallen ? t.hpLabelFallen : critical ? t.hpLabelCritical : t.hpLabelNormal}
            </p>
            <p className="num text-[14px]" data-stat="hp">
              <span className={fallen || critical ? 'text-crimson' : 'text-on-surface'}>{hp}</span>
              <span className="font-normal text-text-muted"> / {maxHp}</span>
            </p>
          </div>
          <div className="mt-1.5">
            <ThinBar
              value={fallen ? 0 : hp}
              max={maxHp}
              label={t.dmHpAria(hp, maxHp)}
              valueText={`${hp} / ${maxHp}`}
              colorClassName={hpTone(ratio).bar}
              height={6}
            />
          </div>

          <dl className="mt-3.5 grid grid-cols-4 gap-2">
            <StatPlaque dense id="ac" label={<Abbr short={t.acShort} full={t.acFull} />} value={sheet.armorClass} />
            <StatPlaque dense id="initiative" label={<Abbr short={t.initiativeShort} full={t.initiative} />} value={signed(sheet.initiative)} />
            <StatPlaque
              dense
              id="dc"
              label={<Abbr short={t.dmSpellDcShort} full={t.spellSaveDc} />}
              value={dcs.length > 0 ? dcs.join(' / ') : t.dmNoValue}
            />
            <StatPlaque dense id="passive" label={<Abbr short={t.dmPassiveShort} full={t.passivePerception} />} value={sheet.passivePerception} />
          </dl>
        </>
      )}

      {/* Los estados van en la misma tarjeta, aunque estén vacíos, para que
          las tarjetas de una fila no cambien de alto según quién está sano. */}
      <ul className="mt-3 flex min-h-6 flex-wrap gap-1.5" aria-label={t.conditionsHeading}>
        {conditions.map((c) => (
          <Pill key={c} as="li" danger>
            {labelOf(t.conditions, c)}
          </Pill>
        ))}
        {exhaustion > 0 && (
          <Pill as="li" danger>
            {t.exhaustion(exhaustion)}
          </Pill>
        )}
      </ul>
    </li>
  );
}

export function Abbr({ short, full }: { short: string; full: string }) {
  return (
    <>
      <span aria-hidden="true">{short}</span>
      <span className="sr-only">{full}</span>
    </>
  );
}
