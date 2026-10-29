import { useEffect, useMemo } from 'react';
import { ArrowLeft } from 'lucide-react';
import { ApiError } from '../../api/client';
import { useNpc, useSheetCatalog } from '../../api/queries';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcSheetHref, dmNpcsHref, Link, navigate, NPC_SHEET_TABS, type SheetTab } from '../../router';
import { computeModel } from '../../sheet/compute';
import { SheetTabs } from '../../sheet/SheetTabs';
import { AppBusyLabel, AppErrorView, Notice } from '../../ui/status';

/**
 * La ficha completa de un PNJ con ficha de personaje (Flutter abre
 * `SheetScreen` en `npcMode`), de solo lectura: la misma ficha que la de un
 * jugador, sin Campaña ni Diario, que en un PNJ son su trasfondo y sus notas y
 * ya están en su ficha de la Biblioteca. Sale del mismo `GET /api/npcs/:id`: un
 * PNJ ajeno, uno inexistente y uno sin ficha dicen lo mismo, «No se encontró».
 */
export function NpcSheetView({ npcId, tab }: { npcId: string; tab: SheetTab | null }) {
  const t = useTexts();
  const lang = useLang();
  const stored = useNpc(npcId);
  const catalog = useSheetCatalog(lang);

  useEffect(() => {
    if (tab === null) navigate(dmNpcSheetHref(npcId), { replace: true });
  }, [npcId, tab]);

  const raw = stored.data?.character ?? null;
  const computed = useMemo(() => (raw && catalog.data ? computeModel(raw, catalog.data) : null), [raw, catalog.data]);

  const back = (
    <Link href={dmNpcsHref(npcId)} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {stored.data?.npc.name || t.dmNpcLibrary}
    </Link>
  );

  const failed = [stored, ...catalog.queries].filter((q) => q.isError);
  let body;
  if ((stored.error instanceof ApiError && stored.error.status === 404) || (stored.data && !raw)) {
    body = <Notice title={t.npcNotFound} body={t.npcNotFoundBody} />;
  } else if (failed.length > 0) {
    body = <AppErrorView as="h1" title={t.npcReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!computed) {
    body = <AppBusyLabel label={t.npcLoading} />;
  } else if (!computed.ok) {
    body = <AppErrorView as="h1" title={t.computeErrorTitle} message={t.computeErrorBody} detail={computed.detail} />;
  } else {
    body = (
      <SheetTabs
        model={computed.model}
        tabs={NPC_SHEET_TABS}
        active={tab ?? 'personaje'}
        hrefOf={(tabId) => dmNpcSheetHref(npcId, tabId)}
      />
    );
  }

  return (
    <div className="flex flex-col gap-4" data-npc-sheet={npcId}>
      {back}
      {body}
    </div>
  );
}
