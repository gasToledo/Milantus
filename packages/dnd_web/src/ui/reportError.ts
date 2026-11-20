import { APP_VERSION } from '../api/client';

// Envío automático de errores al servidor (`POST /api/client-errors`), que
// escribe una línea en su log. Sin esperar respuesta y sin lanzar nunca: un
// error al reportar un error no puede ser otro error.

const MAX_PER_PAGE = 10;
let sent = 0;
// Sin sesión el servidor contesta 401: no se insiste (nada sin cuenta).
let stopped = false;

export function reportError(error: { message: string; stack?: string; componentStack?: string }) {
  if (stopped || sent >= MAX_PER_PAGE) return;
  sent++;
  void (async () => {
    try {
      const response = await fetch('/api/client-errors', {
        method: 'POST',
        keepalive: true,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          ...error,
          route: window.location.pathname,
          version: APP_VERSION,
          userAgent: navigator.userAgent,
        }),
      });
      if (response.status === 401) stopped = true;
    } catch {
      // ponytail: sin reintentos ni cola; si se pierden errores por red caída, guardar en sessionStorage.
    }
  })();
}
