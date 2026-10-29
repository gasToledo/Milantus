// Las entradas del Códice, una función por categoría como `codex_entries.dart`
// de Flutter, para que el mismo contenido se lea igual en los dos clientes.
// Todo sale del catálogo (oficial + homebrew) tal cual o del motor: los
// rótulos (`catalogLabel`, `vocabularyLabel`) y los precios (`formatCost`).
// Nada de esto calcula una regla: el Códice muestra el contenido, no lo aplica.
import {
  catalogLabel,
  catalogLabelOrder,
  formatCost,
  vocabularyLabel,
  type Catalog,
  type JsonObject,
} from '../engine';
import type { Lang, Texts } from '../i18n/texts';
import type { CodexCategory, SheetTab } from '../router';

export interface CodexFact {
  label: string;
  value: string;
}

export interface CodexTrait {
  name: string;
  description: string;
}

/** Lo que va debajo del encabezado del detalle, en este orden. */
export interface CodexDetail {
  /** Datos cortos en placas; cada grupo es una fila aparte. */
  facts: CodexFact[][];
  prose?: string;
  /** Rasgos con nombre: por nivel (clases, subclases, linajes), propiedades. */
  sections: { title: string; traits: CodexTrait[] }[];
  /** Una lista de nombres relacionados: linajes de una especie, subclases de
   *  una clase, clases que preparan un conjuro. */
  related?: { title: string; names: string[] };
  /** Solo el glosario: texto propio en párrafos, con el ejemplo aparte, y lo
   *  que dos entradas llevan además (la tabla de modificadores, los estados). */
  glossary?: { paragraphs: string[]; example?: string; extra?: 'modifiers' | 'conditions' };
  /** Solo las guías: el texto corrido, o los pasos del primer combate, o la
   *  ficha pestaña por pestaña, y el consejo final. */
  guide?: {
    paragraphs: string[];
    steps?: { title: string; text: string }[];
    tabs?: Record<SheetTab, string>;
    tip?: string;
  };
}

export interface CodexEntry {
  id: string;
  name: string;
  subtitle: string;
  /** Clave de `sources` en los textos; vacía si no hay. */
  source: string;
  /** El valor por el que se filtra la categoría, o `null` si no tiene filtro. */
  facet: string | null;
  /** El orden de [facet] entre los filtros. */
  facetRank: number;
  /** Se arma recién al abrir la entrada: son ~1300 en total. */
  detail: () => CodexDetail;
}

/** Las categorías en el orden del panel, con su grupo de la portada. */
export const CATEGORY_GROUPS: { group: 'start' | 'character' | 'gear'; categories: CodexCategory[] }[] = [
  { group: 'start', categories: ['glossary', 'guides'] },
  { group: 'character', categories: ['races', 'lineages', 'classes', 'subclasses', 'backgrounds', 'feats'] },
  { group: 'gear', categories: ['spells', 'magicItems', 'weapons', 'armor', 'gear'] },
];

/**
 * El glosario en orden de lectura —de los dados al DM—, como `_glossary` de
 * Flutter: quien empieza lo recorre de arriba abajo y cada término se apoya en
 * los de antes. Por eso no va alfabético.
 */
const GLOSSARY: [keyof Texts['glossaryGroups'], (keyof Texts['glossary'])[]][] = [
  ['dice', ['dice', 'notation', 'd20-test', 'advantage', 'dc']],
  ['character', ['abilities', 'proficiency', 'skills', 'saves', 'hit-points', 'armor-class', 'level']],
  ['combat', ['initiative', 'turn', 'attack', 'critical', 'zero-hp', 'conditions']],
  ['magic', ['spells', 'slots', 'concentration', 'rests', 'inspiration']],
  ['dm', ['challenge', 'npcs', 'difficulty']],
];

function glossaryEntries(t: Texts): CodexEntry[] {
  return GLOSSARY.flatMap(([group, ids], rank) =>
    ids.map((id) => {
      const g: { title: string; body: string[]; example?: string } = t.glossary[id];
      return {
        id,
        name: g.title,
        subtitle: t.glossaryGroups[group],
        // Texto nuestro y no de un libro: sin procedencia.
        source: '',
        facet: t.glossaryGroups[group],
        facetRank: rank,
        detail: () => ({
          facts: [],
          sections: [],
          glossary: {
            paragraphs: g.body,
            example: g.example,
            extra: id === 'abilities' ? 'modifiers' : id === 'conditions' ? 'conditions' : undefined,
          },
        }),
      };
    }),
  );
}

/** Las guías en el orden en que le sirven a quien empieza, como en Flutter:
 *  qué es una partida, armar el personaje, la primera pelea y leer la ficha. */
