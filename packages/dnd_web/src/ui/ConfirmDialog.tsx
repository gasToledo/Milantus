import { useState } from 'react';
import { TriangleAlert } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { AppDialog } from './AppDialog';

/**
 * Confirmar algo irreversible, con el patrón de `DeleteDialog`: si [onConfirm]
 * falla el diálogo **no se cierra**, queda el error en carmesí y el botón pasa
 * a «Reintentar» (cerrarlo dejaría a quien confirma sin saber si pasó).
 * [body] puede traer párrafos separados por una línea en blanco.
 */
export function ConfirmDialog({
  title,
  body,
  confirmLabel,
  errorText,
  onConfirm,
  onClose,
}: {
  title: string;
  body: string;
  confirmLabel: string;
  errorText: string;
  onConfirm: () => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  const confirm = async () => {
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
      title={title}
      icon={TriangleAlert}
      iconClassName="text-crimson"
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : confirmLabel, tone: 'crimson', primary: true, closes: false, disabled: busy, onSelect: () => void confirm() },
      ]}
    >
      <p className="text-[14px] whitespace-pre-line text-on-surface-variant">{body}</p>
      {failed && (
        <p role="alert" className="mt-2 text-[13px] text-crimson">
          {errorText}
        </p>
      )}
    </AppDialog>
  );
}
