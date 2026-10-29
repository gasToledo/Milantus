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
  guides: 'guias',
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

/** Las secciones de una campaña en el Modo DM. Mismo criterio de segmentos que
 *  las pestañas de la ficha: en español y sin tildes. */
export const DM_SECTIONS = ['mesa', 'capitulos', 'cuaderno', 'pnj', 'combate'] as const;
export type DmSection = (typeof DM_SECTIONS)[number];

/** Las categorías del Códice que pueden tener homebrew, en el orden del
 *  Homebrew de Flutter (los objetos se parten en mágicos y equipo, como en el
 *  Códice). Las criaturas no son del Códice: van aparte (`creatures`). */
/** Las pestañas de la ficha de un miembro de la Mesa: lo que sirve en combate,
 *  como `MemberSheetScreen` de Flutter. Inventario, campañas y diario son del
 *  jugador. */
export const MEMBER_SHEET_TABS = ['personaje', 'combate'] as const satisfies readonly SheetTab[];
/** `undefined` es «no es una pestaña de esa ficha»; `null`, la ruta sin sufijo. */
const sheetTabIn = (tabs: readonly SheetTab[], segment: string | undefined): SheetTab | null | undefined =>
  segment === undefined ? null : tabs.find((t) => t === segment);

export const HOMEBREW_CATEGORIES = ['weapons', 'armor', 'magicItems', 'gear', 'feats', 'races', 'backgrounds', 'spells'] as const satisfies readonly CodexCategory[];
export type HomebrewCategory = (typeof HOMEBREW_CATEGORIES)[number] | 'creatures';
const homebrewSegment = (c: HomebrewCategory): string => (c === 'creatures' ? 'criaturas' : CODEX_CATEGORIES[c]);

/** Qué muestra el Modo DM. `home` es `/v2/dm` a secas: no muestra nada, redirige
 *  a la primera campaña en curso (o a donde haya algo que ver). */
export type DmView =
  | { kind: 'home' }
  | { kind: 'campaign'; id: string; section: DmSection }
  // La ficha completa de un jugador de la Mesa, por su vínculo (`memberId`) y
  // no por el id del personaje: es la fila de `campaign_members` la que le da
  // al DM el permiso de leerla. `tab: null` redirige a la primera.
  | { kind: 'member'; id: string; memberId: string; tab: SheetTab | null }
  // El Bestiario del DM es una herramienta de la cuenta, no de una campaña.
  | { kind: 'bestiary'; entryId: string | null }
  // La Biblioteca de PNJ también: sin PNJ es la lista.
  | { kind: 'npcs'; npcId: string | null }
  // El Homebrew también. Sin categoría es la portada; las criaturas no tienen
  // entrada propia acá: su perfil es el del Bestiario.
  | { kind: 'homebrew'; category: HomebrewCategory | null; entryId: string | null };

