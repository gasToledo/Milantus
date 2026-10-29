import { BookMarked, BookOpen, NotebookText, FlaskConical, PawPrint, Users, UsersRound, Flame, Contact } from 'lucide-react';
import type { DmCampaign } from '../api/client';
import { useTexts } from '../i18n/context';
import { dmCampaignHref, FLUTTER_HOME, rosterHref, dmHref, type DmSection } from '../router';
import { NavCollapsible } from '../ui/disclosure';
import { ModeSwitch, NavGroup, NavItem } from '../ui/Shell';
import { groupCampaigns, stateOf } from './campaigns';

/**
 * El panel del Modo DM (`_sidebar` de `dm_mode_screen.dart`): el interruptor
 * con «DM» activo, las herramientas de la cuenta, las campañas agrupadas por
 * estado y, de la campaña elegida, sus secciones. Lo que React todavía no
 * porta (Biblioteca de PNJ, Homebrew, PNJ de la mesa y Combate) enlaza a
 * Flutter con el ícono de enlace externo.
 */
export function DmPanel({
  campaigns,
  current,
}: {
  /** `undefined` mientras cargan: el panel muestra las herramientas igual. */
  campaigns: readonly DmCampaign[] | undefined;
  current?: { campaign: DmCampaign; section: DmSection };
}) {
  const t = useTexts();
  const groups = campaigns ? groupCampaigns(campaigns) : null;
  const item = (c: DmCampaign) => (
    <li key={c.id}>
      <NavItem
        href={dmCampaignHref(c.id)}
        icon={BookOpen}
        label={c.name}
        active={c.id === current?.campaign.id}
        internal
      />
    </li>
  );
  return (
    <>
      <ModeSwitch mode="dm" playerHref={rosterHref()} dmHref={dmHref()} />

      <NavGroup label={t.dmToolsLabel}>
        <li>
          <NavItem href={FLUTTER_HOME} icon={PawPrint} label={t.navBestiary} external />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={Contact} label={t.dmNpcLibrary} external />
        </li>
        <li>
          <NavItem href={FLUTTER_HOME} icon={FlaskConical} label={t.navHomebrew} external />
        </li>
      </NavGroup>

      {groups && (
        <nav aria-label={t.dmCampaignsLabel} className="flex flex-col gap-2">
          {groups.active.length > 0 && (
            <div>
              <p className="eyebrow px-3 pt-1 pb-1.5">{t.campaignStateActive}</p>
              <ul className="flex flex-col gap-0.5">{groups.active.map(item)}</ul>
            </div>
          )}
          {groups.paused.length > 0 && (
            <div>
              <p className="eyebrow px-3 pt-1 pb-1.5">{t.campaignStatePaused}</p>
              <ul className="flex flex-col gap-0.5">{groups.paused.map(item)}</ul>
            </div>
          )}
          {groups.finished.length > 0 && (
            // Las terminadas se pliegan, salvo que la campaña elegida sea una
            // de ellas: la `key` la vuelve a abrir al elegirla.
            <NavCollapsible
              key={current && stateOf(current.campaign) === 'finished' ? current.campaign.id : 'none'}
              label={t.dmFinishedGroup(groups.finished.length)}
              defaultOpen={current !== undefined && stateOf(current.campaign) === 'finished'}
            >
              <ul className="flex flex-col gap-0.5">{groups.finished.map(item)}</ul>
            </NavCollapsible>
          )}
        </nav>
      )}

      {current && (
        <>
          <div className="mx-3 h-px bg-hairline" aria-hidden="true" />
          <NavGroup label={t.dmSectionsLabel} title={t.dmCurrentCampaign}>
            <li>
              <NavItem
                href={dmCampaignHref(current.campaign.id, 'mesa')}
                icon={Users}
                label={t.dmSectionTable}
                active={current.section === 'mesa'}
                internal
              />
            </li>
            <li>
              <NavItem
                href={dmCampaignHref(current.campaign.id, 'capitulos')}
                icon={BookMarked}
                label={t.dmSectionChapters}
                active={current.section === 'capitulos'}
                internal
              />
            </li>
            <li>
              <NavItem
                href={dmCampaignHref(current.campaign.id, 'cuaderno')}
                icon={NotebookText}
                label={t.dmSectionNotebook}
                active={current.section === 'cuaderno'}
                internal
              />
            </li>
            <li>
              <NavItem href={FLUTTER_HOME} icon={UsersRound} label={t.dmSectionNpcs} external />
            </li>
            <li>
              <NavItem href={FLUTTER_HOME} icon={Flame} label={t.dmSectionCombat} external />
            </li>
          </NavGroup>
        </>
      )}
    </>
  );
}
