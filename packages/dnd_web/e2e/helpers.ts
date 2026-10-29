import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { APIRequestContext, Page } from '@playwright/test';
import type { Catalog, JsonObject } from '../src/engine';

// Mismos valores que `test/e2e_server.dart` en dnd_server.
export const TOKEN = 'sesion-de-humo=';
export const TOKEN_SIN_V2 = 'sesion-sin-v2=';
export const TOKEN_DM = 'sesion-del-dm=';

/** El SRD tal como lo arma `loadCatalog`, leído del motor: lo esperado se
 *  calcula con el mismo catálogo que ve el navegador. */
export const catalogo = (): Catalog => {
  const dir = fileURLToPath(new URL('../../dnd_engine/lib/assets/srd_2024/', import.meta.url));
  const leer = (n: string) => JSON.parse(readFileSync(dir + `${n}.json`, 'utf8')) as JsonObject[];
  return {
    races: leer('races'),
    classes: leer('classes'),
    subclasses: leer('subclasses'),
    lineages: leer('lineages'),
    backgrounds: leer('backgrounds'),
    feats: leer('feats'),
    weapons: leer('weapons'),
    armor: leer('armor'),
    items: [...leer('items'), ...leer('magic_items'), ...leer('efa_magic_items')],
    spells: leer('spells'),
    creatures: leer('creatures'),
  };
};

export type PersonajeApi = JsonObject & { id: string; name: string; combat: { currentHp: number } };

/** Lo que sirve la API a la cuenta de humo: lo esperado sale de acá y del
 *  motor, no de una transcripción. */
export async function api<T>(request: APIRequestContext, path: string): Promise<T> {
  const res = await request.get(path, { headers: { cookie: `dnd_session=${TOKEN}` } });
  return (await res.json()) as T;
}

export async function personajes(request: APIRequestContext): Promise<PersonajeApi[]> {
  const { characters } = await api<{ characters: { character: PersonajeApi }[] }>(request, '/api/characters');
  return characters.map((c) => c.character);
}

/** Las escrituras que la página le hace a la API (cualquier método que no sea
 *  GET). `/v2` es de solo lectura: la lista tiene que quedar vacía. */
export function vigilarEscrituras(page: Page): string[] {
  const escrituras: string[] = [];
  page.on('request', (r) => {
    const { pathname } = new URL(r.url());
    if (pathname.startsWith('/api/') && r.method() !== 'GET') escrituras.push(`${r.method()} ${pathname}`);
  });
  return escrituras;
}
