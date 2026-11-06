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

test('la música se ofrece una vez que se guarda un combate y solo suena si el DM la elige', async ({ context, page, baseURL }) => {
  const cookie = `dnd_session=${TOKEN_DM}`;
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  await context.route('https://www.youtube-nocookie.com/embed/**', (route) => route.fulfill({ body: '<html></html>', contentType: 'text/html' }));
  const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const creada = await page.request.post('/api/campaigns', {
    headers: { cookie },
    data: { campaign: { schemaVersion: 2, id: 'musica-combate-e2e', name: 'Música e2e', premise: '', state: 'active', musicScenes: [
      { id: 'emboscada', name: 'La emboscada', url, offerOnCombat: true },
      { id: 'descanso', name: 'El descanso', url },
    ] } },
  });
  expect(creada.ok()).toBe(true);
  const { campaign } = (await creada.json()) as { campaign: { id: string } };
  const ruta = `/api/campaigns/${campaign.id}/encounter`;
  let fallar = true;
  await page.route(`**${ruta}`, async (route) => {
    if (route.request().method() === 'PUT' && fallar) {
      fallar = false;
      await route.fulfill({ status: 500 });
    } else await route.continue();
  });

  await page.goto(`/v2/dm/campanas/${campaign.id}/combate`);
  const armar = page.locator('[data-action="setup-combat"]');
  const oferta = page.locator('[data-music-offer]');
  const reproductor = page.locator('[data-music-player] iframe');
  await armar.click();
  await expect(page.getByText(t.dmSaveCombatFailed, { exact: true }).first()).toBeVisible();
  await expect(oferta).toHaveCount(0);
  await page.getByRole('button', { name: t.retry, exact: true }).click();
  await expect(oferta.getByText(t.dmMusicOfferOne('La emboscada'), { exact: true })).toBeVisible();
  await expect(reproductor).toHaveCount(0);
  await oferta.getByRole('button', { name: t.dmMusicNotNow, exact: true }).click();
  await page.reload();
  await expect(page.locator('[data-action="discard-combat"]')).toBeVisible();
  await expect(oferta).toHaveCount(0);
  await expect(reproductor).toHaveCount(0);

  await page.locator('[data-action="add-combatant"]').click();
  await page.locator('[data-option="goblin-minion"]').click();
  await page.getByRole('button', { name: t.dmAddShort, exact: true }).click();
  await page.getByRole('button', { name: t.close, exact: true }).click();
  await page.locator('[data-action="roll-initiative"]').click();
  await page.getByRole('button', { name: t.dmStart, exact: true }).click();
  await expect.poll(async () => (await api<{ encounter: { stage: string } }>(page.request, ruta, TOKEN_DM)).encounter.stage).toBe('running');
  await expect(oferta).toHaveCount(0);

  await page.locator('[data-action="finish-combat"]').click();
  await page.getByRole('button', { name: t.encDiscardNoSave, exact: true }).click();
  await armar.click();
  await oferta.getByRole('button', { name: t.dmMusicPlay, exact: true }).click();
  await expect(oferta).toHaveCount(0);
  await expect(reproductor).toHaveAttribute('title', 'La emboscada');
});

