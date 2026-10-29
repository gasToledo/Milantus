import { expect, test } from '@playwright/test';
import type { JsonObject } from '../src/engine';
import { textsFor } from '../src/i18n/texts';
import { api, TOKEN, TOKEN_DM, vigilarEscrituras } from './helpers';

test.use({ locale: 'es-AR' });

const t = textsFor('es');

type Propio = { weapons: JsonObject[]; feats: JsonObject[]; creatures: JsonObject[] };

test('el Homebrew del Modo DM cuenta lo propio por categoría, abre la ficha del Códice y busca en todo, sin escribir', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const { content } = await api<{ content: Propio }>(page.request, '/api/homebrew');
  const hacha = content.weapons[0]!;
  const sombra = content.creatures[0]!;
  const total = content.weapons.length + content.feats.length + content.creatures.length;

  await page.goto('/v2/dm');
  await page.getByRole('navigation', { name: 'Herramientas del DM' }).getByRole('link', { name: 'Homebrew' }).click();
  await expect(page).toHaveURL('/v2/dm/homebrew');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Homebrew');
  await expect(page.getByText(t.dmHomebrewCount(total))).toBeVisible();

  // Cada categoría cuenta solo lo propio: el catálogo oficial no suma.
  await expect(page.locator('[data-category="weapons"]')).toContainText(String(content.weapons.length));
  await expect(page.locator('[data-category="feats"]')).toContainText(String(content.feats[0]!.name));
  await expect(page.locator('[data-category="armor"]')).toContainText(t.dmHomebrewNothingYet);

  // Una categoría es la lista y la ficha del Códice, con las URL del Modo DM.
  await page.locator('[data-category="weapons"]').click();
  await expect(page).toHaveURL('/v2/dm/homebrew/armas');
  await expect(page.locator('[data-field="codex-list"] [data-entry]')).toHaveCount(content.weapons.length);
  await page.locator(`[data-entry="${hacha.id}"]`).click();
  await expect(page).toHaveURL(`/v2/dm/homebrew/armas/${hacha.id}`);
  const detalle = page.locator('[data-field="codex-detail"]');
  await expect(detalle.getByRole('heading', { level: 2 })).toHaveText(String(hacha.name));
  await expect(detalle).toContainText('Propio');

  // La búsqueda de la portada mira todas las categorías; una criatura abre su
  // perfil en el Bestiario del DM.
  await page.goto('/v2/dm/homebrew');
  await page.getByRole('searchbox', { name: t.dmHomebrewSearch }).fill('HUMO');
  await expect(page.locator('[data-entry]')).toHaveCount(total);
  await page.locator(`[data-entry="${sombra.id}"]`).click();
  await expect(page).toHaveURL(`/v2/dm/bestiario/${sombra.id}`);

  expect(escrituras).toEqual([]);
});

test('el Homebrew es de la cuenta: otra cuenta no ve nada de lo ajeno, ni por URL', async ({ context, page, baseURL }) => {
  const { content } = await api<{ content: Propio }>(page.request, '/api/homebrew');
  const hacha = content.weapons[0]!;
  const ajeno = JSON.stringify(await api<unknown>(page.request, '/api/homebrew', TOKEN_DM));
  for (const id of [hacha.id, content.feats[0]!.id, content.creatures[0]!.id]) expect(ajeno).not.toContain(String(id));

  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  await page.goto('/v2/dm/homebrew');
  await expect(page.getByText(t.dmHomebrewEmpty)).toBeVisible();
  // La entrada ajena por su URL no se abre: la lista de esta cuenta no la tiene.
  await page.goto(`/v2/dm/homebrew/armas/${hacha.id}`);
  await expect(page.getByText(t.dmHomebrewEmptyIn(t.codexCategories.weapons))).toBeVisible();
  await expect(page.getByText(String(hacha.name))).toHaveCount(0);
});
