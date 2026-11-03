import { useRoster } from '../api/queries';
import type { Account } from '../api/client';
import { RosterFooter } from '../dashboard/RosterPanel';
import { useTexts } from '../i18n/context';
import { rosterHref } from '../router';
import { Shell, SidebarBack } from '../ui/Shell';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';
import { CreationPage } from './CreationWizard';

/** `/personajes/:id/rehacer`: el creador con el personaje de [id] por rehacer.
 *  Lo ajeno y lo inexistente son lo mismo para la API y acá también. */
export function RebuildPage({ id, account }: { id: string; account: Account }) {
  const t = useTexts();
  const roster = useRoster();
  const character = roster.data?.find((c) => c.character.id === id)?.character;
  if (character) return <CreationPage account={account} replacing={character as typeof character & { id: string }} />;
  return (
    <Shell panel={<SidebarBack href={rosterHref()} label={t.backToCharacters} />} footer={<RosterFooter account={account} />}>
      {roster.isError ? (
        <AppErrorView as="h1" title={t.errorTitle} message={t.errorBody} onRetry={() => void roster.refetch()} />
      ) : roster.data ? (
        <Notice title={t.notFoundTitle} body={t.notFoundBody} />
      ) : (
        <AppBusyLabel label={t.loading} />
      )}
    </Shell>
  );
}
