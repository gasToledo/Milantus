import { useMemo } from 'react';
import { useCampaignChapters, useCampaignMembers, useSheetCatalog } from '../api/queries';
import type { DmCampaign } from '../api/client';
import { toRosterEntry } from '../dashboard/roster';
import { useLang, useTexts } from '../i18n/context';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { stateLabel, stateOf } from './campaigns';
import { DmHeader } from './DmHeader';
import { MemberCard } from './MemberCard';

/**
 * La Mesa: los personajes vinculados a la campaña, de solo lectura. Cada ficha
 * se lee en vivo de la cuenta del jugador y se calcula con el motor y el
 * catálogo del DM (SRD más **su** homebrew, como Flutter): un objeto propio del
 * jugador que el DM no tiene no se resuelve, y la tarjeta lo dice con la CA
 * que da el motor, no con una inventada.
 */
export function MesaView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const lang = useLang();
  const members = useCampaignMembers(campaign.id);
  const catalog = useSheetCatalog(lang);
  // Solo para decir en qué capítulo va la mesa: si falla, la cabecera calla.
  const chapters = useCampaignChapters(campaign.id);

  const entries = useMemo(() => {
    if (!members.data || !catalog.data) return null;
    const cat = catalog.data;
    // El vínculo no guarda cuándo se creó la ficha: `createdAt` no se usa acá.
    return members.data.map((m) => ({ memberId: m.memberId, entry: toRosterEntry(m.character, '', cat) }));
  }, [members.data, catalog.data]);

  const failed = [members, ...catalog.queries].filter((q) => q.isError);
  const state = stateLabel(t, stateOf(campaign));
  const running = chapters.data?.find((c) => c.state === 'active');
  // «En curso · El Valle Hueco»: la campaña y el capítulo en que va.
  const kicker = running ? `${state} · ${running.name}` : state;

  let body;
  if (failed.length > 0) {
    body = (
      <AppErrorView title={t.dmTableReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
    );
  } else if (!entries) {
    body = <AppBusyLabel label={t.dmTableLoading} />;
  } else if (entries.length === 0) {
    body = <AppEmptyState kind="empty" message={t.dmTableEmpty} hint={t.dmTableEmptyHint} />;
  } else {
    body = (
      <>
        <ul
          aria-label={t.dmTableCount(entries.length)}
          className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(min(320px,100%),1fr))]"
        >
          {entries.map(({ memberId, entry }) => (
            <MemberCard key={memberId} entry={entry} />
          ))}
        </ul>
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={campaign.name} kicker={kicker} />
      {body}
    </div>
  );
}
