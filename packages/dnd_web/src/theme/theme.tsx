import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

/** Los tres modos de `ThemeMode` en Flutter (`AppSettings.themeMode`). */
export type ThemeMode = 'dark' | 'light' | 'system';

// La misma clave la lee el script de `index.html` antes del primer cuadro: si
// cambia acá, cambia allá.
const STORAGE_KEY = 'milantus.v2.theme';

const isThemeMode = (v: unknown): v is ThemeMode =>
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

function writeStored(mode: ThemeMode) {
  try {
    window.localStorage.setItem(STORAGE_KEY, mode);
  } catch {
    // Sin almacenamiento el tema dura lo que la pestaña: no es un error.
  }
}

const prefersLight = () => window.matchMedia('(prefers-color-scheme: light)').matches;

function apply(mode: ThemeMode) {
  const light = mode === 'light' || (mode === 'system' && prefersLight());
  document.documentElement.dataset.theme = light ? 'light' : 'dark';
}

interface ThemeState {
  mode: ThemeMode;
  /** Elige el modo y lo recuerda en este navegador. */
  setMode: (mode: ThemeMode) => void;
  /** El de la cuenta (`/api/settings`), si este navegador no eligió uno. */
  adoptAccountMode: (mode: string) => void;
}

const ThemeContext = createContext<ThemeState | null>(null);

/**
 * El tema arranca oscuro. Precedencia: lo elegido en este navegador; si no hay
 * nada, el de los ajustes de la cuenta (lo que Flutter guarda); si tampoco,
 * oscuro. El navegador gana porque el selector de /v2 no escribe en la cuenta
 * (React todavía no escribe nada) y una elección que se deshace sola en cada
 * recarga sería peor que no ofrecerla.
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [stored, setStored] = useState<ThemeMode | null>(readStored);
  const [account, setAccount] = useState<ThemeMode | null>(null);
  const mode: ThemeMode = stored ?? account ?? 'dark';

  useEffect(() => {
    apply(mode);
    if (mode !== 'system') return;
    // «Sistema» sigue al sistema también en vivo, no solo al cargar.
    const query = window.matchMedia('(prefers-color-scheme: light)');
    const onChange = () => apply('system');
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, [mode]);

  const setMode = useCallback((next: ThemeMode) => {
    writeStored(next);
    setStored(next);
  }, []);
  const adoptAccountMode = useCallback((value: string) => {
    setAccount(isThemeMode(value) ? value : null);
  }, []);

  const value = useMemo(() => ({ mode, setMode, adoptAccountMode }), [mode, setMode, adoptAccountMode]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeState {
  const state = useContext(ThemeContext);
  if (!state) throw new Error('useTheme fuera de ThemeProvider');
  return state;
}
