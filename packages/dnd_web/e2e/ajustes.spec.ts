import { expect, test } from '@playwright/test';
import { TOKEN, vigilarEscrituras } from './helpers';

test.use({ locale: 'es-AR' });

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
});

test('Ajustes muestra lo que guarda la cuenta, sin escribirlo', async ({ page }) => {
  const escrituras = vigilarEscrituras(page);
  await page.goto('/v2/ajustes');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Ajustes');

  // Los ajustes sembrados: orden por nivel y Zelda de favorita (el nombre sale
  // de la lista de personajes, no del id guardado).
  const cuenta = page.locator('[data-card="settings-account"]');
  await expect(cuenta.locator('[data-field="start-mode"]')).toContainText('Modo Jugador');
  await expect(cuenta.locator('[data-field="sort"]')).toContainText('Nivel');
  await expect(cuenta.locator('[data-field="favorite"]')).toContainText('Zelda de Humo');

  // El panel marca Ajustes como la pantalla actual.
  await expect(page.getByRole('link', { name: 'Ajustes' }).first()).toHaveAttribute('aria-current', 'page');
  expect(escrituras).toEqual([]);
});

test('el tema y el idioma son del navegador: cambian sin tocar la cuenta', async ({ page }) => {
  const escrituras = vigilarEscrituras(page);
  await page.goto('/v2/ajustes');

  await page.getByRole('combobox', { name: 'Tema' }).click();
  await page.getByRole('option', { name: 'Claro' }).click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');

  // El idioma recarga la página en el idioma nuevo y queda recordado con la
  // clave que comparte con Flutter.
  await page.getByRole('combobox', { name: 'Idioma' }).click();
  await page.getByRole('option', { name: 'English' }).click();
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Settings');
  expect(await page.evaluate(() => window.localStorage.getItem('milantus.locale'))).toBe('en');
  await expect(page.locator('[data-field="sort"]')).toContainText('Level');

  expect(escrituras).toEqual([]);
});
