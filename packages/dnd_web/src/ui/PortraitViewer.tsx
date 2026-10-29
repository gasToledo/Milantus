import * as Dialog from '@radix-ui/react-dialog';
import { X } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { Tooltip } from './primitives';

/**
 * El retrato a pantalla completa (`portrait_viewer.dart`): la imagen original,
 * entera, sobre el velo. Se cierra con `Esc`, con un clic afuera o con el
 * botón; Radix pone el foco atrapado y el título como nombre accesible.
 *
 * ponytail: sin zoom ni arrastre propios (Flutter tiene `InteractiveViewer`);
 * el original llega entero y el navegador ya acerca con el gesto de la
 * pantalla. Si hace falta mirar un detalle, se suma acá.
 */
export function PortraitViewer({
  src,
  name,
  open,
  onOpenChange,
}: {
  src: string;
  name: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useTexts();
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-40 bg-scrim" />
        <Dialog.Content
          className="fixed top-1/2 left-1/2 z-50 -translate-x-1/2 -translate-y-1/2 outline-none"
          data-portrait-viewer
          // El foco va al visor y no al botón de cerrar: si no, su tooltip se
          // abriría solo encima del retrato.
          onOpenAutoFocus={(e) => {
            e.preventDefault();
            (e.currentTarget as HTMLElement).focus();
          }}
        >
          <Dialog.Title className="sr-only">{t.portraitOf(name)}</Dialog.Title>
          <Dialog.Description className="sr-only">{t.portraitOf(name)}</Dialog.Description>
          <img
            src={src}
            alt={t.portraitOf(name)}
            className="block max-h-[calc(100vh-64px)] max-w-[calc(100vw-32px)] rounded-[var(--radius-card)] object-contain"
          />
          {/* Adentro del contenido y no suelto: el foco queda atrapado ahí, y
              afuera el botón no se alcanzaría con el teclado. */}
          <Tooltip content={t.portraitClose}>
            <Dialog.Close asChild>
              <button
                type="button"
                aria-label={t.portraitClose}
                className="absolute top-2 right-2 flex h-10 w-10 items-center justify-center rounded-full border border-hairline bg-surface text-on-surface hover:text-gold"
              >
                <X size={20} aria-hidden="true" />
              </button>
            </Dialog.Close>
          </Tooltip>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
