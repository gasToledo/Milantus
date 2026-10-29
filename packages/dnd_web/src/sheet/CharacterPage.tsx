import { useEffect, useMemo } from 'react';
import { useAppVersion, useRoster, useSheetCatalog } from '../api/queries';
import { computeSheet, migrateCharacter, type CharacterFields, type ComputedSheet } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { characterHref, navigate, rosterHref, SHEET_TABS, type SheetTab } from '../router';
import { LinkTabs, TabPanel } from '../ui/disclosure';
import { Shell, SidebarBack } from '../ui/Shell';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';
import { CharacterTab } from './CharacterTab';
import { CombatTab } from './CombatTab';
import { SheetHeader } from './SheetHeader';
import { CampaignTab } from './CampaignTab';
import { DiaryTab } from './DiaryTab';
import { InventoryTab } from './InventoryTab';
import { SheetFooter, SheetPanel, TAB_ICONS, tabLabel } from './SheetPanel';
import type { SheetModel } from './model';

type Computed =
  | { ok: true; model: SheetModel }
  | { ok: false; detail: string };

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
  const computed = useMemo((): Computed | null => {
    if (!raw || !catalog.data) return null;
    try {
      // Se migra una vez y se usa lo migrado para todo: el motor calcula sobre
      // la forma actual y la pantalla lee los mismos campos (el PG actual, los
      // espacios gastados) sin conocer esquemas viejos.
      const migrated = migrateCharacter(raw);
      // El motor de Dart compilado a JS, el mismo que usan el servidor y
      // Flutter: acá no se recalcula ninguna regla.
      const sheet: ComputedSheet = computeSheet(migrated, catalog.data);
      return {
        ok: true,
        // `CharacterFields` es el subconjunto que esta pantalla lee de un
        // `Character.toJson` que el servidor ya validó al guardarlo.
        model: { character: migrated as unknown as CharacterFields, sheet, catalog: catalog.data },
      };
    } catch (e) {
      // Un esquema más nuevo que este cliente, o una ficha que el motor no
      // entiende: se dice, en vez de mostrar números a medias.
      return { ok: false, detail: String(e) };
    }
  }, [raw, catalog.data]);

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
    const m = computed.model;
    body = (
      <div className="flex flex-col gap-4">
        <SheetHeader model={m} />
        {/* Debajo de 900 px el panel es un cajón: la tira de pestañas va
            arriba del contenido, para cambiar sin abrirlo. Desde 900 las
            pestañas viven en el panel y la tira se oculta; el panel de la
            pestaña es el mismo en los dos casos (se monta una sola vez). */}
        <LinkTabs
          label={t.sheetTabsLabel}
          value={activeTab}
          listClassName="shell:hidden"
          tabs={SHEET_TABS.map((tabId) => ({
            value: tabId,
            label: tabLabel(t, tabId),
            href: characterHref(id, tabId),
            icon: TAB_ICONS[tabId],
          }))}
        >
          <TabPanel value={activeTab} className="pt-4 shell:pt-0">
            <TabBody tab={activeTab} model={m} />
          </TabPanel>
        </LinkTabs>
      </div>
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

function TabBody({ tab, model }: { tab: SheetTab; model: SheetModel }) {
  switch (tab) {
    case 'personaje':
      return <CharacterTab model={model} />;
    case 'combate':
      return <CombatTab model={model} />;
    case 'inventario':
      return <InventoryTab model={model} />;
    case 'campana':
      return <CampaignTab model={model} />;
    case 'diario':
      return <DiaryTab model={model} />;
  }
}
