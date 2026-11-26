import { accentOf } from '../api/catalog';
import type { Catalog } from '../engine';
import type { SheetModel } from './model';

/** La paleta cerrada de adornos, en el orden del panel. Cada clave es la
 *  variable `--orn-<clave>` de `index.css`, y es lo que guarda el personaje. */
export const ORNAMENT_COLORS = ['crimson', 'sky', 'violet', 'teal', 'green', 'silver', 'ember'] as const;
export type OrnamentColor = (typeof ORNAMENT_COLORS)[number];

/** [key] si es de la paleta: una clave que esta versión no conoce vale como
 *  «el color de la clase». */
export const ornamentColor = (key: string | null | undefined) => ORNAMENT_COLORS.find((c) => c === key) ?? null;

export const classAccent = (catalog: Catalog, classId: string) => accentOf(catalog, classId) ?? 'var(--gold)';

export interface SheetCorner {
  classId: string;
  accent: string;
}

/**
 * Qué clase y qué color lleva cada esquina de las placas, con lo que eligió el
 * dueño (`character.sheetStyle`) sobre lo de fábrica: arriba la clase de mayor
 * nivel (en un empate, `character.classId` y después el orden de `classLevels`)
 * y abajo la segunda, o la misma si no hay otra. [auto] es lo de fábrica, que
 * el panel ofrece como «Automático».
 */
export function resolveSheetStyle({ character, sheet, catalog }: SheetModel) {
  const style = character.sheetStyle;
  // `sort` es estable: en un empate queda el orden de entrada.
  const order = (character.classId ? Object.keys(sheet.classLevels) : []).sort(
    (a, b) =>
      sheet.classLevels[b]! - sheet.classLevels[a]! || Number(b === character.classId) - Number(a === character.classId),
  );
  const auto = { tl: order[0], br: order[1] ?? order[0] };
  const corner = (key: 'tl' | 'br'): SheetCorner | null => {
    const chosen = style?.[key]?.classId;
    // Una clase guardada que el personaje ya no tiene cae a automático.
    const classId = chosen && order.includes(chosen) ? chosen : auto[key];
    if (!classId) return null;
    const color = ornamentColor(style?.[key]?.color);
    return { classId, accent: color ? `var(--orn-${color})` : classAccent(catalog, classId) };
  };
  return { on: style?.ornaments ?? true, tl: corner('tl'), br: corner('br'), auto };
}
