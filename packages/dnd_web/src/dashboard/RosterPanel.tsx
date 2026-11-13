import { useState } from 'react';
import { BookOpen, GraduationCap, LogOut, MessageSquare, Settings, Users } from 'lucide-react';
import { useAppVersion } from '../api/queries';
import { logout, type Account } from '../api/client';
import { useTexts } from '../i18n/context';
import { codexHref, dmHref, FLUTTER_HOME, quizHref, rosterHref, settingsHref } from '../router';
import { FeedbackDialog } from '../ui/feedback';
import { showNotice } from '../ui/notices';
import { ModeSwitch, NavGroup, NavItem, ThemeMenu, VersionLabel } from '../ui/Shell';

/**
 * El menú principal del Modo Jugador (`AppSidebar`): interruptor de modo y la
 * navegación. El Homebrew es herramienta del Modo DM y no está acá.
 */
export function RosterPanel({ current }: { current?: 'roster' | 'quiz' }) {
  const t = useTexts();
  return (
    <>
      <ModeSwitch mode="player" playerHref={rosterHref()} dmHref={dmHref()} />
      <NavGroup label={t.navLabel}>
        <li>
          <NavItem href={rosterHref()} icon={Users} label={t.navCharacters} active={current === 'roster'} internal />
        </li>
        <li>
          <NavItem href={quizHref()} icon={GraduationCap} label={t.navQuiz} active={current === 'quiz'} internal />
        </li>
        <li>
          <NavItem href={codexHref()} icon={BookOpen} label={t.navCodex} internal />
        </li>
      </NavGroup>
    </>
  );
}

/**
 * El pie del menú principal: Ajustes (de solo lectura en React), sugerencias, la cuenta con «Cerrar
 * sesión» (que cierra la del servidor y la del proveedor, como Flutter), el tema y la versión. No se rediseña por pantalla: quien entra
 * tiene que poder salir de su cuenta sin buscar.
 */
export function RosterFooter({ account, current, dm = false }: { account: Account; current?: 'settings'; dm?: boolean }) {
  const t = useTexts();
  const version = useAppVersion(true);
  const [reporting, setReporting] = useState(false);
  const [leaving, setLeaving] = useState(false);

  // Cierra la sesión del servidor y navega a donde este indique: ese destino es
  // el cierre de sesión del proveedor, y sin pasar por ahí su cookie sigue viva
  // y el próximo ingreso no pide contraseña. Sin destino, la raíz, que redirige
  // al login. Si falla se avisa: la página no cambia y, sin aviso, quien quiso
  // salir se queda creyendo que salió.
  const signOut = async () => {
    setLeaving(true);
    try {
      window.location.assign((await logout()) ?? FLUTTER_HOME);
    } catch {
      setLeaving(false);
      showNotice(t.signOutError, 'error');
    }
  };
  return (
    <div className="flex flex-col gap-1">
      <ul className="flex flex-col gap-0.5">
        <li>
          <NavItem href={settingsHref(dm)} icon={Settings} label={t.settings} active={current === 'settings'} internal />
        </li>
        <li>
          <NavItem icon={MessageSquare} label={t.feedback} onSelect={() => setReporting(true)} />
        </li>
      </ul>
      {(account.name || account.email) && (
        <div className="mt-1 px-3">
          {account.name && <p className="truncate text-[13px] text-on-surface">{account.name}</p>}
          {account.email && <p className="truncate text-[11px] text-on-surface-variant">{account.email}</p>}
        </div>
      )}
      <button
        type="button"
        disabled={leaving}
        onClick={() => void signOut()}
        className="mt-1.5 flex min-h-9 items-center justify-center gap-2 rounded-[var(--radius-nav)] border border-crimson px-3 py-1.5 text-[12px] text-crimson hover:bg-plaque disabled:pointer-events-none disabled:opacity-60"
      >
        <LogOut size={14} aria-hidden="true" />
        {leaving ? t.signOutBusy : t.signOut}
      </button>
      {reporting && <FeedbackDialog origin="dashboard" onClose={() => setReporting(false)} />}
      <div className="mt-2 flex items-center justify-between gap-2">
        <ThemeMenu />
        <VersionLabel version={version.data} />
      </div>
    </div>
  );
}
