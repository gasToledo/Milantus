import { useState } from 'react';
import { Plus } from 'lucide-react';
import type { DmCampaign } from '../../api/client';
import type { CreatureProfile } from '../../bestiary/creature';
import type { Catalog } from '../../engine';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { Toast } from '../../ui/primitives';
import { flushEncounterSave, useEncounterWriter } from './encounterWriter';
import { MonsterQuantity, type MonsterDraft } from './MonsterQuantity';

export function AddFromBestiary({ campaign, creatureId, profile, catalog, onMusicOffer }: {
  campaign: DmCampaign;
  creatureId: string;
  profile: CreatureProfile;
  catalog: Catalog;
  onMusicOffer: (campaignId: string, show: boolean) => void;
}) {
  const t = useTexts();
  const writer = useEncounterWriter(campaign.id, catalog, undefined, onMusicOffer);
  const [draft, setDraft] = useState<MonsterDraft | null>(null);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const [notice, setNotice] = useState<{ kind: 'success' | 'error'; what: string } | null>(null);
  const title = t.dmAddToCombatOf(campaign.name);

  const save = async (what: string) => {
    setNotice(null);
    try {
      await flushEncounterSave(campaign.id);
      setNotice({ kind: 'success', what });
    } catch {
      setNotice({ kind: 'error', what });
    } finally {
      setBusy(false);
    }
  };

  const add = async () => {
    if (!draft || busy) return;
    setBusy(true);
    setFailed(false);
    try {
      await writer.stageBestiaryAdd({
        type: 'addMonsters', creatureId, ...draft, rollHp: !!profile.hitDice && draft.rollHp,
      });
    } catch {
      setFailed(true);
      setBusy(false);
      return;
    }
    setDraft(null);
    void save(draft.count === 1 ? profile.name : `${draft.count} × ${profile.name}`);
  };

  return (
    <>
      <Button icon={Plus} disabled={busy} onClick={() => {
        setFailed(false);
        setDraft({ count: 1, rollHp: false, side: 'enemy' });
      }}>
        {title}
      </Button>
      {draft && (
        <AppDialog open title={title} width={440} onOpenChange={(open) => !open && !busy && setDraft(null)} actions={[
          { label: t.cancel, disabled: busy },
          { label: failed ? t.retry : draft.count === 1 ? t.dmAddShort : t.dmAddCount(draft.count), primary: true, closes: false, disabled: busy, onSelect: () => void add() },
        ]}>
          <div className="flex flex-col gap-3">
            <p className="font-display text-[18px] text-on-surface">{profile.name}</p>
            <MonsterQuantity draft={draft} onChange={setDraft} hp={profile.hp} hitDice={profile.hitDice} disabled={busy} />
            {failed && <p role="alert" className="text-[13px] text-crimson">{t.dmAddToCombatFailed}</p>}
          </div>
        </AppDialog>
      )}
      {notice && (
        <Toast
          tone={notice.kind}
          open
          message={notice.kind === 'success' ? t.dmAddedToCombat(notice.what, campaign.name) : t.dmAddToCombatFailed}
          onOpenChange={(open) => !open && setNotice((current) => current === notice ? null : current)}
          // La tanda ya está en cola: reintentar el guardado no vuelve a tirar ni a sumar.
          action={notice.kind === 'error' ? { label: t.retry, onSelect: () => { setBusy(true); void save(notice.what); } } : undefined}
        />
      )}
    </>
  );
}
