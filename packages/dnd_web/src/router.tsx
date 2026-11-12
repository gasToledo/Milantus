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
/** Las pantallas de edición de la ficha de un PNJ: las mismas que las de la
 *  ficha propia, bajo `/dm/pnj/:pnj/ficha/`. */
export type NpcSheetScreen =
  | { name: 'levelUp' }
  | { name: 'spells'; classId: string }
  | { name: 'plans' }
  | { name: 'choices' }
  | { name: 'forms' };

export const MEMBER_SHEET_TABS = ['personaje', 'combate'] as const satisfies readonly SheetTab[];

/** Las de un PNJ con ficha, como `SheetScreen` en `npcMode`: sin campañas «de
 *  jugador» ni Diario, porque su trasfondo y sus notas son de la ficha del PNJ. */
export const NPC_SHEET_TABS = ['personaje', 'combate', 'inventario'] as const satisfies readonly SheetTab[];
/** `undefined` es «no es una pestaña de esa ficha»; `null`, la ruta sin sufijo. */
const sheetTabIn = (tabs: readonly SheetTab[], segment: string | undefined): SheetTab | null | undefined =>
  segment === undefined ? null : tabs.find((t) => t === segment);

export const HOMEBREW_CATEGORIES = ['weapons', 'armor', 'magicItems', 'gear', 'feats', 'races', 'backgrounds', 'spells'] as const satisfies readonly CodexCategory[];
export type HomebrewCategory = (typeof HOMEBREW_CATEGORIES)[number] | 'creatures';
/** Las categorías del Homebrew que ya se editan desde `/v2`. `items` es la
 *  colección que guarda el servidor: en pantalla los objetos se parten en
 *  `magicItems` y `gear` (como en el Códice), pero se crean y se editan en un
 *  solo editor, `/dm/homebrew/objetos/…`, que no tiene lista propia. */
export const EDITABLE_HOMEBREW = ['creatures', 'feats', 'races', 'backgrounds', 'weapons', 'armor', 'items', 'spells'] as const;
export type EditableHomebrew = (typeof EDITABLE_HOMEBREW)[number];
const homebrewSegment = (c: HomebrewCategory | EditableHomebrew): string =>
  c === 'creatures' ? 'criaturas' : c === 'items' ? 'objetos' : CODEX_CATEGORIES[c];

/** Qué muestra el Modo DM. `home` es `/v2/dm` a secas: no muestra nada, redirige
 *  a la primera campaña en curso (o a donde haya algo que ver). */
export type DmView =
  | { kind: 'home' }
  | { kind: 'campaign'; id: string; section: DmSection }
  // La ficha completa de un jugador de la Mesa, por su vínculo (`memberId`) y
  // no por el id del personaje: es la fila de `campaign_members` la que le da
  // al DM el permiso de leerla. `tab: null` redirige a la primera.
  | { kind: 'member'; id: string; memberId: string; tab: SheetTab | null }
  // La ficha completa de un PNJ con ficha de personaje.
  | { kind: 'npcSheet'; npcId: string; tab: SheetTab | null; screen?: NpcSheetScreen }
  // El Bestiario del DM es una herramienta de la cuenta, no de una campaña.
  | { kind: 'bestiary'; entryId: string | null }
  // La Biblioteca de PNJ también: sin PNJ es la lista.
  | { kind: 'npcs'; npcId: string | null }
  // El editor del bloque de un PNJ de bloque.
  | { kind: 'npcBlock'; npcId: string }
  | { kind: 'npcPortrait'; npcId: string }
  // El Homebrew también. Sin categoría es la portada; las criaturas no tienen
  // entrada propia acá: su perfil es el del Bestiario.
  | { kind: 'homebrew'; category: HomebrewCategory | null; entryId: string | null }
  // El editor de una entrada propia (hoy criaturas y dotes): `entryId` es la que
  // se edita, o `null` para una nueva (`?de=<id>` la abre como copia de otra).
  | { kind: 'homebrewEditor'; category: EditableHomebrew; entryId: string | null };

export type Route =
  | { name: 'start' }
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
  // El asistente de subida de nivel de la ficha propia.
  | { name: 'levelUp'; id: string }
  // El editor de conjuros de una clase de la ficha propia.
  | { name: 'spellEdit'; id: string; classId: string }
  // Los planos y réplicas del Artífice de la ficha propia.
  | { name: 'magicPlans'; id: string }
  // Las formas anotadas de Forma Salvaje de la ficha propia.
  | { name: 'wildShapeForms'; id: string }
  // Los retratos de la ficha propia: generar, subir, volver a uno y borrar.
  | { name: 'portrait'; id: string }
  // Las elecciones pendientes o reemplazables de la ficha propia.
  | { name: 'choices'; id: string }
  // El creador de personajes, y el mismo para rehacer uno desde nivel 1.
  | { name: 'creation' }
  // El mismo creador, para la ficha de un PNJ (`?nombre=` y `?campana=`).
  | { name: 'npcCreation' }
  | { name: 'rebuild'; id: string }
  | { name: 'unknown' };

