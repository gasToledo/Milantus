import { useEffect, type RefObject } from 'react';

/**
 * La lista del Códice y del Bestiario scrollea sola y tiene que entrar entera
 * en la pantalla: si mide la ventana completa pero empieza debajo del título y
 * el buscador, su final queda fuera de la vista hasta que scrollee la página,
 * y quien scrollea solo la lista no llega a las últimas entradas. CSS no sabe
 * dónde empieza la lista (el alto de los filtros cambia con el ancho), así que
 * se mide y `index.css` lo descuenta en `--codex-list-top`.
 */
export function useListFitsViewport(ref: RefObject<HTMLElement | null>) {
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const measure = () => {
      // Desde el borde del documento, sin el scroll ni el `sticky`: la
      // posición de la lista antes de que la página se mueva.
      const previous = el.style.position;
      el.style.position = 'static';
      el.style.setProperty('--codex-list-top', `${el.getBoundingClientRect().top + window.scrollY}px`);
      el.style.position = previous;
    };
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [ref]);
}
