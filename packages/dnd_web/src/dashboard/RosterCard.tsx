import type { ReactNode } from 'react';
import { useTexts } from '../i18n/context';
import { characterHref } from '../router';
import { signed } from '../sheet/format';
import { Medallion } from '../ui/Medallion';
import { isFallen, type RosterEntry } from './roster';

// Un cuarto de los PG: a partir de ahí el rótulo lo dice con todas las letras
// en vez de dejarlo librado a lo corta que se ve la barra
// (`AppPalette.hpCriticalRatio` en Flutter).
const CRITICAL_HP_RATIO = 0.25;

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
  const critical = !fallen && ratio <= CRITICAL_HP_RATIO;
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
        <Medallion name={character.name} accent={entry.accent} size={64} muted={fallen} />
        <div className="min-w-0 flex-1">
          <h2 className="flex items-center gap-1.5 font-display text-[18px] leading-tight">
            {favorite && (
              <svg
                role="img"
                aria-label={t.favorite}
                viewBox="0 0 24 24"
                width="15"
                height="15"
                className="shrink-0 fill-gold"
              >
                <path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z" />
              </svg>
            )}
            <a
              href={characterHref(character.id)}
              className={`truncate after:absolute after:inset-0 after:rounded-[var(--radius-card)] after:content-[''] ${
                fallen ? 'text-on-surface-variant' : 'text-on-surface'
              }`}
            >
              {character.name}
            </a>
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
            <p className="font-display text-[13px] tabular-nums" data-stat="hp">
              <span className={fallen || critical ? 'text-crimson' : 'text-on-surface'}>{hp}</span>
              <span className="text-text-muted"> / {maxHp}</span>
            </p>
          </div>
          {/* La barra es redundante con la cifra de al lado: va oculta al lector. */}
          <div
            aria-hidden="true"
            className={`mt-1.5 h-[9px] rounded-[var(--radius-pill)] border bg-plaque p-px ${
              fallen || critical ? 'border-crimson' : 'border-hairline'
            }`}
          >
            {!fallen && (
              <div
                className="h-full rounded-[var(--radius-pill)] bg-crimson"
                style={{ width: `${ratio * 100}%` }}
              />
            )}
          </div>

          <dl className="plaque mt-3 grid grid-cols-3 divide-x divide-hairline">
            <Stat id="ac" short={t.acShort} full={t.acFull}>
              {sheet.armorClass}
            </Stat>
            <Stat id="speed" short={t.speedShort} full={t.speed}>
              {sheet.speed}
              <span className="ml-0.5 text-[11px] font-normal text-text-muted">
                {' '}
                {t.feet}
              </span>
            </Stat>
            <Stat id="initiative" short={t.initiativeShort} full={t.initiative}>
              {signed(sheet.initiative)}
            </Stat>
          </dl>
        </>
      )}
    </li>
  );
}

function Stat({
  id,
  short,
  full,
  children,
}: {
  id: string;
  short: string;
  full: string;
  children: ReactNode;
}) {
  return (
    <div className="min-w-0 px-2.5 py-2">
      <dt className="plaque-label">
        <span aria-hidden="true">{short}</span>
        <span className="sr-only">{full}</span>
      </dt>
      <dd className="num mt-0.5 truncate text-[20px] leading-tight text-on-surface" data-stat={id}>
        {children}
      </dd>
    </div>
  );
}