const GUIDES: { id: string; key: keyof Texts['guides'] }[] = [
  { id: 'session', key: 'session' },
  { id: 'creation', key: 'creation' },
  { id: 'first-combat', key: 'firstCombat' },
  { id: 'sheet', key: 'sheet' },
];

function guideEntries(t: Texts): CodexEntry[] {
  return GUIDES.map(({ id, key }) => {
    const g: {
      title: string;
      body?: string[];
      steps?: { title: string; text: string }[];
      tabs?: Record<SheetTab, string>;
      tip?: string;
    } = t.guides[key];
    return {
      id,
      name: g.title,
      subtitle: '',
      source: '',
      facet: null,
      facetRank: 0,
      detail: () => ({
        facts: [],
        sections: [],
        guide: { paragraphs: g.body ?? [], steps: g.steps, tabs: g.tabs, tip: g.tip },
      }),
    };
  });
}

/** Para buscar sin que importen tildes ni mayúsculas (`foldForSearch`). */
export const fold = (s: string): string => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

type Json = JsonObject;
const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const num = (v: unknown): number => (typeof v === 'number' ? v : 0);
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
const objs = (v: unknown): Json[] => (Array.isArray(v) ? v.filter((x): x is Json => typeof x === 'object' && x !== null) : []);

/**
 * Las entradas de [category], ordenadas como las lista el Códice: por nombre
 * en el idioma activo, y los conjuros por nivel y después por nombre.
 */
export function codexEntries(category: CodexCategory, catalog: Catalog, t: Texts, lang: Lang): CodexEntry[] {
  const ctx = new Ctx(catalog, t, lang);
  switch (category) {
    case 'glossary':
      return glossaryEntries(t);
    case 'guides':
      return guideEntries(t);
    case 'races':
      return ctx.sorted(catalog.races).map((r) => ctx.race(r));
    case 'lineages':
      return ctx.sorted(catalog.lineages).map((l) => ctx.lineage(l));
    case 'classes':
      return ctx.sorted(catalog.classes).map((c) => ctx.klass(c));
    case 'subclasses':
      return ctx.sorted(catalog.subclasses).map((s) => ctx.subclass(s));
    case 'backgrounds':
      return ctx.sorted(catalog.backgrounds).map((b) => ctx.background(b));
    case 'feats':
      return ctx.sorted(catalog.feats).map((f) => ctx.feat(f));
    case 'spells':
      return ctx
        .sorted(catalog.spells)
        .sort((a, b) => num(a.level) - num(b.level))
        .map((s) => ctx.spell(s));
    case 'magicItems':
      return ctx.sorted(catalog.items.filter((i) => typeof i.rarity === 'string')).map((i) => ctx.magicItem(i));
    case 'weapons':
      return ctx.sorted(catalog.weapons).map((w) => ctx.weapon(w));
    case 'armor':
      return ctx.sorted(catalog.armor).map((a) => ctx.armor(a));
    case 'gear':
      return ctx.sorted(catalog.items.filter((i) => typeof i.rarity !== 'string')).map((i) => ctx.gear(i));
  }
}

class Ctx {
  private readonly pounds: Intl.NumberFormat;
  private readonly coinLabels: Record<string, string>;

  constructor(
    private readonly catalog: Catalog,
    private readonly t: Texts,
    private readonly lang: Lang,
  ) {
    this.pounds = new Intl.NumberFormat(lang, { maximumFractionDigits: 2 });
    this.coinLabels = Object.fromEntries(Object.entries(t.coins).map(([k, v]) => [k, v.abbr]));
  }

  sorted(list: Json[]): Json[] {
    return [...list].sort((a, b) => str(a.name).localeCompare(str(b.name), this.lang, { sensitivity: 'base' }));
  }

  private nameIn(list: Json[], id: string): string {
    return str(list.find((e) => e.id === id)?.name) || id;
  }

  private base(e: Json, subtitle: string, detail: () => CodexDetail, facet: string | null = null, facetRank = 0): CodexEntry {
    return { id: str(e.id), name: str(e.name) || str(e.id), subtitle, source: str(e.source), facet, facetRank, detail };
  }

  private abbrs(ids: string[]): string {
    return ids.map((a) => catalogLabel('ability', a)).join(' · ');
  }

  private weightAndPrice(e: Json): CodexFact[] {
    const t = this.t;
    return [
      ...(num(e.weight) > 0 ? [{ label: t.codexWeight, value: `${this.pounds.format(num(e.weight))} lb` }] : []),
      ...(num(e.costCp) > 0 ? [{ label: t.codexPrice, value: formatCost(num(e.costCp), this.coinLabels) }] : []),
    ];
  }

