import { useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import type { ChapterItem } from '../api/client';
import type { Catalog } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { BaseDialog } from '../sheet/MagicItemPlans';
import { catalogRows, FamilyFilter, type CatalogRow, type Family } from '../sheet/ItemCatalog';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';

/**
 * «Agregar objeto» para un capítulo o un regalo (`Selector` del Diseño): buscador, familias
 * y «Propios» sobre el catálogo del DM (SRD más **su** homebrew). Agregar no
 * cierra el diálogo —se suelen sumar varios— y la fila pasa a «Agregado»; una
 * sola acción, «Listo». Una plantilla pide su objeto base antes de agregarse, y
 * esa base nunca es de homebrew: el objeto se copia a la cuenta del jugador y la
 * base propia del DM no viaja con él.
 *
 * Solo se entrega lo que existe: no hay forma de sumar texto libre (decisión del
 * usuario, 2026-11-04). Los capítulos viejos que ya lo tienen lo conservan.
 */
export function ItemPicker({
  catalog,
  chosen,
  onAdd,
  onClose,
}: {
  catalog: Catalog;
  /** Lo que el capítulo ya reparte: marca las filas como «Agregado». */
  chosen: readonly ChapterItem[];
  onAdd: (item: ChapterItem) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const all = useMemo(() => catalogRows(catalog, t, lang), [catalog, t, lang]);
  const [query, setQuery] = useState('');
  const [family, setFamily] = useState<Family | 'all' | 'own'>('all');
  const [askBase, setAskBase] = useState<CatalogRow | null>(null);

  const homebrewIds = useMemo(() => new Set(all.filter((r) => r.homebrew).map((r) => r.id)), [all]);
  const needle = query.trim().toLowerCase();
  const matches = all.filter(
    (r) =>
      (needle === '' || r.name.toLowerCase().includes(needle)) &&
      (family === 'all' || (family === 'own' ? r.homebrew : r.family === family)),
  );

  const add = (row: CatalogRow, baseItemId?: string) =>
    onAdd({
      category: row.category,
      itemId: row.id,
      name: row.name,
      ...(baseItemId ? { baseItemId } : {}),
      quantity: 1,
      homebrew: row.homebrew,
    });
  const isChosen = (row: CatalogRow) => chosen.some((c) => c.category === row.category && c.itemId === row.id);

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.catalogAddTitle}
      width={560}
      actions={[{ label: t.commonDone, primary: true }]}
    >
      <div className="flex flex-col gap-2.5">
        <div className="relative">
          <Search size={16} aria-hidden="true" className="absolute top-1/2 left-3 -translate-y-1/2 text-text-muted" />
          <input
            type="search"
            autoFocus
            autoComplete="off"
            aria-label={t.catalogSearchHint}
            placeholder={t.catalogSearchHint}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            data-field="item-picker-search"
            className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-3 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
          />
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <FamilyFilter rows={all} family={family === 'own' ? 'all' : family} onChange={setFamily} label={t.catalogAddTitle} t={t} />
          {all.some((r) => r.homebrew) && (
            <button
              type="button"
              aria-pressed={family === 'own'}
              onClick={() => setFamily(family === 'own' ? 'all' : 'own')}
              className={cx(
                'shrink-0 rounded-[var(--radius-pill)] border px-3 py-[3px] text-[12px]',
                family === 'own' ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface-variant',
              )}
            >
              {t.itemPickOwn}
            </button>
          )}
        </div>
        {matches.length === 0 ? (
          <p className="py-6 text-center text-[13px] text-text-muted">{t.catalogNoMatches}</p>
        ) : (
          <ul className="h-[min(46vh,420px)] divide-y divide-hairline overflow-y-auto" data-field="item-picker">
            {matches.map((r) => {
              const done = isChosen(r) && !r.needsBase;
              return (
                <li key={`${r.category}:${r.id}`} className="flex items-center gap-3 py-2" data-item={r.id}>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[14px] text-on-surface">
                      {r.name}
                      {r.homebrew && (
                        <i className="ml-2 rounded-[var(--radius-pill)] border border-gold px-2 text-[11px] text-gold not-italic">
                          {t.itemOwnTag}
                        </i>
                      )}
                    </span>
                    <span className="block text-[11.5px] text-on-surface-variant">
                      {[r.detail, r.needsBase ? t.itemPickNeedsBase : null].filter(Boolean).join(' · ')}
                    </span>
                  </span>
                  <Button
                    tone={done ? 'secondary' : 'soft'}
                    disabled={done}
                    aria-label={`${r.needsBase ? t.itemPickChooseBase : done ? t.itemPickAdded : t.itemPickAdd}: ${r.name}`}
                    onClick={() => (r.needsBase ? setAskBase(r) : add(r))}
                  >
                    {r.needsBase ? t.itemPickChooseBase : done ? t.itemPickAdded : t.itemPickAdd}
                  </Button>
                </li>
              );
            })}
          </ul>
        )}
      </div>
      {askBase && (
        <BaseDialog
          catalog={catalog}
          itemId={askBase.id}
          title={askBase.name}
          confirm={t.crChoose}
          exclude={homebrewIds}
          onConfirm={(base) => {
            add(askBase, base);
            setAskBase(null);
          }}
          onClose={() => setAskBase(null)}
        />
      )}
    </AppDialog>
  );
}
