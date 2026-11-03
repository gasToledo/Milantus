import type { AbilityId, BestiaryRow, Catalog, CharacterJson, CompanionsView, ComputedSheet, EncounterView, InventoryLine, JsonObject, MagicPlansView, NpcView } from './types';
// Lo genera `npm run build:engine` (o la etapa `engine-js` del Dockerfile) y
// no se versiona. Es un script de dart2js, no un módulo: al cargarse deja
// `globalThis.dndEngine`, y de ahí lo toma este archivo.
import './dnd_engine.generated.js';

export type * from './types';

interface DartEngine {
  compute(characterJson: string, catalogJson: string): string;
  choicesView(characterJson: string, catalogJson: string): string;
  migrateCharacter(characterJson: string): string;
  portraitPrompt(characterJson: string, catalogJson: string, style: string, extraText: string, includeWeapon: boolean): string;
  portraitStyles(): string;
  setLanguage(code: string): void;
  applyTranslation(packJson: string, overlayJson: string): string;
  vocabularyLabel(field: string, value: string): string;
  inventory(characterJson: string, catalogJson: string): string;
  chapterGrants(chapterJson: string): string;
  canLevelUp(characterJson: string): boolean;
  catalogLabel(kind: string, id: string): string;
  catalogLabelOrder(kind: string): string;
  formatCost(cp: number, labelsJson: string): string;
  trade(requestJson: string, labelsJson: string): string;
  levelUp(characterJson: string, catalogJson: string, draftJson: string): string;
  creation(catalogJson: string, draftJson: string, actionJson: string, seed?: number): string;
  creationConfirm(catalogJson: string, draftJson: string, unnamed: string, replacingJson?: string): string;
  demoCharacter(): string;
  rollDie(sides: number): number;
  coinParts(cp: number): string;
  formatAmount(cp: number, labelsJson: string): string;
  abilityModifier(score: number): number;
  bestiary(catalogJson: string): string;
  npcs(entriesJson: string, catalogJson: string): string;
  encounter(encounterJson: string, playersHpJson: string): string;
  musicSource(url: string): string;
  act(characterJson: string, catalogJson: string, actionJson: string, seed?: number): string;
  spellEdit(characterJson: string, catalogJson: string, classId: string): string;
  innateCantripOptions(characterJson: string, catalogJson: string, granted: string): string;
  magicItemPlans(characterJson: string, catalogJson: string): string;
  magicBaseOptions(catalogJson: string, itemId: string): string;
  companionsView(characterJson: string, catalogJson: string): string;
  companionPreview(characterJson: string, catalogJson: string, option: string, creature: string, level: number): string;
}

function engine(): DartEngine {
  const e = (globalThis as { dndEngine?: DartEngine }).dndEngine;
  if (!e) throw new Error('El motor (dart2js) no se inicializó.');
  return e;
}

// El motor guarda el último catálogo que vio y lo reconoce por su texto; si
// cada llamada volviera a serializar el objeto, armar ese texto costaría más
// que calcular la ficha. Se serializa una vez por objeto de catálogo.
const catalogJsonCache = new WeakMap<Catalog, string>();

function catalogJson(catalog: Catalog): string {
  let json = catalogJsonCache.get(catalog);
  if (json === undefined) {
    json = JSON.stringify(catalog);
    catalogJsonCache.set(catalog, json);
  }
  return json;
}

/**
 * Calcula la ficha con el mismo motor que el servidor y Flutter, compilado a
 * JS: ninguna regla se reimplementa en TypeScript. Migra la ficha si viene de
 * un esquema viejo; una versión futura lanza en vez de calcular a medias.
 */
export function computeSheet(
  character: CharacterJson,
  catalog: Catalog,
): ComputedSheet {
  return JSON.parse(
    engine().compute(JSON.stringify(character), catalogJson(catalog)),
  ) as ComputedSheet;
}

/** Un aviso del motor (`CharacterValidator`). `info` es algo por elegir, no
 *  una ficha rota. */
export interface SheetWarning {
  code: string;
  message: string;
  severity: 'info' | 'warning';
}

export interface ChoiceGroup {
  groupId: string;
  name: string;
  count: number;
  replaceable: boolean;
  chosen: string[];
  pending: number;
}

