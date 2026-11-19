import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, MapPin, Pencil, Plus, Trash2 } from 'lucide-react';
import {
  deleteScenario, scenarioCharactersQuery, scenarioImageHref, scenarioQuery, scenariosQuery,
  type Scenario,
} from '../../api/scenarios';
import { ApiError } from '../../api/client';
import { fold } from '../../codex/entries';
import { useTexts } from '../../i18n/context';
import { dmMemberHref, dmNpcsHref, dmScenariosHref, Link, navigate } from '../../router';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { LibraryTabs } from '../LibraryTabs';
import { ScenarioEditorDialog } from './ScenarioEditorDialog';

export function ScenarioLibraryView({ scenarioId }: { scenarioId: string | null }) {
  return scenarioId === null ? <ScenarioList /> : <ScenarioPage id={scenarioId} />;
}

function ScenarioList() {
  const t = useTexts();
  const scenarios = useQuery(scenariosQuery);
  const [search, setSearch] = useState('');
  const [creating, setCreating] = useState(false);
  const query = fold(search.trim());
  const filtered = scenarios.data?.filter((scenario) => fold(scenario.name).includes(query));
  const create = <Button icon={Plus} onClick={() => setCreating(true)}>{t.dmScenarioNew}</Button>;

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmLibrary} actions={create} />
      <LibraryTabs active="scenarios">
      {scenarios.isError ? (
        <AppErrorView title={t.dmScenarioLoadError} onRetry={() => scenarios.refetch()} />
      ) : !filtered ? (
        <AppBusyLabel label={t.dmScenariosLoading} />
      ) : !scenarios.data?.length ? (
        <AppEmptyState kind="empty" message={t.dmScenariosEmpty} />
      ) : (
        <>
          <input
            type="search"
            className="plaque h-10 w-full max-w-sm px-3 text-sm"
            aria-label={t.dmScenarioSearch}
            placeholder={t.dmScenarioSearch}
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
          {filtered.length === 0 ? (
            <AppEmptyState kind="no-match" message={t.catalogNoMatches} />
          ) : (
            <ul className="grid grid-cols-1 gap-3.5 sm:grid-cols-2 xl:grid-cols-3">
              {filtered.map((scenario) => (
                <li key={scenario.id} className="min-w-0">
                  <Link href={dmScenariosHref(scenario.id)} className="card group block overflow-hidden hover:border-gold">
                    {scenario.hasImage ? (
                      <img src={scenarioImageHref(scenario)} alt="" loading="lazy" className="aspect-video w-full bg-plaque object-cover" />
                    ) : (
                      <div className="flex aspect-video items-center justify-center bg-plaque text-text-muted">
                        <MapPin size={28} aria-hidden="true" />
                      </div>
                    )}
                    <div className="space-y-1.5 p-4">
                      <h2 className="font-display text-lg break-words text-on-surface group-hover:text-gold">{scenario.name}</h2>
                      {scenario.description && (
                        <p className="line-clamp-2 text-sm break-words text-on-surface-variant">{scenario.description}</p>
                      )}
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
      </LibraryTabs>
      {creating && (
        <ScenarioEditorDialog onClose={() => setCreating(false)} onSaved={(scenario) => navigate(dmScenariosHref(scenario.id))} />
      )}
    </div>
  );
}

function ScenarioPage({ id }: { id: string }) {
  const t = useTexts();
  const client = useQueryClient();
  const query = useQuery(scenarioQuery(id));
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [busy, setBusy] = useState(false);
  const [deleteError, setDeleteError] = useState(false);
  const scenario = query.data;

  const remove = async () => {
    if (busy) return;
    setBusy(true);
    try {
      await deleteScenario(id);
      client.setQueryData(scenariosQuery.queryKey, (previous) => previous?.filter((entry) => entry.id !== id));
      void client.invalidateQueries({ queryKey: scenariosQuery.queryKey });
      void client.invalidateQueries({ queryKey: scenarioQuery(id).queryKey });
      navigate(dmScenariosHref(), { replace: true });
    } catch {
      setBusy(false);
      setDeleteError(true);
    }
  };

  return (
    <div className="flex flex-col gap-5">
      <Link href={dmScenariosHref()} className="inline-flex items-center gap-1.5 self-start text-sm text-on-surface-variant hover:text-gold">
        <ArrowLeft size={16} aria-hidden="true" />{t.dmLibraryScenarios}
      </Link>
      <DmHeader title={scenario?.name ?? t.dmLibraryScenarios} actions={scenario && (
        <>
          <Button tone="secondary" icon={Pencil} onClick={() => setEditing(true)}>{t.dmScenarioEdit}</Button>
          <Button tone="secondary" icon={Trash2} onClick={() => { setDeleteError(false); setDeleting(true); }}>{t.dmScenarioDelete}</Button>
        </>
      )} />
      {query.isError ? (
        <AppErrorView
          title={query.error instanceof ApiError && query.error.status === 404 ? t.dmScenarioNotFound : t.dmScenarioLoadError}
          onRetry={() => query.refetch()}
        />
      ) : !scenario ? (
        <AppBusyLabel label={t.dmScenariosLoading} />
      ) : (
        <ScenarioDetails scenario={scenario} />
      )}
      {editing && scenario && (
        <ScenarioEditorDialog initial={scenario} onClose={() => setEditing(false)} />
      )}
      {deleting && scenario && (
        <AppDialog
          open
          onOpenChange={(open) => { if (!open && !busy) setDeleting(false); }}
          title={t.dmScenarioDelete}
          description={t.dmScenarioDeleteConfirm(scenario.name)}
          actions={[
            { label: t.cancel, disabled: busy },
            { label: deleteError ? t.retry : t.dmScenarioDelete, primary: true, tone: 'crimson', closes: false, disabled: busy, onSelect: () => void remove() },
          ]}
        >
          {deleteError && <p role="alert" className="text-sm text-crimson">{t.dmScenarioDeleteError}</p>}
        </AppDialog>
      )}
    </div>
  );
}

function ScenarioDetails({ scenario }: { scenario: Scenario }) {
  const t = useTexts();
  const characters = useQuery({ ...scenarioCharactersQuery, enabled: scenario.characterKeys.length > 0 });
  const linked = characters.data?.filter(({ key }) => scenario.characterKeys.includes(key)) ?? [];

  return (
    <article className="card max-w-4xl space-y-5 p-4 sm:p-6">
      {scenario.hasImage && (
        <img
          src={scenarioImageHref(scenario)}
          alt={t.dmScenarioCoverOf(scenario.name)}
          className="max-h-[60vh] w-full rounded-[var(--radius-nav)] bg-plaque object-contain"
        />
      )}
      {scenario.description && <p className="text-sm leading-relaxed break-words whitespace-pre-wrap">{scenario.description}</p>}
      <section className="space-y-2">
        <h2 className="font-display text-lg text-on-surface">{t.dmScenarioCharacters}</h2>
        {characters.isError && scenario.characterKeys.length > 0 ? (
          <AppErrorView title={t.dmScenarioCharactersError} onRetry={() => characters.refetch()} />
        ) : characters.isLoading ? (
          <AppBusyLabel label={t.dmScenarioCharactersLoading} />
        ) : linked.length === 0 ? (
          <p className="text-sm text-text-muted">{t.dmScenarioNoCharacters}</p>
        ) : (
          <ul className="flex flex-wrap gap-2">
            {linked.map(({ key, name, campaignId, campaignName }) => {
              const id = key.slice(key.indexOf(':') + 1);
              return (
                <li key={key}>
                  <Link
                    href={campaignId === null ? dmNpcsHref(id) : dmMemberHref(campaignId, id)}
                    className="plaque inline-flex flex-wrap items-baseline gap-2 px-3 py-2 text-sm text-gold hover:underline"
                  >
                    {name}
                    {campaignName && <span className="text-xs text-text-muted">{campaignName}</span>}
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </article>
  );
}
