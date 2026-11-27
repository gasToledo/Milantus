import { useMemo, useState, type ReactNode } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { attachChapterScript, createScript, type DmCampaign, type DmChapter } from '../../api/client';
import { queryKeys, useCampaignChapters, useCampaignNpcs, useChapterScript, useScripts, useSheetCatalog } from '../../api/queries';
import { npcViews, scriptNew, scriptView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmCampaignHref, Link } from '../../router';
import { Button, ButtonLink } from '../../ui/Button';
import { useDeferredFocus } from '../../ui/focus';
import { Toast, type ToastTone } from '../../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { ChapterMenu, chapterStatusLabel } from '../ChapterMenu';
import { DmHeader } from '../DmHeader';
import { ChapterTabs } from './ChapterTabs';
import { PickOneDialog } from './ScriptDialogs';
import { ScriptEditor } from './ScriptEditor';

/** La pestaña Guion de un capítulo. Es del DM: ninguna cuenta de jugador recibe
 *  nada de esto (`modo-dm.md`). */
export function ChapterScriptView({ campaign, chapterId }: { campaign: DmCampaign; chapterId: string }) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const chapters = useCampaignChapters(campaign.id);
  const chapterScript = useChapterScript(campaign.id, chapterId);
  // Solo para los PG de los chips de PNJ: si no cargan, el chip va sin ellos.
  const npcs = useCampaignNpcs(campaign.id);
  const catalog = useSheetCatalog(lang);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string } | null>(null);
  const notify = (tone: ToastTone, message: string) => setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone, message }));
  // Cerrar el capítulo o quitar el guion se lleva lo que tenía el foco.
  const setFocusTarget = useDeferredFocus(`${chapterScript.dataUpdatedAt} ${chapters.dataUpdatedAt}`);

  const chapter = chapters.data?.find((c) => c.id === chapterId);
  const missing = chapters.data !== undefined && !chapter;
  const data = chapterScript.data;
  const script = data?.script ?? null;
  const progress = data?.progress;
  // La vista se arma acá y no con la del servidor: una edición se ve al instante.
  const view = useMemo(() => (script ? scriptView(script, progress ?? {}) : null), [script, progress]);
  const npcHp = useMemo(() => {
    if (!npcs.data || !catalog.data) return new Map<string, string>();
    return new Map(
      npcViews(npcs.data, catalog.data)
        .filter((n) => n.maxHp > 0 && n.status !== 'dead')
        .map((n) => [n.npc.id, `${n.hurt?.current ?? n.maxHp}/${n.maxHp} ${t.hp}`]),
    );
  }, [npcs.data, catalog.data, t]);

  const back = chapter && (
    <Link href={dmCampaignHref(campaign.id, 'capitulos')} className="-mb-3 self-start text-[13px] text-text-muted hover:text-gold">
      {t.dmSectionChapters}
    </Link>
  );
  const menu = chapter && (
    <ChapterMenu
      campaignId={campaign.id}
      chapter={chapter}
      hasScript={script !== null}
      onClosed={(name) => {
        notify('success', t.dmChapterCloseDone(name));
        setFocusTarget('[data-dm-title]');
      }}
      onDetached={() => setFocusTarget('[data-dm-title]')}
    />
  );
  const page = (actions: ReactNode, body: ReactNode, count?: number) => (
    <div className="flex flex-col gap-5">
      {back}
      <DmHeader
        title={chapter?.name ?? t.dmSectionChapters}
        kicker={chapter ? chapterStatusLabel(t, chapter) : undefined}
        below={
          count === undefined ? undefined : (
            <p className="text-[12.5px] text-text-muted" data-field="milestone-count">
              {t.scMilestonesCount(count)}
            </p>
          )
        }
        actions={
          chapter && (
            <>
              {actions}
              {menu}
            </>
          )
        }
      />
      {chapter ? (
        <ChapterTabs campaignId={campaign.id} chapterId={chapterId} active="guion">
          {body}
        </ChapterTabs>
      ) : (
        body
      )}
    </div>
  );

  const failed = [chapters, chapterScript].filter((q) => q.isError);
  let content;
  if (missing) {
    // Antes que los errores: el guion de un capítulo que no existe da 404.
    content = page(
      null,
      <AppEmptyState
        kind="empty"
        message={t.dmChapterNotFound}
        actions={
          <ButtonLink internal tone="secondary" href={dmCampaignHref(campaign.id, 'capitulos')}>
            {t.dmBackToChapters}
          </ButtonLink>
        }
      />,
    );
  } else if (failed.length > 0 && !(data && chapter)) {
    content = page(
      null,
      <AppErrorView title={t.scReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => void q.refetch())} />,
    );
  } else if (!chapter || !data) {
    content = page(null, <AppBusyLabel label={t.scLoading} />);
  } else if (!script || !view) {
    content = page(null, <NoScript campaignId={campaign.id} chapter={chapter} onFailed={() => notify('error', t.scActionError)} />);
  } else {
    const count = script.steps.reduce((n, s) => n + (s.type === 'fork' ? s.paths.length : 1), 0);
    content = (
      <ScriptEditor
        script={script}
        campaigns={data.campaigns ?? 0}
        view={view}
        chapter={{ campaignId: campaign.id, chapterId, scenes: campaign.musicScenes ?? [], npcHp }}
        onDuplicated={async () => {
          await client.invalidateQueries({ queryKey: queryKeys.chapterScript(campaign.id, chapterId) });
          void client.invalidateQueries({ queryKey: queryKeys.scripts });
          setFocusTarget('[data-dm-title]');
        }}
        layout={(actions, body) => page(actions, body, count)}
      />
    );
  }

  return (
    <>
      {content}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} open onOpenChange={(o) => !o && setToast(null)} />}
    </>
  );
}

