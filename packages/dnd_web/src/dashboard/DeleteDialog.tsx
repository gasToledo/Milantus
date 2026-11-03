import { useState } from 'react';
import { TriangleAlert } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

/** «¿Borrar a …?». Si el borrado falla el diálogo queda abierto con el error
 *  y «Reintentar»: cerrarlo dejaría a quien borra sin saber si pasó. */
export function DeleteDialog({
  name,
  onConfirm,
  onClose,
}: {
  name: string;
  onConfirm: () => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  const remove = async () => {
    if (busy) return;
    setBusy(true);
    try {
      await onConfirm();
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
      title={t.deleteCharacterTitle(name)}
      icon={TriangleAlert}
      iconClassName="text-crimson"
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : t.cardDelete, tone: 'crimson', primary: true, closes: false, disabled: busy, onSelect: () => void remove() },
      ]}
    >
      <p className="text-[14px] text-on-surface-variant">{t.commonCannotUndo}</p>
      {failed && (
        <p role="alert" className="mt-2 text-[13px] text-crimson">
          {t.deleteCharacterError}
        </p>
      )}
    </AppDialog>
  );
}
