// Lo que se escribe en un guion: la acción la aplica el motor, se ve al instante
// en la caché y se guarda en fila (`api/scriptSave.ts`).
import { useMemo } from 'react';
import { useQueryClient, type Query } from '@tanstack/react-query';
import type { DmChapterScript, DmScript, DmStoredScript } from '../../api/client';
import { queryKeys } from '../../api/queries';
import { dropScriptSave, latestScriptDoc, scheduleScriptSave } from '../../api/scriptSave';
import { scriptEdit, type ScriptAction } from '../../engine';

/** Las lecturas de `useChapterScript`, de cualquier campaña. */
const isChapterScript = (q: Query) => q.queryKey[0] === 'dm' && q.queryKey[1] === 'campaigns' && q.queryKey[3] === 'script';

export interface ScriptWriter {
  /** `false` si el motor rechazó la acción. */
  edit(action: ScriptAction): boolean;
}

export function useScriptWriter(scriptId: string, onFailed: () => void): ScriptWriter {
  const client = useQueryClient();
  return useMemo(() => {
    const reread = () => {
      void client.invalidateQueries({ queryKey: queryKeys.scripts });
      void client.invalidateQueries({ predicate: isChapterScript });
    };
    const put = (doc: DmScript) => {
      // Una lectura en vuelo traería el documento de antes y pisaría lo escrito.
      void client.cancelQueries({ queryKey: queryKeys.scripts });
      void client.cancelQueries({ predicate: isChapterScript });
      client.setQueryData<DmStoredScript>(queryKeys.script(scriptId), (old) => old && { ...old, script: doc });
      client.setQueryData<DmStoredScript[]>(queryKeys.scripts, (old) =>
        old?.map((e) => (e.script.id === scriptId ? { ...e, script: doc } : e)),
      );
      client.setQueriesData<DmChapterScript>({ predicate: isChapterScript }, (old) =>
        old?.script?.id === scriptId ? { ...old, script: doc } : old,
      );
      scheduleScriptSave(doc, (ok) => {
        if (ok) return reread();
        // Lo que no se guardó se descarta: si quedara en la fila, la próxima
        // edición partiría de un documento que el servidor no tiene.
        onFailed();
        void dropScriptSave(scriptId).then(reread);
      });
    };
    const cached = (): DmScript | undefined =>
      client.getQueryData<DmStoredScript>(queryKeys.script(scriptId))?.script ??
      client
        .getQueriesData<DmChapterScript>({ predicate: isChapterScript })
        .map(([, data]) => data?.script)
        .find((s): s is DmScript => s?.id === scriptId);
    return {
      edit(action) {
        // La base es lo último que se pidió guardar y no la caché: una relectura
        // en el medio puede haberla atrasado.
        const before = latestScriptDoc(scriptId) ?? cached();
        if (!before) return false;
        try {
          put(scriptEdit(before, action));
          return true;
        } catch {
          onFailed();
          return false;
        }
      },
    };
  }, [client, scriptId, onFailed]);
}
