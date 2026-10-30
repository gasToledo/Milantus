import { useEffect, useMemo, useRef, useState } from 'react';
import { ArrowLeft, Search, X } from 'lucide-react';
import { useSheetCatalog } from '../api/queries';
import { bestiary, type BestiaryRow, type Catalog } from '../engine';
import { fold } from '../codex/entries';
import { useListFitsViewport } from '../codex/listHeight';
import { useLang, useTexts } from '../i18n/context';
import { bestiaryHref, dmBestiaryHref, Link } from '../router';
import { DmHeader } from '../dm/DmHeader';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Pill } from '../ui/data';
import { Select, Tooltip } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { asProfile, type CreatureProfile as Profile } from './creature';
import { CreatureProfile } from './CreatureProfile';

const ALL = '*';

interface Creature {
  row: BestiaryRow;
  profile: Profile;
}

/**
 * El Bestiario: buscar una criatura y leer su perfil, de solo lectura. Salen
 * las del catálogo y las homebrew de la cuenta (el catálogo ya viene fusionado),
 * menos las invocaciones por fórmula, que el motor deja afuera. Lista y perfil
 * son URLs (`/v2/bestiario/goblin`). A diferencia de Flutter, donde es una
 * sección del Modo DM que además suma al combate o copia a Homebrew, acá solo
 * se lee: el catálogo es el mismo contenido público del Códice.
 *
 * Con [dm] es la misma pantalla montada en el Modo DM (`/v2/dm/bestiario`, con
 * el panel del DM): igual navegador y perfil, con la cabecera del Modo DM y sus
 * propias URL. No es otra pantalla: una criatura nueva sale en las dos.
 */
export function BestiaryPage({ entryId, dm = false }: { entryId: string | null; dm?: boolean }) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);

  const creatures = useMemo((): Creature[] | null => {
    if (!catalog.data) return null;
    const byId = new Map(catalog.data.creatures.map((c) => [c.id, c] as const));
    // El motor da el orden y lo que deriva; el perfil se lee del catálogo.
    return bestiary(catalog.data).flatMap((row) => {
      const raw = byId.get(row.id);
      return raw ? [{ row, profile: asProfile(raw) }] : [];
    });
  }, [catalog.data]);

  const failed = catalog.queries.filter((q) => q.isError);
  if (failed.length > 0) {
    return (
      <div>
        <Heading dm={dm} />
        <AppErrorView title={t.bestiaryLoadError} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      </div>
    );
  }
  if (!creatures || !catalog.data) {
    return (
      <div>
        <Heading dm={dm} />
        <AppBusyLabel label={t.bestiaryLoading} />
      </div>
    );
  }
  return <Browser creatures={creatures} catalog={catalog.data} entryId={entryId} dm={dm} />;
}

function Heading({ count, dm = false }: { count?: number; dm?: boolean }) {
  const t = useTexts();
  // El Modo DM tiene su cabecera (título, pill y regla); el conteo va en la
  // pill.
  if (dm) {
    return <DmHeader title={t.bestiaryTitle} kicker={count === undefined ? t.dmReadOnly : `${t.dmReadOnly} · ${t.bestiaryCount(count)}`} />;
  }
  return (
    <header className="flex flex-wrap items-baseline gap-x-3.5 gap-y-1">
      <h1 className="font-display text-[30px] leading-tight text-on-surface">{t.bestiaryTitle}</h1>
      {count !== undefined && <span className="text-text-muted tabular-nums">{t.bestiaryCount(count)}</span>}
    </header>
  );
}

