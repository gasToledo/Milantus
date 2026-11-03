import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import {
  actOn,
  computeSheet,
  innateCantripOptions,
  inventoryOf,
  levelUpView,
  magicPlansView,
  migrateCharacter,
  spellEditView,
  type CharacterJson,
  type LevelUpDraft,
  type SheetAction,
} from '../src/engine';
import { resourceKey, signed } from '../src/sheet/format';
import { api, catalogo, TOKEN_ESCRITURA, TOKEN_SIN_V2, vigilarEscrituras, type PersonajeApi } from './helpers';

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
  // Los botones de espacio son los del nivel elegido en la grilla.
  await page.locator('[data-slot="normal-1"]').click();

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

test('el dado de golpe y los descansos guardan lo del motor, y «Deshacer» vuelve a guardar la ficha de antes', async ({
  page,
  request,
}) => {
  // Cada paso entra de nuevo: el aviso del anterior, con su «Deshacer», no
  // tiene que seguir a la vista.
  await page.goto(COMBATE);
  const antesDelDado = await ilse(request);
  const gastados = (c: PersonajeApi) =>
    Object.values((c.combat as { hitDiceUsed?: Record<string, number> }).hitDiceUsed ?? {}).reduce((a, b) => a + b, 0);
  const conDado = (await proximoGuardado(page, () =>
    page.getByRole('button', { name: /^Dado de golpe/ }).click(),
  )) as PersonajeApi;
  expect(gastados(conDado)).toBe(gastados(antesDelDado) + 1);
  expect(await ilse(request)).toEqual(conDado);

  await page.goto(COMBATE);
  const antesDelCorto = await ilse(request);
  expect(await proximoGuardado(page, () => page.getByRole('button', { name: 'Descanso corto' }).click())).toEqual(
    segunMotor(antesDelCorto, { type: 'shortRest' }),
  );
  const cortoDeshecho = await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).click());
  expect(cortoDeshecho).toEqual(migrateCharacter(antesDelCorto));
  expect(await ilse(request)).toEqual(migrateCharacter(antesDelCorto));

  await page.goto(COMBATE);
  const antes = await ilse(request);
  const ficha = computeSheet(antes, catalogo());
  const cargas = (c: CharacterJson) =>
    (c as { inventory: { itemId: string; charges?: number }[] }).inventory.find((e) => e.itemId === 'baston-de-curacion')!
      .charges;
  const enviado = (await proximoGuardado(page, () =>
    page.getByRole('button', { name: 'Descanso largo' }).click(),
  )) as PersonajeApi;
  // Lo que no tira dados es exactamente lo del motor; el bastón se recarga con
  // una tirada, así que se compara aparte.
  const sinTirada = (c: CharacterJson) => ({ ...c, inventory: undefined });
  expect(sinTirada(enviado)).toEqual(sinTirada(segunMotor(antes, { type: 'longRest' })));
  expect(enviado.combat.currentHp).toBe(ficha.maxHp);
  expect(cargas(enviado)!).toBeGreaterThan(cargas(antes)!);
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
        // Bendición es de nivel 1 y, en Dominio de la Vida, siempre preparada:
        // vive en esa pestaña, que también sigue a la celda elegida.
        await page.locator('[data-slot="normal-1"]').click();
        await page.locator('[data-tab="always"]').click();
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