/** Lo que la ficha propia deja elegir o revisar (`choicesView` del motor). */
export interface ChoicesView {
  warnings: SheetWarning[];
  /** Hay algún cupo completo que se puede cambiar. */
  replaceable: boolean;
  features: (ChoiceGroup & {
    options: { id: string; name: string; description: string; homebrew: boolean; unmet: string | null }[];
  })[];
  proficiencies: (ChoiceGroup & {
    expertise: boolean;
    options: { id: string; label: string; locked: boolean }[];
  })[];
  spells: (ChoiceGroup & {
    grantsSpells: boolean;
    options: { id: string; name: string; level: number }[];
  })[];
  languages: {
    originCount: number;
    origin: { id: string; label: string }[];
    chosenOrigin: string[];
    universal: { id: string; label: string };
    slots: (Omit<ChoiceGroup, 'replaceable'> & { options: { id: string; label: string }[] })[];
  };
  origin: {
    sizes: { id: string; label: string }[];
    size: string | null;
    lineages: { id: string; name: string; description: string }[];
    lineage: string | null;
    speciesAbilityPending: boolean;
    speciesAbilityOptions: { id: AbilityId; label: string }[];
    speciesAbility: AbilityId | null;
    featAbilities: { feat: string; name: string; options: { id: AbilityId; label: string }[]; chosen: AbilityId | null }[];
  };
}

/** Las advertencias y los cupos de elección de la ficha, del motor. */
export function choicesView(character: CharacterJson, catalog: Catalog): ChoicesView {
  return JSON.parse(
    engine().choicesView(JSON.stringify(character), catalogJson(catalog)),
  ) as ChoicesView;
}

/** El prompt de retrato que arma el motor (siempre en inglés). */
export function portraitPrompt(
  character: CharacterJson,
  catalog: Catalog,
  style: string,
  extraText: string,
  includeWeapon: boolean,
): string {
  return engine().portraitPrompt(JSON.stringify(character), catalogJson(catalog), style, extraText, includeWeapon);
}

/** Los ids de los estilos predeterminados (lo que se guarda en los ajustes). */
export function portraitStyles(): string[] {
  return JSON.parse(engine().portraitStyles()) as string[];
}

/** Lleva una ficha al esquema actual sin modificar la de entrada. */
export function migrateCharacter(character: CharacterJson): CharacterJson {
  return JSON.parse(
    engine().migrateCharacter(JSON.stringify(character)),
  ) as CharacterJson;
}

/**
 * Idioma de los rótulos que el motor arma al calcular («Mediano»). Es estado
 * global del motor, igual que en Flutter: se fija **antes** de `computeSheet`.
 */
export function setEngineLanguage(code: 'es' | 'en'): void {
  engine().setLanguage(code);
}

/** Superpone una traducción (`X.en.json`) a un catálogo (`X.json`), como
 *  texto JSON: es el `applyContentTranslation` de Dart, no una copia. */
export function applyTranslation(packJson: string, overlayJson: string): string {
  return engine().applyTranslation(packJson, overlayJson);
}

/** Campos del catálogo con vocabulario cerrado, guardados en español. */
export type VocabularyField = 'school' | 'castingTime' | 'duration' | 'range' | 'size' | 'creatureType';

/** [value] en el idioma fijado con `setEngineLanguage`: la escuela o el
 *  alcance de un conjuro, el tamaño de una especie. Es el `vocabularyLabel`
 *  del motor (con sus patrones), no una tabla acá; un valor que no conoce
 *  (homebrew con texto propio) vuelve tal cual. */
export function vocabularyLabel(field: VocabularyField, value: string): string {
  return engine().vocabularyLabel(field, value);
}

/**
 * La mochila con cada entrada resuelta por el motor (`InventoryOps`): nombre,
 * peso por unidad, si cuenta como equipada, si es mágica, sus cargas. Así
 * ninguna de esas decisiones se repite en TypeScript.
 */
export function inventoryOf(character: CharacterJson, catalog: Catalog): InventoryLine[] {
  return JSON.parse(
    engine().inventory(JSON.stringify(character), catalogJson(catalog)),
  ) as InventoryLine[];
}

/** Lo que repartió un capítulo, en una línea y en el idioma del motor, o
 *  vacío (`Chapter.grantsLabel`). */
export function chapterGrants(chapter: JsonObject): string {
  return engine().chapterGrants(JSON.stringify(chapter));
}

/** Si el personaje todavía puede subir de nivel (`Character.canLevelUp`): el
 *  tope de nivel es una regla del motor. */
export function canLevelUp(character: CharacterJson): boolean {
  return engine().canLevelUp(JSON.stringify(character));
}

