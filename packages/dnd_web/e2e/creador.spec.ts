import { expect, test } from '@playwright/test';
import { computeSheet, creationView, type CreationAction, type CreationDraftJson } from '../src/engine';
import { catalogo, TOKEN, vigilarEscrituras } from './helpers';

test.use({ locale: 'es-AR' });

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
});

test('de Especie a Características: cada paso frena hasta completarse y nada se guarda', async ({ page }) => {
  // Lo que el motor da para los mismos toques: lo que la página tiene que mostrar.
  const acciones: CreationAction[] = [
    { type: 'selectRace', id: 'elf' },
    { type: 'selectLineage', id: 'elf-high' },
    { type: 'setSpeciesAbility', ability: 'intelligence' },
    { type: 'selectClass', id: 'fighter' },
    { type: 'selectBackground', id: 'sage' },
    { type: 'setOriginFeatAbility', ability: 'intelligence' },
    { type: 'setSpread', plusTwo: 'intelligence', plusOne: 'constitution' },
    { type: 'applySuggestedScores' },
  ];
  const catalog = catalogo();
  const esperado = creationView(
    catalog,
    acciones.reduce<CreationDraftJson>((draft, a) => creationView(catalog, draft, a).draft, {}),
  );
  const ficha = computeSheet(esperado.character, catalog);

  const escrituras = vigilarEscrituras(page);
  const opcion = (id: string) => page.locator(`[data-option="${id}"]`);
  const seguir = page.getByRole('button', { name: 'Continuar' });
  const detalle = page.locator('[data-field="creation-detail"]');
  await page.goto('/v2/personajes/nuevo');

  // Especie: el linaje y su aptitud aparecen al elegir la especie.
  await expect(seguir).toBeDisabled();
  await page.getByRole('searchbox', { name: 'Buscar especie…' }).fill('elfo');
  await opcion('elf').click();
  await expect(detalle).toContainText('Elfo');
  await opcion('elf-high').click();
  await expect(seguir).toBeDisabled();
  await opcion('intelligence').click();
  await seguir.click();

  // Clase: lo resuelto se pliega y el paso abre en lo que falta.
  await expect(seguir).toBeDisabled();
  await opcion('fighter').click();
  await opcion('fs-defense').click();
  await expect(opcion('fs-defense')).toHaveCount(0);
  for (const arma of ['longsword', 'greatsword']) await opcion(arma).click();
  await expect(seguir).toBeDisabled();
  await opcion('dagger').click();
  await seguir.click();

  // Trasfondo: la dote pide aptitud y el +1 no puede ir donde está el +2.
  await expect(seguir).toBeDisabled();
  await opcion('sage').click();
  await opcion('intelligence').click();
  await opcion('two-intelligence').click();
  await expect(opcion('one-intelligence')).toBeDisabled();
  await opcion('one-constitution').click();
  await seguir.click();

  // Características: el reparto sugerido y los totales del motor.
  await page.getByRole('button', { name: /^Usar lo sugerido/ }).click();
  await expect(page.locator('[data-field="score-intelligence"]')).toContainText(String(esperado.scores.preview.intelligence));
  await expect(page.locator('[data-field="creation-after"]')).toContainText(String(ficha.maxHp));

  // ponytail: hasta acá llega 5d2; cuando estén los otros pasos, esto sigue.
  await expect(seguir).toBeDisabled();
  expect(escrituras).toEqual([]);
});
