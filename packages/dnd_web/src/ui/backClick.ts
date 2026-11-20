import type { MouseEvent } from 'react';

/**
 * Un «Volver» cuyo destino no es el `href` del `Link` sino [go] (retrocede en
 * el historial con `navigateBack`). El fundido y el foco los hace el router
 * (`withPageFade`). Un clic con modificador, o que no es el principal, sigue
 * al `href` para poder abrirlo en otra pestaña.
 */
export function backClick(e: MouseEvent<HTMLAnchorElement>, go: () => void) {
  if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
  e.preventDefault();
  go();
}