test('la Furia, los estados y el cansancio guardan lo del motor y se releen al recargar', async ({ page, request }) => {
  const BRUNA = 'bruna-de-humo';
  await page.goto(`/v2/personajes/${BRUNA}/combate`);
  const furia = page.locator('[data-stat="mode-rage"]');
  const pasos: [() => Promise<void>, SheetAction][] = [
    [() => furia.getByRole('button', { name: 'Activar' }).click(), { type: 'activateMode', mode: 'rage' }],
    [
      () => page.locator('[data-condition="poisoned"]').click(),
      { type: 'setCondition', condition: 'poisoned', value: true },
    ],
    // Aturdido incluye Incapacitado: el motor termina la Furia.
    [
      () => page.locator('[data-condition="stunned"]').click(),
      { type: 'setCondition', condition: 'stunned', value: true },
    ],
    [
      () => page.getByRole('button', { name: 'Subir un nivel de cansancio' }).click(),
      { type: 'setExhaustion', value: 1 },
    ],
    [
      () => page.getByRole('button', { name: 'Subir un nivel de cansancio' }).click(),
      { type: 'setExhaustion', value: 2 },
    ],
    [
      () => page.getByRole('button', { name: 'Bajar un nivel de cansancio' }).click(),
      { type: 'setExhaustion', value: 1 },
    ],
  ];
  for (const [i, [tocar, accion]] of pasos.entries()) {
    const esperado = segunMotor(await ilse(request, BRUNA), accion);
    expect(await proximoGuardado(page, tocar, BRUNA)).toEqual(esperado);
    expect(await ilse(request, BRUNA)).toEqual(esperado);
    // Con la Furia en curso su franja lo dice, y al quedar aturdida se apaga.
    if (i === 0) await expect(furia).toContainText('En curso');
  }
  await expect(furia).not.toContainText('En curso');

  // Al recargar la pantalla lee lo guardado: los estados siguen marcados, el
  // cansancio en 1 y los números de la ficha ya lo traen aplicado.
  await page.reload();
  await expect(page.locator('[data-condition="stunned"]')).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('[data-condition="poisoned"]')).toHaveAttribute('aria-pressed', 'true');
  const ficha = computeSheet(migrateCharacter(await ilse(request, BRUNA)), catalogo());
  await expect(page.locator('[data-stat="speed"] [data-field="value"]')).toHaveText(String(ficha.speed));
  await expect(page.locator('[data-stat="initiative"] [data-field="value"]')).toHaveText(
    signed(ficha.initiative),
  );

  // Limpia la ficha para el resto de la corrida.
  for (const id of ['poisoned', 'stunned']) await page.locator(`[data-condition="${id}"]`).click();
  await page.getByRole('button', { name: 'Bajar un nivel de cansancio' }).click();
  await expect(page.locator('[data-save-state="saved"]')).toBeVisible();
});

const EDITOR = `/v2/personajes/${ILSE}/conjuros/cleric`;

test('preparar conjuros desde la ficha guarda lo del motor y «Deshacer» vuelve a guardar la de antes', async ({
  page,
  request,
}) => {
  const antes = await ilse(request);
  const vista = spellEditView(antes, catalogo(), 'cleric')!;
  const quitar = vista.chosenSpells[0]!;
  const poner = vista.spells.find((o) => !vista.chosenSpells.includes(o.id))!.id;
  const esperado = segunMotor(antes, {
    type: 'setClassSpells',
    classId: 'cleric',
    cantrips: vista.chosenCantrips,
    spells: [...vista.chosenSpells.slice(1), poner],
  });

  await page.goto(COMBATE);
  await page.locator('[data-action="edit-spells"]').click();
  await expect(page).toHaveURL(EDITOR);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Preparar conjuros · Clérigo');
  const guardar = page.getByRole('button', { name: 'Guardar', exact: true });
  await expect(guardar).toBeDisabled();
  await page.locator(`[data-chip="${quitar}"]`).click();
  await page.locator(`[data-option="${poner}"]`).click();
  const enviado = await proximoGuardado(page, () => guardar.click());
  expect(enviado).toEqual(esperado);
  expect(await ilse(request)).toEqual(esperado);
  await expect(page).toHaveURL(COMBATE);
  await expect(page.getByText('Conjuros guardados.', { exact: true })).toBeVisible();

  const vuelta = await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).click());
  expect(vuelta).toEqual(migrateCharacter(antes));

  // Al recargar el editor lee lo guardado: lo que se sacó vuelve a estar.
  await page.goto(EDITOR);
  await expect(page.locator(`[data-chip="${quitar}"]`)).toBeVisible();
  await expect(page.locator(`[data-chip="${poner}"]`)).toHaveCount(0);
});

