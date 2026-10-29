import { expect, test } from '@playwright/test';
import { TOKEN_SIN_V2 } from './helpers';

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

  for (const ruta of ['/v2/', '/v2/personajes/guerrero-de-humo/combate', '/v2/lo-que-sea']) {
    await page.goto(ruta);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('No disponible');
    await expect(page.getByRole('link', { name: /Personajes|Mis personajes/ })).toHaveCount(0);
  }
  expect(pedidos).toEqual([]);
});
