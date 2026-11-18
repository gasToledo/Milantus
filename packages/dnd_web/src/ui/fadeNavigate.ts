import type { MouseEvent } from 'react';

/**
 * Lo que queda de cuando el fundido de pantalla se pedía a mano en cada enlace:
 * ahora lo hace el router en todo cambio de pantalla (`withPageFade`, en
 * `pageFade.ts`), también en el «atrás» del navegador. Esto solo sirve para un
 * `Link` cuyo destino no es su `href` sino [go] (un «Volver» que retrocede en
 * el historial con `navigateBack`); sin [go], deja seguir al `Link`.
 *
 * [_target] era el título al que iba el foco; el router lo busca solo.
 * ponytail: sobra en las llamadas sin [go]; se borran cuando se toque cada
 * archivo.
 */
export function fadeNavigate(e: MouseEvent<HTMLAnchorElement>, _target: string, go?: () => void) {
  if (!go || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
  e.preventDefault();
  go();
}
