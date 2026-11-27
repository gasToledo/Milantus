import type { ReactNode } from 'react';
import { useTexts } from '../../i18n/context';
import { dmChapterHref, type ChapterTab } from '../../router';
import { LinkTabs, TabPanel } from '../../ui/disclosure';

/** Las pestañas de la página de un capítulo. */
export function ChapterTabs({
  campaignId,
  chapterId,
  active,
  children,
}: {
  campaignId: string;
  chapterId: string;
  active: ChapterTab;
  children: ReactNode;
}) {
  const t = useTexts();
  const tabs = [
    { value: 'guion', label: t.scTab, href: dmChapterHref(campaignId, chapterId, 'guion') },
    { value: 'registro', label: t.scLogTab, href: dmChapterHref(campaignId, chapterId, 'registro') },
  ];
  return (
    <LinkTabs label={t.scChapterTabs} value={active} tabs={tabs}>
      <TabPanel value={active} className="flex flex-col gap-5 pt-5">
        {children}
      </TabPanel>
    </LinkTabs>
  );
}
