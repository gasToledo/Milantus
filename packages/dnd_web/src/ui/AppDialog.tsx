import type { ReactNode } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import type { LucideIcon } from 'lucide-react';
import { cx } from './cx';

/** Una celda de la barra de acciones. `primary` va en negrita y es el verbo
 *  de la acción; `tone` solo para el camino irreversible o la salida
 *  esperada (`diseno-web.md` §8, «Color de las acciones»). */
export interface DialogAction {
  label: string;
  onSelect?: () => void;
  primary?: boolean;
  tone?: 'gold' | 'crimson' | 'verdant';
  /** Cerrar al tocarla (por defecto sí: «Cancelar», «Entendido»). */
  closes?: boolean;
  /** Apagada: «Comprar» cuando la bolsa no alcanza. */
  disabled?: boolean;
}

const TONE: Record<NonNullable<DialogAction['tone']>, string> = {
  gold: 'text-gold',
  crimson: 'text-crimson',
  verdant: 'text-verdant',
};

/**
 * El molde de diálogo (`AppDialog`): una placa del sistema —`surface`, filete,
 * radio 12, sin elevación— sobre un velo que separa por oscurecimiento. Radix
 * pone el foco atrapado, `Esc` para cerrar, `aria-modal` y el título como
 * nombre accesible. Ancho de lectura 480 por defecto (560 si el cuerpo es una
 * ficha y no prosa); el cuerpo scrollea solo y la barra de acciones —celdas de
 * 48 px sobre la placa, separadas por filete— queda fija al pie.
 */
export function AppDialog({
  open,
  onOpenChange,
  title,
  icon: Icon,
  iconClassName = 'text-gold',
  description,
  children,
  actions,
  width = 480,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  icon?: LucideIcon;
  iconClassName?: string;
  /** Una línea que el lector anuncia al abrir; si no hay, no se inventa. */
  description?: string;
  children?: ReactNode;
  actions: DialogAction[];
  width?: number;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-40 bg-scrim" />
        <Dialog.Content
          className="card fixed top-1/2 left-1/2 z-50 flex max-h-[min(85vh,720px)] w-[calc(100vw-32px)] -translate-x-1/2 -translate-y-1/2 flex-col overflow-hidden"
          style={{ maxWidth: width }}
        >
          <div className="flex items-center gap-2.5 px-5 pt-5">
            {Icon && <Icon size={20} aria-hidden="true" className={cx('shrink-0', iconClassName)} />}
            <Dialog.Title className="font-display text-[20px] text-on-surface">{title}</Dialog.Title>
          </div>
          {description ? (
            <Dialog.Description className="px-5 pt-2 text-on-surface-variant">{description}</Dialog.Description>
          ) : (
            // Sin descripción, Radix avisa en consola; se declara a propósito.
            <Dialog.Description className="sr-only">{title}</Dialog.Description>
          )}
          <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>
          <div className="flex border-t border-hairline bg-plaque">
            {actions.map((a, i) => {
              const cell = (
                <button
                  type="button"
                  onClick={a.onSelect}
                  disabled={a.disabled}
                  className={cx(
                    'min-h-12 flex-1 px-3 text-[14px] hover:bg-surface disabled:pointer-events-none disabled:opacity-40',
                    i > 0 && 'border-l border-hairline',
                    a.primary && 'font-bold',
                    a.tone ? TONE[a.tone] : a.primary ? 'text-gold' : 'text-on-surface',
                  )}
                >
                  {a.label}
                </button>
              );
              return a.closes === false ? (
                <span key={a.label} className="contents">
                  {cell}
                </span>
              ) : (
                <Dialog.Close key={a.label} asChild>
                  {cell}
                </Dialog.Close>
              );
            })}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