/** Tablas de rótulos del motor que el cliente lee por id. */
export type CatalogLabelKind =
  | 'rarity'
  | 'featCategory'
  | 'itemCategory'
  | 'armorTraining'
  | 'weaponProficiency'
  | 'tool'
  | 'weaponProperty'
  | 'weaponPropertyRule'
  | 'mastery'
  | 'masteryRule'
  | 'damageType'
  | 'skill'
  | 'ability'
  | 'abilityRule'
  | 'language';

/** El nombre visible de un id del catálogo (una rareza, una propiedad de
 *  arma, una competencia…) en el idioma del motor; un id desconocido vuelve
 *  tal cual. Son las tablas del motor, no copias en TypeScript. */
export function catalogLabel(kind: CatalogLabelKind, id: string): string {
  return engine().catalogLabel(kind, id);
}

/** El orden de las claves de una tabla de rótulos, el de los filtros. */
export function catalogLabelOrder(kind: 'rarity' | 'featCategory' | 'itemCategory'): string[] {
  return JSON.parse(engine().catalogLabelOrder(kind)) as string[];
}

/** Un precio en cobre con la denominación que lo expresa sin fracción
 *  (`formatCost` del motor) y las abreviaturas del idioma de la interfaz. */
export function formatCost(cp: number, labels: Record<string, string>): string {
  return engine().formatCost(cp, JSON.stringify(labels));
}

/** Lo que se escribe en el diálogo de comprar o vender. */
export interface TradeRequest {
  coins: Record<string, number>;
  /** Precio por unidad en po, pp y pc, como se escribió. */
  price: Record<string, number>;
  quantity: number;
  buying: boolean;
}

/** La cuenta del diálogo (`trade` del motor): montos en cobre y ya escritos. */
export interface TradePreview {
  unitCp: number;
  totalCp: number;
  total: string;
  purseCp: number;
  purse: string;
  /** Cuánto falta, si al comprar no alcanza; `null` si alcanza. */
  short: string | null;
  spent: string;
  change: string;
  after: string;
  afterCoins: string;
}

/** La cuenta de comprar o vender con las funciones del motor que después
 *  aplican `buy` y `sell` (`CoinOps.plan`, `receive`). */
export function tradePreview(request: TradeRequest, labels: Record<string, string>): TradePreview {
  return JSON.parse(engine().trade(JSON.stringify(request), JSON.stringify(labels))) as TradePreview;
}

/** Las decisiones de una subida de nivel (`LevelUpDraft` del motor). */
export interface LevelUpDraft {
  classId: string;
  subclassId?: string | null;
  /** Lo que salió en el dado; sin él, el promedio. */
  hpRoll?: number | null;
  asiFeat?: boolean;
  asiPlusTwo?: boolean;
  abilityA?: AbilityId | null;
  abilityB?: AbilityId | null;
  featId?: string | null;
  /** Lo elegido en esta subida para cada cupo, por su `groupId`. */
  featurePicks?: Record<string, string[]>;
  proficiencyPicks?: Record<string, string[]>;
  spellPicks?: Record<string, string[]>;
  /** Los trucos y conjuros de la clase que sube, enteros. */
  classCantripPicks?: string[] | null;
  classSpellPicks?: string[] | null;
}

export interface AbilityChoice {
  amount: number;
  max: number;
  allowed: AbilityId[];
}

/** Lo que el motor resuelve de una subida en curso (`levelUp` de
 *  `js/entrypoint.dart`). `unmet` es el requisito que falta, o `null`. */
