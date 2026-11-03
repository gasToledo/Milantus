// El almacén de imágenes (retratos y, desde 5e8, las imágenes del Diario). Una
// sola clave opaca `<dueño>/<archivo>` por imagen; las lee `ui/portrait.ts`.
import { ApiError } from './client';
import { portraitUrl } from '../ui/portrait';

/** Los bytes a base64 **de a pedazos**: `String.fromCharCode(...bytes)` entero
 *  desborda la pila con una imagen de varios megas. 32 KiB por vez es un
 *  múltiplo de 3, así que ningún pedazo agrega relleno `=` en el medio. */
function toBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000;
  let binary = '';
  for (let i = 0; i < bytes.length; i += CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(binary);
}

/** Sube [file] bajo el id del dueño (`POST /api/characters/<id>/portraits`) y
 *  devuelve la clave. Va bajo el dueño para que borrarlo se lleve la imagen. El
 *  servidor valida tipo y tamaño: rechaza con 400 o 413. */
export async function uploadPortrait(characterId: string, file: File): Promise<string> {
  const path = `/api/characters/${encodeURIComponent(characterId)}/portraits`;
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ bytes: toBase64(new Uint8Array(await file.arrayBuffer())) }),
  });
  if (!response.ok) throw new ApiError(response.status, path);
  return ((await response.json()) as { key: string }).key;
}

/** Borra una imagen del almacén (`DELETE /api/portraits/<clave>`). Un 404 es
 *  que ya no estaba: cuenta como hecho. */
export async function deletePortrait(key: string): Promise<void> {
  const path = portraitUrl(key);
  const response = await fetch(path, { method: 'DELETE' });
  if (!response.ok && response.status !== 404) throw new ApiError(response.status, path);
}
