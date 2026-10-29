// Orden y filtro de la lista de personajes. Es presentación, no reglas: repite
// el criterio de `_visible` en `dashboard_screen.dart` de Flutter para que la
// misma cuenta vea la misma lista en los dos clientes. Todos los números que
// intervienen (nivel) salen del motor.
import type { CharacterFields, ComputedSheet } from '../engine';
import type { RosterSettings } from '../api/client';

export type SortMode = 'manual' | 'dateAdded' | 'name' | 'level' | 'klass';

const SORT_MODES: readonly SortMode[] = ['manual', 'dateAdded', 'name', 'level', 'klass'];

/** Los nombres son los que Flutter guarda en `AppSettings.sortMode`; uno
 *  desconocido cae a `name`, igual que allá. */
export function parseSortMode(value: string): SortMode {
  return SORT_MODES.find((m) => m === value) ?? 'name';
}

export interface RosterEntry {
  character: CharacterFields;
  /** `null` si el motor no pudo calcularla (p. ej. un esquema más nuevo que el
   *  del cliente): la tarjeta se muestra igual, sin cifras, en vez de tirar
   *  abajo la lista entera. */
  sheet: ComputedSheet | null;
  createdAt: string;
  raceName: string;
  /** Una por clase, en el orden de la ficha. */
  classes: { name: string; level: number }[];
  accent: string | null;
}

/** Sin PG. No es un estado guardado aparte: es lo que dicen los PG, como en
 *  Flutter (`_isFallen`). */
export const isFallen = (e: RosterEntry): boolean => (e.character.combat?.currentHp ?? 0) <= 0;

/** Nombres de clase juntos, para ordenar y buscar. */
const classText = (e: RosterEntry): string => e.classes.map((c) => c.name).join(' ');

// Comparación por unidades de código y no `localeCompare`: es la de Dart
// (`String.compareTo`), y la cuenta tiene que ver el mismo orden en los dos
// clientes aunque «Álvaro» quede después de la «Z».
const cmp = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0);

export function visibleRoster(
  all: readonly RosterEntry[],
  query: string,
  settings: Pick<RosterSettings, 'favoriteCharacterId' | 'characterOrder'>,
  sort: SortMode,
): RosterEntry[] {
  const q = query.trim().toLowerCase();
  const list = all.filter(
    (e) =>
      q === '' ||
      e.character.name.toLowerCase().includes(q) ||
      classText(e).toLowerCase().includes(q) ||
      e.raceName.toLowerCase().includes(q),
  );

  switch (sort) {
    case 'manual': {
      // Lo que no está en el orden guardado (un personaje nuevo) va al final en
      // vez de desaparecer o encabezar por accidente.
      const rank = new Map(settings.characterOrder.map((id, i) => [id, i]));
      const last = rank.size;
      list.sort((a, b) => (rank.get(a.character.id) ?? last) - (rank.get(b.character.id) ?? last));
      break;
    }
    case 'dateAdded':
      list.sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
      break;
    case 'name':
      list.sort((a, b) => cmp(a.character.name.toLowerCase(), b.character.name.toLowerCase()));
      break;
    case 'level':
      list.sort((a, b) => (b.sheet?.level ?? 0) - (a.sheet?.level ?? 0));
      break;
    case 'klass':
      list.sort((a, b) => cmp(classText(a), classText(b)));
      break;
  }

  // Los caídos van al final de cualquier criterio, conservando el orden entre
  // ellos: lo que se está jugando va primero.
  const ordered = [...list.filter((e) => !isFallen(e)), ...list.filter(isFallen)];

  // El favorito encabeza cualquiera sea el criterio: para eso se marca.
  const i = ordered.findIndex((e) => e.character.id === settings.favoriteCharacterId);
  if (i > 0) ordered.unshift(...ordered.splice(i, 1));
  return ordered;
}
