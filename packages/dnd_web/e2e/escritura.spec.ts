import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import {
  actOn,
  computeSheet,
  inventoryOf,
  levelUpView,
  migrateCharacter,
  type CharacterJson,
  type LevelUpDraft,
  type SheetAction,
} from '../src/engine';
import { resourceKey } from '../src/sheet/format';
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

async function ilse(request: APIRequestContext, id = ILSE): Promise<PersonajeApi> {
  const { characters } = await api<{ characters: { character: PersonajeApi }[] }>(
    request,
    '/api/characters',
    TOKEN_ESCRITURA,
  );
  return characters.map((c) => c.character).find((c) => c.id === id)!;
}

/** Lo que el motor da para [acciones] en fila sobre [ficha]: lo que la página
 *  tiene que haber guardado. */
function segunMotor(ficha: CharacterJson, ...acciones: SheetAction[]): CharacterJson {
  return acciones.reduce((c, a) => actOn(c, catalogo(), a).character, ficha);
}

/** Espera a que la cola de guardado mande y devuelve lo que mandó. */
async function proximoGuardado(page: Page, accion: () => Promise<void>, id = ILSE): Promise<CharacterJson> {
  const put = page.waitForRequest((r) => r.method() === 'PUT' && r.url().endsWith(`/api/characters/${id}`));
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

test('gastar y recuperar espacios y usos guarda lo que da el motor', async ({ page, request }) => {
  const ficha = computeSheet(await ilse(request), catalogo());
  const canalizar = ficha.resources.find((r) => r.id === 'channel_divinity')!;
  await page.goto(COMBATE);

  for (const [boton, accion] of [
    ['Gastar espacio de nivel 1', { type: 'spendSlot', level: 1, pact: false }],
    [`Usar ${canalizar.name}`, { type: 'spendResource', resource: resourceKey(canalizar) }],
    ['Recuperar espacio de nivel 1', { type: 'recoverSlot', level: 1, pact: false }],
  ] as const) {
    const esperado = segunMotor(await ilse(request), accion);
    const enviado = await proximoGuardado(page, () => page.getByRole('button', { name: boton }).click());
    expect(enviado).toEqual(esperado);
    expect(await ilse(request)).toEqual(esperado);
  }
});

test('el dado de golpe lo tira el motor: cura lo que dice el aviso y gasta uno', async ({ page, request }) => {
  const antes = await ilse(request);
  const { maxHp } = computeSheet(antes, catalogo());
  const gastados = (c: PersonajeApi) =>
    Object.values((c.combat as { hitDiceUsed?: Record<string, number> }).hitDiceUsed ?? {}).reduce((a, b) => a + b, 0);
  await page.goto(COMBATE);

  const enviado = (await proximoGuardado(page, () =>
    page.getByRole('button', { name: /^Dado de golpe/ }).click(),
  )) as PersonajeApi;
  const aviso = await page.getByText(/^Recuperaste \d+ PG/).textContent();
  const curado = Number(/\d+/.exec(aviso!)![0]);

  expect(gastados(enviado)).toBe(gastados(antes) + 1);
  expect(enviado.combat.currentHp).toBe(Math.min(maxHp, antes.combat.currentHp + curado));
  expect(await ilse(request)).toEqual(enviado);
});

test('el descanso corto guarda lo del motor y «Deshacer» vuelve a guardar la ficha de antes', async ({
  page,
  request,
}) => {
  const antes = await ilse(request);
  const esperado = segunMotor(antes, { type: 'shortRest' });
  await page.goto(COMBATE);

  expect(await proximoGuardado(page, () => page.getByRole('button', { name: 'Descanso corto' }).click())).toEqual(
    esperado,
  );
  // Deshacer guarda la ficha de antes del descanso tal como la dio el motor.
  const deshecho = await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).click());
  expect(deshecho).toEqual(migrateCharacter(antes));
  expect(await ilse(request)).toEqual(migrateCharacter(antes));
});

