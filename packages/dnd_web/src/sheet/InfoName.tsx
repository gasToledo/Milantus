import { Info } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

/**
 * El nombre de un recurso o de un objeto que, si tiene texto, es un botón con
 * un ícono `Info` que lo abre en un diálogo. Se abre con un toque y no con un
 * tooltip: en el teléfono el tooltip no existe. Sin texto devuelve el nombre
 * tal cual y sin ícono, para no prometer lo que no hay.
 */
export function InfoName({
  title,
  description,
  children,
  className,
}: {
  title: string;
  /** Vacío o ausente: el nombre queda como texto plano. */
  description?: string;
  /** El nombre tal como se muestra (puede llevar su `data-field`). */
  children: ReactNode;
  className?: string;
}) {
  const t = useTexts();
  const [open, setOpen] = useState(false);
  if (!description) return <>{children}</>;
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={`inline-flex items-center gap-1.5 text-left font-medium ${className ?? ''}`}
      >
        {children}
        <Info size={13} aria-hidden="true" className="shrink-0 text-text-muted" />
      </button>
      {open && (
        <AppDialog open onOpenChange={setOpen} title={title} actions={[{ label: t.close, primary: true }]}>
          <p className="whitespace-pre-line text-on-surface-variant">{description}</p>
        </AppDialog>
      )}
    </>
  );
}
