import { useMemo, useState, type ReactNode } from 'react';
import { ArrowLeft, PawPrint, Search, X, type LucideIcon } from 'lucide-react';
import { useSheetCatalog } from '../api/queries';
import { CategoryView, ICONS } from '../codex/CodexPage';
import { codexEntries, fold, type CodexEntry } from '../codex/entries';
import { bestiary } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { dmBestiaryHref, dmHomebrewHref, HOMEBREW_CATEGORIES, Link, type HomebrewCategory } from '../router';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { DmHeader } from './DmHeader';

/** Una entrada propia, sea del Códice o una criatura. */
interface Own {
  id: string;
  name: string;
  subtitle: string;
}

/**
 * El Homebrew de la cuenta (`homebrew_screen.dart`), de solo lectura: lo propio
 * de cada categoría, con la misma lista y la misma ficha del Códice (la vista
 * es `CategoryView`, montada con las URL del Modo DM). Una criatura propia se
 * lee en el perfil del Bestiario, que ya la trae. Lo propio es lo que el
 * catálogo fusionado marca `homebrew`: el que llega de `/api/homebrew`, de esta
 * cuenta y de ninguna otra. Crear, editar, importar, exportar y borrar siguen
 * en Flutter.
 */
export function HomebrewView({ category, entryId }: { category: HomebrewCategory | null; entryId: string | null }) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);

  // Por categoría, solo lo propio y en el orden del Códice.
  const own = useMemo(() => {
    const cat = catalog.data;
    if (!cat) return null;
    const codex = new Map(
      HOMEBREW_CATEGORIES.map((c) => [c, codexEntries(c, cat, t, lang).filter((e) => e.source === 'homebrew')] as const),
    );
    // El motor da el orden y la línea de tipo; lo propio lo dice el catálogo.
    const mine = new Set(cat.creatures.filter((c) => c.source === 'homebrew').map((c) => c.id));
    const names = new Map(cat.creatures.map((c) => [c.id, typeof c.name === 'string' ? c.name : c.id] as const));
    const creatures: Own[] = bestiary(cat)
      .filter((r) => mine.has(r.id))
      .map((r) => ({ id: r.id, name: names.get(r.id) ?? r.id, subtitle: r.kind }));
    return { codex, creatures };
  }, [catalog.data, t, lang]);

  const failed = catalog.queries.filter((q) => q.isError);
  const total = own ? [...own.codex.values()].reduce((n, l) => n + l.length, own.creatures.length) : 0;
  const header = <DmHeader title={t.navHomebrew} kicker={own ? `${t.dmHomebrewCount(total)} · ${t.dmReadOnly}` : t.dmReadOnly} />;

  if (failed.length > 0) {
    return (
      <div className="flex flex-col gap-5">
        {header}
        <AppErrorView title={t.dmHomebrewReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      </div>
    );
  }
  if (!own) {
    return (
      <div className="flex flex-col gap-5">
        {header}
        <AppBusyLabel label={t.dmHomebrewLoading} />
      </div>
    );
  }
  if (category === 'creatures') return <CreatureList creatures={own.creatures} header={header} />;
  if (category !== null) {
    // Sin nada propio en la categoría, el vacío es «no hay», no el «nada
    // coincide» de una lista filtrada.
    if (own.codex.get(category)!.length === 0) {
      return (
        <div className="flex flex-col gap-4">
          <BackToHome />
          {header}
          <AppEmptyState kind="empty" message={t.dmHomebrewEmptyIn(t.codexCategories[category])} hint={t.dmHomebrewEmptyHint} />
        </div>
      );
    }
    return (
      <div className="flex flex-col gap-4">
        <BackToHome />
        <CategoryView
          key={category}
          category={category}
          entries={own.codex.get(category)!}
          entryId={entryId}
          hrefOf={(c, id) => dmHomebrewHref(c as HomebrewCategory, id)}
          header={header}
        />
      </div>
    );
  }
  return <Home own={own} total={total} header={header} />;
}

function BackToHome() {
  const t = useTexts();
  return (
    <Link href={dmHomebrewHref()} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.navHomebrew}
    </Link>
  );
}

/** La portada: una tarjeta por categoría con lo propio que tiene, y un
 *  buscador que mira todas a la vez: con lo propio uno se acuerda del nombre,
 *  no de en qué categoría lo guardó (como en Flutter). */
