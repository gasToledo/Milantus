// El guardado de la ficha propia: la misma forma que `CharactersController` de
// Flutter. Una espera corta junta los toques seguidos (tres «+Fallo» son un
// solo PUT), una cola por personaje evita que un guardado viejo llegue después
// de uno nuevo, y siempre se manda **la última** copia entera. Mandar el
// estado y no la acción es lo que hace seguro reintentar: repetir un PUT no
// aplica dos veces el mismo daño.
//
// Gana el último que guarda, como entre dos pestañas de Flutter: el servidor
// no tiene versión ni `updatedAt` con que rechazar una copia vieja. Lo que
// achica la ventana está en `CharacterPage` (volver a pedir la ficha al
// volver a la pestaña, solo si no hay nada pendiente).
import { useSyncExternalStore } from 'react';
import type { CharacterJson } from '../engine';
import { saveCharacter } from './client';

export type SaveState = 'saved' | 'saving' | 'error';

/** La espera de Flutter (`CharactersController._debounce`). */
const DEBOUNCE_MS = 400;

interface Entry {
  /** La copia que falta mandar; `null` si no hay nada nuevo. */
  pending: (CharacterJson & { id: string }) | null;
  timer: ReturnType<typeof setTimeout> | null;
  running: boolean;
  failed: boolean;
}

const entries = new Map<string, Entry>();
const listeners = new Set<() => void>();
const notify = () => listeners.forEach((l) => l());

function entryOf(id: string): Entry {
  let e = entries.get(id);
  if (!e) {
    e = { pending: null, timer: null, running: false, failed: false };
    entries.set(id, e);
  }
  return e;
}

/** Deja [character] para guardar dentro de un momento; si ya había una copia
 *  esperando, esta la reemplaza. */
export function scheduleSave(character: CharacterJson & { id: string }): void {
  const e = entryOf(character.id);
  e.pending = character;
  if (e.timer) clearTimeout(e.timer);
  e.timer = setTimeout(() => void flush(character.id), DEBOUNCE_MS);
  notify();
}

async function flush(id: string): Promise<void> {
  const e = entryOf(id);
  if (e.timer) clearTimeout(e.timer);
  e.timer = null;
  // El que está mandando vuelve a mirar `pending` al terminar: así nunca hay
  // dos PUT de la misma ficha en vuelo y el último en llegar es el último.
  if (e.running) return;
  e.running = true;
  notify();
  while (e.pending) {
    const doc = e.pending;
    e.pending = null;
    try {
      await saveCharacter(doc);
      e.failed = false;
    } catch {
      // Lo local se conserva: la copia vuelve a esperar (salvo que ya haya
      // una más nueva) y «Reintentar» la manda.
      e.failed = true;
      e.pending ??= doc;
      break;
    }
  }
  e.running = false;
  notify();
}

/** Manda ya lo que haya pendiente de [id] (el «Reintentar» del pie). */
export function retrySave(id: string): void {
  void flush(id);
}

export function saveStateOf(id: string): SaveState {
  const e = entries.get(id);
  if (!e) return 'saved';
  if (e.timer || e.running) return 'saving';
  return e.failed ? 'error' : 'saved';
}

/** Si alguna ficha tiene algo que todavía no llegó al servidor. */
export function hasUnsavedChanges(): boolean {
  for (const e of entries.values()) {
    if (e.pending || e.running) return true;
  }
  return false;
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useSaveState(id: string): SaveState {
  return useSyncExternalStore(subscribe, () => saveStateOf(id));
}

// Cerrar o recargar con algo sin guardar lo perdería: el navegador pregunta.
// El texto del diálogo lo pone el navegador, no la página.
if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', (event) => {
    if (hasUnsavedChanges()) event.preventDefault();
  });
}
