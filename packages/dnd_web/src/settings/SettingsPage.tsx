import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Globe, Palette } from 'lucide-react';
import { useEffect, useState } from 'react';
import type { RosterSettings } from '../api/client';
import { queryKeys, useRoster, useRosterSettings } from '../api/queries';
import { patchSettings } from '../api/settingsSave';
import { useLang, useTexts } from '../i18n/context';
import { storeLang, type Lang } from '../i18n/texts';
import { parseSortMode } from '../dashboard/roster';
import { isThemeMode, useSystemLight, useTheme, type ThemeMode } from '../theme/theme';
import { Card } from '../ui/Card';
import { SectionRule } from '../ui/data';
import { Button } from '../ui/Button';
import { Select, Switch } from '../ui/primitives';
import { AppBusyLabel, AppErrorView } from '../ui/status';
import { resetTutorials } from '../ui/tutorials';
import { setAnimationsOff, systemReducesMotion, useAnimationsOff } from '../ui/motion';

const LEGACY_COOKIE = 'milantus_v1';

const THEME_MODES = ['dark', 'light', 'system'] as const;

/** Los tres modos; «Sistema» dice qué tema da ahora, para elegirlo sabiendo
 *  qué va a quedar. */
function useThemeOptions() {
  const t = useTexts();
  const light = useSystemLight();
  return THEME_MODES.map((m: ThemeMode) => ({ value: m, label: m === 'system' ? t.themeSystemNow(light) : t.themeModes[m] }));
}

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
  const { browserMode, setMode } = useTheme();
  const themeOptions = useThemeOptions();
  const [reset, setReset] = useState(false);
  const animationsOff = useAnimationsOff();
  // Con el sistema pidiendo menos movimiento ya están apagadas: el interruptor
  // lo muestra y no se puede prender desde acá.
  const systemOff = systemReducesMotion();
  const [legacy, setLegacy] = useState(() => document.cookie.split(';').some((c) => c.trim() === `${LEGACY_COOKIE}=1`));
  return (
    <Card id="settings-browser" title={t.settingsBrowserTitle} icon={Palette}>
      <div className="flex flex-col items-start gap-3">
        <Select
          label={t.themeLabel}
          value={browserMode ?? 'account'}
          onValueChange={(v) => setMode(isThemeMode(v) ? v : null)}
          options={[
            { value: 'account', label: t.settingsUseAccountTheme },
            ...themeOptions,
          ]}
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
        {/* Las animaciones, de este navegador como el tema: apagarlas deja
            cada cambio de golpe, como con «reducir movimiento» del sistema. */}
        <div className="flex flex-col gap-1">
          <Switch
            id="settings-animations"
            label={t.settingsAnimations}
            checked={!animationsOff && !systemOff}
            disabled={systemOff}
            onCheckedChange={(on) => setAnimationsOff(!on)}
          />
          {systemOff && <p className="text-[12.5px] text-text-muted">{t.settingsAnimationsSystem}</p>}
        </div>
        {/* Lo visto es de este navegador, como el tema y el idioma. */}
        <div className="mt-1 flex w-full flex-wrap items-center justify-between gap-3 border-t border-hairline pt-3" data-field="tutorials">
          <span className="text-[14px] text-on-surface">{t.settingsTutorials}</span>
          <Button
            tone="secondary"
            onClick={() => {
              resetTutorials();
              setReset(true);
            }}
          >
            {t.settingsTutorialsReset}
          </Button>
        </div>
        {/* Siempre montado: un `role` que aparece junto con su texto no siempre
            se anuncia. */}
        <p role="status" className="text-[13px] text-verdant empty:hidden">
          {reset && <span className="step-in inline-block">{t.settingsTutorialsResetDone}</span>}
        </p>
        {/* La cookie la lee el servidor al servir `/`: por eso no es localStorage. */}
        <Switch
          id="settings-legacy-version"
          label={t.settingsLegacyVersion}
          checked={legacy}
          onCheckedChange={(on) => {
            document.cookie = on
              ? `${LEGACY_COOKIE}=1; Path=/; SameSite=Lax; Max-Age=31536000`
              : `${LEGACY_COOKIE}=; Path=/; SameSite=Lax; Max-Age=0`;
            setLegacy(on);
          }}
        />
        {legacy && (
          <div role="status" className="step-in flex flex-col gap-2.5" data-field="legacy-version">
            <p className="text-[13px] leading-normal text-text-muted">{t.settingsLegacyNotice}</p>
            <div>
              <Button tone="secondary" onClick={() => window.location.assign('/')}>
                {t.settingsLegacyGo}
              </Button>
            </div>
          </div>
        )}
      </div>
    </Card>
  );
}

