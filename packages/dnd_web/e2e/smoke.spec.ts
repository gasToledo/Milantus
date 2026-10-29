import { expect, test } from '@playwright/test';

// Mismos valores que `test/e2e_server.dart` en dnd_server.
const TOKEN = 'sesion-de-humo=';
const NOMBRE = 'Ada de Humo';

test('/v2 muestra la sesión iniciada contra el servidor real', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  await page.goto('/v2/');
  await expect(page.getByText(`Sesión iniciada como ${NOMBRE}.`)).toBeVisible();
});
