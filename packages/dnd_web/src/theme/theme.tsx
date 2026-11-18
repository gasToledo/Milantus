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
import { prefersReducedMotion } from '../ui/motion';

/** Los tres modos de `ThemeMode` en Flutter (`AppSettings.themeMode`). */
export type ThemeMode = 'dark' | 'light' | 'system';

// La misma clave la lee el script de `index.html` antes del primer cuadro: si
// cambia acá, cambia allá.
const STORAGE_KEY = 'milantus.v2.theme';

export const isThemeMode = (v: unknown): v is ThemeMode =>
  v === 'dark' || v === 'light' || v === 'system';

/** La copia local del tema de la cuenta, o `null`. El almacenamiento
 *  bloqueado (modo privado, sitio sin permisos) equivale a «no hay copia». */
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
  if (!fade || !document.startViewTransition || prefersReducedMotion()) {
    set();
    return;
  }
  root.classList.add('page-fade');
  void document.startViewTransition(set).finished.finally(() => root.classList.remove('page-fade'));
}

interface ThemeState {
  mode: ThemeMode;
  /** Aplica el modo ya y lo copia en este navegador. Guardarlo en la cuenta es
   *  de quien lo llama (Ajustes y el menú del panel pasan por `useAccountSave`). */
  setMode: (mode: ThemeMode) => void;
  /** El de la cuenta (`/api/settings`): manda sobre la copia local. */
  adoptAccountMode: (mode: string) => void;
}

const ThemeContext = createContext<ThemeState | null>(null);

/**
 * El tema es el de la cuenta. Mientras no llegan los ajustes (y si la cuenta
 * todavía no lo guardó) rige la copia local que dejó la última vez, y si
 * tampoco hay, oscuro. La copia sirve para que el primer cuadro salga bien
 * (`index.html` la lee antes de que cargue React).
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [local] = useState<ThemeMode | null>(readStored);
  const [account, setAccount] = useState<ThemeMode | null>(null);
  const mode: ThemeMode = account ?? local ?? 'dark';

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

  const setMode = useCallback((next: ThemeMode) => {
    writeStored(next);
    setAccount(next);
  }, []);
  // Adoptar es lo mismo que elegir: aplica y deja la copia local al día.
  const adoptAccountMode = useCallback(
    (value: string) => {
      if (isThemeMode(value)) setMode(value);
    },
    [setMode],
  );

  const value = useMemo(() => ({ mode, setMode, adoptAccountMode }), [mode, setMode, adoptAccountMode]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeState {
  const state = useContext(ThemeContext);
  if (!state) throw new Error('useTheme fuera de ThemeProvider');
  return state;
}
