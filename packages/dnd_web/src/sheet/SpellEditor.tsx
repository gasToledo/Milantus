import { useEffect, useMemo, useState } from 'react';
import { ArrowLeft, Info, X } from 'lucide-react';
import { nameOf } from '../api/catalog';
import { codexEntries } from '../codex/entries';
import { spellEditView, vocabularyLabel, type CharacterJson, type SpellEditView } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { Link, navigate } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button, ButtonLink } from '../ui/Button';
import { Eyebrow } from '../ui/data';
import { Notice } from '../ui/status';
import { DetailBody, Option, SearchableList, SpellTabs, Status, WIZARD_ASIDE, WizardFooter } from '../ui/wizard';
import type { SheetModel } from './model';
import type { SpellJson } from './SpellList';
import type { SheetWriter } from './writer';

/**
 * El editor de conjuros de una clase de la ficha propia (`SpellEditScreen` de
 * Flutter, con el circuito de los asistentes): trucos y conjuros en pestañas,
 * lo elegido en una bandeja de chips que se sacan con ✕ y, a la derecha, qué
 * es lo último que se tocó. Qué se puede elegir, lo concedido por rasgos y
 * los topes lo dice el motor (`spellEditView`); guardar es una sola acción
 * `setClassSpells`, que no valida el tope a propósito (una ficha pasada de
 * cupo se arregla sacando de a uno).
 *
 * Con el cupo lleno una opción se ve atenuada pero responde: muestra su
 * detalle y el pie dice por qué no se elige. Nada se pliega ni avanza solo:
 * completar un cupo no cambia de pestaña.
 */
export function SpellEditor({ model, write, classId }: { model: SheetModel; write: SheetWriter; classId: string }) {
  const t = useTexts();
  const raw = model.character as unknown as CharacterJson;
  const view = useMemo(() => spellEditView(raw, model.catalog, classId), [raw, model.catalog, classId]);
  if (!view) return <Notice title={t.notFoundTitle} body={t.notFoundBody} />;
  return <Editor model={model} write={write} classId={classId} view={view} />;
}

type TabKey = 'cantrips' | 'spells';

