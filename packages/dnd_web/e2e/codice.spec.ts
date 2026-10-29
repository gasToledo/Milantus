import { expect, test } from '@playwright/test';
import { api, catalogo, TOKEN } from './helpers';
import type { JsonObject } from '../src/engine';

test.use({ locale: 'es-AR' });

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
});

test('el Códice lista el catálogo con el homebrew de la cuenta y abre cada entrada en su URL', async ({
  page,
  request,
}) => {
  const catalog = catalogo();
  const { content } = await api<{ content: { weapons: JsonObject[] } }>(request, '/api/homebrew');
  const hacha = content.weapons[0]!;

  // La portada cuenta lo que hay: las armas oficiales más el arma propia.
  await page.goto('/v2/codice');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Códice');
  await expect(page.locator('[data-category="weapons"]')).toContainText(String(catalog.weapons.length + 1));

  // El arma homebrew está en Armas, con su procedencia.
  await page.locator('[data-category="weapons"]').click();
  await expect(page).toHaveURL('/v2/codice/armas');
  await page.locator(`[data-entry="${hacha.id}"]`).click();
  await expect(page).toHaveURL(`/v2/codice/armas/${hacha.id}`);
  const detalle = page.locator('[data-field="codex-detail"]');
  await expect(detalle.getByRole('heading', { level: 2 })).toHaveText(String(hacha.name));
  await expect(detalle).toContainText('Propio');

  // Un conjuro abierto por URL: los datos de lanzamiento y las clases salen
  // del catálogo y los rótulos del motor.
  const bola = catalog.spells.find((s) => s.id === 'fireball')!;
  await page.goto('/v2/codice/conjuros/fireball');
  await expect(detalle.getByRole('heading', { level: 2 })).toHaveText(String(bola.name));
  await expect(detalle).toContainText(String(bola.range));
  await expect(detalle).toContainText('Hechicero');
  await expect(detalle).toContainText('Mago');
});

test('la búsqueda general agrupa por categoría y «Ver las N» abre la categoría filtrada', async ({ page }) => {
  const catalog = catalogo();
  const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
  const conjuros = catalog.spells.filter((s) => fold(String(s.name)).includes('fuego'));
  expect(conjuros.length).toBeGreaterThan(5);

  await page.goto('/v2/codice');
  await page.getByRole('searchbox', { name: 'Buscar en todo el Códice' }).fill('fuego');
  const grupo = page.locator('[data-results="spells"]');
  await expect(grupo.getByRole('link')).toHaveCount(5);
  await grupo.getByRole('button', { name: `Ver las ${conjuros.length} coincidencias en Conjuros` }).click();
  await expect(page).toHaveURL(/\/v2\/codice\/conjuros\?q=fuego$/);
  await expect(page.locator('[data-field="codex-list"] [data-entry]')).toHaveCount(conjuros.length);
});
