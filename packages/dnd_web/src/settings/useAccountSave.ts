import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';
import type { RosterSettings } from '../api/client';
import { queryKeys } from '../api/queries';
import { patchSettings } from '../api/settingsSave';

/** Las claves que se cambian desde la interfaz (Ajustes y el menú de tema). */
export type AccountPatch = Pick<
  Partial<RosterSettings>,
  'startsInDmMode' | 'themeMode' | 'showEncounterDifficulty' | 'language' | 'animationsOff' | 'tutorialsSeen'
>;

/** El guardado de la cuenta: uno solo para toda la pantalla, porque las filas
 *  que escriben están repartidas en varias tarjetas y el aviso vive en el
 *  encabezado. */
export function useAccountSave() {
  const client = useQueryClient();
  // Lo elegido se ve al instante y se guarda después; si falla, vuelve lo que
  // había. Antes el `fieldset` se deshabilitaba mientras guardaba y el control
  // tocado perdía el foco. Solo se revierten las claves de este cambio: otro
  // guardado que llegó en el medio no se pisa. El tema, el idioma, las
  // animaciones y los tutoriales los sigue `AccountPrefsSync` desde la caché.
  const save = useMutation({
    mutationFn: (patch: AccountPatch) => patchSettings(patch),
    onMutate: async ({ language: _later, ...patch }) => {
      await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
      const before = client.getQueryData<RosterSettings>(queryKeys.rosterSettings);
      client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (current) => current && { ...current, ...patch });
      return before && (Object.fromEntries(Object.keys(patch).map((k) => [k, before[k as keyof RosterSettings]])) as Partial<RosterSettings>);
    },
    onError: (_, __, undo) => {
      if (undo) client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (current) => current && { ...current, ...undo });
    },
    // El idioma es la excepción al «se ve al instante»: cambiarlo recarga la
    // página, y recargar antes de que termine el guardado lo cortaría. Entra a
    // la caché recién cuando el servidor lo confirmó.
    onSuccess: (_, { language }) => {
      if (language !== undefined) client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (current) => current && { ...current, language });
    },
  });
  // «Guardado» se va solo; el error queda hasta el próximo cambio.
  const { isSuccess, submittedAt, reset } = save;
  useEffect(() => {
    if (!isSuccess) return;
    const timer = window.setTimeout(reset, 3000);
    return () => window.clearTimeout(timer);
  }, [isSuccess, submittedAt, reset]);
  return save;
}

export type AccountSave = ReturnType<typeof useAccountSave>;