export type Route =
  | { name: 'roster' }
  | { name: 'dm'; view: DmView }
  | { name: 'settings' }
  | { name: 'campaigns' }
  // Sin criatura es la lista con nada abierto.
  | { name: 'bestiary'; entryId: string | null }
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
  if (section === 'dm') {
    // `/dm` y `/dm/campanas/:id/:seccion`; lo demás es «no encontrada».
    if (id === undefined) return { name: 'dm', view: { kind: 'home' } };
    if (id === 'bestiario' && rest.length === 0) {
      try {
        return { name: 'dm', view: { kind: 'bestiary', entryId: tab === undefined ? null : decodeURIComponent(tab) } };
      } catch {
        return { name: 'unknown' };
      }
    }
    if (id === 'pnj' && rest.length === 0) {
      try {
        return { name: 'dm', view: { kind: 'npcs', npcId: tab === undefined ? null : decodeURIComponent(tab) } };
      } catch {
        return { name: 'unknown' };
      }
    }
    if (id === 'homebrew' && rest.length <= 1) {
      if (tab === undefined) return { name: 'dm', view: { kind: 'homebrew', category: null, entryId: null } };
      const category = (['creatures', ...HOMEBREW_CATEGORIES] as const).find((c) => homebrewSegment(c) === tab);
      if (!category || (category === 'creatures' && rest.length > 0)) return { name: 'unknown' };
      try {
        return { name: 'dm', view: { kind: 'homebrew', category, entryId: rest[0] === undefined ? null : decodeURIComponent(rest[0]) } };
      } catch {
        return { name: 'unknown' };
      }
    }
    // `/dm/campanas/:id/mesa/:miembro[/:pestaña]`.
    if (id === 'campanas' && tab !== undefined && rest[0] === 'mesa' && rest[1] !== undefined && rest.length <= 3) {
      const sheetTab = sheetTabIn(MEMBER_SHEET_TABS, rest[2]);
      if (sheetTab === undefined) return { name: 'unknown' };
      try {
        return {
          name: 'dm',
          view: { kind: 'member', id: decodeURIComponent(tab), memberId: decodeURIComponent(rest[1]), tab: sheetTab },
        };
      } catch {
        return { name: 'unknown' };
      }
    }
    const dmSection = rest.length === 1 ? DM_SECTIONS.find((s) => s === rest[0]) : undefined;
    if (id === 'campanas' && tab !== undefined && dmSection !== undefined) {
      try {
        return { name: 'dm', view: { kind: 'campaign', id: decodeURIComponent(tab), section: dmSection } };
      } catch {
        return { name: 'unknown' };
      }
    }
    return { name: 'unknown' };
  }
  if (section === 'ajustes' && id === undefined) return { name: 'settings' };
  if (section === 'campanas' && id === undefined) return { name: 'campaigns' };
  if (section === 'bestiario' && tab === undefined) {
    try {
      return { name: 'bestiary', entryId: id === undefined ? null : decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
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

/** El Bestiario, o una criatura abierta. */
export const bestiaryHref = (entryId?: string): string =>
  `${import.meta.env.BASE_URL}bestiario` + (entryId ? `/${encodeURIComponent(entryId)}` : '');

export const campaignsHref = (): string => `${import.meta.env.BASE_URL}campanas`;

/** El Modo DM: sin campaña es `/v2/dm`, que redirige a la primera. */
export const dmHref = (): string => `${import.meta.env.BASE_URL}dm`;

/** El Bestiario del Modo DM, o una criatura abierta. */
export const dmBestiaryHref = (entryId?: string): string =>
  `${import.meta.env.BASE_URL}dm/bestiario` + (entryId ? `/${encodeURIComponent(entryId)}` : '');

/** La Biblioteca de PNJ del Modo DM, o la ficha de un PNJ. */
export const dmNpcsHref = (npcId?: string): string =>
  `${import.meta.env.BASE_URL}dm/pnj` + (npcId ? `/${encodeURIComponent(npcId)}` : '');

/** El Homebrew del Modo DM: la portada, una categoría o una entrada abierta. */
export const dmHomebrewHref = (category?: HomebrewCategory, entryId?: string): string =>
  `${import.meta.env.BASE_URL}dm/homebrew` +
  (category ? `/${homebrewSegment(category)}` : '') +
  (category && entryId ? `/${encodeURIComponent(entryId)}` : '');

export const dmCampaignHref =(id: string, section: DmSection = 'mesa'): string =>
  `${import.meta.env.BASE_URL}dm/campanas/${encodeURIComponent(id)}/${section}`;

/** La ficha completa de un miembro de la Mesa, en una de sus pestañas. */
export const dmMemberHref = (campaignId: string, memberId: string, tab: SheetTab = 'personaje'): string =>
  `${dmCampaignHref(campaignId)}/${encodeURIComponent(memberId)}/${tab}`;
/**
 * Los ajustes son de la cuenta y los comparten los dos modos. `desdeDm` deja
 * dicho de cuál se vino (`?modo=dm`) para que el panel y el «atrás» sigan en
 * el Modo DM en vez de caer en el de Jugador.
 */
export const settingsHref = (desdeDm = false): string =>
  `${import.meta.env.BASE_URL}ajustes${desdeDm ? '?modo=dm' : ''}`;

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
