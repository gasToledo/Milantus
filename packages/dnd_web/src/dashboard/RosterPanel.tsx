import { BookOpen, FlaskConical, LogOut, MessageSquare, Settings, Users } from 'lucide-react';
import { useAppVersion } from '../api/queries';
import type { Account } from '../api/client';
import { useTexts } from '../i18n/context';
import { codexHref, FLUTTER_HOME, rosterHref, settingsHref } from '../router';
import { ModeSwitch, NavGroup, NavItem, ThemeMenu, VersionLabel } from '../ui/Shell';

/**
 * El menú principal del Modo Jugador (`AppSidebar`): interruptor de modo y la
 * navegación. Lo que React todavía no tiene (Homebrew, el Modo DM) sigue en
 * Flutter.
 */
export function RosterPanel({ current }: { current?: 'roster' }) {
  const t = useTexts();
  return (
    <>
      <ModeSwitch dmHref={FLUTTER_HOME} />
      <NavGroup label={t.navLabel}>
        <li>
          <NavItem href={rosterHref()} icon={Users} label={t.navCharacters} active={current === 'roster'} internal />
        </li>
        <li>
          <NavItem href={codexHref()} icon={BookOpen} label={t.navCodex} internal />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={FlaskConical} label={t.navHomebrew} external />
        </li>
      </NavGroup>
    </>
  );
}

/**
 * El pie del menú principal: Ajustes (de solo lectura en React), sugerencias, la cuenta con «Cerrar
 * sesión», el tema y la versión. No se rediseña por pantalla: quien entra
 * tiene que poder salir de su cuenta sin buscar.
 */
export function RosterFooter({ account, current }: { account: Account; current?: 'settings' }) {
  const t = useTexts();
  const version = useAppVersion(true);
  return (
    <div className="flex flex-col gap-1">
      <ul className="flex flex-col gap-0.5">
        <li>
          <NavItem href={settingsHref()} icon={Settings} label={t.settings} active={current === 'settings'} internal />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={MessageSquare} label={t.feedback} external />
        </li>
      </ul>
      {(account.name || account.email) && (
        <div className="mt-1 px-3">
          {account.name && <p className="truncate text-[13px] text-on-surface">{account.name}</p>}
          {account.email && <p className="truncate text-[11px] text-on-surface-variant">{account.email}</p>}
        </div>
      )}
      {/* Cerrar la sesión es un POST a `/auth/logout`, y React no escribe
          nada todavía: el botón de Flutter lo hace. */}
      <a
        href={FLUTTER_HOME}
        className="mt-1.5 flex min-h-9 items-center justify-center gap-2 rounded-[var(--radius-nav)] border border-crimson px-3 py-1.5 text-[12px] text-crimson hover:bg-plaque"
      >
        <LogOut size={14} aria-hidden="true" />
        {t.signOut}
      </a>
      <div className="mt-2 flex items-center justify-between gap-2">
        <ThemeMenu />
        <VersionLabel version={version.data} />
      </div>
    </div>
  );
}
