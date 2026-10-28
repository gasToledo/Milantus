import { useEffect, useState } from 'react';

/** Lo que `GET /api/me` devuelve (ver `AccountInfo` en `dnd_app`). */
interface Account {
  userId: string;
  name?: string | null;
  email?: string | null;
}

/** `loading` y `error` son estados aparte de `anonymous`: no poder comprobar
 *  la sesión no es lo mismo que no tenerla. */
type Session =
  | { kind: 'loading' }
  | { kind: 'anonymous' }
  | { kind: 'signed-in'; account: Account }
  | { kind: 'error' };

async function fetchSession(signal: AbortSignal): Promise<Session> {
  // Ruta relativa y mismo origen: la cookie `httpOnly` viaja sola y el
  // cliente no necesita `baseUrl`, igual que `api_client.dart`.
  const response = await fetch('/api/me', { signal });
  if (response.status === 401) return { kind: 'anonymous' };
  if (!response.ok) return { kind: 'error' };
  return { kind: 'signed-in', account: (await response.json()) as Account };
}

export function App() {
  const [session, setSession] = useState<Session>({ kind: 'loading' });

  useEffect(() => {
    const controller = new AbortController();
    fetchSession(controller.signal)
      .then(setSession)
      .catch(() => {
        if (!controller.signal.aborted) setSession({ kind: 'error' });
      });
    return () => controller.abort();
  }, []);

  return (
    <main className="mx-auto max-w-[var(--page-max-width)] p-6">
      <h1 className="font-[family-name:var(--font-display)] text-2xl text-[var(--gold)]">
        Milantus
      </h1>
      <p className="mt-2 text-[var(--on-surface-variant)]">
        {session.kind === 'loading' && 'Comprobando la sesión…'}
        {session.kind === 'anonymous' && 'No hay sesión iniciada.'}
        {session.kind === 'error' && 'No se pudo comprobar la sesión.'}
        {session.kind === 'signed-in' &&
          `Sesión iniciada como ${session.account.name ?? session.account.email ?? session.account.userId}.`}
      </p>
    </main>
  );
}
