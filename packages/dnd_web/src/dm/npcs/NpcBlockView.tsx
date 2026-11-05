import { useCallback, useMemo, type MutableRefObject } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ApiError } from '../../api/client';
import { flushNpcSave } from '../../api/npcSave';
import { queryKeys, useNpc, useSheetCatalog } from '../../api/queries';
import { npcBlock, npcViews, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcsHref, navigate } from '../../router';
import { SidebarBack } from '../../ui/Shell';
import { AppBusyLabel, AppErrorView, Notice } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { CreatureForm } from './CreatureForm';
import { useNpcWriter } from './npcWriter';

/** El «volver» del panel lateral: al PNJ, preguntando antes si hay cambios
 *  (la pregunta la hace el formulario, que es quien sabe). */
export function NpcBlockBack({ npcId, leaveRef }: { npcId: string; leaveRef: MutableRefObject<(() => void) | null> }) {
  const t = useTexts();
  const stored = useNpc(npcId);
  return (
    <SidebarBack
      href={dmNpcsHref(npcId)}
      label={stored.data?.npc.name || t.dmNpcLibrary}
      onClick={(e) => {
        // Sin formulario montado (cargando, error) es un enlace común.
        if (!leaveRef.current) return;
        e.preventDefault();
        leaveRef.current();
      }}
    />
  );
}

/**
 * El editor del bloque de un PNJ de bloque (`/dm/pnj/:id/bloque`). Un PNJ ajeno,
 * uno inexistente y uno que no es de bloque dicen lo mismo, «No se encontró».
 * Guardar reemplaza el bloque entero con `setBlock`, que aplica el motor.
 */
export function NpcBlockView({ npcId, leaveRef }: { npcId: string; leaveRef: MutableRefObject<(() => void) | null> }) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const stored = useNpc(npcId);
  const catalog = useSheetCatalog(lang);
  // El fallo de un guardado en fila lo cuenta `flushNpcSave` al lanzar.
  const writer = useNpcWriter(npcId, useCallback(() => {}, []));
  const view = useMemo(
    () => (stored.data && catalog.data ? npcViews([stored.data], catalog.data)[0] : null),
    [stored.data, catalog.data],
  );
  // Estable: el formulario recalcula su borrador cuando cambia.
  const initial = useMemo(() => (view ? npcBlock(view.npc) : null), [view]);

  const failed = [stored, ...catalog.queries].filter((q) => q.isError);
  if ((stored.error instanceof ApiError && stored.error.status === 404) || (stored.data && stored.data.npc.sheetKind !== 'block')) {
    return <Notice title={t.npcNotFound} body={t.npcNotFoundBody} />;
  }
  if (failed.length > 0) {
    return <AppErrorView as="h1" title={t.npcReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  }
  if (!view || !initial || !catalog.data) {
    return (
      <>
        <DmHeader title={t.npcEditBlock} />
        <AppBusyLabel label={t.npcLoading} />
      </>
    );
  }

  const save = async (block: JsonObject) => {
    if (!writer.edit({ type: 'setBlock', block })) throw new Error('El motor no pudo aplicar el bloque.');
    await flushNpcSave(npcId);
    await client.invalidateQueries({ queryKey: queryKeys.npc(npcId) });
    navigate(dmNpcsHref(npcId));
  };

  return (
    <CreatureForm
      initial={initial}
      catalog={catalog.data}
      title={t.npcEditBlock}
      kicker={view.baseName ? t.blockBasedOn(view.baseName) : undefined}
      exitHref={dmNpcsHref(npcId)}
      onSave={save}
      leaveRef={leaveRef}
    />
  );
}
