import { useState, type ReactNode } from 'react';
import { vocabularyLabel, type AbilityId, type ByAbility, type InnateSpell, type JsonObject } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { Accordion } from '../ui/disclosure';
import { signed } from './format';
import { HigherLevelNote } from './HigherLevelNote';

/** La aptitud con que se lanza: la de la clase o la de un conjuro innato. */
export interface CastingStats {
  ability: AbilityId;
  attackBonus: number;
  saveDc: number;
}

/** Lo que una fila lee de un conjuro del catálogo (`Spell.toJson`). */
export type SpellJson = JsonObject & {
  id: string;
  name?: string;
  level?: number;
  school?: string;
  castingTime?: string;
  range?: string;
  components?: string;
  duration?: string;
  concentration?: boolean;
  ritual?: boolean;
  description?: string;
  higherLevel?: string;
};

export interface ResourceAbility {
  name: string;
  description: string;
  resourceKey: string;
  resourceName: string;
  left: number;
  max: number;
}

/**
 * Los conjuros del personaje en **pestañas** (a propósito, la ficha de Flutter
 * los apila): trucos, siempre preparados, preparados (o conocidos) y los que
 * concede un rasgo, y solo las que tienen algo. Las de siempre preparados y
 * elegidos siguen a la grilla de espacios (`levelFilter`): un mago de nivel 20
 * llenaba la pantalla con la lista entera. Cada uno se despliega con su ficha
 * (tiempo, alcance, componentes, duración y descripción). No se preparan ni se lanzan acá; en la ficha propia
 * ([onConcentrate]) los de concentración llevan «Concentrar», como Flutter.
 *
 * Lo elegido se junta como en Flutter: la lista vieja y las de cada clase,
 * sin repetir. Nada de esto es una regla: qué está siempre preparado y qué
 * conceden los rasgos lo dice el motor (`alwaysPreparedSpellIds`,
 * `innateSpells`). Las opciones mágicas de recursos compartidos llegan como
 * `abilities`: conservan su reserva y no se inventan conjuros en el catálogo.
 */
