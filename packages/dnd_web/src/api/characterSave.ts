// El guardado de la ficha propia: la misma forma que `CharactersController` de
// Flutter. Una espera corta junta los toques seguidos (tres «+Fallo» son un
// solo PUT), una cola por personaje evita que un guardado viejo llegue después
// de uno nuevo, y siempre se manda **la última** copia entera. Mandar el
// estado y no la acción es lo que hace seguro reintentar: repetir un PUT no
// aplica dos veces el mismo daño.
//
// Ya no gana el último: cada PUT lleva la versión que /v2 leyó y, si otra
// pestaña o dispositivo guardó antes, el servidor responde 409. Entonces se
// descarta lo pendiente de esa ficha y se avisa por `onStale` (la pantalla
// vuelve a pedirla). Flutter no manda versión y sigue pisando, así que
// `CharacterPage` además relee al volver a la pestaña, solo si no hay nada
// pendiente.
import { useSyncExternalStore } from 'react';
import type { CharacterJson } from '../engine';
import { ApiError, saveCharacter } from './client';

export type SaveState = 'saved' | 'saving' | 'error';

/** La espera de Flutter (`CharactersController._debounce`). */
const DEBOUNCE_MS = 400;

interface Entry {
  /** La copia que falta mandar; `null` si no hay nada nuevo. */
  pending: (CharacterJson & { id: string }) | null;
  timer: ReturnType<typeof setTimeout> | null;
  running: boolean;
  /** El guardado en vuelo, para poder esperarlo. */
  inflight: Promise<void> | null;
  /** `dropPending` lo descartó: un fallo del guardado en vuelo no lo revive. */
  dropped: boolean;
  failed: boolean;
}

const entries = new Map<string, Entry>();
const listeners = new Set<() => void>();
const notify = () => listeners.forEach((l) => l());

const staleListeners = new Set<(id: string) => void>();

/** Avisa cuando el servidor rechazó un guardado por copia vieja (409). */
export function onStale(listener: (id: string) => void): () => void {
  staleListeners.add(listener);
  return () => staleListeners.delete(listener);
}

function entryOf(id: string): Entry {
  let e = entries.get(id);
  if (!e) {
    e = { pending: null, timer: null, running: false, inflight: null, dropped: false, failed: false };
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
  e.inflight = (async () => {
    while (e.pending) {
      const doc = e.pending;
      e.pending = null;
      try {
        await saveCharacter(doc);
        e.failed = false;
      } catch (error) {
        // Copia vieja: lo local se descarta (sin esperar el vuelo, que es este)
        // y la pantalla carga la versión del servidor.
        if (error instanceof ApiError && error.status === 409) {
          e.pending = null;
          e.failed = false;
          staleListeners.forEach((l) => l(id));
          break;
        }
        // Lo local se conserva: la copia vuelve a esperar (salvo que ya haya
        // una más nueva) y «Reintentar» la manda. Si la ficha se descartó
        // mientras tanto no hay a qué volver.
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
  e.running = false;
  notify();
}

/** Olvida lo que [id] tenga para guardar y espera al guardado en vuelo. Lo
 *  llaman quienes escriben la ficha por otro camino (renombrar desde la lista,
 *  rehacer, borrar): un guardado viejo no puede llegar después y pisar lo
 *  borrado o lo rehecho. La entrada se borra para que un fallo viejo no deje
 *  el aviso de `beforeunload` encendido. */
export async function dropPending(id: string): Promise<void> {
  const e = entries.get(id);
  if (!e) return;
  e.dropped = true;
  if (e.timer) clearTimeout(e.timer);
  e.timer = null;
  e.pending = null;
  await e.inflight;
  entries.delete(id);
  notify();
}

/** Manda ya lo que haya pendiente de [id] (el «Reintentar» del pie). */
export function retrySave(id: string): void {
  void flush(id);
}

/** Manda ya lo pendiente de [id] y espera a que termine: lo que sale de una
 *  pantalla antes de releer, porque releer antes traería la copia vieja. */
export const flushSave = (id: string): Promise<void> => flush(id);

/** Una transferencia lee del servidor: espera también el PUT que ya salió. */
export async function flushCharacterWrites(ids: Iterable<string> = entries.keys()): Promise<void> {
  await Promise.all(Array.from(ids, async (id) => {
    const entry = entries.get(id);
    if (!entry) return;
    await flush(id);
    await entry.inflight;
    if (entry.pending) throw new Error('La ficha tiene cambios sin guardar');
  }));
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
