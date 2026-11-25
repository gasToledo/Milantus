// Las direcciones del almacén de retratos.
// Todas van al mismo origen y las autoriza la cookie de sesión; la clave es
// opaca (`<dueño>/<archivo>`) y se resuelve siempre: no hay forma barata de
// saber antes si existe, así que un 404 (retrato borrado, cuenta ajena) lo
// resuelve quien dibuja la imagen cayendo a la inicial.

const encodeKey = (key: string) => key.split('/').map(encodeURIComponent).join('/');

/** Un retrato o una imagen del diario de **esta** cuenta: un personaje propio,
 *  un PNJ de la biblioteca o la ficha de un PNJ. El servidor deriva el dueño de
 *  la sesión, así que con la clave de otra cuenta responde 404. */
export const portraitUrl = (key: string): string => `/api/portraits/${encodeKey(key)}`;

/** El retrato de un personaje vinculado a una campaña del DM. Con la clave tal
 *  cual no alcanza (sería de otra cuenta): esta ruta resuelve al dueño real
 *  desde el vínculo, y solo necesita el nombre del archivo. */
export const memberPortraitUrl = (campaignId: string, memberId: string, key: string): string =>
  `/api/campaigns/${encodeURIComponent(campaignId)}/members/${encodeURIComponent(memberId)}/portrait/${encodeURIComponent(
    key.split('/').pop() ?? key,
  )}`;

/** El primer retrato de una ficha (`Character.portraitPaths`), si tiene. */
export const firstPortrait = (character: { portraitPaths?: unknown }): string | null => {
  const paths = character.portraitPaths;
  return Array.isArray(paths) && typeof paths[0] === 'string' ? paths[0] : null;
};

/**
 * Anchos de miniatura que genera el servidor (`portrait_thumbnail.dart`). La
 * escalera está duplicada a propósito: no se puede consultar
 * antes de pintar el primer medallón, y un desajuste no rompe nada —ante un
 * ancho que no conoce, el servidor manda el original—, solo baja de más.
 */
const THUMBNAIL_WIDTHS = [96, 128, 160, 192, 256, 320, 384, 512];

/** La miniatura para un recuadro de [size] px en esta pantalla, o el original
 *  si hace falta más que el peldaño más grande. Pedirla es cosa de quien
 *  dibuja chico: un retrato de 1024 px reducido de un salto a un círculo de
 *  cuarenta se ve dentado. */
export function thumbnailUrl(url: string, size: number): string {
  const needed = Math.ceil(size * (window.devicePixelRatio || 1));
  const width = THUMBNAIL_WIDTHS.find((w) => w >= needed);
  return width === undefined ? url : `${url}?w=${width}`;
}

/** El encuadre circular de un retrato: centro `x`, `y` como fracción del ancho y
 *  del alto de la imagen, y diámetro `s` como fracción de su lado más corto
 *  (`Character.portraitFrames`). */
export type PortraitFrame = readonly [x: number, y: number, s: number];

/** El encuadre guardado de [key], o `null` si no hay o no es de tres números
 *  finitos: el documento viene de afuera y un valor torcido solo centra. */
export function frameOf(character: { portraitFrames?: unknown }, key: string): PortraitFrame | null {
  const frames = character.portraitFrames;
  const raw = frames && typeof frames === 'object' ? (frames as Record<string, unknown>)[key] : undefined;
  return Array.isArray(raw) && raw.length === 3 && raw.every((n) => typeof n === 'number' && Number.isFinite(n))
    ? (raw as unknown as PortraitFrame)
    : null;
}

// ponytail: el encuadre viaja en el fragmento de la dirección (`…#x,y,s`) para que
// los ~20 sitios que le pasan `portrait` string al medallón no cambien. El fragmento
// nunca llega al servidor. Techo: un segundo dato por retrato obliga a pasar a un
// objeto `{ url, frame }`.
/** [url] con su [frame] pegado, listo para el medallón. */
export const withFrame = (url: string, frame: PortraitFrame | null): string => (frame ? `${url}#${frame.join(',')}` : url);

/** Lo inverso de [withFrame]: la dirección sola y su encuadre, si lo trae. */
export function splitFrame(portrait: string): { url: string; frame: PortraitFrame | null } {
  const at = portrait.indexOf('#');
  if (at < 0) return { url: portrait, frame: null };
  const parts = portrait.slice(at + 1).split(',').map(Number);
  const ok = parts.length === 3 && parts.every(Number.isFinite) && parts[2]! > 0;
  return { url: portrait.slice(0, at), frame: ok ? (parts as unknown as PortraitFrame) : null };
}

/** El retrato de un personaje de esta cuenta, listo para el medallón. */
export const ownPortrait = (character: { portraitPaths?: unknown; portraitFrames?: unknown }): string | null => {
  const key = firstPortrait(character);
  return key ? withFrame(portraitUrl(key), frameOf(character, key)) : null;
};

/** El retrato de un miembro de la Mesa, por su vínculo. */
export const memberPortrait = (
  campaignId: string,
  memberId: string,
  character: { portraitPaths?: unknown; portraitFrames?: unknown },
): string | null => {
  const key = firstPortrait(character);
  return key ? withFrame(memberPortraitUrl(campaignId, memberId, key), frameOf(character, key)) : null;
};
