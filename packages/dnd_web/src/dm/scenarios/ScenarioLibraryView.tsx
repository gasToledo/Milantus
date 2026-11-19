import { useMemo, useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, ChevronRight, Expand, MapPin, Pencil, Plus, Search, Trash2 } from 'lucide-react';
import {
  deleteScenario, scenarioCharacterId, scenarioCharacterPortrait, scenarioCharactersQuery, scenarioImageHref,
  scenarioQuery, scenariosQuery, type Scenario, type ScenarioCharacter,
} from '../../api/scenarios';
import { ApiError } from '../../api/client';
import { fold } from '../../codex/entries';
import { useTexts } from '../../i18n/context';
import { dmMemberHref, dmNpcsHref, dmScenariosHref, Link, navigate } from '../../router';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { useListTransition } from '../../ui/listTransition';
import { Medallion } from '../../ui/Medallion';
import { PortraitViewer } from '../../ui/PortraitViewer';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { LibraryTabs } from '../LibraryTabs';
import { FilterPill } from '../npcs/NpcLibraryView';
import { ScenarioEditorDialog } from './ScenarioEditorDialog';

export function ScenarioLibraryView({ scenarioId }: { scenarioId: string | null }) {
  return scenarioId === null ? <ScenarioList /> : <ScenarioPage id={scenarioId} />;
}

/** La portada de la tarjeta y la de la ficha comparten nombre: al abrir un
 *  escenario, el fundido de pantalla la hace crecer de una a otra en vez de
 *  cruzarlas (`.scenario-cover` en `index.css`). */
const coverName = (id: string) => `scover-${id.replace(/[^\w-]/g, '_')}`;

/** Los personajes de cada escenario que todavía existen. Una clave vencida (el
 *  PNJ se borró, el jugador cortó el vínculo) simplemente no aparece. */
function useLinked(scenarios: readonly Scenario[] | undefined) {
  const needed = !!scenarios?.some((scenario) => scenario.characterKeys.length > 0);
  const characters = useQuery({ ...scenarioCharactersQuery, enabled: needed });
  const byKey = useMemo(() => new Map((characters.data ?? []).map((c) => [c.key, c])), [characters.data]);
  const linked = (scenario: Scenario) =>
    scenario.characterKeys.map((key) => byKey.get(key)).filter((c): c is ScenarioCharacter => c !== undefined);
  return { characters, linked };
}

