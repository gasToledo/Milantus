// El almacén de imágenes (retratos y, desde 5e8, las imágenes del Diario). Una
// sola clave opaca `<dueño>/<archivo>` por imagen; las lee `ui/portrait.ts`.
import { ApiError } from './client';
import { portraitUrl } from '../ui/portrait';

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

/** Fija [id] como motor predeterminado. Relee los ajustes antes de guardarlos
 *  en vez de usar los que trajo la pantalla: el documento se guarda **entero**
 *  y la pantalla puede quedar abierta un buen rato mientras genera. Con una
 *  copia vieja, fijar el motor pisaría el favorito, el orden o el tema que se
 *  hubieran tocado mientras tanto.
 *
 *  ponytail: es el primer guardado de ajustes de `/v2` y solo sabe de
 *  `imageProvider`; el paso 7 trae el guardado general de ajustes. */
export async function setImageProvider(id: string): Promise<void> {
  const path = '/api/settings';
  const read = await fetch(path);
  if (!read.ok) throw new ApiError(read.status, path);
  const { settings } = (await read.json()) as { settings: Record<string, unknown> | null };
  const response = await fetch(path, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ...settings, imageProvider: id }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
}
