// Lo que se escribe mientras se juega el guion: el progreso, las notas que pasan
// al Registro y el combate preparado. El progreso lo calcula el servidor con el
// motor; acá solo se manda la acción.
import { useCallback, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import {
  advanceChapterScript,
  createNote,
  type DmMilestone,
  type DmNote,
  type DmScript,
  type DmScriptLink,
  type DmScriptNote,
  type DmScriptStep,
  type DmScriptView,
  type ScriptProgressAction,
} from '../../api/client';
import { queryKeys, useSheetCatalog } from '../../api/queries';
import { flushScriptSave } from '../../api/scriptSave';
import { useLang, useTexts } from '../../i18n/context';
import { dmCampaignHref, navigate } from '../../router';
import type { ToastTone } from '../../ui/primitives';
import { flushEncounterSave, useEncounterWriter } from '../combat/encounterWriter';

export type Notify = (tone: ToastTone, message: string) => void;
type Fork = Extract<DmScriptStep, { type: 'fork' }>;

/** La bifurcación que hay que resolver para avanzar: la que ya espera, o la que
 *  sigue al hito actual. Sin ella, se alcanza directo. */
export function forkAhead(script: DmScript, view: DmScriptView): Fork | null {
  const index = view.currentId
    ? script.steps.findIndex((s) => (s.type === 'fork' ? s.paths : [s]).some((m) => m.id === view.currentId)) + 1
    : script.steps.findIndex((s) => s.id === view.awaitingFork);
  const step = script.steps[index];
  return step?.type === 'fork' ? step : null;
}

/** La nota del Registro que sale de una del guion. «Leer en voz alta» no lleva
 *  título: toma el del hito. */
const sharedNote = (note: DmScriptNote, milestone: DmMilestone, chapterId: string): DmNote => ({
  id: `note-${Date.now()}`,
  chapterId,
  title: note.title || milestone.title,
  body: note.body,
  shared: true,
});

/** Las escrituras de un capítulo en juego. Avanzar y compartir van de a una. */
export function usePlay(chapter: { campaignId: string; chapterId: string; notify: Notify } | null, scriptId: string) {
  const t = useTexts();
  const client = useQueryClient();
  const running = useRef(false);
  const [busy, setBusy] = useState(false);

  const lock = async <T>(work: () => Promise<T>): Promise<T | null> => {
    if (running.current) return null;
    running.current = true;
    setBusy(true);
    try {
      return await work();
    } finally {
      running.current = false;
      setBusy(false);
    }
  };
  const send = async (action: ScriptProgressAction) => {
    const { campaignId, chapterId } = chapter!;
    const key = queryKeys.chapterScript(campaignId, chapterId);
    // El servidor avanza sobre el guion guardado: lo pendiente tiene que llegar.
    await flushScriptSave(scriptId);
    const next = await advanceChapterScript(campaignId, chapterId, action);
    await client.cancelQueries({ queryKey: key });
    client.setQueryData(key, next);
    return next;
  };
  const reread = () => {
    void client.invalidateQueries({ queryKey: queryKeys.campaignNotebook(chapter!.campaignId) });
    void client.invalidateQueries({ queryKey: queryKeys.chapterScript(chapter!.campaignId, chapter!.chapterId) });
  };

  return {
    busy,
    /** El guion ya avanzado, o `null` si no se pudo (la caché no se toca). */
    advance: (action: ScriptProgressAction) =>
      lock(() =>
        send(action).catch(() => {
          chapter!.notify('error', t.scActionError);
          return null;
        }),
      ),
    /** `true` si la nota llegó al Registro, aunque no se haya podido marcar. */
    share: (note: DmScriptNote, milestone: DmMilestone) =>
      lock(async () => {
        const { campaignId, chapterId, notify } = chapter!;
        try {
          await createNote(campaignId, sharedNote(note, milestone, chapterId));
        } catch {
          notify('error', t.scActionError);
          return false;
        }
        try {
          await send({ type: 'markShared', note: note.id });
          notify('success', t.scShareDone);
        } catch {
          notify('error', t.scShareUnmarked);
        }
        reread();
        return true;
      }),
    /** Si falla, lanza: el diálogo de la nota queda abierto para reintentar. */
    saveNote: async (note: DmNote) => {
      await createNote(chapter!.campaignId, note);
      reread();
      chapter!.notify('success', t.scNoteSaved);
    },
  };
}

/** Arma en Combate el combate preparado de un hito. */
export function usePreparedCombat({
  campaignId,
  link,
  milestone,
  notify,
  onMusicOffer,
  onClose,
}: {
  campaignId: string;
  link: Extract<DmScriptLink, { type: 'encounter' }>;
  milestone: DmMilestone;
  notify: Notify;
  onMusicOffer: (campaignId: string, show: boolean) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  const writer = useEncounterWriter(
    campaignId,
    catalog.data,
    useCallback(() => notify('error', t.scActionError), [notify, t]),
    onMusicOffer,
  );
  const [busy, setBusy] = useState(false);
  /** Ya hay un combate abierto: la base admite uno solo por campaña. */
  const [blocked, setBlocked] = useState(false);

  const start = async () => {
    if (busy || blocked || !catalog.data) return;
    setBusy(true);
    try {
      if (await writer.read()) {
        setBlocked(true);
      } else if (writer.act({ type: 'open' })) {
        for (const { creatureId, count } of link.creatures) {
          if (!writer.act({ type: 'addMonsters', creatureId, count })) {
            // Lo ya armado queda en Combate y se descarta desde ahí.
            notify('error', t.scCreatureGone);
            return onClose();
          }
        }
        const scenario = milestone.links.find((l) => l.type === 'scenario');
        if (scenario) writer.act({ type: 'setScenario', scenarioId: scenario.scenarioId });
        await flushEncounterSave(campaignId);
        navigate(dmCampaignHref(campaignId, 'combate'));
      }
    } catch {
      notify('error', t.scActionError);
    }
    setBusy(false);
  };

  return { ready: catalog.data !== undefined, busy, blocked, start, combatHref: dmCampaignHref(campaignId, 'combate') };
}
