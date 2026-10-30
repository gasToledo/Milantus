import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import { actOn, computeSheet, migrateCharacter, type CharacterJson, type SheetAction } from '../src/engine';
import { api, catalogo, TOKEN_DM, TOKEN_ESCRITURA, vigilarEscrituras, type PersonajeApi } from './helpers';

// La ficha que escriben estas pruebas es de una cuenta propia (`e2e_server.dart`):
// lo que guardan no cambia los números que leen las otras pruebas.
const ILSE = 'ilse-de-humo';
const COMBATE = `/v2/personajes/${ILSE}/combate`;
const PUT_ILSE = `PUT /api/characters/${ILSE}`;

test.use({ locale: 'es-AR' });
// Escriben la misma ficha: una después de otra, cada una partiendo de lo que
// dejó la anterior (que lee de la API, no de una constante).
test.describe.configure({ mode: 'serial' });

async function ilse(request: APIRequestContext): Promise<PersonajeApi> {
  const { characters } = await api<{ characters: { character: PersonajeApi }[] }>(
    request,
    '/api/characters',
    TOKEN_ESCRITURA,
  );
  return characters.map((c) => c.character).find((c) => c.id === ILSE)!;
}

/** Lo que el motor da para [acciones] en fila sobre [ficha]: lo que la página
 *  tiene que haber guardado. */
function segunMotor(ficha: CharacterJson, ...acciones: SheetAction[]): CharacterJson {
  return acciones.reduce((c, a) => actOn(c, catalogo(), a).character, ficha);
}

/** Espera a que la cola de guardado mande y devuelve lo que mandó. */
async function proximoGuardado(page: Page, accion: () => Promise<void>): Promise<CharacterJson> {
  const put = page.waitForRequest((r) => r.method() === 'PUT' && r.url().endsWith(`/api/characters/${ILSE}`));
  await accion();
  const enviado = (await put).postDataJSON() as { character: CharacterJson };
  await expect(page.locator('[data-save-state="saved"]')).toBeVisible();
  return enviado.character;
}

test.beforeEach(async ({ context, baseURL }) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_ESCRITURA, url: baseURL! }]);
});

test('daño, curación y PG temporales guardan la ficha que da el motor, y se relee igual', async ({ page, request }) => {
  const escrituras = vigilarEscrituras(page);
  await page.goto(COMBATE);
  const tarjeta = page.locator('[data-card="hit-points"]');
  await expect(page.locator('[data-save-state="saved"]')).toHaveText(/Guardado/);

  for (const [boton, accion] of [
    ['Daño', { type: 'damage', amount: 5 }],
    ['Curar', { type: 'heal', amount: 2 }],
    ['PG temp', { type: 'tempHp', amount: 4 }],
  ] as const) {
    const esperado = segunMotor(await ilse(request), accion);
    const enviado = await proximoGuardado(page, async () => {
      await page.getByLabel('Cantidad').fill(String(accion.amount));
      await tarjeta.getByRole('button', { name: boton }).click();
    });
    // Lo que viaja es la ficha del motor, entera y en el esquema actual, y es
    // lo que el servidor guardó.
    expect(enviado).toEqual(esperado);
    expect(await ilse(request)).toEqual(esperado);
  }

  // Legible: el motor la vuelve a leer sin migrar nada, y al recargar la
  // pantalla muestra lo guardado.
  const guardada = await ilse(request);
  expect(migrateCharacter(guardada)).toEqual(guardada);
  computeSheet(guardada, catalogo());
  await page.reload();
  await expect(tarjeta.locator('.num').first()).toHaveText(String(guardada.combat.currentHp));
  expect([...new Set(escrituras)]).toEqual([PUT_ILSE]);
});

test('a 0 PG se marcan las salvaciones de muerte y tres éxitos estabilizan', async ({ page, request }) => {
  const caida = segunMotor(await ilse(request), { type: 'damage', amount: 999 });
  await page.goto(COMBATE);
  const tarjeta = page.locator('[data-card="hit-points"]');
  await proximoGuardado(page, async () => {
    await page.getByLabel('Cantidad').fill('999');
    await tarjeta.getByRole('button', { name: 'Daño' }).click();
  });
  expect(await ilse(request)).toEqual(caida);

  const exito = { type: 'deathSave', success: true } as const;
  const estable = segunMotor(caida, exito, exito, exito);
  // Tres toques seguidos: la cola los junta y manda la última copia.
  for (let i = 0; i < 3; i++) await tarjeta.getByRole('button', { name: '+Éxito' }).click();
  await expect(page.getByText('¡Estabilizado!', { exact: true })).toBeVisible();
  await expect.poll(async () => (await ilse(request)).combat).toEqual((estable as PersonajeApi).combat);
});

test('la ficha de otra cuenta no tiene controles para escribir', async ({ context, page, baseURL }) => {
  await context.clearCookies();
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const { members } = await api<{ members: { memberId: string; character: PersonajeApi }[] }>(
    page.request,
    '/api/campaigns/marca-del-cuervo/members',
    TOKEN_DM,
  );
  const sagan = members.find((m) => m.character.id === 'sagan-de-humo')!;

  await page.goto(`/v2/dm/campanas/marca-del-cuervo/mesa/${sagan.memberId}/combate`);
  await expect(page.locator('[data-card="hit-points"]')).toBeVisible();
  await expect(page.locator('[data-controls]')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Daño' })).toHaveCount(0);
  expect(escrituras).toEqual([]);
});
