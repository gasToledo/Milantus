// Los últimos errores que se escaparon de React, **solo en memoria** y sin
// mostrar nada: los de extensiones del navegador y el ruido de terceros no
// tienen que aparecer en pantalla. `FeedbackDialog` los suma a un reporte de
// tipo «Un error», así uno hecho desde el menú igual trae lo último que falló.
// Es el gancho que usará el envío automático (ver `migracion-react.md`).

import { reportError } from './reportError';

export interface RecentError {
  message: string;
  /** Primera línea de la traza, si hay. */
  trace?: string;
}

const MAX = 3;
const recent: RecentError[] = [];

function push(message: string, stack?: string) {
  const trace = stack?.split('\n').find((l, i) => i > 0 && l.trim() !== '')?.trim();
  recent.push({ message, ...(trace ? { trace } : {}) });
  reportError({ message, stack });
  if (recent.length > MAX) recent.shift();
}

export function recentErrors(): RecentError[] {
  return [...recent];
}

/** Se llama una vez, al arrancar. */
export function watchErrors() {
  window.addEventListener('error', (e) => {
    // Sin archivo propio (extensión, otro origen, «Script error.») no es nuestro.
    if (!e.filename.startsWith(window.location.origin)) return;
    push(e.message, e.error instanceof Error ? e.error.stack : undefined);
  });
  window.addEventListener('unhandledrejection', (e) => {
    const reason: unknown = e.reason;
    const stack = reason instanceof Error ? reason.stack : undefined;
    // ponytail: sin traza no se sabe de dónde viene, y se descarta; si se
    // pierden rechazos propios así, anotar el origen al lanzarlos.
    if (!stack?.includes(window.location.origin)) return;
    push(reason instanceof Error ? reason.message : String(reason), stack);
  });
}
