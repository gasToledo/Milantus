import { useMemo, useState } from 'react';
import { useCampaignNpcs, useSheetCatalog } from '../../api/queries';
import type { DmCampaign } from '../../api/client';
import { npcViews, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcsHref, Link } from '../../router';
import { Button } from '../../ui/Button';
import { cx } from '../../ui/cx';
import { Medallion } from '../../ui/Medallion';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { FilterPill } from './NpcLibraryView';
import { hasTag, normalizeTags, npcPortrait, npcTypeLine, STATUS_TONE } from './npc';

/**
 * Los PNJ de la campaña (`campaign_npcs_view.dart`), con su estado **en esta**
 * campaña, de solo lectura: el estado es una pill y no el selector de Flutter,
 * y traer de la biblioteca o quitar de la campaña siguen allá. Los PG de un
 * herido son los que guardó el último combate de esta mesa, y los resuelve el
 * motor (`npcViews`) con el resto de la línea.
 */
export function CampaignNpcsView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const lang = useLang();
  const npcs = useCampaignNpcs(campaign.id);
  const catalog = useSheetCatalog(lang);
  const [tag, setTag] = useState<string | null>(null);

  const views = useMemo(
    () => (npcs.data && catalog.data ? npcViews(npcs.data, catalog.data) : null),
    [npcs.data, catalog.data],
  );

  const portraits = useMemo(() => new Map((npcs.data ?? []).map((e) => [e.npc.id, npcPortrait(e)])), [npcs.data]);

  const failed = [npcs, ...catalog.queries].filter((q) => q.isError);

  let body;
  if (failed.length > 0) {
    body = <AppErrorView title={t.dmNpcsReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!views) {
    body = <AppBusyLabel label={t.dmNpcsLoading} />;
  } else if (views.length === 0) {
    body = <AppEmptyState kind="empty" message={t.dmNpcsEmpty} hint={t.dmNpcsEmptyHint} />;
  } else {
    const count = (s: NpcView['status']) => views.filter((v) => v.status === s).length;
    const tags = normalizeTags(views.flatMap((v) => v.npc.tags ?? []));
    const visible = tag === null ? views : views.filter((v) => hasTag(v, tag));
    body = (
      <>
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="mr-2.5 text-[13px] text-text-muted" data-field="summary">
            {t.npcCounts(views.length, count('alive'), count('dead'), count('unknown'))}
          </span>
          {tags.length > 0 && (
            <div role="group" aria-label={t.dmTags} className="flex flex-wrap items-center gap-1.5">
              <span aria-hidden="true" className="eyebrow mr-0.5">
                {t.dmTags}
              </span>
              {tags.map((g) => (
                <FilterPill
                  key={g}
                  small
                  label={g}
                  count={views.filter((v) => hasTag(v, g)).length}
                  pressed={tag?.toLowerCase() === g.toLowerCase()}
                  onClick={() => setTag(tag?.toLowerCase() === g.toLowerCase() ? null : g)}
                />
              ))}
            </div>
          )}
        </div>
        {visible.length === 0 ? (
          // Solo el tag puede dejarla vacía: hay PNJ, ninguno con ese tag.
          <AppEmptyState
            kind="no-match"
            message={t.dmNoNpcWithTag}
            actions={
              <Button tone="secondary" onClick={() => setTag(null)}>
                {t.dmClearFilter}
              </Button>
            }
          />
        ) : (
          <ul aria-label={t.dmCampaignNpcs} className="grid gap-3.5 [grid-template-columns:repeat(auto-fill,minmax(min(280px,100%),1fr))]">
            {visible.map((v) => (
              <TableNpcCard key={v.npc.id} view={v} portrait={portraits.get(v.npc.id) ?? null} />
            ))}
          </ul>
        )}
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmSectionNpcs} kicker={campaign.name} />
      {body}
    </div>
  );
}

/** Un PNJ en la mesa: la identidad lleva a su ficha de la Biblioteca y el
 *  estado va al pie, para que en una fila de la grilla queden alineados. */
function TableNpcCard({ view, portrait }: { view: NpcView; portrait: string | null }) {
  const t = useTexts();
  const { npc, status } = view;
  // Tachado y atenuado, no solo en rojo: el estado se lee sin distinguir colores.
  const dead = status === 'dead';
  return (
    <li className={cx('card flex min-w-0 flex-col gap-2.5 px-3.5 pt-3 pb-3.5', dead && 'opacity-70')} data-npc={npc.id}>
      <Link href={dmNpcsHref(npc.id)} className="flex items-center gap-3 rounded-[var(--radius-nav)] hover:text-gold">
        <Medallion name={npc.name} accent={null} size={36} portrait={portrait} />
        <span className="min-w-0 flex-1">
          <span className={cx('font-display block truncate text-[16px]', dead ? 'text-text-muted line-through' : 'text-on-surface')}>
            {npc.name}
          </span>
          <span className="block truncate text-[12px] text-text-muted" data-field="type">
            {npcTypeLine(view, t, { withHurt: true })}
          </span>
        </span>
      </Link>
      {(npc.tags ?? []).length > 0 && (
        <span className="flex flex-wrap gap-1.5">
          {npc.tags!.map((tag) => (
            <span key={tag} className="rounded-[var(--radius-pill)] border border-hairline px-[9px] py-px text-[11.5px] text-on-surface-variant">
              {tag}
            </span>
          ))}
        </span>
      )}
      <span className="mt-auto">
        <span className={cx('inline-block rounded-[var(--radius-pill)] border px-[11px] py-0.5 text-[12px]', STATUS_TONE[status])} data-status={status}>
          {t.npcStatus[status]}
        </span>
      </span>
    </li>
  );
}