test('el descanso largo cura, recarga y lo cuenta; «Deshacer» devuelve también las cargas', async ({
  page,
  request,
}) => {
  const antes = await ilse(request);
  const ficha = computeSheet(antes, catalogo());
  const cargas = (c: CharacterJson) =>
    (c as { inventory: { itemId: string; charges?: number }[] }).inventory.find((e) => e.itemId === 'baston-de-curacion')!
      .charges;
  await page.goto(COMBATE);

  const enviado = (await proximoGuardado(page, () =>
    page.getByRole('button', { name: 'Descanso largo' }).click(),
  )) as PersonajeApi;
  // Lo que no tira dados es exactamente lo del motor; el bastón se recarga con
  // una tirada, así que se compara aparte.
  const sinTirada = (c: CharacterJson) => ({ ...c, inventory: undefined });
  expect(sinTirada(enviado)).toEqual(sinTirada(segunMotor(antes, { type: 'longRest' })));
  expect(enviado.combat.currentHp).toBe(ficha.maxHp);
  expect(cargas(enviado)!).toBeGreaterThan(cargas(antes)!);
  await expect(page.getByText(/^Descanso largo: PG al máximo y recursos recargados; cansancio a nivel 0.*1 objeto mágico recuperó cargas/)).toBeVisible();

  const deshecho = await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).click());
  expect(deshecho).toEqual(migrateCharacter(antes));
});

test('la Inspiración Heroica y la concentración se marcan a mano y guardan lo del motor', async ({
  page,
  request,
}) => {
  const tiene = Boolean((await ilse(request)).combat.heroicInspiration);
  const bendecir = String(catalogo().spells.find((s) => s.id === 'bless')!.name);
  await page.goto(COMBATE);

  const pasos: [() => Promise<void>, SheetAction][] = [
    [
      () => page.getByRole('button', { name: /^Inspiración Heroica/ }).click(),
      { type: 'heroicInspiration', value: !tiene },
    ],
    [
      async () => {
        await page.getByRole('button', { name: new RegExp(`^${bendecir}`) }).click();
        await page.getByRole('button', { name: 'Concentrar', exact: true }).click();
      },
      { type: 'concentrate', spell: bendecir },
    ],
    [() => page.getByRole('button', { name: 'Terminar', exact: true }).click(), { type: 'endConcentration' }],
  ];
  for (const [tocar, accion] of pasos) {
    const esperado = segunMotor(await ilse(request), accion);
    expect(await proximoGuardado(page, tocar)).toEqual(esperado);
    expect(await ilse(request)).toEqual(esperado);
  }
});

test('la mochila se edita desde la fila y quitar se deshace', async ({ page, request }) => {
  await page.goto(`/v2/personajes/${ILSE}/inventario`);
  const fila = page.locator('tr[data-entry="e-baston"]');
  const baston = String(catalogo().items.find((i) => i.id === 'baston-de-curacion')!.name);
  const entry = 'e-baston';

  const pasos: [() => Promise<void>, SheetAction][] = [
    [() => fila.getByRole('checkbox', { name: `Equipar ${baston}` }).click(), { type: 'equip', entry, value: true }],
    [
      () => fila.getByRole('button', { name: `Agregar una unidad de ${baston}` }).click(),
      { type: 'setQuantity', entry, value: 2 },
    ],
    [
      async () => {
        await fila.getByRole('button', { name: `Acciones de ${baston}` }).click();
        await page.getByRole('menuitem', { name: 'Nota…' }).click();
        await page.getByLabel('Qué dice, de dónde salió, para qué sirve').fill('Del templo');
        await page.getByRole('button', { name: 'Guardar', exact: true }).click();
      },
      { type: 'note', entry, text: 'Del templo' },
    ],
  ];
  for (const [tocar, accion] of pasos) {
    const esperado = segunMotor(await ilse(request), accion);
    expect(await proximoGuardado(page, tocar)).toEqual(esperado);
    expect(await ilse(request)).toEqual(esperado);
  }

  const bolsa = (await ilse(request)) as PersonajeApi & { coins?: Record<string, number> };
  const oro = segunMotor(bolsa, { type: 'setCoins', coins: { ...bolsa.coins, gp: 99 } });
  expect(
    await proximoGuardado(page, async () => {
      await page.getByLabel('Monedas de Oro').fill('99');
      await page.getByLabel('Monedas de Oro').press('Enter');
    }),
  ).toEqual(oro);

  const antes = await ilse(request);
  await proximoGuardado(page, async () => {
    await fila.getByRole('button', { name: `Acciones de ${baston}` }).click();
    await page.getByRole('menuitem', { name: 'Quitar', exact: true }).click();
  });
  await expect(fila).toHaveCount(0);
  expect(await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).click())).toEqual(
    migrateCharacter(antes),
  );
});

