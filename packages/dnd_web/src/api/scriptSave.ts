// El guardado de un guion: una instancia de `saveQueue.ts` con el id como clave.
import { saveScript, type DmScript } from './client';
import { createSaveQueue } from './saveQueue';

const queue = createSaveQueue<DmScript>((_id, doc) => saveScript(doc));

export const scheduleScriptSave = (doc: DmScript, onSettled: (ok: boolean) => void): void => queue.schedule(doc.id, doc, onSettled);

/** La copia que falta confirmar, o `null` si la caché ya es lo guardado. */
export const latestScriptDoc = (id: string): DmScript | null => queue.latest(id);

/** Manda ya lo pendiente y lanza si no se pudo: duplicar copia lo guardado. */
export async function flushScriptSave(id: string): Promise<void> {
  try {
    await queue.flush(id);
  } catch {
    throw new Error(`No se guardó el guion ${id}`);
  }
}

/** Olvida lo pendiente y espera lo que esté en vuelo: al borrar, o cuando un
 *  guardado falló y se va a releer. */
export const dropScriptSave = (id: string): Promise<void> => queue.drop(id);
