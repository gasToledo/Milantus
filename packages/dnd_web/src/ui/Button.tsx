import type { ButtonHTMLAttributes, ReactNode } from 'react';
import type { LucideIcon } from 'lucide-react';
import { Link } from '../router';
import { cx } from './cx';

/**
 * `primary`: el oro lleno, el verbo de la pantalla (uno por vista).
 * `soft`: oro sobre `goldSoft` con filete dorado; el verbo de una barra de
 * herramientas, donde el oro lleno pesaría más que el contenido.
 * `secondary`: filete y texto, para lo que acompaña.
 * `danger`: el carmesí, solo para el camino irreversible (`diseno-web.md` §8).
 */
export type ButtonTone = 'primary' | 'soft' | 'secondary' | 'danger';

const TONES: Record<ButtonTone, string> = {
  primary: 'bg-gold text-on-primary font-semibold hover:opacity-90',
  soft: 'border border-gold bg-gold-soft text-gold font-medium hover:bg-plaque',
  secondary: 'border border-hairline text-on-surface hover:bg-plaque',
  danger: 'border border-crimson text-crimson hover:bg-plaque',
};

const BASE = 'inline-flex min-h-9 items-center justify-center gap-2 px-4 py-2 text-[14px] no-underline';

/** Radio 9 (el de los controles) o 20: una pill en una barra de pills. */
const SHAPES = { nav: 'rounded-[var(--radius-nav)]', pill: 'rounded-[var(--radius-pill)]' } as const;

interface Common {
  tone?: ButtonTone;
  shape?: keyof typeof SHAPES;
  icon?: LucideIcon;
  children: ReactNode;
  className?: string;
}

export function Button({
  tone = 'primary',
  shape = 'nav',
  icon: Icon,
  children,
  className,
  type = 'button',
  ...rest
}: Common & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button type={type} className={cx(BASE, SHAPES[shape], TONES[tone], className)} {...rest}>
      {Icon && <Icon size={16} aria-hidden="true" />}
      {children}
    </button>
  );
}

/**
 * Lo mismo, como enlace. `internal` navega dentro de `/v2` sin recargar; sin
 * él es un enlace común (a Flutter, a `/auth/login`).
 */
export function ButtonLink({
  tone = 'primary',
  shape = 'nav',
  icon: Icon,
  children,
  className,
  href,
  internal = false,
}: Common & { href: string; internal?: boolean }) {
  const props = { href, className: cx(BASE, SHAPES[shape], TONES[tone], className) };
  const body = (
    <>
      {Icon && <Icon size={16} aria-hidden="true" />}
      {children}
    </>
  );
  return internal ? <Link {...props}>{body}</Link> : <a {...props}>{body}</a>;
}