test('comprar del catálogo y vender pagan con la cuenta del motor, y vender se deshace', async ({
  page,
  request,
}) => {
  const daga = catalogo().weapons.find((w) => w.id === 'dagger')!;
  const nombre = String(daga.name);
  const d = new Date();
  const hoy = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  await page.goto(`/v2/personajes/${ILSE}/inventario`);

  const compra: SheetAction = { type: 'buy', item: 'dagger', quantity: 1, unitPriceCp: Number(daga.costCp), at: hoy };
  const comprada = segunMotor(await ilse(request), compra);
  expect(
    await proximoGuardado(page, async () => {
      await page.getByRole('button', { name: 'Agregar objeto' }).click();
      await page.getByRole('searchbox', { name: 'Buscar objeto…' }).fill(nombre);
      await page.getByRole('button', { name: `Comprar ${nombre}`, exact: true }).click();
      await page.getByRole('button', { name: 'Comprar', exact: true }).click();
    }),
  ).toEqual(comprada);
  // El catálogo se cierra para dejar a mano «Deshacer».
  await expect(page.getByRole('dialog')).toHaveCount(0);

  const linea = inventoryOf(comprada, catalogo()).find((l) => l.itemId === 'dagger')!;
  const venta: SheetAction = {
    type: 'sell',
    entry: linea.entryId,
    quantity: 1,
    unitPriceCp: linea.salePriceCp,
    at: hoy,
  };
  expect(
    await proximoGuardado(page, async () => {
      await page.locator(`tr[data-entry="${linea.entryId}"]`).getByRole('button', { name: `Acciones de ${nombre}` }).click();
      await page.getByRole('menuitem', { name: 'Vender…' }).click();
      await page.getByRole('button', { name: 'Vender', exact: true }).click();
    }),
  ).toEqual(segunMotor(comprada, venta));
  // El aviso de la compra puede seguir a la vista: «Deshacer» es el último.
  expect(await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).last().click())).toEqual(
    migrateCharacter(comprada),
  );
});

test('la subida de nivel pasa por PG, subclase y mejora, guarda lo del motor y se deshace', async ({
  page,
  request,
}) => {
  const BRUNA = 'bruna-de-humo';
  const antes = await ilse(request, BRUNA);
  const senda = levelUpView(antes, catalogo(), { classId: 'barbarian' }).subclassOptions[0]!;
  const esperado = segunMotor(antes, {
    type: 'levelUp',
    draft: { classId: 'barbarian', subclassId: senda.id, abilityA: 'strength' },
  });
  await page.goto(`/v2/personajes/${BRUNA}/subir-nivel`);

  await page.getByRole('button', { name: 'Empezar' }).click();
  await page.getByRole('button', { name: 'Continuar' }).click();
  await page.getByRole('radio', { name: new RegExp(`^${senda.name}`) }).click();
  await page.getByRole('button', { name: 'Continuar' }).click();
  await page.getByRole('radio', { name: /^Fuerza/ }).click();
  await page.getByRole('button', { name: 'Continuar' }).click();
  const enviado = await proximoGuardado(
    page,
    () => page.getByRole('button', { name: 'Subir a nivel 4' }).click(),
    BRUNA,
  );
  expect(enviado).toEqual(esperado);
  // Vuelve a la ficha con el aviso, y «Deshacer» guarda la de antes.
  await expect(page).toHaveURL(new RegExp(`/personajes/${BRUNA}/personaje$`));
  await expect(page.getByText('Bruna de Humo subió a nivel 4.', { exact: true })).toBeVisible();
  const deshecho = await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).click(), BRUNA);
  expect(deshecho).toEqual(migrateCharacter(antes));
});

