// El almacén de imágenes (retratos y, desde 5e8, las imágenes del Diario). Una
// sola clave opaca `<dueño>/<archivo>` por imagen; las lee `ui/portrait.ts`.
import { ApiError } from './client';
import { portraitUrl } from '../ui/portrait';
import { patchSettings } from './settingsSave';

/** Los bytes a base64 **de a pedazos**: `String.fromCharCode(...bytes)` entero
 *  desborda la pila con una imagen de varios megas. 32 KiB por vez es un
 *  múltiplo de 3, así que ningún pedazo agrega relleno `=` en el medio. */
export function toBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000;
  let binary = '';
  for (let i = 0; i < bytes.length; i += CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(binary);
}

/** Guarda como retrato de [characterId] una imagen ya en base64
 *  (`POST /api/characters/<id>/portraits`) y devuelve la clave. Va bajo el dueño
 *  para que borrarlo se lleve la imagen. El servidor valida tipo y tamaño:
 *  rechaza con 400 o 413. */
export async function savePortraitBase64(characterId: string, base64: string): Promise<string> {
  const path = `/api/characters/${encodeURIComponent(characterId)}/portraits`;
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ bytes: base64 }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { key: string }).key;
}

/** Sube [file] como retrato de [characterId] y devuelve la clave. */
export async function uploadPortrait(characterId: string, file: File): Promise<string> {
  return savePortraitBase64(characterId, toBase64(new Uint8Array(await file.arrayBuffer())));
}

/** Un proveedor de generación ya configurado en el servidor: la clave nunca
 *  llega acá, solo su nombre y si acepta una imagen de referencia. */
export interface PortraitProvider {
  id: string;
  name: string;
  supportsReference: boolean;
}

export async function fetchPortraitProviders(signal: AbortSignal): Promise<PortraitProvider[]> {
  const path = '/api/portraits/providers';
  const response = await fetch(path, { signal });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { providers: PortraitProvider[] }).providers;
}

/** Borra una imagen del almacén (`DELETE /api/portraits/<clave>`). Un 404 es
 *  que ya no estaba: cuenta como hecho. */
export async function deletePortrait(key: string): Promise<void> {
  const path = portraitUrl(key);
  const response = await fetch(path, { method: 'DELETE' });
  if (!response.ok && response.status !== 404) throw new ApiError(response.status, path);
}

/** El proveedor falló al generar (502): [message] es el que armó el servidor,
 *  en castellano y comprensible, para mostrarlo tal cual. */
export class PortraitGenerateError extends Error {}

/** Pide candidatos a [providerId] (`POST /api/portraits/generate`) y devuelve
 *  las imágenes en base64. No manda `count`: el servidor elige, como Flutter.
 *  Un `TypeError` de `fetch` es que no hay conexión, y lo resuelve quien llama. */
export async function generatePortraits(args: {
  providerId: string;
  prompt: string;
  referenceBase64?: string;
}): Promise<string[]> {
  const path = '/api/portraits/generate';
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      providerId: args.providerId,
      prompt: args.prompt,
      ...(args.referenceBase64 ? { referenceBase64: args.referenceBase64 } : {}),
    }),
  });
  if (response.status === 502) {
    // `_errorBody` del servidor: `{ error, code }`.
    const body = (await response.json().catch(() => null)) as { error?: string } | null;
    throw new PortraitGenerateError(body?.error ?? path);
  }
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { images: string[] }).images;
}

/** El motor de imágenes que la cuenta dejó como predeterminado
 *  (`AppSettings.imageProvider`), o `null` si nunca guardó ajustes. */
export async function fetchImageProvider(signal: AbortSignal): Promise<string | null> {
  const path = '/api/settings';
  const response = await fetch(path, { signal });
  if (!response.ok) throw new ApiError(response.status, path);
  const { settings } = (await response.json()) as { settings: { imageProvider?: string } | null };
  return settings?.imageProvider ?? null;
}

/** Fija [id] como motor predeterminado. Va por la cola de ajustes: el
 *  documento se guarda entero y la pantalla puede quedar abierta mientras
 *  genera. */
export const setImageProvider = (id: string): Promise<void> => patchSettings({ imageProvider: id });

/** Sube [file] bajo un PNJ **sin** ficha de personaje: el servidor le reserva esta
 *  ruta y a uno con ficha le da 404; ese va por `uploadPortrait` con su ficha. */
export async function uploadNpcPortrait(npcId: string, file: File): Promise<string> {
  return saveNpcPortraitBase64(npcId, toBase64(new Uint8Array(await file.arrayBuffer())));
}

/** Guarda una imagen ya en base64 como retrato de un PNJ sin ficha
 *  (`POST /api/npcs/<id>/portraits`) y devuelve la clave. */
export async function saveNpcPortraitBase64(npcId: string, base64: string): Promise<string> {
  const path = `/api/npcs/${encodeURIComponent(npcId)}/portraits`;
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ bytes: base64 }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { key: string }).key;
}
