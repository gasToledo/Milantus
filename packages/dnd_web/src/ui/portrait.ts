// Las direcciones del almacén de retratos (`portrait_image.dart` de Flutter).
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
 * escalera está duplicada a propósito, como en Flutter: no se puede consultar
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

/** El retrato de un personaje de esta cuenta, listo para el medallón. */
export const ownPortrait = (character: { portraitPaths?: unknown }): string | null => {
  const key = firstPortrait(character);
  return key ? portraitUrl(key) : null;
};

/** El retrato de un miembro de la Mesa, por su vínculo. */
export const memberPortrait = (campaignId: string, memberId: string, character: { portraitPaths?: unknown }): string | null => {
  const key = firstPortrait(character);
  return key ? memberPortraitUrl(campaignId, memberId, key) : null;
};