test('la ficha de un jugador abierta desde el combate vuelve al combate', async ({ context, page, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  await page.goto(COMBATE);
  await page.locator('[data-combatant="c-elsbeth"]').getByRole('link', { name: t.encOpenSheet, exact: true }).click();
  const ficha = page.locator('[data-member-sheet]');
  await ficha.getByRole('tab', { name: t.tabCombat, exact: true }).click();
  await page.reload();
  await ficha.getByRole('link', { name: t.luBack, exact: true }).click();
  await expect(page).toHaveURL(`${baseURL}${COMBATE}`);
});

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

test('el DM arma, juega, convierte un monstruo en PNJ y termina el combate', async ({ context, page, baseURL }) => {
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

  // Jugar: la cifra existe dos veces (encabezado y barra de la fila partida) y
  // solo una se ve según el ancho de la planilla. Dañar manda la cifra del campo y pasar el turno da la vuelta. El
  // secuaz tira 2d6 de PG (mínimo 2): con 1 de daño siempre queda en pie, y con
  // un solo combatiente el turno vuelve a él y suma una ronda (`Encounter.next`).
  type Guardado = { encounter?: { round: number; combatants: { currentHp: number; maxHp: number }[] } };
  await page.locator('[data-field="amount"]:visible').fill('1');
  await page.locator('[data-action="hurt"]').click();
  await expect
    .poll(async () => {
      const { encounter } = await api<Guardado>(page.request, ruta, TOKEN_DM);
      const g = encounter?.combatants[0];
      return g ? g.maxHp - g.currentHp : null;
    })
    .toBe(1);
  await page.locator('[data-action="next-turn"]').click();
  await expect.poll(async () => (await api<Guardado>(page.request, ruta, TOKEN_DM)).encounter?.round).toBe(2);

  // Efectos y defensas: el diálogo manda lo que cambió y el motor lo guarda.
  await page.locator('[data-action="effects"]').first().click();
  await page.getByRole('button', { name: t.encAdvantage, exact: true }).click();
  await page.locator('[data-field="effects-temp"]').fill('3');
  await page.getByRole('button', { name: t.conditionRules.prone.label, exact: true }).click();
  await page.getByRole('button', { name: t.commonSave, exact: true }).click();
  await expect
    .poll(async () => {
      const { encounter } = await api<{ encounter?: { combatants: { advantage?: string; tempHp?: number; tags?: string[] }[] } }>(page.request, ruta, TOKEN_DM);
      const g = encounter?.combatants[0];
      return g ? [g.advantage, g.tempHp, g.tags] : null;
    })
    .toEqual(['advantage', 3, [textsFor('es').conditionRules.prone.label]]);

  type Combate = { id: string; round: number; turnIndex: number; combatants: { id: string; name: string; npcId?: string }[] };
  const { encounter: antes } = await api<{ encounter: Combate }>(page.request, ruta, TOKEN_DM);
  const original = antes.combatants[0]!;
  const convertir = `${ruta}/${antes.id}/combatants/${original.id}/npc`;
  await page.route(`**${convertir}`, async (route) => {
    // El servidor guardó los tres cambios pero el navegador perdió la respuesta.
    await route.fetch();
    await route.abort();
  }, { times: 1 });
  const fila = page.locator(`[data-combatant="${original.id}"]`);
  await fila.getByRole('button', { name: t.encSideOf(original.name), exact: true }).click();
  await page.getByRole('menuitem', { name: t.encConvertToNpcEllipsis, exact: true }).click();
  const dialogo = page.getByRole('dialog', { name: t.encConvertToNpc, exact: true });
  const campoNombre = dialogo.getByRole('textbox', { name: t.npcNameLabel, exact: true });
  await expect(campoNombre).toHaveValue(original.name);
  await campoNombre.fill('Sable');
  await dialogo.getByRole('button', { name: t.encConvert, exact: true }).click();
  await expect(dialogo.getByRole('alert')).toHaveText(t.encConvertFailed);
  await expect(campoNombre).toHaveValue('Sable');
  const { encounter: convertido } = await api<{ encounter: Combate }>(page.request, ruta, TOKEN_DM);
  const npcId = convertido.combatants[0]?.npcId;
  expect(npcId).toBeTruthy();
  await dialogo.getByRole('button', { name: t.retry, exact: true }).click();
  await expect(fila.getByText('Sable', { exact: true })).toBeVisible();
  expect(convertido).toEqual({ ...antes, combatants: [{ ...original, name: 'Sable', kind: 'npc', npcId }] });
  const { npcs } = await api<{ npcs: { npc: { id: string; name: string } }[] }>(page.request, `/api/campaigns/${campaign.id}/npcs`, TOKEN_DM);
  expect(npcs.map(({ npc }) => [npc.id, npc.name])).toEqual([[npcId, 'Sable']]);
  const biblioteca = await api<{ npcs: { npc: { id: string; name: string } }[] }>(page.request, '/api/npcs', TOKEN_DM);
  expect(biblioteca.npcs.filter(({ npc }) => npc.name === 'Sable').map(({ npc }) => npc.id)).toEqual([npcId]);

  await page.locator('[data-action="finish-combat"]').click();
  await page.getByRole('button', { name: t.encFinishAndSave, exact: true }).click();
  await expect.poll(async () => (await page.request.get(ruta, { headers: { cookie } })).status()).toBe(404);
  await expect.poll(async () => {
    const { encounterLogs } = await api<{ encounterLogs: unknown[] }>(page.request, `/api/campaigns/${campaign.id}/notebook`, TOKEN_DM);
    return encounterLogs.length;
  }).toBe(1);
});
