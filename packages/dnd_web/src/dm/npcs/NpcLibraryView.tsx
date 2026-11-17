import { useMemo, useRef, useState, type CSSProperties } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Plus, Search, Upload } from 'lucide-react';
import { queryKeys, useNpcs, useRosterSettings, useSheetCatalog } from '../../api/queries';
import { patchSettings } from '../../api/settingsSave';
import { movedOrder } from '../../dashboard/roster';
import { useHoldDrag } from '../../ui/holdDrag';
import type { DmCampaign, RosterSettings } from '../../api/client';
import { npcViews, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcsHref, Link } from '../../router';
import { Button } from '../../ui/Button';
import { cx } from '../../ui/cx';
import { fadeNavigate } from '../../ui/fadeNavigate';
import { useListTransition } from '../../ui/listTransition';
import { Toast } from '../../ui/primitives';
import { Medallion } from '../../ui/Medallion';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { DmHeader } from '../DmHeader';
import { ImportNpcDialog } from './ImportNpcDialog';
import { NewNpcDialog } from './NewNpcDialog';
import { hasTag, kindOf, nameMatches, normalizeTags, npcPortrait, npcTypeLine } from './npc';

/** El filtro «sin campaña»: los PNJ que no están en ninguna. `null` es todas. */
const NO_CAMPAIGN = '';
const inCampaign = (links: readonly { campaignId: string }[], id: string | null) =>
  id === null ? true : id === NO_CAMPAIGN ? links.length === 0 : links.some((l) => l.campaignId === id);

/**
 * La Biblioteca de PNJ (`npc_library_view.dart`): todos los de la cuenta,
 * estén o no en alguna campaña. El filtro principal es **por campaña** y los
 * tags van debajo, más chicos: en la mesa la pregunta es «¿quién está en esta
 * campaña?», y el tag afina dentro de eso. Acá se crea un PNJ (sin ficha de
 * personaje: eso sigue en Flutter), se importa un ZIP (de un PNJ o de un
 * personaje exportado) y se borra desde su ficha; editar sigue en Flutter. Nada de esto viaja a un jugador: la API de PNJ es
 * del DM y de nadie más.
 */
