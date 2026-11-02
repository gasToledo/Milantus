import { expect, test } from '@playwright/test';
import { bestiary, type JsonObject } from '../src/engine';
import { textsFor } from '../src/i18n/texts';
import { api, catalogo, TOKEN_DM } from './helpers';

test.use({ locale: 'es-AR' });

const t = textsFor('es');

type Propio = { weapons: JsonObject[]; feats: JsonObject[]; creatures: JsonObject[] };

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
  // En el Bestiario, solo el catálogo oficial: la criatura propia no está.
  await page.goto('/v2/dm/bestiario');
  await expect(page.locator('[data-field="bestiary-list"] [data-entry]')).toHaveCount(bestiary(catalogo()).length);
  await expect(page.locator(`[data-entry="${content.creatures[0]!.id}"]`)).toHaveCount(0);
});
