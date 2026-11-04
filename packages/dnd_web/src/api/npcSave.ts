// El guardado de un PNJ, con la forma de `characterSave.ts`: una espera corta junta
// los toques seguidos, una cola por PNJ evita que un guardado viejo llegue después
// de uno nuevo, y siempre se manda la última copia entera. Gana el último que
// guarda: el servidor no tiene versión con que rechazar una copia vieja.
import type { JsonObject } from '../engine';
import { saveNpc } from './client';

export type NpcDoc = JsonObject & { id: string };

const DEBOUNCE_MS = 400;

interface Entry {
  /** La última copia que se pidió guardar: es la base de la próxima edición. */
  latest: NpcDoc;
  pending: NpcDoc | null;
  timer: ReturnType<typeof setTimeout> | null;
  inflight: Promise<void> | null;
  dropped: boolean;
  failed: boolean;
  onSettled: (ok: boolean) => void;
}

const entries = new Map<string, Entry>();

export function scheduleNpcSave(doc: NpcDoc, onSettled: (ok: boolean) => void): void {
  const e = entries.get(doc.id) ?? { latest: doc, pending: null, timer: null, inflight: null, dropped: false, failed: false, onSettled };
  entries.set(doc.id, e);
  e.latest = doc;
  e.pending = doc;
  e.onSettled = onSettled;
  if (e.timer) clearTimeout(e.timer);
  e.timer = setTimeout(() => void flush(doc.id), DEBOUNCE_MS);
}

async function flush(id: string): Promise<void> {
  const e = entries.get(id);
  if (!e) return;
  if (e.timer) clearTimeout(e.timer);
  e.timer = null;
  // El que está mandando vuelve a mirar `pending` al terminar: nunca hay dos PUT
  // del mismo PNJ en vuelo.
  if (e.inflight) {
    await e.inflight;
    return;
  }
  e.inflight = (async () => {
    while (e.pending) {
      const doc = e.pending;
      e.pending = null;
      try {
        await saveNpc(doc);
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
  if (!e.failed && !e.pending && !e.timer) entries.delete(id);
}

/** La copia que falta confirmar, o `null` si la caché ya es lo guardado. */
export const latestNpcDoc = (id: string): NpcDoc | null => entries.get(id)?.latest ?? null;

export const retryNpcSave = (id: string): void => void flush(id);

/** Manda ya lo pendiente y lanza si no se pudo: renombrar tiene que saberlo. */
export async function flushNpcSave(id: string): Promise<void> {
  await flush(id);
  if (entries.get(id)?.failed) throw new Error(`No se guardó el PNJ ${id}`);
}

/** Olvida lo pendiente y espera lo que esté en vuelo: al borrar, un guardado viejo
 *  no puede llegar después. */
export async function dropNpcSave(id: string): Promise<void> {
  const e = entries.get(id);
  if (!e) return;
  e.dropped = true;
  if (e.timer) clearTimeout(e.timer);
  e.pending = null;
  await e.inflight;
  entries.delete(id);
}

if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', (event) => {
    for (const e of entries.values()) {
      if (e.pending || e.inflight) return event.preventDefault();
    }
  });
}
