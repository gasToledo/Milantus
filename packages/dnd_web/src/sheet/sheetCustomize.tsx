import { createContext, useMemo, useState } from 'react';

/** Si «Personalizar ficha» está abierto y dónde va su panel en pantallas
 *  anchas ([slot], la columna derecha del `Shell`). */
export const SheetCustomizeContext = createContext<{
  open: boolean;
  setOpen: (open: boolean) => void;
  slot: HTMLElement | null;
}>({ open: false, setOpen: () => {}, slot: null });

/**
 * Lo que pone la pantalla que dibuja el `Shell` alrededor de una ficha: el
 * valor del contexto y el `aside`. El panel lo arma `ArrangeableColumns`, que
 * es quien conoce la pestaña y la ficha, y lo lleva a la columna con un portal:
 * así la ficha propia, la de un miembro y la de un PNJ usan el mismo camino.
 */
export function useSheetCustomizeHost() {
  const [open, setOpen] = useState(false);
  const [slot, setSlot] = useState<HTMLElement | null>(null);
  const value = useMemo(() => ({ open, setOpen, slot }), [open, slot]);
  return { value, aside: open ? <div ref={setSlot} /> : undefined };
}
