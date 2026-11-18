import { flushSync } from 'react-dom';
import { prefersReducedMotion } from './motion';

/** Los títulos de pantalla, de más específico a menos: tras el fundido el foco
 *  va al primero que aparezca. Un `h1` cualquiera es el último recurso. */
const TITLE = '[data-page-title], [data-dm-title], [data-sheet-title], [data-npc-title], [data-roster-title], h1';

let running = false;

/**
 * Cambia de pantalla con el fundido de siempre: la pantalla entera se funde
 * (View Transitions, `.page-fade` en `index.css`) y el foco pasa al título de
 * la que llega. Lo llama el router en cada cambio de pantalla, así ningún
 * enlace tiene que acordarse de pedirlo (antes era `fadeNavigate`, a mano, y la
 * mitad de las pantallas cambiaba de golpe).
 *
 * [update] cambia la ubicación y avisa a quien escucha; con `flushSync` React
 * dibuja la pantalla nueva dentro de la transición. Sin soporte, con menos
 * movimiento, con la pestaña oculta o con otro fundido en curso, cambia de una.
 */
export function withPageFade(update: () => void) {
  if (running || !document.startViewTransition || prefersReducedMotion() || document.visibilityState !== 'visible') {
    update();
    return;
  }
  running = true;
  const root = document.documentElement;
  // Le devuelve el nombre a la raíz y se lo saca a las tarjetas, que si no se
  // animarían aparte (ver `index.css`).
  root.classList.add('page-fade');
  const transition = document.startViewTransition(() => flushSync(update));
  void transition.finished.finally(() => {
    root.classList.remove('page-fade');
    running = false;
    // La transición no mueve el foco: el enlace tocado ya no existe y quedaría
    // en el documento.
    const title = document.querySelector<HTMLElement>(TITLE);
    if (!title) return;
    if (!title.hasAttribute('tabindex')) title.tabIndex = -1;
    title.focus({ preventScroll: true });
  });
}
