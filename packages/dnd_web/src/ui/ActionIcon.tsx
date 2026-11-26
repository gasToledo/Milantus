import type { ReactNode } from 'react';

export type ActionKind = 'action' | 'bonus' | 'reaction' | 'long';

/* Un color por tipo, además de la forma: verde la acción, ámbar la adicional,
   violeta la reacción, cielo lo que lleva minutos u horas. Ninguno es el
   carmesí (daño) ni el oro (números e información). La forma sigue diciendo lo
   mismo sin color. */
const ICON: Record<ActionKind, { color: string; shape: ReactNode }> = {
  action: { color: 'text-[var(--act-action)]', shape: <circle cx="8" cy="8" r="4.2" fill="currentColor" /> },
  bonus: { color: 'text-[var(--act-bonus)]', shape: <path d="M8 3.2L13 12.4H3Z" fill="currentColor" /> },
  reaction: {
    color: 'text-[var(--act-reaction)]',
    shape: (
      <>
        <path d="M5.5 4.2H10A3.4 3.4 0 0 1 10 11H5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
        <path d="M7.2 1.9L4.6 4.2L7.2 6.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      </>
    ),
  },
  long: {
    color: 'text-[var(--act-long)]',
    shape: (
      <path d="M4.5 2.5H11.5M4.5 13.5H11.5M5.2 2.5C5.2 6 10.8 6 10.8 8S5.2 10 5.2 13.5M10.8 2.5C10.8 6 5.2 6 5.2 8S10.8 10 10.8 13.5" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    ),
  },
};

/** El tipo de acción de un ataque o un conjuro, delante del nombre. Sin leyenda
 *  a la vista: [label] se lee al pasar el mouse y en el lector de pantalla. */
export function ActionIcon({ kind, label }: { kind: ActionKind; label: string }) {
  const { color, shape } = ICON[kind];
  return (
    <span title={label} className={`inline-flex h-4 w-4 shrink-0 ${color}`}>
      <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
        {shape}
      </svg>
      <span className="sr-only">{label}</span>
    </span>
  );
}
