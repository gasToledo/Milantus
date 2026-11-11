import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { BookOpen, CheckCheck, EllipsisVertical, Pencil, Play, Plus, Trash2 } from 'lucide-react';
import { createChapter, deleteChapter, saveChapter } from '../api/client';
import type { DmCampaign, DmChapter } from '../api/client';
import { queryKeys, useCampaignChapters } from '../api/queries';
import { chapterGrants } from '../engine';
import { useTexts } from '../i18n/context';
import { dmCampaignHref, Link } from '../router';
import { Button } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { cx } from '../ui/cx';
import { StatPlaque } from '../ui/data';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Toast,
  Tooltip,
  type ToastTone,
} from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { stateLabel, stateOf } from './campaigns';
import { CampaignMenu } from './CampaignMenu';
import { ChapterEditorDialog } from './ChapterEditorDialog';
import { CloseChapterDialog } from './CloseChapterDialog';
import { DmHeader } from './DmHeader';

type ChapterStatus = 'closed' | 'open' | 'pending';

/** `completed` es «cerrado» y `active` «abierto»; un estado ausente o
 *  desconocido es pendiente, como `ChapterState.fromJson`. */
const statusOf = (c: DmChapter): ChapterStatus =>
  c.state === 'completed' ? 'closed' : c.state === 'active' ? 'open' : 'pending';

/**
 * Los capítulos de la campaña: estado, objetivo y lo que reparten; crear,
 * editar, empezar, cerrar y borrar. El objetivo (`summary`) lo lee solo su DM: es lo que
 * el servidor poda para el jugador, y por eso esta pantalla pide `/chapters` con
 * la cuenta del DM y no reutiliza nada de la vista del jugador. Cerrar un
 * capítulo le avisa a otras cuentas y reparte objetos: ver `CloseChapterDialog`.
 */
