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
export const CATEGORIES = ['weapons', 'armor', 'items', 'feats', 'races', 'backgrounds', 'spells', 'creatures'] as const;
export type Category = (typeof CATEGORIES)[number];

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

/** El fallo de una escritura: un 400 trae el mensaje del servidor (`{ error }`,
 *  el que dejó el motor al validar), que la pantalla muestra tal cual. */
async function writeFailure(response: Response, path: string): Promise<ApiError> {
  let detail: string | undefined;
  if (response.status === 400) {
    try {
      const body = (await response.json()) as { error?: unknown };
      if (typeof body.error === 'string' && body.error !== '') detail = body.error;
    } catch {
      detail = undefined;
    }
  }
  return new ApiError(response.status, path, undefined, detail);
}

async function send(method: 'POST' | 'PUT' | 'DELETE', path: string, body?: unknown): Promise<Response> {
  const response = await fetch(path, {
    method,
    ...(body === undefined ? {} : { headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }),
  });
  if (!response.ok) throw await writeFailure(response, path);
  return response;
}

/** `POST /api/homebrew/import`: el servidor valida el pack entero y lo guarda en
 *  una sola transacción (todo o nada, así que reintentar no duplica). Devuelve
 *  cuántas entradas escribió. */
export async function importHomebrew(content: Record<string, readonly JsonObject[]>): Promise<number> {
  const { importedCount } = (await (await send('POST', '/api/homebrew/import', { content })).json()) as { importedCount: number };
  return importedCount;
}

/** `PUT /api/homebrew/<categoría>/<id>`: el documento entero, con su `id`. */
export async function saveHomebrew(category: Category, entry: JsonObject & { id: string }): Promise<void> {
  await send('PUT', `/api/homebrew/${category}/${encodeURIComponent(entry.id)}`, entry);
}

/** `DELETE /api/homebrew/<categoría>/<id>`. */
export async function deleteHomebrew(category: Category, id: string): Promise<void> {
  await send('DELETE', `/api/homebrew/${category}/${encodeURIComponent(id)}`);
}

/** Baja un texto como archivo (el JSON del homebrew, que arma el motor). */
export function downloadText(fileName: string, text: string, type = 'application/json'): void {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
  // El navegador puede abrir el blob después de despachar el clic.
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}
