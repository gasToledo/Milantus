import type { ReactNode } from 'react';
import { SectionRule } from '../ui/data';

/**
 * La cabecera de toda sección del Modo DM: título en Georgia 30 con una pill
 * que dice en qué está (el estado de la campaña, «Solo lectura»), a su derecha
 * las `actions` de la pantalla (menú de la campaña, «Sumar personaje») y
 * debajo la regla ornamental. El `h1` es el título: uno por pantalla.
 */
export function DmHeader({ title, kicker, actions }: { title: string; kicker?: string; actions?: ReactNode }) {
  return (
    <>
      <header className="flex flex-wrap items-center gap-x-3 gap-y-2">
        <h1 className="font-display min-w-0 flex-[1_1_260px] text-[30px] leading-tight font-normal break-words text-on-surface">
          {title}
        </h1>
        {kicker && (
          <span className="rounded-[var(--radius-pill)] border border-hairline bg-plaque px-3.5 py-[5px] text-[12px] text-on-surface-variant">
            {kicker}
          </span>
        )}
        {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
      </header>
      <SectionRule className="my-0" />
    </>
  );
}
