// Las escrituras del vínculo entre un PNJ y una campaña. Viven juntas porque las
// tres tienen que releer lo mismo: la lista de la mesa, la biblioteca y la ficha.
import { useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { fetchCampaignNpcs, linkCampaignNpc, unlinkCampaignNpc, type CampaignNpc, type StoredNpc } from '../../api/client';
import { queryKeys } from '../../api/queries';
import type { NpcStatus } from './npc';

/** `useListTransition`: corre el cambio de la caché dentro de la animación. */
type Animate = (update: () => unknown) => void;

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
   *  nada, porque sumar sin estado no toca un vínculo existente.
   *
   *  Con [animate] (la sección PNJ de la campaña, `useListTransition`) la
   *  lista de la mesa se relee antes y entra a la caché dentro de la
   *  transición, que no puede esperar a la red. */
  const linkMany = async (pairs: { campaignId: string; npcId: string }[], animate?: Animate) => {
    try {
      for (const { campaignId, npcId } of pairs) await linkCampaignNpc(campaignId, npcId);
    } finally {
      const ids = [...new Set(pairs.map((p) => p.campaignId))];
      if (animate && ids.length === 1) {
        const key = queryKeys.campaignNpcs(ids[0]!);
        await client.cancelQueries({ queryKey: key });
        const fresh = await fetchCampaignNpcs(ids[0]!, new AbortController().signal);
        animate(() => client.setQueryData(key, fresh));
        void client.invalidateQueries({ queryKey: queryKeys.npcs });
      } else {
        await Promise.all(ids.map(refresh));
      }
    }
  };

  /** Con [animate], el PNJ sale de la caché dentro de la transición y la
   *  relectura va después. */
  const unlink = async (campaignId: string, npcId: string, animate?: Animate) => {
    await unlinkCampaignNpc(campaignId, npcId);
    if (!animate) return void (await refresh(campaignId));
    const key = queryKeys.campaignNpcs(campaignId);
    await client.cancelQueries({ queryKey: key });
    animate(() => client.setQueryData<CampaignNpc[]>(key, (old) => old?.filter((e) => e.npc.id !== npcId)));
    void refresh(campaignId);
  };

  return { setStatus, linkMany, unlink };
}
