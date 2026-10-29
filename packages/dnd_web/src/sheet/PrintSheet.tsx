import { useEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal, flushSync } from 'react-dom';
import { nameOf } from '../api/catalog';
import { catalogLabel, inventoryOf, vocabularyLabel, type CharacterJson, type JsonObject } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { labelOf } from '../i18n/texts';
import { signed } from './format';
import { classesOf, type SheetModel } from './model';
import { ABILITIES, SKILL_ABILITY } from './vocabulary';

/** El idioma que el motor tiene por universal (`Language.universal`): va
 *  primero, como en Flutter, y el resto por nombre. */
const UNIVERSAL_LANGUAGE = 'common';

/**
 * La ficha para imprimir (`print_sheet.dart`): una hoja propia que solo se ve
 * en papel. Acá, a diferencia de Flutter, la pantalla es DOM y se podría
 * imprimir tal cual, pero saldría con los fondos oscuros, las pestañas y el
 * panel; esta hoja es la misma de Flutter, en blanco y negro.
 *
 * Es papel para jugar con lápiz: lo que cambia en la mesa (PG actuales,
 * espacios gastados, usos de recursos, monedas) sale **en blanco**, con el
 * máximo al lado y casillas para marcar. Los conjuros y rasgos van sin su
 * texto: con las descripciones, un mago de nivel 10 ocupa quince hojas.
 *
 * Todo número sale de `computeSheet` y del motor (`inventoryOf`,
 * `catalogLabel`, `vocabularyLabel`): la hoja solo los acomoda.
 *
 * Se monta en un portal al pie de `body` mientras se imprime (`usePrintSheet`)
 * y se desmonta al terminar ([onDone]); la hoja de estilos de impresión
 * (`index.css`, `.print-sheet`) esconde todo lo demás.
 */
export function PrintSheet({ model, onDone }: { model: SheetModel; onDone: () => void }) {
  const done = useRef(onDone);
  done.current = onDone;
  useEffect(() => {
    // `afterprint` llega también si se cancela el diálogo.
    const finish = () => done.current();
    window.addEventListener('afterprint', finish);
    return () => window.removeEventListener('afterprint', finish);
  }, []);
  return createPortal(<Sheet model={model} />, document.body);
}

/**
 * Imprimir: monta la hoja, abre el diálogo del navegador y la desmonta al
 * cerrarlo. El `print()` va en el clic y no en un efecto: `flushSync` deja la
 * hoja en el DOM antes de llamarlo, y así un efecto que corre dos veces (el
 * modo estricto de React en desarrollo) no abre dos diálogos.
 */
export function usePrintSheet(): { printing: boolean; print: () => void; done: () => void } {
  const [printing, setPrinting] = useState(false);
  return {
    printing,
    print: () => {
      flushSync(() => setPrinting(true));
      window.print();
    },
    done: () => setPrinting(false),
  };
}