test('cambiar el truco innato se confirma con «Cambiar» y guarda lo del motor', async ({ page, request }) => {
  const ELFO = 'elfo-de-humo';
  const antes = await ilse(request, ELFO);
  const innato = computeSheet(antes, catalogo()).innateSpells.find((s) => s.replaceableFrom.length > 0)!;
  const otro = innateCantripOptions(antes, catalogo(), innato.grantedSpellId).find(
    (o) => o.id !== innato.grantedSpellId,
  )!;
  const esperado = segunMotor(antes, { type: 'setInnateCantrip', granted: innato.grantedSpellId, spell: otro.id });
  const escrituras = vigilarEscrituras(page);

  await page.goto(`/v2/personajes/${ELFO}/combate`);
  await page.locator('[data-tab="innate"]').click();
  await page.locator('[data-spell-group="innate"]').getByRole('button', { name: innato.name }).click();
  await page.locator('[data-action="swap-innate"]').click();
  const dialogo = page.getByRole('dialog');
  const cambiar = dialogo.getByRole('button', { name: 'Cambiar', exact: true });
  await expect(cambiar).toBeDisabled();
  await dialogo.locator(`[data-option="${otro.id}"]`).click();
  // Elegir no guarda ni cierra: lo hace «Cambiar».
  await expect(cambiar).toBeEnabled();
  expect(escrituras).toEqual([]);
  const enviado = await proximoGuardado(page, () => cambiar.click(), ELFO);
  expect(enviado).toEqual(esperado);
  expect(await ilse(request, ELFO)).toEqual(esperado);
  await expect(page.getByText(`Truco cambiado a ${otro.name}.`, { exact: true })).toBeVisible();
});

test('vincular el arma de pacto la crea con lo del motor y se relee al recargar', async ({ page, request }) => {
  const BRUJO = 'brujo-de-humo';
  const antes = await ilse(request, BRUJO);
  const cupo = computeSheet(antes, catalogo()).targetChoiceSlots[0]!;
  const arma = cupo.creatableWeaponIds[0]!;
  const esperado = segunMotor(antes, { type: 'createEffectTarget', group: cupo.groupId, weapon: arma });
  const escrituras = vigilarEscrituras(page);

  await page.goto(`/v2/personajes/${BRUJO}/inventario`);
  const boton = page.locator(`[data-action="target-${cupo.groupId}"]`);
  await expect(boton).toContainText('(0/1)');
  await boton.click();
  const dialogo = page.getByRole('dialog');
  const vincular = dialogo.getByRole('button', { name: 'Vincular', exact: true });
  await expect(vincular).toBeDisabled();
  await dialogo.locator(`[data-option="weapon:${arma}"]`).click();
  // Elegir no guarda ni cierra: lo hace «Vincular».
  await expect(vincular).toBeEnabled();
  expect(escrituras).toEqual([]);
  const enviado = await proximoGuardado(page, () => vincular.click(), BRUJO);
  expect(enviado).toEqual(esperado);
  expect(await ilse(request, BRUJO)).toEqual(esperado);

  await page.reload();
  await expect(page.locator(`[data-action="target-${cupo.groupId}"]`)).toContainText('(1/1)');
});

test('elegir un plano, replicarlo y quitar la réplica guardan lo del motor, y «Deshacer» guarda la de antes', async ({
  page,
  request,
}) => {
  const ARTIFICE = 'artifice-de-humo';
  const antes = await ilse(request, ARTIFICE);
  // Un plano que no pide objeto base: la réplica se crea sin diálogo.
  const plan = magicPlansView(antes, catalogo())!.options.find((o) => o.baseItemKind === null)!;
  const elegido = segunMotor(antes, { type: 'setMagicItemPlan', item: plan.id, value: true });
  const replicado = segunMotor(elegido, { type: 'replicateItem', item: plan.id });
  const entrada = (replicado.inventory as { entryId: string }[])[0]!.entryId;
  const sinReplica = segunMotor(replicado, { type: 'removeItem', entry: entrada });

  await page.goto(`/v2/personajes/${ARTIFICE}/planos`);
  expect(await proximoGuardado(page, () => page.locator(`[data-option="${plan.id}"]`).click(), ARTIFICE)).toEqual(elegido);
  expect(await ilse(request, ARTIFICE)).toEqual(elegido);

  await page.locator('[data-tab="replicas"]').click();
  const accion = page.locator(`[data-replica="${plan.id}"]`);
  await expect(accion).toHaveText('Crear réplica');
  expect(await proximoGuardado(page, () => accion.click(), ARTIFICE)).toEqual(replicado);
  expect(await ilse(request, ARTIFICE)).toEqual(replicado);

  await expect(accion).toHaveText('Quitar réplica');
  expect(await proximoGuardado(page, () => accion.click(), ARTIFICE)).toEqual(sinReplica);
  const vuelta = await proximoGuardado(page, () => page.getByRole('button', { name: 'Deshacer' }).click(), ARTIFICE);
  expect(vuelta).toEqual(replicado);
  expect(await ilse(request, ARTIFICE)).toEqual(replicado);
});