/** Un capítulo sin guion: empezar uno o ponerle uno de la Biblioteca. */
function NoScript({ campaignId, chapter, onFailed }: { campaignId: string; chapter: DmChapter; onFailed: () => void }) {
  const t = useTexts();
  const client = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [picking, setPicking] = useState(false);

  const attach = async (scriptId: () => Promise<string>) => {
    if (busy) return;
    setBusy(true);
    try {
      await attachChapterScript(campaignId, chapter.id, await scriptId());
      void client.invalidateQueries({ queryKey: queryKeys.scripts });
      await client.invalidateQueries({ queryKey: queryKeys.chapterScript(campaignId, chapter.id) });
    } catch {
      onFailed();
    }
    setBusy(false);
  };

  return (
    <>
      <AppEmptyState
        kind="empty"
        message={t.scNone}
        actions={
          <>
            <Button
              icon={Plus}
              disabled={busy}
              data-action="start-script"
              onClick={() => void attach(async () => (await createScript(scriptNew(crypto.randomUUID(), chapter.name))).id)}
            >
              {t.scStart}
            </Button>
            <Button tone="secondary" disabled={busy} data-action="use-script" onClick={() => setPicking(true)}>
              {t.scUseLibrary}
            </Button>
          </>
        }
      />
      {picking && <ScriptPicker onPick={(id) => void attach(async () => id)} onClose={() => setPicking(false)} />}
    </>
  );
}

function ScriptPicker({ onPick, onClose }: { onPick: (id: string) => void; onClose: () => void }) {
  const t = useTexts();
  const scripts = useScripts();
  return (
    <PickOneDialog
      title={t.scPick}
      items={scripts.data?.map((s) => ({ id: s.script.id, title: s.script.name }))}
      confirmLabel={t.scUse}
      searchLabel={t.scSearch}
      emptyText={t.scScriptsEmpty}
      loading={t.scLoading}
      error={scripts.isError ? { title: t.scReadFail, retry: () => void scripts.refetch() } : undefined}
      onPick={onPick}
      onClose={onClose}
    />
  );
}
