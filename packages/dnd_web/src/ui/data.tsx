import type { ReactNode } from 'react';
import type { LucideIcon } from 'lucide-react';
import { cx } from './cx';

// Las piezas que muestran números de la ficha. Ninguna calcula nada: reciben
// el valor ya resuelto por el motor (`computeSheet`) y solo deciden cómo se ve
// y cómo lo anuncia un lector de pantalla.

/** Rótulo de sección en mayúsculas espaciadas (`Eyebrow`). */
export function Eyebrow({ children, className }: { children: ReactNode; className?: string }) {
  return <p className={cx('eyebrow', className)}>{children}</p>;
}

/**
 * Placa de la **banda táctica**: ícono y rótulo arriba, la cifra grande en
 * sans negrita con cifras tabulares (se compara con la de al lado), y todo
 * **centrado**. A la izquierda, como `StatTile` de Flutter, una placa ancha con
 * «−1» quedaba casi vacía (se ajustó en el lienzo de diseño). `suffix` es la
 * unidad atenuada («pies», «/ 24»), en la misma línea y sobre la misma base
 * que la cifra; `footer` va abajo a todo el ancho (la barra de PG) y
 * `caption`, debajo de él (el porcentaje). Es un par `dt`/`dd`: va adentro de
 * un `<dl>`, que arma la grilla (`.tactical-band` en `index.css`).
 */
export function StatTile({
  id,
  icon: Icon,
  label,
  value,
  suffix,
  valueClassName = 'text-on-surface',
  caption,
  footer,
}: {
  id: string;
  icon?: LucideIcon;
  label: string;
  value: ReactNode;
  suffix?: ReactNode;
  valueClassName?: string;
  caption?: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <div className="plaque flex min-h-[96px] min-w-0 flex-col items-center px-4 py-3.5 text-center" data-stat={id}>
      <dt className="flex max-w-full items-center justify-center gap-1.5 text-[11px] tracking-[1.1px] text-text-muted uppercase">
        {Icon && <Icon size={14} aria-hidden="true" className="shrink-0 text-gold" />}
        <span className="truncate">{label}</span>
      </dt>
      <dd className="flex w-full min-w-0 flex-1 flex-col">
        <span className="flex flex-1 items-center justify-center pt-2">
          <span className="leading-none whitespace-nowrap">
            <span className={cx('num text-[30px]', valueClassName)} data-field="value">
              {value}
            </span>
            {suffix && <span className="text-[14px] text-text-muted"> {suffix}</span>}
          </span>
        </span>
        {footer && <div className="w-full pt-2.5">{footer}</div>}
        {caption && <span className="mt-1 text-[11px] text-text-muted tabular-nums">{caption}</span>}
      </dd>
    </div>
  );
}

/**
 * Rótulo en mayúsculas y valor en Georgia sobre la placa, centrado
 * (`StatPlaque`): las tiras cortas dentro de una tarjeta (CD, ataque de
 * conjuro). `dense` para tarjetas apretadas. Par `dt`/`dd`.
 */
export function StatPlaque({
  id,
  label,
  value,
  dense = false,
  valueClassName = 'text-gold',
}: {
  id?: string;
  /** Texto, o un nodo cuando el rótulo visible es una abreviatura y el lector
   *  necesita la palabra completa. */
  label: ReactNode;
  value: ReactNode;
  dense?: boolean;
  valueClassName?: string;
}) {
  return (
    <div className={cx('plaque flex min-w-0 flex-col items-center text-center', dense ? 'px-2 py-1.5' : 'px-3 py-2.5')} data-stat={id}>
      <dt className={cx('text-text-muted uppercase', dense ? 'text-[8.5px] tracking-[0.5px]' : 'text-[10px] tracking-[1.2px]')}>
        {label}
      </dt>
      <dd
        className={cx('font-display mt-1 leading-none tabular-nums', dense ? 'text-[16px]' : 'text-[24px]', valueClassName)}
        data-field="value"
      >
        {value}
      </dd>
    </div>
  );
}

/**
 * La CA dentro de la silueta de un escudo, con filete dorado de 1.5 px. **Solo
 * para CA**, y solo donde la CA es el tema (Defensa): en la banda táctica va
 * una placa común. `label` es lo que anuncia el lector («Clase de armadura
 * 18»), porque el escudo solo no dice qué número es.
 */
