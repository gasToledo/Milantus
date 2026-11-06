import { useId, useState } from 'react';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';

/** Lo que se acepta tecleando: un `-` adelante y dígitos (una iniciativa puede
 *  ser negativa con una Destreza baja). */
export const NUMBER_FILTER = /^-?\d*$/;
/** Lo que se puede mandar: al menos un dígito. */
export const isWholeNumber = (text: string): boolean => /^-?\d+$/.test(text);

/**
 * Pide un número entero: la iniciativa de alguien que se corrige o que entra
 * tarde. Enter guarda; «Guardar» queda apagado mientras el campo no sea un
 * número.
 */
export function NumberPromptDialog({
  title,
  label,
  initial,
  onSubmit,
  onClose,
}: {
  title: string;
  label: string;
  initial?: number;
  onSubmit: (n: number) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const id = useId();
  const [text, setText] = useState(initial === undefined ? '' : String(initial));
  const valid = isWholeNumber(text);
  const submit = () => {
    if (!valid) return;
    onSubmit(Number(text));
    onClose();
  };
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      width={360}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, closes: false, disabled: !valid, onSelect: submit }]}
    >
      <label htmlFor={id} className="plaque-label mb-1.5 block">
        {label}
      </label>
      <input
        id={id}
        type="text"
        inputMode="numeric"
        autoFocus
        value={text}
        onChange={(e) => NUMBER_FILTER.test(e.target.value) && setText(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && submit()}
        data-field="number-prompt"
        className="h-10 w-full rounded-[8px] border border-hairline bg-plaque px-3 text-[14px] text-on-surface"
      />
    </AppDialog>
  );
}
