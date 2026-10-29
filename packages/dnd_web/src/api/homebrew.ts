// El contenido homebrew de la cuenta y su fusión con el catálogo oficial. Es el
// mismo camino que Flutter (`HomebrewStore.load` + `ContentRepository.addAll`
// en `dnd_app/lib/main.dart`): sin esto, un personaje que equipa un arma propia
// no tiene ese ataque y su CA, PG o rasgos pueden salir distintos a los de la
// aplicación principal.
import type { Catalog, JsonObject } from '../engine';
import { ApiError } from './client';

/** Las categorías que guarda el servidor (`/api/homebrew`) y que el motor
 *  entiende; son las mismas claves de `Catalog`. Clases, subclases y linajes
 *  no tienen homebrew. */
const CATEGORIES = ['weapons', 'armor', 'items', 'feats', 'races', 'backgrounds', 'spells', 'creatures'] as const;
type Category = (typeof CATEGORIES)[number];

export type HomebrewContent = Partial<Record<Category, JsonObject[]>>;

export async function fetchHomebrew(signal: AbortSignal): Promise<HomebrewContent> {
  const response = await fetch('/api/homebrew', { signal });
  if (!response.ok) throw new ApiError(response.status, '/api/homebrew');
  const { content } = (await response.json()) as { content?: Record<string, unknown> };
  const out: HomebrewContent = {};
  for (const category of CATEGORIES) {
    const list = content?.[category];
    if (Array.isArray(list)) out[category] = list.filter(isValidEntry);
  }
  return out;
}

/** Lo mismo que descarta `HomebrewStore._loadCategory`: sin id, o con un origen
 *  que no sea `homebrew`, la entrada no se carga. Así un documento roto no
 *  pisa una entrada oficial con el mismo id. */
function isValidEntry(e: unknown): e is JsonObject {
  if (typeof e !== 'object' || e === null) return false;
  const { id, source } = e as JsonObject;
  return typeof id === 'string' && id !== '' && source === 'homebrew';
}

/**
 * El catálogo oficial con el homebrew encima: por id, el homebrew gana (es el
 * `Map.addAll` de `ContentRepository.addAll`). No muta [official]: el mismo
 * objeto sigue en la caché para otra cuenta o idioma.
 *
 * ponytail: Flutter además descarta una entrada que su `fromJson` no puede
 * leer; acá solo se filtra id y origen, y una entrada malformada llega al
 * motor, que lanza y la ficha muestra «No se pudo calcular». El servidor
 * valida al guardar, así que no debería pasar; si pasa, el camino es exponer
 * una validación por entrada en `js/entrypoint.dart`.
 */
export function mergeHomebrew(official: Catalog, homebrew: HomebrewContent): Catalog {
  const merged: Catalog = { ...official };
  for (const category of CATEGORIES) {
    const extra = homebrew[category];
    if (!extra || extra.length === 0) continue;
    const byId = new Map(official[category].map((e) => [e.id, e] as const));
    for (const e of extra) byId.set(e.id, e);
    merged[category] = [...byId.values()];
  }
  return merged;
}
