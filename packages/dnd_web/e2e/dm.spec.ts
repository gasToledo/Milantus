import { expect, test } from '@playwright/test';
import { bestiary, chapterGrants, computeSheet, musicSource, type JsonObject } from '../src/engine';
import { signed } from '../src/sheet/format';
import { api, catalogo, TOKEN, TOKEN_DM, TOKEN_SIN_V2, vigilarEscrituras, type PersonajeApi } from './helpers';

test.use({ locale: 'es-AR' });

const CAMPANA = 'marca-del-cuervo';
const MESA = `/v2/dm/campanas/${CAMPANA}/mesa`;

// Lo que el DM sembró y no tiene que llegarle a ninguna otra cuenta (ver
// `e2e_server.dart`).
const SOLO_DEL_DM = ['La Marca del Cuervo', 'Tema secreto del DM', 'Resumen reservado del DM', 'Nota reservada del DM'];

test('la Mesa del DM lista a los jugadores vinculados con los números del motor y sin escribir nada', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);

  // Lo esperado sale de la API de miembros y del motor, no de una transcripción.
  const { members } = await api<{ members: { memberId: string; character: PersonajeApi }[] }>(
    page.request,
    `/api/campaigns/${CAMPANA}/members`,
    TOKEN_DM,
  );
  expect(members.map((m) => m.character.id).sort()).toEqual(['elsbeth-de-humo', 'sagan-de-humo']);
  const catalog = catalogo();

  // Entrar por «DM» del interruptor lleva a la primera campaña en curso.
  await page.goto('/v2/');
  await page.getByRole('group', { name: 'Modo' }).getByRole('link', { name: 'DM' }).click();
  await expect(page).toHaveURL(MESA);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('La Marca del Cuervo');
  await expect(page.getByText('En curso · El Valle Hueco')).toBeVisible();
  await expect(page.getByRole('list', { name: '2 personajes en la mesa' })).toBeVisible();
  // El modo actual es DM: el interruptor lo marca y «Jugador» pasa a ser el enlace.
  await expect(page.getByRole('group', { name: 'Modo' }).locator('[aria-current="true"]')).toHaveText('DM');

  for (const { character } of members) {
    const ficha = computeSheet(character, catalog);
    const tarjeta = page.locator(`[data-member="${character.id}"]`);
    const placa = (stat: string) => tarjeta.locator(`[data-stat="${stat}"] [data-field="value"]`);
    await expect(tarjeta.getByRole('heading', { level: 2 })).toHaveText(character.name);
    await expect(tarjeta.locator('[data-stat="level"]')).toHaveText(String(ficha.level));
    await expect(tarjeta.locator('[data-stat="hp"]')).toHaveText(`${character.combat.currentHp} / ${ficha.maxHp}`);
    await expect(placa('ac')).toHaveText(String(ficha.armorClass));
    await expect(placa('initiative')).toHaveText(signed(ficha.initiative));
    await expect(placa('passive')).toHaveText(String(ficha.passivePerception));
    // Elsbeth es clériga (CD del motor); Sagan, guerrero (sin CD).
    const cd = ficha.spellcasting?.saveDc;
    await expect(placa('dc')).toHaveText(cd === undefined ? '—' : String(cd));
  }

  // Los estados de la ficha del jugador, como pills; la sana no tiene ninguno.
  const sagan = page.locator('[data-member="sagan-de-humo"]');
  await expect(sagan.getByRole('listitem').filter({ hasText: 'Envenenado' })).toBeVisible();
  await expect(sagan.getByRole('listitem').filter({ hasText: 'Agotamiento 2' })).toBeVisible();
  await expect(page.locator('[data-member="elsbeth-de-humo"]').getByRole('listitem')).toHaveCount(0);

  // El panel: las tres herramientas de la cuenta ya son de /v2.
  const herramientas = page.getByRole('navigation', { name: 'Herramientas del DM' });
  for (const [name, href] of [
    ['Bestiario', '/v2/dm/bestiario'],
    ['Biblioteca de PNJ', '/v2/dm/pnj'],
    ['Homebrew', '/v2/dm/homebrew'],
  ] as const) {
    await expect(herramientas.getByRole('link', { name })).toHaveAttribute('href', href);
  }
  await expect(page.getByRole('navigation', { name: 'Campañas' }).getByRole('link', { name: 'La Marca del Cuervo' })).toHaveAttribute(
    'aria-current',
    'page',
  );

  // Ni la Mesa ni nada de lo que se vio escribió en la API.
  expect(escrituras).toEqual([]);
});

