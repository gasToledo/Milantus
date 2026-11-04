import { useMemo, useState } from 'react';
import { EllipsisVertical, LibraryBig, Plus, ScrollText, UserMinus } from 'lucide-react';
import { useCampaignNpcs, useSheetCatalog } from '../../api/queries';
import type { DmCampaign } from '../../api/client';
import { npcViews, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcsHref, Link, navigate } from '../../router';
import { Button } from '../../ui/Button';
import { ConfirmDialog } from '../../ui/ConfirmDialog';
import { cx } from '../../ui/cx';
import { Medallion } from '../../ui/Medallion';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Toast,
  Tooltip,
} from '../../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { BringNpcsDialog } from './BringNpcsDialog';
import { useNpcLinks } from './links';
import { NewNpcDialog } from './NewNpcDialog';
import { FilterPill } from './NpcLibraryView';
import { NpcStatusSelector } from './NpcStatusSelector';
import { hasTag, normalizeTags, npcPortrait, npcTypeLine, type NpcStatus } from './npc';

/**
 * Los PNJ de la campaña (`campaign_npcs_view.dart`), con su estado **en esta**
 * campaña: se cambia con el selector, se traen más de la biblioteca y se
 * quitan de la mesa (solo el vínculo: el PNJ sigue en la biblioteca). Se crea
 * uno nuevo y queda vinculado a esta mesa; borrarlo se hace desde su ficha y
 * editarlo sigue en Flutter. Los PG de un herido son los que
 * guardó el último combate de esta mesa, y los resuelve el motor (`npcViews`)
 * con el resto de la línea.
 */
export function CampaignNpcsView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const lang = useLang();
  const npcs = useCampaignNpcs(campaign.id);
  const catalog = useSheetCatalog(lang);
  const [tag, setTag] = useState<string | null>(null);
  const [bringing, setBringing] = useState(false);
  const [creating, setCreating] = useState(false);
  const [removing, setRemoving] = useState<{ id: string; name: string } | null>(null);
  const [toast, setToast] = useState<{ key: number; message: string } | null>(null);
  const links = useNpcLinks(() => setToast((prev) => ({ key: (prev?.key ?? 0) + 1, message: t.npcSaveFailed })));
  const bringButton = (
    <Button tone="soft" icon={LibraryBig} data-action="bring-npcs" onClick={() => setBringing(true)}>
      {t.dmBringFromLibrary}
    </Button>
  );
  const newButton = (
    <Button icon={Plus} data-action="new-npc" onClick={() => setCreating(true)}>
      {t.npcNew}
    </Button>
  );

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
    body = <AppEmptyState kind="empty" message={t.dmNpcsEmpty}
        actions={
          <div className="flex flex-wrap justify-center gap-2">
            {newButton}
            {bringButton}
          </div>
        }
      />;
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
              <TableNpcCard
                key={v.npc.id}
                view={v}
                portrait={portraits.get(v.npc.id) ?? null}
                onStatus={(s) => links.setStatus(campaign.id, v.npc.id, s)}
                onRemove={() => setRemoving({ id: v.npc.id, name: v.npc.name })}
              />
            ))}
          </ul>
        )}
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmSectionNpcs} kicker={campaign.name} actions={
          views && views.length > 0 ? (
            <>
              {bringButton}
              {newButton}
            </>
          ) : undefined
        }
      />
      {body}
      {creating && <NewNpcDialog campaignId={campaign.id} onClose={() => setCreating(false)} />}
      {bringing && <BringNpcsDialog campaignId={campaign.id} onLink={links.linkMany} onClose={() => setBringing(false)} />}
      {removing && (
        <ConfirmDialog
          title={t.dmRemoveFromCampaignTitle(removing.name)}
          body={t.dmRemoveFromCampaignBody}
          confirmLabel={t.dmRemoveShort}
          errorText={t.dmRemoveFromCampaignError}
          onConfirm={() => links.unlink(campaign.id, removing.id)}
          onClose={() => setRemoving(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone="error" message={toast.message} open onOpenChange={(open) => !open && setToast(null)} />}
    </div>
  );
}

/** Un PNJ en la mesa: la identidad lleva a su ficha de la Biblioteca y el
 *  estado va al pie, para que en una fila de la grilla queden alineados. */
function TableNpcCard({
  view,
  portrait,
  onStatus,
  onRemove,
}: {
  view: NpcView;
  portrait: string | null;
  onStatus: (status: NpcStatus) => void;
  onRemove: () => void;
}) {
  const t = useTexts();
  const { npc, status } = view;
  // Tachado y atenuado, no solo en rojo: el estado se lee sin distinguir colores.
  // El selector queda afuera: un control que responde no puede verse apagado.
  const dead = status === 'dead';
  return (
    <li className="card flex min-w-0 flex-col gap-2.5 px-3.5 pt-3 pb-3.5" data-npc={npc.id}>
      <div className="flex items-start gap-1">
        <Link
          href={dmNpcsHref(npc.id)}
          className={cx('flex min-w-0 flex-1 items-center gap-3 rounded-[var(--radius-nav)] hover:text-gold', dead && 'opacity-70')}
        >
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
        <DropdownMenu>
          <Tooltip content={t.dmActionsOf(npc.name)}>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                aria-label={t.dmActionsOf(npc.name)}
                data-action="npc-actions"
                className="inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
              >
                <EllipsisVertical size={18} aria-hidden="true" />
              </button>
            </DropdownMenuTrigger>
          </Tooltip>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => navigate(dmNpcsHref(npc.id))}>
              <ScrollText size={15} aria-hidden="true" className="text-text-muted" />
              {t.dmOpenSheet(npc.name)}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={onRemove} className="text-crimson">
              <UserMinus size={15} aria-hidden="true" />
              {t.dmRemoveFromCampaign}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      {(npc.tags ?? []).length > 0 && (
        <span className={cx('flex flex-wrap gap-1.5', dead && 'opacity-70')}>
          {npc.tags!.map((tag) => (
            <span key={tag} className="rounded-[var(--radius-pill)] border border-hairline px-[9px] py-px text-[11.5px] text-on-surface-variant">
              {tag}
            </span>
          ))}
        </span>
      )}
      <div className="mt-auto">
        <NpcStatusSelector status={status} label={t.dmStatusOf(npc.name)} onChange={onStatus} />
      </div>
    </li>
  );
}