export function ShieldBadge({ value, label, height = 64 }: { value: number; label: string; height?: number }) {
  const k = height / 52;
  return (
    <span role="img" aria-label={label} className="relative inline-flex shrink-0 items-center justify-center" style={{ width: height * 0.86, height }}>
      <svg viewBox="0 0 44 52" width="100%" height="100%" aria-hidden="true" className="absolute inset-0">
        <path
          d="M22 1.5 L41.5 8 V24 C41.5 37 33 46 22 50.5 C11 46 2.5 37 2.5 24 V8 Z"
          fill="var(--plaque)"
          stroke="var(--gold)"
          strokeWidth="1.5"
          strokeLinejoin="round"
        />
      </svg>
      <span className="font-display relative -mt-[6%] text-gold tabular-nums" style={{ fontSize: 20 * k }}>
        {value}
      </span>
    </span>
  );
}

/** Regla ornamental: filete con un rombo dorado de 7 px al centro. Decorativa:
 *  el lector la ignora. */
export function SectionRule({ className }: { className?: string }) {
  return (
    <div aria-hidden="true" className={cx('my-[18px] flex items-center gap-2', className)}>
      <span className="h-px flex-1 bg-hairline" />
      <span className="h-[7px] w-[7px] rotate-45 bg-gold" />
      <span className="h-px flex-1 bg-hairline" />
    </div>
  );
}

/** Cápsula de radio 20 (`GoldPill`). `highlighted={false}` la vuelve neutra:
 *  el oro es información y no se gasta en lo que no la lleva. */
export function Pill({
  children,
  highlighted = true,
  as: Tag = 'span',
  className,
}: {
  children: ReactNode;
  highlighted?: boolean;
  as?: 'span' | 'li';
  className?: string;
}) {
  return (
    <Tag
      className={cx(
        'inline-flex items-center gap-1 rounded-[var(--radius-pill)] border border-hairline px-[9px] py-[2px] text-[11px]',
        highlighted ? 'bg-gold-soft text-gold' : 'bg-plaque text-on-surface-variant',
        className,
      )}
    >
      {children}
    </Tag>
  );
}

/**
 * Usos restantes (`UsagePips`): llenos en oro, gastados atenuados. El color
 * no alcanza solo, así que `label` dice la cuenta («Canalizar divinidad: 1 de
 * 2») y los puntos quedan ocultos al lector.
 */
export function Pips({ max, left, label }: { max: number; left: number; label: string }) {
  return (
    <span role="img" aria-label={label} className="flex flex-wrap justify-end gap-1">
      {Array.from({ length: max }, (_, i) => (
        <span
          key={i}
          aria-hidden="true"
          className={cx(
            'h-3 w-3 rounded-full border',
            i < left ? 'border-gold bg-gold' : 'border-text-muted bg-transparent',
          )}
        />
      ))}
    </span>
  );
}

/**
 * Barra fina de progreso (`ThinBar`): la de los PG. Es un `meter` con su
 * `aria-label`, `aria-valuenow` y el texto del valor: así el lector la lee
 * aunque la cifra de al lado no esté. Recorre el tramo al cambiar (220 ms,
 * apagado si el sistema pide menos movimiento).
 */
export function ThinBar({
  value,
  max,
  label,
  valueText,
  colorClassName = 'bg-gold',
  height = 5,
}: {
  value: number;
  max: number;
  label: string;
  valueText?: string;
  colorClassName?: string;
  height?: number;
}) {
  const ratio = max <= 0 ? 0 : Math.min(1, Math.max(0, value / max));
  return (
    <div
      role="meter"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={Math.max(0, Math.min(value, max))}
      aria-valuetext={valueText}
      className="w-full overflow-hidden bg-hairline"
      style={{ height, borderRadius: height / 2 }}
    >
      <div className={cx('thin-bar-fill h-full', colorClassName)} style={{ width: `${ratio * 100}%`, borderRadius: height / 2 }} />
    </div>
  );
}

/** El color de los PG según cuánto queda (`AppPalette.hpColor`): verde con
 *  más de la mitad, oro hasta un cuarto, carmesí debajo. */
export const HP_CRITICAL_RATIO = 0.25;
export function hpTone(ratio: number): { bar: string; text: string } {
  if (ratio > 0.5) return { bar: 'bg-verdant', text: 'text-verdant' };
  if (ratio > HP_CRITICAL_RATIO) return { bar: 'bg-gold', text: 'text-gold' };
  return { bar: 'bg-crimson', text: 'text-crimson' };
}
