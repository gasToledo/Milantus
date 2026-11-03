import { ApiError } from './client';

// `/api/settings` guarda el documento **entero** (`PUT`), así que dos guardados
// en vuelo se pisarían: el segundo leería los ajustes antes de que el primero
// termine y devolvería el viejo valor. Un solo guardado a la vez; lo que llega
// mientras tanto se combina en un parche y sale en la vuelta siguiente.
let queued: Record<string, unknown> | null = null;
let waiters: { resolve: () => void; reject: (e: unknown) => void }[] = [];
let running = false;

/** Cambia [patch] en los ajustes de la cuenta sin tocar el resto. Relee antes
 *  de cada guardado en vez de usar los que trajo la pantalla: la pantalla puede
 *  quedar abierta un buen rato, y con una copia vieja se pisaría el tema o el
 *  favorito que se hubieran tocado mientras tanto. Un error rechaza las
 *  promesas de ese lote (las del siguiente siguen su camino). */
export function patchSettings(patch: Record<string, unknown>): Promise<void> {
  return new Promise((resolve, reject) => {
    queued = { ...queued, ...patch };
    waiters.push({ resolve, reject });
    if (!running) void drain();
  });
}

async function drain(): Promise<void> {
  running = true;
  while (queued) {
    const batch = queued;
    const batchWaiters = waiters;
    queued = null;
    waiters = [];
    try {
      const path = '/api/settings';
      const read = await fetch(path);
      if (!read.ok) throw new ApiError(read.status, path);
      const { settings } = (await read.json()) as { settings: Record<string, unknown> | null };
      const response = await fetch(path, {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...settings, ...batch }),
      });
      if (!response.ok) throw new ApiError(response.status, path);
      batchWaiters.forEach((w) => w.resolve());
    } catch (e) {
      batchWaiters.forEach((w) => w.reject(e));
    }
  }
  running = false;
}
