import { useCampaignChapters } from '../api/queries';
import type { DmCampaign, DmChapter } from '../api/client';
import { chapterGrants } from '../engine';
import { useTexts } from '../i18n/context';
import { cx } from '../ui/cx';
import { StatPlaque } from '../ui/data';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { stateLabel, stateOf } from './campaigns';
import { DmHeader } from './DmHeader';

type ChapterStatus = 'closed' | 'open' | 'pending';

/** `completed` es «cerrado» y `active` «abierto»; un estado ausente o
 *  desconocido es pendiente, como `ChapterState.fromJson`. */
const statusOf = (c: DmChapter): ChapterStatus =>
  c.state === 'completed' ? 'closed' : c.state === 'active' ? 'open' : 'pending';

/**
 * Los capítulos de la campaña, de solo lectura: estado, objetivo y lo que
 * reparten. El objetivo (`summary`) lo lee solo su DM: es lo que el servidor
 * poda para el jugador, y por eso esta pantalla pide `/chapters` con la cuenta
 * del DM y no reutiliza nada de la vista del jugador. Cerrar un capítulo, que
 * le avisa a otras cuentas, vive en Flutter.
 */
export function ChaptersView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const chapters = useCampaignChapters(campaign.id);
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
      <ol aria-label={t.dmSectionChapters} className="flex max-w-[900px] flex-col gap-3">
        {chapters.data.map((c) => {
          const status = statusOf(c);
          const gold = c.grantsGold ?? 0;
          const items = c.grantsItems ?? [];
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
                <p className="mt-1.5 text-[13.5px] leading-normal whitespace-pre-line text-on-surface-variant">
                  {c.summary?.trim() ? c.summary : t.dmChapterNoGoal}
                </p>
                {rewards !== '' && <p className="mt-2 text-[12.5px] text-text-muted">{t.dmChapterRewards(rewards)}</p>}
              </div>
              {(c.grantsLevel || gold > 0 || items.length > 0) && (
                <dl className="flex flex-none gap-2">
                  {c.grantsLevel && <StatPlaque id="level" label={t.dmChapterLevel} value={t.dmChapterLevelValue} />}
                  {gold > 0 && <StatPlaque id="gold" label={t.dmChapterGold} value={gold} />}
                  {items.length > 0 && <StatPlaque id="items" label={t.dmChapterItems} value={items.length} />}
                </dl>
              )}
            </li>
          );
        })}
      </ol>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmSectionChapters} kicker={kicker} />
      <p className="-mt-2 text-[13px] text-text-muted">{campaign.name}</p>
      {body}
    </div>
  );
}