export interface LevelUpView {
  newLevel: number;
  newClassLevel: number;
  hitDie: number;
  averageHp: number;
  hpGain: number;
  hpIfAverage: number;
  hpIfRoll: number | null;
  hpRange: [number, number];
  isAsi: boolean;
  needsSubclass: boolean;
  asiComplete: boolean;
  complete: boolean;
  unmetMulticlass: string | null;
  classOptions: { id: string; name: string; hitDie: number; unmet: string | null }[];
  subclassOptions: { id: string; name: string; description: string; homebrew: boolean }[];
  featOptions: {
    id: string;
    name: string;
    category: string;
    description: string;
    homebrew: boolean;
    unmet: string | null;
    abilityChoice: AbilityChoice | null;
  }[];
  featAbilityChoice: AbilityChoice | null;
  gainedFeatures: { name: string; description: string }[];
  featureSlots: {
    groupId: string;
    name: string;
    count: number;
    replaceable: boolean;
    chosen: string[];
    original: string[];
    options: {
      id: string;
      name: string;
      repeatable: boolean;
      description: string;
      homebrew: boolean;
      unmet: string | null;
    }[];
  }[];
  proficiencySlots: {
    groupId: string;
    name: string;
    count: number;
    expertise: boolean;
    chosen: string[];
    options: { id: string; label: string; locked: boolean }[];
  }[];
  spellSlots: {
    groupId: string;
    name: string;
    count: number;
    replaceable: boolean;
    grantsSpells: boolean;
    chosen: string[];
    options: CreationSpellRow[];
  }[];
  classSpells: {
    cantripsKnown: number;
    preparedCount: number;
    prepared: boolean;
    cantrips: { id: string; name: string }[];
    spells: CreationSpellRow[];
    chosenCantrips: string[];
    chosenSpells: string[];
    grantedCantrips: string[];
    grantedSpells: string[];
  } | null;
  /** Lo que la subida obliga a elegir y todavía se elige en Flutter. */
  open: { features: number; proficiencies: number; spellChoices: number; classSpells: number };
  /** El personaje como quedaría, para comparar las dos fichas. */
  character: CharacterJson;
}

/** Una subida de nivel en curso, resuelta por el motor (`LevelUp`). */
export function levelUpView(character: CharacterJson, catalog: Catalog, draft: LevelUpDraft): LevelUpView {
  return JSON.parse(
    engine().levelUp(JSON.stringify(character), catalogJson(catalog), JSON.stringify(draft)),
  ) as LevelUpView;
}

/** Lo que el editor de conjuros de la ficha lee del motor (`spellEdit`): la
 *  forma de `LevelUpView.classSpells`. */
export type SpellEditView = NonNullable<LevelUpView['classSpells']>;

/** Los trucos y conjuros de la clase [classId] de la ficha (`LevelUp.classSpells`),
 *  o `null` si esa clase no lanza conjuros. */
export function spellEditView(character: CharacterJson, catalog: Catalog, classId: string): SpellEditView | null {
  return JSON.parse(engine().spellEdit(JSON.stringify(character), catalogJson(catalog), classId)) as SpellEditView | null;
}

/** Los planos del Artífice con sus opciones y réplicas, o `null` si la ficha
 *  no tiene cupo de planos. */
export function magicPlansView(character: CharacterJson, catalog: Catalog): MagicPlansView | null {
  return JSON.parse(engine().magicItemPlans(JSON.stringify(character), catalogJson(catalog))) as MagicPlansView | null;
}

/** Los compañeros de la ficha: lo que puede invocar, lo que tiene en juego y
 *  lo que quedó sin sostén (`companionsView` del motor). */
export function companionsView(character: CharacterJson, catalog: Catalog): CompanionsView {
  return JSON.parse(engine().companionsView(JSON.stringify(character), catalogJson(catalog))) as CompanionsView;
}

/** El perfil y la fila de una forma invocada con un espacio de [level], o
 *  `null` si no existe (`companionPreview` del motor). */
export function companionPreview(
  character: CharacterJson,
  catalog: Catalog,
  option: string,
  creature: string,
  level: number,
): { profile: JsonObject; row: BestiaryRow } | null {
  return JSON.parse(
    engine().companionPreview(JSON.stringify(character), catalogJson(catalog), option, creature, level),
  ) as { profile: JsonObject; row: BestiaryRow } | null;
}

/** Los objetos base entre los que se elige para replicar [itemId]. */
export function magicBaseOptions(catalog: Catalog, itemId: string): { id: string; name: string }[] {
  return JSON.parse(engine().magicBaseOptions(catalogJson(catalog), itemId));
}

/** Los trucos entre los que se puede cambiar el innato [granted]; vacío si no
 *  es reemplazable. El del rasgo va primero. */
export function innateCantripOptions(
  character: CharacterJson,
  catalog: Catalog,
  granted: string,
): { id: string; name: string; school: string }[] {
  return JSON.parse(engine().innateCantripOptions(JSON.stringify(character), catalogJson(catalog), granted));
}

/** Una tirada de un dado de [sides] caras, hecha por el motor. */
/** Las secciones del borrador (`CreationSection` de Dart). */
export type CreationSectionId =
  | 'species'
  | 'characterClass'
  | 'background'
  | 'scores'
  | 'proficiencies'
  | 'spells'
  | 'equipment';

