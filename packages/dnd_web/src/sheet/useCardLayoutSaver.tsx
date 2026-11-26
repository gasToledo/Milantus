import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { patchSettings } from '../api/settingsSave';
import { queryKeys } from '../api/queries';
import type { RosterSettings } from '../api/client';
import { useTexts } from '../i18n/context';
import { Toast } from '../ui/primitives';
import type { CardLayout } from './cardLayout';

/** Guarda el orden de las tarjetas de [tab] (null: el de fábrica). [toast] es
 *  el aviso de que no se pudo, para dibujar donde se use. */
export function useCardLayoutSaver(tab: 'combate' | 'personaje') {
  const t = useTexts();
  const client = useQueryClient();
  const [failed, setFailed] = useState<number | null>(null);

  // Cada movimiento se guarda en el momento. Siempre viaja el objeto entero
  // (las dos pestañas): el servidor combina solo el primer nivel de los ajustes.
  const save = async (next: CardLayout | null) => {
    await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
    const current = client.getQueryData<RosterSettings>(queryKeys.rosterSettings)?.sheetLayout ?? {};
    const sheetLayout = { combate: current.combate ?? null, personaje: current.personaje ?? null, [tab]: next };
    client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (old) => old && { ...old, sheetLayout });
    try {
      await patchSettings({ sheetLayout });
    } catch {
      // Vuelve lo que quedó en el servidor. Sin `write.notify`: en la ficha
      // ajena no existe.
      void client.invalidateQueries({ queryKey: queryKeys.rosterSettings });
      setFailed((n) => (n ?? 0) + 1);
    }
  };

  const toast = failed !== null && (
    <Toast key={failed} tone="error" message={t.layoutSaveFailed} open onOpenChange={(open) => !open && setFailed(null)} />
  );
  return { save, toast };
}