test('transformarse en lobo y volver guardan lo que da el motor', async ({ page, request }) => {
  const DRUIDA = 'druida-de-humo';
  const antes = await ilse(request, DRUIDA);
  const transformado = segunMotor(antes, { type: 'enterWildShape', creature: 'wolf' });
  const vuelta = segunMotor(transformado, { type: 'leaveWildShape' });

  await page.goto(`/v2/personajes/${DRUIDA}/combate`);
  await page.locator('[data-stat="wild-shape"] button').click();
  const enviado = await proximoGuardado(
    page,
    () => page.getByRole('dialog').getByRole('button', { name: 'Transformarse' }).click(),
    DRUIDA,
  );
  expect(enviado).toEqual(transformado);
  // Transformado, los ataques son los de la bestia.
  await expect(page.locator('[data-attack="wolf"]').first()).toBeVisible();

  const fin = await proximoGuardado(page, () => page.locator('[data-stat="wild-shape"] button').click(), DRUIDA);
  expect(fin).toEqual(vuelta);
});

test('invocar un familiar y despedirlo guardan lo que da el motor', async ({ page, request }) => {
  const DRUIDA = 'druida-de-humo';
  const antes = await ilse(request, DRUIDA);
  // Su única opción es el familiar, que no cuesta nada: la primera forma es el murciélago.
  const invocado = segunMotor(antes, { type: 'summonCompanion', option: 'familiar', creature: 'bat' });
  const despedido = segunMotor(invocado, { type: 'dismissCompanion', index: 0 });

  await page.goto(`/v2/personajes/${DRUIDA}/combate`);
  await page.locator('[data-action="summon"]').click();
  const enviado = await proximoGuardado(
    page,
    () => page.getByRole('dialog').getByRole('button', { name: 'Invocar', exact: true }).click(),
    DRUIDA,
  );
  expect(enviado).toEqual(invocado);

  await page.locator('[data-companion="0"] button').first().click();
  const fin = await proximoGuardado(
    page,
    () => page.locator('[data-companion="0"]').getByRole('button', { name: 'Despedir', exact: true }).click(),
    DRUIDA,
  );
  expect(fin).toEqual(despedido);
});

test('un aviso del motor lleva a la pantalla de elecciones, y elegir guarda lo que da el motor', async ({ page, request }) => {
  const ELFA = 'elfa-de-humo';
  const antes = await ilse(request, ELFA);

  await page.goto(`/v2/personajes/${ELFA}/personaje`);
  await page.locator('[data-action="review-warnings"]').click();
  await page.locator('[data-resolve="lineage_pending"]').click();

  const enviado = await proximoGuardado(page, () => page.locator('[data-option="elf-high"]').click(), ELFA);
  expect(enviado).toEqual(segunMotor(antes, { type: 'setLineage', lineage: 'elf-high' }));
});

test('escribir el trasfondo guarda lo que da el motor', async ({ page, request }) => {
  const antes = await ilse(request);
  const text = '## Antes del pacto\n\nCopiaba manuscritos en la biblioteca de Lenn.';

  await page.goto(`/v2/personajes/${ILSE}/diario`);
  await page.locator('[data-action="edit-background"]').click();
  const enviado = await proximoGuardado(page, async () => {
    await page.locator('[data-field="background-input"]').fill(text);
    await page.locator('[data-action="edit-background"]').click();
  });
  expect(enviado).toEqual(segunMotor(antes, { type: 'setBackground', text }));
});