test('la subida elige el estilo de combate pendiente y guarda lo del motor', async ({ page, request }) => {
  const GARRA = 'garra-de-humo';
  const antes = await ilse(request, GARRA);
  const cupo = levelUpView(antes, catalogo(), { classId: 'fighter' }).featureSlots[0]!;
  const estilo = cupo.options.find((o) => o.unmet === null)!;
  const esperado = segunMotor(antes, {
    type: 'levelUp',
    draft: { classId: 'fighter', featurePicks: { [cupo.groupId]: [estilo.id] } },
  });
  await page.goto(`/v2/personajes/${GARRA}/subir-nivel`);

  await page.getByRole('button', { name: 'Empezar' }).click();
  await page.getByRole('button', { name: 'Continuar' }).click();
  await expect(page.getByRole('button', { name: 'Continuar' })).toBeDisabled();
  const literal = estilo.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  await page.getByRole('radio', { name: new RegExp(`^${literal}`) }).click();
  // El panel derecho explica la opción elegida.
  await expect(page.locator('[data-field="level-up-detail"]')).toContainText(estilo.name);
  await page.getByRole('button', { name: 'Continuar' }).click();
  expect(
    await proximoGuardado(page, () => page.getByRole('button', { name: 'Subir a nivel 2' }).click(), GARRA),
  ).toEqual(esperado);
});

test('la clériga sube eligiendo Orden Divina, los conjuros de su dote y los de clase', async ({ page, request }) => {
  const antes = await ilse(request);
  // El borrador se arma paso a paso con el motor, como lo arma la pantalla:
  // lo elegido en un cupo cambia las opciones del siguiente.
  const ver = (d: LevelUpDraft) => levelUpView(antes, catalogo(), d);
  let d: LevelUpDraft = { classId: 'cleric', abilityA: 'wisdom' };
  const orden = ver(d).featureSlots.find((s) => s.chosen.length < s.count)!;
  const ordenId = orden.options.find((o) => o.unmet === null)!.id;
  d = { ...d, featurePicks: { [orden.groupId]: [ordenId] } };
  const dote: string[] = [];
  const spellPicks: Record<string, string[]> = {};
  for (const slot of ver(d).spellSlots) {
    const ids = slot.options.map((o) => o.id).filter((id) => !dote.includes(id)).slice(0, slot.count);
    spellPicks[slot.groupId] = ids;
    dote.push(...ids);
  }
  d = { ...d, spellPicks };
  const cs = ver(d).classSpells!;
  const llenar = (chosen: string[], pool: { id: string }[], n: number) =>
    pool.map((o) => o.id).filter((id) => !chosen.includes(id)).slice(0, n - chosen.length);
  const trucos = llenar(cs.chosenCantrips, cs.cantrips, cs.cantripsKnown);
  const conjuros = llenar(cs.chosenSpells, cs.spells, cs.preparedCount);
  d = {
    ...d,
    classCantripPicks: [...cs.chosenCantrips, ...trucos],
    classSpellPicks: [...cs.chosenSpells, ...conjuros],
  };
  const esperado = segunMotor(antes, { type: 'levelUp', draft: d });
  const tocar = (id: string) => page.locator(`[data-option="${id}"]`).first().click();
  const continuar = () => page.getByRole('button', { name: 'Continuar' }).click();
  await page.goto(`/v2/personajes/${ILSE}/subir-nivel`);

  await page.getByRole('button', { name: 'Empezar' }).click();
  await continuar();
  await page.getByRole('radio', { name: /^Sabiduría/ }).click();
  await continuar();
  await tocar(ordenId);
  await continuar();
  for (const id of dote) await tocar(id);
  await continuar();
  for (const id of [...trucos, ...conjuros]) await tocar(id);
  await continuar();
  expect(await proximoGuardado(page, () => page.getByRole('button', { name: 'Subir a nivel 4' }).click())).toEqual(
    esperado,
  );
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