/** Lo que falta (`CreationPendingKind` de Dart). */
export type CreationPendingKind =
  | 'pickSpecies'
  | 'pickLineage'
  | 'pickLineageAbility'
  | 'pickSize'
  | 'pickClass'
  | 'featureChoice'
  | 'weaponMastery'
  | 'pickBackground'
  | 'pickFeatAbility'
  | 'spread'
  | 'assignScores'
  | 'classSkills'
  | 'speciesSkills'
  | 'originFeat'
  | 'proficiencies'
  | 'expertise'
  | 'languages'
  | 'languageChoices'
  | 'spellChoices'
  | 'cantrips'
  | 'spells'
  | 'classEquipment'
  | 'backgroundEquipment'
  | 'equipmentChoices'
  | 'overspent';

/** Una elección sin resolver: qué y cuánto. El texto lo pone el cliente. */
export interface CreationPending {
  kind: CreationPendingKind;
  section: CreationSectionId;
  have: number;
  need: number;
  name: string;
}

export type ScoreMethodId = 'standardArray' | 'roll4d6' | 'pointBuy' | 'manual';
export type SpreadModeId = 'twoOne' | 'oneOneOne';

/** El borrador (`CreationDraft.toJson`), con lo que las pantallas leen. Se
 *  devuelve tal cual al motor: React no le cambia nada. */
export interface CreationDraftJson {
  raceId?: string | null;
  lineageId?: string | null;
  speciesSpellcastingAbility?: AbilityId | null;
  chosenSize?: string | null;
  classId?: string | null;
  weaponMasteries?: string[];
  backgroundId?: string | null;
  originFeatSpellcastingAbility?: AbilityId | null;
  spreadMode?: SpreadModeId;
  spreadPlusTwo?: AbilityId | null;
  spreadPlusOne?: AbilityId | null;
  scoreMethod?: ScoreMethodId;
  assignedScores?: Partial<Record<AbilityId, number>>;
  classSkills?: string[];
  raceSkills?: string[];
  raceFeatId?: string | null;
  languages?: string[];
  classEquipmentOptionId?: string | null;
  backgroundEquipmentOptionId?: string | null;
  name?: string;
  alignment?: string | null;
  personalityTrait?: string;
  [key: string]: unknown;
}

/** Lo que el motor resuelve del borrador (`CreationDraft.viewJson`). */
export interface CreationView {
  draft: CreationDraftJson;
  pending: CreationPending[];
  character: CharacterJson;
  species: {
    lineages: { id: string; name: string; description: string; homebrew: boolean }[];
    sizes: string[];
    needsLineageAbility: boolean;
    abilityOptions: AbilityId[];
  };
  class: {
    featureSlots: {
      groupId: string;
      name: string;
      count: number;
      chosen: string[];
      options: { id: string; name: string; description: string }[];
    }[];
    features: { name: string; description: string }[];
    weaponMasterySlots: number;
    weapons: { id: string; name: string; mastery: string | null }[];
  };
  background: {
    abilityOptions: AbilityId[];
    featAbilityOptions: AbilityId[];
    spread: Partial<Record<AbilityId, number>>;
  };
  scores: {
    suggested: Partial<Record<AbilityId, number>>;
    standardArray: number[];
    /** Un dado por columna, con quién lo tiene. */
    columns: { value: number; holder: AbilityId | null }[];
    manualRange: [number, number];
    pointBudget: number;
    pointsRemaining: number;
    canRaise: AbilityId[];
    canLower: AbilityId[];
    preview: Partial<Record<AbilityId, number>>;
    descriptions: Record<AbilityId, string>;
  };
  details: { alignments: { id: string; label: string }[] };
  proficiencies: {
    backgroundSkills: string[];
    backgroundTools: string[];
    classSkills: CreationSkillBlock;
    speciesSkills: CreationSkillBlock;
    grantsOriginFeat: boolean;
    originFeats: { id: string; name: string }[];
    slots: {
      groupId: string;
      name: string;
      count: number;
      expertise: boolean;
      chosen: string[];
      options: { id: string; label: string; taken: boolean }[];
    }[];
    languages: { universal: string; count: number; options: { id: string; label: string }[] };
    languageSlots: {
      groupId: string;
      name: string;
      count: number;
      chosen: string[];
      options: { id: string; label: string }[];
    }[];
  };
  spells: {
    applicable: boolean;
    slots: {
      groupId: string;
      name: string;
      count: number;
      chosen: string[];
      options: CreationSpellRow[];
    }[];
    class: {
      prepared: boolean;
      cantripsKnown: number;
      preparedCount: number;
      cantrips: CreationSpellRow[];
      spells: CreationSpellRow[];
      chosenCantrips: string[];
      chosenSpells: string[];
      grantedCantrips: string[];
      grantedSpells: string[];
    } | null;
  };
  equipment: {
    classOptions: CreationPackage[];
    backgroundOptions: CreationPackage[];
    choices: { key: string; fromClass: boolean; chosen: string | null; options: { id: string; name: string }[] }[];
    grantedCp: number;
    purchasesCp: number;
    goldLeftCp: number;
    purchases: { id: string; name: string; quantity: number; unitCp: number; bundleSize: number }[];
    armor: { id: string; name: string; worn: boolean }[];
    weapons: { id: string; name: string; wielded: boolean }[];
    grips: { id: string; name: string; canOffHand: boolean; offHand: boolean; canTwoHanded: boolean; twoHanded: boolean }[];
  };
}

