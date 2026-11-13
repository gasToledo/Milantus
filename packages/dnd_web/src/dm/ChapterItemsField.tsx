import { useState } from 'react';
import { Minus, Plus, X } from 'lucide-react';
import { useSheetCatalog } from '../api/queries';
import type { ChapterItem } from '../api/client';
import { useLang, useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { ItemPicker } from './ItemPicker';

/**
 * La lista de objetos que se reparten, con cantidad (− y +), quitar y «Agregar
 * objeto» (`ItemPicker`). La usa «Dar objeto» de la Mesa (el cierre del
 * capítulo arma sus placas aparte y reusa `StepButton`). [free] es el texto libre de los capítulos viejos: se lista como
 * «Sin catálogo» y se puede quitar, pero no se crea uno nuevo.
 */
export function ChapterItemsField({
  label,
  help,
  items,
  onItems,
  free = [],
  onFree,
}: {
  label?: string;
  help?: string;
  items: ChapterItem[];
  onItems: (items: ChapterItem[]) => void;
  free?: string[];
  onFree?: (free: string[]) => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  const [picking, setPicking] = useState(false);
  return (
    <>
      <div className="flex flex-col gap-1.5">
        {label && <span className="text-[12px] text-text-muted">{label}</span>}
        {(items.length > 0 || free.length > 0) && (
          <ul className="flex flex-col divide-y divide-hairline" data-field="chapter-items">
            {items.map((item, i) => (
              <li key={`${item.category}:${item.itemId}:${item.baseItemId ?? ''}`} className="flex items-center gap-2 py-1.5">
                <span className="min-w-0 flex-1 truncate text-[14px] text-on-surface">
                  {item.name}
                  {item.homebrew && (
                    <i className="ml-2 rounded-[var(--radius-pill)] border border-gold px-2 text-[11px] text-gold not-italic">
                      {t.itemOwnTag}
                    </i>
                  )}
                </span>
                <span className="flex items-center gap-1">
                  <StepButton
                    label={t.itemQtyLess}
                    icon={Minus}
                    disabled={item.quantity <= 1}
                    onClick={() => onItems(items.map((o, j) => (j === i ? { ...o, quantity: o.quantity - 1 } : o)))}
                  />
                  <span className="num w-6 text-center text-[14px]">{item.quantity}</span>
                  <StepButton
                    label={t.itemQtyMore}
                    icon={Plus}
                    onClick={() => onItems(items.map((o, j) => (j === i ? { ...o, quantity: o.quantity + 1 } : o)))}
                  />
                </span>
                <StepButton label={t.itemRemove(item.name)} icon={X} onClick={() => onItems(items.filter((_, j) => j !== i))} />
              </li>
            ))}
            {free.map((text, i) => (
              <li key={`free:${text}`} className="flex items-center gap-2 py-1.5">
                <span className="min-w-0 flex-1 truncate text-[14px] text-on-surface">
                  {text}
                  <i className="ml-2 rounded-[var(--radius-pill)] border border-hairline px-2 text-[11px] text-text-muted not-italic">
                    {t.itemFreeTag}
                  </i>
                </span>
                <StepButton label={t.itemRemove(text)} icon={X} onClick={() => onFree?.(free.filter((_, j) => j !== i))} />
              </li>
            ))}
          </ul>
        )}
        <Button
          tone="secondary"
          icon={Plus}
          data-action="add-chapter-item"
          disabled={!catalog.data}
          onClick={() => setPicking(true)}
          className="self-start"
        >
          {t.catalogAddTitle}
        </Button>
        {help && <span className="text-[12px] text-text-muted">{help}</span>}
      </div>
      {picking && catalog.data && (
        <ItemPicker
          catalog={catalog.data}
          chosen={items}
          onAdd={(item) => onItems([...items, item])}
          onClose={() => setPicking(false)}
        />
      )}
    </>
  );
}

/** Un botón de ícono de la lista de objetos (− + quitar). */
export function StepButton({
  label,
  icon: Icon,
  disabled,
  onClick,
}: {
  label: string;
  icon: typeof X;
  disabled?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      disabled={disabled}
      onClick={onClick}
      className="flex size-8 items-center justify-center rounded-[var(--radius-nav)] border border-hairline text-on-surface-variant hover:text-gold disabled:pointer-events-none disabled:opacity-40"
    >
      <Icon size={15} aria-hidden="true" />
    </button>
  );
}
