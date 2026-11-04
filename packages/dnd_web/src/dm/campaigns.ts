// Presentación de la lista de campañas del DM. El estado se lee tolerante, como
// `CampaignState.fromJson`: ausente o desconocido es «en curso», que es el
// estado en que nace toda campaña.
import { useQueryClient, type QueryClient } from '@tanstack/react-query';
import { ApiError, createCampaign, fetchDmCampaigns, saveCampaign, type DmCampaign } from '../api/client';
import { queryKeys } from '../api/queries';
import { dmCampaignHref, navigate } from '../router';
import type { Texts } from '../i18n/texts';
import type { CampaignDraft } from './CampaignEditorDialog';

/**
 * Cambia la campaña **releyéndola antes de escribir**: las escenas de música y
 * el orden de la Mesa viven en el mismo documento y el PUT lo reemplaza entero,
 * así que escribir sobre la copia que cargó la pantalla pisaría con lo que
 * tuviera de viejo. Quien llama recibe la última y devuelve la que se guarda.
 */
export async function editCampaign(
  client: QueryClient,
  campaignId: string,
  change: (latest: DmCampaign) => DmCampaign,
): Promise<void> {
  const latest = (await fetchDmCampaigns(new AbortController().signal)).find((c) => c.id === campaignId);
  if (!latest) throw new ApiError(404, `/api/campaigns/${campaignId}`);
  await saveCampaign(change(latest));
  await client.invalidateQueries({ queryKey: queryKeys.dmCampaigns });
}

export type CampaignState = 'active' | 'paused' | 'finished';

export function stateOf(campaign: DmCampaign): CampaignState {
  return campaign.state === 'paused' || campaign.state === 'finished' ? campaign.state : 'active';
}

/** Las campañas por estado, cada grupo en el orden en que las devuelve el
 *  servidor (el mismo que Flutter). */
export function groupCampaigns(campaigns: readonly DmCampaign[]): Record<CampaignState, DmCampaign[]> {
  return {
    active: campaigns.filter((c) => stateOf(c) === 'active'),
    paused: campaigns.filter((c) => stateOf(c) === 'paused'),
    finished: campaigns.filter((c) => stateOf(c) === 'finished'),
  };
}

/** A qué campaña lleva `/v2/dm` a secas: la primera en curso y, si no hay,
 *  la primera que haya (Flutter abre la primera en vez de un panel vacío). */
export function defaultCampaign(campaigns: readonly DmCampaign[]): DmCampaign | undefined {
  return campaigns.find((c) => stateOf(c) === 'active') ?? campaigns[0];
}

/** «En curso», «En pausa» o «Terminada». */
export function stateLabel(t: Texts, state: CampaignState): string {
  return { active: t.campaignStateActive, paused: t.campaignStatePaused, finished: t.campaignStateFinished }[state];
}

/** Crear una campaña y abrirla en su Mesa: lo comparten el panel y la
 *  bienvenida. Se navega al id que **devuelve** el servidor, porque lo cambia
 *  si el pedido choca con otra campaña. */
export function useCreateCampaign(): (draft: CampaignDraft) => Promise<void> {
  const client = useQueryClient();
  return async ({ name, premise, state }) => {
    const saved = await createCampaign({ id: campaignIdFrom(name), name, premise, state });
    await client.invalidateQueries({ queryKey: queryKeys.dmCampaigns });
    navigate(dmCampaignHref(saved.id, 'mesa'));
  };
}

/** El id con que se pide una campaña nueva, de su nombre (`_idFrom` de
 *  `campaigns_controller.dart`). No es una regla del juego: solo un nombre
 *  legible para la URL, y el servidor resuelve las colisiones. */
export function campaignIdFrom(name: string): string {
  const id = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40)
    .replace(/-+$/, '');
  return id === '' ? String(Date.now()) : id;
}
