import { Component, type ErrorInfo, type ReactNode } from 'react';
import { useTexts } from '../i18n/context';
import { reportError } from './reportError';
import { Shell } from './Shell';
import { AppErrorView } from './status';

// Sin esto, en React 19 una excepción al dibujar (el motor que falla con una
// multiclase rara) desmonta toda la app y deja la pantalla en blanco.

function trimmed(text: string | undefined, lines: number): string {
  return (text ?? '').split('\n').slice(0, lines).join('\n');
}

function Fallback({ error, componentStack, onRetry }: { error: Error; componentStack?: string; onRetry: () => void }) {
  const t = useTexts();
  // Se muestra el detalle porque viaja en «Reportar este error»; recortado,
  // para no volcar toda la traza en la pantalla.
  const detail = [error.message, trimmed(error.stack, 4), trimmed(componentStack, 4)].filter(Boolean).join('\n');
  return <AppErrorView as="h1" title={t.errorScreenTitle} message={t.errorScreenBody} detail={detail} onRetry={onRetry} />;
}

type Props = { children: ReactNode; reload?: boolean; resetKey?: string };
type State = { error: Error | null; componentStack?: string; resetKey?: string };

/**
 * [reload]: «Reintentar» recarga la página (el de la raíz, que no tiene una
 * vista que volver a montar). Si no, vuelve a montar los hijos.
 *
 * [resetKey]: si cambia, el error se limpia. El de la ruta le pasa la ruta
 * actual: navegar a otra pantalla lo limpia **sin** usar `key`, porque un `key`
 * desmontaría todas las rutas a cada navegación y perdería el estado que
 * sobrevive entre las del mismo personaje (el aviso con «Deshacer» de la
 * subida de nivel, la ficha entre pestañas).
 */
export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null, resetKey: this.props.resetKey };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  static getDerivedStateFromProps(props: Props, state: State): Partial<State> | null {
    return props.resetKey !== state.resetKey ? { error: null, resetKey: props.resetKey } : null;
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    this.setState({ componentStack: info.componentStack ?? undefined });
    console.error(error, info.componentStack);
    reportError({ message: error.message, stack: error.stack, componentStack: info.componentStack ?? undefined });
  }

  render() {
    const { error, componentStack } = this.state;
    if (!error) return this.props.children;
    const fallback = (
      <Fallback
        error={error}
        componentStack={componentStack}
        onRetry={() => (this.props.reload ? window.location.reload() : this.setState({ error: null }))}
      />
    );
    // El de la raíz reemplaza hasta el marco; el de la ruta vive dentro de él.
    return this.props.reload ? <Shell>{fallback}</Shell> : fallback;
  }
}