function Editor({
  model,
  write,
  classId,
  view,
}: {
  model: SheetModel;
  write: SheetWriter;
  classId: string;
  view: SpellEditView;
}) {
  const t = useTexts();
  const lang = useLang();
  const { sheet, catalog } = model;

  // Lo guardado al abrir: contra eso se compara para apagar «Guardar» y para
  // decir qué sale y qué entra.
  const [saved] = useState(() => ({ cantrips: view.chosenCantrips, spells: view.chosenSpells }));
  const [chosen, setChosen] = useState(saved);
  const [tab, setTab] = useState<TabKey>('spells');
  const [focus, setFocus] = useState<string | null>(null);
  const [sheetId, setSheetId] = useState<string | null>(null);
  // La opción que se tocó con el cupo lleno, para decir por qué no entró.
  const [blocked, setBlocked] = useState<string | null>(null);

  const spellById = useMemo(() => new Map(catalog.spells.map((s) => [s.id, s as SpellJson])), [catalog.spells]);
  const details = useMemo(() => codexEntries('spells', catalog, t, lang), [catalog, t, lang]);
  const nameOfSpell = (id: string) => spellById.get(id)?.name ?? id;

  const block = sheet.spellcastingBlocks.find((b) => b.classId === classId)?.spellcasting ?? sheet.spellcasting;
  const maxLevel = Math.max(0, ...Object.keys(block?.slotsByLevel ?? {}).map(Number));
  const className = nameOf(catalog.classes, classId) ?? classId;

  const tabs = [
    ...(view.cantripsKnown > 0
      ? [
          {
            key: 'cantrips' as const,
            title: t.luCantripsTitle,
            cap: view.cantripsKnown as number | null,
            list: chosen.cantrips,
            options: view.cantrips.map((c) => ({ ...c, level: 0 })),
            granted: view.grantedCantrips,
            chosenLabel: t.seChosenCantrips,
            searchLabel: t.luSpellSearch,
            count: t.seCountCantrips(view.cantrips.length),
          },
        ]
      : []),
    {
      key: 'spells' as const,
      title: view.prepared ? t.luPreparedTitle : t.luKnownTitle,
      // Quien conoce conjuros no tiene tope (como en Flutter).
      cap: (view.prepared ? view.preparedCount : null) as number | null,
      list: chosen.spells,
      // Por nivel, y dentro del nivel como los trae el motor.
      options: [...view.spells].sort((a, b) => a.level - b.level),
      granted: view.grantedSpells,
      chosenLabel: t.seChosenSpells,
      searchLabel: t.luSpellSearch,
      count: t.seCountSpells(view.spells.length, maxLevel),
    },
  ].map((x) => ({
    ...x,
    ready: x.cap === null ? x.list.length > 0 : x.list.length === x.cap,
    status: x.cap === null ? undefined : ([x.list.length, x.cap] as [number, number]),
  }));
  const cur = tabs.find((x) => x.key === tab) ?? tabs[tabs.length - 1]!;
  const full = cur.cap !== null && cur.list.length >= cur.cap;

  const setList = (key: TabKey, ids: string[]) => {
    setChosen((c) => ({ ...c, [key === 'cantrips' ? 'cantrips' : 'spells']: ids }));
    setBlocked(null);
  };
  const toggle = (id: string) => {
    setFocus(id);
    if (cur.list.includes(id)) setList(cur.key, cur.list.filter((x) => x !== id));
    else if (full) setBlocked(id);
    else setList(cur.key, [...cur.list, id]);
  };

  const now = [...chosen.cantrips, ...chosen.spells];
  const before = [...saved.cantrips, ...saved.spells];
  const out = before.filter((id) => !now.includes(id));
  const into = now.filter((id) => !before.includes(id));
  const unchanged = out.length === 0 && into.length === 0;
  const names = (ids: string[]) => ids.map(nameOfSpell).join(', ');
  const message =
    blocked && !cur.list.includes(blocked)
      ? t.seFull(nameOfSpell(blocked))
      : [out.length > 0 ? t.seOut(names(out), out.length) : '', into.length > 0 ? t.seIn(names(into), into.length) : '']
          .filter(Boolean)
          .join(' ') || null;

  // Cambios sin guardar: el navegador avisa antes de cerrar o recargar.
  useEffect(() => {
    if (unchanged) return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [unchanged]);

  const save = () => {
    const r = write.act({ type: 'setClassSpells', classId, cantrips: chosen.cantrips, spells: chosen.spells });
    if (!r) return;
    navigate(write.routes.sheet('combate'));
    write.notify(t.seSaved, { undo: () => write.restore(r.before) });
  };

  const focused = focus ? details.find((e) => e.id === focus) : undefined;
  const sheetEntry = sheetId ? details.find((e) => e.id === sheetId) : undefined;
  const noteOf = (id: string) => {
    const s = spellById.get(id);
    return [
      s?.school ? vocabularyLabel('school', s.school) : null,
      s?.concentration ? t.concentration : null,
      s?.ritual ? t.ritual : null,
    ]
      .filter(Boolean)
      .join(' · ');
  };
  const title = view.prepared ? t.seTitlePrepare(className) : t.seTitleEdit(className);

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="spell-edit">
      <header className="flex flex-col gap-1">
        <Link
          href={write.routes.sheet('combate')}
          className="inline-flex min-h-9 items-center gap-1.5 self-start text-[13px] text-gold no-underline hover:text-on-surface"
        >
          <ArrowLeft size={14} aria-hidden="true" />
          {t.seBack}
        </Link>
        <h1 className="font-display text-[24px] text-on-surface">{title}</h1>
      </header>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="card flex min-w-0 flex-col gap-3 p-4">
          <SpellTabs
            tabs={tabs.map((x) => ({ key: x.key, title: x.title, ready: x.ready, count: x.status }))}
            current={cur.key}
            onSelect={(k) => {
              setTab(k as TabKey);
              setBlocked(null);
            }}
            label={t.seTabs}
            t={t}
          />
          <ul aria-label={cur.chosenLabel} className="flex min-h-9 flex-wrap items-center gap-1.5">
            {cur.list.length === 0 && <li className="text-[12.5px] text-on-surface-variant">{t.crNoneYet}</li>}
            {cur.list.map((id) => (
              <li key={id}>
                <button
                  type="button"
                  data-chip={id}
                  aria-label={t.seRemoveSpell(nameOfSpell(id))}
                  onClick={() => {
                    setList(cur.key, cur.list.filter((x) => x !== id));
                  }}
                  className="inline-flex h-9 items-center gap-1.5 rounded-[var(--radius-pill)] border border-gold bg-gold-soft pr-2 pl-3 text-[12.5px] whitespace-nowrap text-on-surface"
                >
                  {nameOfSpell(id)}
                  <X size={14} strokeWidth={2.5} aria-hidden="true" className="text-gold" />
                </button>
              </li>
            ))}
          </ul>
          {/* Con `key`, cada pestaña arranca con el buscador vacío. */}
          <SearchableList
            key={cur.key}
            items={cur.options}
            textOf={(o) => o.name}
            label={cur.searchLabel}
            count={cur.count}
            columns={2}
            multi
            height="max-h-[396px]"
            groupOf={cur.key === 'spells' ? (o) => t.spellLevelShort(o.level) : undefined}
          >
            {(o) => {
              const on = cur.list.includes(o.id);
              return (
                <div key={o.id} className="flex min-w-0 shrink-0 items-stretch gap-1.5">
                  <div className="min-w-0 flex-1">
                    <Option
                      id={o.id}
                      multi
                      selected={on}
                      blocked={!on && full}
                      title={o.name}
                      detail={noteOf(o.id)}
                      onClick={() => toggle(o.id)}
                    />
                  </div>
                  {/* En un teléfono no hay panel al costado: tocar elige, y
                      esto deja leerlo antes de elegir. */}
                  <Button
                    tone="secondary"
                    className="shrink-0 lg:hidden"
                    aria-label={t.crSpellInfo(o.name)}
                    title={t.crSpellInfo(o.name)}
                    onClick={() => setSheetId(o.id)}
                  >
                    <Info size={16} aria-hidden="true" />
                  </Button>
                </div>
              );
            }}
          </SearchableList>
          {cur.granted.length > 0 && (
            <div className="flex flex-wrap items-center justify-between gap-2 border-t border-hairline pt-2.5">
              <span className="text-[12.5px] text-on-surface-variant">
                <span className="font-medium text-on-surface">{t.seNoSlot}</span> {cur.granted.join(', ')}
              </span>
              <Status auto t={t} />
            </div>
          )}
        </section>

        <aside className={WIZARD_ASIDE}>
          {focused && (
            <section className="card flex flex-col gap-3 p-4">
              <div>
                <h2 className="font-display text-[16px] text-on-surface">{focused.name}</h2>
                {focused.subtitle && <Eyebrow className="mt-1">{focused.subtitle}</Eyebrow>}
              </div>
              <DetailBody detail={focused.detail()} />
            </section>
          )}
        </aside>
      </div>

      <WizardFooter message={message}>
        <ButtonLink tone="secondary" href={write.routes.sheet('combate')} internal className="flex-1 sm:flex-none">
          {t.cancel}
        </ButtonLink>
        <Button className="flex-[2] sm:flex-none" disabled={unchanged} onClick={save}>
          {t.seSave}
        </Button>
      </WizardFooter>

      {sheetEntry && (
        <AppDialog
          open
          onOpenChange={(v) => !v && setSheetId(null)}
          title={sheetEntry.name}
          description={sheetEntry.subtitle || undefined}
          actions={[
            { label: t.close },
            {
              label: cur.list.includes(sheetEntry.id) ? t.crRemove : full ? t.seFullShort : t.crChoose,
              primary: true,
              disabled: !cur.list.includes(sheetEntry.id) && full,
              onSelect: () => toggle(sheetEntry.id),
            },
          ]}
        >
          <DetailBody detail={sheetEntry.detail()} />
        </AppDialog>
      )}
    </div>
  );
}
