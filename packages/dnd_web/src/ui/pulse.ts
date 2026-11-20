import { useEffect, useEffectEvent, useRef, useState } from 'react';

/**
 * Cuenta los cambios de [value] para remontar un elemento y repetir su
 * animación (`key`). El primer valor no cuenta: no es un cambio. `null` y
 * `undefined` tampoco, no hay cifra que late.
 *
 * [classify] dice qué fue el cambio (subió o bajó) con el valor anterior y
 * el nuevo. Se lee en el efecto, así la función de cada render no rearma la
 * suscripción ni se queda vieja.
 */
export function usePulseOnChange<T, D = null>(
  value: T,
  classify?: (before: NonNullable<T>, next: NonNullable<T>) => D,
): { key: number; detail: D | null } {
  const last = useRef(value);
  const readDetail = useEffectEvent((before: NonNullable<T>, next: NonNullable<T>): D | null =>
    classify ? classify(before, next) : null,
  );
  const [pulse, setPulse] = useState<{ key: number; detail: D | null } | null>(null);
  useEffect(() => {
    const before = last.current;
    last.current = value;
    if (before == null || value == null || before === value) return;
    const detail = readDetail(before, value);
    setPulse((p) => ({ key: (p?.key ?? 0) + 1, detail }));
  }, [value]);
  return { key: pulse?.key ?? 0, detail: pulse?.detail ?? null };
}
