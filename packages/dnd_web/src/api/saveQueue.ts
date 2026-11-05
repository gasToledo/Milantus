// La cola de guardado de un documento que se manda entero (PNJ, combate): una espera
// corta junta los toques seguidos, un solo envío en vuelo por clave evita que una
// copia vieja llegue después de una nueva, y siempre se manda la última copia entera.
// Gana el último que guarda: el servidor no tiene versión con que rechazar una vieja.
// Cada cola es independiente (su propio mapa y su propio aviso de `beforeunload`).

interface Entry<D> {
  /** La última copia que se pidió guardar: es la base de la próxima edición. */
  latest: D;
  pending: D | null;
  timer: ReturnType<typeof setTimeout> | null;
  inflight: Promise<void> | null;
  dropped: boolean;
  failed: boolean;
  onSettled: (ok: boolean) => void;
}

export function createSaveQueue<D>(send: (key: string, doc: D) => Promise<void>, debounceMs = 400) {
  const entries = new Map<string, Entry<D>>();

  function schedule(key: string, doc: D, onSettled: (ok: boolean) => void): void {
    const e = entries.get(key) ?? { latest: doc, pending: null, timer: null, inflight: null, dropped: false, failed: false, onSettled };
    entries.set(key, e);
    e.latest = doc;
    e.pending = doc;
    e.onSettled = onSettled;
    if (e.timer) clearTimeout(e.timer);
    e.timer = setTimeout(() => void run(key), debounceMs);
  }

  async function run(key: string): Promise<void> {
    const e = entries.get(key);
    if (!e) return;
    if (e.timer) clearTimeout(e.timer);
    e.timer = null;
    // El que está mandando vuelve a mirar `pending` al terminar: nunca hay dos envíos
    // de la misma clave en vuelo.
    if (e.inflight) {
      await e.inflight;
      return;
    }
    e.inflight = (async () => {
      while (e.pending) {
        const doc = e.pending;
        e.pending = null;
        try {
          await send(key, doc);
          e.failed = false;
        } catch {
          // Lo escrito se conserva: la copia vuelve a esperar a «Reintentar».
          if (!e.dropped) {
            e.failed = true;
            e.pending ??= doc;
          }
          break;
        }
      }
    })();
    await e.inflight;
    e.inflight = null;
    if (e.dropped) return;
    e.onSettled(!e.failed);
    if (!e.failed && !e.pending && !e.timer) entries.delete(key);
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('beforeunload', (event) => {
      for (const e of entries.values()) {
        if (e.pending || e.inflight) return event.preventDefault();
      }
    });
  }

  return {
    schedule,
    /** La copia que falta confirmar, o `null` si la caché ya es lo guardado. */
    latest: (key: string): D | null => entries.get(key)?.latest ?? null,
    retry: (key: string): void => void run(key),
    /** Manda ya lo pendiente y lanza si no se pudo: quien espera tiene que saberlo. */
    async flush(key: string): Promise<void> {
      await run(key);
      if (entries.get(key)?.failed) throw new Error(`No se guardó ${key}`);
    },
    /** Olvida lo pendiente y espera lo que esté en vuelo: al borrar, un guardado viejo
     *  no puede llegar después. */
    async drop(key: string): Promise<void> {
      const e = entries.get(key);
      if (!e) return;
      e.dropped = true;
      if (e.timer) clearTimeout(e.timer);
      e.pending = null;
      await e.inflight;
      entries.delete(key);
    },
  };
}
