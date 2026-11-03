import { useEffect, useRef, useState } from 'react';
import { fetchUnseenEvents, markEventsSeen } from '../api/client';
import { useTexts } from '../i18n/context';
import { useRoute } from '../router';
import { Toast, type ToastTone } from '../ui/primitives';
import { eventMessage } from './messages';

interface Notice {
  id: string;
  text: string;
  tone: ToastTone;
}

/**
 * Pide los avisos pendientes de la cuenta al entrar a un lugar concreto y los
 * muestra de a uno (`PendingEventsGate` de Flutter). Sin timer propio: son una
 * cola durable de «esto pasó mientras no mirabas», no tiempo real. El turno es
 * lo otro, y por eso no viaja por acá (`useTurnStatus`).
 *
 * Los puntos de entrada son los mismos que en Flutter: la lista, el Modo DM y
 * una ficha; las subrutas de la ficha (subir de nivel, retrato…) no cuentan.
 *
 * Un fallo al pedirlos o al marcarlos se traga en silencio, por dos motivos:
 * no poder mostrar un aviso no es razón para interrumpir lo que la persona vino
 * a hacer, y uno sin marcar vuelve la próxima vez, que es preferible a perderlo.
 */
export function PendingEvents() {
  const t = useTexts();
  const { route } = useRoute();
  const key =
    route.name === 'roster'
      ? 'roster'
      : route.name === 'dm'
        ? 'dm'
        : route.name === 'character'
          ? `character:${route.id}`
          : null;

  const [queue, setQueue] = useState<Notice[]>([]);
  // Evita pedidos duplicados: `StrictMode` monta dos veces en desarrollo, y un
  // cambio de ruta no debe volver a pedir lo que ya está en cola.
  const running = useRef(false);

  useEffect(() => {
    if (key === null || running.current) return;
    running.current = true;
    void (async () => {
      try {
        const events = await fetchUnseenEvents();
        const shown: Notice[] = [];
        for (const event of events) {
          const message = eventMessage(event, t);
          if (message) shown.push({ id: event.id, ...message });
          // Un `kind` desconocido igual se marca visto: dejarlo pendiente lo
          // volvería a traer para siempre.
          else void markEventsSeen([event.id]).catch(() => {});
        }
        setQueue((q) => [...q, ...shown]);
      } catch {
        // Ver el comentario del componente.
      }
      running.current = false;
    })();
    // Solo la clave de entrada: el idioma no cambia con la página abierta.
  }, [key]);

  const current = queue[0];
  // Se marca visto al mostrarlo y no al pedirlo: el que no llegó a verse vuelve.
  useEffect(() => {
    if (current) void markEventsSeen([current.id]).catch(() => {});
  }, [current?.id]);

  if (!current) return null;
  return (
    <Toast
      key={current.id}
      tone={current.tone}
      message={current.text}
      open
      onOpenChange={(open) => !open && setQueue((q) => q.slice(1))}
      duration={8000}
      closeLabel={t.closeNotice}
    />
  );
}
