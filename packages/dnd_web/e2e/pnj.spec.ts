import { readFile } from 'node:fs/promises';
import { expect, test } from '@playwright/test';
import { textsFor } from '../src/i18n/texts';
import { api, TOKEN, TOKEN_DM } from './helpers';

test.use({ locale: 'es-AR' });

const t = textsFor('es');
const BIBLIOTECA = '/v2/dm/pnj';

// Lo que el DM escribió de sus PNJ (ver `_seedNpcs` en `e2e_server.dart`) y
// no tiene que llegarle a ninguna otra cuenta.
const SOLO_DEL_DM = ['Voz reservada del DM', 'Trasfondo reservado del DM', 'Nota reservada del PNJ', 'Vesna la Cuervo'];

test('los PNJ del DM no llegan a otra cuenta: lo ajeno responde igual que lo inexistente', async ({ context, page, baseURL }) => {
  // En la API: la otra cuenta tiene la biblioteca vacía, y pedir un PNJ del DM
  // da el mismo 404 que uno que no existe.
  const pedir = (path: string) => page.request.get(path, { headers: { cookie: `dnd_session=${TOKEN}` } });
  const { npcs } = await api<{ npcs: unknown[] }>(page.request, '/api/npcs', TOKEN);
  expect(npcs).toEqual([]);
  const ajeno = await pedir('/api/npcs/garrick');
  const inexistente = await pedir('/api/npcs/no-existe');
  expect(ajeno.status()).toBe(404);
  expect(inexistente.status()).toBe(404);
  expect(await ajeno.text()).toBe(await inexistente.text());
  // Los PNJ de una mesa ajena, igual que los de una que no existe.
  const mesaAjena = await pedir('/api/campaigns/marca-del-cuervo/npcs');
  const mesaInexistente = await pedir('/api/campaigns/no-existe/npcs');
  expect(mesaAjena.status()).toBe(404);
  expect(await mesaAjena.text()).toBe(await mesaInexistente.text());

  // Ni por la campaña del jugador: nada de lo que el DM escribió de sus PNJ.
  const jugador = JSON.stringify(await api<unknown>(page.request, '/api/characters/elsbeth-de-humo/campaigns', TOKEN));
  for (const secreto of SOLO_DEL_DM) expect(jugador, `la API del jugador manda «${secreto}»`).not.toContain(secreto);

  // En la pantalla: la misma «No se encontró» para el ajeno y el inexistente.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN, url: baseURL! }]);
  for (const id of ['garrick', 'no-existe']) {
    await page.goto(`${BIBLIOTECA}/${id}`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.npcNotFound);
  }
  // Tampoco la ficha completa del PNJ con ficha.
  for (const id of ['vesna', 'no-existe']) {
    await page.goto(`${BIBLIOTECA}/${id}/ficha/personaje`);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.npcNotFound);
  }
  await page.goto('/v2/dm/campanas/marca-del-cuervo/pnj');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(t.dmCampaignNotFound);
  for (const secreto of SOLO_DEL_DM) await expect(page.getByText(secreto)).toHaveCount(0);
});

// La cuenta de `transferencias.spec.ts`: sin PNJ ni campañas, y no la usa ninguna otra prueba
// que cuente PNJ o mesas, así que importar acá no mueve lo que miran las demás.
const TOKEN_TRANSFERENCIA = 'sesion-de-transferencia=';

test('exporta un PNJ y el ZIP se importa como copia en una campaña', async ({ context, page, request, baseURL }) => {
  // Odile viene sembrada con retrato (`_seedNpcs`): el ZIP tiene que llevarlo.
  await context.addCookies([{ name: 'dnd_session', value: TOKEN_DM, url: baseURL! }]);
  await page.goto(`${BIBLIOTECA}/odile`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('La hermana Odile');
  await page.getByRole('button', { name: t.npcMoreActions, exact: true }).click();
  await page.getByRole('menuitem', { name: t.npcExport, exact: true }).click();
  const exportar = page.getByRole('dialog', { name: t.npcExportTitle });
  const descarga = page.waitForEvent('download');
  await exportar.getByRole('button', { name: t.npcDownloadZip, exact: true }).click();
  const zip = await descarga;
  expect(zip.suggestedFilename()).toBe('la-hermana-odile.zip');
  const buffer = await readFile((await zip.path())!);
  await expect(exportar).toHaveCount(0);

  // Otra cuenta, con una campaña propia donde sumar la copia.
  const comoDestino = { headers: { cookie: `dnd_session=${TOKEN_TRANSFERENCIA}` } };
  await request.post('/api/campaigns', { ...comoDestino, data: { campaign: { id: 'mesa-de-importacion', name: 'Mesa de importación' } } });
  try {
    await context.addCookies([{ name: 'dnd_session', value: TOKEN_TRANSFERENCIA, url: baseURL! }]);
    await page.goto(BIBLIOTECA);
    await page.locator('[data-action="new-npc"]').waitFor();
    await page.getByRole('button', { name: t.npcImport, exact: true }).click();
    const importar = page.getByRole('dialog', { name: t.npcImport });
    await importar.getByLabel(t.npcPickFile).setInputFiles({ name: zip.suggestedFilename(), mimeType: 'application/zip', buffer });
    await expect(importar.locator('[data-field="npc-import-preview"]')).toContainText('La hermana Odile');
    await importar.getByRole('combobox', { name: t.npcAlsoAddToCampaign }).click();
    await page.getByRole('option', { name: 'Mesa de importación', exact: true }).click();
    await importar.getByRole('button', { name: t.transferConfirm, exact: true }).click();
    await expect(importar).toHaveCount(0);
    await expect(page.getByText(t.npcImported('La hermana Odile'), { exact: true }).first()).toBeVisible();
    await expect(page.locator('[data-npc]').filter({ hasText: 'La hermana Odile' })).toHaveCount(1);

    // La copia es de la cuenta nueva, con el retrato y en la campaña elegida.
    const { npcs } = await api<{ npcs: { npc: { id: string; portraitPaths?: string[] }; campaigns: { campaignId: string }[] }[] }>(
      request,
      '/api/npcs',
      TOKEN_TRANSFERENCIA,
    );
    expect(npcs).toHaveLength(1);
    expect(npcs[0]!.npc.portraitPaths).toHaveLength(1);
    expect(npcs[0]!.campaigns.map((c) => c.campaignId)).toEqual(['mesa-de-importacion']);
    await request.delete(`/api/npcs/${npcs[0]!.npc.id}`, comoDestino);
  } finally {
    await request.delete('/api/campaigns/mesa-de-importacion', comoDestino);
  }
});
