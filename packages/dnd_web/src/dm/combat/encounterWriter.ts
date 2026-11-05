// Lo que se escribe en el combate de una campaña: la acción la aplica el motor
// (`encounterAct`), se ve al instante en la caché y se guarda entero por una cola
// (`api/saveQueue.ts`). Descartar no pasa por la cola: es un borrado.
import { useMemo } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { discardCampaignEncounter, saveCampaignEncounter } from '../../api/client';
import { queryKeys } from '../../api/queries';
import { createSaveQueue } from '../../api/saveQueue';
import { encounterAct, type Catalog, type EncounterAction, type JsonObject } from '../../engine';

// La clave es la campaña: hay un solo combate abierto por campaña.
const queue = createSaveQueue<JsonObject>((campaignId, doc) => saveCampaignEncounter(campaignId, doc));

export const retryEncounterSave = (campaignId: string): void => queue.retry(campaignId);

export function useEncounterWriter(
  campaignId: string,
  catalog: Catalog | undefined,
  onFailed: () => void,
): { act(action: EncounterAction): void; discard(): Promise<void> } {
  const client = useQueryClient();
  return useMemo(() => {
    const key = queryKeys.campaignEncounter(campaignId);
    return {
      act(action) {
        if (!catalog) return;
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
        // Una lectura en vuelo traería el combate de antes y pisaría lo escrito.
        void client.cancelQueries({ queryKey: key });
        client.setQueryData<JsonObject | null>(key, doc);
        queue.schedule(campaignId, doc, (ok) => {
          if (!ok) return onFailed();
          // Una lectura que entró entre el guardado y su respuesta pudo dejar la
          // caché con otra copia: lo guardado es lo que manda.
          client.setQueryData<JsonObject | null>(key, doc);
        });
      },
      async discard() {
        // Primero se olvida lo pendiente: un guardado viejo que llegara después
        // del borrado volvería a crear el combate.
        await queue.drop(campaignId);
        await discardCampaignEncounter(campaignId);
        client.setQueryData<JsonObject | null>(key, null);
      },
    };
  }, [client, campaignId, catalog, onFailed]);
}
