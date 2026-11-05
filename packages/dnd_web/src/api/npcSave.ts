// El guardado de un PNJ: una instancia de `saveQueue.ts` con el id como clave.
import type { JsonObject } from '../engine';
import { saveNpc } from './client';
import { createSaveQueue } from './saveQueue';

export type NpcDoc = JsonObject & { id: string };

const queue = createSaveQueue<NpcDoc>((_id, doc) => saveNpc(doc));

export const scheduleNpcSave = (doc: NpcDoc, onSettled: (ok: boolean) => void): void => queue.schedule(doc.id, doc, onSettled);

/** La copia que falta confirmar, o `null` si la caché ya es lo guardado. */
export const latestNpcDoc = (id: string): NpcDoc | null => queue.latest(id);

export const retryNpcSave = (id: string): void => queue.retry(id);

/** Manda ya lo pendiente y lanza si no se pudo: renombrar tiene que saberlo. */
export async function flushNpcSave(id: string): Promise<void> {
  try {
    await queue.flush(id);
  } catch {
    throw new Error(`No se guardó el PNJ ${id}`);
  }
}

/** Olvida lo pendiente y espera lo que esté en vuelo: al borrar, un guardado viejo
 *  no puede llegar después. */
export const dropNpcSave = (id: string): Promise<void> => queue.drop(id);
