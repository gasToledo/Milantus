import { useEffect, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { fetchUnseenEvents, markEventsSeen } from '../api/client';
import { useTexts } from '../i18n/context';
import { characterHref, navigate, useRoute } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Eyebrow } from '../ui/data';
import { Toast, type ToastTone } from '../ui/primitives';
import { eventMessage, type ChapterNotice } from './messages';

interface Notice {
  id: string;
  text: string;
  tone: ToastTone;
  /** Si viene, el aviso es un diálogo y no una tostada. */
  chapter?: ChapterNotice;
  hasGrants?: boolean;
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
            if (message) shown.push({ id: event.id, ...message, hasGrants: event.payload.hasGrants === true });
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
  const next = () => setQueue((q) => q.slice(1));
  if (current.chapter) {
    return <ChapterDoneDialog key={current.id} chapter={current.chapter} hasGrants={current.hasGrants === true} onClose={next} />;
  }
  return (
    <Toast
      key={current.id}
      tone={current.tone}
      message={current.text}
      open
      onOpenChange={(open) => !open && next()}
      duration={8000}
    />
  );
}

/**
 * El fin de capítulo para el jugador: un diálogo y no una tostada, porque entre
 * las demás de la cola se perdía. Cerrarlo de cualquier forma (botón, `Esc`,
 * afuera) pasa al siguiente aviso. «Ir a Inventario» solo si hay objetos
 * esperando **y** el aviso trae el personaje (uno viejo no lo trae).
 */
function ChapterDoneDialog({ chapter, hasGrants, onClose }: { chapter: ChapterNotice; hasGrants: boolean; onClose: () => void }) {
  const t = useTexts();
  const { characterId } = chapter;
  return (
    <AppDialog
      open
      bare
      onOpenChange={(open) => !open && onClose()}
      title={chapter.title}
      actions={[
        ...(hasGrants && characterId
          ? [{ label: t.evtGoToInventory, onSelect: () => navigate(characterHref(characterId, 'inventario')) }]
          : []),
        { label: t.tutDone, primary: true },
      ]}
    >
      <div data-chapter-done className="flex flex-col items-center gap-2.5 text-center">
        <span aria-hidden="true" className="mt-1 mb-2 size-[22px] rotate-45 rounded-[var(--radius-mark)] bg-gold" />
        <Eyebrow>{chapter.campaign}</Eyebrow>
        <h2 aria-hidden="true" className="font-display text-[22px] leading-tight text-on-surface">
          {chapter.title}
        </h2>
        <p className="text-[14px] text-on-surface-variant">{chapter.by}</p>
      </div>
      {chapter.lines.length > 0 && (
        <ul className="mt-4">
          {chapter.lines.map((l) => (
            <li key={l.text} className="flex items-start gap-2.5 border-t border-hairline py-2.5 text-[14px] leading-[1.45] text-on-surface">
              <l.icon size={18} aria-hidden="true" className="mt-0.5 shrink-0 text-gold" />
              <span>{l.text}</span>
            </li>
          ))}
        </ul>
      )}
    </AppDialog>
  );
}
