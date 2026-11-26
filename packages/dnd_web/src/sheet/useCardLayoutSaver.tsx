import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { patchSettings } from '../api/settingsSave';
import { queryKeys } from '../api/queries';
import type { RosterSettings } from '../api/client';
import { useTexts } from '../i18n/context';
import { Toast } from '../ui/primitives';
import type { CardLayout } from './cardLayout';

/** Guarda lo de quien mira: el orden de las tarjetas de [tab] (null: el de
 *  fábrica) y la lista completa de conjuros. [toast] es el aviso de que no se
 *  pudo, para dibujar donde se use. */
export function useCardLayoutSaver(tab: 'combate' | 'personaje') {
  const t = useTexts();
  const client = useQueryClient();
  const [failed, setFailed] = useState<number | null>(null);

  // Cada movimiento se guarda en el momento. Siempre viaja el objeto entero
  // (las dos pestañas): el servidor combina solo el primer nivel de los ajustes.
  const write = async (patch: (current: RosterSettings | undefined) => Partial<RosterSettings>) => {
    await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
    const changed = patch(client.getQueryData<RosterSettings>(queryKeys.rosterSettings));
    client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (old) => old && { ...old, ...changed });
    try {
      await patchSettings(changed);
    } catch {
      // Vuelve lo que quedó en el servidor. Sin `write.notify`: en la ficha
      // ajena no existe.
      void client.invalidateQueries({ queryKey: queryKeys.rosterSettings });
      setFailed((n) => (n ?? 0) + 1);
    }
  };
  const save = (next: CardLayout | null) =>
    write((settings) => {
      const current = settings?.sheetLayout ?? {};
      return { sheetLayout: { combate: current.combate ?? null, personaje: current.personaje ?? null, [tab]: next } };
    });
  const saveSpellList = (spellListFull: boolean) => write(() => ({ spellListFull }));

  const toast = failed !== null && (
    <Toast key={failed} tone="error" message={t.settingsSaveFailed} open onOpenChange={(open) => !open && setFailed(null)} />
  );
  return { save, saveSpellList, toast };
}
