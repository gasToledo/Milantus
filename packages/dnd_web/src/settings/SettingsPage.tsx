import { ExternalLink, Globe, Palette } from 'lucide-react';
import { useRoster, useRosterSettings } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { storeLang, type Lang } from '../i18n/texts';
import { parseSortMode } from '../dashboard/roster';
import { FLUTTER_HOME } from '../router';
import { useTheme, type ThemeMode } from '../theme/theme';
import { ButtonLink } from '../ui/Button';
import { Card } from '../ui/Card';
import { SectionRule } from '../ui/data';
import { Select } from '../ui/primitives';
import { AppBusyLabel, AppErrorView } from '../ui/status';

/**
 * Ajustes, en la medida en que React puede mostrarlos. Dos tarjetas, y la
 * diferencia entre ellas es lo único que hay que entender:
 *
 * - **En este navegador**: el tema y el idioma. Son preferencias locales
 *   (`localStorage`, con las mismas claves que Flutter), se cambian acá y no
 *   tocan ningún documento del servidor.
 * - **En tu cuenta**: lo que Flutter guarda en `/api/settings`. Se **lee y se
 *   muestra**; cambiarlo es una escritura y React todavía no escribe.
 *
 * Lo que Flutter ofrece además y acá no: mantener la pantalla encendida y
 * volver a mostrar los tutoriales (ambos actúan sobre funciones de Flutter),
 * la dificultad del encuentro (es del Modo DM) y el proveedor de retratos
 * (vive en la pantalla de retratos).
 */
export function SettingsPage() {
  const t = useTexts();
  const settings = useRosterSettings();
  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="font-display text-[30px] leading-tight text-on-surface">{t.settings}</h1>
      </header>
      <SectionRule className="my-0" />
      <div className="grid items-start gap-4 [grid-template-columns:repeat(auto-fit,minmax(min(340px,100%),1fr))]">
        <BrowserCard />
        {settings.isError ? (
          <AppErrorView title={t.settingsLoadError} message={t.errorBody} onRetry={() => settings.refetch()} />
        ) : settings.data ? (
          <AccountCard settings={settings.data} />
        ) : (
          <AppBusyLabel label={t.settingsLoading} />
        )}
      </div>
    </div>
  );
}

function BrowserCard() {
  const t = useTexts();
  const lang = useLang();
  const { mode, setMode } = useTheme();
  return (
    <Card id="settings-browser" title={t.settingsBrowserTitle} icon={Palette}>
      <div className="flex flex-col items-start gap-3">
        <Select
          label={t.themeLabel}
          value={mode}
          onValueChange={(v) => setMode(v as ThemeMode)}
          options={(['dark', 'light', 'system'] as const).map((m) => ({ value: m, label: t.themeModes[m] }))}
        />
        <Select
          label={t.settingsLanguage}
          value={lang}
          onValueChange={(next) => {
            // El idioma se resuelve una sola vez al cargar (también el del
            // motor): cambiarlo es guardarlo y recargar.
            if (next !== lang && storeLang(next as Lang)) window.location.reload();
          }}
          options={(['es', 'en'] as const).map((l) => ({ value: l, label: t.languageNames[l] }))}
        />
      </div>
    </Card>
  );
}

function AccountCard({ settings }: { settings: NonNullable<ReturnType<typeof useRosterSettings>['data']> }) {
  const t = useTexts();
  // El favorito se guarda por id: para nombrarlo hace falta la lista. Si
  // todavía no llegó (o falla), la fila dice «Ninguno» antes que un id crudo.
  const roster = useRoster();
  const name = roster.data?.find((c) => c.character.id === settings.favoriteCharacterId)?.character.name;
  const favorite = typeof name === 'string' ? name : undefined;
  const rows: [string, string, string][] = [
    ['start-mode', t.settingsStartMode, settings.startsInDmMode ? t.settingsStartModes.dm : t.settingsStartModes.player],
    ['sort', t.sortLabel, t.sortModes[parseSortMode(settings.sortMode)]],
    ['favorite', t.favorite, favorite ?? t.settingsNoFavorite],
  ];
  return (
    <Card id="settings-account" title={t.settingsAccountTitle} icon={Globe}>
      <dl className="flex flex-col">
        {rows.map(([field, label, value]) => (
          <div
            key={field}
            data-field={field}
            className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 border-t border-hairline py-2.5 first:border-t-0 first:pt-0"
          >
            <dt className="text-[14px] text-on-surface-variant">{label}</dt>
            <dd className="min-w-0 text-[14px] break-words text-on-surface">{value}</dd>
          </div>
        ))}
      </dl>
      {/* Cambiar esto es una escritura, y todavía vive en Flutter. */}
      <ButtonLink href={FLUTTER_HOME} icon={ExternalLink} tone="secondary" className="mt-3">
        {t.settingsChange}
      </ButtonLink>
    </Card>
  );
}
