import { fetchAppVersion } from '../api/client';

// Envío automático de errores al servidor (`POST /api/client-errors`), que
// escribe una línea en su log. Sin esperar respuesta y sin lanzar nunca: un
// error al reportar un error no puede ser otro error.

const MAX_PER_PAGE = 10;
let sent = 0;
// Sin sesión el servidor contesta 401: no se insiste (nada sin cuenta).
let stopped = false;
let version: Promise<string | null> | undefined;

export function reportError(error: { message: string; stack?: string; componentStack?: string }) {
  if (stopped || sent >= MAX_PER_PAGE) return;
  sent++;
  void (async () => {
    try {
      version ??= fetchAppVersion(new AbortController().signal);
      const v = await version;
      const response = await fetch('/api/client-errors', {
        method: 'POST',
        keepalive: true,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          ...error,
          route: window.location.pathname,
          ...(v ? { version: v } : {}),
          userAgent: navigator.userAgent,
        }),
      });
      if (response.status === 401) stopped = true;
    } catch {
      // ponytail: sin reintentos ni cola; si se pierden errores por red caída, guardar en sessionStorage.
    }
  })();
}
