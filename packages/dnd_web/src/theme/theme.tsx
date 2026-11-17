import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from 'react';

/** Los tres modos de `ThemeMode` en Flutter (`AppSettings.themeMode`). */
export type ThemeMode = 'dark' | 'light' | 'system';

// La misma clave la lee el script de `index.html` antes del primer cuadro: si
// cambia acá, cambia allá.
const STORAGE_KEY = 'milantus.v2.theme';

export const isThemeMode = (v: unknown): v is ThemeMode =>
  v === 'dark' || v === 'light' || v === 'system';

/** El modo que eligió este navegador, o `null`. El almacenamiento bloqueado
 *  (modo privado, sitio sin permisos) equivale a «no eligió». */
function readStored(): ThemeMode | null {
  try {
    const v = window.localStorage.getItem(STORAGE_KEY);
    return isThemeMode(v) ? v : null;
  } catch {
    return null;
  }
}

function writeStored(mode: ThemeMode | null) {
  try {
    if (mode === null) window.localStorage.removeItem(STORAGE_KEY);
    else window.localStorage.setItem(STORAGE_KEY, mode);
  } catch {
    // Sin almacenamiento el tema dura lo que la pestaña: no es un error.
  }
}

const LIGHT_QUERY = '(prefers-color-scheme: light)';
const prefersLight = () => window.matchMedia(LIGHT_QUERY).matches;

/** Si el sistema pide tema claro, en vivo: «Sistema» dice qué tema da ahora. */
export function useSystemLight(): boolean {
  return useSyncExternalStore((onChange) => {
    const query = window.matchMedia(LIGHT_QUERY);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, prefersLight);
}

/** Pone el tema; con [fade], fundiendo la pantalla entera (`.page-fade` en
 *  `index.css`) en vez de cambiar los colores de golpe. Si el tema que queda
 *  es el mismo (oscuro → sistema oscuro), no hay nada que fundir. */
function apply(mode: ThemeMode, fade = false) {
  const theme = mode === 'light' || (mode === 'system' && prefersLight()) ? 'light' : 'dark';
  const root = document.documentElement;
  if (root.dataset.theme === theme) return;
  const set = () => {
    root.dataset.theme = theme;
  };
  if (!fade || !document.startViewTransition || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    set();
    return;
  }
  root.classList.add('page-fade');
  void document.startViewTransition(set).finished.finally(() => root.classList.remove('page-fade'));
}

interface ThemeState {
  mode: ThemeMode;
  browserMode: ThemeMode | null;
  /** Elige el modo y lo recuerda en este navegador. */
  setMode: (mode: ThemeMode | null) => void;
  /** El de la cuenta (`/api/settings`), si este navegador no eligió uno. */
  adoptAccountMode: (mode: string) => void;
}

const ThemeContext = createContext<ThemeState | null>(null);

/**
 * El tema arranca oscuro. Precedencia: lo elegido en este navegador; si no hay
 * nada, el de los ajustes de la cuenta (lo que Flutter guarda); si tampoco,
 * oscuro. La preferencia local se puede quitar desde Ajustes.
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [stored, setStored] = useState<ThemeMode | null>(readStored);
  const [account, setAccount] = useState<ThemeMode | null>(null);
  const mode: ThemeMode = stored ?? account ?? 'dark';

  // Al cargar, el tema ya lo puso el script de `index.html`: el fundido es
  // solo para los cambios de después.
  const loaded = useRef(false);
  useEffect(() => {
    apply(mode, loaded.current);
    loaded.current = true;
    if (mode !== 'system') return;
    // «Sistema» sigue al sistema también en vivo, no solo al cargar.
    const query = window.matchMedia(LIGHT_QUERY);
    const onChange = () => apply('system', true);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, [mode]);

  const setMode = useCallback((next: ThemeMode | null) => {
    writeStored(next);
    setStored(next);
  }, []);
  const adoptAccountMode = useCallback((value: string) => {
    setAccount(isThemeMode(value) ? value : null);
  }, []);

  const value = useMemo(
    () => ({ mode, browserMode: stored, setMode, adoptAccountMode }),
    [mode, stored, setMode, adoptAccountMode],
  );
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeState {
  const state = useContext(ThemeContext);
  if (!state) throw new Error('useTheme fuera de ThemeProvider');
  return state;
}
