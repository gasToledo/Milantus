import { useEffect, useState } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { createQueryClient, useAccount, useDmCampaigns, useThemeMode } from './api/queries';
import type { Account } from './api/client';
import { setEngineLanguage } from './engine';
import { LangProvider, useTexts } from './i18n/context';
import { resolveLang, type Lang } from './i18n/texts';
import { DashboardPage } from './dashboard/DashboardPage';
import { RosterFooter, RosterPanel } from './dashboard/RosterPanel';
import { DmPanel } from './dm/DmPanel';
import { useRoute } from './router';
import { DmPage } from './dm/DmPage';
import { CodexPage } from './codex/CodexPage';
import { BestiaryPage } from './bestiary/BestiaryPage';
import { CampaignsPage } from './campaigns/CampaignsPage';
import { CharacterPage } from './sheet/CharacterPage';
import { SettingsPage } from './settings/SettingsPage';
import { ThemeProvider, useTheme } from './theme/theme';
import { ButtonLink } from './ui/Button';
import { TooltipProvider } from './ui/primitives';
import { Shell } from './ui/Shell';
import { AppBusyLabel, AppErrorView, Notice } from './ui/status';

// El idioma se resuelve una vez, al cargar, y también el del motor: sus
// rótulos («Mediano») son estado global que hay que fijar antes de calcular.
const LANG: Lang = resolveLang();
document.documentElement.lang = LANG;
setEngineLanguage(LANG);

export function App() {
  // Un cliente por montaje (no un módulo global): así una prueba o un
  // remontaje empiezan con la caché vacía.
  const [queryClient] = useState(createQueryClient);
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <LangProvider lang={LANG}>
          <TooltipProvider delayDuration={400}>
            <Screen />
          </TooltipProvider>
        </LangProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

/**
 * La sesión decide el marco. `loading` y `error` son estados aparte de «sin
 * sesión»: no poder comprobarla no es lo mismo que no tenerla.
 */
function Screen() {
  const t = useTexts();
  const account = useAccount();

  if (account.isPending) {
    return (
      <Shell>
        <AppBusyLabel label={t.loadingSession} />
      </Shell>
    );
  }
  if (account.isError) {
    return (
      <Shell>
        <AppErrorView as="h1" title={t.sessionErrorTitle} message={t.errorBody} onRetry={() => account.refetch()} />
      </Shell>
    );
  }
  if (account.data === null) {
    return (
      <Shell>
        <Notice
          title={t.signedOutTitle}
          body={t.signedOutBody}
          action={<ButtonLink href="/auth/login">{t.signIn}</ButtonLink>}
        />
      </Shell>
    );
  }
  // Sin `webV2` la ruta no existe: no hay pista de que haya algo detrás. Es
  // la misma pantalla para cualquier ruta, conocida o no, y no pide nada más
  // a la API (ni ajustes, ni personajes).
  if (account.data.webV2 !== true) {
    return (
      <Shell>
        <Notice title={t.unavailableTitle} body={t.unavailableBody} />
      </Shell>
    );
  }
  return <Enabled account={account.data} />;
}

/** Solo para cuentas con `webV2`: el tema de la cuenta y las rutas. */
function Enabled({ account }: { account: Account }) {
  const t = useTexts();
  const { route } = useRoute();
  const themeMode = useThemeMode(true);
  const { adoptAccountMode } = useTheme();
  useEffect(() => {
    if (themeMode.data) adoptAccountMode(themeMode.data);
  }, [themeMode.data, adoptAccountMode]);

  switch (route.name) {
    case 'roster':
      return (
        <Shell panel={<RosterPanel current="roster" />} footer={<RosterFooter account={account} />}>
          <DashboardPage />
        </Shell>
      );
    case 'dm':
      return <DmPage view={route.view} account={account} />;
    case 'bestiary':
      return (
        <Shell panel={<RosterPanel />} footer={<RosterFooter account={account} />}>
          <BestiaryPage entryId={route.entryId} />
        </Shell>
      );
    case 'campaigns':
      return (
        <Shell panel={<RosterPanel />} footer={<RosterFooter account={account} />}>
          <CampaignsPage />
        </Shell>
      );
    case 'settings':
      return (
        <SettingsShell account={account} />
      );
    case 'character':
      return <CharacterPage id={route.id} tab={route.tab} />;
    // La misma página, para que el aviso con «Deshacer» siga al volver a la
    // ficha: React conserva la instancia entre las dos rutas.
    case 'levelUp':
      return <CharacterPage id={route.id} tab={null} levelUp />;
    case 'codex':
      return <CodexPage category={route.category} entryId={route.entryId} />;
    case 'unknown':
      return (
        <Shell panel={<RosterPanel />} footer={<RosterFooter account={account} />}>
          <Notice title={t.notFoundTitleRoute} />
        </Shell>
      );
  }
}

/**
 * Los ajustes con el panel del modo del que se vino (`?modo=dm`): son de la
 * cuenta, pero salir de ellos con «atrás» no puede cambiarte de modo.
 */
function SettingsShell({ account }: { account: Account }) {
  const fromDm = new URLSearchParams(window.location.search).get('modo') === 'dm';
  const campaigns = useDmCampaigns({ enabled: fromDm });
  return (
    <Shell
      panel={fromDm ? <DmPanel campaigns={campaigns.data} /> : <RosterPanel />}
      footer={<RosterFooter account={account} current="settings" dm={fromDm} />}
    >
      <SettingsPage />
    </Shell>
  );
}
