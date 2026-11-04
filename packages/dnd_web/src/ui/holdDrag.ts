import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type DragEvent, type KeyboardEvent as ReactKeyboardEvent, type MouseEvent, type PointerEvent } from 'react';

/** Cuánto hay que sostener el dedo: menos se confunde con desplazar, y a los
 *  500 ms ya saltaría el menú propio del teléfono sobre el enlace. */
const HOLD_MS = 350;
/** Con el mouse no hay nada que distinguir de un desplazamiento: alcanza con
 *  moverse lo suficiente para no comerse un clic tembloroso. */
const MOUSE_SLOP = 6;
/** Moverse esto antes de que venza la espera es desplazar la pantalla. */
const TOUCH_SLOP = 10;
const SETTLE_MS = 160;
/** La franja de los bordes de la ventana que desplaza mientras se arrastra:
 *  con el gesto tomado, el dedo ya no puede hacerlo. */
const EDGE = 72;
const EDGE_SPEED = 12;

interface Slot {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

interface Drag {
  id: string;
  /** Dónde estaba cada tarjeta al arrancar, en coordenadas de la página. */
  slots: Slot[];
  dx: number;
  dy: number;
  over: string | null;
  /** Soltada: va a su lugar y ya no sigue al puntero. */
  settling: boolean;
  /** Con «reducir movimiento» nada sigue al puntero: se atenúa y se marca. */
  animated: boolean;
}

interface Press {
  id: string;
  pointerId: number;
  mouse: boolean;
  startX: number;
  startY: number;
  clientX: number;
  clientY: number;
}

/**
 * Reordenar tarjetas tomándolas enteras, sin un ícono de agarre: con el mouse,
 * apretando y moviendo; con el dedo, sosteniendo primero, para que deslizar siga
 * desplazando la pantalla. La tarjeta sigue al puntero y las demás se corren.
 *
 * Los lugares se miden al arrancar y el destino se calcula contra esos lugares,
 * no con lo que hay bajo el puntero: como las tarjetas se corren, preguntar por
 * lo que está debajo haría saltar el destino con cada movimiento.
 *
 * Con el teclado, Alt más una flecha sobre la tarjeta enfocada la mueve al
 * vecino anterior o siguiente, si [canDrop] lo permite. No dibuja nada: el
 * orden nuevo llega por [onMove] como con el puntero.
 */
export function useHoldDrag({
  ids,
  canDrop,
  onMove,
}: {
  ids: string[];
  canDrop: (from: string, to: string) => boolean;
  onMove: (from: string, to: string) => void;
}) {
  const [drag, setDragState] = useState<Drag | null>(null);
  const dragRef = useRef<Drag | null>(null);
  const setDrag = (next: Drag | null) => {
    dragRef.current = next;
    setDragState(next);
  };
  const press = useRef<Press | null>(null);
  const timer = useRef<number | undefined>(undefined);
  const justDragged = useRef(false);
  const settling = useRef<number | undefined>(undefined);
  const startRef = useRef<() => void>(() => {});
  const callbacks = useRef({ canDrop, onMove });
  callbacks.current = { canDrop, onMove };

  // Al soltar, el orden nuevo llega un momento después (lo guarda quien usa
  // esto). Se limpia recién al recibirlo y antes de pintar: limpiar primero
  // mostraría un instante la lista vieja, y limpiar después, las tarjetas
  // corridas dos veces.
  const order = ids.join('\n');
  useLayoutEffect(() => {
    if (dragRef.current?.settling) setDrag(null);
  }, [order]);

  useEffect(() => {
    const clearPress = () => {
      window.clearTimeout(timer.current);
      press.current = null;
    };

    const follow = () => {
      const current = dragRef.current;
      const p = press.current;
      if (!current || !p || current.settling) return;
      const dx = p.clientX + window.scrollX - p.startX;
      const dy = p.clientY + window.scrollY - p.startY;
      const self = current.slots.find((s) => s.id === current.id)!;
      const cx = self.x + self.width / 2 + dx;
      const cy = self.y + self.height / 2 + dy;
      let nearest = self;
      let best = Number.POSITIVE_INFINITY;
      for (const slot of current.slots) {
        if (slot.id !== current.id && !callbacks.current.canDrop(current.id, slot.id)) continue;
        const distance = Math.hypot(slot.x + slot.width / 2 - cx, slot.y + slot.height / 2 - cy);
        if (distance < best) {
          best = distance;
          nearest = slot;
        }
      }
      setDrag({ ...current, dx, dy, over: nearest.id === current.id ? null : nearest.id });
    };

    const autoscroll = () => {
      const p = press.current;
      if (!dragRef.current || dragRef.current.settling || !p) return;
      const speed =
        p.clientY < EDGE ? -EDGE_SPEED : p.clientY > window.innerHeight - EDGE ? EDGE_SPEED : 0;
      if (speed !== 0) {
        window.scrollBy(0, speed);
        follow();
      }
      requestAnimationFrame(autoscroll);
    };

    const start = () => {
      const p = press.current;
      if (!p) return;
      justDragged.current = true;
      const slots = [...document.querySelectorAll<HTMLElement>('[data-reorder-id]')].map((el) => {
        const r = el.getBoundingClientRect();
        return {
          id: el.getAttribute('data-reorder-id')!,
          x: r.left + window.scrollX,
          y: r.top + window.scrollY,
          width: r.width,
          height: r.height,
        };
      });
      const animated = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      setDrag({ id: p.id, slots, dx: 0, dy: 0, over: null, settling: false, animated });
      // Sin esto, en un teléfono no se nota que la tarjeta ya se levantó.
      if (!p.mouse) navigator.vibrate?.(10);
      requestAnimationFrame(autoscroll);
    };

    const cancel = () => {
      clearPress();
      if (dragRef.current) setDrag(null);
    };

    const onPointerMove = (e: globalThis.PointerEvent) => {
      const p = press.current;
      if (!p || e.pointerId !== p.pointerId) return;
      p.clientX = e.clientX;
      p.clientY = e.clientY;
      if (dragRef.current) return follow();
      const moved = Math.hypot(e.clientX + window.scrollX - p.startX, e.clientY + window.scrollY - p.startY);
      if (p.mouse && moved > MOUSE_SLOP) start();
      else if (!p.mouse && moved > TOUCH_SLOP) clearPress();
    };

    const onPointerUp = (e: globalThis.PointerEvent) => {
      const p = press.current;
      if (!p || e.pointerId !== p.pointerId) return;
      clearPress();
      const current = dragRef.current;
      if (!current) return;
      const { id, over, slots, animated } = current;
      const from = slots.find((s) => s.id === id)!;
      const to = slots.find((s) => s.id === over) ?? from;
      setDrag({ ...current, settling: true, dx: to.x - from.x, dy: to.y - from.y });
      settling.current = window.setTimeout(
        () => {
          if (over !== null) callbacks.current.onMove(id, over);
          // Si el orden no llega a cambiar (se soltó en el mismo lugar, o el
          // guardado se rechazó), no hay nada que espere: se limpia igual.
          settling.current = window.setTimeout(() => {
            if (dragRef.current?.settling) setDrag(null);
          }, over === null ? 0 : 300);
        },
        animated ? SETTLE_MS : 0,
      );
    };

    const onPointerCancel = (e: globalThis.PointerEvent) => {
      if (press.current?.pointerId === e.pointerId) cancel();
    };

    // Tiene que estar antes de que empiece el toque y no ser pasivo: es lo único
    // que le saca el desplazamiento al navegador una vez tomada la tarjeta.
    const onTouchMove = (e: TouchEvent) => {
      if (dragRef.current) e.preventDefault();
    };

    // El clic que sigue a soltar no abre la ficha, ni cuando se sostuvo sin
    // llegar a mover.
    const onClick = (e: globalThis.MouseEvent) => {
      if (!justDragged.current) return;
      justDragged.current = false;
      e.preventDefault();
      e.stopPropagation();
    };

    // No siempre llega ese clic (un toque soltado afuera, `Escape`): sin esto, se
    // comería el primer toque de lo que venga después.
    const onAnyPointerDown = () => {
      justDragged.current = false;
    };

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && dragRef.current) cancel();
    };

    document.addEventListener('pointerdown', onAnyPointerDown, true);
    document.addEventListener('pointermove', onPointerMove);
    document.addEventListener('pointerup', onPointerUp);
    document.addEventListener('pointercancel', onPointerCancel);
    document.addEventListener('touchmove', onTouchMove, { passive: false });
    document.addEventListener('click', onClick, true);
    document.addEventListener('keydown', onKeyDown);
    startRef.current = start;
    return () => {
      window.clearTimeout(timer.current);
      window.clearTimeout(settling.current);
      document.removeEventListener('pointerdown', onAnyPointerDown, true);
      document.removeEventListener('pointermove', onPointerMove);
      document.removeEventListener('pointerup', onPointerUp);
      document.removeEventListener('pointercancel', onPointerCancel);
      document.removeEventListener('touchmove', onTouchMove);
      document.removeEventListener('click', onClick, true);
      document.removeEventListener('keydown', onKeyDown);
    };
    // Todo lo que cambia viaja por refs: los escuchadores se ponen una sola vez.
  }, []);

  const onPointerDown = (id: string) => (e: PointerEvent<HTMLElement>) => {
    if (e.button !== 0 || dragRef.current) return;
    // El menú de la tarjeta sigue siendo un botón.
    if ((e.target as Element).closest('button')) return;
    const mouse = e.pointerType === 'mouse';
    press.current = {
      id,
      pointerId: e.pointerId,
      mouse,
      startX: e.clientX + window.scrollX,
      startY: e.clientY + window.scrollY,
      clientX: e.clientX,
      clientY: e.clientY,
    };
    if (!mouse) timer.current = window.setTimeout(() => startRef.current(), HOLD_MS);
  };

  /** Cómo se dibuja [id] mientras se arrastra: la tomada sigue al puntero y las
   *  que están entre su lugar y el destino pasan al lugar de al lado. */
  const styleOf = (id: string): CSSProperties | undefined => {
    if (!drag?.animated) return undefined;
    if (id === drag.id) {
      return {
        transform: `translate(${drag.dx}px, ${drag.dy}px) scale(1.02)`,
        transition: drag.settling ? `transform ${SETTLE_MS}ms ease-out` : 'none',
        zIndex: 20,
      };
    }
    const shared = { transition: `transform ${SETTLE_MS}ms ease-out` };
    const from = drag.slots.findIndex((s) => s.id === drag.id);
    const to = drag.slots.findIndex((s) => s.id === drag.over);
    const at = drag.slots.findIndex((s) => s.id === id);
    const between = to >= 0 && at >= Math.min(from, to) && at <= Math.max(from, to);
    if (!between) return { ...shared, transform: 'translate(0, 0)' };
    const slot = drag.slots[at]!;
    const next = drag.slots[from < to ? at - 1 : at + 1]!;
    return { ...shared, transform: `translate(${next.x - slot.x}px, ${next.y - slot.y}px)` };
  };

  return {
    item: (id: string) => ({
      'data-reorder-id': id,
      style: styleOf(id),
      onPointerDown: onPointerDown(id),
      // Sostener un enlace abre el menú del teléfono; arrastrarlo con el mouse,
      // el arrastre propio del navegador.
      onContextMenu: (e: MouseEvent<HTMLElement>) => {
        if (press.current && !press.current.mouse) e.preventDefault();
      },
      onDragStart: (e: DragEvent<HTMLElement>) => e.preventDefault(),
      onKeyDown: (e: ReactKeyboardEvent<HTMLElement>) => {
        if (!e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
        const step = e.key === 'ArrowLeft' || e.key === 'ArrowUp' ? -1 : e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : 0;
        if (step === 0) return;
        // Alt más flecha también es «atrás» y «adelante» del navegador.
        e.preventDefault();
        const to = ids[ids.indexOf(id) + step];
        if (to !== undefined && callbacks.current.canDrop(id, to)) callbacks.current.onMove(id, to);
      },
    }),
    /** La tarjeta tomada y el destino. */
    dragging: drag?.id ?? null,
    over: drag?.over ?? null,
    animated: drag?.animated ?? false,
  };
}
