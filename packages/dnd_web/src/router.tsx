import {
  useCallback,
  useSyncExternalStore,
  type AnchorHTMLAttributes,
  type MouseEvent,
} from 'react';

// Un router mínimo a propósito: tres o cuatro rutas y nada de rutas anidadas
// ni cargadores. Lo único que hacía falta respecto del anterior es navegar
// sin recargar (`pushState`), para que la caché de TanStack Query (catálogo,
// personajes) sobreviva al pasar del dashboard a la ficha. Una librería de
// rutas sería más peso que este archivo; si un día hacen falta rutas anidadas
// de verdad, se cambia sin tocar a quien usa `useRoute` y `Link`.

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

// `pushState` no dispara ningún evento: se avisa a mano a quien escucha.
const listeners = new Set<() => void>();
const notify = () => listeners.forEach((l) => l());

function subscribe(listener: () => void) {
  listeners.add(listener);
  window.addEventListener('popstate', listener);
  return () => {
    listeners.delete(listener);
    window.removeEventListener('popstate', listener);
  };
}

const getPath = () => window.location.pathname;

/** Navega dentro de `/v2` sin recargar. `replace` para las redirecciones:
 *  «atrás» no tiene que volver a una URL que solo redirige. */
export function navigate(href: string, { replace = false } = {}) {
  if (href === window.location.pathname) return;
  if (replace) window.history.replaceState(null, '', href);
  else window.history.pushState(null, '', href);
  window.scrollTo(0, 0);
  notify();
}

/** La ruta actual, y vuelve a dibujar cuando cambia. */
export function useRoute(): { route: Route; pathname: string } {
  const pathname = useSyncExternalStore(subscribe, getPath);
  return { route: matchRoute(pathname), pathname };
}

/**
 * Un enlace de verdad (`<a href>`: se puede abrir en otra pestaña, copiar,
 * leer en la barra de estado) que, con un clic simple, navega sin recargar.
 * Los clics con modificador o con otro botón quedan para el navegador.
 */
export function Link({ href, onClick, ...rest }: AnchorHTMLAttributes<HTMLAnchorElement> & { href: string }) {
  const handle = useCallback(
    (e: MouseEvent<HTMLAnchorElement>) => {
      onClick?.(e);
      if (
        e.defaultPrevented ||
        e.button !== 0 ||
        e.metaKey ||
        e.ctrlKey ||
        e.shiftKey ||
        e.altKey ||
        rest.target === '_blank'
      ) {
        return;
      }
      e.preventDefault();
      navigate(href);
    },
    [href, onClick, rest.target],
  );
  return <a href={href} onClick={handle} {...rest} />;
}