function Browser({
  creatures,
  catalog,
  entryId,
  dm,
}: {
  creatures: Creature[];
  catalog: Catalog;
  entryId: string | null;
  dm: boolean;
}) {
  const hrefOf = dm ? dmBestiaryHref : bestiaryHref;
  const t = useTexts();
  const [query, setQuery] = useState('');
  const [type, setType] = useState(ALL);
  const [minCr, setMinCr] = useState<number | null>(null);
  const [maxCr, setMaxCr] = useState<number | null>(null);
  const [sortByCr, setSortByCr] = useState(false);

  // Los tipos y los desafíos salen de lo cargado, no de una lista fija: así el
  // filtro no ofrece uno vacío y no se olvida de uno de homebrew.
  const types = useMemo(() => {
    const seen = new Map<string, string>();
    for (const { row } of creatures) if (row.type && row.typeLabel) seen.set(row.type, row.typeLabel);
    return [...seen.entries()].sort((a, b) => a[1].localeCompare(b[1]));
  }, [creatures]);
  const crs = useMemo(() => {
    const seen = new Map<number, string>();
    for (const { row } of creatures) if (row.cr !== null && row.crText !== null) seen.set(row.cr, row.crText);
    return [...seen.entries()].sort((a, b) => a[0] - b[0]);
  }, [creatures]);

  const visible = useMemo(() => {
    const needle = fold(query.trim());
    const ranged = minCr !== null || maxCr !== null;
    const list = creatures.filter(({ row, profile }) => {
      if (type !== ALL && row.type !== type) return false;
      if (needle && !fold(profile.name).includes(needle) && !fold(row.kind).includes(needle)) return false;
      // Un rango con cualquier extremo deja afuera a las criaturas sin
      // desafío: quien pide «de 1 a 3» no busca un compañero de conjuro.
      if (ranged) {
        if (row.cr === null) return false;
        if (minCr !== null && row.cr < minCr) return false;
        if (maxCr !== null && row.cr > maxCr) return false;
      }
      return true;
    });
    // `sort` es estable: el desempate es el orden alfabético que ya traen.
    return sortByCr ? [...list].sort((a, b) => (a.row.cr ?? Infinity) - (b.row.cr ?? Infinity)) : list;
  }, [creatures, query, type, minCr, maxCr, sortByCr]);

  const open = entryId ? (creatures.find((c) => c.row.id === entryId) ?? null) : null;

  // La criatura abierta queda a la vista en una lista de 300.
  const listRef = useRef<HTMLElement>(null);
  useListFitsViewport(listRef);
  useEffect(() => {
    listRef.current?.querySelector('[aria-current="true"]')?.scrollIntoView({ block: 'nearest' });
  }, [open?.row.id]);

  // Un rango invertido no se muestra como lista vacía: el extremo que no se
  // tocó se corre hasta el que sí.
  const pickMin = (v: number | null) => {
    setMinCr(v);
    if (v !== null && maxCr !== null && maxCr < v) setMaxCr(v);
  };
  const pickMax = (v: number | null) => {
    setMaxCr(v);
    if (v !== null && minCr !== null && minCr > v) setMinCr(v);
  };
  const crOptions = [{ value: ALL, label: t.bestiaryAny }, ...crs.map(([cr, text]) => ({ value: String(cr), label: text }))];
  const clear = () => {
    setQuery('');
    setType(ALL);
    setMinCr(null);
    setMaxCr(null);
  };

  return (
    <div className="flex flex-col gap-4">
      <Heading count={visible.length} dm={dm} />

      <div className="flex flex-wrap items-center gap-x-3 gap-y-2.5">
        <div role="search" className="relative min-w-[min(220px,100%)] max-w-[320px] flex-[1_1_220px]">
          <label htmlFor="bestiary-search" className="sr-only">
            {t.bestiarySearch}
          </label>
          <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
          <input
            id="bestiary-search"
            type="search"
            autoComplete="off"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.bestiarySearch}
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
        <Select
          label={t.bestiaryTypeLabel}
          value={type}
          onValueChange={setType}
          options={[{ value: ALL, label: t.bestiaryAllTypes }, ...types.map(([id, label]) => ({ value: id, label }))]}
        />
        <Select
          label={t.bestiaryCrFrom}
          value={minCr === null ? ALL : String(minCr)}
          onValueChange={(v) => pickMin(v === ALL ? null : Number(v))}
          options={crOptions}
        />
        <Select
          label={t.bestiaryCrTo}
          value={maxCr === null ? ALL : String(maxCr)}
          onValueChange={(v) => pickMax(v === ALL ? null : Number(v))}
          options={crOptions}
        />
        {/* El orden no es un filtro: «Limpiar filtros» no lo toca. */}
        <div role="group" aria-label={t.bestiarySortLabel} className="flex gap-1.5">
          {([false, true] as const).map((byCr) => (
            <button
              key={String(byCr)}
              type="button"
              aria-pressed={sortByCr === byCr}
              onClick={() => setSortByCr(byCr)}
              className={cx(
                'rounded-[var(--radius-pill)] border px-3 py-[5px] text-[12.5px]',
                sortByCr === byCr
                  ? 'border-gold bg-gold-soft font-semibold text-gold'
                  : 'border-hairline text-on-surface-variant hover:text-on-surface',
              )}
            >
              {byCr ? t.bestiarySortCr : t.bestiarySortName}
            </button>
          ))}
        </div>
      </div>

      <div className="codex-split" data-open={open !== null}>
        <div>
          <section ref={listRef} aria-label={t.bestiaryTitle} className="codex-list card p-1.5" data-field="bestiary-list">
            {visible.length === 0 ? (
              <div className="p-2">
                <AppEmptyState
                  kind="no-match"
                  message={t.bestiaryNoMatch}
                  actions={
                    <Button tone="secondary" onClick={clear}>
                      {t.codexClearFilters}
                    </Button>
                  }
                />
              </div>
            ) : (
              <ul>
                {visible.map(({ row, profile }) => {
                  const on = row.id === open?.row.id;
                  return (
                    <li key={row.id}>
                      <Link
                        href={hrefOf(row.id)}
                        aria-current={on ? 'true' : undefined}
                        data-entry={row.id}
                        className={cx(
                          'flex items-center gap-2.5 rounded-[var(--radius-nav)] px-3 py-2',
                          on ? 'bg-gold-soft text-gold' : 'text-on-surface hover:bg-plaque',
                        )}
                      >
                        <span className="min-w-0 flex-1">
                          <span className={cx('block truncate text-[14px]', on && 'font-semibold')}>{profile.name}</span>
                          <span className="mt-0.5 block truncate text-[12px] text-text-muted">{row.kind}</span>
                        </span>
                        {row.crText !== null && (
                          <Pill highlighted>
                            <span className="num text-[12px]">{t.bestiaryCr(row.crText)}</span>
                          </Pill>
                        )}
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
                  href={hrefOf()}
                  className="codex-back mb-3 inline-flex items-center gap-1.5 text-[13px] text-on-surface-variant hover:text-gold"
                >
                  <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
                  {t.codexBackToList}
                </Link>
                <CreatureProfile profile={open.profile} row={open.row} catalog={catalog} />
              </>
            ) : (
              <p className="card p-6 text-on-surface-variant">{t.bestiaryPick}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