  /** Rasgos de un JSON de efectos: los que tienen nombre y descripción. */
  private traits(effects: unknown): CodexTrait[] {
    return objs(effects)
      .filter((e) => e.type === 'passiveTrait' && str(e.name))
      .map((e) => ({ name: str(e.name), description: str(e.description) }));
  }

  /** Rasgos agrupados por nivel, como `_features` de Flutter. */
  private features(list: unknown): CodexDetail['sections'] {
    const byLevel = new Map<number, CodexTrait[]>();
    for (const f of objs(list)) {
      const level = num(f.level);
      byLevel.set(level, [...(byLevel.get(level) ?? []), { name: str(f.name), description: str(f.description) }]);
    }
    return [...byLevel.keys()]
      .sort((a, b) => a - b)
      .map((level) => ({ title: this.t.codexLevelN(level), traits: byLevel.get(level)! }));
  }

  race(r: Json): CodexEntry {
    const t = this.t;
    const type = vocabularyLabel('creatureType', str(r.creatureType));
    return this.base(r, str(r.tagline) || type, () => {
      const sizes = strs(r.sizeOptions);
      const darkvision = objs(r.effects).filter((e) => e.type === 'darkvision');
      const lineages = this.sorted(this.catalog.lineages.filter((l) => l.raceId === r.id)).map((l) => str(l.name));
      const traits = this.traits(r.effects);
      return {
        facts: [
          [
            { label: t.codexType, value: type },
            {
              label: t.codexSize,
              value: (sizes.length > 0 ? sizes : [str(r.size)])
                .map((s) => vocabularyLabel('size', s))
                .join(` ${t.wordOr} `),
            },
            { label: t.codexSpeed, value: t.codexFeet(num(r.speed)) },
            ...darkvision.map((d) => ({ label: t.codexDarkvision, value: t.codexFeet(num(d.range)) })),
          ],
        ],
        prose: str(r.description) || undefined,
        sections: traits.length > 0 ? [{ title: t.codexTraits, traits }] : [],
        related: lineages.length > 0 ? { title: t.codexCategories.lineages, names: lineages } : undefined,
      };
    });
  }

  lineage(l: Json): CodexEntry {
    const race = this.nameIn(this.catalog.races, str(l.raceId));
    return this.base(l, this.t.codexLineageOf(race), () => ({
      facts: [],
      prose: str(l.description) || undefined,
      sections: this.features(l.features),
    }));
  }

  klass(c: Json): CodexEntry {
    const t = this.t;
    const saves = this.abbrs(strs(c.savingThrows));
    return this.base(c, `d${num(c.hitDie)} · ${saves}`, () => {
      const armor = strs(c.armorProficiencies);
      const weapons = strs(c.weaponProficiencies);
      const skillCount = num(c.skillChoiceCount);
      const skillFrom = strs(c.skillChoiceFrom);
      const subclasses = this.sorted(this.catalog.subclasses.filter((s) => s.classId === c.id)).map((s) => str(s.name));
      return {
        facts: [
          [
            { label: t.codexHitDie, value: `d${num(c.hitDie)}` },
            { label: t.codexSaves, value: saves },
            { label: t.codexSubclass, value: t.codexLevelN(num(c.subclassLevel)) },
          ],
          [
            ...(armor.length > 0
              ? [{ label: t.codexCategories.armor, value: armor.map((a) => catalogLabel('armorTraining', a)).join(', ') }]
              : []),
            ...(weapons.length > 0
              ? [{ label: t.codexCategories.weapons, value: weapons.map((w) => catalogLabel('weaponProficiency', w)).join(', ') }]
              : []),
            ...(skillCount > 0
              ? [
                  {
                    label: t.codexSkills,
                    value:
                      skillFrom.length === 0
                        ? t.codexPickAny(skillCount)
                        : t.codexPickFrom(skillCount, skillFrom.map((s) => catalogLabel('skill', s)).join(', ')),
                  },
                ]
              : []),
          ],
        ],
        sections: this.features(c.features),
        related: subclasses.length > 0 ? { title: t.codexCategories.subclasses, names: subclasses } : undefined,
      };
    });
  }

  subclass(s: Json): CodexEntry {
    const klass = this.nameIn(this.catalog.classes, str(s.classId));
    return this.base(
      s,
      this.t.codexSubclassOf(klass),
      () => ({ facts: [], prose: str(s.description) || undefined, sections: this.features(s.features) }),
      klass,
    );
  }

