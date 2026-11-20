import { flushSync } from 'react-dom';
import { prefersReducedMotion } from './motion';

/** Los títulos de pantalla, de más específico a menos: tras el fundido el foco
 *  va al primero que aparezca. Un `h1` cualquiera es el último recurso. */
const TITLE = '[data-page-title], [data-dm-title], [data-sheet-title], [data-npc-title], [data-roster-title], h1';

let running = false;

/** El foco al título de la pantalla que acaba de llegar. La transición no lo
 *  mueve: el enlace tocado ya no existe y quedaría en el documento. */
function focusTitle() {
  const title = document.querySelector<HTMLElement>(TITLE);
  if (!title) return;
  if (!title.hasAttribute('tabindex')) title.tabIndex = -1;
  title.focus({ preventScroll: true });
}

/**
 * Cambia de pantalla con el fundido de siempre: la pantalla entera se funde
 * (View Transitions, `.page-fade` en `index.css`) y el foco pasa al título de
 * la que llega. Lo llama el router en cada cambio de pantalla, así ningún
 * enlace tiene que acordarse de pedirlo (antes se pedía a mano, y la mitad de
 * las pantallas cambiaba de golpe).
 *
 * [update] cambia la ubicación y avisa a quien escucha; con `flushSync` React
 * dibuja la pantalla nueva antes de mover el foco. Sin soporte, con menos
 * movimiento, con la pestaña oculta o con otro fundido en curso, cambia de una
 * y el foco llega igual.
 */
export function withPageFade(update: () => void) {
  if (running || !document.startViewTransition || prefersReducedMotion() || document.visibilityState !== 'visible') {
    flushSync(update);
    focusTitle();
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
    focusTitle();
  });
}
