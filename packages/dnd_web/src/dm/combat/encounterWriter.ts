// Lo que se escribe en el combate de una campaña: la acción la aplica el motor
// (`encounterAct`), se ve al instante en la caché y se guarda entero por una cola
// (`api/saveQueue.ts`). Descartar no pasa por la cola: es un borrado.
import { useMemo } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { convertCampaignCombatant, discardCampaignEncounter, endCampaignEncounter, saveCampaignEncounter } from '../../api/client';
import { queryKeys } from '../../api/queries';
import { createSaveQueue } from '../../api/saveQueue';
import { encounterAct, newNpc, type Catalog, type EncounterAction, type JsonObject } from '../../engine';

// La clave es la campaña: hay un solo combate abierto por campaña.
const queue = createSaveQueue<JsonObject>((campaignId, doc) => saveCampaignEncounter(campaignId, doc));
// Otra acción puede reemplazar el guardado de «Armar» en la cola. La oferta
// sigue al id del combate hasta que se confirme, incluso si hay que reintentar.
const pendingOpens = new Map<string, string>();
const converting = new Set<string>();

export const retryEncounterSave = (campaignId: string): void => queue.retry(campaignId);

export function useEncounterWriter(
  campaignId: string,
  catalog: Catalog | undefined,
  onFailed: () => void,
  onMusicOffer: (campaignId: string, show: boolean) => void,
) {
  const client = useQueryClient();
  return useMemo(() => {
    const key = queryKeys.campaignEncounter(campaignId);
    return {
      act(action: EncounterAction) {
        if (!catalog) return;
        if (converting.has(campaignId)) return onFailed();
        // La base es lo último que se pidió guardar y no la caché sola: una relectura
        // en vuelo puede haberla atrasado, y sumar sobre ella perdería lo anterior.
        const base = queue.latest(campaignId) ?? client.getQueryData<JsonObject | null>(key) ?? null;
        let next: JsonObject | null;
        try {
          next = encounterAct(catalog, base, action);
        } catch {
          // Un tipo desconocido o una criatura inexistente: mejor avisar que creer
          // que se guardó.
          return onFailed();
        }
        // `null` es que no hay nada que guardar (ya estaba, no cambia nada).
        if (!next) return;
        const doc = next;
        if (action.type === 'open' && !base && typeof doc.id === 'string') pendingOpens.set(campaignId, doc.id);
        // Una lectura en vuelo traería el combate de antes y pisaría lo escrito.
        void client.cancelQueries({ queryKey: key });
        client.setQueryData<JsonObject | null>(key, doc);
        queue.schedule(campaignId, doc, (ok) => {
          if (!ok) return onFailed();
          // Una lectura que entró entre el guardado y su respuesta pudo dejar la
          // caché con otra copia: lo guardado es lo que manda.
          client.setQueryData<JsonObject | null>(key, doc);
          const openingId = pendingOpens.get(campaignId);
          if (openingId && openingId === doc.id) {
            pendingOpens.delete(campaignId);
            onMusicOffer(campaignId, true);
          }
        });
      },
      async discard() {
        if (converting.has(campaignId)) throw new Error('Hay una conversión en curso.');
        // Primero se olvida lo pendiente: un guardado viejo que llegara después
        // del borrado volvería a crear el combate.
        pendingOpens.delete(campaignId);
        await queue.drop(campaignId);
        await discardCampaignEncounter(campaignId);
        client.setQueryData<JsonObject | null>(key, null);
        onMusicOffer(campaignId, false);
      },
      async close(deadNpcIds: string[]) {
        if (converting.has(campaignId)) throw new Error('Hay una conversión en curso.');
        // El servidor archiva la copia guardada. Esperamos el último cambio
        // para que entre en el registro y ningún guardado recree el combate.
        await queue.flush(campaignId);
        await endCampaignEncounter(campaignId, deadNpcIds);
        await client.cancelQueries({ queryKey: key });
        client.setQueryData<JsonObject | null>(key, null);
        onMusicOffer(campaignId, false);
        void client.invalidateQueries({ queryKey: queryKeys.campaignNotebook(campaignId) });
        void client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(campaignId) });
        void client.invalidateQueries({ queryKey: queryKeys.npcs });
      },
      async convert(encounterId: string, combatantId: string, creatureId: string, name: string) {
        if (!catalog || converting.has(campaignId)) throw new Error('No se puede convertir el combatiente ahora.');
        converting.add(campaignId);
        try {
          // El servidor convierte lo guardado, incluidos los últimos PG y efectos.
          await queue.flush(campaignId);
          const npc = newNpc(catalog, name, 'block', creatureId);
          const next = await convertCampaignCombatant(campaignId, encounterId, combatantId, npc)
            .catch(async (error: unknown) => {
              // Si se perdió la respuesta y el DM cancela, la próxima acción
              // no debe guardar encima la copia que aún mostraba un monstruo.
              await client.invalidateQueries({ queryKey: key, refetchType: 'all' });
              throw error;
            })
            .finally(() => {
              void client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(campaignId) });
              void client.invalidateQueries({ queryKey: queryKeys.npcs });
            });
          await client.cancelQueries({ queryKey: key });
          client.setQueryData<JsonObject | null>(key, next);
        } finally {
          converting.delete(campaignId);
        }
      },
    };
  }, [client, campaignId, catalog, onFailed, onMusicOffer]);
}