test('la tarjeta de la Mesa abre la ficha completa del miembro, de solo lectura y con los números del motor', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const { members } = await api<{ members: { memberId: string; character: PersonajeApi }[] }>(
    page.request,
    `/api/campaigns/${CAMPANA}/members`,
    TOKEN_DM,
  );
  const elsbeth = members.find((m) => m.character.id === 'elsbeth-de-humo')!;
  const ficha = computeSheet(elsbeth.character, catalogo());

  await page.goto(MESA);
  await page.locator('[data-member="elsbeth-de-humo"]').getByRole('link', { name: elsbeth.character.name }).click();
  // Por el vínculo y no por el id del personaje: es lo que autoriza al DM.
  await expect(page).toHaveURL(`${MESA}/${elsbeth.memberId}/personaje`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(elsbeth.character.name);
  const cifra = (id: string) => page.locator(`section[aria-label="Cifras de combate"] [data-stat="${id}"] [data-field="value"]`);
  await expect(cifra('ac')).toHaveText(String(ficha.armorClass));
  await expect(cifra('initiative')).toHaveText(signed(ficha.initiative));
  // Solo lo que sirve en combate: lo demás es del jugador.
  const pestanas = page.getByRole('tablist', { name: 'Pestañas de la ficha' });
  await expect(pestanas.getByRole('tab')).toHaveText(['Personaje', 'Combate']);
  await pestanas.getByRole('tab', { name: 'Combate' }).click();
  await expect(page).toHaveURL(`${MESA}/${elsbeth.memberId}/combate`);
  await expect(page.locator('[data-stat="spell-dc"] [data-field="value"]')).toHaveText(String(ficha.spellcasting!.saveDc));
  await expect(page.getByRole('navigation', { name: 'Secciones de la campaña' }).getByRole('link', { name: 'Mesa' })).toHaveAttribute(
    'aria-current',
    'page',
  );
  expect(escrituras).toEqual([]);

  // Un vínculo que no existe dice lo mismo que uno cortado.
  await page.goto(`${MESA}/no-existe/personaje`);
  await expect(page.getByText('Ya no ves esta ficha. Puede que te hayan cortado el vínculo.')).toBeVisible();
});

test('la música pone una escena de la campaña con el reproductor que arma el motor, sigue al cambiar de sección y no escribe', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  // La prueba no sale a internet: YouTube no responde y el iframe queda vacío.
  await page.route('https://www.youtube-nocookie.com/**', (r) => r.abort());
  const escrituras = vigilarEscrituras(page);
  const { campaigns } = await api<{ campaigns: { id: string; musicScenes: { name: string; url: string }[] }[] }>(
    page.request,
    '/api/campaigns',
    TOKEN_DM,
  );
  const escena = campaigns.find((c) => c.id === CAMPANA)!.musicScenes[0]!;
  const fuente = musicSource(escena.url)!;

  await page.goto(MESA);
  await page.getByRole('button', { name: 'Música' }).click();
  const escenas = page.getByRole('list', { name: 'Escenas de la campaña' });
  await expect(escenas.getByRole('listitem')).toHaveText([`${escena.name}Video de YouTube`]);
  await escenas.getByRole('button', { name: `Reproducir: ${escena.name}` }).click();
  // La dirección del iframe es la del motor, nunca el texto que pegó el DM.
  const reproductor = page.locator('[data-music-player] iframe');
  await expect(reproductor).toHaveAttribute('src', `${fuente.embedUrl}&autoplay=1`);

  // Cambiar de sección o abrir una herramienta de la cuenta no la corta.
  await page.getByRole('navigation', { name: 'Secciones de la campaña' }).getByRole('link', { name: 'Capítulos' }).click();
  await page.getByRole('navigation', { name: 'Herramientas del DM' }).getByRole('link', { name: 'Bestiario' }).click();
  await expect(page).toHaveURL('/v2/dm/bestiario');
  await expect(reproductor).toHaveAttribute('src', `${fuente.embedUrl}&autoplay=1`);
  expect(escrituras).toEqual([]);
});

