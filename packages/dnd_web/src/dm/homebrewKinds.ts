import type { Category } from '../api/homebrew';
import type { HomebrewCategory } from '../router';

/** La categoría que guarda el servidor para una del Homebrew de pantalla: los
 *  objetos se parten en mágicos y equipo en el Códice, pero son una sola
 *  colección (`items`). */
export const storageOf = (c: HomebrewCategory): Category => (c === 'magicItems' || c === 'gear' ? 'items' : c);
