import { useCallback, useLayoutEffect, useRef } from 'react';
import { prefersReducedMotion } from './motion';

/** Nombre de view-transition de una tarjeta de lista: el prefijo la distingue
 *  de las otras listas y el id queda como identificador CSS válido. */
export function vtName(prefix: string, id: string): string {
  return `${prefix}-${id.replace(/[^\w-]/g, '_')}`;
}

/**
 * Anima con View Transitions lo que cambia el orden o el contenido de una
 * lista de tarjetas (`.roster-card`, ver `index.css`): cada una se desliza a
 * su lugar, la nueva aparece y la que se va se desvanece. Lo usan el dashboard
 * y la Mesa.
 *
 * La lista nueva no se pinta al volver de `update`: un `setQueryData` llega a
 * la pantalla en otra vuelta del bucle. Por eso la transición espera al commit
 * de [list] (lo que la pantalla dibuja), con un tope para no dejar la pantalla
 * congelada si no llega a cambiar. `update` no puede esperar a la red: dentro
 * de la transición la pantalla no se pinta. Arrastrar no pasa por acá:
 * `useHoldDrag` ya anima lo suyo.
 */
export function useListTransition(list: unknown) {
  const committed = useRef<(() => void) | null>(null);
  useLayoutEffect(() => {
    committed.current?.();
    committed.current = null;
  }, [list]);
  return useCallback((update: () => unknown) => {
    if (!document.startViewTransition || prefersReducedMotion()) {
      void update();
      return;
    }
    document.startViewTransition(
      () =>
        new Promise<void>((resolve) => {
          committed.current = resolve;
          window.setTimeout(resolve, 300);
          void update();
        }),
    );
  }, []);
}
