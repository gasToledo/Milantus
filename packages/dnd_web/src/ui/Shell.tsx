import type { ReactNode } from 'react';
import { useTexts } from '../i18n/context';
import { Seal } from './Seal';

/**
 * Panel lateral de 236 px con el sello, y el contenido a la derecha. En
 * ancho de teléfono el panel pasa a ser una barra de arriba y todo se apila:
 * la maqueta no tiene scroll horizontal en ningún ancho.
 */
export function Shell({ children }: { children: ReactNode }) {
  const t = useTexts();
  return (
    <div className="min-h-screen md:grid md:grid-cols-[var(--sidebar-width)_1fr]">
      <a
        href="#contenido"
        className="sr-only focus:not-sr-only focus:absolute focus:z-10 focus:bg-surface focus:p-2 focus:text-gold"
      >
        {t.skipToContent}
      </a>
      <aside className="border-b border-hairline bg-surface md:sticky md:top-0 md:h-screen md:border-r md:border-b-0">
        <div className="flex items-center gap-3 p-4">
          <Seal />
          <div>
            <p className="font-display text-[18px] leading-tight text-on-surface">
              {t.appName}
            </p>
            <p className="text-[11px] tracking-[0.3px] text-gold">{t.appTagline}</p>
          </div>
        </div>
        <nav aria-label={t.navLabel} className="hidden px-3 md:block">
          {/* Una sola entrada por ahora: la ficha abierta, ya activa. */}
          <span
            aria-current="page"
            className="block rounded-[var(--radius-nav)] bg-gold-soft px-3 py-2 text-[14px] font-semibold text-gold"
          >
            {t.navSheet}
          </span>
        </nav>
      </aside>
      <main id="contenido" className="min-w-0 p-4 md:p-6">
        <div className="mx-auto max-w-[960px]">{children}</div>
      </main>
    </div>
  );
}

/** Estados de pantalla completa (sin sesión, no disponible, error…): sobrios,
 *  un título, una línea y, si hace falta, una acción real. */
export function Notice({
  title,
  body,
  action,
}: {
  title: string;
  body?: string;
  action?: ReactNode;
}) {
  return (
    <section className="card p-6" role="status">
      <h1 className="font-display text-[20px] text-on-surface">{title}</h1>
      {body && <p className="mt-2 text-on-surface-variant">{body}</p>}
      {action && <div className="mt-4">{action}</div>}
    </section>
  );
}

export function ActionLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a
      href={href}
      className="inline-block rounded-[var(--radius-nav)] bg-gold px-4 py-2 text-[14px] font-semibold text-on-primary"
    >
      {children}
    </a>
  );
}

export function ActionButton({
  onClick,
  children,
}: {
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="rounded-[var(--radius-nav)] bg-gold px-4 py-2 text-[14px] font-semibold text-on-primary"
    >
      {children}
    </button>
  );
}
