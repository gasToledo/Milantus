import { useMemo, useState } from 'react';
import { ArrowLeft, Info, X } from 'lucide-react';
import { codexEntries } from '../codex/entries';
import {
  catalogLabel,
  catalogLabelOrder,
  magicBaseOptions,
  magicPlansView,
  type CharacterJson,
  type MagicPlansView,
} from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { characterHref, Link } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button, ButtonLink } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { Notice } from '../ui/status';
import { DetailBody, Option, SearchableList, SpellTabs, WIZARD_ASIDE, WizardFooter } from '../ui/wizard';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

/**
 * Los planos del Artífice y sus réplicas (`_manageMagicItemPlans` de Flutter,
 * con el circuito de los asistentes y la ruta propia de `SpellEditor`). Se
 * guarda al tocar, como el resto de la ficha: elegir un plano es la acción
 * `setMagicItemPlan`, crear una réplica es `replicateItem` y quitarla es
 * `removeItem`. Qué planos se ofrecen, los topes y qué réplicas hay lo dice el
 * motor (`magicPlansView`); acá no hay regla.
 *
 * Con el cupo lleno una opción se ve atenuada pero responde: muestra su
 * detalle y el pie dice por qué no se elige. Nada se pliega ni avanza solo.
 */
export function MagicItemPlans({ model, write }: { model: SheetModel; write: SheetWriter }) {
  const t = useTexts();
  const raw = model.character as unknown as CharacterJson;
  const view = useMemo(() => magicPlansView(raw, model.catalog), [raw, model.catalog]);
  if (!view) return <Notice title={t.notFoundTitle} body={t.notFoundBody} />;
  return <Plans model={model} write={write} view={view} />;
}

type TabKey = 'plans' | 'replicas';

