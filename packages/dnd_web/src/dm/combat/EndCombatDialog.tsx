import { useState } from 'react';
import { TriangleAlert } from 'lucide-react';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { Eyebrow } from '../../ui/data';
import { Option } from '../../ui/wizard';

type CloseAction = 'finish' | 'discard';

export function EndCombatDialog({
  fallen,
  onFinish,
  onDiscard,
  onClose,
}: {
  fallen: { npcId: string; name: string; side: string }[];
  onFinish: (deadNpcIds: string[]) => Promise<void>;
  onDiscard: () => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  // Caer no es morir. Marcarlo requiere una decisión del DM.
  const [dead, setDead] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState<CloseAction | null>(null);

  const confirm = async (action: CloseAction) => {
    if (busy) return;
    setBusy(true);
    setFailed(null);
    try {
      if (action === 'finish') await onFinish(dead);
      else await onDiscard();
      onClose();
    } catch {
      setFailed(action);
      setBusy(false);
    }
  };

  // El descarte va en carmesí porque borra lo jugado. Guardar conserva el registro.
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && !busy && onClose()}
      title={t.encFinish}
      icon={TriangleAlert}
      iconClassName="text-crimson"
      actions={[
        { label: t.cancel, disabled: busy },
        { label: failed === 'discard' ? t.retry : t.encDiscardNoSave, tone: 'crimson', closes: false, disabled: busy, onSelect: () => void confirm('discard') },
        { label: failed === 'finish' ? t.retry : t.encFinishAndSave, tone: 'verdant', primary: true, closes: false, disabled: busy, onSelect: () => void confirm('finish') },
      ]}
    >
      <p className="text-[14px] leading-[1.55] text-on-surface-variant">{t.encCloseExplain}</p>
      {fallen.length > 0 && (
        <div className="mt-3.5">
          <Eyebrow>{t.encAnyDied}</Eyebrow>
          <p className="mt-1 mb-2.5 text-[12px] text-text-muted">{t.encFellNote}</p>
          <div className="space-y-2">
            {fallen.map(({ npcId, name, side }) => (
              <Option
                key={npcId}
                id={npcId}
                multi
                title={name}
                detail={t.encSides[side]}
                selected={dead.includes(npcId)}
                disabled={busy}
                onClick={() => setDead((ids) => ids.includes(npcId) ? ids.filter((id) => id !== npcId) : [...ids, npcId])}
              />
            ))}
          </div>
        </div>
      )}
      {failed && <p role="alert" className="mt-2 text-[13px] text-crimson">{t.dmSaveCombatFailed}</p>}
    </AppDialog>
  );
}