  background(b: Json): CodexEntry {
    const t = this.t;
    const abilities = strs(b.abilityOptions);
    return this.base(b, str(b.tagline) || this.abbrs(abilities), () => {
      const skills = strs(b.skillProficiencies);
      const tools = strs(b.toolProficiencies);
      const feat = str(b.originFeatId);
      return {
        facts: [
          [
            ...(abilities.length > 0 ? [{ label: t.codexAbilities, value: this.abbrs(abilities) }] : []),
            ...(skills.length > 0 ? [{ label: t.codexSkills, value: skills.map((s) => catalogLabel('skill', s)).join(', ') }] : []),
            ...(tools.length > 0 ? [{ label: t.codexTools, value: tools.map((x) => catalogLabel('tool', x)).join(', ') }] : []),
            ...(feat ? [{ label: t.codexOriginFeat, value: this.nameIn(this.catalog.feats, feat) }] : []),
          ],
        ],
        prose: str(b.description) || undefined,
        sections: [],
      };
    });
  }

  private featOrder?: string[];
  feat(f: Json): CodexEntry {
    const t = this.t;
    this.featOrder ??= catalogLabelOrder('featCategory');
    const category = catalogLabel('featCategory', str(f.category));
    return this.base(
      f,
      category,
      () => {
        const prerequisite = this.prerequisite(f.prerequisite);
        const traits = this.traits(f.effects);
        // `featSummary`: la descripción si la tiene; si no, sus rasgos.
        // ponytail: sin rasgo ni descripción (Duro, Resiliente) Flutter
        // describe los efectos uno por línea con `describeEffect`, que vive en
        // la app y no en el motor; acá esas dotes quedan sin prosa. La salida es
        // mover `describeEffect` al motor y exponerlo en el puente.
        const prose = str(f.description) || traits.map((x) => x.description).join(' ');
        return {
          facts: [
            [
              { label: t.codexCategory, value: category },
              ...(prerequisite ? [{ label: t.codexRequirements, value: prerequisite }] : []),
              ...(f.repeatable === true ? [{ label: t.codexRepeatable, value: t.yes }] : []),
            ],
          ],
          prose: prose || undefined,
          sections: [],
        };
      },
      category,
      this.featOrder.indexOf(str(f.category)),
    );
  }

  /** Los requisitos de una dote en una línea (`_prerequisite` de Flutter). */
  private prerequisite(p: unknown): string | null {
    if (typeof p !== 'object' || p === null) return null;
    const pre = p as Json;
    const t = this.t;
    const scores = (m: unknown, join: string) =>
      typeof m === 'object' && m !== null
        ? Object.entries(m as Record<string, number>)
            .map(([a, n]) => `${catalogLabel('ability', a)} ${n}`)
            .join(join)
        : '';
    const prof = str(pre.requiredProficiency);
    const parts = [
      typeof pre.minLevel === 'number' ? t.codexLevelN(pre.minLevel) : '',
      scores(pre.minAbilityScores, ` ${t.wordAnd} `),
      scores(pre.anyAbilityScores, ` ${t.wordOr} `),
      pre.requiredClassId ? this.nameIn(this.catalog.classes, str(pre.requiredClassId)) : '',
      str(pre.requiredClassFeature),
      strs(pre.requiredFeatIds)
        .map((id) => this.nameIn(this.catalog.feats, id))
        .join(` ${t.wordOr} `),
      pre.requiredFeatCategory ? t.codexPrereqFeat(catalogLabel('featCategory', str(pre.requiredFeatCategory))) : '',
      prof ? (prof === 'spellcasting' ? t.codexPrereqCast : t.codexPrereqProf(prof)) : '',
    ].filter(Boolean);
    return parts.length > 0 ? parts.join(' · ') : null;
  }

  spell(s: Json): CodexEntry {
    const t = this.t;
    const level = num(s.level);
    const levelLabel = level === 0 ? t.cantrip : t.spellLevelShort(level);
    return this.base(
      s,
      `${levelLabel} · ${vocabularyLabel('school', str(s.school))}`,
      () => {
        const time = vocabularyLabel('castingTime', str(s.castingTime));
        const duration = vocabularyLabel('duration', str(s.duration));
        const classes = strs(s.classes)
          .map((id) => this.nameIn(this.catalog.classes, id))
          .sort((a, b) => a.localeCompare(b, this.lang));
        return {
          facts: [
            [
              { label: t.codexCastingTime, value: s.ritual === true ? t.codexRitual(time) : time },
              { label: t.codexRange, value: vocabularyLabel('range', str(s.range)) },
              { label: t.codexComponents, value: str(s.components) },
              { label: t.codexDuration, value: s.concentration === true ? t.codexConcentration(duration) : duration },
            ],
          ],
          prose: str(s.description) || undefined,
          sections: [],
          related: classes.length > 0 ? { title: t.codexCanPrepare, names: classes } : undefined,
        };
      },
      levelLabel,
      level,
    );
  }

