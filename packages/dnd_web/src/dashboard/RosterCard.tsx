import { Star } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { characterHref, Link } from '../router';
import { signed } from '../sheet/format';
import { HP_CRITICAL_RATIO, hpTone, StatPlaque, ThinBar } from '../ui/data';
import { Medallion } from '../ui/Medallion';
import { ownPortrait } from '../ui/portrait';
import { isFallen, type RosterEntry } from './roster';

/**
 * Tarjeta de personaje: identidad arriba y datos de combate abajo, para no
 * abrir la ficha. Todo número viene de `ComputedSheet`; de la ficha cruda solo
 * se lee lo que no es un resultado de reglas (los PG actuales).
 *
 * La tarjeta entera es un enlace, pero el enlace es el nombre y se estira con
 * `::after` sobre toda la tarjeta: así el lector de pantalla anuncia «Brunilda
 * de Humo» y no la tarjeta entera leída de corrido, y el clic cae en cualquier
 * parte.
 */
export function RosterCard({ entry, favorite }: { entry: RosterEntry; favorite: boolean }) {
  const t = useTexts();
  const { character, sheet } = entry;
  const fallen = isFallen(entry);
  const hp = character.combat?.currentHp ?? 0;
  const maxHp = sheet?.maxHp ?? 0;
  const ratio = maxHp === 0 ? 0 : Math.min(1, Math.max(0, hp / maxHp));
  // Un cuarto de los PG: a partir de ahí el rótulo lo dice con todas las
  // letras en vez de dejarlo librado a lo corta que se ve la barra.
  const critical = !fallen && ratio <= HP_CRITICAL_RATIO;
  const hpLabel = fallen ? t.hpLabelFallen : critical ? t.hpLabelCritical : t.hpLabelNormal;

  const classes = entry.classes
    .map((c) => (entry.classes.length > 1 ? `${c.name} ${c.level}` : c.name))
    .join(' · ');

  return (
    <li
      className="roster-card card relative flex flex-col p-4"
      data-character={character.id}
      data-favorite={favorite}
    >
      <div className="flex items-start gap-3">
        <Medallion name={character.name} accent={entry.accent} size={64} muted={fallen} portrait={ownPortrait(character)} />
        <div className="min-w-0 flex-1">
          <h2 className="flex items-center gap-1.5 font-display text-[18px] leading-tight">
            {favorite && (
              <span role="img" aria-label={t.favorite} className="flex shrink-0">
                <Star size={15} aria-hidden="true" className="fill-gold text-gold" />
              </span>
            )}
            <Link
              href={characterHref(character.id)}
              className={`truncate after:absolute after:inset-0 after:rounded-[var(--radius-card)] after:content-[''] ${
                fallen ? 'text-on-surface-variant' : 'text-on-surface'
              }`}
            >
              {character.name}
            </Link>
            {fallen && (
              <span className="shrink-0 rounded-[var(--radius-pill)] border border-crimson px-[7px] font-body text-[9.5px] font-semibold tracking-[0.6px] text-crimson">
                {t.fallenBadge}
              </span>
            )}
          </h2>
          <p className="mt-0.5 truncate text-[12.5px] text-on-surface-variant">
            {[entry.raceName, classes].filter(Boolean).join(' · ')}
          </p>
        </div>
        {sheet && (
          <div className="shrink-0 text-right" data-field="level">
            <p className="eyebrow">{t.levelWord}</p>
            <p className="stat-value mt-1" data-stat="level">
              {sheet.level}
            </p>
          </div>
        )}
      </div>

      {sheet && (
        <>
          <div className="my-3 h-px bg-hairline" />
          <div className="flex items-baseline gap-2">
            <p
              className={`min-w-0 flex-1 truncate text-[9.5px] tracking-[1px] ${
                fallen || critical ? 'font-semibold text-crimson' : 'text-text-muted'
              }`}
            >
              {hpLabel}
            </p>
            {/* Sans negrita con cifras tabulares: se compara con la tarjeta de
                al lado. */}
            <p className="num text-[14px]" data-stat="hp">
              <span className={fallen || critical ? 'text-crimson' : 'text-on-surface'}>{hp}</span>
              <span className="font-normal text-text-muted"> / {maxHp}</span>
            </p>
          </div>
          {/* Recorre el tramo y cambia de color como en Flutter (verde, oro,
              carmesí); su `aria-label` dice lo mismo que la cifra de arriba. */}
          <div className="mt-1.5">
            <ThinBar
              value={fallen ? 0 : hp}
              max={maxHp}
              label={t.hp}
              valueText={`${hp} / ${maxHp}`}
              colorClassName={hpTone(ratio).bar}
              height={6}
            />
          </div>

          {/* Tres placas cortas dentro de la tarjeta: es el caso de
              `StatPlaque` (rótulo y valor en Georgia sobre la placa). El
              rótulo corto se ve; el completo se lee. */}
          <dl className="mt-3.5 grid grid-cols-3 gap-2">
            <StatPlaque id="ac" label={<Abbr short={t.acShort} full={t.acFull} />} value={sheet.armorClass} />
            <StatPlaque
              id="speed"
              label={<Abbr short={t.speedShort} full={t.speed} />}
              value={
                <>
                  {sheet.speed}
                  <span className="sr-only"> {t.feet}</span>
                </>
              }
            />
            <StatPlaque
              id="initiative"
              label={<Abbr short={t.initiativeShort} full={t.initiative} />}
              value={signed(sheet.initiative)}
            />
          </dl>
        </>
      )}
    </li>
  );
}

function Abbr({ short, full }: { short: string; full: string }) {
  return (
    <>
      <span aria-hidden="true">{short}</span>
      <span className="sr-only">{full}</span>
    </>
  );
}