export function NpcLibraryView({ campaigns }: { campaigns: readonly DmCampaign[] | undefined }) {
  const t = useTexts();
  const lang = useLang();
  const npcs = useNpcs();
  const catalog = useSheetCatalog(lang);
  // El buscador escribe en `query` al instante y la grilla filtra con
  // `listQuery` dentro de la transición, como el dashboard.
  const [query, setQuery] = useState('');
  const [listQuery, setListQuery] = useState('');
  const [campaign, setCampaign] = useState<string | null>(null);
  const [tag, setTag] = useState<string | null>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const [creating, setCreating] = useState(false);
  const [importing, setImporting] = useState(false);
  const [imported, setImported] = useState<{ key: number; message: string } | null>(null);
  const [orderFailed, setOrderFailed] = useState(0);
  // Importar es secundario (filete y texto): «Nuevo PNJ» sigue siendo el único
  // oro de la vista.
  const actions = (
    <>
      <Button tone="secondary" icon={Upload} data-action="import-npc" onClick={() => setImporting(true)}>
        {t.npcImport}
      </Button>
      <Button icon={Plus} data-action="new-npc" onClick={() => setCreating(true)}>
        {t.npcNew}
      </Button>
    </>
  );

  const settings = useRosterSettings();
  const client = useQueryClient();
  // El motor migra cada PNJ y le saca los números una vez por respuesta. Van
  // en el orden del DM (`npcOrder` de los ajustes, como el dashboard): lo que
  // no figura va al final en el orden del servidor.
  const npcOrder = settings.data?.npcOrder;
  const entries = useMemo(() => {
    const stored = npcs.data;
    if (!stored || !catalog.data) return null;
    const rank = (id: string) => {
      const i = npcOrder?.indexOf(id) ?? -1;
      return i < 0 ? Number.MAX_SAFE_INTEGER : i;
    };
    return npcViews(stored, catalog.data)
      .map((view, i) => ({
        view,
        links: stored[i]?.campaigns ?? [],
        portrait: stored[i] ? npcPortrait(stored[i]) : null,
      }))
      .sort((a, b) => rank(a.view.npc.id) - rank(b.view.npc.id));
  }, [npcs.data, catalog.data, npcOrder]);

  const visible = useMemo(
    () =>
      entries?.filter(
        ({ view, links }) => inCampaign(links, campaign) && (tag === null || hasTag(view, tag)) && nameMatches(view, listQuery),
      ) ?? [],
    [entries, campaign, tag, listQuery],
  );
  const visibleIds = useMemo(() => visible.map(({ view }) => view.npc.id).join('\n'), [visible]);
  // Filtrar anima la grilla, como las otras listas de tarjetas.
  const animateList = useListTransition(visibleIds);

  // Con un filtro puesto no se mueven: soltar entre dos filtrados no dice dónde
  // quedan respecto de los ocultos (la regla del dashboard). Se ve al instante
  // y se guarda después; si falla, se relee lo guardado.
  const canMove = listQuery.trim() === '' && campaign === null && tag === null;
  const moveNpc = (from: string, to: string) => {
    const order = movedOrder(
      visible.map(({ view }) => view.npc.id),
      from,
      to,
    );
    void (async () => {
      await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
      client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (old) => old && { ...old, npcOrder: order });
      try {
        await patchSettings({ npcOrder: order });
      } catch {
        setOrderFailed((n) => n + 1);
        void client.invalidateQueries({ queryKey: queryKeys.rosterSettings });
      }
    })();
  };
  const reorder = useHoldDrag({
    ids: canMove ? visible.map(({ view }) => view.npc.id) : [],
    canDrop: () => canMove,
    onMove: moveNpc,
  });

  const failed = [npcs, settings, ...catalog.queries].filter((q) => q.isError);
  const kicker = entries ? t.dmLibraryCount(entries.length) : undefined;

  let body;
  if (failed.length > 0) {
    body = <AppErrorView title={t.dmLibraryReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!entries) {
    body = <AppBusyLabel label={t.dmLibraryLoading} />;
  } else if (entries.length === 0) {
    body = <AppEmptyState kind="empty" message={t.dmLibraryEmpty} actions={<div className="flex flex-wrap justify-center gap-2">{actions}</div>} />;
  } else {
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
    // El botón desaparece al tocarlo: el foco pasa al buscador.
    const clear = () => {
      setQuery('');
      searchRef.current?.focus();
      animateList(() => {
        setListQuery('');
        setCampaign(null);
        setTag(null);
      });
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
                ref={searchRef}
                type="search"
                autoComplete="off"
                value={query}
                onChange={(e) => {
                  const value = e.target.value;
                  setQuery(value);
                  animateList(() => setListQuery(value));
                }}
                placeholder={t.dmSearchByName}
                className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-3 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
              />
            </div>
            <div role="group" aria-label={t.dmCampaignFilter} className="flex flex-wrap gap-1.5">
              <FilterPill label={t.dmAllF} count={entries.length} pressed={campaign === null} onClick={() => animateList(() => setCampaign(null))} />
              {campaignOptions.map((c) => (
                <FilterPill
                  key={c.id}
                  label={c.name}
                  count={entries.filter(({ links }) => inCampaign(links, c.id)).length}
                  pressed={campaign === c.id}
                  onClick={() => animateList(() => setCampaign(c.id))}
                />
              ))}
              <FilterPill
                label={t.dmNoCampaign}
                count={entries.filter(({ links }) => links.length === 0).length}
                pressed={campaign === NO_CAMPAIGN}
                onClick={() => animateList(() => setCampaign(NO_CAMPAIGN))}
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
                  onClick={() => animateList(() => setTag(tag?.toLowerCase() === g.toLowerCase() ? null : g))}
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
            {visible.map(({ view, links, portrait }) => (
              <NpcCard
                key={view.npc.id}
                view={view}
                campaigns={links.map((l) => l.campaignName)}
                portrait={portrait}
                reorder={
                  canMove
                    ? {
                        item: reorder.item(view.npc.id),
                        dragging: reorder.dragging === view.npc.id,
                        over: reorder.over === view.npc.id,
                        animated: reorder.animated,
                      }
                    : undefined
                }
              />
            ))}
          </ul>
        )}
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader title={t.dmNpcLibrary} kicker={kicker} actions={entries && entries.length > 0 ? actions : undefined} />
      {body}
      {creating && <NewNpcDialog onClose={() => setCreating(false)} />}
      {importing && (
        <ImportNpcDialog
          campaigns={campaigns ?? []}
          onClose={() => setImporting(false)}
          onImported={(name) => setImported((prev) => ({ key: (prev?.key ?? 0) + 1, message: t.npcImported(name) }))}
        />
      )}
      {orderFailed > 0 && (
        <Toast key={orderFailed} tone="error" message={t.dmOrderSaveError} open onOpenChange={(open) => !open && setOrderFailed(0)} />
      )}
      {imported && (
        <Toast key={imported.key} tone="success" message={imported.message} open onOpenChange={(open) => !open && setImported(null)} />
      )}
    </div>
  );
}

