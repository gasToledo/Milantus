import { useEffect, type RefObject } from 'react';

/**
 * La lista y el detalle del Códice y del Bestiario scrollean solos y tienen
 * que entrar enteros en la pantalla: si miden la ventana completa pero empiezan
 * debajo del título y el buscador, su final queda fuera de la vista. CSS no
 * sabe dónde empiezan (el alto de los filtros cambia con el ancho), así que se
 * mide y `index.css` lo descuenta en `--codex-list-top`. Va en el padre, que
 * es la grilla de las dos columnas: así lo heredan la lista y el detalle.
 */
export function useListFitsViewport(ref: RefObject<HTMLElement | null>) {
  useEffect(() => {
    const el = ref.current;
    const grid = el?.parentElement;
    if (!el || !grid) return;
    const measure = () => grid.style.setProperty('--codex-list-top', `${el.getBoundingClientRect().top + window.scrollY}px`);
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [ref]);
}
