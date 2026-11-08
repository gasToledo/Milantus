import { useSyncExternalStore } from 'react';
import { Toast, type ToastTone } from './primitives';

interface Notice {
  id: number;
  message: string;
  tone: ToastTone;
}

// Un aviso que sale de una acción que además navega («"Lobo" se guardó» y a la
// vez se vuelve al perfil) no puede vivir en la pantalla que lo dispara: esa se
// desmonta y el aviso con ella. Por eso la cola es del módulo y la dibuja
// `AppNotices`, montado una sola vez junto al resto de los avisos de la app.
let queue: readonly Notice[] = [];
let nextId = 0;
const listeners = new Set<() => void>();
const emit = () => listeners.forEach((l) => l());

/** Muestra un aviso (`showAppMessage` de Flutter) desde cualquier lugar. */
export function showNotice(message: string, tone: ToastTone = 'success'): void {
  queue = [...queue, { id: ++nextId, message, tone }];
  emit();
}

function dismiss(id: number) {
  queue = queue.filter((n) => n.id !== id);
  emit();
}

const subscribe = (listener: () => void) => {
  listeners.add(listener);
  return () => void listeners.delete(listener);
};

/** Dibuja los avisos de [showNotice]; va dentro del `ToastProvider`. */
export function AppNotices() {
  const notices = useSyncExternalStore(subscribe, () => queue);
  return (
    <>
      {notices.map((n) => (
        <Toast key={n.id} tone={n.tone} message={n.message} open onOpenChange={(open) => !open && dismiss(n.id)} />
      ))}
    </>
  );
}
