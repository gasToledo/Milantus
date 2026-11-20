import { expect, test } from '@playwright/test';
import { api, TOKEN_DM, vigilarEscrituras, type PersonajeApi } from './helpers';

test.use({ locale: 'es-AR' });

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

  await page.goto(`/dm/campanas/marca-del-cuervo/mesa/${sagan.memberId}/combate`);
  await expect(page.locator('[data-card="hit-points"]')).toBeVisible();
  await expect(page.locator('[data-controls]')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Daño' })).toHaveCount(0);
  // Ni estados, ni cansancio, ni estados activables: nada que escriba.
  await expect(page.locator('[data-condition], [data-field="exhaustion"]')).toHaveCount(0);
  await expect(page.getByRole('button', { name: /^(Activar|Terminar)$/ })).toHaveCount(0);
  // Ni preparar conjuros ni cambiar el truco innato. La ficha de un miembro
  // no tiene pestaña Inventario (`MEMBER_SHEET_TABS`), así que el arma de
  // pacto y los planos (`target-*`, `magic-plans`) no tienen dónde aparecer.
  await expect(page.locator('[data-action="edit-spells"], [data-action="swap-innate"]')).toHaveCount(0);
  expect(escrituras).toEqual([]);
});
