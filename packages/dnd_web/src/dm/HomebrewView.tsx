import { useMemo, useRef, useState, type ReactNode } from 'react';
import { ArrowLeft, Copy, Download, Pencil, PawPrint, Plus, Search, Trash2, Upload, X, type LucideIcon } from 'lucide-react';
import { CATEGORIES, downloadText } from '../api/homebrew';
import { useHomebrew, useSheetCatalog } from '../api/queries';
import { CategoryView, ICONS } from '../codex/CodexPage';
import { codexEntries, fold, type CodexEntry } from '../codex/entries';
import { bestiary, homebrewExport, type Catalog } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import {
  dmBestiaryHref,
  dmHomebrewEditHref,
  dmHomebrewHref,
  dmHomebrewNewHref,
  HOMEBREW_CATEGORIES,
  Link,
  navigate,
  type HomebrewCategory,
} from '../router';
import { Button, ButtonLink } from '../ui/Button';
import { cx } from '../ui/cx';
import { showNotice } from '../ui/notices';
import { Tooltip } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { DeleteHomebrewDialog } from './DeleteHomebrewDialog';
import { DmHeader } from './DmHeader';
import { DuplicateFromCatalogDialog } from './DuplicateFromCatalogDialog';
import { storageOf } from './homebrewKinds';
import { ImportHomebrewDialog } from './ImportHomebrewDialog';

/** Una entrada propia, sea del Códice o una criatura. */
interface Own {
  id: string;
  name: string;
  subtitle: string;
}

/**
 * El Homebrew de la cuenta (`homebrew_screen.dart`): lo propio de cada
 * categoría, con la misma lista y la misma ficha del Códice (la vista es
 * `CategoryView`, montada con las URL del Modo DM). Una criatura propia se lee
 * en el perfil del Bestiario, que ya la trae. Lo propio es lo que el catálogo
 * fusionado marca `homebrew`: el que llega de `/api/homebrew`, de esta cuenta y
 * de ninguna otra.
 *
 * Desde acá se **importa y se exporta** todo el homebrew (en la portada), se
 * **borra** cualquier entrada propia (en su ficha) y se **crean, editan y
 * duplican las ocho categorías**: criaturas, dotes, especies, trasfondos, armas,
 * armaduras, objetos y conjuros.
 *
 * ponytail: Flutter además lista las entradas inválidas que no pudo cargar
 * (`loadIssues`) para borrarlas; `fetchHomebrew` las descarta al leer y esta
 * pantalla no las ve. El servidor valida al guardar, así que no debería haber.
 * Si aparece una, el camino es exponer la validación por entrada en el puente
 * (`js/entrypoint.dart`) y listarla acá.
 */
