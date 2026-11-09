import type { ReactNode } from 'react';
import { useTexts } from '../../i18n/context';
import type { Texts } from '../../i18n/texts';
import { cx } from '../../ui/cx';
import { FilterPill } from '../npcs/NpcLibraryView';

// Las piezas que los formularios de especie y trasfondo comparten: un campo con
// su rótulo y su error, una sección y un grupo de pills a marcar. Ninguna sabe
// de reglas: qué es un error y cuántas se pueden marcar lo dice el motor.

/** El texto de un código de error numérico del motor (`number`, `integer`,
 *  `range:a:b`): los de Flutter, sin el rango reescrito acá. */
export function numberError(code: string | undefined, t: Texts): string | null {
  if (code === undefined) return null;
  if (code === 'number') return t.hbNumberRequired;
  if (code === 'integer') return t.hbIntInvalid;
  const range = /^range:(-?\d+):(-?\d+)$/.exec(code);
  return range ? t.hbRange(Number(range[1]), Number(range[2])) : null;
}

/** El texto de un código de error del peso: vacío, no numérico o negativo. */
export function weightError(code: string | undefined, t: Texts): string | null {
  if (code === undefined) return null;
  if (code === 'number') return t.hbWeightRequired;
  if (code === 'decimal') return t.hbNumberInvalid;
  if (code === 'negative') return t.hbNegative;
  return null;
}

/** El texto de un código de error de un dado (`required` o `dice`). */
export function diceError(code: string | undefined, t: Texts): string | null {
  if (code === undefined) return null;
  return code === 'required' ? t.hbDiceRequired : t.hbDiceInvalid;
}

const INPUT = 'h-[38px] w-full min-w-0 rounded-[var(--radius-input)] border bg-plaque px-3 text-[14px] text-on-surface';

/** Un campo de texto con su rótulo y, si hay, su error en carmesí debajo. */
export function TextField({
  label,
  value,
  onChange,
  error,
  dataField,
  autoFocus,
  numeric,
  className,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  error?: string | null;
  dataField?: string;
  autoFocus?: boolean;
  /** Un número: en negrita y con cifras tabulares, para compararlo con el de al lado. */
  numeric?: boolean;
  className?: string;
}) {
  return (
    <label className={cx('flex min-w-0 flex-col gap-1.5', className)}>
      <span className="text-[12px] text-text-muted">{label}</span>
      <input
        data-field={dataField}
        value={value}
        autoFocus={autoFocus}
        inputMode={numeric ? 'numeric' : undefined}
        aria-invalid={error ? true : undefined}
        onChange={(e) => onChange(e.target.value)}
        className={cx(INPUT, numeric && 'font-bold tabular-nums', error ? 'border-crimson' : 'border-hairline')}
      />
      {error && (
        <span role="alert" className="text-[12.5px] text-crimson">
          {error}
        </span>
      )}
    </label>
  );
}

/** Un texto de varias líneas con su rótulo. */
export function TextAreaField({ label, value, onChange, dataField }: { label: string; value: string; onChange: (value: string) => void; dataField?: string }) {
  return (
    <label className="flex min-w-0 flex-col gap-1.5">
      <span className="text-[12px] text-text-muted">{label}</span>
      <textarea
        rows={3}
        data-field={dataField}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="min-w-0 rounded-[var(--radius-input)] border border-hairline bg-plaque px-3 py-2 text-[14px] leading-[1.5] text-on-surface"
      />
    </label>
  );
}

/** Una sección del formulario: siempre abierta, con su título en Georgia. */
export function FormSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="card flex flex-col gap-2.5 p-4">
      <h2 className="font-display text-[16px] text-on-surface">{title}</h2>
      {children}
    </section>
  );
}

/** Peso y precio en cobre, que arma y armadura piden igual: la sección Economía. */
export function EconomySection({
  weight,
  costCp,
  errors,
  onChange,
}: {
  weight: string;
  costCp: string;
  errors: Record<string, string>;
  onChange: (patch: { weight?: string; costCp?: string }) => void;
}) {
  const t = useTexts();
  return (
    <section className="card grid gap-3.5 p-4 sm:grid-cols-2">
      <h2 className="font-display text-[16px] text-on-surface sm:col-span-2">{t.hbEconomy}</h2>
      <TextField numeric label={t.hbWeightLabel} value={weight} onChange={(weight) => onChange({ weight })} error={weightError(errors.weight, t)} />
      <TextField numeric label={t.hbPriceLabel} value={costCp} onChange={(costCp) => onChange({ costCp })} error={numberError(errors.costCp, t)} />
    </section>
  );
}

/**
 * Elegir varias de una lista cerrada, una `FilterPill` por opción con
 * `aria-pressed`. Una opción marcada que la lista no trae (una herramienta que
 * el glosario no conoce) se agrega al final con su id, punteada, para poder
 * quitarla. Con [max] marcadas, las demás quedan apagadas: un toque que no
 * responde parece roto.
 */
export function PillGroup({
  label,
  options,
  selected,
  onChange,
  max,
  error,
  hideLabel,
}: {
  label: string;
  /** El título de la sección ya lo dice: el rótulo queda solo para lectores de pantalla. */
  hideLabel?: boolean;
  options: { id: string; label: string }[];
  selected: string[];
  onChange: (selected: string[]) => void;
  max?: number;
  error?: string | null;
}) {
  const known = new Set(options.map((o) => o.id));
  const rows = [...options.map((o) => ({ ...o, raw: false })), ...selected.filter((id) => !known.has(id)).map((id) => ({ id, label: id, raw: true }))];
  const full = max !== undefined && selected.length >= max;
  const toggle = (id: string) => onChange(selected.includes(id) ? selected.filter((x) => x !== id) : [...selected, id]);
  return (
    <div role="group" aria-label={label} className="flex flex-col gap-1.5">
      <span className={cx('text-[12px] text-text-muted', hideLabel && 'sr-only')}>{label}</span>
      <div className="flex flex-wrap gap-1.5">
        {rows.map((o) => (
          <FilterPill
            key={o.id}
            label={o.label}
            pressed={selected.includes(o.id)}
            disabled={full && !selected.includes(o.id)}
            dashed={o.raw}
            onClick={() => toggle(o.id)}
          />
        ))}
      </div>
      {error && (
        <span role="alert" className="text-[12.5px] text-crimson">
          {error}
        </span>
      )}
    </div>
  );
}
