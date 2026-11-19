import { useEffect, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { BookOpen, CheckCheck, EllipsisVertical, Pencil, Play, Plus, Trash2 } from 'lucide-react';
import { createChapter, deleteChapter, fetchCampaignChapters, saveChapter } from '../api/client';
import { useListTransition } from '../ui/listTransition';
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
import { useMentionReader } from './mentions/reader';
import { withMentions } from '../ui/mentions';
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
  // Las menciones del objetivo abren el panel lateral, como en el Cuaderno.
  const { mentions, panel, readingClass } = useMentionReader(campaign.id);
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

  // Crear o borrar un capítulo anima la lista (`useListTransition`). La red
  // queda afuera de la transición, que congela la pantalla: al crear se relee
  // antes y al borrar se saca de la caché y se relee después.
  const chaptersKey = queryKeys.campaignChapters(campaign.id);
  const animateList = useListTransition(chapters.data);

  // Empezar o cerrar cambia el botón del capítulo por otro, y borrarlo se
  // lleva su ⋮: el foco caería al documento. Va al título del capítulo que
  // cambió (o al de la sección, si ya no está) cuando la lista nueva se dibuja
  // y el diálogo terminó de devolver el foco a su botón.
  const [focusTarget, setFocusTarget] = useState<string | null>(null);
  useEffect(() => {
    if (!focusTarget) return;
    const id = window.setTimeout(() => {
      document.querySelector<HTMLElement>(focusTarget)?.focus();
      setFocusTarget(null);
    }, 0);
    return () => window.clearTimeout(id);
  }, [focusTarget, chapters.data]);
  const focusChapter = (id: string) => setFocusTarget(`[data-chapter="${CSS.escape(id)}"] h2`);

  const submit = async (chapter: DmChapter) => {
    if (editing === 'new') {
      await createChapter(campaign.id, chapter);
      await client.cancelQueries({ queryKey: chaptersKey });
      const fresh = await fetchCampaignChapters(campaign.id, new AbortController().signal);
      animateList(() => client.setQueryData(chaptersKey, fresh));
      void client.invalidateQueries({ queryKey: queryKeys.campaignNotebook(campaign.id) });
    } else {
      await saveChapter(campaign.id, chapter);
      await refresh();
    }
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
      focusChapter(c.id);
    } catch {
      notify('error', t.dmChapterStartError);
    }
  };

  const remove = async (c: DmChapter) => {
    await deleteChapter(campaign.id, c.id);
    await client.cancelQueries({ queryKey: chaptersKey });
    animateList(() => client.setQueryData<DmChapter[]>(chaptersKey, (old) => old?.filter((o) => o.id !== c.id)));
    void refresh();
    setFocusTarget('[data-dm-title]');
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
              // Su nombre en las transiciones de la lista: único y un
              // identificador CSS válido.
              data-vt-card
              style={{ viewTransitionName: `ch-${c.id.replace(/[^\w-]/g, '_')}` }}
              // El abierto es el que se está jugando: borde oro más grueso.
              // Empezarlo o cerrarlo dora o apaga el borde en 160 ms, para que
              // se note cuál cambió.
              className={cx(
                'card flex flex-wrap items-start gap-3.5 px-[18px] py-4 transition-colors duration-[160ms] ease-out',
                status === 'open' && 'border-2 border-gold',
              )}
            >
              <div className="min-w-0 flex-[1_1_320px]">
                <div className="flex flex-wrap items-center gap-2.5">
                  {/* `tabIndex`: el foco viene acá al empezarlo o cerrarlo. */}
                  <h2 tabIndex={-1} className="font-display text-[20px] break-words text-on-surface outline-none">
                    {c.name}
                  </h2>
                  <span
                    className={cx(
                      'rounded-[var(--radius-pill)] border px-2.5 py-0.5 text-[11.5px] transition-colors duration-[160ms] ease-out',
                      status === 'open' ? 'border-gold text-gold' : status === 'closed' ? 'border-text-muted text-text-muted' : 'border-on-surface-variant text-on-surface-variant',
                    )}
                  >
                    {label[status]}
                  </span>
                </div>
                <p className="mt-1.5 text-[13.5px] leading-normal whitespace-pre-line text-on-surface-variant">
                  {c.summary?.trim() ? withMentions(c.summary, mentions) : t.dmChapterNoGoal}
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
    <div className={cx('flex flex-col gap-5', readingClass)}>
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
          campaignId={campaign.id}
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
      {panel}
      {closing && (
        <CloseChapterDialog
          campaignId={campaign.id}
          chapter={closing}
          onClosed={(name) => {
            notify('success', t.dmChapterCloseDone(name));
            focusChapter(closing.id);
          }}
          onClose={() => setClosing(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} open onOpenChange={(open) => !open && setToast(null)} />}
    </div>
  );
}
