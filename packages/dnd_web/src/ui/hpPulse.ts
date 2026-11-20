import { usePulseOnChange } from './pulse';

/**
 * El pulso de los PG (`.hp-pulse-down` / `.hp-pulse-up` en `index.css`): la
 * cifra late carmesí al bajar y verde al subir, y confirma que el golpe o la
 * curación entró. Lo usan la fila del Combate del DM y los PG de la ficha.
 *
 * Devuelve la `key` y la clase del elemento que late: la `key` lo remonta en
 * cada cambio, así dos golpes seguidos laten dos veces. La cuenta es
 * `usePulseOnChange`; acá solo se elige el color. La primera lectura no late:
 * no es un cambio.
 */
export function useHpPulse(current: number | undefined): { key: number; className: string | undefined } {
  const { key, detail } = usePulseOnChange(current, (before, next) => (next > before ? 'hp-pulse-up' : 'hp-pulse-down'));
  return { key, className: detail ?? undefined };
}
