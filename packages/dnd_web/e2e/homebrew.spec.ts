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

test('el DM crea una dote propia con un efecto, la lee en su detalle y la borra', async ({ context, page, baseURL }) => {
  const nombre = `Mano firme ${Date.now().toString(36)}`;
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_TRANSFERENCIA, url: baseURL! }]);
  await page.goto('/v2/dm/homebrew/dotes');
  await page.getByRole('link', { name: t.hbNewFeat, exact: true }).first().click();

  await page.locator('[data-field="feat-name"]').fill(nombre);
  // El primer tipo del diálogo arranca en «+1 Fuerza»: su frase es estable y no
  // hace falta abrir ningún desplegable.
  await page.locator('[data-action="effect-add"]').click();
  await page.getByRole('dialog', { name: t.effAdd }).getByRole('button', { name: t.effConfirm, exact: true }).click();
  await page.locator('[data-action="feat-save"]').click();

  await expect(page.getByText(t.hbSaved(nombre), { exact: true }).first()).toBeVisible();
  // Sin descripción ni rasgo, el Códice muestra el efecto descripto.
  await expect(page.getByText('+1 FUE', { exact: true })).toBeVisible();

  await page.getByRole('button', { name: t.hbDeleteTooltip(nombre), exact: true }).click();
  const borrar = page.getByRole('dialog', { name: t.hbDeleteTitle(t.hbDeleteKinds.feats, nombre) });
  await borrar.getByRole('button', { name: t.cardDelete, exact: true }).click();
  await expect(page.getByText(t.hbDeleted(nombre), { exact: true }).first()).toBeVisible();
  const { content } = await api<{ content: { feats: { name: string }[] } }>(page.request, '/api/homebrew', TOKEN_TRANSFERENCIA);
  expect(content.feats.map((f) => f.name)).not.toContain(nombre);
});

test('el DM crea un trasfondo propio con tres características, lo lee en su detalle y lo borra', async ({ context, page, baseURL }) => {
  const nombre = `Contrabandista ${Date.now().toString(36)}`;
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_TRANSFERENCIA, url: baseURL! }]);
  await page.goto('/v2/dm/homebrew/trasfondos');
  await page.getByRole('link', { name: t.hbNewBackground, exact: true }).first().click();

  await page.locator('[data-field="background-name"]').fill(nombre);
  for (const ability of ['FUE', 'DES', 'CON']) await page.getByRole('button', { name: ability, exact: true }).click();
  // Con tres marcadas, las demás quedan apagadas.
  await expect(page.getByRole('button', { name: 'INT', exact: true })).toHaveAttribute('aria-disabled', 'true');
  await page.locator('[data-action="background-save"]').click();

  await expect(page.getByText(t.hbSaved(nombre), { exact: true }).first()).toBeVisible();
  await expect(page.getByText('FUE · DES · CON', { exact: true }).first()).toBeVisible();

  await page.getByRole('button', { name: t.hbDeleteTooltip(nombre), exact: true }).click();
  const borrar = page.getByRole('dialog', { name: t.hbDeleteTitle(t.hbDeleteKinds.backgrounds, nombre) });
  await borrar.getByRole('button', { name: t.cardDelete, exact: true }).click();
  await expect(page.getByText(t.hbDeleted(nombre), { exact: true }).first()).toBeVisible();
  const { content } = await api<{ content: { backgrounds: { name: string }[] } }>(page.request, '/api/homebrew', TOKEN_TRANSFERENCIA);
  expect(content.backgrounds.map((b) => b.name)).not.toContain(nombre);
});
