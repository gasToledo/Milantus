import { useEffect, useRef, useState } from 'react';

/**
 * El pulso de los PG (`.hp-pulse-down` / `.hp-pulse-up` en `index.css`): la
 * cifra late carmesí al bajar y verde al subir, y confirma que el golpe o la
 * curación entró. Lo usan la fila del Combate del DM y los PG de la ficha.
 *
 * Devuelve la `key` y la clase del elemento que late: la `key` lo remonta en
 * cada cambio, así dos golpes seguidos laten dos veces. La primera lectura no
 * late: no es un cambio.
 */
export function useHpPulse(current: number | undefined): { key: number; className: string | undefined } {
  const last = useRef(current);
  const [pulse, setPulse] = useState<{ up: boolean; n: number } | null>(null);
  useEffect(() => {
    const before = last.current;
    last.current = current;
    if (before === undefined || current === undefined || before === current) return;
    setPulse((p) => ({ up: current > before, n: (p?.n ?? 0) + 1 }));
  }, [current]);
  return { key: pulse?.n ?? 0, className: pulse ? (pulse.up ? 'hp-pulse-up' : 'hp-pulse-down') : undefined };
}