export function HomebrewView({ category, entryId }: { category: HomebrewCategory | null; entryId: string | null }) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  // Borrar una entrada que no es criatura: el diálogo vive acá y no en la ficha,
  // que se desmonta al volver a la lista.
  const [deleting, setDeleting] = useState<{ category: HomebrewCategory; id: string; name: string } | null>(null);
  // «Duplicar del catálogo»: el selector de lo que no es propio.
  const [picking, setPicking] = useState(false);

  // Por categoría, solo lo propio y en el orden del Códice.
  const own = useMemo(() => {
    const cat = catalog.data;
    if (!cat) return null;
    const codex = new Map(
      HOMEBREW_CATEGORIES.map((c) => [c, codexEntries(c, cat, t, lang).filter((e) => e.source === 'homebrew')] as const),
    );
    // El motor da el orden y la línea de tipo; lo propio lo dice el catálogo.
    const mine = new Set(cat.creatures.filter((c) => c.source === 'homebrew').map((c) => c.id));
    const names = new Map(cat.creatures.map((c) => [c.id, typeof c.name === 'string' ? c.name : String(c.id)] as const));
    const creatures: Own[] = bestiary(cat)
      .filter((r) => mine.has(r.id))
      .map((r) => ({ id: r.id, name: names.get(r.id) ?? r.id, subtitle: r.kind }));
    return { codex, creatures };
  }, [catalog.data, t, lang]);

  const failed = catalog.queries.filter((q) => q.isError);
  const total = own ? [...own.codex.values()].reduce((n, l) => n + l.length, own.creatures.length) : 0;
  const headerWith = (actions?: ReactNode) => (
    <DmHeader title={t.navHomebrew} kicker={own ? t.dmHomebrewCount(total) : undefined} actions={actions} />
  );
  const header = headerWith();

  if (failed.length > 0) {
    return (
      <div className="flex flex-col gap-5">
        {header}
        <AppErrorView title={t.dmHomebrewReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      </div>
    );
  }
  if (!own || !catalog.data) {
    return (
      <div className="flex flex-col gap-5">
        {header}
        <AppBusyLabel label={t.dmHomebrewLoading} />
      </div>
    );
  }
  if (category === 'creatures') {
    return <CreatureList creatures={own.creatures} catalog={catalog.data} headerWith={headerWith} />;
  }
  if (category !== null) {
    // Toda categoría con lista se crea, se edita y se duplica desde acá.
    // «Objetos mágicos» y «Equipo» son dos categorías del Códice pero un solo
    // editor: `items`.
    const editable = category === 'magicItems' || category === 'gear' ? ('items' as const) : category;
    const labels = {
      feats: { create: t.hbNewFeat, action: 'homebrew-new-feat', empty: t.hbFeatEmpty },
      races: { create: t.hbNewRace, action: 'homebrew-new-race', empty: t.hbRaceEmpty },
      backgrounds: { create: t.hbNewBackground, action: 'homebrew-new-background', empty: t.hbBackgroundEmpty },
      weapons: { create: t.hbNewWeapon, action: 'homebrew-new-weapon', empty: t.hbWeaponEmpty },
      armor: { create: t.hbNewArmor, action: 'homebrew-new-armor', empty: t.hbArmorEmpty },
      items: { create: t.hbNewItem, action: 'homebrew-new-item', empty: t.hbItemEmpty },
      spells: { create: t.hbNewSpell, action: 'homebrew-new-spell', empty: t.hbSpellEmpty },
    };
    const duplicate = (
      <Button tone="secondary" icon={Copy} onClick={() => setPicking(true)} data-action="homebrew-duplicate-catalog">
        {t.hbDuplicateFromCatalog}
      </Button>
    );
    const create = (
      <ButtonLink internal icon={Plus} href={dmHomebrewNewHref(editable)} data-action={labels[editable].action}>
        {labels[editable].create}
      </ButtonLink>
    );
    const categoryHeader = headerWith(
      <>
        {duplicate}
        {create}
      </>,
    );
    const picker = picking && (
      <DuplicateFromCatalogDialog
        category={editable}
        catalog={catalog.data}
        onClose={() => setPicking(false)}
        onPick={(id) => {
          setPicking(false);
          navigate(dmHomebrewNewHref(editable, id));
        }}
      />
    );
    // Sin nada propio en la categoría, el vacío es «no hay», no el «nada
    // coincide» de una lista filtrada.
    if (own.codex.get(category)!.length === 0) {
      return (
        <div className="flex flex-col gap-4">
          <BackToHome />
          {categoryHeader}
          {picker}
          <AppEmptyState
            kind="empty"
            message={labels[editable].empty}
            actions={
              <>
                {create}
                {duplicate}
              </>
            }
          />
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
          header={categoryHeader}
          detailActions={(entry) => (
            // «Editar», «Duplicar» y «Borrar», en el mismo orden y forma que el
            // perfil de una criatura.
            <>
              <ButtonLink internal tone="secondary" icon={Pencil} href={dmHomebrewEditHref(editable, entry.id)} data-action="homebrew-edit">
                {t.commonEdit}
              </ButtonLink>
              <Tooltip content={t.hbDuplicateTooltip}>
                <button
                  type="button"
                  aria-label={t.hbDuplicateTitle(entry.name)}
                  data-action="homebrew-duplicate"
                  onClick={() => navigate(dmHomebrewNewHref(editable, entry.id))}
                  className="inline-flex size-9 items-center justify-center rounded-[var(--radius-nav)] border border-hairline text-on-surface hover:bg-plaque"
                >
                  <Copy size={16} aria-hidden="true" />
                </button>
              </Tooltip>
              <Tooltip content={t.cardDelete}>
                <button
                  type="button"
                  aria-label={t.hbDeleteTooltip(entry.name)}
                  data-action="homebrew-delete"
                  onClick={() => setDeleting({ category, id: entry.id, name: entry.name })}
                  className="inline-flex size-9 items-center justify-center rounded-[var(--radius-nav)] border border-hairline text-crimson hover:bg-plaque"
                >
                  <Trash2 size={16} aria-hidden="true" />
                </button>
              </Tooltip>
            </>
          )}
        />
        {picker}
        {deleting && (
          <DeleteHomebrewDialog
            category={storageOf(deleting.category)}
            id={deleting.id}
            name={deleting.name}
            onClose={() => setDeleting(null)}
            onDeleted={() => navigate(dmHomebrewHref(deleting.category))}
          />
        )}
      </div>
    );
  }
  return <Home own={own} total={total} headerWith={headerWith} />;
}

function BackToHome() {
  const t = useTexts();
  return (
    <Link back href={dmHomebrewHref()} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.luBack}
    </Link>
  );
}

