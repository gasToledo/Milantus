// Las escrituras del vínculo entre un PNJ y una campaña. Viven juntas porque las
// tres tienen que releer lo mismo: la lista de la mesa, la biblioteca y la ficha.
import { useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { linkCampaignNpc, unlinkCampaignNpc, type CampaignNpc, type StoredNpc } from '../../api/client';
import { queryKeys } from '../../api/queries';
import type { NpcStatus } from './npc';

export function useNpcLinks(onStatusError: () => void) {
  const client = useQueryClient();
  // En fila, como las escenas de música: dos toques seguidos no pueden llegar al
  // servidor al revés, porque el último que llega es el que queda.
  const queue = useRef<Promise<void>>(Promise.resolve());
  const pending = useRef(0);

  // `queryKeys.npcs` es prefijo de `queryKeys.npc(id)`: alcanza para las dos.
  const refresh = (campaignId: string) =>
    Promise.all([
      client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(campaignId) }),
      client.invalidateQueries({ queryKey: queryKeys.npcs }),
    ]);

  const setStatus = (campaignId: string, npcId: string, status: NpcStatus) => {
    // Una lectura en vuelo traería el estado de antes y pisaría el recién elegido.
    void client.cancelQueries({ queryKey: queryKeys.campaignNpcs(campaignId) });
    void client.cancelQueries({ queryKey: queryKeys.npcs });
    const patchLinks = (entry: StoredNpc): StoredNpc =>
      entry.npc.id !== npcId
        ? entry
        : { ...entry, campaigns: entry.campaigns.map((l) => (l.campaignId === campaignId ? { ...l, status } : l)) };
    client.setQueryData<CampaignNpc[]>(queryKeys.campaignNpcs(campaignId), (old) =>
      old?.map((e) => (e.npc.id === npcId ? { ...e, status } : e)),
    );
    client.setQueryData<StoredNpc[]>(queryKeys.npcs, (old) => old?.map(patchLinks));
    client.setQueryData<StoredNpc>(queryKeys.npc(npcId), (old) => old && patchLinks(old));

    pending.current += 1;
    queue.current = queue.current
      .then(() => linkCampaignNpc(campaignId, npcId, status))
      .catch(onStatusError)
      .then(() => {
        pending.current -= 1;
        // Releer recién con la fila vacía: antes traería lo que un toque más
        // nuevo todavía no guardó. También deshace lo local si algo falló, y
        // trae los PG que el servidor borra a quien vuelve de la muerte.
        if (pending.current === 0) void refresh(campaignId);
      });
  };

  /** Uno por vez, y si uno falla los demás ya quedaron: reintentar no duplica
   *  nada, porque sumar sin estado no toca un vínculo existente. */
  const linkMany = async (pairs: { campaignId: string; npcId: string }[]) => {
    try {
      for (const { campaignId, npcId } of pairs) await linkCampaignNpc(campaignId, npcId);
    } finally {
      await Promise.all([...new Set(pairs.map((p) => p.campaignId))].map(refresh));
    }
  };

  const unlink = async (campaignId: string, npcId: string) => {
    await unlinkCampaignNpc(campaignId, npcId);
    await refresh(campaignId);
  };

  return { setStatus, linkMany, unlink };
}
