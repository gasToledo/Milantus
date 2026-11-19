import type { ReactNode } from 'react';
import { MapPin, User } from 'lucide-react';
import { useTexts } from '../i18n/context';
import { dmNpcsHref, dmScenariosHref } from '../router';
import { LinkTabs, TabPanel } from '../ui/disclosure';

export function LibraryTabs({ active, children }: { active: 'npcs' | 'scenarios'; children: ReactNode }) {
  const t = useTexts();
  const tabs = [
    { value: 'npcs', label: t.dmLibraryNpcs, href: dmNpcsHref(), icon: User },
    { value: 'scenarios', label: t.dmLibraryScenarios, href: dmScenariosHref(), icon: MapPin },
  ];
  return (
    <LinkTabs label={t.dmLibrary} value={active} tabs={tabs}>
      <TabPanel value={active} className="flex flex-col gap-5 pt-5">{children}</TabPanel>
    </LinkTabs>
  );
}
