import { useMemo, useRef, useState, type CSSProperties } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, ChevronRight, EllipsisVertical, Expand, MapPin, Pencil, Plus, ScrollText, Search, Trash2, Users } from 'lucide-react';
import {
  deleteScenario, scenarioCharacterId, scenarioCharacterPortrait, scenarioCharactersQuery, scenarioImageHref,
  scenarioQuery, scenariosQuery, type Scenario, type ScenarioCharacter,
} from '../../api/scenarios';
import { ApiError, type RosterSettings } from '../../api/client';
import { queryKeys, useRosterSettings } from '../../api/queries';
import { patchSettings } from '../../api/settingsSave';
import { fold } from '../../codex/entries';
import { movedOrder } from '../../dashboard/roster';
import { useTexts } from '../../i18n/context';
import { dmMemberHref, dmNpcsHref, dmScenariosHref, Link, navigate } from '../../router';
import { Button } from '../../ui/Button';
import { Card } from '../../ui/Card';
import { ConfirmDialog } from '../../ui/ConfirmDialog';
import { cx } from '../../ui/cx';
import { useHoldDrag } from '../../ui/holdDrag';
import { useListTransition, vtName } from '../../ui/listTransition';
import { Medallion } from '../../ui/Medallion';
import { PortraitViewer } from '../../ui/PortraitViewer';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Toast, Tooltip } from '../../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { LibraryTabs } from '../LibraryTabs';
import { FilterPill } from '../npcs/NpcLibraryView';
import { ScenarioEditorDialog } from './ScenarioEditorDialog';

// La pantalla sigue a la de PNJ, que es la referencia de la Biblioteca: la
// misma tarjeta (`.roster-card`, se levanta y se arrastra), la misma cabecera
// de ficha (ícono para editar y ⋮ para borrar) y las mismas `Card` con título.

const ICON_BUTTON = 'inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold';

export function ScenarioLibraryView({ scenarioId }: { scenarioId: string | null }) {
  return scenarioId === null ? <ScenarioList /> : <ScenarioPage id={scenarioId} />;
}

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
  const client = useQueryClient();
  const scenarios = useQuery(scenariosQuery);
  const settings = useRosterSettings();
  const { linked } = useLinked(scenarios.data);
  const searchRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState('');
  const [listQuery, setListQuery] = useState('');
  const [campaign, setCampaign] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [orderFailed, setOrderFailed] = useState(0);

  // En el orden del DM (`scenarioOrder` de los ajustes, como `npcOrder`): lo
  // que no figura va al final, en el orden del servidor. Las campañas salen de
  // los personajes vinculados: la de un miembro y las de un PNJ.
  const order = settings.data?.scenarioOrder;
  const rank = (id: string) => {
    const i = order?.indexOf(id) ?? -1;
    return i < 0 ? Number.MAX_SAFE_INTEGER : i;
  };
  const entries = (scenarios.data ?? [])
    .map((scenario) => {
      const people = linked(scenario);
      const campaigns = new Map(people.flatMap((c) => c.campaigns).map((c) => [c.id, c.name]));
      return { scenario, people, campaigns };
    })
    .sort((a, b) => rank(a.scenario.id) - rank(b.scenario.id));
  const campaignOptions = [...new Map(entries.flatMap(({ campaigns }) => [...campaigns])).entries()]
    .map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.name.localeCompare(b.name));
  const search = fold(listQuery.trim());
  const visible = entries.filter(({ scenario, campaigns }) =>
    fold(scenario.name).includes(search) && (campaign === null || campaigns.has(campaign)));
  const visibleIds = visible.map(({ scenario }) => scenario.id);
  const animateList = useListTransition(visibleIds.join('\n'));

  // Con un filtro puesto no se mueven, como los PNJ: soltar entre dos
  // filtrados no dice dónde quedan respecto de los ocultos. Se ve al instante
  // y se guarda después; si falla, se relee lo guardado.
  const canMove = listQuery.trim() === '' && campaign === null;
  const move = (from: string, to: string) => {
    const next = movedOrder(visibleIds, from, to);
    void (async () => {
      await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
      client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (old) => old && { ...old, scenarioOrder: next });
      try {
        await patchSettings({ scenarioOrder: next });
      } catch {
        setOrderFailed((n) => n + 1);
        void client.invalidateQueries({ queryKey: queryKeys.rosterSettings });
      }
    })();
  };
  const reorder = useHoldDrag({ ids: canMove ? visibleIds : [], canDrop: () => canMove, onMove: move });

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
                  <ScenarioCard
                    key={scenario.id}
                    scenario={scenario}
                    people={people}
                    reorder={
                      canMove
                        ? {
                            item: reorder.item(scenario.id),
                            dragging: reorder.dragging === scenario.id,
                            over: reorder.over === scenario.id,
                            animated: reorder.animated,
                          }
                        : undefined
                    }
                  />
                ))}
              </ul>
            )}
          </>
        )}
      </LibraryTabs>
      {creating && (
        <ScenarioEditorDialog onClose={() => setCreating(false)} onSaved={(scenario) => navigate(dmScenariosHref(scenario.id))} />
      )}
      {orderFailed > 0 && (
        <Toast key={orderFailed} tone="error" message={t.dmOrderSaveError} open onOpenChange={(open) => !open && setOrderFailed(0)} />
      )}
    </div>
  );
}

