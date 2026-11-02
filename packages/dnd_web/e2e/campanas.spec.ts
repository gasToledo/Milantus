import { expect, test } from '@playwright/test';
import { api, TOKEN, TOKEN_DM, TOKEN_SIN_V2 } from './helpers';

test.use({ locale: 'es-AR' });

const ELSBETH = 'elsbeth-de-humo';

// Lo que el DM sembró y el jugador no tiene que ver (ver `e2e_server.dart`).
const SOLO_DEL_DM = [
  'Tema secreto del DM',
  'escena-secreta',
  'Resumen reservado del DM',
  'Nota reservada del DM',
  'Nota privada',
  'El Valle Hueco',
  'Garrick el Tabernero',
  'capitulo-en-marcha',
  'El Concilio de Brasas',
  'subió a nivel',
  'levelUps',
  'encounterLogs',
];

test('nada del DM llega al jugador: ni en lo que manda la API ni en la pantalla de Campañas', async ({
  context,
  page,
  request,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  const { campaigns } = await api<{ campaigns: { campaign: { name: string } }[] }>(
    request,
    `/api/characters/${ELSBETH}/campaigns`,
  );

  await page.goto('/v2/campanas');
  await expect(page.getByRole('heading', { level: 2, name: campaigns[0]!.campaign.name })).toBeVisible();

  const crudo = JSON.stringify(campaigns);
  const texto = await page.locator('body').innerText();
  for (const secreto of SOLO_DEL_DM) {
    expect(crudo, `la API manda «${secreto}»`).not.toContain(secreto);
    expect(texto, `la pantalla muestra «${secreto}»`).not.toContain(secreto);
  }
});

test('lo ajeno y lo inexistente responden igual: 404, y la cuenta sin v2 no ve campañas', async ({
  context,
  page,
  baseURL,
}) => {
  // Ni otra cuenta ni el propio DM de la mesa leen la ficha de Elsbeth por su
  // id; un id que no existe responde lo mismo.
  for (const token of [TOKEN_SIN_V2, TOKEN_DM]) {
    const ajeno = await page.request.get(`/api/characters/${ELSBETH}/campaigns`, {
      headers: { cookie: `dnd_session=${token}` },
    });
    expect(ajeno.status()).toBe(404);
    const inexistente = await page.request.get('/api/characters/no-existe/campaigns', {
      headers: { cookie: `dnd_session=${token}` },
    });
    expect(inexistente.status()).toBe(404);
    expect(await ajeno.text()).toBe(await inexistente.text());
  }

  // Y sin webV2 la ruta no existe: «No disponible», sin pedir campañas.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_SIN_V2, url: baseURL! }]);
  const pedidos: string[] = [];
  page.on('request', (r) => {
    if (new URL(r.url()).pathname.includes('/campaigns')) pedidos.push(r.url());
  });
  await page.goto('/v2/campanas');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('No disponible');
  expect(pedidos).toEqual([]);
});
