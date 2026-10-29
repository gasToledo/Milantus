import type { ReactNode } from 'react';

/**
 * Lista vacía. Distingue «no hay nada» de «nada coincide con la búsqueda»:
 * son situaciones distintas y piden acciones distintas (empezar vs. corregir
 * la búsqueda), así que quien llama decide el texto y las acciones. Sin
 * encabezado propio: la pantalla ya tiene su `h1`.
 */
export function EmptyState({
  message,
  hint,
  actions,
  kind,
}: {
  message: string;
  hint?: string;
  actions?: ReactNode;
  kind: 'empty' | 'no-match';
}) {
  return (
    <div className="card p-8 text-center" data-empty={kind}>
      <p className="font-display text-[18px] text-on-surface">{message}</p>
      {hint && <p className="mt-2 text-[14px] text-on-surface-variant">{hint}</p>}
      {actions && <div className="mt-4 flex flex-wrap justify-center gap-3">{actions}</div>}
    </div>
  );
}
