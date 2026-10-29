import { useCallback, useEffect, useState } from 'react';
import { fetchAccount, fetchThemeMode, type Account } from './api/client';
import { setEngineLanguage } from './engine';
import { LangProvider, useTexts } from './i18n/context';
import { resolveLang, type Lang } from './i18n/texts';
import { DashboardPage } from './dashboard/DashboardPage';
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
      <Screen />
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

  // Cada estado arma su marco: solo con sesión y `webV2` el panel lleva
  // navegación y cuenta.
  switch (session.kind) {
    case 'loading':
      return (
        <Shell>
          <Notice title={t.loadingSession} />
        </Shell>
      );
    case 'error':
      return (
        <Shell>
          <Notice
            title={t.errorTitle}
            body={t.errorBody}
            action={<ActionButton onClick={retry}>{t.retry}</ActionButton>}
          />
        </Shell>
      );
    case 'anonymous':
      return (
        <Shell>
          <Notice
            title={t.signedOutTitle}
            body={t.signedOutBody}
            action={<ActionLink href="/auth/login">{t.signIn}</ActionLink>}
          />
        </Shell>
      );
    case 'signed-in': {
      // Sin `webV2` la ruta no existe: no hay pista de que haya algo detrás.
      // Es la misma pantalla para cualquier ruta, conocida o no.
      if (session.account.webV2 !== true) {
        return (
          <Shell>
            <Notice title={t.unavailableTitle} body={t.unavailableBody} />
          </Shell>
        );
      }
      const { account } = session;
      const route = matchRoute(window.location.pathname);
      switch (route.name) {
        case 'roster':
          return (
            <Shell account={account} current="roster">
              <DashboardPage />
            </Shell>
          );
        case 'character':
          return (
            <Shell account={account} current="sheet">
              <CharacterPage id={route.id} />
            </Shell>
          );
        case 'unknown':
          return (
            <Shell account={account}>
              <Notice title={t.notFoundTitleRoute} />
            </Shell>
          );
      }
    }
  }
}
