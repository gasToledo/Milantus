import { useEffect } from 'react';
import { Plus } from 'lucide-react';
import type { Account } from '../api/client';
import { useDmCampaigns } from '../api/queries';
import { RosterFooter } from '../dashboard/RosterPanel';
import { useTexts } from '../i18n/context';
import { dmCampaignHref, FLUTTER_HOME, navigate, type DmView } from '../router';
import { ButtonLink } from '../ui/Button';
import { Shell } from '../ui/Shell';
import { AppBusyLabel, AppEmptyState, AppErrorView, Notice } from '../ui/status';
import { defaultCampaign } from './campaigns';
import { DmHeader } from './DmHeader';
import { DmPanel } from './DmPanel';
import { BestiaryPage } from '../bestiary/BestiaryPage';
import { ChaptersView } from './ChaptersView';
import { MesaView } from './MesaView';
import { NotebookView } from './NotebookView';

/**
 * El Modo DM de solo lectura (`/v2/dm/...`). Lo que el DM escribe (crear y
 * editar campañas, capítulos, notas, el combate, la música) sigue en Flutter;
 * acá se lee. Cada pedido pasa por la API de campañas, cuya autorización va
 * adentro del `WHERE`: una campaña ajena y una inexistente responden igual
 * (404), y la pantalla tampoco las distingue.
 */
export function DmPage({ view, account }: { view: DmView; account: Account }) {
  const t = useTexts();
  const campaigns = useDmCampaigns();
  const list = campaigns.data;

  // `/v2/dm` a secas no es una pantalla: lleva a la primera campaña. Con
  // `replace` para que «atrás» no vuelva a una URL que solo redirige.
  const target = view.kind === 'home' && list ? defaultCampaign(list) : undefined;
  useEffect(() => {
    if (target) navigate(dmCampaignHref(target.id), { replace: true });
  }, [target]);

  const current =
    view.kind === 'campaign' && list
      ? (() => {
          const campaign = list.find((c) => c.id === view.id);
          return campaign ? { campaign, section: view.section } : undefined;
        })()
      : undefined;

  let body;
  if (view.kind === 'bestiary') {
    // El Bestiario no depende de las campañas: se abre también sin ninguna y
    // cuando la lista no cargó (el panel lo dice solo).
    body = <BestiaryPage entryId={view.entryId} dm />;
  } else if (campaigns.isError) {
    body = (
      <>
        <DmHeader title={t.dmCampaignsLabel} />
        <AppErrorView title={t.dmCampaignsLoadFail} message={t.errorBody} onRetry={() => campaigns.refetch()} />
      </>
    );
  } else if (!list || target) {
    body = (
      <>
        <DmHeader title={t.dmCampaignsLabel} />
        <AppBusyLabel label={t.dmCampaignsLoading} />
      </>
    );
  } else if (view.kind === 'home') {
    // Sin ninguna campaña: crear es una escritura, y vive en Flutter.
    body = (
      <>
        <DmHeader title={t.dmCampaignsLabel} />
        <AppEmptyState
          kind="empty"
          message={t.dmNoCampaigns}
          hint={t.dmNoCampaignsHint}
          actions={
            <ButtonLink href={FLUTTER_HOME} icon={Plus} tone="secondary">
              {t.dmCreateCampaign}
            </ButtonLink>
          }
        />
      </>
    );
  } else if (!current) {
    body = <Notice title={t.dmCampaignNotFound} body={t.dmCampaignNotFoundBody} />;
  } else {
    const Section = { mesa: MesaView, capitulos: ChaptersView, cuaderno: NotebookView }[current.section];
    body = <Section key={current.campaign.id} campaign={current.campaign} />;
  }

  return (
    <Shell panel={<DmPanel campaigns={list} current={current} tool={view.kind === 'bestiary' ? 'bestiary' : undefined} />} footer={<RosterFooter account={account} dm />}>
      {body}
    </Shell>
  );
}
