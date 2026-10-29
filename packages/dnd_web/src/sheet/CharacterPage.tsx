import { useEffect, useMemo } from 'react';
import { useAppVersion, useRoster, useSheetCatalog } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { characterHref, navigate, rosterHref, SHEET_TABS, type SheetTab } from '../router';
import { Shell, SidebarBack } from '../ui/Shell';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';
import { computeModel, type ComputedModel } from './compute';
import { SheetFooter, SheetPanel } from './SheetPanel';
import { SheetTabs } from './SheetTabs';

/**
 * La ficha de [id], de solo lectura, en la pestaña [tab]. La API no tiene
 * `GET` por id (el cliente de Flutter tampoco: carga la lista), así que se
 * busca en `/api/characters`; con la caché, si se viene del dashboard ni
 * siquiera se vuelve a pedir. Lo ajeno y lo inexistente son lo mismo para la
 * API; acá también.
 */
export function CharacterPage({ id, tab }: { id: string; tab: SheetTab | null }) {
  const t = useTexts();
  const lang = useLang();
  const roster = useRoster();
  const catalog = useSheetCatalog(lang);
  const version = useAppVersion(true);

  // La ruta sin pestaña es la primera: se reemplaza en el historial para que
  // «atrás» no vuelva a una URL que solo redirige.
  useEffect(() => {
    if (tab === null) navigate(characterHref(id), { replace: true });
  }, [id, tab]);

  const raw = roster.data?.find((c) => c.character.id === id)?.character ?? null;
  const computed = useMemo(
    (): ComputedModel | null => (raw && catalog.data ? computeModel(raw, catalog.data) : null),
    [raw, catalog.data],
  );

  const failed = [roster, ...catalog.queries].filter((q) => q.isError);
  const activeTab: SheetTab = tab ?? 'personaje';
  const model = computed?.ok ? computed.model : null;

  let body;
  if (failed.length > 0) {
    body = (
      <AppErrorView as="h1" title={t.errorTitle} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
    );
  } else if (roster.data && !raw) {
    body = <Notice title={t.notFoundTitle} body={t.notFoundBody} />;
  } else if (!computed) {
    body = <AppBusyLabel label={t.loading} />;
  } else if (!computed.ok) {
    body = <AppErrorView as="h1" title={t.computeErrorTitle} message={t.computeErrorBody} detail={computed.detail} />;
  } else {
    // Debajo de 900 px el panel es un cajón: la tira de pestañas va arriba del
    // contenido, para cambiar sin abrirlo. Desde 900 las pestañas viven en el
    // panel y la tira se oculta; el panel de la pestaña es el mismo en los dos
    // casos (se monta una sola vez).
    body = (
      <SheetTabs
        model={computed.model}
        tabs={SHEET_TABS}
        active={activeTab}
        hrefOf={(tabId) => characterHref(id, tabId)}
        listClassName="shell:hidden"
        panelClassName="pt-4 shell:pt-0"
      />
    );
  }

  return (
    <Shell
      panel={model ? <SheetPanel model={model} tab={activeTab} /> : <SidebarBack href={rosterHref()} label={t.backToCharacters} />}
      footer={<SheetFooter version={version.data} />}
    >
      {body}
    </Shell>
  );
}
