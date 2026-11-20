import { useEffect, useEffectEvent, useId, useRef, useState, type CSSProperties } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { useQueryClient } from '@tanstack/react-query';
import { Sparkles, X } from 'lucide-react';
import { fetchUnseenEvents, markEventsSeen } from '../api/client';
import { useTexts } from '../i18n/context';
import { characterHref, navigate, useRoute } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Eyebrow } from '../ui/data';
import { ICON_TONE, Toast } from '../ui/primitives';
import { eventMessage, type ChapterNotice, type EventMessage, type InspirationNotice, type ItemNotice } from './messages';

type Notice = EventMessage & { id: string; hasGrants?: boolean };

/** Lo que está a la vista: una pantalla, una tostada suelta o la bandeja. */
type Active = { kind: 'screen' | 'toast'; notice: Notice } | { kind: 'tray'; notices: Notice[] };

/**
 * Pide los avisos pendientes de la cuenta y los muestra. Son una cola durable
 * de «esto pasó mientras no mirabas»; el turno
 * es lo otro, y por eso no viaja por acá (`useTurnStatus`).
 *
 * Cada aviso toma la forma que le toca (`display`): el fin de capítulo, la
 * Inspiración Heroica y un objeto del DM tienen su pantalla y van primero, de a
 * uno; las tostadas se juntan en una bandeja si son 2 o más, y salen sueltas si
 * es una. Lo que llega con algo abierto espera su turno.
 *
 * Se piden al entrar a un lugar concreto (la lista, el Modo DM y una ficha; las
 * subrutas de la ficha no cuentan), al volver a la pestaña y **cada 30 s con la
 * página visible**. El timer es decisión del usuario (2026-11-04): el jugador
 * deja la ficha abierta en la mesa, y sin él el aviso de un capítulo cerrado o
 * de un combate terminado no le llega hasta que navegue.
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

  // `queue` espera su turno; `active` es lo que está a la vista.
  const [queue, setQueue] = useState<Notice[]>([]);
  const [active, setActive] = useState<Active | null>(null);
  // Evita pedidos duplicados: `StrictMode` monta dos veces en desarrollo, y un
  // cambio de ruta no debe volver a pedir lo que ya está en cola.
  const running = useRef(false);
  const queued = useRef(new Set<string>());

  // Los textos y el cliente se leen al pedir, no al suscribir: el timer queda
  // atado a la pantalla (`key`) y no se rearma si cambia la identidad de `t`.
  const pull = useEffectEvent(() => {
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
  });
  useEffect(() => {
    if (key === null) return;
    pull();
    const onVisible = () => document.visibilityState === 'visible' && pull();
    const timer = setInterval(onVisible, 30_000);
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [key]);

  // Con la vista libre pasa lo que sigue: una pantalla (la primera que llegó) o,
  // si no hay ninguna, todas las tostadas juntas.
  useEffect(() => {
    if (active || queue.length === 0) return;
    const screen = queue.find((n) => n.display !== 'toast');
    if (screen) {
      setActive({ kind: 'screen', notice: screen });
      setQueue((q) => q.filter((n) => n !== screen));
    } else {
      setActive(queue.length === 1 ? { kind: 'toast', notice: queue[0]! } : { kind: 'tray', notices: queue });
      setQueue([]);
    }
  }, [active, queue]);

  // Se marca visto al mostrarlo y no al pedirlo: el que no llegó a verse vuelve.
  // La bandeja marca todos juntos cuando aparece.
  useEffect(() => {
    if (!active) return;
    const ids = active.kind === 'tray' ? active.notices.map((n) => n.id) : [active.notice.id];
    void markEventsSeen(ids).catch(() => {});
  }, [active]);

  if (!active) return null;
  const close = () => setActive(null);
  if (active.kind === 'tray') return <PendingTray key={active.notices[0]!.id} notices={active.notices} onClose={close} />;
  const { notice } = active;
  if (notice.display === 'chapter' && notice.chapter) {
    return <ChapterDoneDialog key={notice.id} chapter={notice.chapter} hasGrants={notice.hasGrants === true} onClose={close} />;
  }
  if (notice.display === 'inspiration' && notice.inspiration) {
    return <InspirationCelebration key={notice.id} notice={notice.inspiration} onClose={close} />;
  }
  if (notice.display === 'item' && notice.item) {
    return <ItemGrantDialog key={notice.id} notice={notice.item} onClose={close} />;
  }
  return (
    <Toast
      key={notice.id}
      tone={notice.tone}
      message={notice.text}
      icon={notice.icon}
      iconTone={notice.iconTone}
      progress
      open
      onOpenChange={(open) => !open && close()}
      duration={8000}
    />
  );
}

/** Retraso en línea, como el escalonado de `.lv-up`. */
const delay = (ms: number) => ({ animationDelay: `${ms}ms` }) as CSSProperties;

/**
 * «Mientras no estabas» (lámina A): varios avisos sueltos en un solo lugar, en
 * vez de una tostada tras otra. No se cierra sola; «Entendido» los descarta
 * todos y cada fila se puede sacar sola (al sacar la última, se cierra).
 */
