import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { expect, test } from '@playwright/test';
import { computeSheet, type AbilityId, type Catalog, type JsonObject } from '../src/engine';
import { signed } from '../src/sheet/format';

// Mismos valores que `test/e2e_server.dart` en dnd_server.
const TOKEN = 'sesion-de-humo=';
const PERSONAJE = 'guerrero-de-humo';

const catalogo = (): Catalog => {
  const dir = fileURLToPath(new URL('../../dnd_engine/lib/assets/srd_2024/', import.meta.url));
  const leer = (n: string) => JSON.parse(readFileSync(dir + `${n}.json`, 'utf8')) as JsonObject[];
  return {
    races: leer('races'),
    classes: leer('classes'),
    subclasses: leer('subclasses'),
    lineages: leer('lineages'),
    backgrounds: leer('backgrounds'),
    feats: leer('feats'),
    weapons: leer('weapons'),
    armor: leer('armor'),
    items: [...leer('items'), ...leer('magic_items'), ...leer('efa_magic_items')],
    spells: leer('spells'),
    creatures: leer('creatures'),
  };
};

// Español fijo: sin esto el idioma sería el del navegador de CI (en-US).
test.use({ locale: 'es-AR' });

test('la ficha muestra los números que da el motor para el personaje sembrado', async ({
  context,
  page,
  request,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);

  // Lo esperado sale del motor, no de una transcripción: el mismo personaje
  // que sirve la API, calculado con el mismo dart2js que corre el navegador.
  const respuesta = await request.get('/api/characters', {
    headers: { cookie: `dnd_session=${TOKEN}` },
  });
  const { characters } = (await respuesta.json()) as {
    characters: { character: JsonObject & { combat: { currentHp: number } } }[];
  };
  const personaje = characters.find((c) => c.character.id === PERSONAJE)!.character;
  const ficha = computeSheet(personaje, catalogo());

  await page.goto(`/v2/personajes/${PERSONAJE}`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Brunilda de Humo');

  const cifra = (id: string) => page.locator(`[data-stat="${id}"] dd`);
  await expect(cifra('hp')).toHaveText(`${personaje.combat.currentHp} / ${ficha.maxHp}`);
  await expect(cifra('ac')).toHaveText(String(ficha.armorClass));
  await expect(cifra('initiative')).toHaveText(signed(ficha.initiative));
  await expect(cifra('proficiency')).toHaveText(signed(ficha.proficiencyBonus));
  await expect(cifra('passive-perception')).toHaveText(String(ficha.passivePerception));

  for (const ab of Object.keys(ficha.abilityModifiers) as AbilityId[]) {
    const placa = page.locator(`[data-ability="${ab}"]`);
    await expect(placa.locator('[data-field="modifier"]')).toHaveText(
      signed(ficha.abilityModifiers[ab]!),
    );
    await expect(placa.locator('[data-field="score"]')).toContainText(
      String(ficha.abilityScores[ab]),
    );
  }
  for (const [skill, mod] of Object.entries(ficha.skillModifiers)) {
    await expect(
      page.locator(`[data-row="skill-${skill}"] [data-field="modifier"]`),
    ).toHaveText(signed(mod));
  }
});
