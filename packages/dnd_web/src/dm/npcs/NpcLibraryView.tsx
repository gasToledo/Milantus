import { useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import { useNpcs, useSheetCatalog } from '../../api/queries';
import type { DmCampaign } from '../../api/client';
import { npcViews, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcsHref, Link } from '../../router';
import { Button } from '../../ui/Button';
import { cx } from '../../ui/cx';
import { Medallion } from '../../ui/Medallion';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { hasTag, kindOf, nameMatches, normalizeTags, npcTypeLine } from './npc';

/** El filtro «sin campaña»: los PNJ que no están en ninguna. `null` es todas. */
const NO_CAMPAIGN = '';

/**
 * La Biblioteca de PNJ (`npc_library_view.dart`): todos los de la cuenta,
 * estén o no en alguna campaña, de solo lectura. El filtro principal es **por
 * campaña** y los tags van debajo, más chicos: en la mesa la pregunta es
 * «¿quién está en esta campaña?», y el tag afina dentro de eso. Crear,
 * importar, editar y borrar siguen en Flutter. Nada de esto viaja a un
 * jugador: la API de PNJ es del DM y de nadie más.
 */
export function NpcLibraryView({ campaigns }: { campaigns: readonly DmCampaign[] | undefined }) {
  const t = useTexts();
  const lang = useLang();
  const npcs = useNpcs();
  const catalog = useSheetCatalog(lang);
  const [query, setQuery] = useState('');
  const [campaign, setCampaign] = useState<string | null>(null);
  const [tag, setTag] = useState<string | null>(null);

  // El motor migra cada PNJ y le saca los números una vez por respuesta.
  const entries = useMemo(() => {
    const stored = npcs.data;
    if (!stored || !catalog.data) return null;
    return npcViews(stored, catalog.data).map((view, i) => ({ view, links: stored[i]?.campaigns ?? [] }));
  }, [npcs.data, catalog.data]);

  const failed = [npcs, ...catalog.queries].filter((q) => q.isError);
  const kicker = entries ? t.dmLibraryCount(entries.length) : t.dmReadOnly;

  let body;
  if (failed.length > 0) {
    body = <AppErrorView title={t.dmLibraryReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!entries) {
    body = <AppBusyLabel label={t.dmLibraryLoading} />;
  } else if (entries.length === 0) {
    body = <AppEmptyState kind="empty" message={t.dmLibraryEmpty} hint={t.dmLibraryEmptyHint} />;
  } else {
    const inCampaign = (links: { campaignId: string }[], id: string | null) =>
      id === null ? true : id === NO_CAMPAIGN ? links.length === 0 : links.some((l) => l.campaignId === id);
    const visible = entries.filter(
      ({ view, links }) => inCampaign(links, campaign) && (tag === null || hasTag(view, tag)) && nameMatches(view, query),
    );
    // Las campañas del panel que tienen algún PNJ, en el orden del panel; una
    // que no está en la lista (la lista todavía no cargó) sale de los vínculos.
    const known = campaigns ?? [];
    const campaignOptions = [
      ...known.map((c) => ({ id: c.id, name: c.name })),
      ...entries
        .flatMap(({ links }) => links)
        .filter((l, i, all) => !known.some((c) => c.id === l.campaignId) && all.findIndex((x) => x.campaignId === l.campaignId) === i)
        .map((l) => ({ id: l.campaignId, name: l.campaignName })),
    ];
    const tags = normalizeTags(entries.flatMap(({ view }) => view.npc.tags ?? []));
    const clear = () => {
      setQuery('');
      setCampaign(null);
      setTag(null);
    };

    body = (
      <>
        <div className="flex flex-col gap-2.5">
          <div className="flex flex-wrap items-center gap-2">
            <div role="search" className="relative min-w-[min(220px,100%)] max-w-[280px] flex-[1_1_220px]">
              <label htmlFor="npc-search" className="sr-only">
                {t.dmSearchByName}
              </label>
              <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
              <input
                id="npc-search"
                type="search"
                autoComplete="off"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={t.dmSearchByName}
                className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-3 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
              />
            </div>
            <div role="group" aria-label={t.dmCampaignFilter} className="flex flex-wrap gap-1.5">
              <FilterPill label={t.dmAllF} count={entries.length} pressed={campaign === null} onClick={() => setCampaign(null)} />
              {campaignOptions.map((c) => (
                <FilterPill
                  key={c.id}
                  label={c.name}
                  count={entries.filter(({ links }) => inCampaign(links, c.id)).length}
                  pressed={campaign === c.id}
                  onClick={() => setCampaign(c.id)}
                />
              ))}
              <FilterPill
                label={t.dmNoCampaign}
                count={entries.filter(({ links }) => links.length === 0).length}
                pressed={campaign === NO_CAMPAIGN}
                onClick={() => setCampaign(NO_CAMPAIGN)}
              />
            </div>
          </div>
          {tags.length > 0 && (
            <div role="group" aria-label={t.dmTags} className="flex flex-wrap items-center gap-1.5">
              <span aria-hidden="true" className="eyebrow mr-0.5">
                {t.dmTags}
              </span>
              {tags.map((g) => (
                <FilterPill
                  key={g}
                  small
                  label={g}
                  count={entries.filter(({ view }) => hasTag(view, g)).length}
                  pressed={tag?.toLowerCase() === g.toLowerCase()}
                  // Tocar el elegido lo suelta, como el `FilterChip` de Flutter.
                  onClick={() => setTag(tag?.toLowerCase() === g.toLowerCase() ? null : g)}
                />
              ))}
            </div>
          )}
        </div>

        {visible.length === 0 ? (
          <AppEmptyState
            kind="no-match"
            message={t.dmNoNpcMatches}
            actions={
              <Button tone="secondary" onClick={clear}>
                {t.codexClearFilters}
              </Button>
            }
          />
        ) : (
          <ul aria-label={t.dmNpcLibrary} className="grid gap-3.5 [grid-template-columns:repeat(auto-fill,minmax(min(300px,100%),1fr))]">
            {visible.map(({ view, links }) => (
              <NpcCard key={view.npc.id} view={view} campaigns={links.map((l) => l.campaignName)} />
            ))}
          </ul>
        )}
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmNpcLibrary} kicker={kicker} />
      {body}
    </div>
  );
}

/** Una pill de filtro con su conteo: la selección es estado local, no ruta. */
function FilterPill({
  label,
  count,
  pressed,
  onClick,
  small = false,
}: {
  label: string;
  count: number;
  pressed: boolean;
  onClick: () => void;
  small?: boolean;
}) {
  return (
    <button
      type="button"
      aria-pressed={pressed}
      onClick={onClick}
      className={cx(
        'rounded-[var(--radius-pill)] border',
        small ? 'px-[11px] py-[3px] text-[12px]' : 'px-3 py-[5px] text-[12.5px]',
        pressed ? 'border-gold bg-gold-soft font-semibold text-gold' : 'border-hairline text-on-surface-variant hover:text-on-surface',
      )}
    >
      {label} <span className="tabular-nums opacity-80">{count}</span>
    </button>
  );
}

/** Un PNJ de la biblioteca: identidad, tags y en qué campañas está. La tarjeta
 *  entera lleva a su ficha. */
function NpcCard({ view, campaigns }: { view: NpcView; campaigns: string[] }) {
  const t = useTexts();
  const { npc } = view;
  const tags = npc.tags ?? [];
  return (
    <li className="min-w-0" data-npc={npc.id}>
      <Link href={dmNpcsHref(npc.id)} className="card flex h-full min-h-[150px] flex-col gap-2.5 p-3.5 hover:border-gold">
        <span className="flex items-center gap-3">
          <Medallion name={npc.name} accent={null} size={44} />
          <span className="min-w-0 flex-1">
            <span className="font-display block truncate text-[17px] text-on-surface">{npc.name}</span>
            <span className={cx('mt-0.5 block truncate text-[12px] text-text-muted', kindOf(view) === 'none' && 'italic')} data-field="type">
              {npcTypeLine(view, t)}
            </span>
          </span>
        </span>
        <span className="flex min-h-[22px] flex-wrap gap-1.5">
          {tags.map((tag) => (
            <span key={tag} className="rounded-[var(--radius-pill)] border border-hairline px-[9px] py-px text-[11.5px] text-on-surface-variant">
              {tag}
            </span>
          ))}
        </span>
        <span
          className={cx(
            'mt-auto truncate border-t border-hairline pt-2 text-[12.5px]',
            campaigns.length === 0 ? 'text-text-muted italic' : 'text-on-surface',
          )}
          data-field="campaigns"
        >
          {campaigns.length === 0 ? t.dmNoCampaignYet : campaigns.join(' · ')}
        </span>
      </Link>
    </li>
  );
}
