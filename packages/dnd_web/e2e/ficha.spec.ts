import { expect, test } from '@playwright/test';
import { mergeHomebrew, type HomebrewContent } from '../src/api/homebrew';
import { computeSheet, type AbilityId } from '../src/engine';
import { signed } from '../src/sheet/format';
import { api, catalogo, personajes, TOKEN } from './helpers';

// Mismos valores que `test/e2e_server.dart` en dnd_server.
const BRUNILDA = 'guerrero-de-humo';
const ALDRIC = 'aldric-de-humo';
const HACHA = 'hacha-de-humo';

// Español fijo: sin esto el idioma sería el del navegador de CI (en-US).
test.use({ locale: 'es-AR' });

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
});

test('la ficha muestra los números que da el motor para el personaje sembrado', async ({ page, request }) => {
  // Lo esperado sale del motor, no de una transcripción: el mismo personaje
  // que sirve la API, calculado con el mismo dart2js que corre el navegador.
  const personaje = (await personajes(request)).find((c) => c.id === BRUNILDA)!;
  const ficha = computeSheet(personaje, catalogo());

  // La ruta sin pestaña es la de Personaje.
  await page.goto(`/v2/personajes/${BRUNILDA}`);
  await expect(page).toHaveURL(`/v2/personajes/${BRUNILDA}/personaje`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Brunilda de Humo');

  const cifra = (id: string) => page.locator(`[data-stat="${id}"] [data-field="value"]`);
  await expect(cifra('hp')).toHaveText(String(personaje.combat.currentHp));
  await expect(page.locator('[data-stat="hp"] dd')).toContainText(`/ ${ficha.maxHp}`);
  await expect(cifra('ac')).toHaveText(String(ficha.armorClass));
  await expect(cifra('initiative')).toHaveText(signed(ficha.initiative));
  await expect(cifra('proficiency')).toHaveText(signed(ficha.proficiencyBonus));
  // La percepción pasiva no va en la banda táctica sino con las habilidades.
  await expect(page.locator('section[aria-label="Cifras de combate"] [data-stat="passive-perception"]')).toHaveCount(0);
  await expect(cifra('passive-perception')).toHaveText(String(ficha.passivePerception));

  for (const ab of Object.keys(ficha.abilityModifiers) as AbilityId[]) {
    const placa = page.locator(`[data-ability="${ab}"]`);
    await expect(placa.locator('[data-field="modifier"]')).toHaveText(signed(ficha.abilityModifiers[ab]!));
    await expect(placa.locator('[data-field="score"]')).toContainText(String(ficha.abilityScores[ab]));
  }
  for (const [skill, mod] of Object.entries(ficha.skillModifiers)) {
    await expect(page.locator(`[data-row="skill-${skill}"] [data-field="modifier"]`)).toHaveText(signed(mod));
  }
});

test('las pestañas Personaje y Combate son rutas propias y el historial vuelve entre ellas', async ({
  page,
  request,
}) => {
  const personaje = (await personajes(request)).find((c) => c.id === BRUNILDA)!;
  const ficha = computeSheet(personaje, catalogo());

  await page.goto(`/v2/personajes/${BRUNILDA}/personaje`);
  const panel = page.getByRole('navigation', { name: 'Secciones de la ficha' });
  await expect(panel.getByRole('link', { name: 'Personaje' })).toHaveAttribute('aria-current', 'page');

  await panel.getByRole('link', { name: 'Combate' }).click();
  await expect(page).toHaveURL(`/v2/personajes/${BRUNILDA}/combate`);
  await expect(panel.getByRole('link', { name: 'Combate' })).toHaveAttribute('aria-current', 'page');
  await expect(page.getByRole('heading', { level: 2, name: 'Salvaciones' })).toBeVisible();
  for (const [ab, mod] of Object.entries(ficha.savingThrows)) {
    await expect(page.locator(`[data-row="save-${ab}"] [data-field="modifier"]`)).toHaveText(signed(mod));
  }
  await expect(page.getByRole('heading', { level: 2, name: 'Habilidades' })).toHaveCount(0);

  // Una URL de pestaña se abre directa (recarga) y «atrás» vuelve.
  await page.reload();
  await expect(page.getByRole('heading', { level: 2, name: 'Salvaciones' })).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(`/v2/personajes/${BRUNILDA}/personaje`);
  await expect(page.getByRole('heading', { level: 2, name: 'Habilidades' })).toBeVisible();

  // Una pestaña que no existe no es la ficha.
  await page.goto(`/v2/personajes/${BRUNILDA}/inexistente`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Página no encontrada');
});

test('el ataque de un arma homebrew aparece, con el bonificador del motor sobre el catálogo fusionado', async ({
  page,
  request,
}) => {
  const personaje = (await personajes(request)).find((c) => c.id === ALDRIC)!;
  const { content } = await api<{ content: HomebrewContent }>(request, '/api/homebrew');
  const oficial = catalogo();
  const ficha = computeSheet(personaje, mergeHomebrew(oficial, content));
  const ataque = ficha.attacks.find((a) => a.weaponId === HACHA);
  // Sin la fusión el motor no conoce el arma: es lo que esta prueba protege.
  expect(ataque).toBeDefined();
  expect(computeSheet(personaje, oficial).attacks.some((a) => a.weaponId === HACHA)).toBe(false);

  await page.goto(`/v2/personajes/${ALDRIC}/combate`);
  const fila = page.locator(`[data-attack="${HACHA}"]`);
  await expect(fila).toContainText('Hacha de Humo');
  await expect(fila.locator('[data-field="attack-bonus"] [aria-hidden="true"]')).toHaveText(signed(ataque!.attackBonus));
});