/** La portada: una tarjeta por categoría con lo propio que tiene, y un
 *  buscador que mira todas a la vez: con lo propio uno se acuerda del nombre,
 *  no de en qué categoría lo guardó (como en Flutter). Acá también se importa
 *  y se exporta todo. */
function Home({
  own,
  total,
  headerWith,
}: {
  own: { codex: Map<(typeof HOMEBREW_CATEGORIES)[number], CodexEntry[]>; creatures: Own[] };
  total: number;
  headerWith: (actions?: ReactNode) => ReactNode;
}) {
  const t = useTexts();
  const homebrew = useHomebrew();
  const [query, setQuery] = useState('');
  // Elegir el archivo abre el diálogo de la vista previa; el `input` queda
  // oculto y lo abren los dos «Importar archivo» (el de la cabecera y el del vacío).
  const picker = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);

  const exportAll = () => {
    const content = homebrew.data;
    if (!content) return;
    // Lo que viaja lo arma el motor, en el formato `dnd_homebrew` de Flutter.
    const count = CATEGORIES.reduce((n, c) => n + (content[c]?.length ?? 0), 0);
    const { fileName, text } = homebrewExport(content, new Date());
    downloadText(fileName, text);
    showNotice(t.hbExported(count));
  };
  const importButton = (
    <Button tone="secondary" icon={Upload} onClick={() => picker.current?.click()} data-action="homebrew-import">
      {t.hbImportFile}
    </Button>
  );

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
    body = <AppEmptyState kind="empty" message={t.dmHomebrewEmpty} hint={t.dmHomebrewEmptyHint} actions={importButton} />;
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

  // Sin nada propio no hay qué exportar: «Exportar todo» no aparece, y
  // «Importar archivo» va en el estado vacío.
  const actions =
    total > 0 ? (
      <>
        {importButton}
        <Button tone="secondary" icon={Download} onClick={exportAll} disabled={!homebrew.data} data-action="homebrew-export">
          {t.hbExportAll}
        </Button>
      </>
    ) : undefined;

  return (
    <div className="flex flex-col gap-5">
      {headerWith(actions)}
      <input
        ref={picker}
        type="file"
        hidden
        accept=".json,application/json"
        aria-label={t.hbPickFile}
        data-field="homebrew-import-file"
        onChange={(e) => {
          setFile(e.currentTarget.files?.[0] ?? null);
          // Sin esto, elegir de nuevo el mismo archivo no dispararía el cambio.
          e.currentTarget.value = '';
        }}
      />
      {file && <ImportHomebrewDialog file={file} onClose={() => setFile(null)} />}
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
 *  es donde se lee una criatura (no hay una segunda ficha) y donde están sus
 *  acciones. Acá se crea una nueva, vacía o copiada del catálogo. */
function CreatureList({
  creatures,
  catalog,
  headerWith,
}: {
  creatures: Own[];
  catalog: Catalog;
  headerWith: (actions?: ReactNode) => ReactNode;
}) {
  const t = useTexts();
  const [picking, setPicking] = useState(false);
  const duplicate = (
    <Button tone="secondary" icon={Copy} onClick={() => setPicking(true)} data-action="homebrew-duplicate-catalog">
      {t.hbDuplicateFromCatalog}
    </Button>
  );
  const create = (
    <ButtonLink internal icon={Plus} href={dmHomebrewNewHref('creatures')} data-action="homebrew-new-creature">
      {t.hbNewCreature}
    </ButtonLink>
  );
  return (
    <div className="flex flex-col gap-4">
      <BackToHome />
      {headerWith(
        <>
          {duplicate}
          {create}
        </>,
      )}
      {picking && (
        <DuplicateFromCatalogDialog
          category="creatures"
          catalog={catalog}
          onClose={() => setPicking(false)}
          onPick={(id) => {
            setPicking(false);
            navigate(dmHomebrewNewHref('creatures', id));
          }}
        />
      )}
      {creatures.length === 0 ? (
        <AppEmptyState
          kind="empty"
          message={t.dmHomebrewNoCreatures}
          actions={
            <>
              {create}
              {duplicate}
            </>
          }
        />
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
