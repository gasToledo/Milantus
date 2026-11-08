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

// La cuenta de `transferencias.spec.ts`: sin homebrew propio, y ninguna otra
// prueba cuenta su Bestiario, así que importar y borrar acá no mueve lo que
// miran las demás.
const TOKEN_TRANSFERENCIA = 'sesion-de-transferencia=';

test('el DM importa una criatura propia desde un archivo y la borra desde su perfil', async ({ context, page, baseURL }) => {
  const id = `hb-e2e-${Date.now().toString(36)}`;
  const nombre = `Lobo de ceniza ${id}`;
  const archivo = JSON.stringify({
    type: 'dnd_homebrew',
    formatVersion: 1,
    content: { creatures: [{ id, name: nombre, source: 'homebrew', ac: '13', hp: '11' }] },
  });
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_TRANSFERENCIA, url: baseURL! }]);
  await page.goto('/v2/dm/homebrew');

  // Importar: elegir el archivo muestra qué trae, y recién «Importar» escribe.
  await page.locator('[data-field="homebrew-import-file"]').setInputFiles({
    name: 'homebrew.json',
    mimeType: 'application/json',
    buffer: Buffer.from(archivo),
  });
  const importar = page.getByRole('dialog', { name: t.hbImportTitle });
  await expect(importar.getByText(nombre)).toBeVisible();
  await importar.getByRole('button', { name: t.transferConfirm, exact: true }).click();
  await expect(page.getByText(t.hbImported(1), { exact: true })).toBeVisible();

  // Está en Homebrew › Criaturas, y su perfil (el del Bestiario) trae «Borrar».
  await page.locator('[data-category="creatures"]').click();
  await page.locator(`[data-entry="${id}"]`).click();
  await page.getByRole('button', { name: t.hbDeleteTooltip(nombre), exact: true }).click();
  const borrar = page.getByRole('dialog', { name: t.hbDeleteTitle(t.hbDeleteKinds.creatures, nombre) });
  await expect(borrar.getByText(t.hbNoUsers)).toBeVisible();
  await borrar.getByRole('button', { name: t.cardDelete, exact: true }).click();

  await expect(page.getByText(t.hbDeleted(nombre), { exact: true })).toBeVisible();
  await expect(page.locator(`[data-entry="${id}"]`)).toHaveCount(0);
  const { content } = await api<{ content: { creatures: { id: string }[] } }>(page.request, '/api/homebrew', TOKEN_TRANSFERENCIA);
  expect(content.creatures.map((c) => c.id)).not.toContain(id);
});
