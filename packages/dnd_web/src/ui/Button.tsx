import type { ButtonHTMLAttributes, ReactNode } from 'react';
import type { LucideIcon } from 'lucide-react';
import { Link } from '../router';
import { cx } from './cx';

/**
 * `primary`: el oro lleno, el verbo de la pantalla (uno por vista).
 * `secondary`: filete y texto, para lo que acompaña.
 * `danger`: el carmesí, solo para el camino irreversible (`diseno-web.md` §8).
 */
export type ButtonTone = 'primary' | 'secondary' | 'danger';

const TONES: Record<ButtonTone, string> = {
  primary: 'bg-gold text-on-primary font-semibold hover:opacity-90',
  secondary: 'border border-hairline text-on-surface hover:bg-plaque',
  danger: 'border border-crimson text-crimson hover:bg-plaque',
};

const BASE =
  'inline-flex min-h-9 items-center justify-center gap-2 rounded-[var(--radius-nav)] px-4 py-2 text-[14px] no-underline';

interface Common {
  tone?: ButtonTone;
  icon?: LucideIcon;
  children: ReactNode;
  className?: string;
}

export function Button({
  tone = 'primary',
  icon: Icon,
  children,
  className,
  type = 'button',
  ...rest
}: Common & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button type={type} className={cx(BASE, TONES[tone], className)} {...rest}>
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
  icon: Icon,
  children,
  className,
  href,
  internal = false,
}: Common & { href: string; internal?: boolean }) {
  const props = { href, className: cx(BASE, TONES[tone], className) };
  const body = (
    <>
      {Icon && <Icon size={16} aria-hidden="true" />}
      {children}
    </>
  );
  return internal ? <Link {...props}>{body}</Link> : <a {...props}>{body}</a>;
}