function Sheet({ model }: { model: SheetModel }) {
  const t = useTexts();
  const lang = useLang();
  const { character, sheet: s, catalog } = model;
  const p = t.print;
  const sortByName = (a: string, b: string) => a.localeCompare(b, lang);
  const number = new Intl.NumberFormat(lang, { maximumFractionDigits: 2 });

  const classes = classesOf(model)
    .map((c) => t.classLevel(c.name, c.level))
    .join(' / ');
  const origin = [nameOf(catalog.races, character.raceId) ?? character.raceId, nameOf(catalog.backgrounds, character.backgroundId), t.miniClassLine(classes, s.level)]
    .filter(Boolean)
    .join(' · ');

  const hitDice = Object.entries(s.hitDiceBySize)
    .filter(([, n]) => n > 0)
    .sort(([a], [b]) => Number(b) - Number(a));
  const damage = (ids: string[]) => ids.map((id) => labelOf(t.damageTypes, id)).sort(sortByName);

  // Por el nombre traducido: en papel se busca con el dedo.
  const skills = Object.entries(s.skillModifiers).sort(([a], [b]) => sortByName(labelOf(t.skills, a), labelOf(t.skills, b)));

  const profs = [
    ...s.armorProficiencies.map((id) => catalogLabel('armorTraining', id)),
    ...s.weaponProficiencies.map((id) => nameOf(catalog.weapons, id) ?? catalogLabel('weaponProficiency', id)),
    ...s.toolProficiencies.map((id) => catalogLabel('tool', id)),
  ].sort(sortByName);
  const languages = [
    catalogLabel('language', UNIVERSAL_LANGUAGE),
    ...s.languages
      .filter((id) => id !== UNIVERSAL_LANGUAGE)
      .map((id) => catalogLabel('language', id))
      .sort(sortByName),
  ];

  const inventory = inventoryOf(character as unknown as CharacterJson, catalog);

  // Los mismos conjuntos que la pestaña Combate (`SpellList`), para que el
  // papel no diga otra cosa que la pantalla.
  const sc = s.spellcasting;
  const spellById = new Map(catalog.spells.map((sp) => [sp.id as string, sp as SpellJson]));
  const spellsOf = (ids: Iterable<string>) =>
    [...new Set(ids)]
      .map((id) => spellById.get(id))
      .filter((sp): sp is SpellJson => sp !== undefined)
      .sort((a, b) => (a.level ?? 0) - (b.level ?? 0) || (a.name ?? '').localeCompare(b.name ?? '', lang));
  const always = spellsOf(s.alwaysPreparedSpellIds);
  const alwaysIds = new Set(always.map((sp) => sp.id));
  const cantrips = spellsOf([...(character.cantripIds ?? []), ...Object.values(character.classCantripIds ?? {}).flat()]);
  const chosen = spellsOf([...(character.spellIds ?? []), ...Object.values(character.classSpellIds ?? {}).flat()]).filter(
    (sp) => !alwaysIds.has(sp.id),
  );
  const blocks = s.spellcastingBlocks.length > 1 ? s.spellcastingBlocks : sc ? [{ classId: character.classId, spellcasting: sc }] : [];
  const slotRows = (byLevel: Record<string, number>) =>
    Object.entries(byLevel)
      .filter(([, n]) => n > 0)
      .sort(([a], [b]) => Number(a) - Number(b));
  const prepares = sc?.preparation === 'prepared';

  return (
    <div className="print-sheet" lang={lang}>
      {/* Nombre y «Hoja N de M» al pie de cada hoja, en el margen que dibuja
          el navegador (Chrome 131+; el que no lo soporta imprime sin pie). */}
      <style>{pageFooter(character.name, p.pageOf('\u0000', '\u0001'))}</style>
      <header>
        <h1>{character.name}</h1>
        <p>{origin}</p>
      </header>

      {/* ------------------------------------------------------ Hoja 1 */}
      <section className="stats">
        <Stat id="hp" label={t.hitPoints} note={p.currentHp} wide>
          <Blank /> / {s.maxHp}
        </Stat>
        <Stat id="ac" label={t.armor}>{s.armorClass}</Stat>
        <Stat id="temp-hp" label={p.tempHp}>
          <Blank />
        </Stat>
        <Stat id="initiative" label={t.initiative}>{signed(s.initiative)}</Stat>
        <Stat id="speed" label={t.speed}>
          {s.speed} {t.feet}
        </Stat>
        <Stat id="proficiency" label={t.proficiency}>{signed(s.proficiencyBonus)}</Stat>
        <Stat id="passive" label={t.passivePerception}>{s.passivePerception}</Stat>
      </section>

      <div className="cols">
        <div>
          {/* Características y salvaciones en una tabla: es lo que más se
              compara. El modificador va grande porque es lo que se suma. */}
          <h2>{p.abilities}</h2>
          <table className="abilities">
            <thead>
              <tr>
                <th />
                <th className="num">{p.modifier}</th>
                <th className="num">{p.score}</th>
                <th />
                <th className="num">{p.saves}</th>
              </tr>
            </thead>
            <tbody>
              {ABILITIES.map((a) => (
                <tr key={a}>
                  <td>{t.abilities[a]}</td>
                  <td className="num mod">{signed(s.abilityModifiers[a] ?? 0)}</td>
                  <td className="num muted">{s.abilityScores[a]}</td>
                  <td>{s.savingThrowProficiencies.includes(a) ? '●' : ''}</td>
                  <td className="num">{signed(s.savingThrows[a] ?? 0)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <h2>{p.deathSaves}</h2>
          <p className="marks">
            ✓ <Boxes n={3} />
            &emsp;✗ <Boxes n={3} />
          </p>
          {hitDice.length > 0 && (
            <>
              <h2>{p.hitDice}</h2>
              {hitDice.map(([size, n]) => (
                <p key={size} className="marks">
                  {n}d{size} <Boxes n={n} />
                </p>
              ))}
            </>
          )}
          {s.darkvision !== null && (
            <p>
              {p.darkvision}: {s.darkvision} {t.feet}
            </p>
          )}
          {s.resistances.length > 0 && <p>{t.resistances(damage(s.resistances).join(', '))}</p>}
          {s.immunities.length > 0 && <p>{t.immunities(damage(s.immunities).join(', '))}</p>}
        </div>
        <div>
          {/* ○ sin competencia, ● competente, ◉ pericia: se ve igual en
              blanco y negro. */}
          <h2>{t.skillsHeading}</h2>
          <table>
            <tbody>
              {skills.map(([skill, mod]) => {
                const ability = SKILL_ABILITY[skill];
                const mark = s.expertiseSkills.includes(skill) ? '◉' : s.skillProficiencies.includes(skill) ? '●' : '○';
                return (
                  <tr key={skill}>
                    <td>
                      {mark} {labelOf(t.skills, skill)} {ability && <span className="muted">{t.abilityAbbr[ability]}</span>}
                    </td>
                    <td className="num">{signed(mod)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {s.attacks.length > 0 && (
        <>
          <h2>{t.attacksHeading}</h2>
          <table className="wide">
            <thead>
              <tr>
                <th />
                <th>{p.bonus}</th>
                <th>{p.damage}</th>
                <th>{p.range}</th>
              </tr>
            </thead>
            <tbody>
              {s.attacks.map((a) => (
                <tr key={`${a.weaponId}-${a.sourceEntryId ?? ''}-${a.offHand}`}>
                  <td>{a.name}</td>
                  <td className="num">{signed(a.attackBonus)}</td>
                  <td>
                    {[`${a.damage} ${labelOf(t.damageTypes, a.damageType)}`, ...(a.extraDamage ?? []).map((x) => `${x.dice} ${labelOf(t.damageTypes, x.type)}`)].join(' + ')}
                  </td>
                  <td>{a.range ? `${a.range[0]}/${a.range[1]} ${t.feet}` : ''}</td>
                </tr>
              ))}
              <EmptyRows cols={4} n={1} />
            </tbody>
          </table>
        </>
      )}

      <div className="cols">
        <div>
          <h2>{p.proficiencies}</h2>
          <p>{profs.join(', ')}</p>
        </div>
        <div>
          <h2>{t.creatureLanguages}</h2>
          <p>{languages.join(', ')}</p>
        </div>
      </div>

      {/* Lo que la ficha en pantalla marca con un toque y en papel no tiene
          dónde: la Inspiración, el Cansancio, las condiciones y lo que se
          anota. */}
      <div className="cols">
        <div>
          <h2>{p.state}</h2>
          <p className="marks">
            {t.heroicInspiration} <Boxes n={1} />
            &emsp;{p.exhaustion} <Boxes n={6} />
          </p>
          <p>{t.conditionsHeading}</p>
          <Lines n={1} />
        </div>
        <div>
          <h2>{p.notes}</h2>
          <Lines n={3} />
        </div>
      </div>

      {/* ------------------------------------------------------ Hoja 2 */}
      <div className="page">
        {s.resources.length > 0 && (
          <>
            <h2>{t.resourcesAndRests}</h2>
            <table className="wide">
              <thead>
                <tr>
                  <th />
                  <th>{p.uses}</th>
                  <th>{p.recharge}</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {s.resources.map((r) => (
                  <tr key={`${r.classId ?? ''}:${r.id}`}>
                    <td>{r.name}</td>
                    {/* Una reserva de 20 puntos son 20 casillas que nadie
                        tacha: va con un hueco, como los PG. */}
                    <td className="marks">
                      {r.pool || r.max > 10 ? (
                        <>
                          <Blank /> / {r.max}
                        </>
                      ) : (
                        <Boxes n={r.max} />
                      )}
                    </td>
                    <td>{t.recharge[r.recharge]}</td>
                    <td>
                      {[
                        r.saveDc !== undefined
                          ? r.saveAbility
                            ? p.saveDcAbility(r.saveDc, t.abilityAbbr[r.saveAbility])
                            : t.dcValue(r.saveDc)
                          : null,
                        r.damage ?? null,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </>
        )}

        {s.passives.length > 0 && (
          <>
            <h2>{t.featuresAndFeats}</h2>
            <ul className="list">
              {s.passives.map((f, i) => (
                <li key={`${i}-${f.name}`}>{f.name}</li>
              ))}
            </ul>
          </>
        )}

        {/* La tabla sale aunque no haya nada: los renglones vacíos son para lo
            que se consiga jugando. */}
        <h2>{p.inventory}</h2>
        <table className="wide">
          <thead>
            <tr>
              <th>{p.qty}</th>
              <th>{p.item}</th>
              <th>{p.equipped}</th>
              <th className="num">{p.weight}</th>
            </tr>
          </thead>
          <tbody>
            {inventory.map((line) => (
              <tr key={line.entryId}>
                <td className="num">{line.quantity}</td>
                <td>{line.name}</td>
                <td>{line.equipped ? '●' : ''}</td>
                <td className="num">{line.weight === 0 ? '' : `${number.format(line.weight * line.quantity)} ${t.pounds}`}</td>
              </tr>
            ))}
            <EmptyRows cols={4} n={6} />
          </tbody>
        </table>
        {/* Las monedas y la carga cambian en cada sesión: en blanco, como los
            PG, y no con lo que había el día que se imprimió. */}
        <p className="coins">
          {(['pp', 'gp', 'ep', 'sp', 'cp'] as const).map((c) => (
            <span key={c}>
              {t.coins[c].abbr} <Blank />
            </span>
          ))}
        </p>
        <p>
          {p.load} <Blank /> / {number.format(s.carryingCapacity)} {t.pounds}
        </p>
      </div>

      {/* ------------------------------------------------------ Hoja 3 */}
      {(sc || s.innateSpells.length > 0) && (
        <div className="page">
          <h2>{p.spells}</h2>
          {blocks.map((b) => (
            <p key={b.classId}>
              {blocks.length > 1 && `${nameOf(catalog.classes, b.classId) ?? b.classId}: `}
              {p.casterLine(b.spellcasting.saveDc, signed(b.spellcasting.attackBonus), t.abilityAbbr[b.spellcasting.ability])}
            </p>
          ))}
          {slotRows(s.normalSpellSlotsByLevel).length > 0 && (
            <>
              <h3>{p.slots}</h3>
              {slotRows(s.normalSpellSlotsByLevel).map(([level, n]) => (
                <p key={level} className="marks">
                  {t.slotLevel(level)} <Boxes n={n} round />
                </p>
              ))}
            </>
          )}
          {slotRows(s.pactSlotsByLevel).length > 0 && (
            <>
              <h3>{p.pactSlots}</h3>
              {slotRows(s.pactSlotsByLevel).map(([level, n]) => (
                <p key={level} className="marks">
                  {t.slotLevel(level)} <Boxes n={n} round />
                </p>
              ))}
            </>
          )}
          <SpellTable title={p.cantrips} spells={cantrips} />
          <SpellTable title={p.alwaysPrepared} spells={always} />
          {/* Quien prepara cambia la lista entre descansos: una casilla por
              conjuro para marcar los de hoy sin reimprimir. */}
          <SpellTable title={prepares ? p.prepared : p.known} spells={chosen} checkable={prepares} />
          {s.innateSpells.length > 0 && (
            <>
              <h3>{p.fromFeatures}</h3>
              <table className="wide">
                <tbody>
                  {s.innateSpells.map((i) => (
                    <tr key={`${i.source}-${i.spellId}`}>
                      <td>{i.name}</td>
                      <td>{labelOf(t.innateUses, i.use)}</td>
                      <td>
                        {t.dcValue(i.saveDc)} · {t.attackValue(signed(i.attackBonus))}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          )}
        </div>
      )}
    </div>
  );
}

type SpellJson = JsonObject & {
  id: string;
  name?: string;
  level?: number;
  castingTime?: string;
  range?: string;
  components?: string;
  duration?: string;
  concentration?: boolean;
  ritual?: boolean;
};

function SpellTable({ title, spells, checkable = false }: { title: string; spells: SpellJson[]; checkable?: boolean }) {
  const t = useTexts();
  const p = t.print;
  if (spells.length === 0) return null;
  return (
    <>
      <h3>{title}</h3>
      <table className="wide spells">
        <thead>
          <tr>
            {checkable && <th />}
            <th />
            <th />
            <th>{p.castingTime}</th>
            <th>{p.range}</th>
            <th>{p.components}</th>
            <th>{p.duration}</th>
          </tr>
        </thead>
        <tbody>
          {spells.map((sp) => (
            <tr key={sp.id}>
              {checkable && (
                <td className="check">
                  <Boxes n={1} />
                </td>
              )}
              {/* (C) y (R), como en la pestaña: entran en la celda del nombre
                  y se leen sin leyenda. */}
              <td className="name">
                {sp.name}
                {sp.concentration && ' (C)'}
                {sp.ritual && ' (R)'}
              </td>
              <td>{(sp.level ?? 0) === 0 ? t.cantrip : t.spellLevelShort(sp.level ?? 0)}</td>
              <td>{sp.castingTime ? vocabularyLabel('castingTime', sp.castingTime) : ''}</td>
              <td>{sp.range ? vocabularyLabel('range', sp.range) : ''}</td>
              <td>{sp.components}</td>
              <td>{sp.duration ? vocabularyLabel('duration', sp.duration) : ''}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

function Stat({ id, label, note, wide = false, children }: { id: string; label: string; note?: string; wide?: boolean; children: ReactNode }) {
  return (
    <div className={wide ? 'stat wide' : 'stat'} data-stat={id}>
      <span>{label}</span>
      <b>{children}</b>
      {note && <small>{note}</small>}
    </div>
  );
}

/** Un hueco para escribir a lápiz. */
const Blank = () => <i className="blank" />;

function Boxes({ n, round = false }: { n: number; round?: boolean }) {
  return (
    <>
      {Array.from({ length: n }, (_, i) => (
        <i key={i} className={round ? 'dot' : 'box'} />
      ))}
    </>
  );
}

function Lines({ n }: { n: number }) {
  return (
    <div className="lines">
      {Array.from({ length: n }, (_, i) => (
        <i key={i} />
      ))}
    </div>
  );
}

function EmptyRows({ cols, n }: { cols: number; n: number }) {
  return (
    <>
      {Array.from({ length: n }, (_, r) => (
        <tr key={`empty-${r}`} className="empty">
          {Array.from({ length: cols }, (_, c) => (
            <td key={c} />
          ))}
        </tr>
      ))}
    </>
  );
}

/** El pie de cada hoja. El nombre va como cadena CSS: `<` se escapa porque la
 *  regla vive en un `<style>`, y un nombre con `</style>` cerraría el bloque. */
function pageFooter(name: string, pageOf: string): string {
  const css = (v: string) => v.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/</g, '\\3C ').replace(/\n/g, '\\A ');
  const counters = css(pageOf).replace('\u0000', '" counter(page) "').replace('\u0001', '" counter(pages) "');
  return `@page { @bottom-left { content: "${css(name)}"; } @bottom-right { content: "${counters}"; } }`;
}
