import { useState, type ReactNode } from 'react';
import * as Collapsible from '@radix-ui/react-collapsible';
import { ChevronDown, type LucideIcon } from 'lucide-react';
import { cx } from './cx';

/**
 * La tarjeta de sección (`sheetCard` en Flutter): superficie con filete,
 * cabecera con ícono dorado, título en Georgia 16 y, a la derecha, lo que
 * haga falta (`trailing`: un contador, una acción).
 *
 * Con `collapsible` la cabecera entera es el botón que pliega (Radix
 * Collapsible: `aria-expanded` y `aria-controls` vienen solos). El título
 * sigue siendo un encabezado: el botón va **adentro** del `h2`, así quien
 * navega por títulos lo encuentra igual.
 *
 * [id] arma los ids del título y del cuerpo, y tiene que ser único en la
 * pantalla.
 */
export function Card({
  id,
  title,
  icon: Icon,
  trailing,
  collapsible = false,
  defaultOpen = true,
  headingLevel = 2,
  className,
  children,
}: {
  id: string;
  title: string;
  icon?: LucideIcon;
  trailing?: ReactNode;
  collapsible?: boolean;
  defaultOpen?: boolean;
  headingLevel?: 2 | 3;
  className?: string;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  const H = headingLevel === 2 ? 'h2' : 'h3';
  const headingId = `h-${id}`;
  const label = (
    <>
      {Icon && <Icon size={18} aria-hidden="true" className="shrink-0 text-gold" />}
      <span className="font-display min-w-0 flex-1 text-[16px] break-words text-on-surface">{title}</span>
    </>
  );

  if (!collapsible) {
    return (
      <section aria-labelledby={headingId} className={cx('card min-w-0 p-4', className)} data-card={id}>
        <div className="mb-3 flex items-center gap-2">
          <H id={headingId} className="flex min-w-0 flex-1 items-center gap-2">
            {label}
          </H>
          {trailing}
        </div>
        {children}
      </section>
    );
  }

  return (
    <Collapsible.Root asChild open={open} onOpenChange={setOpen}>
      <section aria-labelledby={headingId} className={cx('card min-w-0 p-4', className)} data-card={id}>
        <div className="flex items-center gap-2">
          <H id={headingId} className="flex min-w-0 flex-1">
            <Collapsible.Trigger className="-m-1 flex min-w-0 flex-1 items-center gap-2 rounded-[var(--radius-nav)] p-1 text-left">
              {label}
              <ChevronDown
                size={18}
                aria-hidden="true"
                className={cx('shrink-0 text-text-muted transition-transform', open && 'rotate-180')}
              />
            </Collapsible.Trigger>
          </H>
          {trailing}
        </div>
        <Collapsible.Content className="mt-3">{children}</Collapsible.Content>
      </section>
    </Collapsible.Root>
  );
}
