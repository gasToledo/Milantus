import { useState } from 'react';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Select } from '../ui/primitives';
import { stateLabel, type CampaignState } from './campaigns';

export interface CampaignDraft {
  name: string;
  premise: string;
  state: CampaignState;
}

/**
 * Nombre, premisa y estado de una campaña (`campaign_editor_dialog.dart`):
 * sirve para crear y para editar. Se monta solo mientras está abierto, así los
 * campos arrancan siempre con [initial]. [onSubmit] guarda; si falla el
 * diálogo **no se cierra**, lo escrito se conserva y «Guardar» pasa a
 * «Reintentar».
 */
export function CampaignEditorDialog({
  title,
  initial,
  onSubmit,
  onClose,
}: {
  title: string;
  initial: CampaignDraft;
  onSubmit: (draft: CampaignDraft) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [name, setName] = useState(initial.name);
  const [premise, setPremise] = useState(initial.premise);
  const [state, setState] = useState<CampaignState>(initial.state);
  const [missingName, setMissingName] = useState(false);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (busy) return;
    const trimmed = name.trim();
    if (trimmed === '') return setMissingName(true);
    setBusy(true);
    try {
      await onSubmit({ name: trimmed, premise: premise.trim(), state });
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  const field = 'text-[14px] text-on-surface rounded-[var(--radius-nav)] border bg-plaque px-3';
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : t.commonSave, primary: true, closes: false, disabled: busy, onSelect: () => void save() },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmCampaignName}</span>
          <input
            autoFocus
            value={name}
            onChange={(e) => {
              setName(e.target.value);
              setMissingName(false);
            }}
            onKeyDown={(e) => e.key === 'Enter' && void save()}
            aria-invalid={missingName}
            data-field="campaign-name"
            className={`${field} h-[38px] ${missingName ? 'border-crimson' : 'border-hairline'}`}
          />
        </label>
        {missingName && (
          <p role="alert" className="-mt-2 text-[13px] text-crimson">
            {t.dmCampaignNameRequired}
          </p>
        )}
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmPremise}</span>
          <textarea
            value={premise}
            onChange={(e) => setPremise(e.target.value)}
            placeholder={t.dmPremiseHint}
            data-field="campaign-premise"
            className={`${field} h-[84px] resize-none border-hairline py-2 placeholder:text-text-muted`}
          />
        </label>
        <Select
          label={t.combatState}
          value={state}
          onValueChange={(v) => setState(v as CampaignState)}
          options={(['active', 'paused', 'finished'] as const).map((s) => ({ value: s, label: stateLabel(t, s) }))}
          className="w-full justify-between"
        />
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmCampaignSaveError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
