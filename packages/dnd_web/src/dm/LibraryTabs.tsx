import type { ReactNode } from 'react';
import { MapPin, ScrollText, User } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { dmNpcsHref, dmScenariosHref, dmScriptsHref } from '../router';
import { LinkTabs, TabPanel } from '../ui/disclosure';

export function LibraryTabs({ active, children }: { active: 'npcs' | 'scenarios' | 'scripts'; children: ReactNode }) {
  const t = useTexts();
  const tabs = [
    { value: 'npcs', label: t.dmLibraryNpcs, href: dmNpcsHref(), icon: User },
    { value: 'scenarios', label: t.dmLibraryScenarios, href: dmScenariosHref(), icon: MapPin },
    { value: 'scripts', label: t.scLibraryTab, href: dmScriptsHref(), icon: ScrollText },
  ];
  return (
    <LinkTabs label={t.dmLibrary} value={active} tabs={tabs}>
      <TabPanel value={active} className="flex flex-col gap-5 pt-5">{children}</TabPanel>
    </LinkTabs>
  );
}
