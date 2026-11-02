import { expect, test } from '@playwright/test';
import { textsFor } from '../src/i18n/texts';
import { api, TOKEN } from './helpers';

test.use({ locale: 'es-AR' });

const t = textsFor('es');
const MESA = '/api/campaigns/marca-del-cuervo';
const COMBATE = '/v2/dm/campanas/marca-del-cuervo/combate';

// Lo que el DM anotó en el combate sembrado (`e2e_server.dart`) y que el
// jugador no tiene que recibir por ningún lado.
const SOLO_DEL_DM = ['Marca reservada del DM', 'emboscada-del-valle', 'Lobo 1'];

test('el combate es del DM: otra cuenta recibe el mismo 404 que ante lo inexistente y el jugador solo ve su turno', async ({
  context,
  page,
  baseURL,
}) => {
  const pedir = (path: string) => page.request.get(path, { headers: { cookie: `dnd_session=${TOKEN}` } });
  const ajeno = await pedir(`${MESA}/encounter`);
  const inexistente = await pedir('/api/campaigns/no-existe/encounter');
  expect(ajeno.status()).toBe(404);
  expect(await ajeno.text()).toBe(await inexistente.text());

  // El jugador vinculado pregunta por su turno y recibe un estado, nunca el
  // combate; tampoco viaja en la campaña que ve.
  const turno = await api<{ turn: string }>(page.request, '/api/characters/elsbeth-de-humo/turn', TOKEN);
  expect(turno.turn).toBe('waiting');
  const campanas = await api<unknown>(page.request, '/api/characters/elsbeth-de-humo/campaigns', TOKEN);
  for (const secreto of SOLO_DEL_DM) {
    expect(JSON.stringify(turno), `el turno manda «${secreto}»`).not.toContain(secreto);
    expect(JSON.stringify(campanas), `la campaña del jugador manda «${secreto}»`).not.toContain(secreto);
  }

  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  await page.goto(COMBATE);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.dmCampaignNotFound);
  for (const secreto of SOLO_DEL_DM) await expect(page.getByText(secreto)).toHaveCount(0);
});
