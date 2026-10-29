import { useEffect, useState, type ReactNode } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { ArrowLeft, Menu, Monitor, Moon, Sun, X, type LucideIcon } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { Link, useRoute } from '../router';
import { useTheme, type ThemeMode } from '../theme/theme';
import { cx } from './cx';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
  ScrollArea,
  Tooltip,
} from './primitives';
import { Seal } from './Seal';

/**
 * El marco de toda pantalla (`diseno-web.md` §7.1): panel lateral de 236 px
 * fijo desde 900 px y, debajo, una barra superior con un botón que abre el
 * **mismo** panel como cajón (Radix Dialog: foco atrapado, `Esc`, velo). El
 * contenido ocupa todo el ancho que queda, sin un máximo centrado: la ficha
 * tiene tres columnas y en un monitor ancho las necesita.
 *
 * [panel] es lo propio de cada pantalla (navegación, la tarjeta del personaje)
 * y [footer] su pie. Sin ninguno de los dos (sin sesión, no disponible) el
 * panel es solo la marca: ni un enlace delata qué hay detrás.
 */
export function Shell({
  panel,
  footer,
  children,
}: {
  panel?: ReactNode;
  footer?: ReactNode;
  children: ReactNode;
}) {
  const t = useTexts();
  const [open, setOpen] = useState(false);
  const { pathname } = useRoute();
  // Navegar desde el cajón lo cierra: el destino es lo que se quería ver.
  useEffect(() => setOpen(false), [pathname]);

  const hasPanel = panel !== undefined || footer !== undefined;
  const content = (
    <>
      <SidebarBrand />
      {panel !== undefined && (
        <ScrollArea className="flex-1">
          <div className="flex flex-col gap-3 px-3 pb-3">{panel}</div>
        </ScrollArea>
      )}
      {footer !== undefined && <div className="border-t border-hairline px-3 py-3">{footer}</div>}
    </>
  );

  return (
    <div className="min-h-screen shell:grid shell:grid-cols-[var(--sidebar-width)_minmax(0,1fr)]">
      <a
        href="#contenido"
        className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:rounded-[var(--radius-nav)] focus:bg-surface focus:p-2 focus:text-gold"
      >
        {t.skipToContent}
      </a>

      {/* Desde 900 px: el panel fijo, con su propio scroll si no entra. */}
      {/* La celda de la grilla pinta el fondo y el filete en todo el alto de
          la página; el panel de adentro queda pegado a la ventana. */}
      <div className="hidden border-r border-hairline bg-surface shell:block">
        <aside aria-label={t.panelLabel} className="sticky top-0 flex h-screen flex-col">
          {content}
        </aside>
      </div>

      {/* Debajo de 900 px: barra con la marca y el botón del cajón. */}
      <header className="sticky top-0 z-30 flex items-center gap-2 border-b border-hairline bg-surface pr-3 shell:hidden">
        <div className="min-w-0 flex-1">
          <SidebarBrand />
        </div>
        {hasPanel && (
          <Dialog.Root open={open} onOpenChange={setOpen}>
            <Tooltip content={t.menu}>
              <Dialog.Trigger asChild>
                <button
                  type="button"
                  aria-label={t.menu}
                  className="flex h-10 w-10 items-center justify-center rounded-[var(--radius-nav)] border border-hairline text-on-surface"
                >
                  <Menu size={20} aria-hidden="true" />
                </button>
              </Dialog.Trigger>
            </Tooltip>
            <Dialog.Portal>
              <Dialog.Overlay className="fixed inset-0 z-40 bg-scrim" />
              <Dialog.Content
                aria-describedby={undefined}
                className="drawer fixed inset-y-0 left-0 z-50 flex w-[var(--sidebar-width)] max-w-[85vw] flex-col border-r border-hairline bg-surface"
              >
                <Dialog.Title className="sr-only">{t.panelLabel}</Dialog.Title>
                <Dialog.Close asChild>
                  <button
                    type="button"
                    aria-label={t.closeMenu}
                    className="absolute top-3 right-2 flex h-9 w-9 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:bg-plaque"
                  >
                    <X size={18} aria-hidden="true" />
                  </button>
                </Dialog.Close>
                {content}
              </Dialog.Content>
            </Dialog.Portal>
          </Dialog.Root>
        )}
      </header>

      <main id="contenido" tabIndex={-1} className="min-w-0 px-4 py-4 shell:px-6 shell:py-6 min-[1400px]:px-8">
        {children}
      </main>
    </div>
  );
}

/** La marca en lo alto de todo panel: sello, nombre y subtítulo. */
function SidebarBrand() {
  const t = useTexts();
  return (
    <div className="flex items-center gap-3 p-4">
      <Seal />
      <div className="min-w-0">
        <p className="font-display truncate text-[18px] leading-tight text-on-surface">{t.appName}</p>
        <p className="truncate text-[11px] tracking-[0.3px] text-gold">{t.appTagline}</p>
      </div>
    </div>
  );
}

