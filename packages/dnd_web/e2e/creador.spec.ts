import { expect, test } from '@playwright/test';
import { computeSheet, creationView, formatAmount, type CreationAction, type CreationDraftJson } from '../src/engine';
import { textsFor } from '../src/i18n/texts';
import { catalogo, TOKEN, vigilarEscrituras } from './helpers';

test.use({ locale: 'es-AR' });

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
});

test('de Especie a Equipo: cada paso frena hasta completarse y nada se guarda', async ({ page }) => {
  const catalog = catalogo();
  let draft: CreationDraftJson = {};
  // Lo que el motor da para los mismos toques: lo que la página tiene que mostrar.
  const motor = (...acciones: CreationAction[]) => {
    for (const a of acciones) draft = creationView(catalog, draft, a).draft;
    return creationView(catalog, draft);
  };

  const escrituras = vigilarEscrituras(page);
  const opcion = (id: string) => page.locator(`[data-option="${id}"]`);
  const seguir = page.getByRole('button', { name: 'Continuar', exact: true });
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

  // Clase: lo elegido sigue a la vista, para leerlo a la derecha.
  await expect(seguir).toBeDisabled();
  await opcion('fighter').click();
  await opcion('fs-defense').click();
  await expect(opcion('fs-defense')).toBeVisible();
  await expect(detalle).toContainText('Defensa');
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
  let vista = motor(
    { type: 'selectRace', id: 'elf' },
    { type: 'selectLineage', id: 'elf-high' },
    { type: 'setSpeciesAbility', ability: 'intelligence' },
    { type: 'selectClass', id: 'fighter' },
    { type: 'toggle', pick: 'feature', id: 'fs-defense', group: 'fighting-style' },
    { type: 'toggle', pick: 'weaponMastery', id: 'longsword' },
    { type: 'toggle', pick: 'weaponMastery', id: 'greatsword' },
    { type: 'toggle', pick: 'weaponMastery', id: 'dagger' },
    { type: 'selectBackground', id: 'sage' },
    { type: 'setOriginFeatAbility', ability: 'intelligence' },
    { type: 'setSpread', plusTwo: 'intelligence', plusOne: 'constitution' },
    { type: 'applySuggestedScores' },
  );
  // Una columna por dado, aunque la tirada repita un valor.
  await opcion('roll4d6').click();
  await expect(page.locator('[data-ability="strength"] [role="radio"]')).toHaveCount(6);
  await opcion('standardArray').click();
  await page.locator('[data-ability="strength"] [data-value="8"]').click();
  await expect(page.locator('[data-ability="strength"] [role="radio"][aria-checked="true"]')).toHaveText('8');
  await page.getByRole('button', { name: /^Usar lo sugerido/ }).click();
  await expect(page.locator('[data-field="score-intelligence"]')).toContainText(String(vista.scores.preview.intelligence));
  await expect(page.locator('[data-field="creation-after"]')).toContainText(
    String(computeSheet(vista.character, catalog).maxHp),
  );
  await seguir.click();

  // Competencias: lo tomado en un origen se apaga en el otro.
  await expect(seguir).toBeDisabled();
  const especie = vista.proficiencies.speciesSkills.options[0]!.id;
  await opcion(`species-${especie}`).click();
  await expect(opcion(`class-${especie}`)).toBeDisabled();
  vista = motor({ type: 'toggle', pick: 'speciesSkill', id: especie });
  const libres = vista.proficiencies.classSkills.options.filter((o) => !o.taken);
  const idiomas = vista.proficiencies.languages.options.slice(0, 2);
  for (const o of libres.slice(0, vista.proficiencies.classSkills.count)) {
    await opcion(`class-${o.id}`).click();
    await expect(detalle).toContainText(o.label);
    vista = motor({ type: 'toggle', pick: 'classSkill', id: o.id });
  }
  await expect(seguir).toBeDisabled();
  for (const l of idiomas) {
    await opcion(`lang-${l.id}`).click();
    vista = motor({ type: 'toggle', pick: 'language', id: l.id });
  }
  await seguir.click();

  // Conjuros: un Guerrero no lanza, pero la dote del Erudito le da un cupo.
  await expect(page.getByRole('navigation', { name: 'Pasos' }).getByRole('button', { name: 'Conjuros' })).toBeVisible();
  await expect(seguir).toBeDisabled();
  for (const cupo of vista.spells.slots) {
    for (const o of cupo.options.slice(0, cupo.count)) {
      await opcion(o.id).first().click();
      vista = motor({ type: 'toggle', pick: 'featureSpell', id: o.id, group: cupo.groupId });
    }
  }
  await seguir.click();

  // Equipo: lo comprado sale del oro de las opciones.
  await expect(seguir).toBeDisabled();
  const clase = vista.equipment.classOptions[0]!.id;
  const oro = vista.equipment.backgroundOptions.find((o) => Object.keys(o.coins).length > 0 && o.items.length === 0)!.id;
  await opcion(`class-pack-${clase}`).click();
  await opcion(`background-pack-${oro}`).click();
  vista = motor({ type: 'setClassEquipment', id: clase }, { type: 'setBackgroundEquipment', id: oro });
  for (const c of vista.equipment.choices) {
    await opcion(`choice-${c.options[0]!.id}`).click();
    vista = motor({ type: 'setEquipmentChoice', key: c.key, id: c.options[0]!.id });
  }
  await page.getByRole('button', { name: 'Comprar del catálogo' }).click();
  await page.getByRole('searchbox', { name: 'Buscar objeto…' }).fill('antorcha');
  await page.locator('[data-item="torch"]').getByRole('button').last().click();
  vista = motor({ type: 'buy', id: 'torch' });
  await page.getByRole('button', { name: 'Listo, volver al equipo' }).click();
  await expect(page.locator('[data-field="purchases"] [data-item="torch"]')).toBeVisible();
  const monedas = Object.fromEntries(Object.entries(textsFor('es').coins).map(([k, v]) => [k, v.abbr]));
  await expect(page.locator('[data-field="gold-left"]')).toContainText(formatAmount(vista.equipment.goldLeftCp, monedas));

  // ponytail: hasta acá llega 5d3; cuando estén Detalles y Revisión, esto sigue.
  await expect(page.locator('[data-page="creation"] footer [role="status"]')).toBeVisible();
  await expect(seguir).toBeDisabled();
  expect(escrituras).toEqual([]);
});
