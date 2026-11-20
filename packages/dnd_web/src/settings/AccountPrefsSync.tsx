import { useEffect } from 'react';
import { useRosterSettings } from '../api/queries';
import { useLang } from '../i18n/context';
import { storeLang } from '../i18n/texts';
import { useTheme } from '../theme/theme';
import { setAnimationsOff } from '../ui/motion';
import { adoptSeen } from '../ui/tutorials';

/**
 * Lleva a este navegador lo que dice la cuenta: tema, idioma, animaciones,
 * y tutoriales vistos. No dibuja nada.
 *
 * **No escribe nada en la cuenta, ni al cargar ni después.** Una clave `null`
 * es «la cuenta todavía no la guardó»: en ese caso rige lo que tenga este
 * navegador y no se toca. Recién se guarda cuando alguien la cambia en Ajustes
 * (o cierra un tutorial). Así abrir una pantalla no produce escrituras, y una
 * cuenta que nunca tocó un ajuste no pisa lo que este navegador ya tenía.
 *
 * Lo local (`localStorage`) es la copia de lo que dice la cuenta: el primer
 * cuadro sale bien antes de que lleguen los ajustes.
 */
export function AccountPrefsSync() {
  const settings = useRosterSettings().data;
  const { adoptAccountMode } = useTheme();
  const lang = useLang();

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

  return null;
}
