import { Info, TriangleAlert } from 'lucide-react';
import type { EncounterDetails } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import type { Texts } from '../../i18n/texts';
import { cx } from '../../ui/cx';

type Difficulty = EncounterDetails['difficulty'];

/** El nombre de una dificultad, como se lee en la banda. */
function tierLabel(t: Texts, tier: string): string {
  switch (tier) {
    case 'low':
      return t.encDifficultyLow;
    case 'moderate':
      return t.encDifficultyModerate;
    case 'high':
      return t.encDifficultyHigh;
    default:
      return t.encDifficultyExtreme;
  }
}

/**
 * Qué tan difícil es el combate que se está armando (`EncounterDifficultyBand`
 * de Flutter). Va sobre `plaque`, como la barra de arriba: es un dato que la app
 * calculó, no algo que el DM edite. Solo «Extrema» cambia de color; las otras
 * tres son dificultades que el DM elige a propósito y ninguna es una alarma.
 * **No calcula nada**: todo número sale de `encounterDetails`.
 */
export function DifficultyBand({ difficulty: d }: { difficulty: Difficulty }) {
  const t = useTexts();
  const lang = useLang();
  const fmt = (n: number) => new Intl.NumberFormat(lang).format(n);
  const extreme = d.tier === 'extreme';

  const party =
    d.characters === 0 ? null : d.lowestLevel === d.highestLevel ? t.encDifficultyPartySame(d.characters, d.lowestLevel) : t.encDifficultyPartyMixed(d.characters, d.lowestLevel, d.highestLevel);

  // Los avisos: `true` es una advertencia y `false` solo informa por qué el
  // presupuesto es más chico que el de la mesa sola.
  const notices: { warning: boolean; title: string; body: string }[] = [];
  if (d.manyCreatures) notices.push({ warning: true, title: t.encDifficultyManyTitle, body: t.encDifficultyManyBody(d.enemies, d.characters) });
  if (d.powerfulCr !== null) notices.push({ warning: true, title: t.encDifficultyPowerfulTitle, body: t.encDifficultyPowerfulBody(String(d.powerfulCr), d.lowestLevel) });
  if (d.enemyCharacters > 0) notices.push({ warning: false, title: t.encDifficultyEnemySheetsTitle, body: t.encDifficultyEnemySheetsBody(d.enemyCharacters) });
  if (d.uncountedEnemies > 0) notices.push({ warning: true, title: t.encDifficultyUncountedTitle, body: t.encDifficultyUncountedBody(d.uncountedEnemies) });

  return (
    <section className="plaque flex flex-col gap-2.5 px-3.5 py-3" aria-label={t.encDifficulty} data-field="difficulty">
      <div className="grid grid-cols-1 items-center gap-x-6 gap-y-3 md:grid-cols-[176px_minmax(0,1fr)_190px]">
        <div>
          <p className="plaque-label">{t.encDifficulty}</p>
          {d.tier && (
            <p className={cx('font-display text-[22px] leading-[1.3]', extreme ? 'text-crimson' : 'text-gold')} data-field="tier">
              {tierLabel(t, d.tier)}
            </p>
          )}
          {party && <p className={cx('text-[12px] text-text-muted', !d.tier && 'mt-1')}>{party}</p>}
        </div>
        {d.tier === null ? <p className="text-[13px] text-text-muted">{d.characters === 0 ? t.encDifficultyNoParty : t.encDifficultyNoEnemies}</p> : <BudgetTrack d={d} extreme={extreme} fmt={fmt} />}
        {d.enemies > 0 && (
          <div className="md:text-right">
            <p className="plaque-label">{d.allyXp > 0 ? t.encDifficultyNetXp : t.encDifficultyEnemyXp}</p>
            <p className="num text-[20px] leading-[1.35]" data-field="net-xp">
              {fmt(d.netXp)}
            </p>
            {d.tier && (
              <p className="text-[12px] text-text-muted">{extreme ? t.encDifficultyOver(fmt(-d.remainingXp)) : t.encDifficultyLeft(fmt(d.remainingXp), tierLabel(t, d.tier))}</p>
            )}
            {d.allyXp > 0 && <p className="text-[12px] text-text-muted">{t.encDifficultyBreakdown(fmt(d.enemyXp), fmt(d.allyXp))}</p>}
          </div>
        )}
      </div>
      {notices.map((n) => (
        <div key={n.title} className="flex gap-2 border-t border-hairline pt-2.5 text-[13px]">
          {n.warning ? <TriangleAlert size={16} aria-hidden="true" className="mt-px text-gold" /> : <Info size={16} aria-hidden="true" className="mt-px text-text-muted" />}
          <p>
            <span className="font-semibold">{n.title}</span> <span className="text-text-muted">{n.body}</span>
          </p>
        </div>
      ))}
    </section>
  );
}

/** La regla del presupuesto: cuánto se lleva gastado y dónde cae cada techo. */
function BudgetTrack({ d, extreme, fmt }: { d: Difficulty; extreme: boolean; fmt: (n: number) => string }) {
  const t = useTexts();
  // La regla sigue un cuarto más allá del techo alto: sin ese tramo, «Extrema»
  // no tendría dónde verse pasada.
  const scale = d.highBudget * 1.25;
  const at = (xp: number) => (xp / scale) * 100;
  const budgets = [
    { name: t.encDifficultyLow, xp: d.lowBudget },
    { name: t.encDifficultyModerate, xp: d.moderateBudget },
    { name: t.encDifficultyHigh, xp: d.highBudget },
  ];
  return (
    <div
      role="img"
      aria-label={t.encDifficultyTrack(fmt(d.netXp), fmt(d.lowBudget), fmt(d.moderateBudget), fmt(d.highBudget))}
      className="relative mt-3.5 mb-[34px] h-2 rounded-[4px] border border-hairline bg-gold-soft"
    >
      <span className={cx('absolute inset-y-0 left-0 rounded-[4px]', extreme ? 'bg-crimson' : 'bg-gold')} style={{ width: `${Math.min(100, at(d.netXp))}%` }} />
      {budgets.map((b, i) => (
        <span key={b.name} aria-hidden="true">
          <span className="absolute -top-[7px] h-5 w-px bg-text-muted" style={{ left: `${at(b.xp)}%` }} />
          {/* «Baja» a la izquierda de su marca y las otras dos a la derecha:
              centradas se pisan cuando los techos bajo y moderado quedan cerca. */}
          <span
            className={cx('absolute top-[15px] flex flex-col', i === 0 ? 'items-end' : 'items-start')}
            style={i === 0 ? { right: `calc(${100 - at(b.xp)}% + 5px)` } : { left: `calc(${at(b.xp)}% + 5px)` }}
          >
            <span className="text-[10.5px] whitespace-nowrap text-text-muted">{b.name}</span>
            <span className="num text-[11.5px]">{fmt(b.xp)}</span>
          </span>
        </span>
      ))}
    </div>
  );
}
