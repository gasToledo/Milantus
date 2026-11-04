import { useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { UserPlus } from 'lucide-react';
import { deleteCampaignLink, grantHeroicInspiration } from '../api/client';
import { queryKeys, useCampaignChapters, useCampaignMembers, useSheetCatalog } from '../api/queries';
import type { DmCampaign } from '../api/client';
import { movedOrder, toRosterEntry } from '../dashboard/roster';
import { useLang, useTexts } from '../i18n/context';
import { dmMemberHref } from '../router';
import { useHoldDrag } from '../ui/holdDrag';
import { Button } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { Toast, type ToastTone } from '../ui/primitives';
import { memberPortrait } from '../ui/portrait';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { editCampaign, stateLabel, stateOf } from './campaigns';
import { AddMemberDialog } from './AddMemberDialog';
import { GiveItemDialog } from './GiveItemDialog';
import { CampaignMenu } from './CampaignMenu';
import { DmHeader } from './DmHeader';
import { MemberCard } from './MemberCard';

/**
 * La Mesa: los personajes vinculados a la campaña. Sumar uno (con el código que
 * compartió el jugador) y echarlo cortan o crean el vínculo; conceder
 * Inspiración Heroica es un aviso. Ninguna acción escribe una ficha ajena. Cada ficha
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
  const client = useQueryClient();
  const [adding, setAdding] = useState(false);
  const [giving, setGiving] = useState<{ memberId: string; name: string } | null>(null);
  const [removing, setRemoving] = useState<{ memberId: string; name: string } | null>(null);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string } | null>(null);
  const notify = (tone: ToastTone, message: string) => setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone, message }));

  // Sin diálogo de confirmación: no rompe nada y se puede volver a conceder. Lo
  // que sí hace el aviso es decir que esto es un **aviso**, no una escritura en
  // la ficha ajena: si no, el DM la marca y después se sorprende de que el
  // jugador no la tenga.
  const grant = async (memberId: string, name: string) => {
    try {
      await grantHeroicInspiration(campaign.id, memberId);
      notify('success', t.dmInspirationSent(name));
    } catch {
      notify('error', t.dmInspirationError(name));
    }
  };

  const remove = async ({ memberId, name }: { memberId: string; name: string }) => {
    await deleteCampaignLink(memberId);
    await client.invalidateQueries({ queryKey: queryKeys.campaignMembers(campaign.id) });
    notify('info', t.dmMemberLeft(name));
  };

  const memberOrder = campaign.memberOrder;
  const entries = useMemo(() => {
    if (!members.data || !catalog.data) return null;
    const cat = catalog.data;
    // El vínculo no guarda cuándo se creó la ficha: `createdAt` no se usa acá.
    const all = members.data.map((m) => ({ memberId: m.memberId, entry: toRosterEntry(m.character, '', cat) }));
    // El orden del DM; lo que no figura va al final en el orden del servidor, y
    // un id que ya no está (echaron a alguien) se ignora.
    const rank = (id: string) => {
      const i = memberOrder?.indexOf(id) ?? -1;
      return i < 0 ? Number.MAX_SAFE_INTEGER : i;
    };
    return [...all].sort((a, b) => rank(a.memberId) - rank(b.memberId));
  }, [members.data, catalog.data, memberOrder]);

  const ids = useMemo(() => (entries ?? []).map((e) => e.memberId), [entries]);
  // Guarda el orden nuevo: la caché cambia al instante y el documento se relee
  // antes de escribir (`editCampaign`) para no pisar las escenas de música.
  const moveMember = (from: string, to: string) => {
    const order = movedOrder(ids, from, to);
    void (async () => {
      await client.cancelQueries({ queryKey: queryKeys.dmCampaigns });
      client.setQueryData<DmCampaign[]>(queryKeys.dmCampaigns, (old) =>
        old?.map((c) => (c.id === campaign.id ? { ...c, memberOrder: order } : c)),
      );
      try {
        await editCampaign(client, campaign.id, (latest) => ({ ...latest, memberOrder: order }));
      } catch {
        notify('error', t.dmOrderSaveError);
        void client.invalidateQueries({ queryKey: queryKeys.dmCampaigns });
      }
    })();
  };
  const reorder = useHoldDrag({ ids, canDrop: () => true, onMove: moveMember });

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
    body = <AppEmptyState kind="empty" message={t.dmTableEmptyTitle} hint={t.dmTableEmpty} />;
  } else {
    body = (
      <>
        <ul
          aria-label={t.dmTableCount(entries.length)}
          className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(min(320px,100%),1fr))]"
        >
          {entries.map(({ memberId, entry }) => (
            <MemberCard
              key={memberId}
              entry={entry}
              href={dmMemberHref(campaign.id, memberId)}
              portrait={memberPortrait(campaign.id, memberId, entry.character)}
              reorder={{
                item: reorder.item(memberId),
                dragging: reorder.dragging === memberId,
                over: reorder.over === memberId,
                animated: reorder.animated,
              }}
              actions={{
                onGiveItem: () => setGiving({ memberId, name: entry.character.name }),
                onGrantInspiration: () => void grant(memberId, entry.character.name),
                onRemove: () => setRemoving({ memberId, name: entry.character.name }),
              }}
            />
          ))}
        </ul>
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader
        title={campaign.name}
        kicker={kicker}
        actions={
          <>
            <CampaignMenu campaign={campaign} />
            <Button icon={UserPlus} data-action="add-member" onClick={() => setAdding(true)} className="min-h-11">
              {t.dmAddMember}
            </Button>
          </>
        }
      />
      {body}
      {adding && (
        <AddMemberDialog
          campaign={campaign}
          onAdded={(name) => notify('success', t.dmMemberAdded(name, campaign.name))}
          onClose={() => setAdding(false)}
        />
      )}
      {giving && (
        <GiveItemDialog
          campaignId={campaign.id}
          member={giving}
          onSent={(name) => notify('success', t.dmGiveItemSent(name))}
          onClose={() => setGiving(null)}
        />
      )}
      {removing && (
        <ConfirmDialog
          title={t.dmRemoveMember}
          body={t.dmRemoveMemberBody(removing.name, campaign.name)}
          confirmLabel={t.dmRemoveMember}
          errorText={t.dmMemberRemoveError}
          onConfirm={() => remove(removing)}
          onClose={() => setRemoving(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} open onOpenChange={(open) => !open && setToast(null)} />}
    </div>
  );
}
