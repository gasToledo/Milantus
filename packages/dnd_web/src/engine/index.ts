import type { Catalog, CharacterJson, ComputedSheet, InventoryLine, JsonObject } from './types';
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
