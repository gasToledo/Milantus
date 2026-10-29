import type { ReactNode } from 'react';
import { vocabularyLabel, type InnateSpell, type JsonObject } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { Eyebrow } from '../ui/data';
import { Accordion } from '../ui/disclosure';

/** Lo que una fila lee de un conjuro del catálogo (`Spell.toJson`). */
type SpellJson = JsonObject & {
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
};

/**
 * Los conjuros del personaje, como la sección de Flutter (`_spellsCard`):
 * trucos, siempre preparados, preparados (o conocidos) y los que concede un
 * rasgo. Cada uno se despliega con su ficha (tiempo, alcance, componentes,
 * duración y descripción). Solo lectura: no se preparan ni se lanzan acá.
 *
 * Lo elegido se junta como en Flutter: la lista vieja y las de cada clase,
 * sin repetir. Nada de esto es una regla: qué está siempre preparado y qué
 * conceden los rasgos lo dice el motor (`alwaysPreparedSpellIds`,
 * `innateSpells`).
 */
export function SpellList({
  cantripIds,
  spellIds,
  alwaysPreparedIds,
  innate,
  preparation,
  catalog,
  innateNote,
}: {
  cantripIds: string[];
  spellIds: string[];
  alwaysPreparedIds: string[];
  innate: InnateSpell[];
  preparation: 'prepared' | 'known' | null;
  catalog: JsonObject[];
  innateNote: (s: InnateSpell) => string;
}) {
  const t = useTexts();
  const lang = useLang();
  const byId = new Map(catalog.map((s) => [s.id, s as SpellJson]));
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

  if (cantrips.length + always.length + spells.length + innate.length === 0) {
    return <p className="text-[13px] text-text-muted">{t.spellsNoneChosen}</p>;
  }

  const group = (id: string, title: string, list: SpellJson[]) =>
    list.length > 0 && (
      <section aria-labelledby={`spells-${id}`} data-spell-group={id}>
        <Eyebrow className="mb-1">
          <span id={`spells-${id}`}>{title}</span>
        </Eyebrow>
        <Accordion
          headingLevel={4}
          items={list.map((s) => ({
            id: s.id,
            title: <SpellTitle spell={s} />,
            content: <SpellDetail spell={s} />,
          }))}
        />
      </section>
    );

  return (
    <div className="flex flex-col gap-3.5">
      {group('cantrips', t.spellsCantripsTitle, cantrips)}
      {group('always', t.spellsAlwaysPrepared, always)}
      {group('chosen', preparation === 'known' ? t.spellsKnownTitle : t.spellsPreparedTitle, spells)}
      {innate.length > 0 && (
        <section aria-labelledby="spells-innate" data-spell-group="innate">
          <Eyebrow className="mb-1">
            <span id="spells-innate">{t.spellsFromFeatures}</span>
          </Eyebrow>
          <Accordion
            headingLevel={4}
            items={innate.map((i) => {
              const s = byId.get(i.spellId);
              return {
                id: `innate-${i.spellId}`,
                // El nombre que da el motor (puede venir del rasgo) y su uso,
                // CD y ataque, que son los del rasgo y no los de la clase.
                title: <SpellTitle spell={s} name={i.name} note={innateNote(i)} />,
                content: s ? <SpellDetail spell={s} /> : null,
              };
            })}
          />
        </section>
      )}
    </div>
  );
}

function SpellTitle({ spell, name, note }: { spell: SpellJson | undefined; name?: string; note?: string }) {
  const t = useTexts();
  const level = spell?.level ?? 0;
  const line =
    note ??
    [
      level === 0 ? t.cantrip : t.spellLevelShort(level),
      spell?.school ? vocabularyLabel('school', spell.school) : null,
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
function Tag({ children }: { children: ReactNode }) {
  return (
    <span className="rounded-[var(--radius-pill)] border border-hairline px-1.5 text-[10px] font-normal text-on-surface-variant">
      {children}
    </span>
  );
}

/** La ficha del conjuro al desplegarlo. Los cuatro datos de lanzamiento son
 *  vocabulario del catálogo en español: los traduce el motor. */
function SpellDetail({ spell }: { spell: SpellJson }) {
  const meta = [
    spell.castingTime && vocabularyLabel('castingTime', spell.castingTime),
    spell.range && vocabularyLabel('range', spell.range),
    spell.components,
    spell.duration && vocabularyLabel('duration', spell.duration),
  ]
    .filter(Boolean)
    .join(' · ');
  return (
    <>
      {meta && <p className="mb-1.5 text-[12px] text-on-surface">{meta}</p>}
      {spell.description}
    </>
  );
}
