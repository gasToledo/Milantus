import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Axe,
  BookMarked,
  BookOpen,
  Box,
  GitBranch,
  Medal,
  Network,
  ScrollText,
  Search,
  Shield,
  ShieldHalf,
  Users,
  WandSparkles,
  X,
  ArrowLeft,
  type LucideIcon,
} from 'lucide-react';
import { useAppVersion, useSheetCatalog } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { codexHref, Link, navigate, rosterHref, type CodexCategory } from '../router';
import { SheetFooter } from '../sheet/SheetPanel';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow, Pill, SectionRule } from '../ui/data';
import { Tooltip } from '../ui/primitives';
import { NavGroup, NavItem, Shell, SidebarBack } from '../ui/Shell';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { CATEGORY_GROUPS, codexEntries, fold, type CodexEntry } from './entries';

/** Ícono por categoría (los de `CodexCategory` en Flutter, en lucide). */
const ICONS: Record<CodexCategory, LucideIcon> = {
  races: Users,
  lineages: Network,
  classes: Shield,
  subclasses: GitBranch,
  backgrounds: ScrollText,
  feats: Medal,
  spells: BookOpen,
  magicItems: WandSparkles,
  weapons: Axe,
  armor: ShieldHalf,
  gear: Box,
};

const ALL_CATEGORIES = CATEGORY_GROUPS.flatMap((g) => g.categories);

/** Cuántas coincidencias por categoría muestra la búsqueda general antes de
 *  ofrecer «Ver las N»: con una letra, «a» encuentra casi todo el catálogo. */
const SEARCH_PREVIEW = 5;

/**
 * El Códice: todo el contenido del juego para leer, sin crear un personaje ni
 * editar nada. Es de **solo lectura** a propósito: agregar algo a una ficha
 * tiene su lugar y editar contenido es Homebrew. Las criaturas no están, como
 * en Flutter: el Códice lo abre cualquier jugador y los perfiles de los
 * monstruos son del DM (el Bestiario del Modo DM).
 *
 * Portada, categoría y entrada son URLs (`/v2/codice/conjuros/fireball`); la
 * búsqueda general vive en el panel y no cambia la URL.
 */
export function CodexPage({ category, entryId }: { category: CodexCategory | null; entryId: string | null }) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  const version = useAppVersion(true);
  const [query, setQuery] = useState('');

  // Las entradas de cada categoría, armadas una vez por catálogo e idioma; el
  // detalle de cada una se arma recién al abrirla.
  const entries = useMemo(() => {
    if (!catalog.data) return null;
    return new Map(ALL_CATEGORIES.map((c) => [c, codexEntries(c, catalog.data!, t, lang)] as const));
  }, [catalog.data, t, lang]);

  const needle = fold(query.trim());
  const matches = useMemo(() => {
    if (!entries || !needle) return null;
    return new Map(ALL_CATEGORIES.map((c) => [c, entries.get(c)!.filter((e) => fold(e.name).includes(needle))] as const));
  }, [entries, needle]);

  // Elegir una categoría o una entrada cancela la búsqueda general, como en
  // Flutter: pedir una categoría y seguir viendo resultados mezclados sería
  // contestar otra cosa.
  useEffect(() => setQuery(''), [category, entryId]);

  const failed = catalog.queries.filter((q) => q.isError);
  let body;
  if (failed.length > 0) {
    body = <AppErrorView as="h1" title={t.codexLoadError} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!entries) {
    body = <AppBusyLabel label={t.codexLoading} />;
  } else if (matches) {
    body = <SearchResults query={query.trim()} matches={matches} onClear={() => setQuery('')} />;
  } else if (category === null) {
    body = <Home entries={entries} />;
  } else {
    body = <CategoryView key={category} category={category} entries={entries.get(category)!} entryId={entryId} />;
  }

  return (
    <Shell
      panel={
        <>
          <SidebarBack href={rosterHref()} label={t.backToCharacters} />
          <div role="search" className="relative">
            <label htmlFor="codex-search" className="sr-only">
              {t.codexSearchAll}
            </label>
            <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
            <input
              id="codex-search"
              type="search"
              autoComplete="off"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t.packSearchHint}
              className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-8 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
            />
            {query !== '' && (
              <Tooltip content={t.rosterClearSearch}>
                <button
                  type="button"
                  aria-label={t.rosterClearSearch}
                  onClick={() => setQuery('')}
                  className="absolute inset-y-0 right-1 flex w-7 items-center justify-center text-text-muted hover:text-on-surface"
                >
                  <X size={14} aria-hidden="true" />
                </button>
              </Tooltip>
            )}
          </div>
          <NavGroup label={t.codexNavLabel}>
            <li>
              <NavItem href={codexHref()} icon={BookMarked} label={t.codexHome} active={!matches && category === null} internal />
            </li>
            {CATEGORY_GROUPS.map(({ group, categories }) => (
              <li key={group}>
                <Eyebrow className="px-3 pt-3.5 pb-1">{t.codexGroups[group]}</Eyebrow>
                <ul className="flex flex-col gap-0.5">
                  {categories.map((c) => {
                    // Buscando, el panel cuenta coincidencias: dice dónde hay
                    // algo sin tener que bajar por los resultados.
                    const count = matches ? matches.get(c)!.length : entries?.get(c)?.length;
                    return (
                      <li key={c}>
                        <NavItem
                          href={codexHref(c)}
                          icon={ICONS[c]}
                          label={t.codexCategories[c]}
                          active={!matches && category === c}
                          count={count}
                          muted={matches !== null && count === 0}
                          internal
                        />
                      </li>
                    );
                  })}
                </ul>
              </li>
            ))}
          </NavGroup>
        </>
      }
      footer={<SheetFooter version={version.data} />}
    >
      {body}
    </Shell>
  );
}

