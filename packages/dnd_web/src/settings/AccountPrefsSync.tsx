import { useEffect } from 'react';
import { useRosterSettings } from '../api/queries';
import { useLang } from '../i18n/context';
import { storeLang } from '../i18n/texts';
import { useRoute } from '../router';
import { useTheme } from '../theme/theme';
import { setAnimationsOff } from '../ui/motion';
import { adoptSeen } from '../ui/tutorials';

const LEGACY_COOKIE = 'milantus_v1';

/**
 * Lleva a este navegador lo que dice la cuenta: tema, idioma, animaciones,
 * tutoriales vistos y versión anterior. No dibuja nada.
 *
 * **No escribe nada en la cuenta, ni al cargar ni después.** Una clave `null`
 * es «la cuenta todavía no la guardó»: en ese caso rige lo que tenga este
 * navegador y no se toca. Recién se guarda cuando alguien la cambia en Ajustes
 * (o cierra un tutorial). Así abrir una pantalla no produce escrituras, y una
 * cuenta que nunca tocó un ajuste no pisa lo que este navegador ya tenía.
 *
 * Lo local (`localStorage`, la cookie) es la copia de lo que dice la cuenta: el
 * primer cuadro sale bien antes de que lleguen los ajustes y el servidor sabe
 * servir la versión anterior en `/`.
 */
export function AccountPrefsSync() {
  const settings = useRosterSettings().data;
  const { adoptAccountMode } = useTheme();
  const lang = useLang();
  const { route } = useRoute();
  const onSettings = route.name === 'settings';

  const themeMode = settings?.themeMode ?? null;
  useEffect(() => {
    if (themeMode !== null) adoptAccountMode(themeMode);
  }, [themeMode, adoptAccountMode]);

  const language = settings?.language ?? null;
  useEffect(() => {
    // `storeLang` devuelve `false` sin almacenamiento: sin copia no hay
    // recarga que cambie nada, y recargar sería un bucle.
    if (language !== null && language !== lang && storeLang(language)) window.location.reload();
  }, [language, lang]);

  const animationsOff = settings?.animationsOff ?? null;
  useEffect(() => {
    if (animationsOff !== null) setAnimationsOff(animationsOff);
  }, [animationsOff]);

  // Por contenido y no por identidad: un refetch trae otra lista igual.
  const seenKey = settings?.tutorialsSeen?.join(',');
  useEffect(() => {
    if (seenKey !== undefined) adoptSeen(seenKey.split(',').filter(Boolean));
  }, [seenKey]);

  const legacy = settings?.legacyVersion;
  useEffect(() => {
    if (legacy === undefined) return;
    if (!legacy) {
      document.cookie = `${LEGACY_COOKIE}=; Path=/; SameSite=Lax; Max-Age=0`;
      return;
    }
    document.cookie = `${LEGACY_COOKIE}=1; Path=/; SameSite=Lax; Max-Age=31536000`;
    // En Ajustes no redirige: si no, no habría desde dónde apagarla.
    if (!onSettings) window.location.assign('/');
  }, [legacy, onSettings]);

  return null;
}
