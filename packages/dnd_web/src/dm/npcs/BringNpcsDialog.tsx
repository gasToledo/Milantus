import { useMemo } from 'react';
import { useNpcs, useSheetCatalog } from '../../api/queries';
import { npcViews } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { npcTypeLine } from './npc';
import { PickManyDialog } from './PickManyDialog';

/** Suma a esta campaña PNJ que ya están en la biblioteca. */
export function BringNpcsDialog({
  campaignId,
  onLink,
  onClose,
}: {
  campaignId: string;
  onLink: (pairs: { campaignId: string; npcId: string }[]) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const npcs = useNpcs();
  const catalog = useSheetCatalog(lang);
  const items = useMemo(() => {
    const stored = npcs.data;
    if (!stored || !catalog.data) return null;
    const views = npcViews(stored, catalog.data);
    return views
      .filter((_, i) => !stored[i]!.campaigns.some((l) => l.campaignId === campaignId))
      .map((v) => ({ id: v.npc.id, title: v.npc.name, detail: npcTypeLine(v, t) }));
  }, [npcs.data, catalog.data, campaignId, t]);
  const failed = [npcs, ...catalog.queries].filter((q) => q.isError);
  return (
    <PickManyDialog
      title={t.dmBringFromLibrary}
      searchLabel={t.dmSearchNpcs}
      items={items ?? []}
      loading={!items}
      loadError={failed.length > 0 ? t.dmLibraryReadFail : undefined}
      onRetryLoad={() => failed.forEach((q) => q.refetch())}
      emptyText={t.dmAllNpcsInCampaign}
      errorText={t.dmLinkError}
      onSubmit={(ids) => onLink(ids.map((npcId) => ({ campaignId, npcId })))}
      onClose={onClose}
    />
  );
}
