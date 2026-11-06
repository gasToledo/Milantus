import { expect, test } from '@playwright/test';
import { textsFor } from '../src/i18n/texts';
import { TOKEN_DM } from './helpers';

test.use({ locale: 'es-AR' });

test('Ajustes guarda en la cuenta y el modo de inicio respeta la navegación', async ({ context, page, baseURL }) => {
  const t = textsFor('es');
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  let settings: Record<string, unknown> = { imageProvider: 'pollinations', sortMode: 'name' };
  let rejectSave = true;
  await page.route('**/api/settings', async (route) => {
    if (route.request().method() === 'PUT') {
      if (rejectSave) {
        rejectSave = false;
        return route.fulfill({ status: 500 });
      }
      settings = route.request().postDataJSON();
    }
    await route.fulfill({ json: { settings } });
  });

  await page.goto('/v2/');
  await expect(page).toHaveURL('/v2/personajes');
  await page.getByRole('link', { name: t.settings, exact: true }).click();
  const difficulty = page.getByRole('switch', { name: t.settingsShowEncounterDifficulty });
  await expect(difficulty).toBeChecked();
  await difficulty.click();
  await expect(page.getByRole('alert')).toHaveText(t.settingsSaveError);
  await expect(difficulty).toBeChecked();
  await difficulty.click();
  await expect(difficulty).not.toBeChecked();

  await page.getByRole('combobox', { name: t.settingsAccountTheme }).click();
  await page.getByRole('option', { name: t.themeModes.light }).click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await page.getByRole('combobox', { name: t.settingsStartMode }).click();
  await page.getByRole('option', { name: t.settingsStartModes.dm }).click();
  await expect(page.getByRole('status').filter({ hasText: t.settingsSaved })).toBeVisible();
  expect(settings).toEqual({
    imageProvider: 'pollinations', sortMode: 'name', showEncounterDifficulty: false, themeMode: 'light', startsInDmMode: true,
  });

  await page.goBack();
  await expect(page).toHaveURL('/v2/personajes');
  await page.goto('/v2/');
  await expect(page).toHaveURL(/\/v2\/dm(?:\/|$)/);
  await page.goto('/v2/personajes');
  await expect(page).toHaveURL('/v2/personajes');
});
