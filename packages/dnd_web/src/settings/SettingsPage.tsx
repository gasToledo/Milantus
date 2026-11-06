import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Globe, Palette } from 'lucide-react';
import type { RosterSettings } from '../api/client';
import { queryKeys, useRoster, useRosterSettings } from '../api/queries';
import { patchSettings } from '../api/settingsSave';
import { useLang, useTexts } from '../i18n/context';
import { storeLang, type Lang } from '../i18n/texts';
import { parseSortMode } from '../dashboard/roster';
import { isThemeMode, useTheme } from '../theme/theme';
import { Card } from '../ui/Card';
import { SectionRule } from '../ui/data';
import { Select, Switch } from '../ui/primitives';
import { AppBusyLabel, AppErrorView } from '../ui/status';

const THEME_MODES = ['dark', 'light', 'system'] as const;

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
  return (
    <Card id="settings-browser" title={t.settingsBrowserTitle} icon={Palette}>
      <div className="flex flex-col items-start gap-3">
        <Select
          label={t.themeLabel}
          value={browserMode ?? 'account'}
          onValueChange={(v) => setMode(isThemeMode(v) ? v : null)}
          options={[
            { value: 'account', label: t.settingsUseAccountTheme },
            ...THEME_MODES.map((m) => ({ value: m, label: t.themeModes[m] })),
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
      </div>
    </Card>
  );
}

function AccountCard({ settings }: { settings: RosterSettings }) {
  const t = useTexts();
  const client = useQueryClient();
  const save = useMutation({
    mutationFn: (patch: Pick<Partial<RosterSettings>, 'startsInDmMode' | 'themeMode' | 'showEncounterDifficulty'>) => patchSettings(patch),
    onSuccess: async (_, patch) => {
      await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
      client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (current) => current && { ...current, ...patch });
    },
  });
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
      <fieldset disabled={save.isPending} className="flex min-w-0 flex-col items-start gap-3">
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
          options={THEME_MODES.map((m) => ({ value: m, label: t.themeModes[m] }))}
        />
        <Switch
          id="settings-encounter-difficulty"
          label={t.settingsShowEncounterDifficulty}
          checked={settings.showEncounterDifficulty}
          onCheckedChange={(showEncounterDifficulty) => save.mutate({ showEncounterDifficulty })}
        />
      </fieldset>
      {save.isPending && <p role="status" className="mt-2 text-[13px] text-text-muted">{t.settingsSaving}</p>}
      {save.isSuccess && <p role="status" className="mt-2 text-[13px] text-verdant">{t.settingsSaved}</p>}
      {save.isError && <p role="alert" className="mt-2 text-[13px] text-crimson">{t.settingsSaveError}</p>}
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
