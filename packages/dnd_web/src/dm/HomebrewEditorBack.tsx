import type { MutableRefObject } from 'react';
import { SidebarBack } from '../ui/Shell';

/** El «volver» del panel lateral de un editor del Homebrew: pregunta antes si
 *  hay cambios (lo sabe el formulario, que registra en [leaveRef] cómo salir). */
export function HomebrewEditorBack({ exitHref, leaveRef }: { exitHref: string; leaveRef: MutableRefObject<(() => void) | null> }) {
  return (
    <SidebarBack
      href={exitHref}
      onClick={(e) => {
        // Sin formulario montado (cargando, error) es un enlace común.
        if (!leaveRef.current) return;
        e.preventDefault();
        leaveRef.current();
      }}
    />
  );
}