function AccountCard({ settings }: { settings: RosterSettings }) {
  const t = useTexts();
  const client = useQueryClient();
  const themeOptions = useThemeOptions();
  // Lo elegido se ve al instante y se guarda después; si falla, vuelve lo que
  // había. Antes el `fieldset` se deshabilitaba mientras guardaba y el control
  // tocado perdía el foco. Solo se revierten las claves de este cambio: otro
  // guardado que llegó en el medio no se pisa.
  const save = useMutation({
    mutationFn: (patch: Pick<Partial<RosterSettings>, 'startsInDmMode' | 'themeMode' | 'showEncounterDifficulty'>) => patchSettings(patch),
    onMutate: async (patch) => {
      await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
      const before = client.getQueryData<RosterSettings>(queryKeys.rosterSettings);
      client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (current) => current && { ...current, ...patch });
      return before && (Object.fromEntries(Object.keys(patch).map((k) => [k, before[k as keyof RosterSettings]])) as Partial<RosterSettings>);
    },
    onError: (_, __, undo) => {
      if (undo) client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (current) => current && { ...current, ...undo });
    },
  });
  // «Guardado» se va solo; el error queda hasta el próximo cambio.
  const { isSuccess, submittedAt, reset } = save;
  useEffect(() => {
    if (!isSuccess) return;
    const timer = window.setTimeout(reset, 3000);
    return () => window.clearTimeout(timer);
  }, [isSuccess, submittedAt, reset]);
  // El favorito se guarda por id: para nombrarlo hace falta la lista. Si
  // todavía no llegó (o falla), la fila dice «Ninguno» antes que un id crudo.
  const roster = useRoster();
  const name = roster.data?.find((c) => c.character.id === settings.favoriteCharacterId)?.character.name;
  const favorite = typeof name === 'string' ? name : undefined;
  const rows: [string, string, string][] = [
    ['sort', t.sortLabel, t.sortModes[parseSortMode(settings.sortMode)]],
    ['favorite', t.favorite, favorite ?? t.settingsNoFavorite],
  ];
  return (
    <Card id="settings-account" title={t.settingsAccountTitle} icon={Globe}>
      <fieldset className="flex min-w-0 flex-col items-start gap-3">
        <Select
          label={t.settingsStartMode}
          value={settings.startsInDmMode ? 'dm' : 'player'}
          onValueChange={(value) => save.mutate({ startsInDmMode: value === 'dm' })}
          options={(['player', 'dm'] as const).map((m) => ({ value: m, label: t.settingsStartModes[m] }))}
        />
        <Select
          label={t.settingsAccountTheme}
          value={isThemeMode(settings.themeMode) ? settings.themeMode : 'dark'}
          onValueChange={(themeMode) => save.mutate({ themeMode })}
          options={themeOptions}
        />
        <Switch
          id="settings-encounter-difficulty"
          label={t.settingsShowEncounterDifficulty}
          checked={settings.showEncounterDifficulty}
          onCheckedChange={(showEncounterDifficulty) => save.mutate({ showEncounterDifficulty })}
        />
      </fieldset>
      {/* Una línea con su lugar reservado: el aviso no empuja lo de abajo. Las
          dos regiones están siempre montadas para que se anuncien. */}
      <div className="mt-2 min-h-5 text-[13px]">
        <p role="status">
          {save.isPending && <span className="step-in inline-block text-text-muted">{t.settingsSaving}</span>}
          {save.isSuccess && <span className="step-in inline-block text-verdant">{t.settingsSaved}</span>}
        </p>
        <p role="alert">{save.isError && <span className="step-in inline-block text-crimson">{t.settingsSaveError}</span>}</p>
      </div>
      <dl className="mt-3 flex flex-col">
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
    </Card>
  );
}