/**
 * Un ítem del panel (`appNavItem`): ícono, rótulo y, si hace falta, una cifra
 * al final. Activo: oro sobre `goldSoft` y `aria-current="page"`. Con
 * `internal` navega dentro de `/v2`; sin él es un enlace común (a Flutter).
 */
export function NavItem({
  href,
  icon: Icon,
  label,
  active = false,
  internal = false,
  external = false,
}: {
  href: string;
  icon: LucideIcon;
  label: string;
  active?: boolean;
  internal?: boolean;
  /** Lleva a Flutter: se marca para que no sorprenda el cambio de cliente. */
  external?: boolean;
}) {
  const t = useTexts();
  const className = cx(
    'flex min-h-9 items-center gap-2.5 rounded-[var(--radius-nav)] px-3 py-2 text-[14px]',
    active ? 'bg-gold-soft font-semibold text-gold' : 'text-on-surface-variant hover:bg-plaque hover:text-on-surface',
  );
  const body = (
    <>
      <Icon size={17} aria-hidden="true" className="shrink-0" />
      <span className="min-w-0 flex-1 truncate">{label}</span>
      {external && <span className="sr-only">{` (${t.opensFlutter})`}</span>}
    </>
  );
  return internal ? (
    <Link href={href} aria-current={active ? 'page' : undefined} className={className}>
      {body}
    </Link>
  ) : (
    <a href={href} aria-current={active ? 'page' : undefined} className={className}>
      {body}
    </a>
  );
}

/** Lista de ítems del panel con su rótulo (para el lector, un `nav` por
 *  grupo con nombre propio). */
export function NavGroup({ label, title, children }: { label: string; title?: string; children: ReactNode }) {
  return (
    <nav aria-label={label}>
      {title && <p className="eyebrow px-3 pt-1 pb-1.5">{title}</p>}
      <ul className="flex flex-col gap-0.5">{children}</ul>
    </nav>
  );
}

/** El «volver» de una pantalla de adentro (`SidebarBackButton`): ocupa el
 *  lugar y la forma del interruptor de modo, para que la salida esté siempre
 *  en el mismo sitio. */
export function SidebarBack({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="plaque flex min-h-9 items-center gap-2 rounded-[var(--radius-nav)] px-3 py-2 text-[13px] text-on-surface hover:text-gold"
    >
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {label}
    </Link>
  );
}

/**
 * «Jugador / DM». El Modo DM no existe en React, así que «DM» lleva de vuelta
 * a Flutter, donde sí; «Jugador» es el estado actual y no un botón.
 */
export function ModeSwitch({ dmHref }: { dmHref: string }) {
  const t = useTexts();
  return (
    <div
      role="group"
      aria-label={t.modeSwitchLabel}
      className="grid grid-cols-2 gap-1 rounded-[var(--radius-pill)] border border-hairline bg-plaque p-[3px] text-center text-[12px]"
    >
      <span aria-current="true" className="rounded-[var(--radius-pill)] bg-gold-soft py-1.5 font-medium text-gold">
        {t.modePlayer}
      </span>
      <a href={dmHref} className="rounded-[var(--radius-pill)] py-1.5 text-on-surface-variant hover:bg-surface hover:text-on-surface">
        {t.modeDm}
      </a>
    </div>
  );
}

const THEME_ICON: Record<ThemeMode, LucideIcon> = { dark: Moon, light: Sun, system: Monitor };

/**
 * El tema (oscuro, claro, sistema), recordado en este navegador. Botón de
 * ícono con su nombre accesible completo («Tema: Oscuro») y un menú de
 * opciones excluyentes.
 */
export function ThemeMenu() {
  const t = useTexts();
  const { mode, setMode } = useTheme();
  const Icon = THEME_ICON[mode];
  const label = `${t.themeLabel}: ${t.themeModes[mode]}`;
  return (
    <DropdownMenu>
      <Tooltip content={label}>
        <DropdownMenuTrigger asChild>
          <button
            type="button"
            aria-label={label}
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--radius-nav)] border border-hairline text-on-surface-variant hover:text-gold"
          >
            <Icon size={17} aria-hidden="true" />
          </button>
        </DropdownMenuTrigger>
      </Tooltip>
      <DropdownMenuContent align="start" side="top">
        <DropdownMenuLabel>{t.themeLabel}</DropdownMenuLabel>
        <DropdownMenuRadioGroup value={mode} onValueChange={(v) => setMode(v as ThemeMode)}>
          {(['dark', 'light', 'system'] as const).map((m) => {
            const ItemIcon = THEME_ICON[m];
            return (
              <DropdownMenuRadioItem key={m} value={m}>
                <ItemIcon size={16} aria-hidden="true" className="text-text-muted" />
                {t.themeModes[m]}
              </DropdownMenuRadioItem>
            );
          })}
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/** La versión del panel, en oro chico (como `SidebarLightFooter`). */
export function VersionLabel({ version }: { version: string | null | undefined }) {
  if (!version) return null;
  return <p className="text-[11px] tracking-[0.3px] text-gold tabular-nums">v{version}</p>;
}
