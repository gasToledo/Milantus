import type { BestiaryRow, Catalog, CharacterJson, ComputedSheet, EncounterView, InventoryLine, JsonObject, NpcView } from './types';
// Lo genera `npm run build:engine` (o la etapa `engine-js` del Dockerfile) y
// no se versiona. Es un script de dart2js, no un módulo: al cargarse deja
// `globalThis.dndEngine`, y de ahí lo toma este archivo.
import './dnd_engine.generated.js';

export type * from './types';

interface DartEngine {
  compute(characterJson: string, catalogJson: string): string;
  migrateCharacter(characterJson: string): string;
  setLanguage(code: string): void;
  applyTranslation(packJson: string, overlayJson: string): string;
  vocabularyLabel(field: string, value: string): string;
  inventory(characterJson: string, catalogJson: string): string;
  chapterGrants(chapterJson: string): string;
  catalogLabel(kind: string, id: string): string;
  catalogLabelOrder(kind: string): string;
  formatCost(cp: number, labelsJson: string): string;
  abilityModifier(score: number): number;
  bestiary(catalogJson: string): string;
  npcs(entriesJson: string, catalogJson: string): string;
  encounter(encounterJson: string, playersHpJson: string): string;
  musicSource(url: string): string;
  act(characterJson: string, catalogJson: string, actionJson: string, seed?: number): string;
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
  | 'damageType'
  | 'skill'
  | 'ability'
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
  | { type: 'spendSlot' | 'recoverSlot'; level: number; pact: boolean }
  | { type: 'spendResource' | 'recoverResource'; resource: string; amount?: number }
  | { type: 'spendHitDie' | 'shortRest' | 'longRest' | 'endConcentration' }
  | { type: 'heroicInspiration'; value: boolean }
  | { type: 'concentrate'; spell: string };

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
