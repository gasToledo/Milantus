import { useState } from 'react';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

/**
 * «Editar nombre»: lo usan la lista y la ficha. Se monta solo mientras está
 * abierto, así el campo arranca siempre con el nombre actual. [onSubmit]
 * guarda; si falla, el diálogo **no se cierra**: el nombre escrito se conserva,
 * el error queda a la vista y «Guardar» pasa a «Reintentar».
 */
export function RenameDialog({
  current,
  onSubmit,
  onClose,
}: {
  current: string;
  onSubmit: (name: string) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [name, setName] = useState(current);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  const trimmed = name.trim();
  const canSave = trimmed !== '' && !busy;

  const save = async () => {
    if (!canSave) return;
    // Igual al actual: no hay nada que guardar.
    if (trimmed === current) return onClose();
    setBusy(true);
    try {
      await onSubmit(trimmed);
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.renameTitle}
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : t.commonSave, primary: true, closes: false, disabled: !canSave, onSelect: () => void save() },
      ]}
    >
      <label className="flex flex-col gap-1.5">
        <span className="text-[12px] text-text-muted">{t.crName}</span>
        <input
          autoFocus
          value={name}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && void save()}
          data-field="rename"
          className="h-[38px] rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 text-[14px] text-on-surface"
        />
      </label>
      {failed && (
        <p role="alert" className="mt-2 text-[13px] text-crimson">
          {t.renameSaveError}
        </p>
      )}
    </AppDialog>
  );
}
