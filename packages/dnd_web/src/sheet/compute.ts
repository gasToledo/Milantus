import { computeSheet, migrateCharacter, type Catalog, type CharacterFields, type CharacterJson } from '../engine';
import type { SheetModel } from './model';

export type ComputedModel = { ok: true; model: SheetModel } | { ok: false; detail: string };

/**
 * La ficha lista para mostrar: migrada y calculada por el motor. La comparten
 * la ficha propia, la de un miembro de la Mesa y la de un PNJ con ficha, que
 * leen documentos distintos (`/api/characters`, los miembros, `/api/npcs/:id`)
 * pero los muestran igual.
 */
export function computeModel(raw: CharacterJson, catalog: Catalog): ComputedModel {
  try {
    // Se migra una vez y se usa lo migrado para todo: el motor calcula sobre
    // la forma actual y la pantalla lee los mismos campos (el PG actual, los
    // espacios gastados) sin conocer esquemas viejos.
    const migrated = migrateCharacter(raw);
    // El motor de Dart compilado a JS, el mismo que usan el servidor y
    // Flutter: acá no se recalcula ninguna regla.
    const sheet = computeSheet(migrated, catalog);
    // `CharacterFields` es el subconjunto que la pantalla lee de un
    // `Character.toJson` que el servidor ya validó al guardarlo.
    return { ok: true, model: { character: migrated as unknown as CharacterFields, sheet, catalog } };
  } catch (e) {
    // Un esquema más nuevo que este cliente, o una ficha que el motor no
    // entiende: se dice, en vez de mostrar números a medias.
    return { ok: false, detail: String(e) };
  }
}