  private rarityOrder?: string[];
  magicItem(i: Json): CodexEntry {
    const t = this.t;
    this.rarityOrder ??= catalogLabelOrder('rarity');
    const rarity = catalogLabel('rarity', str(i.rarity));
    const attune = i.requiresAttunement === true;
    return this.base(
      i,
      attune ? t.codexRarityAttune(rarity) : rarity,
      () => {
        const description = str(i.description);
        // La primera línea es la de tipo y rareza, que ya está en las placas.
        const cut = description.indexOf('\n');
        return {
          facts: [
            [
              { label: t.codexRarity, value: rarity },
              { label: t.codexAttunement, value: attune ? t.codexRequires : t.codexNotRequired },
              ...(typeof i.maxCharges === 'number' ? [{ label: t.codexCharges, value: String(i.maxCharges) }] : []),
              ...this.weightAndPrice(i),
            ],
          ],
          prose: (cut < 0 ? description : description.slice(cut + 1)) || undefined,
          sections: [],
        };
      },
      rarity,
      this.rarityOrder.indexOf(str(i.rarity)),
    );
  }

  weapon(w: Json): CodexEntry {
    const t = this.t;
    const damage = `${str(w.damageDice)} ${catalogLabel('damageType', str(w.damageType)).toLowerCase()}`;
    const category = catalogLabel('weaponProficiency', str(w.category));
    return this.base(
      w,
      `${category} · ${damage}`,
      () => {
        const properties = strs(w.properties);
        const range = num(w.rangeNormal) > 0 ? t.codexRangeFeet(num(w.rangeNormal), num(w.rangeLong)) : '';
        return {
          facts: [
            [
              { label: t.codexDamage, value: damage },
              ...(str(w.versatileDice) ? [{ label: t.codexTwoHanded, value: str(w.versatileDice) }] : []),
              ...(range ? [{ label: t.codexRange, value: range }] : []),
              ...(str(w.mastery) ? [{ label: t.codexMastery, value: catalogLabel('mastery', str(w.mastery)) }] : []),
              ...this.weightAndPrice(w),
            ],
          ],
          prose: str(w.description) || undefined,
          sections:
            properties.length > 0
              ? [
                  {
                    title: t.codexProperties,
                    traits: properties.map((p) => ({
                      name: catalogLabel('weaponProperty', p),
                      description: catalogLabel('weaponPropertyRule', p),
                    })),
                  },
                ]
              : [],
        };
      },
      category,
      w.category === 'simple' ? 0 : 1,
    );
  }

  armor(a: Json): CodexEntry {
    const t = this.t;
    const category = catalogLabel('armorTraining', str(a.category));
    const base = num(a.baseAc);
    const ac =
      a.category === 'shield'
        ? `+${base}`
        : a.addDexMod !== true
          ? String(base)
          : typeof a.maxDexBonus === 'number'
            ? t.codexAcDexMax(base, a.maxDexBonus)
            : t.codexAcDex(base);
    return this.base(
      a,
      t.codexArmorSubtitle(category, ac),
      () => ({
        facts: [
          [
            { label: t.codexAc, value: ac },
            ...(typeof a.strengthRequirement === 'number' ? [{ label: t.codexStrength, value: String(a.strengthRequirement) }] : []),
            ...(a.stealthDisadvantage === true ? [{ label: t.codexStealth, value: t.codexDisadvantage }] : []),
            ...this.weightAndPrice(a),
          ],
        ],
        prose: str(a.description) || undefined,
        sections: [],
      }),
      category,
      ['light', 'medium', 'heavy', 'shield'].indexOf(str(a.category)),
    );
  }

  private itemOrder?: string[];
  gear(i: Json): CodexEntry {
    const t = this.t;
    this.itemOrder ??= catalogLabelOrder('itemCategory');
    const category = catalogLabel('itemCategory', str(i.category));
    return this.base(
      i,
      category,
      () => ({
        facts: [
          [
            { label: t.codexCategory, value: category },
            ...(num(i.bundleSize) > 1 ? [{ label: t.codexPackOf, value: String(num(i.bundleSize)) }] : []),
            ...this.weightAndPrice(i),
          ],
        ],
        prose: str(i.description) || undefined,
        sections: [],
      }),
      category,
      this.itemOrder.indexOf(str(i.category)),
    );
  }
}