/** Un conjuro para elegir. */
export interface CreationSpellRow {
  id: string;
  name: string;
  level: number;
  school: string;
}

/** Un cupo de habilidades: lo que suma cada una sin y con competencia. */
export interface CreationSkillBlock {
  count: number;
  options: {
    id: string;
    label: string;
    ability: AbilityId | null;
    base: number;
    withProficiency: number;
    taken: boolean;
  }[];
}

/** Una opción de equipo inicial, con lo que trae. */
export interface CreationPackage {
  id: string;
  label: string;
  items: { name: string; quantity: number }[];
  choices: string[][];
  coins: Record<string, number>;
}

/** Lo que el jugador tocó (`CreationDraft.apply`). */
export type CreationAction =
  | { type: 'selectRace' | 'selectLineage' | 'selectClass' | 'selectBackground' | 'setSize'; id: string }
  | { type: 'setSpeciesAbility' | 'setOriginFeatAbility'; ability: AbilityId }
  | { type: 'setSpreadMode'; mode: SpreadModeId }
  | { type: 'setSpread'; plusTwo: AbilityId | null; plusOne: AbilityId | null }
  | { type: 'applyScoreMethod'; method: ScoreMethodId }
  | { type: 'applySuggestedScores' | 'clearScores' }
  | { type: 'assignScore'; ability: AbilityId; value: number }
  | { type: 'unassignScore'; ability: AbilityId }
  | { type: 'stepPointBuy'; ability: AbilityId; delta: number }
  | { type: 'setManualScore'; ability: AbilityId; value: number | null }
  | {
      type: 'toggle';
      pick:
        | 'classSkill'
        | 'speciesSkill'
        | 'weaponMastery'
        | 'feature'
        | 'proficiency'
        | 'language'
        | 'featureLanguage'
        | 'featureSpell'
        | 'cantrip'
        | 'spell';
      id: string;
      group?: string;
    }
  | { type: 'toggleRaceFeat' | 'setClassEquipment' | 'setBackgroundEquipment' | 'buy'; id: string }
  | { type: 'setEquipmentChoice'; key: string; id: string }
  | { type: 'setPurchase'; id: string; quantity: number }
  | { type: 'setName'; name: string }
  | { type: 'setAlignment'; alignment: string | null }
  | { type: 'setTrait'; text: string }
  | { type: 'setArmorWorn' | 'setWeaponWielded' | 'setOffHand' | 'setTwoHanded'; id: string; on: boolean };

/** El creador: aplica [action] al borrador y devuelve el borrador nuevo y lo
 *  que muestran los pasos. Sin acción, solo lee. */
export function creationView(catalog: Catalog, draft: CreationDraftJson, action?: CreationAction): CreationView {
  return JSON.parse(
    engine().creation(catalogJson(catalog), JSON.stringify(draft), action ? JSON.stringify(action) : ''),
  ) as CreationView;
}

/** El personaje listo para guardar. Lanza si el borrador está incompleto: la
 *  pantalla no lo ofrece, pero la regla es del motor. */
export function creationConfirm(
  catalog: Catalog,
  draft: CreationDraftJson,
  unnamed: string,
  replacing?: CharacterJson,
): CharacterJson & { id: string } {
  return JSON.parse(
    engine().creationConfirm(catalogJson(catalog), JSON.stringify(draft), unnamed, replacing ? JSON.stringify(replacing) : ''),
  ) as CharacterJson & { id: string };
}

/** El personaje de ejemplo de la cuenta vacía (`demoSagan` del motor). */
export function demoCharacter(): CharacterJson & { id: string } {
  return JSON.parse(engine().demoCharacter()) as CharacterJson & { id: string };
}

