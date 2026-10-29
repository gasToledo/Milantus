import { useEffect, useState, type ReactNode } from 'react';
import { fetchAppVersion, type Account } from '../api/client';
import { useTexts } from '../i18n/context';
import { FLUTTER_HOME, rosterHref } from '../router';
import { Seal } from './Seal';

/** Qué entrada del panel está activa: la lista, o una ficha abierta (que se
 *  muestra como entrada propia, debajo de «Personajes»). */
export type NavCurrent = 'roster' | 'sheet';

const NAV_ITEM =
  'block rounded-[var(--radius-nav)] px-3 py-2 text-[14px] text-on-surface-variant hover:bg-plaque';
const NAV_ACTIVE =
  'block rounded-[var(--radius-nav)] bg-gold-soft px-3 py-2 text-[14px] font-semibold text-gold';

/**
 * Panel lateral de 236 px con el sello, y el contenido a la derecha. En
 * ancho de teléfono el panel pasa a ser una barra de arriba con un botón de
 * menú y todo se apila: la maqueta no tiene scroll horizontal en ningún ancho.
 *
 * Sin [account] (sin sesión, no disponible, cargando) el panel es solo la
 * marca: ni siquiera un enlace delata qué hay detrás de un «No disponible».
 */
export function Shell({
  children,
  account,
  current,
}: {
  children: ReactNode;
  account?: Account;
  current?: NavCurrent;
}) {
  const t = useTexts();
  const [menuOpen, setMenuOpen] = useState(false);
  const [version, setVersion] = useState<string | null>(null);

  useEffect(() => {
    if (!account) return;
    const controller = new AbortController();
    fetchAppVersion(controller.signal).then((v) => {
      if (!controller.signal.aborted) setVersion(v);
    });
    return () => controller.abort();
  }, [account]);

  return (
    <div className="min-h-screen md:grid md:grid-cols-[var(--sidebar-width)_1fr]">
      <a
        href="#contenido"
        className="sr-only focus:not-sr-only focus:absolute focus:z-10 focus:bg-surface focus:p-2 focus:text-gold"
      >
        {t.skipToContent}
      </a>
      <aside className="flex flex-col border-b border-hairline bg-surface md:sticky md:top-0 md:h-screen md:border-r md:border-b-0">
        <div className="flex items-center gap-3 p-4">
          <Seal />
          <div className="min-w-0 flex-1">
            <p className="font-display text-[18px] leading-tight text-on-surface">
              {t.appName}
            </p>
            <p className="text-[11px] tracking-[0.3px] text-gold">{t.appTagline}</p>
          </div>
          {account && (
            <button
              type="button"
              aria-expanded={menuOpen}
              aria-controls="panel-menu"
              onClick={() => setMenuOpen((open) => !open)}
              className="rounded-[var(--radius-nav)] border border-hairline px-3 py-1.5 text-[13px] text-on-surface md:hidden"
            >
              {t.menu}
            </button>
          )}
        </div>
        {account && (
          // En teléfono el menú se despliega con el botón; desde `md` siempre
          // está a la vista.
          <div
            id="panel-menu"
            className={`${menuOpen ? 'flex' : 'hidden'} min-h-0 flex-1 flex-col px-3 pb-3 md:flex`}
          >
            <ModeSwitch />
            <nav aria-label={t.navLabel} className="mt-3 flex-1 overflow-y-auto">
              <ul className="flex flex-col gap-1">
                <li>
                  <a
                    href={rosterHref()}
                    aria-current={current === 'roster' ? 'page' : undefined}
                    className={current === 'roster' ? NAV_ACTIVE : NAV_ITEM}
                  >
                    {t.navCharacters}
                  </a>
                </li>
                {current === 'sheet' && (
                  <li>
                    <span aria-current="page" className={NAV_ACTIVE}>
                      {t.navSheet}
                    </span>
                  </li>
                )}
                {/* Lo que React todavía no tiene sigue en Flutter. */}
                <li>
                  <a href={FLUTTER_HOME} className={NAV_ITEM}>
                    {t.navCodex}
                  </a>
                </li>
                <li>
                  <a href={FLUTTER_HOME} className={NAV_ITEM}>
                    {t.navHomebrew}
                  </a>
                </li>
              </ul>
            </nav>
            <div className="mt-3 border-t border-hairline pt-2">
              <a href={FLUTTER_HOME} className={NAV_ITEM}>
                {t.settings}
              </a>
              <a href={FLUTTER_HOME} className={NAV_ITEM}>
                {t.feedback}
              </a>
              {account.name && (
                <p className="mt-1 truncate px-2 text-[13px] text-on-surface">{account.name}</p>
              )}
              {account.email && (
                <p className="truncate px-2 text-[11px] text-on-surface-variant">{account.email}</p>
              )}
              {/* Cerrar la sesión es un POST a `/auth/logout`, y React no
                  escribe nada todavía: el botón de Flutter lo hace. */}
              <a
                href={FLUTTER_HOME}
                className="mt-2 block rounded-[var(--radius-nav)] border border-crimson px-3 py-1.5 text-center text-[12px] text-crimson"
              >
                {t.signOut}
              </a>
              {version && (
                <p className="mt-2.5 text-center text-[11px] tracking-[0.3px] text-gold">
                  v{version}
                </p>
              )}
            </div>
          </div>
        )}
      </aside>
      <main id="contenido" className="min-w-0 p-4 md:p-6">
        <div className="mx-auto max-w-[1200px]">{children}</div>
      </main>
    </div>
  );
}

/** «Jugador / DM». Solo muestra el estado: el Modo DM no existe en React, así
 *  que «DM» lleva de vuelta a Flutter, donde sí. */
function ModeSwitch() {
  const t = useTexts();
  return (
    <div
      role="group"
      aria-label={t.modeSwitchLabel}
      className="plaque grid grid-cols-2 gap-1 rounded-[var(--radius-nav)] p-1 text-center text-[13px]"
    >
      <span
        aria-current="true"
        className="rounded-[var(--radius-nav)] bg-gold-soft py-1.5 font-semibold text-gold"
      >
        {t.modePlayer}
      </span>
      <a
        href={FLUTTER_HOME}
        className="rounded-[var(--radius-nav)] py-1.5 text-on-surface-variant hover:bg-surface"
      >
        {t.modeDm}
      </a>
    </div>
  );
}

/** Estados de pantalla completa (sin sesión, no disponible, error…): sobrios,
 *  un título, una línea y, si hace falta, una acción real. */
export function Notice({
  title,
  body,
  action,
}: {
  title: string;
  body?: string;
  action?: ReactNode;
}) {
  return (
    <section className="card p-6" role="status">
      <h1 className="font-display text-[20px] text-on-surface">{title}</h1>
      {body && <p className="mt-2 text-on-surface-variant">{body}</p>}
      {action && <div className="mt-4">{action}</div>}
    </section>
  );
}

export function ActionLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a
      href={href}
      className="inline-block rounded-[var(--radius-nav)] bg-gold px-4 py-2 text-[14px] font-semibold text-on-primary"
    >
      {children}
    </a>
  );
}

export function ActionButton({
  onClick,
  children,
}: {
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="rounded-[var(--radius-nav)] bg-gold px-4 py-2 text-[14px] font-semibold text-on-primary"
    >
      {children}
    </button>
  );
}
