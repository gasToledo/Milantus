import type { ReactNode } from 'react';
import { useTexts } from '../i18n/context';
import type { SheetTab } from '../router';
import { LinkTabs, TabPanel } from '../ui/disclosure';
import { CampaignTab } from './CampaignTab';
import { CharacterTab } from './CharacterTab';
import { CombatTab } from './CombatTab';
import { DiaryTab } from './DiaryTab';
import { InventoryTab } from './InventoryTab';
import { SheetHeader } from './SheetHeader';
import { TAB_ICONS, tabLabel } from './SheetPanel';
import type { SheetModel } from './model';

/**
 * La ficha de solo lectura con sus pestañas como rutas: la cabecera y, debajo,
 * la pestaña [active]. La usan la ficha propia y, en el Modo DM, la de un
 * miembro y la de un PNJ con ficha, cada una con las pestañas que le tocan
 * ([tabs]) y sus URL ([hrefOf]): son la misma pantalla con otra puerta, así
 * una cifra no puede quedar distinta en un lugar y en otro.
 */
export function SheetTabs({
  model,
  tabs,
  active,
  hrefOf,
  listClassName,
  panelClassName = 'pt-4',
  leading,
}: {
  model: SheetModel;
  tabs: readonly SheetTab[];
  active: SheetTab;
  hrefOf: (tab: SheetTab) => string;
  /** Para ocultar la tira donde el panel lateral ya hace de pestañas. */
  listClassName?: string;
  panelClassName?: string;
  /** Lo que va a la izquierda del nombre (el retrato, donde el panel no lo
   *  muestra). */
  leading?: ReactNode;
}) {
  const t = useTexts();
  return (
    <div className="flex flex-col gap-4">
      <SheetHeader model={model} leading={leading} />
      <LinkTabs
        label={t.sheetTabsLabel}
        value={active}
        listClassName={listClassName}
        tabs={tabs.map((tabId) => ({ value: tabId, label: tabLabel(t, tabId), href: hrefOf(tabId), icon: TAB_ICONS[tabId] }))}
      >
        <TabPanel value={active} className={panelClassName}>
          <TabBody tab={active} model={model} />
        </TabPanel>
      </LinkTabs>
    </div>
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