export function rollDie(sides: number): number {
  return engine().rollDie(sides);
}

/** [cp] partido en oro, plata y cobre (`CoinOps.changeFor`). */
export function coinParts(cp: number): Record<string, number> {
  return JSON.parse(engine().coinParts(cp)) as Record<string, number>;
}

/** Un monto en cobre para leer («7 po 5 pp», `CoinOps.formatAmount`). */
export function formatAmount(cp: number, labels: Record<string, string>): string {
  return engine().formatAmount(cp, JSON.stringify(labels));
}

/** El modificador de una puntuación de característica (`abilityModifier`). */
export function abilityModifier(score: number): number {
  return engine().abilityModifier(score);
}

/** Las criaturas del catálogo listas para el Bestiario, en orden alfabético y
 *  sin las invocaciones por fórmula (`bestiary` del motor). */
export function bestiary(catalog: Catalog): BestiaryRow[] {
  return JSON.parse(engine().bestiary(catalogJson(catalog))) as BestiaryRow[];
}

/** Lo que trae la API por cada PNJ: `GET /api/npcs` (sin estado) o
 *  `GET /api/campaigns/:id/npcs` (con el estado y los PG en esa campaña). */
export interface NpcEntryJson {
  npc: JsonObject;
  character?: CharacterJson;
  status?: string;
  currentHp?: number;
}

/** Cada PNJ migrado y con sus números de combate, en el mismo orden (`npcs`
 *  del motor): los PG de un bloque, la ficha compilada, si viene herido. */
export function npcViews(entries: readonly NpcEntryJson[], catalog: Catalog): NpcView[] {
  return JSON.parse(engine().npcs(JSON.stringify(entries), catalogJson(catalog))) as NpcView[];
}

/** El combate abierto, migrado y con lo que deriva el motor (`encounter`): de
 *  quién es el turno, cuántos quedan en pie y, por fila, si está caído o
 *  maltrecho y sus PG. Los de un jugador entran en [playersHp] (`memberId` →
 *  actuales de su ficha y máximo de `computeSheet`): el encuentro no los lleva. */
export function encounterView(
  encounter: JsonObject,
  playersHp: Record<string, { current: number; max: number }>,
): EncounterView {
  return JSON.parse(engine().encounter(JSON.stringify(encounter), JSON.stringify(playersHp))) as EncounterView;
}

/** Un enlace de YouTube reconocido por el motor (`MusicSource`). */
export interface MusicSource {
  kind: 'video' | 'playlist';
  id: string;
  /** El reproductor embebido, por `youtube-nocookie.com` y con `enablejsapi=1`. */
  embedUrl: string;
  /** La página de YouTube, armada con el id y no con lo que pegó el DM. */
  pageUrl: string;
}

/** El enlace de una escena de música, o `null` si no es uno de YouTube que el
 *  motor reconozca (`MusicSource.parse`): una escena de Spotify guardada antes
 *  de sacarlo queda sin reproducir. */
export function musicSource(url: string): MusicSource | null {
  return JSON.parse(engine().musicSource(url)) as MusicSource | null;
}

