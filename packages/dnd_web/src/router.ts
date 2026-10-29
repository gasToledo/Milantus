// Un router de una sola ruta a propósito: la ficha es la única pantalla de
// /v2 y una dependencia para eso sería más peso que código. Cuando haya varias
// pantallas, se cambia por una librería sin tocar quien lo usa.

export type Route =
  | { name: 'character'; id: string }
  | { name: 'unknown' };

/** `/v2/personajes/:id` (con o sin barra final). El prefijo lo pone Vite
 *  (`base`), y es el mismo con el que el servidor monta el build. */
export function matchRoute(pathname: string): Route {
  const base = import.meta.env.BASE_URL; // `/v2/`
  if (!pathname.startsWith(base)) return { name: 'unknown' };
  const parts = pathname.slice(base.length).split('/').filter(Boolean);
  const [section, id, ...rest] = parts;
  if (section === 'personajes' && id && rest.length === 0) {
    try {
      return { name: 'character', id: decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
  return { name: 'unknown' };
}
