import { useEffect, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
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
 * Pide los avisos pendientes de la cuenta y los muestra de a uno
 * (`PendingEventsGate` de Flutter). Son una cola durable de «esto pasó mientras
 * no mirabas»; el turno es lo otro, y por eso no viaja por acá
 * (`useTurnStatus`).
 *
 * Se piden al entrar a un lugar concreto (la lista, el Modo DM y una ficha; las
 * subrutas de la ficha no cuentan), al volver a la pestaña y **cada 30 s con la
 * página visible**. El timer es decisión del usuario (2026-11-04): el jugador
 * deja la ficha abierta en la mesa, y sin él el aviso de un capítulo cerrado o
 * de un combate terminado no le llega hasta que navegue. Flutter no lo tiene.
 *
 * Un fallo al pedirlos o al marcarlos se traga en silencio, por dos motivos:
 * no poder mostrar un aviso no es razón para interrumpir lo que la persona vino
 * a hacer, y uno sin marcar vuelve la próxima vez, que es preferible a perderlo.
 */
export function PendingEvents() {
  const t = useTexts();
  const client = useQueryClient();
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
  const queued = useRef(new Set<string>());

  useEffect(() => {
    if (key === null) return;
    const pull = () => {
      if (running.current) return;
      running.current = true;
      void (async () => {
        try {
          const events = await fetchUnseenEvents();
          const shown: Notice[] = [];
          for (const event of events) {
            // Con el timer, uno en cola que todavía no se mostró (y por eso no
            // está visto) volvería a llegar en cada pedido.
            if (queued.current.has(event.id)) continue;
            queued.current.add(event.id);
            // Un cierre con objetos, o uno dado desde la Mesa, deja regalos en la bandeja de Inventario.
            if ((event.kind === 'chapter_completed' || event.kind === 'item_granted') && event.payload.hasGrants === true) {
              void client.invalidateQueries({ queryKey: ['itemGrants'] }); // prefijo de `queryKeys.itemGrants`
            }
            const message = eventMessage(event, t);
            if (message) shown.push({ id: event.id, ...message });
            // Un `kind` desconocido igual se marca visto: dejarlo pendiente lo
            // volvería a traer para siempre.
            else void markEventsSeen([event.id]).catch(() => {});
          }
          if (shown.length > 0) setQueue((q) => [...q, ...shown]);
        } catch {
          // Ver el comentario del componente.
        }
        running.current = false;
      })();
    };
    pull();
    const onVisible = () => document.visibilityState === 'visible' && pull();
    const timer = setInterval(onVisible, 30_000);
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
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
