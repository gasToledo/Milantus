import type { CSSProperties } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { useTexts } from '../i18n/context';
import { Button } from '../ui/Button';
import { StatPlaque } from '../ui/data';
import { Medallion } from '../ui/Medallion';

/** Lo que dice la presentación de un personaje recién creado. Lo arma el
 *  creador con la ficha que acaba de salir del motor: acá no se calcula nada. */
export interface CreatedData {
  name: string;
  subtitle: string;
  initial: string;
  accent: string | null;
  stats: { label: string; value: string | number; key?: boolean }[];
  features: string[];
}

// El aviso viaja del creador a la ficha por la memoria del módulo, sin
// persistirse: recargar la ficha no tiene que repetir la presentación.
const announced = new Map<string, CreatedData>();

export function announceCreated(id: string, data: CreatedData) {
  announced.set(id, data);
}

/** No lo consume: el modo estricto de React llama dos veces al inicializador de
 *  `useState` que lo lee, y la segunda ya no lo encontraría. Lo borra
 *  `clearCreated`, al cerrar. */
export function createdFor(id: string): CreatedData | null {
  return announced.get(id) ?? null;
}

export function clearCreated() {
  announced.clear();
}

/**
 * La presentación al crear un personaje (el lienzo «Creador: el personaje toma
 * forma», lámina C), armada como la celebración de la subida de nivel: el
 * medallón cae con el acento de su clase, un aro se abre y lo que trae entra de
 * a uno. Un `Dialog` de Radix: el foco queda adentro y `Escape` la cierra.
 */
export function CreatedCelebration({ data, onClose }: { data: CreatedData; onClose: () => void }) {
  const t = useTexts();
  // El escalonado sigue después del aro: las placas y los rasgos, en una cuenta.
  const delay = (i: number) => ({ animationDelay: `${620 + i * 60}ms` }) as CSSProperties;
  const ring = { borderColor: data.accent ?? 'var(--gold)' } as CSSProperties;
  return (
    <Dialog.Root open onOpenChange={(open) => !open && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay className="lv-scrim fixed inset-0 z-50 bg-scrim" />
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <Dialog.Content
            data-created-celebration
            className="lv-card flex max-h-full w-[500px] max-w-full flex-col items-center overflow-y-auto rounded-[var(--radius-card)] border border-hairline bg-surface px-8 pt-8 pb-6 text-center outline-none"
          >
            <div aria-hidden="true" className="relative flex size-24 items-center justify-center">
              <span className="cr-ring absolute size-20 rounded-full border-2" style={ring} />
              <span className="cr-med relative flex">
                <Medallion name={data.initial} accent={data.accent} size={80} />
              </span>
            </div>
            <Dialog.Title className="font-display mt-[18px] text-[28px] text-on-surface">{t.crCelebrateTitle(data.name)}</Dialog.Title>
            <Dialog.Description className="mt-1.5 text-[14px] text-on-surface-variant">{data.subtitle}</Dialog.Description>

            <div className="mt-[22px] w-full text-left">
              <p className="flex items-center gap-3">
                <span className="eyebrow shrink-0">{t.crCelebrateStart}</span>
                <span aria-hidden="true" className="h-px flex-1 bg-hairline" />
              </p>
              <dl className="mt-2.5 grid grid-cols-4 gap-2">
                {data.stats.map((s, i) => (
                  <StatPlaque
                    key={s.label}
                    label={s.label}
                    value={s.value}
                    valueClassName={s.key ? 'text-gold' : 'text-on-surface'}
                    className="lv-up"
                    style={delay(i)}
                  />
                ))}
              </dl>
              {data.features.length > 0 && (
                <>
                  <p className="mt-[18px] flex items-center gap-3">
                    <span className="eyebrow shrink-0">{t.crCelebrateBrings}</span>
                    <span aria-hidden="true" className="h-px flex-1 bg-hairline" />
                  </p>
                  <ul className="mt-2.5 flex flex-wrap gap-1.5">
                    {data.features.map((f, i) => (
                      <li
                        key={f}
                        className="lv-up rounded-[var(--radius-pill)] border border-hairline bg-gold-soft px-3 py-1 text-[12.5px] text-gold"
                        style={delay(data.stats.length + i)}
                      >
                        {f}
                      </li>
                    ))}
                  </ul>
                </>
              )}
            </div>

            <Button className="mt-[26px] min-h-11 w-full" onClick={onClose} data-action="created-close">
              {t.crCelebrateClose}
            </Button>
          </Dialog.Content>
        </div>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
