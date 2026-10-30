import { expect, test } from '@playwright/test';
import { mergeHomebrew, type HomebrewContent } from '../src/api/homebrew';
import { chapterGrants, computeSheet, inventoryOf, type AbilityId, type JsonObject } from '../src/engine';
import { signed } from '../src/sheet/format';
import { api, catalogo, personajes, TOKEN, type PersonajeApi } from './helpers';

// Mismos valores que `test/e2e_server.dart` en dnd_server.
const BRUNILDA = 'guerrero-de-humo';
const ALDRIC = 'aldric-de-humo';
const HACHA = 'hacha-de-humo';
const ELSBETH = 'elsbeth-de-humo';

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

test('la ficha de un lanzador lista sus trucos y conjuros, con la CD del motor', async ({ page, request }) => {
  const personaje = (await personajes(request)).find((c) => c.id === ELSBETH)! as PersonajeApi & {
    cantripIds: string[];
    spellIds: string[];
  };
  const catalog = catalogo();
  const ficha = computeSheet(personaje, catalog);
  const nombre = (id: string) => catalog.spells.find((s) => s.id === id)!.name as string;

  await page.goto(`/v2/personajes/${ELSBETH}/combate`);
  await expect(page.locator('[data-stat="spell-dc"] [data-field="value"]')).toHaveText(
    String(ficha.spellcasting!.saveDc),
  );
  // Lo elegido aparece, cada uno en su grupo: era lo que faltaba (la tarjeta
  // mostraba CD, espacios y reacciones, pero no los conjuros).
  const grupo = (id: string) => page.locator(`[data-spell-group="${id}"]`);
  for (const id of personaje.cantripIds) await expect(grupo('cantrips')).toContainText(nombre(id));
  // Lo que el motor da por siempre preparado (el dominio del clérigo) va en su
  // grupo y no se repite entre los elegidos.
  const siempre = new Set(ficha.alwaysPreparedSpellIds);
  expect(siempre.size).toBeGreaterThan(0);
  for (const id of siempre) await expect(grupo('always')).toContainText(nombre(id));
  for (const id of personaje.spellIds) {
    if (siempre.has(id)) await expect(grupo('chosen')).not.toContainText(nombre(id));
    else await expect(grupo('chosen')).toContainText(nombre(id));
  }
});

test('imprimir arma la hoja con los números del motor, que solo se ve en papel y se va al cerrar el diálogo', async ({
  page,
  request,
}) => {
  const personaje = (await personajes(request)).find((c) => c.id === ELSBETH)! as PersonajeApi & { cantripIds: string[] };
  const catalog = catalogo();
  const ficha = computeSheet(personaje, catalog);
  // El diálogo del navegador no se abre en la prueba: se cuenta la llamada.
  await page.addInitScript(() => {
    const w = window as unknown as { impresiones: number };
    w.impresiones = 0;
    window.print = () => void w.impresiones++;
  });

  await page.goto(`/v2/personajes/${ELSBETH}/personaje`);
  await page.getByRole('button', { name: 'Imprimir ficha' }).click();
  expect(await page.evaluate(() => (window as unknown as { impresiones: number }).impresiones)).toBe(1);
  const hoja = page.locator('.print-sheet');
  // En pantalla no se ve; en papel se ve ella sola.
  await expect(hoja).toBeHidden();
  await page.emulateMedia({ media: 'print' });
  await expect(hoja).toBeVisible();
  await expect(page.locator('#root')).toBeHidden();
  await expect(hoja.getByRole('heading', { level: 1 })).toHaveText(personaje.name);
  // Los PG actuales van en blanco, con el máximo del motor al lado.
  await expect(hoja.locator('[data-stat="hp"] b')).toHaveText(`/ ${ficha.maxHp}`);
  await expect(hoja.locator('[data-stat="ac"] b')).toHaveText(String(ficha.armorClass));
  await expect(hoja.locator('[data-stat="passive"] b')).toHaveText(String(ficha.passivePerception));
  for (const id of personaje.cantripIds) {
    await expect(hoja).toContainText(catalog.spells.find((s) => s.id === id)!.name as string);
  }

  await page.evaluate(() => window.dispatchEvent(new Event('afterprint')));
  await expect(hoja).toHaveCount(0);
});

test('el inventario muestra la mochila que resuelve el motor, con la carga de la ficha', async ({
  page,
  request,
}) => {
  const personaje = (await personajes(request)).find((c) => c.id === ELSBETH)!;
  const catalog = catalogo();
  const ficha = computeSheet(personaje, catalog);
  const lineas = inventoryOf(personaje, catalog);
  const libras = new Intl.NumberFormat('es-AR', { maximumFractionDigits: 2 });

  await page.goto(`/v2/personajes/${ELSBETH}/inventario`);
  await expect(page.locator('[data-stat="load"] [data-field="value"]')).toHaveText(
    `${libras.format(ficha.carriedWeight)} / ${libras.format(ficha.carryingCapacity)} lb`,
  );
  // Cada entrada con el nombre que resuelve el motor y su marca de equipado.
  // La ficha es propia, así que lo que se equipa es una casilla.
  for (const l of lineas) {
    const fila = page.locator(`[data-entry="${l.entryId}"]`);
    const marca = fila.locator('[data-field="equipped"]');
    await expect(fila.locator('[data-field="name"]')).toHaveText(l.name);
    if (l.equippable) await expect(marca.getByRole('checkbox')).toBeChecked({ checked: l.equipped });
    else await expect(marca).toHaveText(l.equipped ? 'Sí' : '—No se equipa');
  }
  // Filtrar no escribe nada: solo deja a la vista lo equipado.
  await page.getByRole('button', { name: 'Equipados' }).click();
  await expect(page.locator('[data-entry]')).toHaveCount(lineas.filter((l) => l.equipped).length);
});

test('la campaña muestra la mesa, sus batallas y lo que repartió cada capítulo cerrado', async ({
  page,
  request,
}) => {
  const [mesa] = await api<{ campaigns: { campaign: { name: string }; chapters: JsonObject[] }[] }>(
    request,
    `/api/characters/${ELSBETH}/campaigns`,
  ).then((r) => r.campaigns);

  await page.goto(`/v2/personajes/${ELSBETH}/campana`);
  await expect(page.getByRole('heading', { level: 2, name: mesa!.campaign.name })).toBeVisible();
  // Lo repartido lo nombra el motor (`Chapter.grantsLabel`).
  for (const capitulo of mesa!.chapters) {
    await expect(page.locator(`[data-chapter="${capitulo.id}"]`)).toContainText(
      `Te llevaste ${chapterGrants(capitulo)}`,
    );
  }
  await expect(page.getByText('Contra Lobo ×3')).toBeVisible();
  await expect(page.getByText('Con Thalion · cayeron todos')).toBeVisible();
});

test('el diario muestra el trasfondo y abre cada entrada', async ({
  page,
}) => {
  await page.goto(`/v2/personajes/${ELSBETH}/diario`);
  // El Markdown del trasfondo se arma como elementos, no como HTML.
  await expect(page.locator('[data-card="background"] strong')).toHaveText('no se quemó por accidente');
  await page.locator('[data-entry="d-mapa"]').click();
  const dialogo = page.getByRole('dialog', { name: 'Mapa de la Marca' });
  await expect(dialogo.getByRole('link')).toHaveAttribute('href', 'https://example.org/marca');
  await dialogo.getByRole('button', { name: 'Cerrar' }).click();
  await expect(dialogo).toHaveCount(0);
});