function PendingTray({ notices, onClose }: { notices: Notice[]; onClose: () => void }) {
  const t = useTexts();
  const titleId = useId();
  const [rows, setRows] = useState(notices);
  const close = useEffectEvent(onClose);
  useEffect(() => {
    if (rows.length === 0) close();
  }, [rows.length]);
  if (rows.length === 0) return null;
  return (
    <section
      role="region"
      aria-labelledby={titleId}
      className="card notice-in fixed right-4 bottom-4 z-50 flex w-[min(400px,calc(100vw-32px))] flex-col gap-2.5 px-3.5 pt-3.5 pb-3"
    >
      <div className="flex items-center justify-between gap-2.5 px-0.5">
        <h2 id={titleId} className="eyebrow">
          {t.evtTrayTitle}
        </h2>
        <span className="num text-[12px] text-text-muted tabular-nums">{t.evtTrayCount(rows.length)}</span>
      </div>
      <ul className="rounded-[var(--radius-card)] border border-hairline bg-plaque">
        {rows.map((n) => (
          <li key={n.id} className="step-in flex items-start gap-2.5 border-t border-hairline py-2.5 pr-2 pl-2.5 first:border-t-0">
            <span aria-hidden="true" className="inline-flex size-[30px] shrink-0 items-center justify-center rounded-[9px] bg-plaque">
              <n.icon size={16} className={ICON_TONE[n.iconTone]} />
            </span>
            <span className="min-w-0 flex-1 pt-1 text-[13.5px] leading-[1.45] text-on-surface">{n.text}</span>
            <button
              type="button"
              aria-label={t.closeNotice}
              title={t.closeNotice}
              onClick={() => setRows((r) => r.filter((x) => x !== n))}
              className="inline-flex size-[30px] shrink-0 items-center justify-center rounded-[9px] text-text-muted hover:bg-surface hover:text-on-surface"
            >
              <X size={14} aria-hidden="true" />
            </button>
          </li>
        ))}
      </ul>
      <div className="flex justify-end">
        <Button className="min-h-[38px] px-4 text-[13.5px] font-bold" onClick={onClose}>
          {t.tutDone}
        </Button>
      </div>
    </section>
  );
}

/** Las chispas de la Inspiración: hacia dónde salen (px) y con qué retraso (ms). */
const SPARKS = [
  [0, -120, 620],
  [85, -85, 640],
  [120, 0, 680],
  [85, 85, 620],
  [0, 120, 660],
  [-85, 85, 700],
  [-120, 0, 630],
  [-85, -85, 670],
] as const;

/**
 * La Inspiración Heroica a pantalla completa (lámina D): es rara y es un regalo
 * del DM. `Dialog` de Radix atrapa el foco; `Esc` y «Entendido» cierran. «Ir a
 * la ficha» solo navega: marcarla es del jugador.
 */
