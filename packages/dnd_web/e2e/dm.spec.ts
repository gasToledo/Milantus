import { expect, test } from '@playwright/test';
import { chapterGrants, computeSheet, type JsonObject } from '../src/engine';
import { signed } from '../src/sheet/format';
import { api, catalogo, TOKEN, TOKEN_DM, TOKEN_SIN_V2, vigilarEscrituras, type PersonajeApi } from './helpers';

test.use({ locale: 'es-AR' });

const CAMPANA = 'marca-del-cuervo';
const MESA = `/v2/dm/campanas/${CAMPANA}/mesa`;

// Lo que el DM sembró y no tiene que llegarle a ninguna otra cuenta (ver
// `e2e_server.dart`).
const SOLO_DEL_DM = ['La Marca del Cuervo', 'Tema secreto del DM', 'Resumen reservado del DM', 'Nota reservada del DM'];

test('la Mesa del DM lista a los jugadores vinculados con los números del motor y sin escribir nada', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);

  // Lo esperado sale de la API de miembros y del motor, no de una transcripción.
  const { members } = await api<{ members: { memberId: string; character: PersonajeApi }[] }>(
    page.request,
    `/api/campaigns/${CAMPANA}/members`,
    TOKEN_DM,
  );
  expect(members.map((m) => m.character.id).sort()).toEqual(['elsbeth-de-humo', 'sagan-de-humo']);
  const catalog = catalogo();

  // Entrar por «DM» del interruptor lleva a la primera campaña en curso.
  await page.goto('/v2/');
  await page.getByRole('group', { name: 'Modo' }).getByRole('link', { name: 'DM' }).click();
  await expect(page).toHaveURL(MESA);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('La Marca del Cuervo');
  await expect(page.getByText('En curso · El Valle Hueco')).toBeVisible();
  await expect(page.getByRole('list', { name: '2 personajes en la mesa' })).toBeVisible();
  // El modo actual es DM: el interruptor lo marca y «Jugador» pasa a ser el enlace.
  await expect(page.getByRole('group', { name: 'Modo' }).locator('[aria-current="true"]')).toHaveText('DM');

  for (const { character } of members) {
    const ficha = computeSheet(character, catalog);
    const tarjeta = page.locator(`[data-member="${character.id}"]`);
    const placa = (stat: string) => tarjeta.locator(`[data-stat="${stat}"] [data-field="value"]`);
    await expect(tarjeta.getByRole('heading', { level: 2 })).toHaveText(character.name);
    await expect(tarjeta.locator('[data-stat="level"]')).toHaveText(String(ficha.level));
    await expect(tarjeta.locator('[data-stat="hp"]')).toHaveText(`${character.combat.currentHp} / ${ficha.maxHp}`);
    await expect(placa('ac')).toHaveText(String(ficha.armorClass));
    await expect(placa('initiative')).toHaveText(signed(ficha.initiative));
    await expect(placa('passive')).toHaveText(String(ficha.passivePerception));
    // Elsbeth es clériga (CD del motor); Sagan, guerrero (sin CD).
    const cd = ficha.spellcasting?.saveDc;
    await expect(placa('dc')).toHaveText(cd === undefined ? '—' : String(cd));
  }

  // Los estados de la ficha del jugador, como pills; la sana no tiene ninguno.
  const sagan = page.locator('[data-member="sagan-de-humo"]');
  await expect(sagan.getByRole('listitem').filter({ hasText: 'Envenenado' })).toBeVisible();
  await expect(sagan.getByRole('listitem').filter({ hasText: 'Agotamiento 2' })).toBeVisible();
  await expect(page.locator('[data-member="elsbeth-de-humo"]').getByRole('listitem')).toHaveCount(0);

  // El panel: herramientas que viven en Flutter con su aviso, y las campañas.
  const herramientas = page.getByRole('navigation', { name: 'Herramientas del DM' });
  await expect(herramientas.getByRole('link', { name: /Biblioteca de PNJ/ })).toContainText('se abre en la aplicación principal');
  await expect(page.getByRole('navigation', { name: 'Campañas' }).getByRole('link', { name: 'La Marca del Cuervo' })).toHaveAttribute(
    'aria-current',
    'page',
  );

  // Ni la Mesa ni nada de lo que se vio escribió en la API.
  expect(escrituras).toEqual([]);
});

