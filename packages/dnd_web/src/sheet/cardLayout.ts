/** Tres columnas de ids de tarjeta (los `id` de `Card`). */
export type CardLayout = string[][];

/** El orden de fábrica de cada pestaña: el que tenían las columnas fijas. */
export const COMBAT_DEFAULT: CardLayout = [
  ['hit-points', 'defense', 'companions'],
  ['attacks', 'spells'],
  ['saves', 'conditions', 'resources'],
];
export const CHARACTER_DEFAULT: CardLayout = [['identity', 'abilities'], ['skills'], ['proficiencies', 'features']];

const isLayout = (value: unknown): value is CardLayout =>
  Array.isArray(value) && value.length === 3 && value.every((col) => Array.isArray(col) && col.every((id) => typeof id === 'string'));

/**
 * Lo guardado contra lo que hay. [present] son las tarjetas que esa ficha
 * muestra (Compañeros no siempre está). Lo guardado que no es un arreglo de
 * tres arreglos de strings se descarta y vale [defaults]; los ids que ya no
 * están y los repetidos se quitan; y una tarjeta que la preferencia no conoce
 * (una de una versión futura) va al final de su columna de fábrica.
 */
export function resolveLayout(saved: unknown, defaults: CardLayout, present: readonly string[]): CardLayout {
  const here = new Set(present);
  const seen = new Set<string>();
  const layout = (isLayout(saved) ? saved : defaults).map((col) =>
    col.filter((id) => {
      if (!here.has(id) || seen.has(id)) return false;
      seen.add(id);
      return true;
    }),
  );
  defaults.forEach((col, c) => {
    for (const id of col) if (here.has(id) && !seen.has(id)) layout[c]!.push(id);
  });
  return layout;
}

/** Pone [id] en la columna [col], en el lugar [index] de la columna ya sin él
 *  (un índice grande es «al final»). Devuelve un layout nuevo. */
export function moveCard(layout: CardLayout, id: string, col: number, index: number): CardLayout {
  const next = layout.map((c) => c.filter((x) => x !== id));
  next[col]!.splice(Math.max(0, Math.min(index, next[col]!.length)), 0, id);
  return next;
}