/** La tarjeta de un escenario, hecha como la de un PNJ: se levanta al pasar el
 *  mouse, se arrastra tomándola entera y el enlace ocupa toda la tarjeta. */
function ScenarioCard({ scenario, people, reorder }: {
  scenario: Scenario;
  people: readonly ScenarioCharacter[];
  reorder?: { item: Record<string, unknown>; dragging: boolean; over: boolean; animated: boolean };
}) {
  const t = useTexts();
  return (
    <li
      className={cx(
        'card roster-card min-w-0',
        reorder && 'select-none [-webkit-touch-callout:none]',
        reorder?.dragging && (reorder.animated ? 'cursor-grabbing border-gold [&_*]:cursor-grabbing' : 'opacity-40'),
        reorder?.over && !reorder.animated && 'outline-2 outline-offset-1 outline-gold',
      )}
      data-scenario={scenario.id}
      {...reorder?.item}
      // Después del `item`, que trae su `style` para el arrastre.
      style={{
        viewTransitionName: vtName('sc', scenario.id),
        ...(reorder?.item.style as CSSProperties | undefined),
      }}
    >
      <Link
        href={dmScenariosHref(scenario.id)}
        draggable={false}
        className="flex h-full flex-col overflow-hidden rounded-[inherit]"
      >
        {scenario.hasImage ? (
          <img
            src={scenarioImageHref(scenario)}
            alt=""
            loading="lazy"
            draggable={false}
            className="aspect-video w-full border-b border-hairline bg-plaque object-cover"
          />
        ) : (
          <span className="flex aspect-video items-center justify-center border-b border-hairline bg-plaque text-text-muted">
            <MapPin size={30} strokeWidth={1.6} aria-hidden="true" />
          </span>
        )}
        <span className="flex flex-1 flex-col gap-2.5 p-3.5">
          <span className="flex flex-col gap-1">
            <span className="font-display block text-[17px] leading-tight break-words text-on-surface">{scenario.name}</span>
            {scenario.description && (
              <span className="line-clamp-2 text-[13px] leading-normal break-words text-on-surface-variant">{scenario.description}</span>
            )}
          </span>
          <span
            className={cx(
              'mt-auto flex min-w-0 items-center gap-2.5 border-t border-hairline pt-2 text-[12.5px]',
              people.length === 0 ? 'text-text-muted italic' : 'text-on-surface',
            )}
          >
            {people.length > 0 && (
              <span aria-hidden="true" className="flex shrink-0">
                {people.slice(0, 3).map((character, index) => (
                  <span key={character.key} className={cx('rounded-full ring-2 ring-surface', index > 0 && '-ml-[7px]')}>
                    <Medallion name={character.name} accent={null} size={24} portrait={scenarioCharacterPortrait(character)} />
                  </span>
                ))}
              </span>
            )}
            <span className="min-w-0 truncate">{t.dmScenarioPeople(people.map((character) => character.name))}</span>
          </span>
        </span>
      </Link>
    </li>
  );
}

