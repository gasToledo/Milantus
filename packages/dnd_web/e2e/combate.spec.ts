import { expect, test } from '@playwright/test';
import { textsFor } from '../src/i18n/texts';
import { api, catalogo, TOKEN, TOKEN_DM } from './helpers';

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

test('armar, descartar y empezar un combate guardan lo que da el motor', async ({ context, page, baseURL }) => {
  const cookie = `dnd_session=${TOKEN_DM}`;
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  // Una campaña propia de la prueba: no toca el combate sembrado de la del cuervo.
  const creada = await page.request.post('/api/campaigns', {
    headers: { cookie },
    data: { campaign: { id: 'combate-e2e', name: 'Combate e2e', premise: '', state: 'active' } },
  });
  expect(creada.ok()).toBe(true);
  const { campaign } = (await creada.json()) as { campaign: { id: string } };
  const ruta = `/api/campaigns/${campaign.id}/encounter`;

  await page.goto(`/v2/dm/campanas/${campaign.id}/combate`);
  await page.locator('[data-action="setup-combat"]').click();
  await page.locator('[data-action="add-combatant"]').click();
  // Sin PNJ en la campaña, el diálogo abre en el Bestiario.
  await page.locator('[data-option="goblin-minion"]').click();
  const mas = page.getByRole('button', { name: t.dmOneMore, exact: true });
  await mas.click();
  await mas.click();
  await page.getByRole('button', { name: t.dmAddCount(3), exact: true }).click();
  await page.getByRole('button', { name: t.close, exact: true }).click();

  // El guardado espera 400 ms: se lee hasta que llega.
  const nombre = String(catalogo().creatures.find((c) => c.id === 'goblin-minion')!.name);
  await expect
    .poll(async () => {
      const { encounter } = await api<{ encounter?: { stage: string; combatants: { name: string }[] } }>(page.request, ruta, TOKEN_DM);
      return encounter ? [encounter.stage, ...encounter.combatants.map((c) => c.name)] : null;
    })
    .toEqual(['preparing', `${nombre} 1`, `${nombre} 2`, `${nombre} 3`]);

  await page.locator('[data-action="discard-combat"]').click();
  await page.getByRole('button', { name: t.encDiscardShort, exact: true }).click();
  await expect.poll(async () => (await page.request.get(ruta, { headers: { cookie } })).status()).toBe(404);

  // Empezar: se arma de nuevo con una sola criatura y «Tirar iniciativa» manda
  // la tirada que propuso el motor (el campo la trae escrita).
  await page.locator('[data-action="setup-combat"]').click();
  await page.locator('[data-action="add-combatant"]').click();
  await page.locator('[data-option="goblin-minion"]').click();
  await page.getByRole('button', { name: t.dmAddShort, exact: true }).click();
  await page.getByRole('button', { name: t.close, exact: true }).click();
  await page.locator('[data-action="roll-initiative"]').click();
  const campo = page.locator('[data-initiative]');
  const n = Number(await campo.inputValue());
  await page.getByRole('button', { name: t.dmStart, exact: true }).click();
  await expect
    .poll(async () => {
      const { encounter } = await api<{ encounter?: { stage: string; combatants: { initiative: number }[] } }>(page.request, ruta, TOKEN_DM);
      return encounter ? [encounter.stage, encounter.combatants[0]?.initiative] : null;
    })
    .toEqual(['running', n]);
});