function Plans({ model, write, view }: { model: SheetModel; write: SheetWriter; view: MagicPlansView }) {
  const t = useTexts();
  const lang = useLang();
  const { character, catalog } = model;

  const [tab, setTab] = useState<TabKey>('plans');
  // Lo último que se tocó, para el panel de la derecha.
  const [focus, setFocus] = useState<string | null>(null);
  const [sheetId, setSheetId] = useState<string | null>(null);
  // La opción que se tocó con el cupo lleno, y el aviso de réplicas sin cupo.
  const [blocked, setBlocked] = useState<string | null>(null);
  const [replicaHint, setReplicaHint] = useState('');
  // El plano cuya réplica pide base, y la base elegida.
  const [baseFor, setBaseFor] = useState<string | null>(null);

  const details = useMemo(() => codexEntries('magicItems', catalog, t, lang), [catalog, t, lang]);
  const rarityOrder = useMemo(() => catalogLabelOrder('rarity'), []);
  const options = useMemo(
    // Por rareza, de la más común a la más rara; dentro de ella, como los trae
    // el motor (por nombre).
    () => [...view.options].sort((a, b) => rarityOrder.indexOf(a.rarity) - rarityOrder.indexOf(b.rarity)),
    [view.options, rarityOrder],
  );
  const optionById = useMemo(() => new Map(view.options.map((o) => [o.id, o])), [view.options]);
  const nameOfPlan = (id: string) => view.chosen.find((c) => c.id === id)?.name ?? optionById.get(id)?.name ?? id;
  // Un plano elegido que ya no está entre las opciones se lee del catálogo.
  const baseKindOf = (id: string) =>
    optionById.get(id)
      ? optionById.get(id)!.baseItemKind
      : ((catalog.items.find((i) => i.id === id)?.baseItemKind as MagicPlansView['options'][number]['baseItemKind']) ?? null);

  const chosenIds = new Set(view.chosen.map((c) => c.id));
  const full = view.chosen.length >= view.count;
  const free = view.maxActive - view.replicas.length;
  const replicaOf = (id: string) => view.replicas.find((r) => r.itemId === id);

  const noteOf = (o: MagicPlansView['options'][number]) =>
    [
      catalogLabel('rarity', o.rarity),
      o.requiresAttunement ? t.mpNeedsAttunement : null,
      o.baseItemKind ? t.mpNeedsBase : null,
    ]
      .filter(Boolean)
      .join(' · ');

  const removePlan = (id: string) => {
    setFocus(id);
    setBlocked(null);
    setReplicaHint('');
    const name = nameOfPlan(id);
    const r = write.act({ type: 'setMagicItemPlan', item: id, value: false });
    // Un plano sin réplica se saca sin aviso; con ella, «Deshacer».
    if (r?.outcome.removedReplica) write.notify(t.mpRemovedPlan(name), { undo: () => write.restore(r.before) });
  };
  const togglePlan = (id: string) => {
    setFocus(id);
    setReplicaHint('');
    if (chosenIds.has(id)) removePlan(id);
    else if (full) setBlocked(id);
    else {
      setBlocked(null);
      write.act({ type: 'setMagicItemPlan', item: id, value: true });
    }
  };

  const createReplica = (id: string, base?: string) => {
    setFocus(id);
    setReplicaHint('');
    write.act({ type: 'replicateItem', item: id, ...(base ? { base } : {}) });
  };
  const replicaAction = (id: string) => {
    setFocus(id);
    const replica = replicaOf(id);
    if (replica) {
      const r = write.act({ type: 'removeItem', entry: replica.entryId });
      setReplicaHint('');
      if (r) write.notify(t.mpRemovedReplica(nameOfPlan(id)), { undo: () => write.restore(r.before) });
    } else if (free <= 0) {
      setReplicaHint(t.mpNoSlots);
    } else if (baseKindOf(id)) {
      setBaseFor(id);
    } else {
      createReplica(id);
    }
  };

  const tabs = [
    { key: 'plans' as const, title: t.mpTabPlans, n: view.chosen.length, cap: view.count },
    { key: 'replicas' as const, title: t.mpTabReplicas, n: view.replicas.length, cap: view.maxActive },
  ];

  const message =
    tab === 'plans'
      ? blocked && !chosenIds.has(blocked)
        ? t.mpFull(nameOfPlan(blocked))
        : null
      : replicaHint || (view.chosen.length > 0 && free > 0 ? t.mpSlotsLeft(free) : null);

  const focused = focus ? details.find((e) => e.id === focus) : undefined;
  const sheetEntry = sheetId ? details.find((e) => e.id === sheetId) : undefined;
  const back = characterHref(character.id, 'inventario');

  /** En un teléfono no hay panel al costado: esto deja leer el detalle. */
  const info = (id: string, name: string) => (
    <Button
      tone="secondary"
      className="shrink-0 lg:hidden"
      aria-label={t.mpInfo(name)}
      title={t.mpInfo(name)}
      onClick={() => setSheetId(id)}
    >
      <Info size={16} aria-hidden="true" />
    </Button>
  );

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="magic-plans">
      <header className="flex flex-col gap-1">
        <Link
          href={back}
          className="inline-flex min-h-9 items-center gap-1.5 self-start text-[13px] text-gold no-underline hover:text-on-surface"
        >
          <ArrowLeft size={14} aria-hidden="true" />
          {t.mpBack}
        </Link>
        <h1 className="font-display text-[24px] text-on-surface">{t.mpTitle}</h1>
      </header>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="card flex min-w-0 flex-col gap-3 p-4">
          <SpellTabs
            tabs={tabs.map((x) => ({ key: x.key, title: x.title, ready: x.n >= x.cap, count: [x.n, x.cap] }))}
            current={tab}
            onSelect={(k) => {
              setTab(k as TabKey);
              setBlocked(null);
              setReplicaHint('');
            }}
            label={t.mpTabs}
            t={t}
          />

          {tab === 'plans' ? (
            <>
              <ul aria-label={t.mpChosenLabel} className="flex min-h-9 flex-wrap items-center gap-1.5">
                {view.chosen.length === 0 && <li className="text-[12.5px] text-on-surface-variant">{t.crNoneYet}</li>}
                {view.chosen.map((c) => (
                  <li key={c.id}>
                    <button
                      type="button"
                      data-chip={c.id}
                      aria-label={t.mpRemovePlan(c.name)}
                      onClick={() => removePlan(c.id)}
                      className="inline-flex h-9 items-center gap-1.5 rounded-[var(--radius-pill)] border border-gold bg-gold-soft pr-2 pl-3 text-[12.5px] whitespace-nowrap text-on-surface"
                    >
                      {c.name}
                      <X size={14} strokeWidth={2.5} aria-hidden="true" className="text-gold" />
                    </button>
                  </li>
                ))}
              </ul>
              <SearchableList
                items={options}
                textOf={(o) => o.name}
                label={t.mpSearch}
                count={t.mpCount(options.length)}
                columns={2}
                multi
                height="max-h-[396px]"
                groupOf={(o) => catalogLabel('rarity', o.rarity)}
              >
                {(o) => {
                  const on = chosenIds.has(o.id);
                  return (
                    <div key={o.id} className="flex min-w-0 shrink-0 items-stretch gap-1.5">
                      <div className="min-w-0 flex-1">
                        <Option
                          id={o.id}
                          multi
                          selected={on}
                          blocked={!on && full}
                          title={o.name}
                          detail={noteOf(o)}
                          onClick={() => togglePlan(o.id)}
                        />
                      </div>
                      {info(o.id, o.name)}
                    </div>
                  );
                }}
              </SearchableList>
            </>
          ) : (
            <div aria-label={t.mpReplicasLabel} className="flex max-h-[540px] flex-col gap-2 overflow-y-auto pr-1">
              {view.chosen.length === 0 && <p className="text-[13px] text-on-surface-variant">{t.mpPickPlan}</p>}
              {view.chosen.map((c) => {
                const replica = replicaOf(c.id);
                const noSlot = !replica && free <= 0;
                const option = optionById.get(c.id);
                const note = replica
                  ? replica.baseName
                    ? t.mpReplicaOn(replica.baseName)
                    : t.mpReplicaActive
                  : option
                    ? noteOf(option)
                    : '';
                return (
                  <div
                    key={c.id}
                    className={cx(
                      'flex min-h-14 shrink-0 items-center gap-2 rounded-[var(--radius-card)] border px-3.5 py-2',
                      replica ? 'border-gold bg-gold-soft' : 'border-hairline bg-plaque',
                    )}
                  >
                    <button type="button" className="min-w-0 flex-1 text-left" onClick={() => setFocus(c.id)}>
                      <span className="block font-medium text-on-surface">{c.name}</span>
                      {note && <span className="mt-0.5 block text-[12.5px] text-on-surface-variant">{note}</span>}
                    </button>
                    {info(c.id, c.name)}
                    <Button
                      tone="secondary"
                      data-replica={c.id}
                      aria-disabled={noSlot || undefined}
                      className={cx('shrink-0', noSlot && 'opacity-45')}
                      onClick={() => replicaAction(c.id)}
                    >
                      {replica ? t.mpRemoveReplica : t.mpCreateReplica}
                    </Button>
                  </div>
                );
              })}
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
        <ButtonLink href={back} internal className="flex-1 sm:flex-none">
          {t.mpDone}
        </ButtonLink>
      </WizardFooter>

      {sheetEntry && (
        <AppDialog
          open
          onOpenChange={(v) => !v && setSheetId(null)}
          title={sheetEntry.name}
          description={sheetEntry.subtitle || undefined}
          actions={[{ label: t.close }]}
        >
          <DetailBody detail={sheetEntry.detail()} />
        </AppDialog>
      )}

      {baseFor && (
        <BaseDialog
          catalog={catalog}
          itemId={baseFor}
          title={t.mpBaseTitle(nameOfPlan(baseFor))}
          confirm={t.mpCreateReplica}
          onConfirm={(base) => createReplica(baseFor, base)}
          onClose={() => setBaseFor(null)}
        />
      )}
    </div>
  );
}

/** La elección del objeto base de una réplica: radios con lo que el motor
 *  permite para esa plantilla (`magicBaseOptions`). */
function BaseDialog({
  catalog,
  itemId,
  title,
  confirm,
  onConfirm,
  onClose,
}: {
  catalog: SheetModel['catalog'];
  itemId: string;
  title: string;
  confirm: string;
  onConfirm: (base: string) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const bases = useMemo(() => magicBaseOptions(catalog, itemId), [catalog, itemId]);
  const [pick, setPick] = useState<string | null>(null);
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      description={t.mpPickBase}
      actions={[
        { label: t.cancel },
        { label: confirm, primary: true, disabled: pick === null, onSelect: () => pick && onConfirm(pick) },
      ]}
    >
      <div className="flex flex-col gap-3">
        <SearchableList items={bases} textOf={(b) => b.name} label={t.mpBaseLabel} empty={t.catalogNoMatches} height="max-h-[300px]">
          {(b) => <Option key={b.id} id={b.id} selected={b.id === pick} title={b.name} onClick={() => setPick(b.id)} />}
        </SearchableList>
      </div>
    </AppDialog>
  );
}