function Home({ entries }: { entries: Map<CodexCategory, CodexEntry[]> }) {
  const t = useTexts();
  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="font-display text-[30px] leading-tight text-on-surface">{t.codexTitle}</h1>
        <p className="mt-1.5 text-on-surface-variant">{t.codexIntro}</p>
      </header>
      {CATEGORY_GROUPS.map(({ group, categories }) => (
        <section key={group} aria-labelledby={`codex-group-${group}`} className="flex flex-col gap-2.5">
          <div className="flex items-center gap-2.5">
            <h2 id={`codex-group-${group}`} className="eyebrow">
              {t.codexGroups[group]}
            </h2>
            <span aria-hidden="true" className="h-px flex-1 bg-hairline" />
          </div>
          <ul className="grid gap-3 [grid-template-columns:repeat(auto-fill,minmax(min(260px,100%),1fr))]">
            {categories.map((c) => {
              const Icon = ICONS[c];
              const list = entries.get(c)!;
              return (
                <li key={c}>
                  <Link
                    href={codexHref(c)}
                    className="card block px-4 py-[15px] hover:border-gold"
                    data-category={c}
                  >
                    <span className="flex items-center gap-2.5">
                      <Icon size={20} aria-hidden="true" className="shrink-0 text-gold" />
                      <span className="font-display flex-1 text-[17px] text-on-surface">{t.codexCategories[c]}</span>
                      <span className="num text-[18px] text-on-surface-variant">
                        <span aria-hidden="true">{list.length}</span>
                        <span className="sr-only">{t.codexEntries(list.length)}</span>
                      </span>
                    </span>
                    {/* Una muestra y no un resumen: dice de qué se trata sin
                        prometer que estén todos. */}
                    <span aria-hidden="true" className="mt-2 block truncate text-[13px] text-text-muted">
                      {list
                        .slice(0, 3)
                        .map((e) => e.name)
                        .join(' · ')}
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
        </section>
      ))}
    </div>
  );
}

function CategoryView({
  category,
  entries,
  entryId,
}: {
  category: CodexCategory;
  entries: CodexEntry[];
  entryId: string | null;
}) {
  const t = useTexts();
  // «Ver las N» de la búsqueda general llega con `?q=`: la lista arranca
  // filtrada por lo mismo.
  const [query, setQuery] = useState(() => new URLSearchParams(window.location.search).get('q') ?? '');
  const [facet, setFacet] = useState<string | null>(null);
  const label = t.codexCategories[category];

  // Los valores del filtro salen de lo cargado, así una rareza o categoría de
  // homebrew nueva también aparece; van en el orden del motor.
  const facets = useMemo(() => {
    const ranks = new Map<string, number>();
    for (const e of entries) if (e.facet !== null && !ranks.has(e.facet)) ranks.set(e.facet, e.facetRank);
    return [...ranks.entries()].sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0])).map(([f]) => f);
  }, [entries]);

  const needle = fold(query.trim());
  const visible = entries.filter((e) => (facet === null || e.facet === facet) && (!needle || fold(e.name).includes(needle)));
  const open = entryId ? entries.find((e) => e.id === entryId) ?? null : null;

  // La entrada abierta queda a la vista en la lista: llegando por un enlace a
  // Bola de Fuego, estaría tres niveles más abajo.
  const listRef = useRef<HTMLElement>(null);
  useEffect(() => {
    listRef.current?.querySelector('[aria-current="true"]')?.scrollIntoView({ block: 'nearest' });
  }, [open?.id]);

  return (
    <div className="flex flex-col gap-4">
      <header className="flex flex-wrap items-baseline gap-x-3.5 gap-y-1">
        <h1 className="font-display text-[30px] leading-tight text-on-surface">{label}</h1>
        <span className="text-text-muted tabular-nums">{t.codexEntries(entries.length)}</span>
      </header>

      <div className="flex flex-wrap items-center gap-x-3.5 gap-y-2.5">
        <div role="search" className="relative min-w-[min(220px,100%)] flex-[1_1_220px] max-w-[320px]">
          <label htmlFor="codex-category-search" className="sr-only">
            {t.codexSearchIn(label)}
          </label>
          <input
            id="codex-category-search"
            type="search"
            autoComplete="off"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.codexSearchIn(label)}
            className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque px-4 text-[13px] text-on-surface placeholder:text-text-muted"
          />
        </div>
        {facets.length > 1 && (
          <div role="group" aria-label={t.codexFilterLabel} className="flex flex-wrap gap-1.5">
            {[null, ...facets].map((f) => (
              <button
                key={f ?? '*'}
                type="button"
                aria-pressed={facet === f}
                onClick={() => setFacet(f)}
                className={cx(
                  'rounded-[var(--radius-pill)] border px-3 py-[5px] text-[12.5px] tabular-nums',
                  facet === f
                    ? 'border-gold bg-gold-soft font-semibold text-gold'
                    : 'border-hairline text-on-surface-variant hover:text-on-surface',
                )}
              >
                {f ?? t.codexAll}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="codex-split" data-open={open !== null}>
        <div>
          <section ref={listRef} aria-label={label} className="codex-list card p-1.5" data-field="codex-list">
            {visible.length === 0 ? (
              <div className="p-2">
                <AppEmptyState
                  kind="no-match"
                  message={t.codexNothingMatches}
                  actions={
                    <Button
                      tone="secondary"
                      onClick={() => {
                        setQuery('');
                        setFacet(null);
                      }}
                    >
                      {t.codexClearFilters}
                    </Button>
                  }
                />
              </div>
            ) : (
              <ul>
                {visible.map((e) => {
                  const on = e.id === open?.id;
                  return (
                    <li key={e.id}>
                      <Link
                        href={codexHref(category, e.id)}
                        aria-current={on ? 'true' : undefined}
                        className={cx(
                          'block rounded-[var(--radius-nav)] px-3 py-2',
                          on ? 'bg-gold-soft text-gold' : 'text-on-surface hover:bg-plaque',
                        )}
                        data-entry={e.id}
                      >
                        <span className={cx('block text-[14px]', on && 'font-semibold')}>{e.name}</span>
                        {e.subtitle && <span className="mt-0.5 block truncate text-[12px] text-text-muted">{e.subtitle}</span>}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            )}
          </section>

          <div className="codex-detail min-w-0">
            {open ? (
              <>
                <Link
                  href={codexHref(category)}
                  className="codex-back mb-3 inline-flex items-center gap-1.5 text-[13px] text-on-surface-variant hover:text-gold"
                >
                  <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
                  {t.codexBackToList}
                </Link>
                <EntryDetail entry={open} />
              </>
            ) : (
              <p className="card p-6 text-on-surface-variant">{t.codexPickEntry}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

/** La entrada abierta: la «página» del manual. */
function EntryDetail({ entry }: { entry: CodexEntry }) {
  const t = useTexts();
  const detail = useMemo(() => entry.detail(), [entry]);
  const source = (t.sources as Record<string, string>)[entry.source];
  return (
    <article aria-labelledby="codex-entry-title" className="card px-5 py-6 sm:px-8 sm:py-7" data-field="codex-detail">
      {source && (
        <Pill highlighted={entry.source === 'srd_2024'}>
          <span aria-hidden="true">{source}</span>
          <span className="sr-only">{t.sourceLabel(source)}</span>
        </Pill>
      )}
      <h2 id="codex-entry-title" className="font-display mt-3.5 text-[34px] leading-[1.1] break-words text-on-surface">
        {entry.name}
      </h2>
      {entry.subtitle && <p className="mt-1.5 text-[15px] text-on-surface-variant">{entry.subtitle}</p>}
      <SectionRule className="my-[22px]" />

      {detail.facts
        .filter((g) => g.length > 0)
        .map((group, i) => (
          <dl key={i} className="mb-2.5 grid items-start gap-2.5 [grid-template-columns:repeat(auto-fill,minmax(min(120px,100%),1fr))]">
            {group.map((f) => (
              <div key={f.label} className="plaque px-3.5 py-[11px]">
                <dt className="plaque-label">{f.label}</dt>
                <dd className="mt-1.5 text-[15px] text-on-surface">{f.value}</dd>
              </div>
            ))}
          </dl>
        ))}

      {detail.prose && (
        <p className="mt-5 max-w-[620px] text-[16px] leading-[1.65] whitespace-pre-line text-on-surface">{detail.prose}</p>
      )}

      {detail.sections.map((s) => (
        <section key={s.title} className="mt-6 max-w-[680px]">
          <Eyebrow className="mb-2">{s.title}</Eyebrow>
          <ul className="divide-y divide-hairline border-t border-hairline">
            {s.traits.map((tr, i) => (
              <li key={`${tr.name}-${i}`} className="py-2.5">
                <p className="font-medium text-on-surface">{tr.name}</p>
                {tr.description && (
                  <p className="mt-1 text-[14px] leading-[1.55] whitespace-pre-line text-on-surface-variant">{tr.description}</p>
                )}
              </li>
            ))}
          </ul>
        </section>
      ))}

      {detail.related && (
        <div className="mt-6 flex flex-wrap items-center gap-2">
          <span className="mr-0.5 text-[13px] text-text-muted">{detail.related.title}</span>
          <ul className="contents">
            {detail.related.names.map((n) => (
              <Pill as="li" key={n} highlighted={false}>
                {n}
              </Pill>
            ))}
          </ul>
        </div>
      )}
    </article>
  );
}

function SearchResults({
  query,
  matches,
  onClear,
}: {
  query: string;
  matches: Map<CodexCategory, CodexEntry[]>;
  onClear: () => void;
}) {
  const t = useTexts();
  // Agrupados por categoría: el mismo nombre puede ser un conjuro y un objeto,
  // y son cosas distintas.
  const groups = ALL_CATEGORIES.map((c) => ({ c, list: matches.get(c)! })).filter((g) => g.list.length > 0);
  const total = groups.reduce((n, g) => n + g.list.length, 0);
  if (total === 0) {
    return (
      <AppEmptyState
        kind="no-match"
        message={t.codexNoMatch(query)}
        actions={
          <Button tone="secondary" icon={X} onClick={onClear}>
            {t.rosterClearSearch}
          </Button>
        }
      />
    );
  }
  return (
    <div className="flex flex-col gap-4">
      <header className="flex flex-wrap items-baseline gap-x-3.5 gap-y-1">
        <h1 className="font-display text-[30px] leading-tight text-on-surface">{t.codexResultsTitle(query)}</h1>
        <span role="status" className="text-text-muted tabular-nums">
          {t.codexResultsCount(total, groups.length)}
        </span>
      </header>
      {groups.map(({ c, list }) => {
        const Icon = ICONS[c];
        return (
          <section key={c} aria-labelledby={`codex-results-${c}`} className="card px-4 pt-3.5 pb-2.5" data-results={c}>
            <h2 id={`codex-results-${c}`} className="mb-1.5 flex items-center gap-2">
              <Icon size={18} aria-hidden="true" className="text-gold" />
              <span className="font-display flex-1 text-[16px] text-on-surface">{t.codexCategories[c]}</span>
              <span className="text-[12px] text-text-muted tabular-nums">{list.length}</span>
            </h2>
            <ul>
              {list.slice(0, SEARCH_PREVIEW).map((e) => (
                <li key={e.id} className="border-t border-hairline">
                  <Link href={codexHref(c, e.id)} className="flex flex-wrap items-baseline gap-x-2.5 px-1 py-2 hover:text-gold">
                    <span className="text-[14px] text-on-surface">{e.name}</span>
                    {e.subtitle && <span className="text-[12px] text-text-muted">{e.subtitle}</span>}
                  </Link>
                </li>
              ))}
            </ul>
            {list.length > SEARCH_PREVIEW && (
              <button
                type="button"
                onClick={() => navigate(`${codexHref(c)}?q=${encodeURIComponent(query)}`)}
                className="block w-full border-t border-hairline px-1 pt-2 pb-1 text-left text-[13px] text-gold hover:underline"
              >
                {t.codexSeeAll(list.length, t.codexCategories[c])}
              </button>
            )}
          </section>
        );
      })}
    </div>
  );
}
