import { useId, useState, type ReactNode } from 'react';
import { CircleAlert } from 'lucide-react';
import { useTexts } from '../../i18n/context';
import type { Texts } from '../../i18n/texts';
import { cx } from '../../ui/cx';
import { Switch } from '../../ui/primitives';
import { FilterPill } from '../npcs/NpcLibraryView';

// Las piezas que los formularios de especie y trasfondo comparten: un campo con
// su rótulo y su error, una sección y un grupo de pills a marcar. Ninguna sabe
// de reglas: qué es un error y cuántas se pueden marcar lo dice el motor.

/** El texto de un código de error numérico del motor (`number`, `integer`,
 *  `range:a:b`), sin el rango reescrito acá. */
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

// Un campo de 40 px, radio 8. El borde se oscurece hacia el oro al pasar el
// puntero y, con el foco, el contorno dorado lo rodea con 1 px de separación.
const INPUT =
  'w-full min-w-0 rounded-[8px] border bg-plaque px-3 text-[14px] text-on-surface transition-colors duration-[120ms] hover:border-[color-mix(in_srgb,var(--gold)_35%,var(--hairline))] focus-visible:border-gold focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-gold';
const LABEL = 'text-[12.5px] text-on-surface-variant';

/** El error de un campo: ícono y texto en carmesí, que entra con `step-in`. */
function FieldError({ message }: { message: string }) {
  const t = useTexts();
  return (
    <span role="alert" className="step-in flex items-center gap-1.5 text-[12.5px] text-crimson">
      <CircleAlert size={14} aria-label={t.error} role="img" className="shrink-0" />
      {message}
    </span>
  );
}

/**
 * Un campo de texto con su rótulo y, si hay, su error en carmesí debajo. El
 * error se muestra **después de interactuar**: cuando el campo ya perdió el foco
 * una vez o cuando el formulario pide mostrarlos todos (`showError`, que pasa a
 * ser cierto al intentar guardar). El formulario le da siempre el error del motor.
 */
export function TextField({
  label,
  value,
  onChange,
  error,
  showError,
  dataField,
  autoFocus,
  numeric,
  className,
  onFocus,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  error?: string | null;
  /** Mostrar el error aunque el campo no haya perdido el foco todavía. */
  showError?: boolean;
  dataField?: string;
  autoFocus?: boolean;
  /** Entrar al campo: el formulario explica la regla de ese número. */
  onFocus?: () => void;
  /** Un número: en negrita y con cifras tabulares, para compararlo con el de al lado. */
  numeric?: boolean;
  className?: string;
}) {
  const [left, setLeft] = useState(false);
  const shown = error && (left || showError) ? error : null;
  return (
    <label className={cx('flex min-w-0 flex-col gap-1.5', className)}>
      <span className={LABEL}>{label}</span>
      <input
        data-field={dataField}
        value={value}
        autoFocus={autoFocus}
        onFocus={onFocus}
        onBlur={() => setLeft(true)}
        inputMode={numeric ? 'numeric' : undefined}
        aria-invalid={shown ? true : undefined}
        onChange={(e) => onChange(e.target.value)}
        className={cx(INPUT, 'h-10', numeric && 'font-bold tabular-nums', shown ? 'border-crimson' : 'border-hairline')}
      />
      {shown && <FieldError message={shown} />}
    </label>
  );
}

/** Un texto de varias líneas con su rótulo. */
export function TextAreaField({ label, value, onChange, dataField }: { label: string; value: string; onChange: (value: string) => void; dataField?: string }) {
  return (
    <label className="flex min-w-0 flex-col gap-1.5">
      <span className={LABEL}>{label}</span>
      <textarea
        data-field={dataField}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={cx(INPUT, 'min-h-24 resize-y border-hairline py-2.5 leading-[1.5]')}
      />
    </label>
  );
}

/** Una sección del formulario: siempre abierta, con su número y su título en
 *  Georgia. [className] cambia cómo se acomoda el contenido (una grilla). */
export function FormSection({ n, title, children, className }: { n: number; title: string; children: ReactNode; className?: string }) {
  return (
    <section className={cx('card p-4', className ?? 'flex flex-col gap-3')}>
      <h2 className="font-display col-span-full flex items-center gap-2.5 text-[16px] text-on-surface">
        <span
          aria-hidden="true"
          className="flex size-[22px] shrink-0 items-center justify-center rounded-full border border-hairline bg-plaque font-sans text-[11.5px] font-bold text-text-muted"
        >
          {n}
        </span>
        {title}
      </h2>
      {children}
    </section>
  );
}

/** Un sí/no suelto: el rótulo a la izquierda y el interruptor a la derecha.
 *  Apagado (`disabled`), el motivo va debajo. */
export function SwitchRow({
  label,
  checked,
  onChange,
  disabled,
  reason,
}: {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  reason?: string | null;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center justify-between gap-3">
        <span id={`${id}-label`} className="text-[14px] text-on-surface">
          {label}
        </span>
        <Switch id={id} label={label} labelledBy={`${id}-label`} checked={checked} onCheckedChange={onChange} disabled={disabled} />
      </div>
      {reason && <p className="text-[12.5px] text-text-muted">{reason}</p>}
    </div>
  );
}

/** Peso y precio en cobre, que arma y armadura piden igual: la sección Economía. */
export function EconomySection({
  weight,
  costCp,
  errors,
  showError,
  n,
  onChange,
}: {
  weight: string;
  costCp: string;
  errors: Record<string, string>;
  showError: boolean;
  n: number;
  onChange: (patch: { weight?: string; costCp?: string }) => void;
}) {
  const t = useTexts();
  return (
    <FormSection n={n} title={t.hbEconomy} className="grid gap-x-3.5 gap-y-3 sm:grid-cols-2">
      <TextField numeric label={t.hbWeightLabel} value={weight} onChange={(weight) => onChange({ weight })} error={weightError(errors.weight, t)} showError={showError} />
      <TextField numeric label={t.hbPriceLabel} value={costCp} onChange={(costCp) => onChange({ costCp })} error={numberError(errors.costCp, t)} showError={showError} />
    </FormSection>
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
  onTouch,
}: {
  label: string;
  /** El título de la sección ya lo dice: el rótulo queda solo para lectores de pantalla. */
  hideLabel?: boolean;
  options: { id: string; label: string }[];
  selected: string[];
  onChange: (selected: string[]) => void;
  max?: number;
  error?: string | null;
  /** Se llama con el id de la pill tocada, marcada o desmarcada. */
  onTouch?: (id: string) => void;
}) {
  const known = new Set(options.map((o) => o.id));
  const rows = [...options.map((o) => ({ ...o, raw: false })), ...selected.filter((id) => !known.has(id)).map((id) => ({ id, label: id, raw: true }))];
  const full = max !== undefined && selected.length >= max;
  const toggle = (id: string) => onChange(selected.includes(id) ? selected.filter((x) => x !== id) : [...selected, id]);
  return (
    <div role="group" aria-label={label} className="flex flex-col gap-1.5">
      <span className={cx(LABEL, hideLabel && 'sr-only')}>{label}</span>
      <div className="flex flex-wrap gap-1.5">
        {rows.map((o) => (
          <FilterPill
            key={o.id}
            label={o.label}
            pressed={selected.includes(o.id)}
            disabled={full && !selected.includes(o.id)}
            dashed={o.raw}
            onClick={() => {
              toggle(o.id);
              onTouch?.(o.id);
            }}
          />
        ))}
      </div>
      {error && <FieldError message={error} />}
    </div>
  );
}