test('Capítulos muestra estado, objetivo y recompensas de cada capítulo, y solo el DM lee el objetivo', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  const { chapters } = await api<{ chapters: (JsonObject & { id: string })[] }>(
    page.request,
    `/api/campaigns/${CAMPANA}/chapters`,
    TOKEN_DM,
  );

  await page.goto(MESA);
  await page.getByRole('navigation', { name: 'Secciones de la campaña' }).getByRole('link', { name: 'Capítulos' }).click();
  await expect(page).toHaveURL(`/v2/dm/campanas/${CAMPANA}/capitulos`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Capítulos');
  await expect(page.getByText('En curso · 3 capítulos')).toBeVisible();

  const estado = { 'paso-de-varn': 'closed', 'capitulo-en-marcha': 'open', 'concilio-de-brasas': 'pending' };
  const rotulo = { closed: 'Cerrado', open: 'Abierto', pending: 'Pendiente' };
  for (const c of chapters) {
    const tarjeta = page.locator(`[data-chapter="${c.id}"]`);
    const e = estado[c.id as keyof typeof estado] as keyof typeof rotulo;
    await expect(tarjeta).toHaveAttribute('data-status', e);
    await expect(tarjeta).toContainText(rotulo[e]);
    // Lo que reparte lo nombra el motor, igual que en la vista del jugador.
    if (chapterGrants(c)) await expect(tarjeta).toContainText(`Reparte ${chapterGrants(c)}`);
  }
  // El objetivo es del DM: acá se lee; el sin definir lo dice.
  await expect(page.locator('[data-chapter="capitulo-en-marcha"]')).toContainText('Resumen reservado del DM');
  await expect(page.locator('[data-chapter="concilio-de-brasas"]')).toContainText('Sin definir todavía.');
  await expect(page.locator('[data-chapter="paso-de-varn"] [data-stat="gold"]')).toContainText('25');
  // El abierto se destaca con el borde oro.
  await expect(page.locator('[data-chapter="capitulo-en-marcha"]')).toHaveClass(/border-gold/);
  expect(escrituras).toEqual([]);

  // El jugador vinculado nunca recibe el objetivo ni los capítulos sin cerrar.
  const jugador = await api<unknown>(page.request, '/api/characters/elsbeth-de-humo/campaigns', TOKEN);
  const crudo = JSON.stringify(jugador);
  for (const secreto of ['Resumen reservado del DM', 'El Concilio de Brasas', 'El Valle Hueco']) {
    expect(crudo, `la API del jugador manda «${secreto}»`).not.toContain(secreto);
  }
});

