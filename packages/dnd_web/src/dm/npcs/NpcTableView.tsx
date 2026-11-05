import { useState } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { Eye, EyeOff, X } from 'lucide-react';
import { useTexts } from '../../i18n/context';
import { Tooltip } from '../../ui/primitives';

const ROUND_BUTTON =
  'flex size-11 items-center justify-center rounded-full border border-hairline bg-surface text-on-surface hover:text-gold';

/**
 * «Mostrar a la mesa»: el retrato de un PNJ y su nombre, a pantalla completa,
 * para girar la pantalla hacia los jugadores. Muestra **solo** retrato y nombre
 * —ni números, ni tags, ni estado, ni trasfondo—. La app no le manda nada al
 * jugador: es una capa sobre la pantalla del DM, sin ruta, y por eso el DM
 * decide qué se ve.
 *
 * Tapa el panel lateral a propósito: lo que está a la vista de la mesa no debe
 * incluir la biblioteca de PNJ. El estado del nombre oculto no se guarda.
 */
export function NpcTableView({
  name,
  portrait,
  open,
  onOpenChange,
}: {
  name: string;
  portrait: string | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useTexts();
  const [nameHidden, setNameHidden] = useState(false);
  // La dirección que falló, como `Medallion`: si el retrato cambia se reintenta.
  const [failed, setFailed] = useState<string | null>(null);
  const shown = portrait !== null && failed !== portrait ? portrait : null;
  const toggleLabel = nameHidden ? t.npcShowName : t.npcHideName;
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Content
          data-npc-table
          className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-5 overflow-y-auto bg-scaffold p-4 outline-none"
          // Igual que `PortraitViewer`: sin esto el foco cae en un botón y su
          // tooltip se abriría solo.
          onOpenAutoFocus={(e) => {
            e.preventDefault();
            (e.currentTarget as HTMLElement).focus();
          }}
        >
          <Dialog.Title className="sr-only">{t.npcShowTable}</Dialog.Title>
          <Dialog.Description className="sr-only">{t.portraitOf(name)}</Dialog.Description>
          <div className="absolute top-4 right-4 flex gap-2">
            <Tooltip content={toggleLabel}>
              <button type="button" aria-label={toggleLabel} data-action="npc-table-name" onClick={() => setNameHidden((h) => !h)} className={ROUND_BUTTON}>
                {nameHidden ? <Eye size={20} aria-hidden="true" /> : <EyeOff size={20} aria-hidden="true" />}
              </button>
            </Tooltip>
            <Tooltip content={t.close}>
              <Dialog.Close asChild>
                <button type="button" aria-label={t.close} className={ROUND_BUTTON}>
                  <X size={20} aria-hidden="true" />
                </button>
              </Dialog.Close>
            </Tooltip>
          </div>
          {/* El marco no cambia de tamaño al ocultar el nombre: el alto sale de la
              ventana menos lo que ocupan el nombre y los márgenes. */}
          <div
            className="shrink-0 overflow-hidden rounded-[var(--radius-card)] border-2 border-gold bg-plaque"
            style={{
              width: 'min(calc((100dvh - 152px) * 3 / 4), 540px, calc(100vw - 32px))',
              aspectRatio: '3 / 4',
              containerType: 'inline-size',
            }}
          >
            {shown ? (
              <img src={shown} alt={t.portraitOf(name)} onError={() => setFailed(shown)} className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center">
                {/* No es `Medallion`: pide píxeles fijos y este círculo escala con
                    el marco (unidades de contenedor). */}
                <div
                  aria-hidden="true"
                  className="font-display flex items-center justify-center rounded-full border-2 border-gold text-on-surface"
                  style={{
                    width: '50cqw',
                    aspectRatio: '1',
                    fontSize: '22cqw',
                    background: 'radial-gradient(circle at 50% 35%, color-mix(in srgb, var(--gold) 40%, transparent), var(--plaque))',
                  }}
                >
                  {Array.from(name)[0]?.toUpperCase()}
                </div>
              </div>
            )}
          </div>
          {!nameHidden && <h2 className="font-display text-center text-[38px] leading-[1.2] break-words text-on-surface">{name}</h2>}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
