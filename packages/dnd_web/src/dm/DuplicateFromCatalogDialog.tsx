import { useMemo, useState } from 'react';
import { Copy } from 'lucide-react';
import { codexEntries, fold } from '../codex/entries';
import { bestiary, type Catalog } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

/** Las categorías que se duplican desde el catálogo. */
export type DuplicableCategory = 'creatures' | 'feats';

/**
 * «Duplicar criatura» / «Duplicar dote» (`_CatalogPicker` de Flutter): elegir una
 * del catálogo para abrirla como copia propia. Salen solo las que **no** son
 * tuyas, porque para lo propio está «Duplicar» en su perfil. Las criaturas
 * llevan el orden y la línea de tipo del motor (`bestiary`), igual que el
 * Bestiario; las dotes, el orden y la categoría del Códice.
 */
export function DuplicateFromCatalogDialog({
  category,
  catalog,
  onPick,
  onClose,
}: {
  category: DuplicableCategory;
  catalog: Catalog;
  onPick: (id: string) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const [query, setQuery] = useState('');
  const title = category === 'creatures' ? t.hbDuplicateCreature : t.hbDuplicateFeat;

  const options = useMemo(() => {
    if (category === 'feats') {
      return codexEntries('feats', catalog, t, lang)
        .filter((e) => e.source !== 'homebrew')
        .map((e) => ({ id: e.id, name: e.name, kind: e.subtitle }));
    }
    const names = new Map(catalog.creatures.filter((c) => c.source !== 'homebrew').map((c) => [c.id, String(c.name ?? c.id)] as const));
    return bestiary(catalog)
      .filter((r) => names.has(r.id))
      .map((r) => ({
        id: r.id,
        name: names.get(r.id)!,
        kind: [r.kind, r.crText !== null ? t.bestiaryCr(r.crText) : null].filter(Boolean).join(' · '),
      }));
  }, [category, catalog, t, lang]);

  const needle = fold(query.trim());
  const visible = needle ? options.filter((o) => fold(o.name).includes(needle)) : options;

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      icon={Copy}
      actions={[{ label: t.cancel }]}
    >
      <div className="flex flex-col gap-2.5">
        <label className="flex flex-col gap-1.5 text-[12px] text-text-muted">
          {t.hbSearchCatalog}
          <input
            type="search"
            autoComplete="off"
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            data-field="homebrew-catalog-search"
            className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque px-3.5 text-[14px] text-on-surface"
          />
        </label>
        {visible.length === 0 ? (
          <p className="text-[14px] text-on-surface-variant">{t.hbCatalogNoMatch(query.trim())}</p>
        ) : (
          <ul aria-label={title} className="plaque max-h-[320px] overflow-y-auto rounded-[var(--radius-card)] border border-hairline p-1">
            {visible.map((o) => (
              <li key={o.id}>
                <button
                  type="button"
                  data-entry={o.id}
                  onClick={() => onPick(o.id)}
                  className="flex w-full justify-between gap-2.5 rounded-[var(--radius-nav)] px-2.5 py-2 text-left text-[14px] text-on-surface hover:bg-surface"
                >
                  <span>{o.name}</span>
                  <span className="text-[12px] text-text-muted">{o.kind}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </AppDialog>
  );
}
