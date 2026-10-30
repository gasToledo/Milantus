import {
  ArrowUpCircle,
  Backpack,
  BookOpen,
  Eye,
  Flag,
  Image,
  Printer,
  Share2,
  Swords,
  User,
  type LucideIcon,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { useTexts } from '../i18n/context';
import { characterHref, FLUTTER_HOME, levelUpHref, rosterHref, SHEET_TABS, type SheetTab } from '../router';
import type { Texts } from '../i18n/texts';
import { Medallion } from '../ui/Medallion';
import { PrintSheet, usePrintSheet } from './PrintSheet';
import { ownPortrait } from '../ui/portrait';
import { NavGroup, NavItem, SidebarBack, ThemeMenu, VersionLabel } from '../ui/Shell';
import { accentFor, classesOf, type SheetModel } from './model';

export const TAB_ICONS: Record<SheetTab, LucideIcon> = {
  personaje: User,
  combate: Swords,
  inventario: Backpack,
  campana: Flag,
  diario: BookOpen,
};

/**
 * El panel de una pantalla de adentro (`SidebarBackButton` + navegación de la
 * ficha): «volver», la tarjeta del personaje, las secciones y las acciones.
 * Las cinco secciones son pestañas de `/v2`. Imprimir es de acá (`PrintSheet`);
 * subir de nivel es el asistente de `/v2` (`LevelUpWizard`); retrato y
 * compartir escriben o generan algo y todavía viven en Flutter, así que
 * enlazan allá.
 */
export function SheetPanel({ model, tab }: { model: SheetModel; tab: SheetTab }) {
  const t = useTexts();
  const { character, sheet } = model;
  const classes = classesOf(model)
    .map((c) => t.classLevel(c.name, c.level))
    .join(' / ');
  const id = character.id;
  const printing = usePrintSheet();

  return (
    <>
      <SidebarBack href={rosterHref()} label={t.backToCharacters} />

      {/* La tarjeta no es un enlace: ya se está en la ficha. */}
      <div className="plaque flex items-center gap-2.5 px-2.5 py-2">
        <Medallion name={character.name} accent={accentFor(model)} size={38} portrait={ownPortrait(character)} viewable />
        <div className="min-w-0">
          <p className="truncate text-[13.5px] font-medium text-on-surface">{character.name}</p>
          <p className="mt-0.5 truncate text-[11px] text-text-muted">{t.miniClassLine(classes, sheet.level)}</p>
        </div>
      </div>

      <NavGroup label={t.sheetNavLabel}>
        {SHEET_TABS.map((tabId) => (
          <li key={tabId}>
            <NavItem
              href={characterHref(id, tabId)}
              icon={TAB_ICONS[tabId]}
              label={tabLabel(t, tabId)}
              active={tab === tabId}
              internal
            />
          </li>
        ))}
      </NavGroup>

      <NavGroup label={t.sheetActionsLabel}>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Image} label={t.actionPortrait} external />
        </li>
        <li>
          <NavItem href={levelUpHref(id)} icon={ArrowUpCircle} label={t.actionLevelUp} internal />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Share2} label={t.actionShare} external />
        </li>
        <li>
          <NavItem onSelect={printing.print} icon={Printer} label={t.actionPrint} />
        </li>
      </NavGroup>
      {printing.printing && <PrintSheet model={model} onDone={printing.done} />}
    </>
  );
}

/** El pie liviano (`SidebarLightFooter`): «Solo lectura» —o, en la ficha
 *  propia, el estado del guardado ([status])—, el tema y la versión. Ajustes y
 *  la cuenta quedan a un «volver» de distancia. */
export function SheetFooter({ version, status }: { version: string | null | undefined; status?: ReactNode }) {
  const t = useTexts();
  return (
    <div className="flex items-center justify-between gap-2">
      {status ?? (
        <span className="inline-flex items-center gap-1.5 rounded-[var(--radius-pill)] border border-hairline px-2.5 py-1 text-[11.5px] text-on-surface-variant">
          <Eye size={13} aria-hidden="true" />
          {t.readOnly}
        </span>
      )}
      <div className="flex items-center gap-2">
        <VersionLabel version={version} />
        <ThemeMenu />
      </div>
    </div>
  );
}

export function tabLabel(t: Texts, tab: SheetTab): string {
  switch (tab) {
    case 'personaje':
      return t.tabCharacter;
    case 'combate':
      return t.tabCombat;
    case 'inventario':
      return t.navInventory;
    case 'campana':
      return t.navCampaign;
    case 'diario':
      return t.navDiary;
  }
}
