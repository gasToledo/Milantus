import { useCallback, useEffect, useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { hasUnsavedChanges, retrySave, useSaveState } from '../api/characterSave';
import { queryKeys, useAppVersion, useRoster, useSheetCatalog } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { characterHref, navigate, rosterHref, SHEET_TABS, type SheetTab } from '../router';
import { Toast, ToastProvider, ToastViewport, type ToastTone } from '../ui/primitives';
import { Shell, SidebarBack } from '../ui/Shell';
import { AppBusyLabel, AppErrorView, Notice, SaveStatusBadge } from '../ui/status';
import { computeModel, type ComputedModel } from './compute';
import { SheetFooter, SheetPanel } from './SheetPanel';
import { SheetTabs } from './SheetTabs';
import { LevelUpWizard } from '../levelup/LevelUpWizard';
import { useSheetWriter, type SheetNotify } from './writer';

interface ToastState {
  key: number;
  tone: ToastTone;
  message: string;
  undo?: () => void;
}

/**
 * La ficha propia de [id] en la pestaña [tab]. La API no tiene `GET` por id
 * (el cliente de Flutter tampoco: carga la lista), así que se busca en
 * `/api/characters`; con la caché, si se viene del dashboard ni siquiera se
 * vuelve a pedir. Lo ajeno y lo inexistente son lo mismo para la API; acá
 * también.
 *
 * Es la única ficha que escribe (`useSheetWriter`): PG, usos y descansos, cada
 * uno pasado por el motor y guardado con la cola de `characterSave.ts`.
 */
export function CharacterPage({ id, tab, levelUp = false }: { id: string; tab: SheetTab | null; levelUp?: boolean }) {
  const t = useTexts();
  const lang = useLang();
  const roster = useRoster();
  const catalog = useSheetCatalog(lang);
  const version = useAppVersion(true);
  const client = useQueryClient();
  const saveState = useSaveState(id);

  // La ruta sin pestaña es la primera: se reemplaza en el historial para que
  // «atrás» no vuelva a una URL que solo redirige.
  useEffect(() => {
    if (tab === null && !levelUp) navigate(characterHref(id), { replace: true });
  }, [id, tab, levelUp]);

  // Al volver a la pestaña se pide la ficha de nuevo, por si se tocó en
  // Flutter mientras tanto: así la próxima acción parte de esa copia y no la
  // pisa con una vieja. Nunca con algo pendiente, que se perdería.
  useEffect(() => {
    const refresh = () => {
      if (document.visibilityState === 'visible' && !hasUnsavedChanges()) {
        void client.invalidateQueries({ queryKey: queryKeys.roster });
      }
    };
    document.addEventListener('visibilitychange', refresh);
    return () => document.removeEventListener('visibilitychange', refresh);
  }, [client]);

  const [toast, setToast] = useState<ToastState | null>(null);
  const notify = useCallback<SheetNotify>(
    (message, options) =>
      setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone: options?.tone ?? 'info', message, undo: options?.undo })),
    [],
  );
  const write = useSheetWriter(id, catalog.data, notify, t.actionFailed);

  const raw = roster.data?.find((c) => c.character.id === id)?.character ?? null;
  const computed = useMemo(
    (): ComputedModel | null => (raw && catalog.data ? computeModel(raw, catalog.data) : null),
    [raw, catalog.data],
  );

  const failed = [roster, ...catalog.queries].filter((q) => q.isError);
  const activeTab: SheetTab = tab ?? 'personaje';
  const model = useMemo(
    () => (computed?.ok ? { ...computed.model, write: write ?? undefined } : null),
    [computed, write],
  );

  let body;
  if (failed.length > 0) {
    body = (
      <AppErrorView as="h1" title={t.errorTitle} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
    );
  } else if (roster.data && !raw) {
    body = <Notice title={t.notFoundTitle} body={t.notFoundBody} />;
  } else if (!computed) {
    body = <AppBusyLabel label={t.loading} />;
  } else if (!model) {
    body = <AppErrorView as="h1" title={t.computeErrorTitle} message={t.computeErrorBody} detail={computed.ok ? undefined : computed.detail} />;
  } else if (levelUp) {
    body = model.write ? <LevelUpWizard model={model} write={model.write} /> : <AppBusyLabel label={t.loading} />;
  } else {
    // Debajo de 900 px el panel es un cajón: la tira de pestañas va arriba del
    // contenido, para cambiar sin abrirlo. Desde 900 las pestañas viven en el
    // panel y la tira se oculta; el panel de la pestaña es el mismo en los dos
    // casos (se monta una sola vez).
    body = (
      <SheetTabs
        model={model}
        tabs={SHEET_TABS}
        active={activeTab}
        hrefOf={(tabId) => characterHref(id, tabId)}
        listClassName="shell:hidden"
        panelClassName="pt-4 shell:pt-0"
      />
    );
  }

  return (
    <ToastProvider>
      <Shell
        panel={model ? <SheetPanel model={model} tab={activeTab} /> : <SidebarBack href={rosterHref()} label={t.backToCharacters} />}
        footer={
          <SheetFooter
            version={version.data}
            status={model ? <SaveStatusBadge state={saveState} onRetry={() => retrySave(id)} /> : undefined}
          />
        }
      >
        {body}
      </Shell>
      {toast && (
        <Toast
          key={toast.key}
          tone={toast.tone}
          message={toast.message}
          open
          onOpenChange={(open) => !open && setToast(null)}
          action={toast.undo ? { label: t.undo, onSelect: toast.undo } : undefined}
        />
      )}
      <ToastViewport />
    </ToastProvider>
  );
}
