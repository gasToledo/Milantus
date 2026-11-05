import { useMemo } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { scheduleSave } from '../api/characterSave';
import type { StoredCharacter, StoredNpc } from '../api/client';
import { queryKeys } from '../api/queries';
import { actOn, migrateCharacter, type Catalog, type CharacterJson, type SheetAction, type SheetOutcome } from '../engine';
import { ownSheetRoutes, type SheetRoutes } from '../router';
import type { ToastTone } from '../ui/primitives';

/** Un aviso de la ficha; con [undo], lleva «Deshacer». */
export type SheetNotify = (message: string, options?: { tone?: ToastTone; undo?: () => void }) => void;

/**
 * Lo que una ficha escribe. Sin él, ningún componente muestra un control que
 * escriba: la ficha de un miembro de la Mesa no lo recibe (el DM no escribe la
 * ficha de otra cuenta). Lo arman `CharacterPage` (`own`) y la ficha de un PNJ
 * (`npc`): el DM sí escribe la de su PNJ, que es suya.
 */
export interface SheetWriter {
  /** Lo que conecta una ficha con otra cuenta o lleva a una pantalla de la
   *  ficha propia (compartir, regalos, editores) solo aparece con `own`. */
  kind: 'own' | 'npc';
  /** Aplica la acción con el motor, la muestra al instante y la deja para
   *  guardar. `before` es la ficha de antes (para «Deshacer»); `null` si el
   *  motor no pudo (ya se avisó). */
  act(action: SheetAction): { outcome: SheetOutcome; before: CharacterJson } | null;
  /** Vuelve a [before] y lo guarda: el «Deshacer» de un descanso. */
  restore(before: CharacterJson): void;
  notify: SheetNotify;
  /** A dónde llevan las pantallas de la ficha (la propia o la del PNJ). */
  routes: SheetRoutes;
}

type Doc = CharacterJson & { id: string };

/** Lo común a las dos fichas: de dónde se lee la copia y cómo se pone y se
 *  guarda la nueva cambia; el motor y los avisos no. */
function buildWriter({
  kind,
  routes,
  catalog,
  notify,
  failedMessage,
  read,
  put,
}: {
  kind: SheetWriter['kind'];
  routes: SheetRoutes;
  catalog: Catalog;
  notify: SheetNotify;
  failedMessage: string;
  read: () => CharacterJson | undefined;
  put: (doc: Doc) => void;
}): SheetWriter {
  return {
    kind,
    routes,
    act(action) {
      const raw = read();
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
}

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
    return buildWriter({
      kind: 'own',
      routes: ownSheetRoutes(id),
      catalog,
      notify,
      failedMessage,
      read: () => client.getQueryData<StoredCharacter[]>(queryKeys.roster)?.find((s) => s.character.id === id)?.character,
      put: (doc) => {
        // Un pedido de la lista en vuelo (el de volver a la pestaña) traería la
        // copia de antes y pisaría la acción en pantalla.
        void client.cancelQueries({ queryKey: queryKeys.roster });
        client.setQueryData<StoredCharacter[]>(queryKeys.roster, (list) =>
          list?.map((s) => (s.character.id === id ? { ...s, character: doc } : s)),
        );
        scheduleSave(doc);
      },
    });
  }, [client, id, catalog, notify, failedMessage]);
}

/**
 * Lo mismo para la ficha de un PNJ con ficha de personaje: vive en la caché de
 * `GET /api/npcs/:id` (y en la entrada de la lista) y se guarda por la misma
 * cola que la ficha propia, con `PUT /api/characters/:id`.
 */
export function useNpcSheetWriter(
  npcId: string,
  catalog: Catalog | undefined,
  notify: SheetNotify,
  failedMessage: string,
): SheetWriter | null {
  const client = useQueryClient();
  return useMemo(() => {
    if (!catalog) return null;
    return buildWriter({
      kind: 'npc',
      // Provisorio: la parte 2 de 6f3 le pone las rutas del PNJ; mientras tanto
      // esos enlaces siguen ocultos para `npc`.
      routes: ownSheetRoutes(npcId),
      catalog,
      notify,
      failedMessage,
      read: () => client.getQueryData<StoredNpc>(queryKeys.npc(npcId))?.character,
      put: (doc) => {
        // `npc(id)` cuelga de `npcs`: un pedido en vuelo de la lista o del PNJ
        // traería la copia de antes y pisaría la acción en pantalla.
        void client.cancelQueries({ queryKey: queryKeys.npcs });
        client.setQueryData<StoredNpc>(queryKeys.npc(npcId), (old) => old && { ...old, character: doc });
        client.setQueryData<StoredNpc[]>(queryKeys.npcs, (list) =>
          list?.map((e) => (e.npc.id === npcId ? { ...e, character: doc } : e)),
        );
        scheduleSave(doc);
      },
    });
  }, [client, npcId, catalog, notify, failedMessage]);
}
