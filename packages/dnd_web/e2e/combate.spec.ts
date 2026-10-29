import { expect, test } from '@playwright/test';
import type { CampaignMember, CampaignNpc } from '../src/api/client';
import { computeSheet, encounterView, npcViews, type JsonObject } from '../src/engine';
import { textsFor } from '../src/i18n/texts';
import { api, catalogo, TOKEN, TOKEN_DM, vigilarEscrituras } from './helpers';

test.use({ locale: 'es-AR' });

const t = textsFor('es');
const MESA = '/api/campaigns/marca-del-cuervo';
const COMBATE = '/v2/dm/campanas/marca-del-cuervo/combate';

// Lo que el DM anotó en el combate sembrado (`e2e_server.dart`) y que el
// jugador no tiene que recibir por ningún lado.
const SOLO_DEL_DM = ['Marca reservada del DM', 'emboscada-del-valle', 'Lobo 1'];

test('el Combate muestra el orden, el turno, los PG de cada fuente y los combates pasados, sin escribir', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const catalog = catalogo();
  const { encounter } = await api<{ encounter: JsonObject }>(page.request, `${MESA}/encounter`, TOKEN_DM);
  const { members } = await api<{ members: CampaignMember[] }>(page.request, `${MESA}/members`, TOKEN_DM);
  const { npcs } = await api<{ npcs: CampaignNpc[] }>(page.request, `${MESA}/npcs`, TOKEN_DM);
  const { encounterLogs } = await api<{ encounterLogs: unknown[] }>(page.request, `${MESA}/notebook`, TOKEN_DM);
  // Lo esperado, con el mismo motor: los PG de un jugador son los de su ficha
  // real y el máximo el que la compila.
  const fichas = new Map(members.map((m) => [m.memberId, { raw: m.character, sheet: computeSheet(m.character, catalog) }] as const));
  const playersHp = Object.fromEntries(
    [...fichas].map(([id, f]) => [id, { current: (f.raw.combat as { currentHp: number }).currentHp, max: f.sheet.maxHp }]),
  );
  const vista = encounterView(encounter, playersHp);
  // El sembrado: el turno es del primer lobo, Elsbeth ya actuó y el segundo
  // lobo, caído, se salta.
  expect(vista.currentId).toBe('c-lobo-1');

  await page.goto('/v2/dm/campanas/marca-del-cuervo/mesa');
  await page.getByRole('navigation', { name: 'Secciones de la campaña' }).getByRole('link', { name: 'Combate' }).click();
  await expect(page).toHaveURL(COMBATE);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Combate');

  const barra = page.locator('[data-field="control-bar"]');
  await expect(barra.locator('[data-field="round"]')).toHaveText(String(vista.encounter.round));
  await expect(barra.locator('[data-field="turn"]')).toHaveText(t.encTurnOf(vista.currentIndex + 1, vista.encounter.combatants.length));
  await expect(barra.locator('[data-field="allies"]')).toContainText(`${vista.standing.alliesUp}/${vista.standing.allies}`);
  await expect(barra.locator('[data-field="enemies"]')).toContainText(`${vista.standing.enemiesUp}/${vista.standing.enemies}`);

  await expect(page.locator('[data-combatant]')).toHaveCount(vista.encounter.combatants.length);
  await expect(page.locator('[data-combatant="c-lobo-1"]')).toHaveAttribute('aria-current', 'true');
  await expect(page.locator('[data-combatant="c-lobo-1"] [data-field="mark"]')).toHaveText(t.encTurnWord);
  await expect(page.locator('[data-combatant="c-elsbeth"] [data-field="mark"]')).toHaveText(t.encActed);
  await expect(page.locator('[data-combatant="c-lobo-2"] [data-field="mark"]')).toHaveText(t.encSkips);
  for (const fila of vista.rows) {
    if (fila.hp) {
      await expect(page.locator(`[data-combatant="${fila.id}"] [data-field="hp-value"]`)).toHaveText(`${fila.hp.current}/${fila.hp.max}`);
    }
  }
  // Los PG de Elsbeth son los de su ficha, no un número del encuentro (que no
  // los lleva), y la fila lo dice.
  const elsbeth = encounter.combatants as { id: string; memberId?: string }[];
  const deElsbeth = fichas.get(elsbeth.find((c) => c.id === 'c-elsbeth')!.memberId!)!;
  await expect(page.locator('[data-combatant="c-elsbeth"] [data-field="hp"]')).toContainText(
    `${(deElsbeth.raw.combat as { currentHp: number }).currentHp}/${deElsbeth.sheet.maxHp}`,
  );
  await expect(page.locator('[data-combatant="c-elsbeth"] [data-field="hp"]')).toContainText(t.encOnTheirSheet);
  // La CA de cada fuente: la ficha compilada, el PNJ que resuelve el motor y el
  // catálogo.
  await expect(page.locator('[data-combatant="c-elsbeth"] [data-field="ac"]')).toHaveText(String(deElsbeth.sheet.armorClass));
  const garrick = npcViews(npcs, catalog).find((v) => v.npc.id === 'garrick')!;
  await expect(page.locator('[data-combatant="c-garrick"] [data-field="ac"]')).toHaveText(garrick.armorClass!);
  const lobo = catalog.creatures.find((c) => c.id === 'wolf')!;
  await expect(page.locator('[data-combatant="c-lobo-1"] [data-field="ac"]')).toHaveText(String(lobo.ac));
  await expect(page.locator('[data-combatant="c-lobo-1"]')).toContainText('Marca reservada del DM');

  // «Del turno» es el perfil del lobo que juega, el del Bestiario.
  const turno = page.locator('[data-field="turn-panel"]');
  await expect(turno.locator('[data-field="creature-detail"] h2')).toHaveText(String(lobo.name));

  // Abajo, los combates cerrados de la campaña.
  await expect(page.locator('[data-log]')).toHaveCount(encounterLogs.length);

  expect(escrituras).toEqual([]);
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