/** Una acción de partida sobre la ficha propia (`SheetActions` del motor). */
export type SheetAction =
  | { type: 'damage' | 'heal' | 'tempHp'; amount: number }
  | { type: 'deathSave'; success: boolean }
  | { type: 'rename'; name: string }
  | { type: 'spendSlot' | 'recoverSlot'; level: number; pact: boolean }
  | { type: 'spendResource' | 'recoverResource'; resource: string; amount?: number }
  | { type: 'spendHitDie' | 'shortRest' | 'longRest' | 'endConcentration' }
  | { type: 'heroicInspiration'; value: boolean }
  | { type: 'setCondition'; condition: string; value: boolean }
  | { type: 'setExhaustion'; value: number }
  | { type: 'activateMode'; mode: string; variant?: string; variants?: string[] }
  | { type: 'deactivateMode'; mode: string }
  | { type: 'concentrate'; spell: string }
  | { type: 'equip' | 'attune'; entry: string; value: boolean }
  | { type: 'setQuantity' | 'setCharges'; entry: string; value: number }
  | { type: 'note'; entry: string; text: string }
  | { type: 'offHand' | 'twoHanded' | 'removeItem'; entry: string }
  | { type: 'setCoins'; coins: Record<string, number> }
  | { type: 'addItem'; item: string; base?: string }
  | { type: 'setItemBase'; entry: string; base: string }
  | { type: 'buy'; item: string; quantity: number; unitPriceCp: number; at: string; base?: string }
  | { type: 'sell'; entry: string; quantity: number; unitPriceCp: number; at: string }
  | { type: 'levelUp'; draft: LevelUpDraft }
  | { type: 'setClassSpells'; classId: string; cantrips: string[]; spells: string[] }
  | { type: 'setInnateCantrip'; granted: string; spell: string }
  | { type: 'setEffectTarget'; group: string; entry: string }
  | { type: 'createEffectTarget'; group: string; weapon: string }
  | { type: 'clearEffectTargets'; group: string }
  | { type: 'setMagicItemPlan'; item: string; value: boolean }
  | { type: 'replicateItem'; item: string; base?: string }
  | { type: 'transmuteReplica'; entry: string; item: string; base?: string }
  | { type: 'enterWildShape'; creature: string }
  | { type: 'leaveWildShape' }
  | { type: 'setWildShapeForm'; creature: string; value: boolean }
  | { type: 'setFeatureChoice' | 'setProficiencyChoice' | 'setSpellChoice'; group: string; id: string; value: boolean }
  /** `group` null es la elección del origen. */
  | { type: 'setLanguage'; group: string | null; id: string; value: boolean }
  | { type: 'setSize'; size: string }
  | { type: 'setLineage'; lineage: string }
  | { type: 'setSpeciesAbility'; ability: AbilityId }
  | { type: 'setFeatAbility'; feat: string; ability: AbilityId }
  | { type: 'setUnarmoredDefense'; classId: string }
  | { type: 'setBackground'; text: string }
  | {
      type: 'saveDiaryEntry';
      entry: string;
      kind: 'text' | 'image' | 'link';
      title: string;
      body: string;
      imageKey: string | null;
      at: string;
    }
  | { type: 'removeDiaryEntry'; entry: string }
  | { type: 'moveDiaryEntry'; entry: string; to: string }
  | { type: 'addPortrait'; key: string; prompt?: string }
  | { type: 'restorePortrait' | 'removePortrait'; key: string }
  | { type: 'summonCompanion'; option: string; creature: string; level?: number; pact?: boolean; free?: boolean }
  | { type: 'damageCompanion' | 'healCompanion' | 'companionTempHp'; index: number; amount: number }
  | { type: 'dismissCompanion'; index: number }
  | { type: 'setCompanionCondition'; index: number; condition: string; value: boolean };

/** Lo que cuenta el motor de una acción, para el aviso. Cada campo existe
 *  solo en la acción que lo da (ver `SheetActions.apply`). */
export interface SheetOutcome {
  deathSave?: 'stable' | 'dead' | null;
  healed?: number;
  restored?: string[];
  exhaustion?: number | null;
  inspirationGained?: boolean;
  itemsRecharged?: number;
  dismissed?: string[];
  paid?: boolean;
  added?: boolean;
  died?: boolean;
  activated?: boolean;
  removedReplica?: boolean;
  created?: boolean;
  /** `enterWildShape`: false si la forma no está anotada o no quedan usos. */
  entered?: boolean;
  /** `enterWildShape`: los PG temporales que dio. */
  tempHp?: number;
  /** `summonCompanion`: false si se rechazó (sin espacio, uso o forma). */
  summoned?: boolean;
  /** Compañeros: la forma invocada, dañada o despedida. */
  name?: string;
  /** `summonCompanion`: el nivel de espacio gastado, o `null`. */
  spentSlot?: number | null;
  /** `summonCompanion`: el recurso gratis que se gastó, o `null`. */
  freeName?: string | null;
  concentrates?: boolean;
  /** `summonCompanion`: cortó una concentración anterior. */
  brokeConcentration?: boolean;
  /** `damageCompanion`: el daño lo destruyó. */
  destroyed?: boolean;
}

/**
 * Aplica [action] a la ficha con el motor y devuelve la ficha nueva —migrada,
 * con el `schemaVersion` actual, lista para guardar tal cual— y lo que pasó.
 * Las tiradas (el dado de golpe, la recarga al amanecer) las hace el motor. No
 * modifica la de entrada; una acción desconocida o una ficha de una versión
 * futura lanzan.
 */
export function actOn(
  character: CharacterJson,
  catalog: Catalog,
  action: SheetAction,
): { character: CharacterJson; outcome: SheetOutcome } {
  return JSON.parse(
    engine().act(JSON.stringify(character), catalogJson(catalog), JSON.stringify(action)),
  ) as { character: CharacterJson; outcome: SheetOutcome };
}
