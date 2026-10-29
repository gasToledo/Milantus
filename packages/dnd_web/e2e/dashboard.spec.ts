import { expect, test } from '@playwright/test';
import { computeSheet } from '../src/engine';
import { signed } from '../src/sheet/format';
import { catalogo, personajes, TOKEN } from './helpers';

// Español fijo: sin esto el idioma sería el del navegador de CI (en-US).
test.use({ locale: 'es-AR' });

test('el dashboard lista los personajes en el orden de los ajustes, marca el favorito, filtra y muestra los números del motor', async ({
  context,
  page,
  request,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);

  // Lo esperado sale del motor y de la API, no de una transcripción. Las
  // cifras de la tarjeta (nivel, PG, CA, velocidad, iniciativa) no dependen
  // del arma homebrew de Aldric: alcanza con el catálogo oficial.
  const catalog = catalogo();
  const porId = new Map(
    (await personajes(request)).map((character) => [character.id, { character, ficha: computeSheet(character, catalog) }]),
  );

  await page.goto('/v2/');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Mis personajes');

  const tarjetas = page.locator('[data-field="roster"] > li');
  const ids = () => tarjetas.evaluateAll((els) => els.map((e) => e.getAttribute('data-character')));

  // Los ajustes sembrados piden orden «nivel» y a Zelda de favorita: la
  // favorita encabeza aunque tenga menos nivel que Brunilda, y el resto va de
  // más a menos nivel (el alfabético sería Aldric, Brunilda, Zelda).
  await expect(tarjetas).toHaveCount(3);
  expect(await ids()).toEqual(['zelda-de-humo', 'guerrero-de-humo', 'aldric-de-humo']);
  await expect(page.locator('[data-field="sort"]')).toHaveText('Nivel');

  await expect(tarjetas.nth(0)).toHaveAttribute('data-favorite', 'true');
  await expect(tarjetas.nth(0).getByRole('img', { name: 'Favorito' })).toBeVisible();
  await expect(tarjetas.nth(1)).toHaveAttribute('data-favorite', 'false');
  await expect(tarjetas.nth(2)).toHaveAttribute('data-favorite', 'false');

  // Los números de cada tarjeta son los del motor.
  for (const [id, { character, ficha }] of porId) {
    const tarjeta = page.locator(`[data-character="${id}"]`);
    const cifra = (stat: string) => tarjeta.locator(`[data-stat="${stat}"]`);
    await expect(cifra('level')).toHaveText(String(ficha.level));
    await expect(cifra('hp')).toHaveText(`${character.combat.currentHp} / ${ficha.maxHp}`);
    await expect(cifra('ac')).toHaveText(String(ficha.armorClass));
    await expect(cifra('speed')).toHaveText(`${ficha.speed} pies`);
    await expect(cifra('initiative')).toHaveText(signed(ficha.initiative));
    await expect(tarjeta.getByRole('link')).toHaveAttribute('href', `/v2/personajes/${id}/personaje`);
  }

  // El buscador filtra en el cliente; sin coincidencias no es la lista vacía.
  const buscador = page.getByRole('searchbox', { name: 'Buscar personajes' });
  await buscador.fill('brunilda');
  await expect(tarjetas).toHaveCount(1);
  expect(await ids()).toEqual(['guerrero-de-humo']);
  await buscador.fill('xyz');
  await expect(page.locator('[data-empty="no-match"]')).toBeVisible();
  await expect(page.locator('[data-empty="empty"]')).toHaveCount(0);
  await page.getByRole('button', { name: 'Limpiar búsqueda' }).first().click();
  await expect(tarjetas).toHaveCount(3);
});
