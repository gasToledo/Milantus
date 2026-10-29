// Presentación de la lista de campañas del DM. El estado se lee tolerante, como
// `CampaignState.fromJson`: ausente o desconocido es «en curso», que es el
// estado en que nace toda campaña.
import type { DmCampaign } from '../api/client';
import type { Texts } from '../i18n/texts';

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