/** Una pill de filtro con su conteo: la selección es estado local, no ruta.
 *  La comparten la Biblioteca y los PNJ de la mesa. */
export function FilterPill({
  label,
  count,
  pressed,
  onClick,
  small = false,
  disabled = false,
  dashed = false,
}: {
  label: string;
  /** Sin número, la pill es una opción a marcar (los formularios del Homebrew). */
  count?: number;
  pressed: boolean;
  onClick: () => void;
  small?: boolean;
  /** Apagada: no responde y se ve apagada (`aria-disabled`, que sigue en el
   *  orden de tabulación; `onClick` no se llama). */
  disabled?: boolean;
  /** Borde punteado: lo que el glosario no conoce y se muestra por su id. */
  dashed?: boolean;
}) {
  return (
    <button
      type="button"
      aria-pressed={pressed}
      aria-disabled={disabled ? true : undefined}
      onClick={disabled ? undefined : onClick}
      className={cx(
        'pick rounded-[var(--radius-pill)] border',
        dashed && 'border-dashed',
        disabled && 'opacity-40',
        small ? 'px-[11px] py-[3px] text-[12px]' : 'px-3 py-[5px] text-[12.5px]',
        pressed ? 'border-gold bg-gold-soft font-semibold text-gold' : 'border-hairline text-on-surface-variant hover:text-on-surface',
      )}
    >
      {label}
      {count !== undefined && <> <span className="tabular-nums opacity-80">{count}</span></>}
    </button>
  );
}

/** Un PNJ de la biblioteca: identidad, tags y en qué campañas está. La tarjeta
 *  entera lleva a su ficha. */
function NpcCard({
  view,
  campaigns,
  portrait,
  reorder,
}: {
  view: NpcView;
  campaigns: string[];
  portrait: string | null;
  /** Mover la tarjeta tomándola entera (`useHoldDrag`), con las mismas clases
   *  que los PNJ de la campaña. Sin esto no se mueve (con un filtro puesto). */
  reorder?: { item: Record<string, unknown>; dragging: boolean; over: boolean; animated: boolean };
}) {
  const t = useTexts();
  const { npc } = view;
  const tags = npc.tags ?? [];
  return (
    // Se levanta y se aprieta como las del dashboard (`.roster-card`), y el
    // nombre la sigue en las transiciones de la grilla. El enlace ocupa toda la
    // tarjeta; arrastrarla es de la tarjeta, no del enlace.
    <li
      className={cx(
        'card roster-card min-w-0',
        reorder && 'select-none [-webkit-touch-callout:none]',
        reorder?.dragging && (reorder.animated ? 'cursor-grabbing border-gold [&_*]:cursor-grabbing' : 'opacity-40'),
        reorder?.over && !reorder.animated && 'outline-2 outline-offset-1 outline-gold',
      )}
      data-npc={npc.id}
      {...reorder?.item}
      // Después del `item`, que trae su `style` para el arrastre.
      style={{
        viewTransitionName: `lib-${npc.id.replace(/[^\w-]/g, '_')}`,
        ...(reorder?.item.style as CSSProperties | undefined),
      }}
    >
      {/* Abrir la ficha funde la pantalla, como tarjeta → ficha en el modo jugador. */}
      <Link
        href={dmNpcsHref(npc.id)}
        draggable={false}
        onClick={(e) => fadeNavigate(e, '[data-npc-title]')}
        className="flex h-full min-h-[150px] flex-col gap-2.5 rounded-[inherit] p-3.5"
      >
        <span className="flex items-center gap-3">
          <Medallion name={npc.name} accent={null} size={44} portrait={portrait} />
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
