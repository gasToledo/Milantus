import { useMemo, useState } from 'react';
import { Copy } from 'lucide-react';
import { codexEntries, fold } from '../codex/entries';
import { bestiary, catalogLabel, type Catalog } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

/** Las categorías que se duplican desde el catálogo. */
export type DuplicableCategory = 'creatures' | 'feats' | 'races' | 'backgrounds' | 'weapons' | 'armor' | 'items';

/**
 * «Duplicar criatura» / «Duplicar dote» / «Duplicar especie» / «Duplicar
 * trasfondo» (`_CatalogPicker` de Flutter): elegir una
 * del catálogo para abrirla como copia propia. Salen solo las que **no** son
 * tuyas, porque para lo propio está «Duplicar» en su perfil. Las criaturas
 * llevan el orden y la línea de tipo del motor (`bestiary`), igual que el
 * Bestiario; el resto, el orden y la línea secundaria del Códice (la categoría
 * de la dote, el lema o el tipo de la especie, las características del
 * trasfondo, la categoría y el daño del arma, la categoría y la CA de la
 * armadura).
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
  const title = {
    creatures: t.hbDuplicateCreature,
    feats: t.hbDuplicateFeat,
    races: t.hbDuplicateRace,
    backgrounds: t.hbDuplicateBackground,
    weapons: t.hbDuplicateWeapon,
    armor: t.hbDuplicateArmor,
    items: t.hbDuplicateItem,
  }[category];

  const options = useMemo(() => {
    if (category === 'items') {
      // Los objetos viven en dos categorías del Códice —equipo y objetos
      // mágicos— pero son una sola en el Homebrew: se ofrecen los dos, por orden
      // alfabético. La línea secundaria es la familia si es mundano y la rareza
      // si es mágico.
      return [...codexEntries('gear', catalog, t, lang), ...codexEntries('magicItems', catalog, t, lang)]
        .filter((e) => e.source !== 'homebrew')
        .map((e) => ({ id: e.id, name: e.name, kind: e.facet ?? e.subtitle }))
        .sort((a, b) => a.name.localeCompare(b.name, lang));
    }
    if (category !== 'creatures') {
      // El trasfondo se reconoce por sus características, no por su lema.
      const abilities = new Map(
        catalog.backgrounds.map((b) => [b.id, (Array.isArray(b.abilityOptions) ? b.abilityOptions : []).map((a) => catalogLabel('ability', String(a))).join(' · ')] as const),
      );
      return codexEntries(category, catalog, t, lang)
        .filter((e) => e.source !== 'homebrew')
        .map((e) => ({ id: e.id, name: e.name, kind: category === 'backgrounds' ? (abilities.get(e.id) ?? '') : e.subtitle }));
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