export function SpellList({
  cantripIds,
  spellIds,
  alwaysPreparedIds,
  innate,
  preparation,
  catalog,
  innateNote,
  onConcentrate,
  onSwapInnate,
  levelFilter,
  caps,
  damageBonuses,
  casting,
  abilityModifiers,
  abilities,
  onUseAbility,
}: {
  abilities: ResourceAbility[];
  onUseAbility?: (key: string) => void;
  /** Lo que se suma al daño de cada conjuro, con su fuente (`spellDamageBonuses`). */
  damageBonuses: Record<string, { bonus: number; source: string }[]>;
  /** La aptitud de la clase, para los que no son innatos; `null` si no lanza. */
  casting: CastingStats | null;
  abilityModifiers: ByAbility;
  /** El nivel elegido en la grilla de espacios: `upTo` (el pacto, que se
   *  lanza a ese nivel o menos) muestra hasta él; si no, solo ese. `null` si
   *  no hay grilla. Solo filtra la vista: no es una regla. */
  levelFilter: { upTo: boolean; level: number } | null;
  /** Los cupos del motor, para «25 de 25»; `spells` es `null` si conoce. Solo
   *  con una clase lanzadora: con varias no hay un cupo único. */
  caps: { cantrips: number; spells: number | null } | null;
  cantripIds: string[];
  spellIds: string[];
  alwaysPreparedIds: string[];
  innate: InnateSpell[];
  preparation: 'prepared' | 'known' | null;
  catalog: JsonObject[];
  innateNote: (s: InnateSpell) => string;
  /** El nombre del conjuro, como lo guarda Flutter en `concentratingOn`. */
  onConcentrate?: (name: string) => void;
  /** Abre el cambio del truco innato (el del rasgo, `grantedSpellId`). Solo en
   *  la ficha propia; solo lo llevan los que el rasgo deja reemplazar. */
  onSwapInnate?: (innate: InnateSpell) => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const byId = new Map(catalog.map((s) => [s.id, s as SpellJson]));
  // El bono al daño en palabras (`+4 al daño (Descarga Agónica)`); vacío si
  // el conjuro no lleva ninguno. La suma es la de la lista del motor.
  const bonusOf = (id: string | undefined): string | undefined => {
    const list = id ? damageBonuses[id] : undefined;
    if (!list || list.length === 0) return undefined;
    const total = list.reduce((sum, b) => sum + b.bonus, 0);
    return t.spellsDamageBonus(signed(total), [...new Set(list.map((b) => b.source))].join(', '));
  };
  // «Lanzás con Carisma (+4). Ataque de conjuro +7 · CD de salvación 15.» con
  // la aptitud de quien lo da; sin aptitud no hay línea.
  const detail = (spell: SpellJson, stats: CastingStats | null) => {
    const bonus = bonusOf(spell.id);
    const cast = stats
      ? t.spellsCastWith(t.abilities[stats.ability], signed(abilityModifiers[stats.ability] ?? 0), signed(stats.attackBonus), stats.saveDc)
      : null;
    return cast ? [cast, bonus && `${bonus}.`].filter(Boolean).join(' ') : undefined;
  };
  const resolve = (ids: string[]) =>
    [...new Set(ids)]
      .map((id) => byId.get(id))
      .filter((s): s is SpellJson => s !== undefined)
      // Por nivel y después por nombre, en el idioma de la interfaz.
      .sort((a, b) => (a.level ?? 0) - (b.level ?? 0) || (a.name ?? '').localeCompare(b.name ?? '', lang));

  const cantrips = resolve(cantripIds);
  const chosen = new Set(spellIds);
  // Un siempre preparado que además está elegido se muestra una sola vez, en
  // su grupo: no ocupa cupo, que es lo que esa lista explica.
  const always = resolve(alwaysPreparedIds);
  const alwaysSet = new Set(always.map((s) => s.id));
  const spells = resolve([...chosen].filter((id) => !alwaysSet.has(id)));

  const tabs: { key: TabKey; title: string; count: string }[] = [];
  const num = (n: number, cap: number | null | undefined) =>
    cap ? t.spellsTabCount(n, cap) : String(n);
  if (cantrips.length > 0)
    tabs.push({ key: 'cantrips', title: t.spellsTabCantrips, count: num(cantrips.length, caps?.cantrips) });
  if (always.length > 0) tabs.push({ key: 'always', title: t.spellsTabAlways, count: String(always.length) });
  if (spells.length > 0)
    tabs.push({
      key: 'chosen',
      title: preparation === 'known' ? t.spellsTabKnown : t.spellsTabChosen,
      count: num(spells.length, caps?.spells),
    });
  if (innate.length + abilities.length > 0) tabs.push({ key: 'innate', title: t.spellsTabInnate, count: String(innate.length + abilities.length) });

  // Local a la lista: elegir una pestaña no mueve nada más. Empieza en los
  // conjuros elegidos (lo que más se consulta) y, si la elegida desaparece
  // (se desprepara el último), cae en la primera.
  const [picked, setPicked] = useState<TabKey>(() => (tabs.some((x) => x.key === 'chosen') ? 'chosen' : (tabs[0]?.key ?? 'chosen')));

  if (tabs.length === 0) {
    return <p className="text-[13px] text-text-muted">{t.spellsNoneChosen}</p>;
  }
  const tab = tabs.some((x) => x.key === picked) ? picked : tabs[0]!.key;

  // `always` y `chosen` siguen a la grilla: un nivel, o hasta él si es pacto.
  const leveled = (list: SpellJson[], empty: string) => {
    const shown = levelFilter
      ? list.filter((s) => (levelFilter.upTo ? (s.level ?? 0) <= levelFilter.level : (s.level ?? 0) === levelFilter.level))
      : list;
    if (shown.length === 0) return <p className="text-[13px] text-text-muted">{empty}</p>;
    const items = (l: SpellJson[]) => (
      <Accordion
        headingLevel={4}
        items={l.map((s) => ({
          id: s.id,
          title: <SpellTitle spell={s} hideLevel bonus={bonusOf(s.id)} />,
          content: (
            <SpellDetail spell={s} castLine={detail(s, casting)} onConcentrate={onConcentrate && (() => onConcentrate(s.name ?? s.id))} />
          ),
        }))}
      />
    );
    // Una celda normal ya dice el nivel: lista plana, sin rótulo.
    if (levelFilter && !levelFilter.upTo) return items(shown);
    const byLevel = new Map<number, SpellJson[]>();
    for (const s of shown) byLevel.set(s.level ?? 0, [...(byLevel.get(s.level ?? 0) ?? []), s]);
    return (
      <div className="max-h-[420px] overflow-y-auto">
        {[...byLevel].map(([level, l]) => (
          <div key={level}>
            <Eyebrow className="mb-1 mt-2 first:mt-0">{t.spellLevelShort(level)}</Eyebrow>
            {items(l)}
          </div>
        ))}
      </div>
    );
  };

  const level = levelFilter?.level ?? 0;
  let panel: ReactNode;
  if (tab === 'cantrips') {
    panel = (
      <Accordion
        headingLevel={4}
        items={cantrips.map((s) => ({
          id: s.id,
          title: <SpellTitle spell={s} bonus={bonusOf(s.id)} />,
          content: (
            <SpellDetail spell={s} castLine={detail(s, casting)} onConcentrate={onConcentrate && (() => onConcentrate(s.name ?? s.id))} />
          ),
        }))}
      />
    );
  } else if (tab === 'always') {
    panel = leveled(always, t.spellsNoAlwaysAtLevel(level));
  } else if (tab === 'chosen') {
    panel = leveled(spells, preparation === 'known' ? t.spellsNoKnownAtLevel(level) : t.spellsNoneAtLevel(level));
  } else {
    panel = (
      <Accordion
        headingLevel={4}
        items={[...innate.map((i) => {
          const s = byId.get(i.spellId);
          return {
            // Por el conjuro concedido, único en la lista: con dos filas de la
            // misma clave React no desmonta la de más y se acumula en las pestañas.
            id: `innate-${i.grantedSpellId}`,
            // El nombre que da el motor (puede venir del rasgo) y su uso,
            // CD y ataque, que son los del rasgo y no los de la clase.
            title: <SpellTitle spell={s} name={i.name} note={innateNote(i)} bonus={bonusOf(i.spellId)} />,
            content: s ? (
              <SpellDetail
                spell={s}
                castLine={detail(s, i)}
                onConcentrate={onConcentrate && (() => onConcentrate(i.name))}
                onSwap={onSwapInnate && i.replaceableFrom.length > 0 ? () => onSwapInnate(i) : undefined}
              />
            ) : null,
          };
        }), ...abilities.map((a, index) => ({
          id: `ability-${index}-${a.name}`,
          title: <SpellTitle spell={undefined} name={a.name} note={`${a.resourceName} · ${t.poolValue(a.left, a.max)}`} />,
          content: (
            <div data-resource-ability={a.resourceKey}>
              <p>{a.description}</p>
              {onUseAbility && (
                <Button className="mt-2" tone="secondary" disabled={a.left === 0} onClick={() => onUseAbility(a.resourceKey)}>
                  {t.spendResource(a.name)}
                </Button>
              )}
            </div>
          ),
        }))]}
      />
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {/* Local a este archivo: `SpellTabs` lleva estados de cupo que acá no van. */}
      <div role="tablist" className="grid auto-cols-fr grid-flow-col gap-1.5">
        {tabs.map((x) => {
          const on = x.key === tab;
          return (
            <button
              key={x.key}
              type="button"
              role="tab"
              aria-selected={on}
              data-tab={x.key}
              onClick={() => setPicked(x.key)}
              className={cx(
                'pick flex min-h-[52px] min-w-0 flex-col items-center justify-center rounded-[var(--radius-card)] border px-2.5 py-1.5',
                on ? 'border-gold bg-gold-soft text-gold' : 'border-hairline bg-plaque',
              )}
            >
              <span className="text-[12.5px]">{x.title}</span>
              <b className="text-[13px] font-bold tabular-nums">{x.count}</b>
            </button>
          );
        })}
      </div>
      <div role="tabpanel" data-spell-group={tab}>
        {panel}
      </div>
    </div>
  );
}

type TabKey = 'cantrips' | 'always' | 'chosen' | 'innate';

function SpellTitle({
  spell,
  name,
  note,
  hideLevel,
  bonus,
}: {
  /** Lo que se suma al daño, después de la escuela. */
  bonus?: string;
  spell: SpellJson | undefined;
  name?: string;
  note?: string;
  /** El nivel ya se lee en la celda o en el rótulo de grupo: la línea es la escuela. */
  hideLevel?: boolean;
}) {
  const t = useTexts();
  const level = spell?.level ?? 0;
  const line = [
    ...(note
      ? [note]
      : [
          hideLevel ? null : level === 0 ? t.cantrip : t.spellLevelShort(level),
          spell?.school ? vocabularyLabel('school', spell.school) : null,
        ]),
    bonus,
  ]
    .filter(Boolean)
    .join(' · ');
  return (
    <span className="flex flex-col">
      <span className="flex flex-wrap items-center gap-1.5">
        <span>{name ?? spell?.name ?? spell?.id}</span>
        {spell?.concentration && <Tag>{t.concentration}</Tag>}
        {spell?.ritual && <Tag>{t.ritual}</Tag>}
      </span>
      <span className="mt-0.5 text-[12px] font-normal text-text-muted">{line}</span>
    </span>
  );
}

/** Concentración y ritual: rótulo chico con filete (`OutlinedTag`), más
 *  liviano que una pill para no competir con el nombre. */
export function Tag({ children }: { children: ReactNode }) {
  return (
    <span className="rounded-[var(--radius-pill)] border border-hairline px-1.5 text-[10px] font-normal text-on-surface-variant">
      {children}
    </span>
  );
}

/** Tiempo, alcance, componentes y duración en una línea. Son vocabulario del
 *  catálogo en español: los traduce el motor. */
export function spellMeta(spell: SpellJson): string {
  return [
    spell.castingTime && vocabularyLabel('castingTime', spell.castingTime),
    spell.range && vocabularyLabel('range', spell.range),
    spell.components,
    spell.duration && vocabularyLabel('duration', spell.duration),
  ]
    .filter(Boolean)
    .join(' · ');
}

/** La ficha del conjuro al desplegarlo. Los cuatro datos de lanzamiento son
 *  vocabulario del catálogo en español: los traduce el motor. «Concentrar» va
 *  acá y no en la fila porque la fila ya es el botón del acordeón. */
function SpellDetail({
  spell,
  castLine,
  onConcentrate,
  onSwap,
}: {
  spell: SpellJson;
  /** «Lanzás con…» más el bono al daño; falta si el conjuro no tiene aptitud. */
  castLine?: string;
  onConcentrate?: () => void;
  onSwap?: () => void;
}) {
  const t = useTexts();
  const meta = spellMeta(spell);
  return (
    <>
      {meta && <p className="mb-1.5 text-[12px] text-on-surface">{meta}</p>}
      {castLine && <p className="mb-1.5 text-[12px] text-on-surface">{castLine}</p>}
      {spell.description}
      {spell.higherLevel && <HigherLevelNote level={spell.level} text={spell.higherLevel} />}
      {((spell.concentration && onConcentrate) || onSwap) && (
        <div className="mt-2 flex flex-wrap gap-2">
          {spell.concentration && onConcentrate && (
            <Button tone="secondary" onClick={onConcentrate}>
              {t.spellsConcentrate}
            </Button>
          )}
          {onSwap && (
            <Button tone="secondary" data-action="swap-innate" onClick={onSwap}>
              {t.swapAction}
            </Button>
          )}
        </div>
      )}
    </>
  );
}