function ScenarioPage({ id }: { id: string }) {
  const t = useTexts();
  const client = useQueryClient();
  const query = useQuery({
    ...scenarioQuery(id),
    // Al llegar desde la lista el escenario ya está en caché: con él la ficha
    // se dibuja dentro del fundido de pantalla, en vez de fundirse a
    // «Cargando…» y saltar a la ficha un momento después.
    initialData: () => client.getQueryData(scenariosQuery.queryKey)?.find((entry) => entry.id === id),
    initialDataUpdatedAt: () => client.getQueryState(scenariosQuery.queryKey)?.dataUpdatedAt,
  });
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const scenario = query.data;

  const remove = async () => {
    await deleteScenario(id);
    client.setQueryData(scenariosQuery.queryKey, (previous) => previous?.filter((entry) => entry.id !== id));
    navigate(dmScenariosHref(), { replace: true });
    client.removeQueries({ queryKey: scenarioQuery(id).queryKey });
    void client.invalidateQueries({ queryKey: scenariosQuery.queryKey });
  };

  const back = (
    <Link back href={dmScenariosHref()} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.luBack}
    </Link>
  );

  if (query.isError || !scenario) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        {query.isError ? (
          <AppErrorView
            as="h1"
            title={query.error instanceof ApiError && query.error.status === 404 ? t.dmScenarioNotFound : t.dmScenarioLoadError}
            onRetry={() => query.refetch()}
          />
        ) : (
          <>
            <h1 className="sr-only">{t.dmLibraryScenarios}</h1>
            <AppBusyLabel label={t.dmScenariosLoading} />
          </>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-5" data-scenario={scenario.id}>
      {back}
      <header className="flex items-start gap-x-[18px]">
        <h1 data-dm-title tabIndex={-1} className="font-display min-w-0 flex-1 text-[28px] leading-tight break-words text-on-surface outline-none">
          {scenario.name}
        </h1>
        <div className="flex gap-1">
          <Tooltip content={t.dmScenarioEdit}>
            <button type="button" aria-label={t.dmScenarioEdit} data-action="scenario-edit" onClick={() => setEditing(true)} className={ICON_BUTTON}>
              <Pencil size={18} aria-hidden="true" />
            </button>
          </Tooltip>
          <DropdownMenu>
            <Tooltip content={t.npcMoreActions}>
              <DropdownMenuTrigger asChild>
                <button
                  type="button"
                  aria-label={t.npcMoreActions}
                  data-action="scenario-menu"
                  className="inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
                >
                  <EllipsisVertical size={20} aria-hidden="true" />
                </button>
              </DropdownMenuTrigger>
            </Tooltip>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onSelect={() => setDeleting(true)} className="text-crimson">
                <Trash2 size={15} aria-hidden="true" />
                {t.dmScenarioDelete}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </header>
      <ScenarioDetails scenario={scenario} />
      {editing && <ScenarioEditorDialog initial={scenario} onClose={() => setEditing(false)} />}
      {deleting && (
        <ConfirmDialog
          title={t.dmScenarioDeleteTitle(scenario.name)}
          body={t.dmScenarioDeleteBody}
          confirmLabel={t.dmScenarioDelete}
          errorText={t.dmScenarioDeleteError}
          onConfirm={remove}
          onClose={() => setDeleting(false)}
        />
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
          <img src={cover} alt={t.dmScenarioCoverOf(scenario.name)} fetchPriority="high" className="h-full w-full object-cover" />
          <Tooltip content={t.dmScenarioViewCover}>
            <button
              type="button"
              aria-label={t.dmScenarioViewCover}
              onClick={() => setViewing(true)}
              className="absolute right-3 bottom-3 flex h-10 w-10 items-center justify-center rounded-[var(--radius-nav)] border border-hairline bg-plaque text-on-surface hover:border-gold"
            >
              <Expand size={16} aria-hidden="true" />
            </button>
          </Tooltip>
          <PortraitViewer src={cover} name={scenario.name} open={viewing} onOpenChange={setViewing} />
        </figure>
      )}
      {/* Las dos columnas de la ficha de un PNJ: el texto se estira y la
          columna de al lado topea en 380 px; en angosto, una debajo de otra. */}
      <div className="flex flex-wrap items-start gap-4">
        {scenario.description && (
          <Card id="scenario-description" title={t.dmScenarioDescription} icon={ScrollText} className="flex-[999_1_420px]">
            <p className="text-[14.5px] leading-[1.65] break-words whitespace-pre-wrap text-on-surface">{scenario.description}</p>
          </Card>
        )}
        <Card
          id="scenario-people"
          title={t.dmScenarioCharacters}
          icon={Users}
          className={cx('flex-[1_1_300px]', scenario.description && 'max-w-[380px]')}
          trailing={people.length > 0 ? <span className="text-[12.5px] text-text-muted tabular-nums">{people.length}</span> : undefined}
        >
          {characters.isError && scenario.characterKeys.length > 0 ? (
            <AppErrorView title={t.dmScenarioCharactersError} onRetry={() => characters.refetch()} />
          ) : characters.isLoading ? (
            <AppBusyLabel label={t.dmScenarioCharactersLoading} />
          ) : people.length === 0 ? (
            <p className="text-text-muted italic">{t.dmScenarioPeople([])}</p>
          ) : (
            <ul className="-mx-2 flex flex-col">
              {people.map((character) => {
                const target = scenarioCharacterId(character);
                return (
                  <li key={character.key}>
                    <Link
                      href={character.campaignId === null ? dmNpcsHref(target) : dmMemberHref(character.campaignId, target)}
                      className="group flex items-center gap-3 rounded-[var(--radius-nav)] px-2 py-2 transition-colors duration-[120ms] ease-out hover:bg-plaque focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold"
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
        </Card>
      </div>
    </>
  );
}