function InspirationCelebration({ notice, onClose }: { notice: InspirationNotice; onClose: () => void }) {
  const t = useTexts();
  const { characterId } = notice;
  return (
    <Dialog.Root open onOpenChange={(open) => !open && onClose()}>
      <Dialog.Portal>
        <Dialog.Content
          data-inspiration-celebration
          className="ih-veil fixed inset-0 z-50 flex flex-col items-center justify-center overflow-y-auto bg-scrim-strong px-4 text-center outline-none"
        >
          <div aria-hidden="true" className="relative flex size-[220px] shrink-0 items-center justify-center">
            <span
              className="ih-glow absolute -inset-10 rounded-full"
              style={{
                background:
                  'radial-gradient(circle, color-mix(in srgb, var(--gold) 45%, transparent) 0%, color-mix(in srgb, var(--gold) 12%, transparent) 45%, transparent 70%)',
              }}
            />
            <span className="ih-ring absolute size-[90px] rounded-full border-2 border-gold" />
            {SPARKS.map(([dx, dy, ms]) => (
              <span key={`${dx},${dy}`} className="ih-spark" style={{ '--dx': `${dx}px`, '--dy': `${dy}px`, animationDelay: `${ms}ms` } as CSSProperties} />
            ))}
            <Sparkles className="ih-star" size={112} strokeWidth={0.6} fill="var(--gold)" stroke="var(--gold-light)" strokeLinejoin="round" />
          </div>
          <p className="ih-rise mt-[22px] text-[12px] font-medium tracking-[2.4px] text-gold uppercase" style={delay(900)}>
            {notice.campaign}
          </p>
          <Dialog.Title className="ih-rise font-display mt-2.5 text-[44px] leading-[1.1] text-on-surface" style={delay(980)}>
            {t.evtInspirationTitle}
          </Dialog.Title>
          <Dialog.Description className="ih-rise mt-3.5 max-w-[440px] text-[16px] leading-[1.55] text-on-surface-variant" style={delay(1060)}>
            {t.evtInspirationBody(notice.character)}
          </Dialog.Description>
          <div className="ih-rise mt-[30px] flex flex-wrap justify-center gap-2.5" style={delay(1200)}>
            {characterId && (
              <Button
                tone="secondary"
                className="min-h-[46px] px-[22px] text-[14.5px]"
                onClick={() => {
                  navigate(characterHref(characterId));
                  onClose();
                }}
              >
                {t.evtGoToSheet}
              </Button>
            )}
            <Button data-action="inspiration-close" className="min-h-[46px] px-[26px] text-[14.5px] font-bold" onClick={onClose}>
              {t.tutDone}
            </Button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

/**
 * Un objeto que mandó el DM (lámina E): el cofre cae, la tapa se abre y lo que
 * trae sube de a uno. Los objetos esperan en la bandeja de Inventario: el aviso
 * no escribe la ficha. «Ir a Inventario» solo si el aviso trae el personaje.
 */
function ItemGrantDialog({ notice, onClose }: { notice: ItemNotice; onClose: () => void }) {
  const t = useTexts();
  const { characterId, items } = notice;
  const title = t.evtItemTitle(notice.character);
  return (
    <AppDialog
      open
      bare
      onOpenChange={(open) => !open && onClose()}
      title={title}
      width={460}
      actions={[
        ...(characterId ? [{ label: t.evtGoToInventory, onSelect: () => navigate(characterHref(characterId, 'inventario')) }] : []),
        { label: t.tutDone, primary: true },
      ]}
    >
      <div data-item-grant className="flex flex-col items-center text-center">
        <div aria-hidden="true" className="relative h-[86px] w-24">
          <span
            className="ob-shine absolute top-1.5 left-1/2 -ml-[35px] h-10 w-[70px] rounded-full"
            style={{ background: 'radial-gradient(ellipse, color-mix(in srgb, var(--gold) 55%, transparent), transparent 70%)' }}
          />
          <svg className="ob-chest absolute inset-0" width="96" height="86" viewBox="0 0 96 86" fill="none" stroke="var(--gold)" strokeWidth="2.4" strokeLinejoin="round">
            <rect x="14" y="40" width="68" height="38" rx="5" fill="var(--gold-soft)" />
            <path d="M14 54h68" />
            <rect x="42" y="48" width="12" height="12" rx="2" fill="var(--gold)" stroke="none" />
            <g className="ob-lid">
              <path d="M14 40v-8a10 10 0 0 1 10-10h48a10 10 0 0 1 10 10v8z" fill="var(--gold-soft)" />
            </g>
          </svg>
        </div>
        <Eyebrow className="mt-3.5">{notice.campaign}</Eyebrow>
        <h2 aria-hidden="true" className="font-display mt-1.5 text-[26px] leading-[1.2] text-on-surface">
          {title}
        </h2>
        {items.length > 0 && (
          <ul className="mt-[18px] w-full rounded-[var(--radius-card)] border border-hairline bg-plaque px-3.5 py-0.5 text-left">
            {items.map((item, i) => (
              <li
                key={`${i}:${item}`}
                className="lv-up flex items-center gap-2.5 border-t border-hairline py-2.5 text-[14.5px] text-on-surface first:border-t-0"
                style={delay(900 + i * 60)}
              >
                <span aria-hidden="true" className="size-[7px] shrink-0 rotate-45 bg-gold" />
                {item}
              </li>
            ))}
          </ul>
        )}
        <p className="lv-up mt-3 text-[13px] text-on-surface-variant" style={delay(900 + items.length * 60)}>
          {t.evtItemsWaiting}
        </p>
      </div>
    </AppDialog>
  );
}

/**
 * El fin de capítulo para el jugador (lámina C): un diálogo y no una tostada,
 * porque entre las demás de la cola se perdía. Cerrarlo de cualquier forma
 * (botón, `Esc`, afuera) pasa al siguiente aviso. «Ir a Inventario» solo si hay
 * objetos esperando **y** el aviso trae el personaje (uno viejo no lo trae).
 * Entra como la subida de nivel: el rombo cae girando, un anillo se abre y lo
 * que trae el capítulo sube de a uno.
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
        <div aria-hidden="true" className="relative flex size-[72px] items-center justify-center">
          <span className="lv-ring absolute size-[15px] rounded-full border-2 border-gold" />
          <span className="lv-rombo absolute size-[30px] rounded-[var(--radius-mark)] bg-gold" />
        </div>
        <Eyebrow>{chapter.campaign}</Eyebrow>
        <h2 aria-hidden="true" className="font-display text-[22px] leading-tight text-on-surface">
          {chapter.title}
        </h2>
        <p className="text-[14px] text-on-surface-variant">{chapter.by}</p>
      </div>
      {chapter.lines.length > 0 && (
        <ul className="mt-4 rounded-[var(--radius-card)] border border-hairline bg-plaque px-3.5 py-0.5">
          {chapter.lines.map((l, i) => (
            <li
              key={l.text}
              className="lv-up flex items-start gap-2.5 border-t border-hairline py-2.5 text-[14px] leading-[1.45] text-on-surface first:border-t-0"
              style={delay(620 + i * 60)}
            >
              <l.icon size={18} aria-hidden="true" className="mt-0.5 shrink-0 text-gold" />
              <span>{l.text}</span>
            </li>
          ))}
        </ul>
      )}
    </AppDialog>
  );
}
