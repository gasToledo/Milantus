import type { MouseEvent } from 'react';
import { navigate } from '../router';
import { prefersReducedMotion } from './motion';

/**
 * Navega con un fundido corto de la pantalla entera (View Transitions) en vez
 * de un corte: entre el dashboard y la ficha, de ida y de vuelta. Se probó que
 * el medallón y el nombre viajaran hasta la ficha y no gustó: distraía más de
 * lo que orientaba. Se llama desde el `onClick` de un `Link`: sin soporte, o
 * con modificadores (abrir en otra pestaña), sigue de largo y navega `Link`.
 *
 * [target] es el selector del título de la pantalla de destino: la transición
 * espera a que aparezca y después le pasa el foco. [go] reemplaza al
 * `navigate(href)`: un «Volver» retrocede en el historial (`navigateBack`).
 * ponytail: el «atrás» del navegador no pasa por acá y cambia de una;
 * animarlo pide envolver el `popstate` del router.
 */
export function fadeNavigate(e: MouseEvent<HTMLAnchorElement>, target: string, go?: () => void) {
  if (!document.startViewTransition || prefersReducedMotion() || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
  const href = e.currentTarget.getAttribute('href')!;
  // El ítem activo del panel lleva adonde ya se está: no hay nada que fundir.
  if (href === window.location.pathname + window.location.search + window.location.hash) return;
  e.preventDefault();
  // Le devuelve el nombre a la raíz (`.page-fade` en `index.css`) y se lo saca
  // a las tarjetas del dashboard, que si no se animarían aparte.
  document.documentElement.classList.add('page-fade');
  const transition = document.startViewTransition(
    () =>
      new Promise<void>((resolve) => {
        // El destino sale de la caché y se dibuja enseguida, pero no en esta
        // misma vuelta: se espera a su título, con un tope para no dejar la
        // pantalla congelada si tarda. Entre secciones del Modo DM el título
        // de antes tiene la misma marca: vale uno que no sea ese.
        const before = document.querySelector(target);
        const ready = () => {
          const now = document.querySelector(target);
          return now !== null && now !== before;
        };
        const observer = new MutationObserver(() => ready() && done());
        const timer = window.setTimeout(() => done(), 300);
        const done = () => {
          observer.disconnect();
          window.clearTimeout(timer);
          resolve();
        };
        observer.observe(document.body, { childList: true, subtree: true });
        if (go) go();
        else navigate(href);
        if (ready()) done();
      }),
  );
  // La transición no mueve el foco: el enlace ya no existe y quedaría en el
  // documento. Va al título del destino.
  void transition.finished.finally(() => {
    document.documentElement.classList.remove('page-fade');
    document.querySelector<HTMLElement>(target)?.focus({ preventScroll: true });
  });
}