/** Adónde mandan los enlaces a lo que todavía vive solo en Flutter (crear,
 *  Códice, Ajustes, el Modo DM…): su raíz, que sirve el cliente de `/`. */
export const FLUTTER_HOME = '/';

/** `/v2/` (el inicio), `/v2/personajes` (la lista) y sus fichas, con o sin barra final.
 *  El prefijo lo pone Vite (`base`), y es el mismo con el que el servidor
 *  monta el build. */
export function matchRoute(pathname: string): Route {
  const base = import.meta.env.BASE_URL; // `/v2/`
  if (pathname === base.slice(0, -1)) return { name: 'start' };
  if (!pathname.startsWith(base)) return { name: 'unknown' };
  const parts = pathname.slice(base.length).split('/').filter(Boolean);
  const [section, id, tab, ...rest] = parts;
  if (parts.length === 0) return { name: 'start' };
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
    // Antes de todo lo que lee `/dm/pnj/:pnj`: si no, `nuevo` se tomaría por un id.
    if (id === 'pnj' && tab === 'nuevo' && rest.length === 0) return { name: 'npcCreation' };
    // Las pantallas de edición, antes que la pestaña: `subir-nivel` no es una.
    if (id === 'pnj' && tab !== undefined && rest[0] === 'ficha' && rest[1] !== undefined) {
      const screens: Record<string, NpcSheetScreen | undefined> = {
        'subir-nivel': { name: 'levelUp' },
        planos: { name: 'plans' },
        elecciones: { name: 'choices' },
        formas: { name: 'forms' },
      };
      try {
        const screen =
          rest[1] === 'conjuros' && rest.length === 3
            ? ({ name: 'spells', classId: decodeURIComponent(rest[2]!) } as const)
            : rest.length === 2
              ? Object.hasOwn(screens, rest[1]) ? screens[rest[1]] : undefined
              : undefined;
        if (screen) return { name: 'dm', view: { kind: 'npcSheet', npcId: decodeURIComponent(tab), tab: null, screen } };
      } catch {
        return { name: 'unknown' };
      }
    }
    // `/dm/pnj/:pnj/ficha[/:pestaña]`.
    if (id === 'pnj' && tab !== undefined && rest[0] === 'ficha' && rest.length <= 2) {
      const sheetTab = sheetTabIn(NPC_SHEET_TABS, rest[1]);
      if (sheetTab === undefined) return { name: 'unknown' };
      try {
        return { name: 'dm', view: { kind: 'npcSheet', npcId: decodeURIComponent(tab), tab: sheetTab } };
      } catch {
        return { name: 'unknown' };
      }
    }
    // `/dm/pnj/:pnj/bloque`.
    if (id === 'pnj' && tab !== undefined && rest[0] === 'bloque' && rest.length === 1) {
      try {
        return { name: 'dm', view: { kind: 'npcBlock', npcId: decodeURIComponent(tab) } };
      } catch {
        return { name: 'unknown' };
      }
    }
    // `/dm/pnj/:pnj/retrato`.
    if (id === 'pnj' && tab !== undefined && rest[0] === 'retrato' && rest.length === 1) {
      try {
        return { name: 'dm', view: { kind: 'npcPortrait', npcId: decodeURIComponent(tab) } };
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
    // Los editores, antes que la lista: `nueva` no es una criatura ni una dote.
    const editable = id === 'homebrew' ? EDITABLE_HOMEBREW.find((c) => homebrewSegment(c) === tab) : undefined;
    if (editable && rest[0] === 'nueva' && rest.length === 1) {
      return { name: 'dm', view: { kind: 'homebrewEditor', category: editable, entryId: null } };
    }
    if (editable && rest[1] === 'editar' && rest.length === 2) {
      try {
        return { name: 'dm', view: { kind: 'homebrewEditor', category: editable, entryId: decodeURIComponent(rest[0]!) } };
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
  if (section === 'personajes' && id === undefined) return { name: 'roster' };
  if (section === 'personajes' && id === 'nuevo' && tab === undefined) return { name: 'creation' };
  if (section === 'personajes' && id && tab === 'subir-nivel' && rest.length === 0) {
    try {
      return { name: 'levelUp', id: decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
  if (section === 'personajes' && id && tab === 'conjuros' && rest.length === 1) {
    try {
      return { name: 'spellEdit', id: decodeURIComponent(id), classId: decodeURIComponent(rest[0]!) };
    } catch {
      return { name: 'unknown' };
    }
  }
  if (section === 'personajes' && id && tab === 'planos' && rest.length === 0) {
    try {
      return { name: 'magicPlans', id: decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
  if (section === 'personajes' && id && tab === 'elecciones' && rest.length === 0) {
    try {
      return { name: 'choices', id: decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
  if (section === 'personajes' && id && tab === 'formas' && rest.length === 0) {
    try {
      return { name: 'wildShapeForms', id: decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
  if (section === 'personajes' && id && tab === 'rehacer' && rest.length === 0) {
    try {
      return { name: 'rebuild', id: decodeURIComponent(id) };
    } catch {
      return { name: 'unknown' };
    }
  }
  if (section === 'personajes' && id && tab === 'retrato' && rest.length === 0) {
    try {
      return { name: 'portrait', id: decodeURIComponent(id) };
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

export const rosterHref = (): string => `${import.meta.env.BASE_URL}personajes`;

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

/** El creador de personajes para un PNJ con ficha. Los datos viajan en la URL
 *  para que recargar no los pierda (mismo patrón que `?capitulo=`). */
export const dmNpcCreationHref = (name: string, campaignId?: string): string => {
  const params = new URLSearchParams({ nombre: name });
  if (campaignId) params.set('campana', campaignId);
  return `${dmNpcsHref()}/nuevo?${params}`;
};

/** El Homebrew del Modo DM: la portada, una categoría o una entrada abierta. */
export const dmHomebrewHref = (category?: HomebrewCategory, entryId?: string): string =>
  `${import.meta.env.BASE_URL}dm/homebrew` +
  (category ? `/${homebrewSegment(category)}` : '') +
  (category && entryId ? `/${encodeURIComponent(entryId)}` : '');

/** El editor de una entrada propia: la nueva (vacía, o copia de `from`, propia u
 *  oficial) o la que se edita. */
export const dmHomebrewNewHref = (category: EditableHomebrew, from?: string): string =>
  `${import.meta.env.BASE_URL}dm/homebrew/${homebrewSegment(category)}/nueva${from ? `?de=${encodeURIComponent(from)}` : ''}`;
export const dmHomebrewEditHref = (category: EditableHomebrew, id: string): string =>
  `${import.meta.env.BASE_URL}dm/homebrew/${homebrewSegment(category)}/${encodeURIComponent(id)}/editar`;

export const dmCampaignHref =(id: string, section: DmSection = 'mesa'): string =>
  `${import.meta.env.BASE_URL}dm/campanas/${encodeURIComponent(id)}/${section}`;

/** La ficha completa de un miembro de la Mesa, en una de sus pestañas. */
export const dmMemberHref = (campaignId: string, memberId: string, tab: SheetTab = 'personaje'): string =>
  `${dmCampaignHref(campaignId)}/${encodeURIComponent(memberId)}/${tab}`;

/** La ficha completa de un PNJ con ficha, en una de sus pestañas. */
export const dmNpcBlockHref = (npcId: string): string => `${dmNpcsHref(npcId)}/bloque`;
export const dmNpcPortraitHref = (npcId: string): string => `${dmNpcsHref(npcId)}/retrato`;
export const dmNpcSheetHref = (npcId: string, tab: SheetTab = 'personaje'): string =>
  `${dmNpcsHref(npcId)}/ficha/${tab}`;
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

export const creationHref = (): string => `${import.meta.env.BASE_URL}personajes/nuevo`;

export const levelUpHref = (id: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/subir-nivel`;

export const spellEditHref = (id: string, classId: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/conjuros/${encodeURIComponent(classId)}`;

export const magicPlansHref = (id: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/planos`;

/** La pantalla de elecciones de la ficha propia, en la pestaña [tab] (`origin`,
 *  `features`…); sin ella abre en la primera con algo pendiente. */
export const choicesHref = (id: string, tab?: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/elecciones${tab ? `?tab=${tab}` : ''}`;

export const wildShapeFormsHref = (id: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/formas`;

/** A dónde llevan las pantallas de una ficha que se escribe: la propia y la de un
 *  PNJ son las mismas pantallas con otras URL. */
export interface SheetRoutes {
  sheet(tab?: SheetTab): string;
  levelUp(): string;
  spells(classId: string): string;
  plans(): string;
  choices(tab?: string): string;
  forms(): string;
}

export const ownSheetRoutes = (id: string): SheetRoutes => ({
  sheet: (tab) => characterHref(id, tab),
  levelUp: () => levelUpHref(id),
  spells: (classId) => spellEditHref(id, classId),
  plans: () => magicPlansHref(id),
  choices: (tab) => choicesHref(id, tab),
  forms: () => wildShapeFormsHref(id),
});

/** Lo mismo para la ficha de un PNJ. */
export const npcSheetRoutes = (npcId: string): SheetRoutes => {
  const base = `${dmNpcsHref(npcId)}/ficha`;
  return {
    sheet: (tab) => dmNpcSheetHref(npcId, tab),
    levelUp: () => `${base}/subir-nivel`,
    spells: (classId) => `${base}/conjuros/${encodeURIComponent(classId)}`,
    plans: () => `${base}/planos`,
    choices: (tab) => `${base}/elecciones${tab ? `?tab=${tab}` : ''}`,
    forms: () => `${base}/formas`,
  };
};

export const rebuildHref = (id: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/rehacer`;
export const portraitHref = (id: string): string =>
  `${import.meta.env.BASE_URL}personajes/${encodeURIComponent(id)}/retrato`;

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

const getLocation = () => window.location.pathname + window.location.search + window.location.hash;
const pathnameOf = (href: string) => href.split(/[?#]/, 1)[0]!;

type ScreenBack = { href: string; steps: number };
const screenBack = (): ScreenBack | undefined => window.history.state?.milantusBack;

function sheetKey(pathname: string): string | undefined {
  const route = matchRoute(pathname);
  if (route.name === 'character') return `character:${route.id}`;
  if (route.name !== 'dm') return undefined;
  const { view } = route;
  if (view.kind === 'member') return JSON.stringify(['member', view.id, view.memberId]);
  if (view.kind === 'npcSheet' && !view.screen) return `npc:${view.npcId}`;
}

/** Los catálogos de lista y detalle; el editor de homebrew no cuenta. */
function browseKey(pathname: string): string | undefined {
  const route = matchRoute(pathname);
  if (route.name === 'codex' || route.name === 'bestiary') return route.name;
  if (route.name === 'dm' && (route.view.kind === 'bestiary' || route.view.kind === 'homebrew')) return `dm:${route.view.kind}`;
}

/** Navega dentro de `/v2` sin recargar. `replace` para las redirecciones:
 *  «atrás» no tiene que volver a una URL que solo redirige. */
export function navigate(href: string, { replace = false } = {}) {
  const current = getLocation();
  if (href === current) return;
  // Hojear un catálogo (categorías, entradas, anterior/siguiente) no apila
  // historial: «atrás» vuelve a la pantalla que lo abrió y no recorre cada
  // entrada leída.
  const browsing = browseKey(pathnameOf(current));
  if (replace || (browsing !== undefined && browsing === browseKey(pathnameOf(href)))) {
    window.history.replaceState(window.history.state, '', href);
  } else {
    const currentPath = pathnameOf(current);
    const nextPath = pathnameOf(href);
    const sheet = sheetKey(currentPath);
    // Las pestañas quedan en el historial del navegador. El «Atrás» de la
    // ficha salta esas entradas para regresar a la pantalla que la abrió.
    const withinScreen = currentPath === nextPath || (sheet !== undefined && sheet === sheetKey(nextPath));
    const previous = withinScreen ? screenBack() : { href: current, steps: 0 };
    const milantusBack = previous && { ...previous, steps: previous.steps + 1 };
    window.history.pushState({ milantusBack }, '', href);
  }
  window.scrollTo(0, 0);
  notify();
}

/** Una URL abierta directamente conserva el destino habitual de la pantalla. */
export function navigateBack(fallback: string) {
  const back = screenBack();
  if (back) window.history.go(-back.steps);
  else navigate(fallback, { replace: true });
}

/** La ruta actual, y vuelve a dibujar cuando cambia. */
export function useRoute(): { route: Route; pathname: string } {
  const pathname = pathnameOf(useSyncExternalStore(subscribe, getLocation));
  return { route: matchRoute(pathname), pathname };
}

/**
 * Un enlace de verdad (`<a href>`: se puede abrir en otra pestaña, copiar,
 * leer en la barra de estado) que, con un clic simple, navega sin recargar.
 * Los clics con modificador o con otro botón quedan para el navegador.
 */
export function Link({ href, back, onClick, ...rest }: AnchorHTMLAttributes<HTMLAnchorElement> & { href: string; back?: boolean }) {
  const handle = useCallback(
    (e: MouseEvent<HTMLAnchorElement>) => {
      if (!back) onClick?.(e);
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
      if (back) onClick?.(e);
      if (e.defaultPrevented) return;
      e.preventDefault();
      if (back) navigateBack(href);
      else navigate(href);
    },
    [back, href, onClick, rest.target],
  );
  return <a href={(back && screenBack()?.href) || href} onClick={handle} {...rest} />;
}
