import { useMemo } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { scheduleSave } from '../api/characterSave';
import type { StoredCharacter } from '../api/client';
import { queryKeys } from '../api/queries';
import { actOn, migrateCharacter, type Catalog, type CharacterJson, type SheetAction, type SheetOutcome } from '../engine';
import type { ToastTone } from '../ui/primitives';

/** Un aviso de la ficha; con [undo], lleva «Deshacer». */
export type SheetNotify = (message: string, options?: { tone?: ToastTone; undo?: () => void }) => void;

/**
 * Lo que la ficha **propia** puede escribir. Solo `CharacterPage` lo arma: la
 * ficha de un miembro de la Mesa y la de un PNJ usan los mismos componentes
 * sin él, y sin él no aparece ni un control (el DM no escribe la ficha de
 * otra cuenta).
 */
export interface SheetWriter {
  /** Aplica la acción con el motor, la muestra al instante y la deja para
   *  guardar. `before` es la ficha de antes (para «Deshacer»); `null` si el
   *  motor no pudo (ya se avisó). */
  act(action: SheetAction): { outcome: SheetOutcome; before: CharacterJson } | null;
  /** Vuelve a [before] y lo guarda: el «Deshacer» de un descanso. */
  restore(before: CharacterJson): void;
  notify: SheetNotify;
}

type Doc = CharacterJson & { id: string };

/**
 * La ficha vive en la caché de `/api/characters` (la misma que lee el
 * dashboard): cada acción reemplaza ahí el documento por el que devuelve el
 * motor y lo pone en la cola de guardado. No se vuelve a pedir después de
 * guardar: lo que hay en la caché es justo lo que se mandó.
 */
export function useSheetWriter(
  id: string,
  catalog: Catalog | undefined,
  notify: SheetNotify,
  failedMessage: string,
): SheetWriter | null {
  const client = useQueryClient();
  return useMemo(() => {
    if (!catalog) return null;
    const put = (doc: Doc) => {
      // Un pedido de la lista en vuelo (el de volver a la pestaña) traería la
      // copia de antes y pisaría la acción en pantalla.
      void client.cancelQueries({ queryKey: queryKeys.roster });
      client.setQueryData<StoredCharacter[]>(queryKeys.roster, (list) =>
        list?.map((s) => (s.character.id === id ? { ...s, character: doc } : s)),
      );
      scheduleSave(doc);
    };
    return {
      act(action) {
        const raw = client
          .getQueryData<StoredCharacter[]>(queryKeys.roster)
          ?.find((s) => s.character.id === id)?.character;
        if (!raw) return null;
        try {
          const before = migrateCharacter(raw);
          const { character, outcome } = actOn(before, catalog, action);
          put(character as Doc);
          return { outcome, before };
        } catch {
          // Una ficha de una versión futura, o un motor desfasado: no se
          // guarda nada que el motor no haya producido.
          notify(failedMessage, { tone: 'error' });
          return null;
        }
      },
      restore(before) {
        put(before as Doc);
      },
      notify,
    };
  }, [client, id, catalog, notify, failedMessage]);
}
