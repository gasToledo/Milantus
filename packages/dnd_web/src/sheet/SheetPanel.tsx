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
import { useTexts } from '../i18n/context';
import { characterHref, FLUTTER_HOME, rosterHref, type SheetTab } from '../router';
import { Medallion } from '../ui/Medallion';
import { NavGroup, NavItem, SidebarBack, ThemeMenu, VersionLabel } from '../ui/Shell';
import { accentFor, classesOf, type SheetModel } from './model';

export const TAB_ICONS: Record<SheetTab, LucideIcon> = { personaje: User, combate: Swords };

/**
 * El panel de una pantalla de adentro (`SidebarBackButton` + navegación de la
 * ficha): «volver», la tarjeta del personaje, las secciones y las acciones.
 * Personaje y Combate son pestañas de `/v2`; lo demás (Inventario, Campaña,
 * Diario y las cuatro acciones) todavía vive en Flutter y enlaza allá.
 */
export function SheetPanel({ model, tab }: { model: SheetModel; tab: SheetTab }) {
  const t = useTexts();
  const { character, sheet } = model;
  const classes = classesOf(model)
    .map((c) => t.classLevel(c.name, c.level))
    .join(' / ');
  const id = character.id;

  return (
    <>
      <SidebarBack href={rosterHref()} label={t.backToCharacters} />

      {/* La tarjeta no es un enlace: ya se está en la ficha. */}
      <div className="plaque flex items-center gap-2.5 px-2.5 py-2">
        <Medallion name={character.name} accent={accentFor(model)} size={38} />
        <div className="min-w-0">
          <p className="truncate text-[13.5px] font-medium text-on-surface">{character.name}</p>
          <p className="mt-0.5 truncate text-[11px] text-text-muted">{t.miniClassLine(classes, sheet.level)}</p>
        </div>
      </div>

      <NavGroup label={t.sheetNavLabel}>
        <li>
          <NavItem href={characterHref(id, 'personaje')} icon={TAB_ICONS.personaje} label={t.tabCharacter} active={tab === 'personaje'} internal />
        </li>
        <li>
          <NavItem href={characterHref(id, 'combate')} icon={TAB_ICONS.combate} label={t.tabCombat} active={tab === 'combate'} internal />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Backpack} label={t.navInventory} external />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Flag} label={t.navCampaign} external />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={BookOpen} label={t.navDiary} external />
        </li>
      </NavGroup>

      <NavGroup label={t.sheetActionsLabel}>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Image} label={t.actionPortrait} external />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={ArrowUpCircle} label={t.actionLevelUp} external />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Share2} label={t.actionShare} external />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Printer} label={t.actionPrint} external />
        </li>
      </NavGroup>
    </>
  );
}

/** El pie liviano (`SidebarLightFooter`): «Solo lectura», el tema y la
 *  versión. Ajustes y la cuenta quedan a un «volver» de distancia. */
export function SheetFooter({ version }: { version: string | null | undefined }) {
  const t = useTexts();
  return (
    <div className="flex items-center justify-between gap-2">
      <span className="inline-flex items-center gap-1.5 rounded-[var(--radius-pill)] border border-hairline px-2.5 py-1 text-[11.5px] text-on-surface-variant">
        <Eye size={13} aria-hidden="true" />
        {t.readOnly}
      </span>
      <div className="flex items-center gap-2">
        <VersionLabel version={version} />
        <ThemeMenu />
      </div>
    </div>
  );
}
