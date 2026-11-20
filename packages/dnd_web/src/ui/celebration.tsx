import type { CSSProperties, ReactNode } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { cx } from './cx';

/**
 * El lienzo de una celebración (el personaje recién creado y el final de la
 * subida de nivel): el velo, la tarjeta centrada, el héroe, el título y lo
 * que entra de a uno. El héroe, el cuerpo y las acciones son de cada una.
 * Un `Dialog` de Radix: el foco queda adentro y `Escape` llama a [onDismiss].
 */
export function CelebrationShell({
  kind,
  hero,
  title,
  subtitle,
  children,
  actions,
  onDismiss,
}: {
  /** Cuál es: fija el atributo que leen las pruebas, sin cambiar el marcado. */
  kind: 'created' | 'level-up';
  hero: ReactNode;
  title: string;
  subtitle: string;
  children: ReactNode;
  actions: ReactNode;
  onDismiss: () => void;
}) {
  return (
    <Dialog.Root open onOpenChange={(open) => !open && onDismiss()}>
      <Dialog.Portal>
        <Dialog.Overlay className="lv-scrim fixed inset-0 z-50 bg-scrim" />
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <Dialog.Content
            {...(kind === 'created' ? { 'data-created-celebration': true } : { 'data-level-up-celebration': true })}
            className="lv-card flex max-h-full w-[500px] max-w-full flex-col items-center overflow-y-auto rounded-[var(--radius-card)] border border-hairline bg-surface px-8 pt-8 pb-6 text-center outline-none"
          >
            <div aria-hidden="true" className="relative flex size-24 items-center justify-center">
              {hero}
            </div>
            <Dialog.Title className="font-display mt-[18px] text-[28px] text-on-surface">{title}</Dialog.Title>
            <Dialog.Description className="mt-1.5 text-[14px] text-on-surface-variant">{subtitle}</Dialog.Description>
            <div className="mt-[22px] w-full text-left">{children}</div>
            {actions}
          </Dialog.Content>
        </div>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

/** El escalonado arranca cuando el aro ya se abrió: cada ítem, 60 ms después. */
export function celebrationDelay(i: number): CSSProperties {
  return { animationDelay: `${620 + i * 60}ms` };
}

/** El rótulo de una sección, con el filete. `spaced` es el de abajo: lleva
 *  margen aunque sea el único (así estaba en las dos celebraciones). */
export function CelebrationHeading({ label, spaced = false }: { label: string; spaced?: boolean }) {
  return (
    <p className={cx('flex items-center gap-3', spaced && 'mt-[18px]')}>
      <span className="eyebrow shrink-0">{label}</span>
      <span aria-hidden="true" className="h-px flex-1 bg-hairline" />
    </p>
  );
}

/** Los rasgos que entran de a uno. [start] sigue la cuenta de lo que ya
 *  entró arriba (las placas o las filas). */
export function CelebrationPills({ items, start }: { items: string[]; start: number }) {
  return (
    <ul className="mt-2.5 flex flex-wrap gap-1.5">
      {items.map((item, i) => (
        <li
          key={item}
          className="lv-up rounded-[var(--radius-pill)] border border-hairline bg-gold-soft px-3 py-1 text-[12.5px] text-gold"
          style={celebrationDelay(start + i)}
        >
          {item}
        </li>
      ))}
    </ul>
  );
}