export function ChaptersView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const chapters = useCampaignChapters(campaign.id);
  const client = useQueryClient();
  const [editing, setEditing] = useState<DmChapter | 'new' | null>(null);
  const [deleting, setDeleting] = useState<DmChapter | null>(null);
  const [closing, setClosing] = useState<DmChapter | null>(null);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string } | null>(null);
  const notify = (tone: ToastTone, message: string) => setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone, message }));
  // Borrar o cambiar un capítulo mueve también lo que cuelga de él en el Cuaderno.
  const refresh = () =>
    Promise.all([
      client.invalidateQueries({ queryKey: queryKeys.campaignChapters(campaign.id) }),
      client.invalidateQueries({ queryKey: queryKeys.campaignNotebook(campaign.id) }),
    ]);

  const submit = async (chapter: DmChapter) => {
    if (editing === 'new') await createChapter(campaign.id, chapter);
    else await saveChapter(campaign.id, chapter);
    await refresh();
  };

  // Un solo capítulo en marcha por campaña. Se mira la lista antes de pedirle
  // al servidor, que igual lo comprueba (Flutter puede haber empezado uno): en
  // ese caso el 400 se dice con el aviso genérico.
  const start = async (c: DmChapter) => {
    const running = chapters.data?.find((o) => o.state === 'active');
    if (running) return notify('error', t.dmChapterAlreadyRunning(running.name));
    try {
      await saveChapter(campaign.id, { ...c, state: 'active' });
      await refresh();
    } catch {
      notify('error', t.dmChapterStartError);
    }
  };

  const remove = async (c: DmChapter) => {
    await deleteChapter(campaign.id, c.id);
    await refresh();
  };

  const kicker = chapters.data
    ? `${stateLabel(t, stateOf(campaign))} · ${t.dmChaptersCount(chapters.data.length)}`
    : stateLabel(t, stateOf(campaign));
  const label: Record<ChapterStatus, string> = {
    closed: t.dmChapterClosed,
    open: t.dmChapterOpen,
    pending: t.dmChapterPending,
  };

  let body;
  if (chapters.isError) {
    body = <AppErrorView title={t.dmChaptersReadFail} message={t.errorBody} onRetry={() => chapters.refetch()} />;
  } else if (!chapters.data) {
    body = <AppBusyLabel label={t.dmChaptersLoading} />;
  } else if (chapters.data.length === 0) {
    body = <AppEmptyState kind="empty" message={t.dmChaptersEmpty} hint={t.dmChaptersEmptyHint} />;
  } else {
    body = (
      <ol aria-label={t.dmSectionChapters} className="flex flex-col gap-3">
        {chapters.data.map((c) => {
          const status = statusOf(c);
          const gold = c.grantsGold ?? 0;
          const itemCount = (c.grantsItems ?? []).length + (c.grantsCatalog ?? []).length;
          const rewards = chapterGrants(c);
          return (
            <li
              key={c.id}
              data-chapter={c.id}
              data-status={status}
              // El abierto es el que se está jugando: borde oro más grueso.
              className={cx('card flex flex-wrap items-start gap-3.5 px-[18px] py-4', status === 'open' && 'border-2 border-gold')}
            >
              <div className="min-w-0 flex-[1_1_320px]">
                <div className="flex flex-wrap items-center gap-2.5">
                  <h2 className="font-display text-[20px] break-words text-on-surface">{c.name}</h2>
                  <span
                    className={cx(
                      'rounded-[var(--radius-pill)] border px-2.5 py-0.5 text-[11.5px]',
                      status === 'open' ? 'border-gold text-gold' : status === 'closed' ? 'border-text-muted text-text-muted' : 'border-on-surface-variant text-on-surface-variant',
                    )}
                  >
                    {label[status]}
                  </span>
                </div>
                <p className="mt-1.5 max-w-[620px] text-[13.5px] leading-normal whitespace-pre-line text-on-surface-variant">
                  {c.summary?.trim() ? c.summary : t.dmChapterNoGoal}
                </p>
                {rewards !== '' && <p className="mt-2 text-[12.5px] text-text-muted">{t.dmChapterRewards(rewards)}</p>}
              </div>
              {(c.grantsLevel || gold > 0 || itemCount > 0) && (
                <dl className="flex flex-none gap-2">
                  {c.grantsLevel && <StatPlaque id="level" label={t.dmChapterLevel} value={t.dmChapterLevelValue} />}
                  {gold > 0 && <StatPlaque id="gold" label={t.dmChapterGold} value={gold} />}
                  {itemCount > 0 && <StatPlaque id="items" label={t.dmChapterItems} value={itemCount} />}
                </dl>
              )}
              <DropdownMenu>
                <Tooltip content={t.dmChapterActions}>
                  <DropdownMenuTrigger asChild>
                    <button
                      type="button"
                      aria-label={t.dmChapterActions}
                      data-action="chapter-actions"
                      className="inline-flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
                    >
                      <EllipsisVertical size={20} aria-hidden="true" />
                    </button>
                  </DropdownMenuTrigger>
                </Tooltip>
                <DropdownMenuContent align="end">
                  {status !== 'closed' && (
                    <DropdownMenuItem onSelect={() => setEditing(c)}>
                      <Pencil size={15} aria-hidden="true" className="text-text-muted" />
                      {t.commonEdit}
                    </DropdownMenuItem>
                  )}
                  <DropdownMenuItem onSelect={() => setDeleting(c)} className="text-crimson">
                    <Trash2 size={15} aria-hidden="true" />
                    {t.commonDelete}
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
              <div className="flex basis-full flex-wrap items-center gap-3">
                {status === 'pending' && (
                  <Button icon={Play} data-action="start-chapter" onClick={() => void start(c)}>
                    {t.dmStart}
                  </Button>
                )}
                {status === 'open' && (
                  <Button icon={CheckCheck} data-action="close-chapter" onClick={() => setClosing(c)}>
                    {t.dmCloseChapter}
                  </Button>
                )}
                <Link
                  href={`${dmCampaignHref(campaign.id, 'cuaderno')}?capitulo=${encodeURIComponent(c.id)}`}
                  data-action="chapter-notebook"
                  className="inline-flex min-h-9 items-center gap-2 text-[13.5px] text-gold underline-offset-2 hover:underline"
                >
                  <BookOpen size={16} aria-hidden="true" />
                  {t.dmViewInNotebook}
                </Link>
              </div>
            </li>
          );
        })}
      </ol>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader
        title={t.dmSectionChapters}
        kicker={kicker}
        actions={
          <>
            <CampaignMenu campaign={campaign} />
            <Button icon={Plus} data-action="new-chapter" onClick={() => setEditing('new')} className="min-h-11">
              {t.dmNewChapter}
            </Button>
          </>
        }
      />
      <p className="-mt-2 text-[13px] text-text-muted">{campaign.name}</p>
      {body}
      {editing && (
        <ChapterEditorDialog
          title={editing === 'new' ? t.dmNewChapter : t.dmEditChapter}
          initial={editing === 'new' ? { id: `chapter-${Date.now()}`, name: '' } : editing}
          onSubmit={submit}
          onClose={() => setEditing(null)}
        />
      )}
      {deleting && (
        <ConfirmDialog
          title={t.dmDeleteChapter}
          body={t.dmDeleteChapterBody(deleting.name)}
          confirmLabel={t.dmDeleteChapter}
          errorText={t.dmChapterDeleteError}
          onConfirm={() => remove(deleting)}
          onClose={() => setDeleting(null)}
        />
      )}
      {closing && (
        <CloseChapterDialog
          campaignId={campaign.id}
          chapter={closing}
          onClosed={(name) => notify('success', t.dmChapterCloseDone(name))}
          onClose={() => setClosing(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} open onOpenChange={(open) => !open && setToast(null)} />}
    </div>
  );
}
