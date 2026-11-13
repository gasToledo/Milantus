import { expect, test } from '@playwright/test';
import { textsFor } from '../src/i18n/texts';
import { TOKEN } from './helpers';

// Español fijo: sin esto el idioma sería el del navegador de CI (en-US).
test.use({ locale: 'es-AR' });

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
});

test('una ronda de reglas muestra una pregunta y traba la respuesta', async ({ page }) => {
  const t = textsFor('es');
  await page.goto('/v2/quiz');
  // La primera vez sale el tutorial, después del primer render. Saltarlo es lo
  // que hace quien ya lo vio; si no aparece, la ronda sigue igual.
  const skip = page.getByRole('button', { name: t.tutSkipAll, exact: true });
  const tutorial = await skip.waitFor({ state: 'visible', timeout: 3000 }).then(() => true).catch(() => false);
  if (tutorial) await skip.click();
  await page.locator('[data-quiz-target="reglas"]').click();
  await expect(page.locator('[data-quiz="question"]')).toBeVisible();
  const option = page.locator('[data-option="A"]');
  await option.click();
  await expect(option).toBeDisabled();
  await expect(page.locator('[data-action="quiz-next"]')).toBeVisible();
});