test('el Cuaderno junta notas, combates y subidas de nivel por capítulo, y nada de eso llega al jugador', async ({
  context,
  page,
  baseURL,
}) => {
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);

  await page.goto(MESA);
  await page.getByRole('navigation', { name: 'Secciones de la campaña' }).getByRole('link', { name: 'Cuaderno' }).click();
  await expect(page).toHaveURL(`/v2/dm/campanas/${CAMPANA}/cuaderno`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Cuaderno');

  // Se abre en el capítulo en marcha: su nota y la subida de nivel que anotó
  // el servidor, con la clase que da el catálogo.
  const pill = (n: string) => page.getByRole('group', { name: 'Capítulo' }).getByRole('button', { name: n });
  await expect(pill('El Valle Hueco')).toHaveAttribute('aria-pressed', 'true');
  const nota = page.locator('[data-entry="note"]');
  await expect(nota).toContainText('Nota privada');
  await expect(nota).toContainText('Nota reservada del DM: el herrero traiciona al grupo.');
  const subida = page.locator('[data-entry="levelUp"]');
  await expect(subida).toContainText('Elsbeth de Humo subió a nivel 3');
  await expect(subida).toContainText('Clérigo 3');
  await expect(page.locator('[data-field="counts"]')).toHaveText('1 nota1 subida de nivel');

  // El combate cerrado de otro capítulo, con quiénes pelearon y cuánto duró.
  await pill('El paso de Varn').click();
  const combate = page.locator('[data-entry="fight"]');
  await expect(combate).toContainText('Combate contra Lobo');
  await expect(combate).toContainText('Elsbeth de Humo, Thalion contra Lobo ×3. Cayeron todos los enemigos.');
  await expect(combate).toContainText('4 rondas');

  // Lo que no cuelga de ningún capítulo, con el PNJ aliado por su nombre propio:
  // eso es solo del DM.
  await pill('Sin capítulo').click();
  await expect(page.locator('[data-entry="fight"]')).toContainText('Aliados: Garrick el Tabernero.');

  // Buscar suma las coincidencias por capítulo y apaga las pills vacías.
  await page.getByRole('searchbox', { name: 'Buscar en el cuaderno' }).fill('lobo');
  await expect(pill('El paso de Varn')).toContainText('1');
  await expect(pill('El Valle Hueco')).toContainText('0');
  await pill('El paso de Varn').click();
  await expect(page.locator('[data-entry]')).toHaveCount(1);
  await page.getByRole('searchbox', { name: 'Buscar en el cuaderno' }).fill('zzz');
  await expect(page.getByText('Nada en este capítulo coincide con la búsqueda.')).toBeVisible();
  expect(escrituras).toEqual([]);

  // El jugador vinculado no recibe ni las notas, ni los nombres propios de los
  // PNJ, ni las subidas de nivel anotadas para el DM.
  const crudo = JSON.stringify(await api<unknown>(page.request, '/api/characters/elsbeth-de-humo/campaigns', TOKEN));
  for (const secreto of ['Nota reservada del DM', 'Garrick el Tabernero', 'subió a nivel', 'levelUps', 'encounterLogs']) {
    expect(crudo, `la API del jugador manda «${secreto}»`).not.toContain(secreto);
  }
});

test('el Bestiario del DM es el mismo del jugador montado bajo /v2/dm, con el homebrew de la cuenta y sin dárselo a otra', async ({
  context,
  page,
  baseURL,
}) => {
  const catalog = catalogo();
  const lista = '[data-field="bestiary-list"]';
  const { content } = await api<{ content: { creatures: JsonObject[] } }>(page.request, '/api/homebrew', TOKEN);
  const sombra = content.creatures[0]!;
  const todas = bestiary({ ...catalog, creatures: [...catalog.creatures, sombra] });

  // La cuenta de humo no dirige ninguna campaña, y el Bestiario abre igual.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  const escrituras = vigilarEscrituras(page);
  await page.goto('/v2/dm');
  await page.getByRole('navigation', { name: 'Herramientas del DM' }).getByRole('link', { name: 'Bestiario' }).click();
  await expect(page).toHaveURL('/v2/dm/bestiario');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Bestiario');
  await expect(page.getByText(`Solo lectura · ${todas.length} criaturas`)).toBeVisible();
  await expect(page.getByRole('group', { name: 'Modo' }).locator('[aria-current="true"]')).toHaveText('DM');
  await expect(page.locator(`${lista} [data-entry]`)).toHaveCount(todas.length);

  // El perfil abre en una URL del Modo DM, con lo que deriva el motor.
  await page.locator(`[data-entry="${sombra.id}"]`).click();
  await expect(page).toHaveURL(`/v2/dm/bestiario/${sombra.id}`);
  const detalle = page.locator('[data-field="creature-detail"]');
  await expect(detalle.getByRole('heading', { level: 2 })).toHaveText('Sombra de Humo');
  await expect(detalle).toContainText('Propio');
  await expect(detalle.locator('[data-actions="action"]')).toContainText('Roce helado');
  await expect(page.getByRole('navigation', { name: 'Herramientas del DM' }).getByRole('link', { name: 'Bestiario' })).toHaveAttribute(
    'aria-current',
    'page',
  );
  expect(escrituras).toEqual([]);

  // El homebrew es de la cuenta: el DM de la mesa ve solo el catálogo oficial,
  // y sus campañas siguen en el panel.
  await context.clearCookies();
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  await page.goto('/v2/dm/bestiario');
  await expect(page.locator(`${lista} [data-entry]`)).toHaveCount(bestiary(catalog).length);
  await expect(page.locator(`[data-entry="${sombra.id}"]`)).toHaveCount(0);
  await expect(page.getByRole('navigation', { name: 'Campañas' }).getByRole('link', { name: 'La Marca del Cuervo' })).toBeVisible();
});

