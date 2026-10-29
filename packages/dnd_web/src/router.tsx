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

/** Las pestañas de la ficha. Son parte de la URL (`/personajes/:id/combate`):
 *  se comparten, se recargan y «atrás» vuelve a la anterior. El segmento va
 *  en español porque es lo que se lee en la barra de direcciones, y sin tilde
 *  (`campana`) para que no viaje como `%C3%B1`. */
export const SHEET_TABS = ['personaje', 'combate', 'inventario', 'campana', 'diario'] as const;
export type SheetTab = (typeof SHEET_TABS)[number];

/** Las categorías del Códice, con el segmento de su URL (en español y sin
 *  tildes, como las pestañas de la ficha). */
export const CODEX_CATEGORIES = {
  glossary: 'glosario',
  races: 'especies',
  lineages: 'linajes',
  classes: 'clases',
  subclasses: 'subclases',
  backgrounds: 'trasfondos',
  feats: 'dotes',
  spells: 'conjuros',
  magicItems: 'objetos-magicos',
  weapons: 'armas',
  armor: 'armaduras',
  gear: 'equipo',
} as const;
export type CodexCategory = keyof typeof CODEX_CATEGORIES;

export type Route =
  | { name: 'roster' }
  // Sin categoría es la portada; sin entrada, la lista sin nada abierto.
  | { name: 'codex'; category: CodexCategory | null; entryId: string | null }
  // `tab: null` es la ruta sin sufijo, que redirige a la primera pestaña.
  | { name: 'character'; id: string; tab: SheetTab | null }
  | { name: 'unknown' };

/** Adónde mandan los enlaces a lo que todavía vive solo en Flutter (crear,
 *  Códice, Ajustes, el Modo DM…): su raíz, que sirve el cliente de `/`. */
export const FLUTTER_HOME = '/';

/** `/v2/` (la lista) y `/v2/personajes/:id[/pestaña]`, con o sin barra final.
 *  El prefijo lo pone Vite (`base`), y es el mismo con el que el servidor
 *  monta el build. */
export function matchRoute(pathname: string): Route {
  const base = import.meta.env.BASE_URL; // `/v2/`
  // `/v2` sin barra es la misma lista: nadie escribe la barra a mano.
  if (pathname === base.slice(0, -1)) return { name: 'roster' };
  if (!pathname.startsWith(base)) return { name: 'unknown' };
  const parts = pathname.slice(base.length).split('/').filter(Boolean);
  const [section, id, tab, ...rest] = parts;
  if (parts.length === 0) return { name: 'roster' };
  if (section === 'codice' && rest.length === 0) {
    if (id === undefined) return { name: 'codex', category: null, entryId: null };
    const category = (Object.keys(CODEX_CATEGORIES) as CodexCategory[]).find((c) => CODEX_CATEGORIES[c] === id);
    if (!category) return { name: 'unknown' };
    try {
      return { name: 'codex', category, entryId: tab === undefined ? null : decodeURIComponent(tab) };
    } catch {
      return { name: 'unknown' };
    }
  }
  if (section === 'personajes' && id && rest.length === 0) {
    const sheetTab = tab === undefined ? null : SHEET_TABS.find((t) => t === tab);
    if (sheetTab === undefined) return { name: 'unknown' };
    try {
      return { name: 'character', id: decodeURIComponent(id), tab: sheetTab };
    } catch {
      return { name: 'unknown' };
    }
  }
  return { name: 'unknown' };
}

export const rosterHref = (): string => import.meta.env.BASE_URL;

/** La portada del Códice, una categoría o una entrada abierta. */
export const codexHref = (category?: CodexCategory, entryId?: string): string =>
  `${import.meta.env.BASE_URL}codice` +
  (category ? `/${CODEX_CATEGORIES[category]}` : '') +
  (category && entryId ? `/${encodeURIComponent(entryId)}` : '');

export const characterHref = (id: string, tab: SheetTab = 'personaje'): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/${tab}`;

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
