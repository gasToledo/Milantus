import { expect, test } from '@playwright/test';
import { textsFor } from '../src/i18n/texts';
import { api, TOKEN } from './helpers';

test.use({ locale: 'es-AR' });

const t = textsFor('es');
const BIBLIOTECA = '/v2/dm/pnj';

// Lo que el DM escribió de sus PNJ (ver `_seedNpcs` en `e2e_server.dart`) y
// no tiene que llegarle a ninguna otra cuenta.
const SOLO_DEL_DM = ['Voz reservada del DM', 'Trasfondo reservado del DM', 'Nota reservada del PNJ', 'Vesna la Cuervo'];

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
  // Los PNJ de una mesa ajena, igual que los de una que no existe.
  const mesaAjena = await pedir('/api/campaigns/marca-del-cuervo/npcs');
  const mesaInexistente = await pedir('/api/campaigns/no-existe/npcs');
  expect(mesaAjena.status()).toBe(404);
  expect(await mesaAjena.text()).toBe(await mesaInexistente.text());

  // Ni por la campaña del jugador: nada de lo que el DM escribió de sus PNJ.
  const jugador = JSON.stringify(await api<unknown>(page.request, '/api/characters/elsbeth-de-humo/campaigns', TOKEN));
  for (const secreto of SOLO_DEL_DM) expect(jugador, `la API del jugador manda «${secreto}»`).not.toContain(secreto);

  // En la pantalla: la misma «No se encontró» para el ajeno y el inexistente.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  for (const id of ['garrick', 'no-existe']) {
    await page.goto(`${BIBLIOTECA}/${id}`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.npcNotFound);
  }
  // Tampoco la ficha completa del PNJ con ficha.
  for (const id of ['vesna', 'no-existe']) {
    await page.goto(`${BIBLIOTECA}/${id}/ficha/personaje`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.npcNotFound);
  }
  await page.goto('/v2/dm/campanas/marca-del-cuervo/pnj');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.dmCampaignNotFound);
  for (const secreto of SOLO_DEL_DM) await expect(page.getByText(secreto)).toHaveCount(0);
});
