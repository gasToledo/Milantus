import { useEffect, useState } from 'react';
import { prefersReducedMotion } from './motion';

/**
 * Mueve el foco un turno después de pedirlo. El diálogo que se está cerrando
 * le devuelve el foco a su botón en este mismo turno, y ese botón a veces ya
 * no existe (se borró la fila, cambió el control): si se enfoca ahora, el
 * diálogo pisa el foco al terminar. `setTimeout(0)` corre después de ese
 * cierre, cuando la lista nueva ya se dibujó.
 *
 * [watch] rearma la espera cuando cambia (la lista que va a pintar el
 * destino). Con `retry`, si el elemento todavía no está no se olvida el
 * pedido: se vuelve a intentar cuando [watch] cambie. Sin `retry` el pedido
 * se da por cumplido igual, porque no hay a quién enfocar. Con `scroll`,
 * primero se lo trae a la vista y el foco no mueve el scroll.
 */
export function useDeferredFocus(watch?: unknown, options?: { retry?: boolean; scroll?: boolean }) {
  const retry = options?.retry ?? false;
  const scroll = options?.scroll ?? false;
  const [target, setTarget] = useState<string | null>(null);
  useEffect(() => {
    if (!target) return;
    const id = window.setTimeout(() => {
      const el = document.querySelector<HTMLElement>(target);
      if (!el) {
        if (!retry) setTarget(null);
        return;
      }
      if (scroll) {
        el.scrollIntoView({ block: 'nearest', behavior: prefersReducedMotion() ? 'auto' : 'smooth' });
        el.focus({ preventScroll: true });
      } else {
        el.focus();
      }
      setTarget(null);
    }, 0);
    return () => window.clearTimeout(id);
  }, [target, watch, retry, scroll]);
  return setTarget;
}
