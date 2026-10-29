import type { ReactNode } from 'react';
import { CircleAlert, Inbox, LoaderCircle, RotateCw, SearchX } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { Button } from './Button';

// Los tres estados que toda pantalla con datos tiene, siempre con los mismos
// componentes (`diseno-web.md` §8, «Retroalimentación»): si cada pantalla
// dibujara el suyo, «cargando» se vería de cinco formas distintas.

/**
 * Un pedido en curso. El texto es **obligatorio**: un spinner solo no dice qué
 * está pasando. Es región viva para que el lector lo anuncie.
 */
export function AppBusyLabel({ label }: { label: string }) {
  return (
    <p role="status" className="flex items-center gap-2.5 text-[14px] text-on-surface-variant">
      <LoaderCircle size={18} aria-hidden="true" className="shrink-0 animate-spin text-gold" />
      {label}
    </p>
  );
}

/**
 * Algo falló. `onRetry` es lo que lo separa de un cartel muerto: casi todo lo
 * que falla acá es la red o el túnel, y se arregla reintentando. El detalle
 * técnico, si hay, se puede seleccionar y copiar para reportarlo.
 *
 * [as] `h1` cuando el error ocupa la pantalla (es su único título).
 */
export function AppErrorView({
  title,
  message,
  detail,
  onRetry,
  as: Heading = 'h2',
}: {
  title: string;
  message?: string;
  detail?: string;
  onRetry?: () => void;
  as?: 'h1' | 'h2';
}) {
  const t = useTexts();
  return (
    <section role="alert" className="card flex flex-col items-start gap-3 p-6">
      <CircleAlert size={40} aria-hidden="true" className="text-crimson" />
      <Heading className="font-display text-[20px] text-on-surface">{title}</Heading>
      {message && <p className="text-on-surface-variant">{message}</p>}
      {detail && (
        <pre className="plaque max-w-full overflow-x-auto px-3 py-2 text-[12px] whitespace-pre-wrap text-text-muted select-text">
          {detail}
        </pre>
      )}
      {onRetry && (
        <Button icon={RotateCw} onClick={onRetry}>
          {t.retry}
        </Button>
      )}
    </section>
  );
}

/**
 * Una lista vacía. Distingue **«no hay nada»** (`empty`: invita a empezar) de
 * **«nada coincide con la búsqueda»** (`no-match`: invita a corregir la
 * búsqueda): son situaciones distintas y piden acciones distintas, y por eso
 * el ícono también cambia. El mensaje es región viva: al tipear en un
 * buscador, el lector anuncia que dejó de haber resultados.
 */
export function AppEmptyState({
  kind,
  message,
  hint,
  actions,
}: {
  kind: 'empty' | 'no-match';
  message: string;
  hint?: string;
  actions?: ReactNode;
}) {
  const Icon = kind === 'empty' ? Inbox : SearchX;
  return (
    <div className="card flex flex-col items-center p-8 text-center" data-empty={kind}>
      <Icon size={40} aria-hidden="true" className="text-on-surface-variant" />
      <p role="status" className="font-display mt-3 text-[18px] text-on-surface">
        {message}
      </p>
      {hint && <p className="mt-2 text-[14px] text-on-surface-variant">{hint}</p>}
      {actions && <div className="mt-4 flex flex-wrap justify-center gap-3">{actions}</div>}
    </div>
  );
}

/** Pantalla sobria de un solo mensaje (sin sesión, no disponible, no
 *  encontrado): un título, una línea y, si hace falta, una acción real. */
export function Notice({ title, body, action }: { title: string; body?: string; action?: ReactNode }) {
  return (
    <section className="card p-6">
      <h1 className="font-display text-[20px] text-on-surface">{title}</h1>
      {body && <p className="mt-2 text-on-surface-variant">{body}</p>}
      {action && <div className="mt-4">{action}</div>}
    </section>
  );
}
