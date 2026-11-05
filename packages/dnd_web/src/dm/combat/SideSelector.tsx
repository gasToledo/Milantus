import { useTexts } from '../../i18n/context';
import { cx } from '../../ui/cx';

/** Las pestañas segmentadas de la lámina (`.seg`): una fila de botones
 *  `aria-pressed` sobre una placa hundida. La palabra siempre está. */
export function Segmented<T extends string>({
  options,
  value,
  onChange,
  label,
  disabled = false,
  className,
}: {
  options: { value: T; label: string }[];
  /** `null` es que todavía no se eligió nada. */
  value: T | null;
  onChange: (value: T) => void;
  label: string;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <div role="group" aria-label={label} className={cx('flex gap-[3px] rounded-[var(--radius-nav)] border border-hairline bg-plaque p-[3px]', className)}>
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          aria-pressed={o.value === value}
          data-segment={o.value}
          disabled={disabled}
          onClick={() => o.value !== value && onChange(o.value)}
          className={cx(
            'min-h-[34px] min-w-0 flex-1 rounded-[7px] px-2 text-[12.5px] transition-colors duration-[120ms] disabled:pointer-events-none disabled:opacity-45',
            o.value === value ? 'bg-gold-soft font-semibold text-gold' : 'text-on-surface-variant hover:text-on-surface',
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Aliado · Enemigo · Neutral. Sin valor por defecto cuando [value] es `null`. */
export function SideSelector({ value, onChange, disabled }: { value: string | null; onChange: (side: string) => void; disabled?: boolean }) {
  const t = useTexts();
  return (
    <Segmented
      label={t.dmWhichSide}
      options={['ally', 'enemy', 'neutral'].map((s) => ({ value: s, label: t.encSides[s]! }))}
      value={value}
      onChange={onChange}
      disabled={disabled}
    />
  );
}
