import { applyTranslation, type Catalog, type JsonObject } from '../engine';
import type { Lang } from '../i18n/texts';

// Los catálogos que `loadOfficialContent` (dnd_app, asset_content_loader.dart)
// pide, con los mismos nombres de archivo. `items` junta tres.
const PACKS = [
  'races',
  'classes',
  'subclasses',
  'lineages',
  'backgrounds',
  'feats',
  'weapons',
  'armor',
  'items',
  'magic_items',
  'efa_magic_items',
  'spells',
  'creatures',
] as const;

// `npm run build` copia el SRD del motor a `dist/content/` (ver
// `scripts/copy-content.mjs`). El servidor lo sirve con `no-cache`: el
// navegador revalida y recibe un 304 si no cambió.
const BASE = `${import.meta.env.BASE_URL}content`;

async function text(path: string, signal: AbortSignal, optional = false): Promise<string> {
  const response = await fetch(`${BASE}/${path}`, { signal });
  if (response.ok) return response.text();
  // Un catálogo sin superposición se queda en español, que es el respaldo.
  if (optional && response.status === 404) return '{}';
  throw new Error(`${path} respondió ${response.status}`);
}

/**
 * El catálogo del SRD en [lang]. Todos los archivos se piden juntos (no de a
 * uno: cada pedido cruza el túnel). En inglés, la superposición `X.en.json` se
 * aplica con el `applyContentTranslation` del motor y no con una copia acá.
 */
export async function loadCatalog(lang: Lang, signal: AbortSignal): Promise<Catalog> {
  const packs = await Promise.all(
    PACKS.map(async (name): Promise<JsonObject[]> => {
      const [pack, overlay] = await Promise.all([
        text(`${name}.json`, signal),
        lang === 'en' ? text(`${name}.en.json`, signal, true) : Promise.resolve('{}'),
      ]);
      return JSON.parse(lang === 'en' ? applyTranslation(pack, overlay) : pack) as JsonObject[];
    }),
  );
  const by = Object.fromEntries(PACKS.map((name, i) => [name, packs[i] ?? []]));
  const get = (name: (typeof PACKS)[number]) => by[name] ?? [];
  return {
    races: get('races'),
    classes: get('classes'),
    subclasses: get('subclasses'),
    lineages: get('lineages'),
    backgrounds: get('backgrounds'),
    feats: get('feats'),
    weapons: get('weapons'),
    armor: get('armor'),
    items: [...get('items'), ...get('magic_items'), ...get('efa_magic_items')],
    spells: get('spells'),
    creatures: get('creatures'),
  };
}

/** Nombre de una entrada del catálogo (ya en el idioma activo), o su id. */
export function nameOf(list: JsonObject[], id: string | null | undefined): string | null {
  if (!id) return null;
  const entry = list.find((e) => e.id === id);
  return typeof entry?.name === 'string' ? entry.name : id;
}

/** El acento de una clase viene del JSON del catálogo (`accentColor`), no del
 *  código: así el homebrew usa el mismo mecanismo (`diseno-web.md` §3.3). Es un
 *  dato y no un color de diseño. Un valor que no sea `#RRGGBB` se descarta
 *  (como `classAccent` de Flutter) y quien llama cae al oro. */
export function accentOf(catalog: Catalog, classId: string): string | null {
  const hex = catalog.classes.find((c) => c.id === classId)?.accentColor;
  return typeof hex === 'string' && /^#[0-9a-fA-F]{6}$/.test(hex) ? hex : null;
}