function ScenarioList() {
  const t = useTexts();
  const scenarios = useQuery(scenariosQuery);
  const { linked } = useLinked(scenarios.data);
  const searchRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState('');
  const [listQuery, setListQuery] = useState('');
  const [campaign, setCampaign] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  // Las campañas salen de los personajes vinculados: la de un miembro y las de
  // un PNJ. Un escenario aparece en cada campaña donde está alguno de los suyos.
  const entries = (scenarios.data ?? []).map((scenario) => {
    const people = linked(scenario);
    const campaigns = new Map(people.flatMap((c) => c.campaigns).map((c) => [c.id, c.name]));
    return { scenario, people, campaigns };
  });
  const campaignOptions = [...new Map(entries.flatMap(({ campaigns }) => [...campaigns])).entries()]
    .map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.name.localeCompare(b.name));
  const search = fold(listQuery.trim());
  const visible = entries.filter(({ scenario, campaigns }) =>
    fold(scenario.name).includes(search) && (campaign === null || campaigns.has(campaign)));
  const animateList = useListTransition(visible.map(({ scenario }) => scenario.id).join());

  const clear = () => {
    setQuery('');
    searchRef.current?.focus();
    animateList(() => {
      setListQuery('');
      setCampaign(null);
    });
  };

  const create = <Button icon={Plus} onClick={() => setCreating(true)}>{t.dmScenarioNew}</Button>;
  const empty = scenarios.data?.length === 0;

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmLibrary} actions={scenarios.data && !empty ? create : undefined} />
      <LibraryTabs active="scenarios">
        {scenarios.isError ? (
          <AppErrorView title={t.dmScenarioLoadError} onRetry={() => scenarios.refetch()} />
        ) : !scenarios.data ? (
          <AppBusyLabel label={t.dmScenariosLoading} />
        ) : empty ? (
          <AppEmptyState kind="empty" message={t.dmScenariosEmpty} actions={create} />
        ) : (
          <>
            <div className="flex flex-wrap items-center gap-2">
              <div role="search" className="relative min-w-[min(220px,100%)] max-w-[280px] flex-[1_1_220px]">
                <label htmlFor="scenario-search" className="sr-only">{t.dmSearchByName}</label>
                <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
                <input
                  id="scenario-search"
                  ref={searchRef}
                  type="search"
                  autoComplete="off"
                  value={query}
                  onChange={(event) => {
                    const value = event.target.value;
                    setQuery(value);
                    animateList(() => setListQuery(value));
                  }}
                  placeholder={t.dmSearchByName}
                  className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-3 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
                />
              </div>
              {campaignOptions.length > 0 && (
                <div role="group" aria-label={t.dmCampaignFilter} className="flex flex-wrap gap-1.5">
                  <FilterPill label={t.codexAll} count={entries.length} pressed={campaign === null} onClick={() => animateList(() => setCampaign(null))} />
                  {campaignOptions.map((c) => (
                    <FilterPill
                      key={c.id}
                      label={c.name}
                      count={entries.filter(({ campaigns }) => campaigns.has(c.id)).length}
                      pressed={campaign === c.id}
                      onClick={() => animateList(() => setCampaign(c.id))}
                    />
                  ))}
                </div>
              )}
            </div>
            {visible.length === 0 ? (
              <AppEmptyState
                kind="no-match"
                message={listQuery.trim() ? t.dmScenarioNoMatches(listQuery.trim()) : t.catalogNoMatches}
                actions={<Button tone="secondary" onClick={clear}>{t.codexClearFilters}</Button>}
              />
            ) : (
              <ul aria-label={t.dmLibraryScenarios} className="grid grid-cols-1 gap-3.5 sm:grid-cols-2 lg:grid-cols-3">
                {visible.map(({ scenario, people }) => (
                  <li key={scenario.id} data-vt-card className="min-w-0" style={{ viewTransitionName: `sc-${scenario.id.replace(/[^\w-]/g, '_')}` }}>
                    <ScenarioCard scenario={scenario} people={people} />
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

/** Toda la tarjeta es un solo destino: el enlace envuelve al artículo y adentro
 *  no hay otro control. */
function ScenarioCard({ scenario, people }: { scenario: Scenario; people: readonly ScenarioCharacter[] }) {
  const t = useTexts();
  return (
    <Link
      href={dmScenariosHref(scenario.id)}
      className="card group flex h-full flex-col overflow-hidden transition-colors duration-[120ms] ease-out hover:border-gold focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold"
    >
      <article className="flex h-full flex-col">
        {scenario.hasImage ? (
          <img
            src={scenarioImageHref(scenario)}
            alt=""
            loading="lazy"
            className="scenario-cover aspect-video w-full border-b border-hairline bg-plaque object-cover"
            style={{ viewTransitionName: coverName(scenario.id) }}
          />
        ) : (
          <div className="flex aspect-video items-center justify-center border-b border-hairline bg-plaque text-text-muted">
            <MapPin size={30} strokeWidth={1.6} aria-hidden="true" />
          </div>
        )}
        <div className="flex flex-1 flex-col gap-1.5 px-4 pt-3.5 pb-4">
          <h2 className="font-display text-[19px] leading-tight font-normal break-words text-on-surface transition-colors duration-[120ms] ease-out group-hover:text-gold">
            {scenario.name}
          </h2>
          {scenario.description && (
            <p className="line-clamp-2 text-[13.5px] leading-normal break-words text-on-surface-variant">{scenario.description}</p>
          )}
          <div className="mt-auto flex min-h-[26px] items-center gap-2.5 pt-2.5">
            {people.length > 0 && (
              <span aria-hidden="true" className="flex">
                {people.slice(0, 3).map((character, index) => (
                  <span key={character.key} className={`rounded-full ring-2 ring-surface ${index > 0 ? '-ml-[7px]' : ''}`}>
                    <Medallion name={character.name} accent={null} size={26} portrait={scenarioCharacterPortrait(character)} />
                  </span>
                ))}
              </span>
            )}
            <span className="min-w-0 truncate text-[12.5px] text-text-muted">
              {t.dmScenarioPeople(people.map((character) => character.name))}
            </span>
          </div>
        </div>
      </article>
    </Link>
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
    <div className="flex flex-col gap-4">
      <Link href={dmScenariosHref()} className="inline-flex items-center gap-1.5 self-start text-[13.5px] text-on-surface-variant hover:text-gold">
        <ArrowLeft size={16} aria-hidden="true" />{t.dmLibraryScenarios}
      </Link>
      <DmHeader title={scenario?.name ?? t.dmLibraryScenarios} actions={scenario && (
        <>
          <Button tone="secondary" icon={Pencil} onClick={() => setEditing(true)}>{t.commonEdit}</Button>
          <Button tone="secondary" icon={Trash2} onClick={() => { setDeleteError(false); setDeleting(true); }}>{t.commonDelete}</Button>
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
            { label: deleteError ? t.retry : t.commonDelete, primary: true, tone: 'crimson', closes: false, disabled: busy, onSelect: () => void remove() },
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
  const { characters, linked } = useLinked([scenario]);
  const people = linked(scenario);
  const [viewing, setViewing] = useState(false);
  const cover = scenarioImageHref(scenario);

  return (
    <>
      {scenario.hasImage && (
        <figure className="relative m-0 h-[clamp(200px,32vw,340px)] overflow-hidden rounded-[var(--radius-card)] border border-hairline bg-plaque">
          <img
            src={cover}
            alt={t.dmScenarioCoverOf(scenario.name)}
            fetchPriority="high"
            className="scenario-cover h-full w-full object-cover"
            style={{ viewTransitionName: coverName(scenario.id) }}
          />
          <button
            type="button"
            aria-label={t.dmScenarioViewCover}
            title={t.dmScenarioViewCover}
            onClick={() => setViewing(true)}
            className="absolute right-3 bottom-3 flex h-10 w-10 items-center justify-center rounded-[var(--radius-nav)] border border-hairline bg-plaque text-on-surface hover:border-gold"
          >
            <Expand size={16} aria-hidden="true" />
          </button>
          <PortraitViewer src={cover} name={scenario.name} open={viewing} onOpenChange={setViewing} />
        </figure>
      )}
      <div className={`grid items-start gap-4 ${scenario.description ? 'lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]' : ''}`}>
        {scenario.description && (
          <section aria-label={t.dmScenarioDescription} className="card px-[22px] py-5">
            <p className="text-[14.5px] leading-[1.65] break-words whitespace-pre-wrap text-on-surface">{scenario.description}</p>
          </section>
        )}
        <section aria-labelledby="scenario-people" className="card px-2.5 pt-4 pb-2.5">
          <div className="flex items-baseline justify-between px-3 pb-1.5">
            <h2 id="scenario-people" className="font-display text-[18px] font-normal text-on-surface">{t.dmScenarioCharacters}</h2>
            {people.length > 0 && <span className="text-[12.5px] text-text-muted tabular-nums">{people.length}</span>}
          </div>
          {characters.isError && scenario.characterKeys.length > 0 ? (
            <AppErrorView title={t.dmScenarioCharactersError} onRetry={() => characters.refetch()} />
          ) : characters.isLoading ? (
            <div className="px-3 pb-2"><AppBusyLabel label={t.dmScenarioCharactersLoading} /></div>
          ) : people.length === 0 ? (
            <p className="px-3 pb-2 text-[13.5px] text-text-muted">{t.dmScenarioPeople([])}</p>
          ) : (
            <ul className="flex flex-col">
              {people.map((character) => {
                const target = scenarioCharacterId(character);
                return (
                  <li key={character.key}>
                    <Link
                      href={character.campaignId === null ? dmNpcsHref(target) : dmMemberHref(character.campaignId, target)}
                      className="group flex items-center gap-3 rounded-[var(--radius-nav)] px-3 py-2.5 transition-colors duration-[120ms] ease-out hover:bg-plaque focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold"
                    >
                      <Medallion name={character.name} accent={null} size={38} portrait={scenarioCharacterPortrait(character)} />
                      <span className="min-w-0 flex-1">
                        <span className="block text-[14.5px] break-words text-on-surface group-hover:text-gold">{character.name}</span>
                        <span className="block text-[12.5px] text-text-muted">{character.campaignName ?? t.dmLibraryNpcs}</span>
                      </span>
                      <ChevronRight size={16} aria-hidden="true" className="shrink-0 text-text-muted" />
                    </Link>
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      </div>
    </>
  );
}
