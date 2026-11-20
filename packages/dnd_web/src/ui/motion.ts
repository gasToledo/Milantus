import { useSyncExternalStore, type CSSProperties } from 'react';

/** La misma clave la lee el script de `index.html` antes del primer cuadro. */
const STORAGE_KEY = 'milantus.v2.motion';
const SYSTEM_QUERY = '(prefers-reduced-motion: reduce)';

/** Si el sistema pide menos movimiento. */
export const systemReducesMotion = () => window.matchMedia(SYSTEM_QUERY).matches;

/**
 * Si hay que animar menos: lo pide el sistema o se apagó en Ajustes («Animaciones»,
 * y es de la cuenta, como el tema). Todo lo que anima desde JS (WAAPI, View
 * Transitions, el arrastre) pregunta acá y no a `matchMedia`, para que el
 * ajuste valga también ahí; lo del CSS lo cubre `[data-motion='reduce']` en
 * `index.css`.
 */
export const prefersReducedMotion = () => document.documentElement.dataset.motion === 'reduce' || systemReducesMotion();

/** Apaga o prende las animaciones de la app. La cuenta es la que manda
 *  (`AccountPrefsSync` llama acá al llegar los ajustes); lo local es la copia
 *  que lee `index.html` antes del primer cuadro. */
export function setAnimationsOff(off: boolean) {
  if (off) document.documentElement.dataset.motion = 'reduce';
  else delete document.documentElement.dataset.motion;
  try {
    if (off) window.localStorage.setItem(STORAGE_KEY, 'reduce');
    else window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // Sin almacenamiento dura lo que la pestaña: no es un error.
  }
  listeners.forEach((l) => l());
}

const listeners = new Set<() => void>();

/** El ajuste de la app (no el del sistema), en vivo para la pantalla de Ajustes. */
export function useAnimationsOff(): boolean {
  return useSyncExternalStore(
    (onChange) => {
      listeners.add(onChange);
      return () => listeners.delete(onChange);
    },
    () => document.documentElement.dataset.motion === 'reduce',
  );
}

/** Si el sistema pide menos movimiento, en vivo. Ajustes lo muestra y deja
 *  el interruptor apagado mientras el sistema lo pida: leerlo una sola vez
 *  se queda viejo si se cambia con la pantalla abierta. */
export function useSystemReducesMotion(): boolean {
  return useSyncExternalStore((onChange) => {
    const query = window.matchMedia(SYSTEM_QUERY);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, systemReducesMotion);
}

/** El lugar de un hijo de `.stagger-in`, que retrasa su entrada según él.
 *  `sibling-index()` lo diría solo, pero recién es Baseline desde 2026-08 y acá
 *  React ya sabe el índice. */
export const staggerIndex = (i: number) => ({ '--sibling-index': i + 1 }) as CSSProperties;

/** La entrada suave de una ficha que se reemplaza (Códice, Bestiario). Se
 *  anima el mismo elemento en vez de remontarlo, así el foco no se mueve.
 *  Con menos movimiento, o sin elemento, no hace nada. */
const SOFT_ENTER: Keyframe[] = [
  { opacity: 0, translate: '0 4px' },
  { opacity: 1, translate: '0 0' },
];

export function softEnter(el: Element | null | undefined) {
  if (!el || prefersReducedMotion()) return;
  el.animate(SOFT_ENTER, { duration: 160, easing: 'ease-out' });
}
