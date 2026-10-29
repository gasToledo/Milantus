import { useEffect, useMemo } from 'react';
import { ArrowLeft } from 'lucide-react';
import type { DmCampaign } from '../api/client';
import { useCampaignMembers, useSheetCatalog } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { dmCampaignHref, dmMemberHref, Link, MEMBER_SHEET_TABS, navigate, type SheetTab } from '../router';
import { computeModel } from '../sheet/compute';
import { SheetTabs } from '../sheet/SheetTabs';
import { accentFor } from '../sheet/model';
import { Medallion } from '../ui/Medallion';
import { memberPortrait } from '../ui/portrait';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';

/**
 * La ficha completa de un jugador de la Mesa (`MemberSheetScreen` de Flutter),
 * de solo lectura: la misma ficha que ve el jugador, con las pestañas que
 * sirven en combate. El DM no escribe la ficha de otra cuenta: no hay ningún
 * control, y la ficha se lee de la misma consulta que la Mesa (`GET
 * /api/campaigns/:id/members`), sin otra puerta entre cuentas.
 *
 * Como en Flutter, se lee al entrar y no se sondea: un espacio de conjuro que
 * cambia solo, sin que pase nada delante del DM, se lee como un error.
 */
export function MemberSheetView({
  campaign,
  memberId,
  tab,
}: {
  campaign: DmCampaign;
  memberId: string;
  tab: SheetTab | null;
}) {
  const t = useTexts();
  const lang = useLang();
  const members = useCampaignMembers(campaign.id);
  const catalog = useSheetCatalog(lang);

  useEffect(() => {
    if (tab === null) navigate(dmMemberHref(campaign.id, memberId), { replace: true });
  }, [campaign.id, memberId, tab]);

  const raw = members.data?.find((m) => m.memberId === memberId)?.character ?? null;
  // El catálogo del DM (SRD más **su** homebrew), como la Mesa y Flutter.
  const computed = useMemo(() => (raw && catalog.data ? computeModel(raw, catalog.data) : null), [raw, catalog.data]);

  const back = (
    <Link
      href={dmCampaignHref(campaign.id)}
      className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold"
    >
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.dmSectionTable}
    </Link>
  );

  const failed = [members, ...catalog.queries].filter((q) => q.isError);
  let body;
  if (failed.length > 0) {
    body = <AppErrorView as="h1" title={t.dmSheetReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (members.data && !raw) {
    // Un vínculo cortado y uno que nunca existió son lo mismo: la fila de
    // `campaign_members` ya no está.
    body = (
      <>
        <h1 className="sr-only">{t.dmSectionTable}</h1>
        <AppEmptyState kind="empty" message={t.dmSheetGone} />
      </>
    );
  } else if (!computed) {
    body = <AppBusyLabel label={t.dmSheetLoading} />;
  } else if (!computed.ok) {
    body = <AppErrorView as="h1" title={t.computeErrorTitle} message={t.computeErrorBody} detail={computed.detail} />;
  } else {
    body = (
      <SheetTabs
        model={computed.model}
        tabs={MEMBER_SHEET_TABS}
        active={tab ?? 'personaje'}
        hrefOf={(tabId) => dmMemberHref(campaign.id, memberId, tabId)}
        leading={
          <Medallion
            name={computed.model.character.name}
            accent={accentFor(computed.model)}
            size={64}
            portrait={memberPortrait(campaign.id, memberId, computed.model.character)}
            viewable
          />
        }
      />
    );
  }

  return (
    <div className="flex flex-col gap-4" data-member-sheet={memberId}>
      {back}
      {body}
    </div>
  );
}
