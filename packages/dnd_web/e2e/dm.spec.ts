import { expect, test } from '@playwright/test';
import { api, TOKEN, TOKEN_DM, TOKEN_SIN_V2, type PersonajeApi } from './helpers';

test.use({ locale: 'es-AR' });

const CAMPANA = 'marca-del-cuervo';
const MESA = `/v2/dm/campanas/${CAMPANA}/mesa`;

// Lo que el DM sembró y no tiene que llegarle a ninguna otra cuenta (ver
// `e2e_server.dart`).
const SOLO_DEL_DM = ['La Marca del Cuervo', 'Tema secreto del DM', 'Resumen reservado del DM', 'Nota reservada del DM'];

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

  const { members } = await api<{ members: { memberId: string; character: PersonajeApi }[] }>(
    page.request,
    `/api/campaigns/${CAMPANA}/members`,
    TOKEN_DM,
  );

  // El retrato del jugador es de su cuenta: el DM lo pide por el vínculo, y con
  // la clave tal cual recibe 404, como cualquier otra cuenta.
  const elsbeth = members.find((m) => m.character.id === 'elsbeth-de-humo')!;
  const clave = (elsbeth.character.portraitPaths as string[])[0]!;
  const pedirComoDm = (path: string) => page.request.get(path, { headers: { cookie: `dnd_session=${TOKEN_DM}` } });
  expect(
    (await pedirComoDm(`/api/campaigns/${CAMPANA}/members/${elsbeth.memberId}/portrait/${clave.split('/').pop()}`)).status(),
  ).toBe(200);
  expect((await pedirComoDm(`/api/portraits/${clave}`)).status()).toBe(404);

  // Con webV2 pero sin esa campaña: la pantalla responde lo mismo que ante un
  // id inexistente, y ni el nombre ni los jugadores aparecen.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  for (const id of [CAMPANA, 'no-existe']) {
    await page.goto(`/v2/dm/campanas/${id}/mesa`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('No se encontró la campaña');
  }
  // Tampoco la ficha de un miembro: la URL con un vínculo real no abre nada.
  await page.goto(`/v2/dm/campanas/${CAMPANA}/mesa/${members[0]!.memberId}/personaje`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('No se encontró la campaña');
  const texto = await page.locator('body').innerText();
  for (const secreto of SOLO_DEL_DM) expect(texto, `la pantalla muestra «${secreto}»`).not.toContain(secreto);
  await expect(page.locator('[data-member]')).toHaveCount(0);

  // Sin campañas propias, «DM» no tiene a dónde llevar: lo dice.
  await page.goto('/v2/dm');
  await expect(page.getByText('Todavía no dirigís ninguna campaña.')).toBeVisible();

  // Para el propio DM, un vínculo que no existe dice lo mismo que uno cortado.
  await context.clearCookies();
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  await page.goto(`${MESA}/no-existe/personaje`);
  await expect(page.getByText('Ya no ves esta ficha. Puede que te hayan cortado el vínculo.')).toBeVisible();
});