test('el DM no escribe la ficha del jugador: leerla no la cambia', async ({ request }) => {
  const leer = async () =>
    JSON.stringify((await api<{ characters: unknown[] }>(request, '/api/characters', TOKEN)).characters);
  const antes = await leer();
  await api(request, `/api/campaigns/${CAMPANA}/members`, TOKEN_DM);
  expect(await leer()).toBe(antes);
});

test('otra cuenta recibe 404 al pedir la campaña, idéntico al de una inexistente, y no ve nada del DM en /v2', async ({
  context,
  page,
  baseURL,
}) => {
  for (const token of [TOKEN, TOKEN_SIN_V2]) {
    for (const ruta of ['members', 'chapters', 'notebook']) {
      const ajena = await page.request.get(`/api/campaigns/${CAMPANA}/${ruta}`, {
        headers: { cookie: `dnd_session=${token}` },
      });
      const inexistente = await page.request.get(`/api/campaigns/no-existe/${ruta}`, {
        headers: { cookie: `dnd_session=${token}` },
      });
      expect(ajena.status(), `${ruta} con otra cuenta`).toBe(404);
      expect(inexistente.status()).toBe(404);
      expect(await ajena.text()).toBe(await inexistente.text());
    }
    // La lista de campañas de otra cuenta no incluye la del DM.
    const { campaigns } = await api<{ campaigns: unknown[] }>(page.request, '/api/campaigns', token);
    expect(JSON.stringify(campaigns)).not.toContain(CAMPANA);
  }

  // Con webV2 pero sin esa campaña: la pantalla responde lo mismo que ante un
  // id inexistente, y ni el nombre ni los jugadores aparecen.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  for (const id of [CAMPANA, 'no-existe']) {
    await page.goto(`/v2/dm/campanas/${id}/mesa`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('No se encontró la campaña');
  }
  // Tampoco la ficha de un miembro: la URL con un vínculo real no abre nada.
  const { members } = await api<{ members: { memberId: string }[] }>(page.request, `/api/campaigns/${CAMPANA}/members`, TOKEN_DM);
  await page.goto(`/v2/dm/campanas/${CAMPANA}/mesa/${members[0]!.memberId}/personaje`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('No se encontró la campaña');
  const texto = await page.locator('body').innerText();
  for (const secreto of SOLO_DEL_DM) expect(texto, `la pantalla muestra «${secreto}»`).not.toContain(secreto);
  await expect(page.locator('[data-member]')).toHaveCount(0);

  // Sin campañas propias, «DM» no tiene a dónde llevar: lo dice.
  await page.goto('/v2/dm');
  await expect(page.getByText('Todavía no dirigís ninguna campaña.')).toBeVisible();
});
