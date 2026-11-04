// Lo que se escribe en la ficha de un PNJ: la acción la aplica el motor, se ve al
// instante en la caché y se guarda en fila (`api/npcSave.ts`).
import { useMemo } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { type StoredNpc } from '../../api/client';
import { latestNpcDoc, scheduleNpcSave, type NpcDoc } from '../../api/npcSave';
import { queryKeys } from '../../api/queries';
import { npcEdit, type NpcAction } from '../../engine';

export interface NpcWriter {
  /** `before` es el documento de antes, para «Deshacer»; `null` si el motor no pudo. */
  edit(action: NpcAction): { before: NpcDoc } | null;
  restore(before: NpcDoc): void;
}

export function useNpcWriter(npcId: string, onFailed: () => void): NpcWriter {
  const client = useQueryClient();
  return useMemo(() => {
    const put = (doc: NpcDoc) => {
      // Una lectura en vuelo traería el documento de antes y pisaría lo escrito.
      void client.cancelQueries({ queryKey: queryKeys.npcs });
      client.setQueryData<StoredNpc>(queryKeys.npc(npcId), (old) => old && { ...old, npc: doc });
      client.setQueryData<StoredNpc[]>(queryKeys.npcs, (old) => old?.map((e) => (e.npc.id === npcId ? { ...e, npc: doc } : e)));
      scheduleNpcSave(doc, (ok) => {
        if (!ok) return onFailed();
        // Con la fila vacía: el nombre y los tags también se ven en la mesa de cada
        // campaña, y el combate lee esa misma lista.
        void client.invalidateQueries({ queryKey: queryKeys.npcs });
        void client.invalidateQueries({
          predicate: (q) => q.queryKey[0] === 'dm' && q.queryKey[1] === 'campaigns' && q.queryKey[3] === 'npcs',
        });
      });
    };
    return {
      edit(action) {
        // La base es lo último que se pidió guardar y no la caché: una relectura por
        // otra escritura (el estado de una campaña) puede haberla atrasado.
        const before = latestNpcDoc(npcId) ?? (client.getQueryData<StoredNpc>(queryKeys.npc(npcId))?.npc as NpcDoc | undefined);
        if (!before) return null;
        try {
          put(npcEdit(before, action));
          return { before };
        } catch {
          onFailed();
          return null;
        }
      },
      restore: put,
    };
  }, [client, npcId, onFailed]);
}
