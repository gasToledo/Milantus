import { expect, test } from '@playwright/test';
import { abilityModifier, bestiary, catalogLabel, type JsonObject } from '../src/engine';
import { api, catalogo, TOKEN, TOKEN_DM, vigilarEscrituras } from './helpers';

test.use({ locale: 'es-AR' });

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
});

const firmado = (n: number) => (n >= 0 ? `+${n}` : `−${-n}`);

test('el Bestiario lista el catálogo con el homebrew de la cuenta y el perfil muestra lo que deriva el motor', async ({
  page,
  request,
}) => {
  const escrituras = vigilarEscrituras(page);
  const catalog = catalogo();
  // Lo mismo que el cliente: el homebrew encima, y sin las invocaciones por
  // fórmula (la lista sale del motor, no de un conteo propio).
  const { content } = await api<{ content: { creatures: JsonObject[] } }>(request, '/api/homebrew');
  const sombra = content.creatures[0]!;
  const todas = bestiary({ ...catalog, creatures: [...catalog.creatures, sombra] });

  await page.goto('/v2/bestiario');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(/^Bestiario/);
  await expect(page.locator('[data-field="bestiary-list"] [data-entry]')).toHaveCount(todas.length);
  expect(todas.length).toBeLessThan(catalog.creatures.length + 1); // hay invocaciones afuera

  // El homebrew: procedencia «Propio» e iniciativa del perfil (+6; con DES 16
  // sería +3), que el motor da y la pantalla no recalcula.
  const fila = todas.find((r) => r.id === sombra.id)!;
  await page.locator(`[data-entry="${sombra.id}"]`).click();
  await expect(page).toHaveURL(`/v2/bestiario/${sombra.id}`);
  const detalle = page.locator('[data-field="creature-detail"]');
  await expect(detalle.getByRole('heading', { level: 2 })).toHaveText('Sombra de Humo');
  await expect(detalle).toContainText('Propio');
  await expect(detalle).toContainText(fila.kind);
  await expect(detalle.getByText('Iniciativa').locator('xpath=..')).toContainText(firmado(fila.initiative));
  expect(fila.initiative).toBe(6);
  await expect(detalle.locator('[data-actions="action"]')).toContainText('Roce helado');
  await expect(detalle.locator('[data-actions="action"]')).toContainText('+5');
  await expect(detalle.locator('[data-actions="action"]')).toContainText(catalogLabel('damageType', 'cold'));

  // Un archimago por URL: CA y PG del catálogo, modificadores del motor,
  // salvaciones y el lanzamiento de conjuros con sus grupos.
  const archimago = catalog.creatures.find((c) => c.id === 'archmage')!;
  const scores = archimago.abilityScores as Record<string, number>;
  await page.goto('/v2/bestiario/archmage');
  await expect(detalle.getByRole('heading', { level: 2 })).toHaveText(String(archimago.name));
  await expect(detalle).toContainText(String(archimago.ac));
  await expect(detalle).toContainText(String(archimago.hp));
  await expect(detalle.locator('[data-ability="int"]')).toContainText(firmado(abilityModifier(scores.int!)));
  await expect(detalle.locator('[data-ability="int"]')).toContainText('SALV +9');
  await expect(detalle.getByText('A voluntad')).toBeVisible();
  await expect(detalle.getByRole('link', { name: 'Mano de mago' })).toHaveAttribute('href', '/v2/codice/conjuros/mage-hand');

  expect(escrituras).toEqual([]);
});

test('buscar, filtrar por tipo y por desafío, y ordenar por VD', async ({ page }) => {
  await page.goto('/v2/bestiario');
  const lista = page.locator('[data-field="bestiary-list"] [data-entry]');

  await page.getByRole('searchbox', { name: 'Buscar criatura' }).fill('sombra');
  // Busca por nombre sin tildes ni mayúsculas: está la «Sombra» del SRD y la
  // propia.
  await expect(page.locator('[data-entry="sombra-de-humo"]')).toBeVisible();
  await expect(page.locator('[data-entry="shadow"]')).toBeVisible();

  // Tipo: los muertos vivientes incluyen al homebrew.
  await page.getByRole('combobox', { name: 'Tipo' }).click();
  await page.getByRole('option', { name: 'Muerto viviente' }).click();
  await expect(page.locator('[data-entry="sombra-de-humo"]')).toBeVisible();

  // Un desafío mínimo de 2 la deja afuera (es VD 1); «hasta 0» corre el mínimo.
  await page.getByRole('combobox', { name: 'VD desde' }).click();
  await page.getByRole('option', { name: '2', exact: true }).click();
  await expect(page.locator('[data-entry="sombra-de-humo"]')).toHaveCount(0);

  await page.getByRole('searchbox', { name: 'Buscar criatura' }).fill('zzzz-nada');
  await expect(page.getByText('Ninguna criatura coincide con lo que buscaste.')).toBeVisible();
  await page.getByRole('button', { name: 'Limpiar filtros' }).click();
  await expect(page.locator('[data-entry="sombra-de-humo"]')).toBeVisible();

  // Por VD: sin búsqueda, la lista abre con las de menor desafío.
  await page.getByRole('searchbox', { name: 'Buscar criatura' }).fill('');
  await page.getByRole('button', { name: 'VD', exact: true }).click();
  const primeras = await page.locator('[data-field="bestiary-list"] [data-entry]').first().innerText();
  expect(primeras).toMatch(/VD 0|VD 1\/8/);
});

test('el homebrew es de la cuenta: otra cuenta no lo recibe', async ({ request }) => {
  const { content } = await api<{ content?: { creatures?: JsonObject[] } }>(request, '/api/homebrew');
  expect(content?.creatures?.map((c) => c.id)).toContain('sombra-de-humo');
  const ajeno = await request.get('/api/homebrew', { headers: { cookie: `dnd_session=${TOKEN_DM}` } });
  expect(JSON.stringify(await ajeno.json())).not.toContain('sombra-de-humo');
});
