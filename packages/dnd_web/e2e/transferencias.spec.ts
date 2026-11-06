import { readFile } from 'node:fs/promises';
import { expect, test } from '@playwright/test';
import { textsFor } from '../src/i18n/texts';
import { TOKEN } from './helpers';

test.use({ locale: 'es-AR' });

test('descarga un personaje e importa el ZIP en otra cuenta con su retrato', async ({ context, page, baseURL }) => {
  const t = textsFor('es');
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  await page.goto('/v2/personajes');
  const name = 'Elsbeth de Humo';
  await page.getByRole('button', { name: t.cardActionsTooltip(name), exact: true }).click();
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('menuitem', { name: t.transferExportCharacter }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toMatch(/^Elsbeth_de_Humo-.*\.zip$/);
  const buffer = await readFile((await download.path())!);

  await context.addCookies([{ name: 'dnd_session', value: 'sesion-de-transferencia=', url: baseURL! }]);
  await page.reload();
  await page.getByRole('button', { name: t.transferTitle, exact: true }).click();
  await page.getByRole('menuitem', { name: t.transferImport }).click();
  const dialog = page.getByRole('dialog', { name: t.transferImport });
  const input = dialog.getByLabel(t.transferFile);
  const submit = dialog.getByRole('button', { name: t.transferConfirm, exact: true });
  await input.setInputFiles({ name: 'invalido.zip', mimeType: 'application/zip', buffer: Buffer.from('no es un zip') });
  await submit.click();
  await expect(dialog.getByRole('alert')).toHaveText(t.transferInvalid);

  await input.setInputFiles({ name: download.suggestedFilename(), mimeType: 'application/zip', buffer });
  await submit.click();
  await expect(dialog).toHaveCount(0);
  await expect(page.getByText(t.transferImported(1, 1), { exact: true }).first()).toBeVisible();
  await expect(page.getByRole('link', { name, exact: true })).toBeVisible();

  await page.getByRole('button', { name: t.transferTitle, exact: true }).click();
  const backupPromise = page.waitForEvent('download');
  await page.getByRole('menuitem', { name: t.transferExportBackup }).click();
  expect((await backupPromise).suggestedFilename()).toMatch(/^backup-.*\.zip$/);
});
