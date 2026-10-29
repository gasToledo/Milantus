// Un router mínimo a propósito: hay dos pantallas (la lista y la ficha) y los
// enlaces son enlaces reales (carga completa de la página), así que una
// dependencia para eso sería más peso que código. Cuando haya navegación
// interna de verdad, se cambia por una librería sin tocar quien lo usa.

export type Route =
  | { name: 'roster' }
  | { name: 'character'; id: string }
  | { name: 'unknown' };

/** Adónde mandan los enlaces a lo que todavía vive solo en Flutter (crear,
 *  Códice, Ajustes, el Modo DM…): su raíz, que sirve el cliente de `/`. */
export const FLUTTER_HOME = '/';

/** `/v2/` (la lista) y `/v2/personajes/:id`, con o sin barra final. El prefijo
 *  lo pone Vite (`base`), y es el mismo con el que el servidor monta el build. */
export function matchRoute(pathname: string): Route {
  const base = import.meta.env.BASE_URL; // `/v2/`
  // `/v2` sin barra es la misma lista: nadie escribe la barra a mano.
  if (pathname === base.slice(0, -1)) return { name: 'roster' };
  if (!pathname.startsWith(base)) return { name: 'unknown' };
  const parts = pathname.slice(base.length).split('/').filter(Boolean);
  const [section, id, ...rest] = parts;
  if (parts.length === 0) return { name: 'roster' };
  if (section === 'personajes' && id && rest.length === 0) {
    try {
      return { name: 'character', id: decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
  return { name: 'unknown' };
}

export const rosterHref = (): string => import.meta.env.BASE_URL;

export const characterHref = (id: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}`;
