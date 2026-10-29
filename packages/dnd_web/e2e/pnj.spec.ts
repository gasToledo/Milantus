import { expect, test } from '@playwright/test';
import { computeSheet, npcViews, type NpcEntryJson } from '../src/engine';
import { npcTypeLine } from '../src/dm/npcs/npc';
import { textsFor } from '../src/i18n/texts';
import { signed } from '../src/sheet/format';
import { api, catalogo, TOKEN, TOKEN_DM, vigilarEscrituras } from './helpers';

test.use({ locale: 'es-AR' });

const t = textsFor('es');
const BIBLIOTECA = '/v2/dm/pnj';

// Lo que el DM escribió de sus PNJ (ver `_seedNpcs` en `e2e_server.dart`) y
// no tiene que llegarle a ninguna otra cuenta.
const SOLO_DEL_DM = ['Voz reservada del DM', 'Trasfondo reservado del DM', 'Nota reservada del PNJ', 'Vesna la Cuervo'];

type Guardado = NpcEntryJson & { npc: { id: string; name: string }; campaigns: { campaignName: string; status: string }[] };

test('la Biblioteca de PNJ lista los de la cuenta con lo que da el motor, filtra y no escribe', async ({ context, page, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const { npcs } = await api<{ npcs: Guardado[] }>(page.request, '/api/npcs', TOKEN_DM);
  expect(npcs.map((n) => n.npc.id).sort()).toEqual(['garrick', 'odile', 'vesna']);
  const vistas = npcViews(npcs, catalogo());

  await page.goto('/v2/dm');
  await page.getByRole('navigation', { name: 'Herramientas del DM' }).getByRole('link', { name: 'Biblioteca de PNJ' }).click();
  await expect(page).toHaveURL(BIBLIOTECA);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Biblioteca de PNJ');
  await expect(page.getByText(t.dmLibraryCount(3))).toBeVisible();

  // Cada tarjeta dice lo que es con los números del motor: el bloque de
  // Garrick nombra su criatura de base por el catálogo, y la ficha de Vesna
  // la especie y la clase de su ficha.
  for (const vista of vistas) {
    const tarjeta = page.locator(`[data-npc="${vista.npc.id}"]`);
    await expect(tarjeta.locator('[data-field="type"]')).toHaveText(npcTypeLine(vista, t));
  }
  await expect(page.locator('[data-npc="garrick"] [data-field="type"]')).toContainText('Bandido');
  await expect(page.locator('[data-npc="odile"] [data-field="campaigns"]')).toHaveText(t.dmNoCampaignYet);

  // El filtro principal es por campaña, con sus conteos; los tags afinan.
  const campanas = page.getByRole('group', { name: 'Campaña' });
  await campanas.getByRole('button', { name: /La Marca del Cuervo/ }).click();
  await expect(page.locator('[data-npc]')).toHaveCount(2);
  await campanas.getByRole('button', { name: /Sin campaña/ }).click();
  await expect(page.locator('[data-npc]')).toHaveCount(1);
  await expect(page.locator('[data-npc="odile"]')).toBeVisible();
  await campanas.getByRole('button', { name: /Todas/ }).click();
  await page.getByRole('group', { name: 'Tags' }).getByRole('button', { name: /Enemigos/ }).click();
  await expect(page.locator('[data-npc]')).toHaveCount(1);
  await expect(page.locator('[data-npc="vesna"]')).toBeVisible();

  // Sin coincidencias, el vacío es «nada coincide» y limpia todo junto.
  await page.getByRole('searchbox', { name: 'Buscar por nombre' }).fill('garrick');
  await expect(page.getByText(t.dmNoNpcMatches)).toBeVisible();
  await page.getByRole('button', { name: 'Limpiar filtros' }).click();
  await expect(page.locator('[data-npc]')).toHaveCount(3);
  // La búsqueda ignora tildes y mayúsculas.
  await page.getByRole('searchbox', { name: 'Buscar por nombre' }).fill('ODÍLE');
  await expect(page.locator('[data-npc]')).toHaveCount(1);

  expect(escrituras).toEqual([]);
});

test('la ficha de un PNJ muestra su voz, trasfondo, notas, cómo pelea y su estado en cada campaña', async ({ context, page, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const catalog = catalogo();
  const garrick = await api<Guardado>(page.request, '/api/npcs/garrick', TOKEN_DM);
  const [vista] = npcViews([garrick], catalog);

  await page.goto(BIBLIOTECA);
  await page.locator('[data-npc="garrick"]').getByRole('link').click();
  await expect(page).toHaveURL(`${BIBLIOTECA}/garrick`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Garrick el Tabernero');
  await expect(page.locator('[data-field="type"]')).toHaveText(npcTypeLine(vista!, t));
  await expect(page.locator('[data-field="speech"]')).toContainText('Voz reservada del DM');
  // El trasfondo se lee con el Markdown chico de la mesa.
  await expect(page.locator('strong', { hasText: 'sirvió en la guardia' })).toBeVisible();
  await expect(page.locator('[data-entry="deuda"]')).toContainText('Le debe al gremio');
  // El bloque: las cifras del bloque copiado, no las del catálogo.
  const stats = page.locator('[data-card="stats"]');
  await expect(stats.locator('[data-stat="ac"] [data-field="value"]')).toHaveText(vista!.block!.ac);
  await expect(stats.locator('[data-stat="hp"] [data-field="value"]')).toHaveText(vista!.block!.hp);
  await expect(stats.locator('[data-stat="cr"] [data-field="value"]')).toHaveText(vista!.block!.crText!);
  await expect(stats).toContainText(t.npcBasedOn(vista!.baseName!));
  // El estado es por campaña, con la palabra además del color.
  await expect(page.locator('[data-campaign="marca-del-cuervo"] [data-status]')).toHaveText('Vivo');

  // Un PNJ con ficha muestra los cuatro números de la ficha compilada.
  const vesna = await api<Guardado>(page.request, '/api/npcs/vesna', TOKEN_DM);
  const ficha = computeSheet(vesna.character!, catalog);
  await page.goto(`${BIBLIOTECA}/vesna`);
  const hoja = page.locator('[data-card="stats"]');
  await expect(hoja.locator('[data-stat="ac"] [data-field="value"]')).toHaveText(String(ficha.armorClass));
  await expect(hoja.locator('[data-stat="hp"] [data-field="value"]')).toHaveText(String(ficha.maxHp));
  await expect(hoja.locator('[data-stat="initiative"] [data-field="value"]')).toHaveText(signed(ficha.initiative));
  await expect(hoja.locator('[data-stat="passive"] [data-field="value"]')).toHaveText(String(ficha.passivePerception));
  await expect(page.locator('[data-campaign="marca-del-cuervo"] [data-status]')).toHaveText('Desconocido');

  // Un PNJ sin estadísticas lo dice en vez de mostrar placas vacías.
  await page.goto(`${BIBLIOTECA}/odile`);
  await expect(page.locator('[data-card="stats"]')).toContainText(t.npcNoStatsNote);
  await expect(page.locator('[data-card="campaigns"]')).toContainText(t.npcNoCampaignsYet);

  expect(escrituras).toEqual([]);
});

test('los PNJ del DM no llegan a otra cuenta: lo ajeno responde igual que lo inexistente', async ({ context, page, baseURL }) => {
  // En la API: la otra cuenta tiene la biblioteca vacía, y pedir un PNJ del DM
  // da el mismo 404 que uno que no existe.
  const pedir = (path: string) => page.request.get(path, { headers: { cookie: `dnd_session=${TOKEN}` } });
  const { npcs } = await api<{ npcs: unknown[] }>(page.request, '/api/npcs', TOKEN);
  expect(npcs).toEqual([]);
  const ajeno = await pedir('/api/npcs/garrick');
  const inexistente = await pedir('/api/npcs/no-existe');
  expect(ajeno.status()).toBe(404);
  expect(inexistente.status()).toBe(404);
  expect(await ajeno.text()).toBe(await inexistente.text());

  // Ni por la campaña del jugador: nada de lo que el DM escribió de sus PNJ.
  const jugador = JSON.stringify(await api<unknown>(page.request, '/api/characters/elsbeth-de-humo/campaigns', TOKEN));
  for (const secreto of SOLO_DEL_DM) expect(jugador, `la API del jugador manda «${secreto}»`).not.toContain(secreto);

  // En la pantalla: la misma «No se encontró» para el ajeno y el inexistente.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  for (const id of ['garrick', 'no-existe']) {
    await page.goto(`${BIBLIOTECA}/${id}`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.npcNotFound);
  }
  for (const secreto of SOLO_DEL_DM) await expect(page.getByText(secreto)).toHaveCount(0);
});
