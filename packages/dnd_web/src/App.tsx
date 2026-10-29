import { useCallback, useEffect, useState } from 'react';
import { fetchAccount, fetchThemeMode, type Account } from './api/client';
import { setEngineLanguage } from './engine';
import { LangProvider, useTexts } from './i18n/context';
import { resolveLang, type Lang } from './i18n/texts';
import { matchRoute } from './router';
import { CharacterPage } from './sheet/CharacterPage';
import { ActionButton, ActionLink, Notice, Shell } from './ui/Shell';

/** `loading` y `error` son estados aparte de `anonymous`: no poder comprobar
 *  la sesión no es lo mismo que no tenerla. */
type Session =
  | { kind: 'loading' }
  | { kind: 'anonymous' }
  | { kind: 'signed-in'; account: Account }
  | { kind: 'error' };

// El idioma se resuelve una vez, al cargar, y también el del motor: sus
// rótulos («Mediano») son estado global que hay que fijar antes de calcular.
const LANG: Lang = resolveLang();
document.documentElement.lang = LANG;
setEngineLanguage(LANG);

/** Aplica el tema de los ajustes de la cuenta: `dark` (el que arranca),
 *  `light` o `system`, como `AppThemeController` de Flutter. */
function applyTheme(mode: string) {
  const dark =
    mode === 'system'
      ? !window.matchMedia('(prefers-color-scheme: light)').matches
      : mode !== 'light';
  document.documentElement.dataset.theme = dark ? 'dark' : 'light';
}

export function App() {
  return (
    <LangProvider lang={LANG}>
      <Shell>
        <Screen />
      </Shell>
    </LangProvider>
  );
}

function Screen() {
  const t = useTexts();
  const [session, setSession] = useState<Session>({ kind: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const retry = useCallback(() => {
    setSession({ kind: 'loading' });
    setAttempt((n) => n + 1);
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    fetchAccount(controller.signal)
      .then(async (account): Promise<Session> => {
        if (account === null) return { kind: 'anonymous' };
        if (account.webV2 === true) {
          applyTheme(await fetchThemeMode(controller.signal));
        }
        return { kind: 'signed-in', account };
      })
      .then(setSession)
      .catch(() => {
        if (!controller.signal.aborted) setSession({ kind: 'error' });
      });
    return () => controller.abort();
  }, [attempt]);

  switch (session.kind) {
    case 'loading':
      return <Notice title={t.loadingSession} />;
    case 'error':
      return (
        <Notice
          title={t.errorTitle}
          body={t.errorBody}
          action={<ActionButton onClick={retry}>{t.retry}</ActionButton>}
        />
      );
    case 'anonymous':
      return (
        <Notice
          title={t.signedOutTitle}
          body={t.signedOutBody}
          action={<ActionLink href="/auth/login">{t.signIn}</ActionLink>}
        />
      );
    case 'signed-in': {
      // Sin `webV2` la ruta no existe: no hay pista de que haya algo detrás.
      // Es la misma pantalla para cualquier ruta, conocida o no.
      if (session.account.webV2 !== true) {
        return <Notice title={t.unavailableTitle} body={t.unavailableBody} />;
      }
      const route = matchRoute(window.location.pathname);
      if (route.name === 'character') return <CharacterPage id={route.id} />;
      return <Notice title={t.notFoundTitleRoute} />;
    }
  }
}