test('Capítulos muestra estado, objetivo y recompensas de cada capítulo, y solo el DM lee el objetivo', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const { chapters } = await api<{ chapters: (JsonObject & { id: string })[] }>(
    page.request,
    `/api/campaigns/${CAMPANA}/chapters`,
    TOKEN_DM,
  );

  await page.goto(MESA);
  await page.getByRole('navigation', { name: 'Secciones de la campaña' }).getByRole('link', { name: 'Capítulos' }).click();
  await expect(page).toHaveURL(`/v2/dm/campanas/${CAMPANA}/capitulos`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Capítulos');
  await expect(page.getByText('En curso · 3 capítulos')).toBeVisible();

  const estado = { 'paso-de-varn': 'closed', 'capitulo-en-marcha': 'open', 'concilio-de-brasas': 'pending' };
  const rotulo = { closed: 'Cerrado', open: 'Abierto', pending: 'Pendiente' };
  for (const c of chapters) {
    const tarjeta = page.locator(`[data-chapter="${c.id}"]`);
    const e = estado[c.id as keyof typeof estado] as keyof typeof rotulo;
    await expect(tarjeta).toHaveAttribute('data-status', e);
    await expect(tarjeta).toContainText(rotulo[e]);
    // Lo que reparte lo nombra el motor, igual que en la vista del jugador.
    if (chapterGrants(c)) await expect(tarjeta).toContainText(`Reparte ${chapterGrants(c)}`);
  }
  // El objetivo es del DM: acá se lee; el sin definir lo dice.
  await expect(page.locator('[data-chapter="capitulo-en-marcha"]')).toContainText('Resumen reservado del DM');
  await expect(page.locator('[data-chapter="concilio-de-brasas"]')).toContainText('Sin definir todavía.');
  await expect(page.locator('[data-chapter="paso-de-varn"] [data-stat="gold"]')).toContainText('25');
  // El abierto se destaca con el borde oro.
  await expect(page.locator('[data-chapter="capitulo-en-marcha"]')).toHaveClass(/border-gold/);
  expect(escrituras).toEqual([]);

  // El jugador vinculado nunca recibe el objetivo ni los capítulos sin cerrar.
  const jugador = await api<unknown>(page.request, '/api/characters/elsbeth-de-humo/campaigns', TOKEN);
  const crudo = JSON.stringify(jugador);
  for (const secreto of ['Resumen reservado del DM', 'El Concilio de Brasas', 'El Valle Hueco']) {
    expect(crudo, `la API del jugador manda «${secreto}»`).not.toContain(secreto);
  }
});

test('el DM no escribe la ficha del jugador: leerla no la cambia', async ({ request }) => {
  const leer = async () =>
    JSON.stringify((await api<{ characters: unknown[] }>(request, '/api/characters', TOKEN)).characters);
  const antes = await leer();
  await api(request, `/api/campaigns/${CAMPANA}/members`, TOKEN_DM);
  expect(await leer()).toBe(antes);
});

test('otra cuenta recibe 404 al pedir la campaña, idéntico al de una inexistente, y no ve nada del DM en /v2', async ({
  context,
  page,
  baseURL,
}) => {
  for (const token of [TOKEN, TOKEN_SIN_V2]) {
    for (const ruta of ['members', 'chapters', 'notebook']) {
      const ajena = await page.request.get(`/api/campaigns/${CAMPANA}/${ruta}`, {
        headers: { cookie: `dnd_session=${token}` },
      });
      const inexistente = await page.request.get(`/api/campaigns/no-existe/${ruta}`, {
        headers: { cookie: `dnd_session=${token}` },
      });
      expect(ajena.status(), `${ruta} con otra cuenta`).toBe(404);
      expect(inexistente.status()).toBe(404);
      expect(await ajena.text()).toBe(await inexistente.text());
    }
    // La lista de campañas de otra cuenta no incluye la del DM.
    const { campaigns } = await api<{ campaigns: unknown[] }>(page.request, '/api/campaigns', token);
    expect(JSON.stringify(campaigns)).not.toContain(CAMPANA);
  }

  // Con webV2 pero sin esa campaña: la pantalla responde lo mismo que ante un
  // id inexistente, y ni el nombre ni los jugadores aparecen.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  for (const id of [CAMPANA, 'no-existe']) {
    await page.goto(`/v2/dm/campanas/${id}/mesa`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('No se encontró la campaña');
  }
  const texto = await page.locator('body').innerText();
  for (const secreto of SOLO_DEL_DM) expect(texto, `la pantalla muestra «${secreto}»`).not.toContain(secreto);
  await expect(page.locator('[data-member]')).toHaveCount(0);

  // Sin campañas propias, «DM» no tiene a dónde llevar: lo dice.
  await page.goto('/v2/dm');
  await expect(page.getByText('Todavía no dirigís ninguna campaña.')).toBeVisible();
});