test('subir un retrato guarda lo que da el motor', async ({ page, request }) => {
  const antes = await ilse(request);
  // Un PNG de 1×1: al servidor le alcanza la cabecera (`sniffPortraitImageType`).
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg==',
    'base64',
  );

  await page.goto(`/v2/personajes/${ILSE}/retrato`);
  // Con proveedores la pantalla abre en Generar: se pasa a Subir.
  await page.locator('[data-tab="upload"]').click();
  const enviado = await proximoGuardado(page, () =>
    page.locator('[data-field="portrait-file"]').setInputFiles({ name: 'retrato.png', mimeType: 'image/png', buffer: png }),
  );
  expect(enviado).toEqual(segunMotor(antes, { type: 'addPortrait', key: enviado.portraitPaths![0] }));
});

test('renombrar desde la lista guarda lo que da el motor', async ({ page, request }) => {
  const antes = await ilse(request);
  const nuevo = 'Ilse de las Cenizas';

  // Por el menú ⋮ de la tarjeta; devuelve lo que viajó en el PUT.
  async function renombrar(actual: string, nombre: string): Promise<CharacterJson> {
    await page.locator(`[data-character="${ILSE}"]`).getByRole('button', { name: `Acciones de ${actual}` }).click();
    await page.getByRole('menuitem', { name: 'Renombrar' }).click();
    await page.locator('[data-field="rename"]').fill(nombre);
    const put = page.waitForRequest((r) => r.method() === 'PUT' && r.url().endsWith(`/api/characters/${ILSE}`));
    await page.getByRole('button', { name: 'Guardar', exact: true }).click();
    const enviado = ((await put).postDataJSON() as { character: CharacterJson }).character;
    await expect(page.getByRole('dialog')).toBeHidden();
    return enviado;
  }

  await page.goto('/v2/');
  const enviado = await renombrar(antes.name, nuevo);
  expect(enviado).toEqual(segunMotor(antes, { type: 'rename', name: nuevo }));
  expect((await ilse(request)).name).toBe(nuevo);

  // Se deja el nombre original: las otras pruebas de esta cuenta lo leen.
  await renombrar(nuevo, antes.name);
  expect((await ilse(request)).name).toBe(antes.name);
});

test('compartir: el código se canjea, el aviso llega y dejar de compartir avisa al DM', async ({ page, request }) => {
  const { name } = await ilse(request);

  await page.goto(`/v2/personajes/${ILSE}/personaje`);
  await page.getByRole('button', { name: 'Compartir' }).click();
  await page.getByRole('button', { name: 'Generar código' }).click();
  const code = (await page.locator('[data-field="share-code"]').textContent())!;

  // El DM es la cuenta sin /v2 y solo por API: sus avisos no aparecen en
  // ninguna pantalla ni chocan con las pruebas que corren en paralelo.
  const comoDm = { headers: { cookie: `dnd_session=${TOKEN_SIN_V2}` } };
  await request.post('/api/campaigns', { ...comoDm, data: { campaign: { id: 'mesa-de-compartir', name: 'Mesa de Compartir' } } });
  await request.post('/api/campaigns/mesa-de-compartir/members', { ...comoDm, data: { code } });

  await page.reload();
  await expect(page.getByText(`«${name}» se sumó a la campaña «Mesa de Compartir».`, { exact: true })).toBeVisible();
  // Marcado visto: no vuelve a la próxima entrada.
  await expect
    .poll(async () => (await api<{ events: unknown[] }>(request, '/api/events', TOKEN_ESCRITURA)).events)
    .toEqual([]);

  await page.getByRole('button', { name: 'Compartir' }).click();
  await page.getByRole('button', { name: 'Dejar de compartir con Mesa de Compartir' }).click();
  await page.getByRole('button', { name: 'Dejar de compartir', exact: true }).click();
  await expect(page.getByText('Ya no se comparte con Mesa de Compartir.', { exact: true })).toBeVisible();

  const { events } = await api<{ events: { kind: string }[] }>(request, '/api/events', TOKEN_SIN_V2);
  expect(events.map((e) => e.kind)).toContain('character_unlinked_by_owner');
});