function Home({
  own,
  total,
  header,
}: {
  own: { codex: Map<(typeof HOMEBREW_CATEGORIES)[number], CodexEntry[]>; creatures: Own[] };
  total: number;
  header: ReactNode;
}) {
  const t = useTexts();
  const [query, setQuery] = useState('');
  const sections: { c: HomebrewCategory; label: string; icon: LucideIcon; list: Own[] }[] = [
    ...HOMEBREW_CATEGORIES.map((c) => ({ c, label: t.codexCategories[c], icon: ICONS[c], list: own.codex.get(c)! })),
    { c: 'creatures' as const, label: t.dmHomebrewCreatures, icon: PawPrint, list: own.creatures },
  ];
  // Una criatura se abre en el Bestiario; lo demás, en su categoría.
  const href = (c: HomebrewCategory, id: string) => (c === 'creatures' ? dmBestiaryHref(id) : dmHomebrewHref(c, id));
  const needle = fold(query.trim());
  const hits = needle
    ? sections.flatMap(({ c, label, list }) => list.filter((e) => fold(e.name).includes(needle)).map((e) => ({ c, label, e })))
    : null;

  let body;
  if (total === 0) {
    body = <AppEmptyState kind="empty" message={t.dmHomebrewEmpty} hint={t.dmHomebrewEmptyHint} />;
  } else if (hits && hits.length === 0) {
    body = (
      <AppEmptyState
        kind="no-match"
        message={t.codexNoMatch(query.trim())}
        actions={
          <Button tone="secondary" icon={X} onClick={() => setQuery('')}>
            {t.rosterClearSearch}
          </Button>
        }
      />
    );
  } else if (hits) {
    body = (
      <ul aria-label={t.dmHomebrewSearch} className="card max-w-[720px] p-1.5">
        {hits.map(({ c, label, e }) => (
          <li key={`${c}/${e.id}`}>
            <Link href={href(c, e.id)} className="flex flex-wrap items-baseline gap-x-2.5 rounded-[var(--radius-nav)] px-3 py-2 hover:bg-plaque" data-entry={e.id}>
              <span className="text-[14px] text-on-surface">{e.name}</span>
              <span className="text-[12px] text-text-muted">{label}</span>
            </Link>
          </li>
        ))}
      </ul>
    );
  } else {
    body = (
      <ul className="grid gap-3 [grid-template-columns:repeat(auto-fill,minmax(min(260px,100%),1fr))]">
        {sections.map(({ c, label, icon: Icon, list }) => {
          const empty = list.length === 0;
          return (
            <li key={c}>
              <Link href={dmHomebrewHref(c)} className="card block px-4 py-[15px] hover:border-gold" data-category={c}>
                <span className="flex items-center gap-2.5">
                  <Icon size={20} aria-hidden="true" className={cx('shrink-0', empty ? 'text-text-muted' : 'text-gold')} />
                  <span className={cx('font-display flex-1 text-[17px]', empty ? 'text-text-muted' : 'text-on-surface')}>{label}</span>
                  <span className={cx('num text-[18px]', empty ? 'text-text-muted' : 'text-gold')}>
                    <span aria-hidden="true">{list.length}</span>
                    <span className="sr-only">{t.codexEntries(list.length)}</span>
                  </span>
                </span>
                <span aria-hidden="true" className="mt-2 block truncate text-[13px] text-text-muted">
                  {empty ? t.dmHomebrewNothingYet : list.slice(0, 3).map((e) => e.name).join(' · ')}
                </span>
              </Link>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      {header}
      {total > 0 && (
        <div role="search" className="relative max-w-[320px]">
          <label htmlFor="homebrew-search" className="sr-only">
            {t.dmHomebrewSearch}
          </label>
          <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-2.5 left-3 text-text-muted" />
          <input
            id="homebrew-search"
            type="search"
            autoComplete="off"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.dmHomebrewSearch}
            className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-3 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
          />
        </div>
      )}
      {body}
    </div>
  );
}

/** Las criaturas propias: cada una abre su perfil en el Bestiario del DM, que
 *  es donde se lee una criatura (no hay una segunda ficha). */
function CreatureList({ creatures, header }: { creatures: Own[]; header: ReactNode }) {
  const t = useTexts();
  return (
    <div className="flex flex-col gap-4">
      <BackToHome />
      {header}
      {creatures.length === 0 ? (
        <AppEmptyState kind="empty" message={t.dmHomebrewNoCreatures} hint={t.dmHomebrewEmptyHint} />
      ) : (
        <ul aria-label={t.dmHomebrewCreatures} className="card max-w-[720px] p-1.5">
          {creatures.map((c) => (
            <li key={c.id}>
              <Link href={dmBestiaryHref(c.id)} className="block rounded-[var(--radius-nav)] px-3 py-2 hover:bg-plaque" data-entry={c.id}>
                <span className="block text-[14px] text-on-surface">{c.name}</span>
                <span className="mt-0.5 block truncate text-[12px] text-text-muted">{c.subtitle}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
