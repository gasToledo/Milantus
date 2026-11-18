import { Check, CircleHelp, Globe, History, Palette, Sword, Users, type LucideIcon } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import type { RosterSettings } from '../api/client';
import { useRoster, useRosterSettings } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { parseSortMode } from '../dashboard/roster';
import { useSystemLight, useTheme, type ThemeMode } from '../theme/theme';
import { useAccountSave, type AccountSave } from './useAccountSave';
import { Card } from '../ui/Card';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Switch } from '../ui/primitives';
import { AppBusyLabel, AppErrorView } from '../ui/status';
import { systemReducesMotion, useAnimationsOff } from '../ui/motion';

const THEME_MODES = ['dark', 'light', 'system'] as const;

const SAVE_PILL =
  'step-in inline-flex h-[26px] items-center gap-1.5 rounded-[var(--radius-pill)] border border-hairline bg-plaque px-[11px] text-[12.5px]';

export function SettingsPage() {
  const t = useTexts();
  const settings = useRosterSettings();
  const save = useAccountSave();
  // Lo que depende de la cuenta se resuelve acá: con los ajustes caídos o
  // cargando, el aviso ocupa el lugar de esas tarjetas. Ayuda y Versión
  // anterior se dibujan igual (la segunda apaga su interruptor hasta que llegan).
  const withAccount = (render: (s: RosterSettings) => ReactNode) =>
    settings.isError ? (
      <AppErrorView title={t.settingsLoadError} message={t.errorBody} onRetry={() => settings.refetch()} />
    ) : settings.data ? (
      render(settings.data)
    ) : (
      <AppBusyLabel label={t.settingsLoading} />
    );
  return (
    <div className="flex flex-col gap-4">
      <header className="flex min-h-11 items-center justify-between gap-4">
        <h1 data-page-title tabIndex={-1} className="font-display text-[30px] leading-tight text-on-surface outline-none">{t.settings}</h1>
        {/* Lugar reservado de 26 px: el aviso no mueve nada. Las dos regiones
            están siempre montadas para que se anuncien. */}
        <div className="flex min-h-[26px] shrink-0 items-center">
          <p role="status">
            {save.isPending && <span className={cx(SAVE_PILL, 'text-text-muted')}>{t.settingsSaving}</span>}
            {save.isSuccess && (
              <span className={cx(SAVE_PILL, 'text-verdant')}>
                <Check size={13} strokeWidth={3} aria-hidden="true" />
                {t.settingsSavedAccount}
              </span>
            )}
          </p>
          <p role="alert">{save.isError && <span className={cx(SAVE_PILL, 'text-crimson')}>{t.settingsSaveError}</span>}</p>
        </div>
      </header>
      <div className="@container">
        <div className="grid items-start gap-4 @[880px]:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
          <div className="flex min-w-0 flex-col gap-4">
            {withAccount((s) => (
              <>
                <LookCard save={save} />
                <StartCard settings={s} save={save} />
              </>
            ))}
          </div>
          <div className="flex min-w-0 flex-col gap-4">
            {withAccount((s) => (
              <>
                <DmCard settings={s} save={save} />
                <ListCard settings={s} />
              </>
            ))}
            <HelpCard save={save} />
            <LegacyCard save={save} />
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Piezas locales ─────────────────────────────────────────────────────────

type Layout = 'inline' | 'wide' | 'stack';

// Cada tarjeta es un `@container`: la fila se acomoda al ancho de su tarjeta
// (que depende del panel y de las columnas), no al de la ventana.
const ROW_LAYOUT: Record<Layout, string> = {
  inline: 'flex items-center justify-between gap-4',
  wide: 'flex flex-col gap-2.5 @[420px]:flex-row @[420px]:items-center @[420px]:justify-between @[420px]:gap-4',
  stack: 'flex flex-col gap-3',
};
const CONTROL_LAYOUT: Record<Layout, string> = {
  inline: 'shrink-0',
  wide: 'w-full @[420px]:w-auto @[420px]:shrink-0',
  stack: 'w-full',
};

/** Una fila de ajustes: el rótulo, la etiqueta de dónde se guarda y el control.
 *  [note] va debajo, dentro de la misma fila. */
function SettingRow({
  label,
  labelId,
  layout,
  dataField,
  note,
  children,
}: {
  label: string;
  labelId: string;
  layout: Layout;
  dataField?: string;
  note?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="border-t border-hairline py-3.5" data-field={dataField}>
      <div className={ROW_LAYOUT[layout]}>
        <span id={labelId} className="min-w-0 text-[14px] text-on-surface">{label}</span>
        <div className={CONTROL_LAYOUT[layout]}>{children}</div>
      </div>
      {note}
    </div>
  );
}

/** La tarjeta de una sección: `Card` con su ícono y `@container` para sus filas. */
function Section({ id, title, icon, children }: { id: string; title: string; icon: LucideIcon; children: ReactNode }) {
  return (
    <Card id={id} title={title} icon={icon} className="@container">
      {children}
    </Card>
  );
}

const FOCUS_RING = 'has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-gold';

/** Un tema dibujado en miniatura: fondo, barra, placa y rombo. Los colores
 *  salen de las utilidades de siempre; `data-theme-preview` (`index.css`) les
 *  cambia el tema solo a este elemento. */
function ThemeMini({ theme, className }: { theme: 'dark' | 'light'; className?: string }) {
  return (
    <span data-theme-preview={theme} className={cx('absolute inset-0 bg-scaffold', className)}>
      <span className="absolute top-2.5 right-2.5 left-2.5 h-[18px] rounded-[var(--radius-mark)] border border-hairline bg-surface" />
      <span className="absolute top-[34px] left-2.5 h-[18px] w-[42%] rounded-[var(--radius-mark)] border border-hairline bg-plaque" />
      <span className="absolute top-[38px] right-3 h-2.5 w-2.5 rotate-45 rounded-[2px] bg-gold" />
    </span>
  );
}

/** El círculo de radio de `Option` (`ui/wizard.tsx`). */
function RadioDot({ on }: { on: boolean }) {
  return (
    <span
      aria-hidden="true"
      className={cx('flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded-full border-[1.5px]', on ? 'border-gold' : 'border-text-muted')}
    >
      {on && <span className="h-2 w-2 rounded-full bg-gold" />}
    </span>
  );
}

/** El tema de la cuenta, a elegir mirándolo. Cada opción es un radio de
 *  verdad (flechas y foco gratis) con la tarjeta como su rótulo. */
function ThemeTiles({ value, onChange, labelledBy }: { value: ThemeMode; onChange: (m: ThemeMode) => void; labelledBy: string }) {
  const t = useTexts();
  const light = useSystemLight();
  return (
    <div role="radiogroup" aria-labelledby={labelledBy} className="grid grid-cols-3 gap-2.5">
      {THEME_MODES.map((m) => {
        const on = value === m;
        return (
          <label
            key={m}
            className={cx(
              'pick relative flex min-w-0 flex-col gap-2 rounded-[var(--radius-card)] border p-2',
              FOCUS_RING,
              // Con `!` para que el oro de lo elegido gane también al hover de `.pick`.
              on ? 'border-gold! bg-gold-soft!' : 'border-hairline bg-plaque',
            )}
          >
            <input type="radio" name="account-theme" value={m} checked={on} onChange={() => onChange(m)} className="sr-only" />
            <span aria-hidden="true" className="relative block h-16 overflow-hidden rounded-[var(--radius-nav)] border border-hairline">
              {m === 'system' ? (
                // Dos mitades, cada una con su tema, partidas en diagonal.
                <>
                  <ThemeMini theme="dark" className="[clip-path:polygon(0_0,100%_0,0_100%)]" />
                  <ThemeMini theme="light" className="[clip-path:polygon(100%_0,100%_100%,0_100%)]" />
                </>
              ) : (
                <ThemeMini theme={m} />
              )}
            </span>
            <span className="flex items-center justify-between gap-1.5 px-0.5 pb-0.5 text-[13px] text-on-surface">
              <span className="min-w-0">
                {t.themeModes[m]}
                {m === 'system' && <span className="ml-1 text-text-muted">{t.themeSystemNowShort(light)}</span>}
              </span>
              <RadioDot on={on} />
            </span>
          </label>
        );
      })}
    </div>
  );
}

/** Pocas opciones en una pastilla: radios de verdad, así las flechas del
 *  teclado andan solas. Angosto ocupa todo el ancho con las opciones repartidas. */
function SegmentedRadios<T extends string>({
  name,
  value,
  options,
  onChange,
  labelledBy,
}: {
  name: string;
  value: T;
  options: { value: T; label: string }[];
  onChange: (value: T) => void;
  labelledBy: string;
}) {
  return (
    <div
      role="radiogroup"
      aria-labelledby={labelledBy}
      className="flex w-full gap-1 rounded-[var(--radius-pill)] border border-hairline bg-plaque p-[3px] @[420px]:inline-flex @[420px]:w-auto"
    >
      {options.map((o) => {
        const on = o.value === value;
        return (
          <label
            key={o.value}
            className={cx(
              'relative flex min-h-[38px] flex-1 cursor-pointer items-center justify-center rounded-[var(--radius-pill)] px-3.5 text-[13px] transition-colors @[420px]:min-h-8 @[420px]:flex-none',
              FOCUS_RING,
              on ? 'bg-gold-soft font-medium text-gold' : 'text-on-surface-variant hover:text-on-surface',
            )}
          >
            <input type="radio" name={name} value={o.value} checked={on} onChange={() => onChange(o.value)} className="sr-only" />
            {o.label}
          </label>
        );
      })}
    </div>
  );
}

// ── Las seis tarjetas ──────────────────────────────────────────────────────

function LookCard({ save }: { save: AccountSave }) {
  const t = useTexts();
  // El modo efectivo: el de la cuenta, o la copia local si todavía no lo guardó.
  const { mode } = useTheme();
  const animationsOff = useAnimationsOff();
  // Con el sistema pidiendo menos movimiento ya están apagadas: el interruptor
  // lo muestra y no se puede prender desde acá.
  const systemOff = systemReducesMotion();
  return (
    <Section id="settings-look" title={t.settingsSectionLook} icon={Palette}>
      <SettingRow label={t.themeLabel} labelId="settings-account-theme-label" layout="stack">
        <ThemeTiles
          value={mode}
          onChange={(themeMode) => save.mutate({ themeMode })}
          labelledBy="settings-account-theme-label"
        />
      </SettingRow>
      {/* Apagarlas deja cada cambio de golpe, como con «reducir movimiento»
          del sistema. */}
      <SettingRow
        label={t.settingsAnimations}
        labelId="settings-animations-label"
        layout="inline"
        note={systemOff && <p className="mt-2 text-[12.5px] text-text-muted">{t.settingsAnimationsSystem}</p>}
      >
        <Switch
          id="settings-animations"
          label={t.settingsAnimations}
          labelledBy="settings-animations-label"
          checked={!animationsOff && !systemOff}
          disabled={systemOff}
          onCheckedChange={(on) => save.mutate({ animationsOff: !on })}
        />
      </SettingRow>
    </Section>
  );
}

function StartCard({ settings, save }: { settings: RosterSettings; save: AccountSave }) {
  const t = useTexts();
  const lang = useLang();
  return (
    <Section id="settings-start" title={t.settingsSectionStart} icon={Globe}>
      <SettingRow label={t.settingsLanguage} labelId="settings-language-label" layout="wide">
        <SegmentedRadios
          name="language"
          labelledBy="settings-language-label"
          value={lang}
          options={(['es', 'en'] as const).map((l) => ({ value: l, label: t.languageNames[l] }))}
          onChange={(next) => {
            // El idioma se resuelve una sola vez al cargar (también el del
            // motor): cambiarlo es guardarlo en la cuenta, y cuando el guardado
            // termina bien `AccountPrefsSync` lo copia y recarga.
            if (next !== lang) save.mutate({ language: next });
          }}
        />
      </SettingRow>
      <SettingRow label={t.settingsStartMode} labelId="settings-start-mode-label" layout="wide">
        <SegmentedRadios
          name="start-mode"
          labelledBy="settings-start-mode-label"
          value={settings.startsInDmMode ? 'dm' : 'player'}
          options={(['player', 'dm'] as const).map((m) => ({ value: m, label: t.settingsStartModes[m] }))}
          onChange={(m) => save.mutate({ startsInDmMode: m === 'dm' })}
        />
      </SettingRow>
    </Section>
  );
}

function DmCard({ settings, save }: { settings: RosterSettings; save: AccountSave }) {
  const t = useTexts();
  return (
    <Section id="settings-dm" title={t.settingsSectionDm} icon={Sword}>
      <SettingRow label={t.settingsShowEncounterDifficulty} labelId="settings-encounter-difficulty-label" layout="inline">
        <Switch
          id="settings-encounter-difficulty"
          label={t.settingsShowEncounterDifficulty}
          labelledBy="settings-encounter-difficulty-label"
          checked={settings.showEncounterDifficulty}
          onCheckedChange={(showEncounterDifficulty) => save.mutate({ showEncounterDifficulty })}
        />
      </SettingRow>
    </Section>
  );
}

function ListCard({ settings }: { settings: RosterSettings }) {
  const t = useTexts();
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
    <Section id="settings-list" title={t.settingsSectionRoster} icon={Users}>
      {/* Solo se muestran: se editan en Mis personajes, así que sin etiqueta de alcance. */}
      <dl>
        {rows.map(([field, label, value]) => (
          <div key={field} data-field={field} className="flex items-center justify-between gap-4 border-t border-hairline py-3.5">
            <dt className="text-[14px] text-on-surface">{label}</dt>
            <dd className="min-w-0 text-[14px] break-words text-on-surface-variant">{value}</dd>
          </div>
        ))}
      </dl>
    </Section>
  );
}

function HelpCard({ save }: { save: AccountSave }) {
  const t = useTexts();
  const [reset, setReset] = useState(false);
  return (
    <Section id="settings-help" title={t.settingsSectionHelp} icon={CircleHelp}>
      {/* Lo visto es de la cuenta: vaciar la lista hace que vuelvan a salir. */}
      <SettingRow
        label={t.settingsTutorials}
        labelId="settings-tutorials-label"
        layout="inline"
        dataField="tutorials"
        note={
          // Siempre montado: un `role` que aparece junto con su texto no
          // siempre se anuncia.
          <p role="status" className="mt-2 text-[13px] text-verdant empty:hidden">
            {reset && <span className="step-in inline-block">{t.settingsTutorialsResetDone}</span>}
          </p>
        }
      >
        <Button
          tone="secondary"
          onClick={() => {
            save.mutate({ tutorialsSeen: [] });
            setReset(true);
          }}
        >
          {t.settingsTutorialsReset}
        </Button>
      </SettingRow>
    </Section>
  );
}

function LegacyCard({ save }: { save: AccountSave }) {
  const t = useTexts();
  const settings = useRosterSettings().data;
  const legacy = settings?.legacyVersion === true;
  return (
    <Section id="settings-legacy" title={t.settingsSectionLegacy} icon={History}>
      <SettingRow
        label={t.settingsLegacyVersion}
        labelId="settings-legacy-version-label"
        layout="inline"
        note={
          legacy && (
            <div role="status" className="step-in mt-3 flex flex-col items-start gap-2.5" data-field="legacy-version">
              <p className="text-[13px] leading-normal text-text-muted">{t.settingsLegacyNotice}</p>
              <Button tone="secondary" onClick={() => window.location.assign('/')}>
                {t.settingsLegacyGo}
              </Button>
            </div>
          )
        }
      >
        {/* La cookie que lee el servidor al servir `/` la pone `AccountPrefsSync`
            cuando cambia lo que dice la cuenta. */}
        <Switch
          id="settings-legacy-version"
          label={t.settingsLegacyVersion}
          labelledBy="settings-legacy-version-label"
          checked={legacy}
          disabled={!settings}
          onCheckedChange={(on) => save.mutate({ legacyVersion: on })}
        />
      </SettingRow>
    </Section>
  );
}
