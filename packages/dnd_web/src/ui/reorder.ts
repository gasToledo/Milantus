import { useCallback, useEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from 'react';

/**
 * Reordenar una lista de tarjetas con el puntero o el teclado, sin
 * dependencias (lo usa el Diario; la lista de personajes lo va a reusar).
 *
 * El gesto arranca **solo** en el ícono de mover (`grip`): el resto de la
 * tarjeta sigue siendo un botón y la pantalla táctil se desplaza con normalidad
 * —el ícono lleva `touch-action: none`, nada más—. Mientras se arrastra no
 * sigue nada al puntero: la tarjeta de origen se atenúa (`dragging`) y la de
 * destino se marca (`over`); al soltar, `onMove(desde, hasta)` si cambió.
 *
 * Con el teclado, las flechas mueven la tarjeta un lugar y el foco queda en el
 * mismo ícono, para poder seguir.
 *
 * Cada tarjeta lleva `item(id)` (para hallarla bajo el puntero) y su ícono
 * `grip(id)`.
 */
export function useReorder({ ids, onMove }: { ids: string[]; onMove: (from: string, to: string) => void }) {
  const [dragging, setDragging] = useState<string | null>(null);
  const [over, setOver] = useState<string | null>(null);
  // El destino también en una ref: `pointerup` llega en el mismo tick que el
  // último `pointermove` y no tiene por qué ver el render intermedio.
  const overRef = useRef<string | null>(null);
  const refocus = useRef<string | null>(null);

  const reset = useCallback(() => {
    overRef.current = null;
    setDragging(null);
    setOver(null);
  }, []);

  // Escape cancela el arrastre aunque el foco no esté en el ícono (Safari no
  // enfoca un botón al tocarlo).
  useEffect(() => {
    if (dragging === null) return;
    const onKey = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && reset();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [dragging, reset]);

  // Reordenar mueve el nodo en el DOM y el navegador puede soltar el foco.
  const order = ids.join('\n');
  useEffect(() => {
    const id = refocus.current;
    refocus.current = null;
    if (id !== null) document.querySelector<HTMLElement>(`[data-reorder-grip="${CSS.escape(id)}"]`)?.focus();
  }, [order]);

  const grip = (id: string) => ({
    'data-reorder-grip': id,
    style: { touchAction: 'none' as const },
    onPointerDown: (e: PointerEvent<HTMLElement>) => {
      if (e.button !== 0) return;
      e.currentTarget.setPointerCapture(e.pointerId);
      setDragging(id);
    },
    onPointerMove: (e: PointerEvent<HTMLElement>) => {
      if (dragging !== id) return;
      const hit = document.elementFromPoint(e.clientX, e.clientY)?.closest('[data-reorder-id]');
      const target = hit?.getAttribute('data-reorder-id') ?? null;
      const next = target !== null && target !== id ? target : null;
      overRef.current = next;
      setOver(next);
    },
    onPointerUp: () => {
      const to = overRef.current;
      reset();
      if (dragging !== null && to !== null) onMove(dragging, to);
    },
    onPointerCancel: reset,
    onKeyDown: (e: KeyboardEvent<HTMLElement>) => {
      const step = e.key === 'ArrowLeft' || e.key === 'ArrowUp' ? -1 : e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : 0;
      if (step === 0) return;
      e.preventDefault();
      const to = ids[ids.indexOf(id) + step];
      if (to === undefined) return;
      refocus.current = id;
      onMove(id, to);
    },
  });

  return {
    item: (id: string) => ({ 'data-reorder-id': id }),
    grip,
    /** La tarjeta que se está moviendo y el destino sobre el que está. */
    dragging,
    over,
  };
}
