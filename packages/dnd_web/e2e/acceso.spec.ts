import { expect, test } from '@playwright/test';
import { api, TOKEN_DM, TOKEN_SIN_V2, vigilarEscrituras, type PersonajeApi } from './helpers';

test.use({ locale: 'es-AR' });

test('una cuenta sin webV2 ve «No disponible» en cualquier ruta y no pide sus datos', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_SIN_V2, url: baseURL! }]);
  // Más allá de `/api/me`, ni personajes, ni ajustes, ni homebrew: la pantalla
  // no puede delatar nada de lo que hay detrás.
  const pedidos: string[] = [];
  page.on('request', (r) => {
    const path = new URL(r.url()).pathname;
    if (path.startsWith('/api/') && path !== '/api/me') pedidos.push(path);
  });

  for (const ruta of ['/v2/', '/v2/personajes/guerrero-de-humo/combate', '/v2/bestiario', '/v2/campanas', '/v2/ajustes', '/v2/lo-que-sea']) {
    await page.goto(ruta);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('No disponible');
    await expect(page.getByRole('link', { name: /Personajes|Mis personajes/ })).toHaveCount(0);
  }
  expect(pedidos).toEqual([]);
});

// Acá y no con las de escritura: esas corren en serie, y una falla cualquiera
// salteaba esta, que es de autorización.
test('la ficha de otra cuenta no tiene controles para escribir', async ({ context, page, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const { members } = await api<{ members: { memberId: string; character: PersonajeApi }[] }>(
    page.request,
    '/api/campaigns/marca-del-cuervo/members',
    TOKEN_DM,
  );
  const sagan = members.find((m) => m.character.id === 'sagan-de-humo')!;

  await page.goto(`/v2/dm/campanas/marca-del-cuervo/mesa/${sagan.memberId}/combate`);
  await expect(page.locator('[data-card="hit-points"]')).toBeVisible();
  await expect(page.locator('[data-controls]')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Daño' })).toHaveCount(0);
  // Ni estados, ni cansancio, ni estados activables: nada que escriba.
  await expect(page.locator('[data-condition], [data-field="exhaustion"]')).toHaveCount(0);
  await expect(page.getByRole('button', { name: /^(Activar|Terminar)$/ })).toHaveCount(0);
  // Ni preparar conjuros ni cambiar el truco innato.
  await expect(page.locator('[data-action="edit-spells"], [data-action="swap-innate"]')).toHaveCount(0);
  expect(escrituras).toEqual([]);
});
