import type { Catalog, CharacterFields, ComputedSheet } from '../engine';
import { accentOf, nameOf } from '../api/catalog';
import type { SheetWriter } from './writer';

/** Lo que toda pieza de la ficha recibe: el personaje (ya migrado), la ficha
 *  que calculó el motor y el catálogo con el que se calculó (oficial +
 *  homebrew), para los nombres. [write] solo existe en la ficha propia: sin
 *  él, ningún componente muestra un control que escriba. */
export interface SheetModel {
  character: CharacterFields;
  sheet: ComputedSheet;
  catalog: Catalog;
  write?: SheetWriter;
}

/** Cada clase con su nivel y su subclase, en el orden de la ficha (el orden
 *  en que se subió de nivel, `classLevels`). */
export function classesOf({ character, sheet, catalog }: SheetModel) {
  return Object.entries(sheet.classLevels).map(([id, level]) => {
    const subclassId =
      character.subclassIds?.[id] ?? (id === character.classId ? character.subclassId : null);
    return {
      id,
      level,
      name: nameOf(catalog.classes, id) ?? id,
      subclass: nameOf(catalog.subclasses, subclassId),
    };
  });
}

export const accentFor = ({ character, catalog }: SheetModel) => accentOf(catalog, character.classId);

/** Usos de [r] que quedan: el máximo es del motor; lo gastado, de la mesa.
 *  La clave es la de `CharacterResource.key`, con la que se guarda el uso. */
export function resourceLeft(
  { character }: SheetModel,
  r: { classId?: string; id: string; max: number },
): number {
  const key = r.classId ? `${r.classId}:${r.id}` : r.id;
  return Math.max(0, r.max - (character.combat?.resourceUsage?.[key] ?? 0));
}
