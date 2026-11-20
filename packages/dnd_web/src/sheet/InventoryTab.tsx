import { useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Backpack, Check, EllipsisVertical, Plus, X } from 'lucide-react';
import { formatCost, inventoryOf, magicPlansView, type CharacterJson, type InventoryLine } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { AppDialog } from '../ui/AppDialog';
import { Button, ButtonLink } from '../ui/Button';
import { Card } from '../ui/Card';
import { cx } from '../ui/cx';
import { Eyebrow, Pips, SpendRecoverButtons, ThinBar } from '../ui/data';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Tooltip } from '../ui/primitives';
import { AppEmptyState } from '../ui/status';
import { ItemGrants } from './ItemGrants';
import { InfoName } from './InfoName';
import { signed } from './format';
import { EffectTargetDialog } from './EffectTargetDialog';
import { BaseDialog } from './MagicItemPlans';
import { coinLabels, ItemCatalogDialog, TradeDialog, type CatalogRow, type Trade } from './ItemCatalog';
import type { SheetModel } from './model';
import { TransmuteDialog } from './TransmuteDialog';
import type { SheetWriter } from './writer';

/** Las familias en que se agrupa la mochila: primero lo que se empuña,
 *  después lo que se gasta y al final
 *  lo que solo se lleva encima. */
const GROUP_ORDER = [
  'weapon',
  'armor',
  'ammunition',
  'focus',
  'magic',
  'tool',
  'container',
  'pack',
  'gear',
  'missing',
] as const;
type Group = (typeof GROUP_ORDER)[number];

/** La familia de una línea. Es agrupación y
 *  no regla: qué es arma, armadura o mágico ya lo resolvió el motor. */
function groupOf(line: InventoryLine): Group {
  if (line.kind === null) return 'missing';
  if (line.kind === 'weapon' || line.kind === 'armor') return line.kind;
  const family = line.family;
  return GROUP_ORDER.find((g) => g === family) ?? 'gear';
}

/** Monedas de mayor a menor, como se leen en la mesa. */
const COINS = ['pp', 'gp', 'ep', 'sp', 'cp'] as const;

type Filter = 'all' | 'magic';

/** El diálogo de una línea que está abierto: cantidad exacta o nota. */
type Ask = { kind: 'quantity' | 'note' | 'sell' | 'base'; line: InventoryLine };

/** La fecha del asiento en «Cuentas», local y no UTC: a la noche, UTC ya es
 *  mañana. */
function today(): string {
  const d = new Date();
  const two = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}`;
}

/**
 * Pestaña Inventario: la bolsa (monedas, carga y sintonización) y la mochila
 * agrupada por familia. Cada entrada la resolvió el motor (`inventoryOf`):
 * nombre, peso, si cuenta como equipada, si es mágica, si se equipa. La carga
 * y la capacidad son de `ComputedSheet`. En la ficha propia (`model.write`)
 * se escriben las monedas y, por fila, equipar, cantidad, cargas y el menú
 * (cantidad exacta, nota, sintonizar, mano secundaria, a dos manos,
 * vender, quitar), más «Agregar objeto» con el catálogo (`ItemCatalog.tsx`);
 * cada cambio lo hace el motor.
 */
export function InventoryTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const lang = useLang();
  const { character, sheet, catalog, write } = model;
  const [ask, setAsk] = useState<Ask | null>(null);
  const [catalogOpen, setCatalogOpen] = useState(false);
  /** El cupo de arma (pacto) cuyo diálogo está abierto. */
  const [targetGroup, setTargetGroup] = useState<string | null>(null);
  /** La réplica que se está transmutando. */
  const [transmuting, setTransmuting] = useState<InventoryLine | null>(null);
  const [buying, setBuying] = useState<CatalogRow | null>(null);
  // La base de la compra en curso: se elige antes de ponerle precio.
  const [buyingBase, setBuyingBase] = useState<string | undefined>(undefined);
  // La plantilla del catálogo a la que se le está eligiendo base.
  const [askBase, setAskBase] = useState<{ row: CatalogRow; buy: boolean } | null>(null);
  const [added, setAdded] = useState(0);
  const coins = character.coins ?? {};

  const buy = (row: CatalogRow, trade: Trade) => {
    const r = write!.act({
      type: 'buy',
      item: row.id,
      quantity: trade.quantity,
      unitPriceCp: trade.unitCp,
      at: today(),
      ...(buyingBase ? { base: buyingBase } : {}),
    });
    setBuying(null);
    if (!r) return;
    if (!r.outcome.paid) {
      write!.notify(t.tradeNotPaid, { tone: 'error' });
      return;
    }
    // El catálogo se cierra para que «Deshacer» quede a mano.
    setCatalogOpen(false);
    write!.notify(t.invBought(trade.quantity, row.name, trade.total), { undo: () => write!.restore(r.before) });
  };
  const add = (row: CatalogRow, base?: string) => {
    const r = write!.act({ type: 'addItem', item: row.id, ...(base ? { base } : {}) });
    if (r?.outcome.added) setAdded((n) => n + 1);
  };
  const sell = (line: InventoryLine, trade: Trade) => {
    const r = write!.act({
      type: 'sell',
      entry: line.entryId,
      quantity: trade.quantity,
      unitPriceCp: trade.unitCp,
      at: today(),
    });
    setAsk(null);
    if (r) write!.notify(t.invSold(trade.quantity, line.name, trade.total), { undo: () => write!.restore(r.before) });
  };
  // `character` es el `Character.toJson` migrado entero (ver `CharacterPage`);
  // el tipo solo nombra lo que la ficha lee, así que vuelve a su forma JSON.
  const lines = useMemo(() => inventoryOf(character as unknown as CharacterJson, catalog), [character, catalog]);
  // Los planos del Artífice; `null` si la ficha no tiene cupo de planos.
  const plans = useMemo(() => magicPlansView(character as unknown as CharacterJson, catalog), [character, catalog]);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');

  const number = useMemo(() => new Intl.NumberFormat(lang, { maximumFractionDigits: 2 }), [lang]);
  const attuned = lines.filter((l) => l.attuned).length;

  // En uso: lo equipado y lo sintonizado. Lo demás va en la mochila, que es
  // lo único que se busca y se filtra.
  const isInUse = (l: InventoryLine) => l.equipped || l.attuned;
  const inUse = lines.filter(isInUse);
  const rest = lines.filter((l) => !isInUse(l));
  const needle = query.trim().toLowerCase();
  const visible = rest.filter(
    (l) => (needle === '' || l.name.toLowerCase().includes(needle)) && (filter === 'all' || l.magic),
  );
  const groups = GROUP_ORDER.map((g) => ({ group: g, lines: visible.filter((l) => groupOf(l) === g) })).filter(
    (g) => g.lines.length > 0,
  );

  return (
    <div className="flex flex-col gap-4">
      <ItemGrants model={model} />
      <Card id="bag" title={t.bagHeading} icon={Backpack}>
        <div className="flex flex-wrap gap-x-7 gap-y-5">
          <div className="min-w-0 flex-[2_1_320px]">
            <Eyebrow className="mb-2">{t.coinsHeading}</Eyebrow>
            <dl className="grid grid-cols-5 gap-2">
              {COINS.map((c) => {
                const n = character.coins?.[c] ?? 0;
                return (
                  // Escribibles, avisan como lo que se toca: el borde se dora al
                  // pasar y mientras se escribe.
                  <div
                    key={c}
                    className={cx('plaque px-1.5 pt-3 pb-2.5 text-center', write && 'transition-colors duration-[120ms] ease-out focus-within:border-gold hover:border-gold')}
                    data-coin={c}
                  >
                    <dt className="text-[10px] tracking-[1.2px] text-text-muted uppercase">
                      <span aria-hidden="true">{t.coins[c].abbr}</span>
                      <span className="sr-only">{t.coins[c].name}</span>
                    </dt>
                    {/* Las que están en cero se atenúan: lo que hay se ve primero. */}
                    {/* `key`: un valor nuevo entra con su fundido. */}
                    <dd key={n} className={cx('font-display step-in mt-[7px] text-[22px] leading-none tabular-nums', n > 0 ? 'text-gold' : 'text-text-muted')}>
                      {write ? (
                        <CoinInput
                          // La clave reinicia el campo cuando el motor guarda
                          // otra cantidad (un descanso, otra pestaña).
                          key={n}
                          value={n}
                          label={t.invCoinField(t.coins[c].name)}
                          onCommit={(v) => write.act({ type: 'setCoins', coins: { ...character.coins, [c]: v } })}
                        />
                      ) : (
                        n
                      )}
                    </dd>
                  </div>
                );
              })}
            </dl>
          </div>

          <div className="flex min-w-0 flex-[1_1_220px] flex-col gap-3.5">
            <div data-stat="load">
              <div className="flex items-baseline justify-between gap-2.5">
                <Eyebrow>{t.loadHeading}</Eyebrow>
                <span className="num text-[14px]" data-field="value">
                  {number.format(sheet.carriedWeight)}
                  <span className="font-normal text-text-muted">
                    {' / '}
                    {number.format(sheet.carryingCapacity)} {t.pounds}
                  </span>
                </span>
              </div>
              <div className="mt-2">
                <ThinBar
                  value={sheet.carriedWeight}
                  max={sheet.carryingCapacity}
                  label={t.loadHeading}
                  valueText={t.loadLabel(number.format(sheet.carriedWeight), number.format(sheet.carryingCapacity))}
                  colorClassName={sheet.isEncumbered ? 'bg-crimson' : 'bg-gold'}
                  height={6}
                />
              </div>
            </div>
            {sheet.attunementSlots > 0 && (
              <div className="flex items-center justify-between gap-2.5">
                <Eyebrow>{t.attunementHeading}</Eyebrow>
                <Pips
                  max={sheet.attunementSlots}
                  left={Math.min(attuned, sheet.attunementSlots)}
                  label={t.attunementLabel(attuned, sheet.attunementSlots)}
                />
              </div>
            )}
          </div>
        </div>
      </Card>

      <section aria-labelledby="h-pack" className="card @container min-w-0 px-5 pt-[18px] pb-2.5" data-card="pack">
        <div className="mb-4 flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
            <h2 id="h-pack" className="flex min-w-0 flex-[1_1_140px] items-center gap-2">
              <Backpack size={18} aria-hidden="true" className="shrink-0 text-gold" />
              <span className="font-display text-[16px] text-on-surface">{t.packHeading}</span>
              <span className="text-[12px] text-text-muted tabular-nums">{t.itemsCount(lines.length)}</span>
            </h2>
            {write && (
              <Button
                tone="soft"
                icon={Plus}
                onClick={() => {
                  setAdded(0);
                  setCatalogOpen(true);
                }}
              >
                {t.catalogAddTitle}
              </Button>
            )}
            {write && plans && (
              <ButtonLink tone="soft" internal href={write.routes.plans()} data-action="magic-plans">
                {t.invPlansButton(plans.chosen.length, plans.count)}
              </ButtonLink>
            )}
            {write &&
              sheet.targetChoiceSlots.map((slot) => (
                <Button key={slot.groupId} tone="soft" data-action={`target-${slot.groupId}`} onClick={() => setTargetGroup(slot.groupId)}>
                  {t.invTargetButton(slot.name, slot.chosenEntryIds.length, slot.count)}
                </Button>
              ))}
          </div>
        </div>

        {lines.length === 0 ? (
          <div className="pb-2.5">
            <AppEmptyState kind="empty" message={t.packEmpty} />
          </div>
        ) : (
          <>
            {/* Lo que el personaje lleva puesto o sintonizado, aparte y arriba:
                es lo que se mira en el turno (con qué pega, cuánta CA). Los
                números son del motor (`sheet.attacks`, `sheet.armorClass`). */}
            {inUse.length > 0 && (
              <section aria-labelledby="h-in-use" className="pb-2">
                <h3 id="h-in-use" className="mb-2.5 flex items-center gap-3">
                  <span className="eyebrow shrink-0">{t.invInUse}</span>
                  <span aria-hidden="true" className="h-px flex-1 bg-hairline" />
                </h3>
                <ul className="grid gap-2.5 [grid-template-columns:repeat(auto-fit,minmax(min(180px,100%),1fr))]">
                  {inUse.map((line) => (
                    <InUseCard
                      key={line.entryId}
                      line={line}
                      model={model}
                      write={write}
                      canTransmute={plans !== null && plans.chosen.some((c) => c.id !== line.itemId)}
                      onTransmute={() => setTransmuting(line)}
                      onAsk={(kind) => setAsk({ kind, line })}
                    />
                  ))}
                </ul>
              </section>
            )}

            <section aria-labelledby="h-in-pack" className="pt-3">
              {/* Buscar y filtrar miran solo la mochila: lo que está en uso
                  siempre está a la vista. */}
              <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
                <h3 id="h-in-pack" className="flex min-w-[160px] flex-[1_1_160px] items-center gap-3">
                  <span className="eyebrow shrink-0">{t.invInPack}</span>
                  <span aria-hidden="true" className="h-px flex-1 bg-hairline" />
                </h3>
                {rest.length > 0 && (
                  <>
                    <div role="search" className="relative min-w-[min(180px,100%)] flex-[0_1_240px]">
                      <label htmlFor="pack-search" className="sr-only">
                        {t.packSearchLabel}
                      </label>
                      <input
                        id="pack-search"
                        type="search"
                        autoComplete="off"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                        placeholder={t.packSearchHint}
                        className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque px-4 pr-9 text-[13px] text-on-surface placeholder:text-text-muted"
                      />
                      {query !== '' && (
                        <Tooltip content={t.rosterClearSearch}>
                          <button
                            type="button"
                            aria-label={t.rosterClearSearch}
                            onClick={() => setQuery('')}
                            className="absolute inset-y-0 right-1 flex w-8 items-center justify-center text-text-muted transition-colors duration-[120ms] ease-out hover:text-on-surface"
                          >
                            <X size={16} aria-hidden="true" />
                          </button>
                        </Tooltip>
                      )}
                    </div>
                    <PackFilter filter={filter} onChange={setFilter} />
                  </>
                )}
              </div>

              {rest.length === 0 ? (
                <p className="py-4 text-[13px] text-text-muted">{t.packAllInUse}</p>
              ) : visible.length === 0 ? (
                <div className="pb-2.5">
                  <AppEmptyState
                    kind="no-match"
                    message={needle ? t.packNoMatch(query.trim()) : t.packNoMatchHint}
                    hint={needle ? t.packNoMatchHint : undefined}
                    actions={
                      <Button
                        tone="secondary"
                        onClick={() => {
                          setQuery('');
                          setFilter('all');
                        }}
                      >
                        {t.packShowAll}
                      </Button>
                    }
                  />
                </div>
              ) : (
                // Una lista por familia, sin encabezado de columnas: cada fila
                // dice su cantidad (×20) y su peso, y lo demás va en el ⋮.
                <div data-field="pack">
                  {groups.map(({ group, lines: rows }) => (
                    <div key={group} data-group={group}>
                      <p className="flex items-baseline gap-2 px-2 pt-4 pb-1.5 text-[12.5px] text-on-surface-variant">
                        {t.itemGroups[group]}
                        <span className="text-[12px] text-text-muted tabular-nums">{rows.length}</span>
                      </p>
                      <ul>
                        {rows.map((line) => (
                          <PackRow
                            key={line.entryId}
                            line={line}
                            group={group}
                            t={t}
                            format={number.format}
                            write={write}
                            slotLabels={sheet.targetChoiceSlots.filter((s) => s.chosenEntryIds.includes(line.entryId)).map((s) => s.name)}
                            canTransmute={plans !== null && plans.chosen.some((c) => c.id !== line.itemId)}
                            onTransmute={() => setTransmuting(line)}
                            onAsk={(kind) => setAsk({ kind, line })}
                          />
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </>
        )}
      </section>
      {ask && write && (ask.kind === 'quantity' || ask.kind === 'note') && <EntryDialog ask={ask} write={write} onClose={() => setAsk(null)} />}
      {ask && write && ask.kind === 'sell' && (
        <TradeDialog
          buying={false}
          title={t.invSellTitle(ask.line.name)}
          detail={t.invSellDetail(ask.line.quantity, formatCost(ask.line.costCp, coinLabels(t)))}
          bundleSize={ask.line.bundleSize}
          catalogCp={ask.line.salePriceCp}
          maxQuantity={ask.line.quantity}
          coins={coins}
          onConfirm={(trade) => sell(ask.line, trade)}
          onClose={() => setAsk(null)}
        />
      )}
      {ask && write && ask.kind === 'base' && (
        <BaseDialog
          catalog={catalog}
          itemId={ask.line.itemId}
          title={ask.line.name}
          confirm={t.crChoose}
          onConfirm={(base) => {
            write.act({ type: 'setItemBase', entry: ask.line.entryId, base });
            setAsk(null);
          }}
          onClose={() => setAsk(null)}
        />
      )}
      {transmuting && write && plans && (
        <TransmuteDialog model={model} write={write} line={transmuting} plans={plans} onClose={() => setTransmuting(null)} />
      )}
      {targetGroup && write && (
        <EffectTargetDialog
          model={model}
          write={write}
          slot={sheet.targetChoiceSlots.find((s) => s.groupId === targetGroup)!}
          onClose={() => setTargetGroup(null)}
        />
      )}
      {catalogOpen && write && (
        <ItemCatalogDialog
          catalog={catalog}
          coins={coins}
          added={added}
          onAdd={(row) => (row.needsBase ? setAskBase({ row, buy: false }) : add(row))}
          onBuy={(row) => {
            setBuyingBase(undefined);
            if (row.needsBase) setAskBase({ row, buy: true });
            else setBuying(row);
          }}
          onClose={() => setCatalogOpen(false)}
        />
      )}
      {askBase && write && (
        <BaseDialog
          catalog={catalog}
          itemId={askBase.row.id}
          title={askBase.row.name}
          confirm={t.crChoose}
          onConfirm={(base) => {
            if (askBase.buy) {
              setBuyingBase(base);
              setBuying(askBase.row);
            } else {
              add(askBase.row, base);
            }
            setAskBase(null);
          }}
          onClose={() => setAskBase(null)}
        />
      )}
      {buying && write && (
        <TradeDialog
          buying
          title={t.invBuyTitle(buying.name)}
          detail={buying.detail}
          bundleSize={buying.bundleSize}
          catalogCp={buying.costCp}
          coins={coins}
          onConfirm={(trade) => buy(buying, trade)}
          onClose={() => setBuying(null)}
        />
      )}
    </div>
  );
}

/** Todo / Mágico, como el selector Jugador/DM: el fondo dorado es
 *  una pieza aparte que se desliza al botón elegido. Los botones miden
 *  distinto, así que se mide el elegido y el fondo recorre `left` y `width`
 *  con una transición (el selector no se desmonta). Sin transición la primera
 *  vez, para que no entre deslizándose desde la izquierda. */
function PackFilter({ filter, onChange }: { filter: Filter; onChange: (f: Filter) => void }) {
  const t = useTexts();
  const group = useRef<HTMLDivElement>(null);
  const [pill, setPill] = useState<{ left: number; width: number; animate: boolean } | null>(null);
  useLayoutEffect(() => {
    const on = group.current?.querySelector<HTMLElement>('[aria-pressed="true"]');
    if (!on) return;
    setPill((prev) => ({ left: on.offsetLeft, width: on.offsetWidth, animate: prev !== null }));
  }, [filter, t]);
  return (
    <div
      ref={group}
      role="group"
      aria-label={t.packFilterLabel}
      className="relative flex gap-1 rounded-[var(--radius-pill)] border border-hairline bg-plaque p-[3px]"
    >
      {pill && (
        <span
          aria-hidden="true"
          className={cx(
            'absolute inset-y-[3px] rounded-[var(--radius-pill)] bg-gold-soft',
            pill.animate && 'transition-[left,width] duration-[220ms] ease-out',
          )}
          style={{ left: pill.left, width: pill.width }}
        />
      )}
      {(['all', 'magic'] as const).map((f) => (
        <button
          key={f}
          type="button"
          aria-pressed={filter === f}
          onClick={() => onChange(f)}
          className={cx(
            'relative rounded-[var(--radius-pill)] px-3 py-[5px] text-[12px] transition-colors duration-[120ms] ease-out',
            filter === f ? 'font-semibold text-gold' : 'text-on-surface-variant hover:text-on-surface',
          )}
        >
          {t.packFilters[f]}
        </button>
      ))}
    </div>
  );
}

/** Una moneda escrita a mano. Se guarda al salir del campo o con Enter:
 *  guardar con cada tecla mandaría «1», «12», «120». */
function CoinInput({ value, label, onCommit }: { value: number; label: string; onCommit: (v: number) => void }) {
  const [text, setText] = useState(String(value));
  const commit = () => {
    const v = Number.parseInt(text, 10) || 0;
    if (v !== value) onCommit(v);
    else setText(String(value));
  };
  return (
    <input
      type="number"
      inputMode="numeric"
      min={0}
      aria-label={label}
      value={text}
      onChange={(e) => setText(e.target.value)}
      onBlur={commit}
      onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
      className="w-full bg-transparent text-center tabular-nums [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none"
      // El foco lo dice el borde dorado de la placa (`focus-within`): el contorno
      // global de `:focus-visible` dibujaba un segundo recuadro adentro. Va en
      // línea porque esa regla está fuera de las capas y le gana a `outline-none`.
      style={{ outline: 'none' }}
    />
  );
}

/** Cantidad exacta o nota de una línea. */
function EntryDialog({ ask, write, onClose }: { ask: Ask; write: SheetWriter; onClose: () => void }) {
  const t = useTexts();
  const { kind, line } = ask;
  const [value, setValue] = useState(kind === 'quantity' ? String(line.quantity) : line.note);
  const confirm = () => {
    if (kind === 'note') {
      write.act({ type: 'note', entry: line.entryId, text: value.trim() });
    } else {
      const n = Number.parseInt(value, 10);
      if (n >= 1) write.act({ type: 'setQuantity', entry: line.entryId, value: n });
    }
    onClose();
  };
  const label = kind === 'note' ? t.invNoteLabel : line.bundleSize > 1 ? t.invBundlesOf(line.bundleSize) : t.invUnits;
  const field = 'mt-2 w-full rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 text-[14px] text-on-surface';
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={kind === 'note' ? t.invNoteTitle : t.invQuantityTitle}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, onSelect: confirm }]}
    >
      <form
        onSubmit={(e) => {
          e.preventDefault();
          confirm();
        }}
      >
        <label htmlFor="entry-value" className="text-[13px] text-on-surface-variant">
          {label}
        </label>
        {kind === 'note' ? (
          <textarea
            id="entry-value"
            rows={4}
            autoFocus
            value={value}
            onChange={(e) => setValue(e.target.value)}
            className={cx(field, 'py-2')}
          />
        ) : (
          <input
            id="entry-value"
            type="number"
            inputMode="numeric"
            min={1}
            autoFocus
            value={value}
            onChange={(e) => setValue(e.target.value)}
            className={cx(field, 'num h-9')}
          />
        )}
      </form>
    </AppDialog>
  );
}

function PackRow({
  line,
  group,
  t,
  format,
  write,
  slotLabels,
  canTransmute,
  onTransmute,
  onAsk,
}: {
  line: InventoryLine;
  group: Group;
  t: Texts;
  format: (n: number) => string;
  write: SheetWriter | undefined;
  /** Los cupos (arma de pacto) a los que esta línea está vinculada. */
  slotLabels: string[];
  /** Si la línea es una réplica y hay otro plano elegido al que pasarla. */
  canTransmute: boolean;
  onTransmute: () => void;
  onAsk: (kind: Ask['kind']) => void;
}) {
  const entry = line.entryId;
  const notes = [...slotLabels, line.needsBase ? t.invNoBase : null, line.note || null].filter(Boolean);
  return (
    // Se resalta al pasar: ayuda a seguir con la vista la fila entera.
    <li
      className="group/row flex items-center gap-3 rounded-[var(--radius-nav)] border-t border-hairline px-2 py-2.5 transition-colors duration-[120ms] ease-out hover:bg-plaque/60"
      data-entry={entry}
      data-group={group}
    >
      <span className="min-w-0 flex-1">
        <span className="flex flex-wrap items-center gap-1.5 text-[14px] text-on-surface">
          <InfoName title={line.name} description={line.description}>
            <span className="break-words" data-field="name">
              {line.name}
            </span>
          </InfoName>
          {line.replica && <MiniTag>{t.invReplica}</MiniTag>}
          {line.homebrew && <MiniTag>{t.homebrewTag}</MiniTag>}
        </span>
        {notes.length > 0 && <span className="mt-0.5 block text-[12px] text-text-muted">{notes.join(' · ')}</span>}
        <Charges line={line} t={t} write={write} />
      </span>
      {write && line.equippable && <EquipToggle line={line} t={t} write={write} />}
      <span className="num shrink-0 text-[14px]" data-field="quantity">
        {/* La cantidad es «×20»; − y + aparecen al pasar o al llegar con el
            teclado (siguen en el orden de tabulación). Sin mouse se ven
            siempre: un control invisible no se toca. El − se apaga en 1;
            quitar la línea está en el menú. */}
        <span className="inline-flex items-center gap-1">
          {write && (
            <span className="transition-opacity duration-[120ms] ease-out [@media(hover:hover)]:opacity-0 [@media(hover:hover)]:group-focus-within/row:opacity-100 [@media(hover:hover)]:group-hover/row:opacity-100">
              <SpendRecoverButtons
                spendLabel={t.invRemoveOne(line.name)}
                recoverLabel={t.invAddOne(line.name)}
                onSpend={
                  line.quantity > 1 ? () => write.act({ type: 'setQuantity', entry, value: line.quantity - 1 }) : undefined
                }
                onRecover={() => write.act({ type: 'setQuantity', entry, value: line.quantity + 1 })}
              />
            </span>
          )}
          <span className="min-w-9 text-right">×{line.quantity}</span>
        </span>
      </span>
      <span className="hidden w-14 shrink-0 text-right text-[13px] text-on-surface-variant tabular-nums @xl:block">
        {format(line.weight)} {t.pounds}
      </span>
      {write && (
        <ItemMenu line={line} t={t} write={write} onAsk={onAsk} canTransmute={canTransmute && line.replica} onTransmute={onTransmute} />
      )}
    </li>
  );
}

/** Una marca chica junto al nombre (réplica, homebrew). */
function MiniTag({ children }: { children: ReactNode }) {
  return (
    <span className="rounded-[var(--radius-pill)] border border-hairline px-1.5 text-[10px] text-on-surface-variant">{children}</span>
  );
}

/** Equipar o quitarse un objeto: una pill que se dora cuando está puesto. Es
 *  un botón con `aria-pressed` y el mismo nombre en los dos estados. */
function EquipToggle({ line, t, write }: { line: InventoryLine; t: Texts; write: SheetWriter }) {
  return (
    <button
      type="button"
      aria-pressed={line.equipped}
      aria-label={t.invEquip(line.name)}
      onClick={() => write.act({ type: 'equip', entry: line.entryId, value: !line.equipped })}
      className={cx(
        'pick inline-flex h-7 shrink-0 items-center self-center rounded-[var(--radius-pill)] border px-2.5 text-[12px]',
        line.equipped ? 'border-gold bg-gold-soft font-semibold text-gold' : 'border-hairline text-on-surface-variant',
      )}
    >
      {line.equipped ? t.colEquipped : t.invEquipShort}
    </button>
  );
}

/** Las cargas de un objeto: los puntos y, en la ficha propia, gastar y
 *  recuperar. Con máximo 0 (cargas tiradas al aparecer) no hay techo. */
function Charges({ line, t, write }: { line: InventoryLine; t: Texts; write: SheetWriter | undefined }) {
  const max = line.maxCharges;
  if (max === null) return null;
  const charges = line.charges ?? max;
  return (
    <span className="mt-1 flex items-center gap-2">
      {max > 0 ? (
        <span className="[&>[role=img]]:justify-start">
          <Pips max={max} left={charges} label={t.chargesNote(charges, max)} />
        </span>
      ) : (
        <span className="text-[12px] text-text-muted">{t.chargesNote(charges, max)}</span>
      )}
      {write && (
        <SpendRecoverButtons
          spendLabel={t.invSpendCharge(line.name)}
          recoverLabel={t.invRecoverCharge(line.name)}
          onSpend={charges > 0 ? () => write.act({ type: 'setCharges', entry: line.entryId, value: charges - 1 }) : undefined}
          onRecover={max !== 0 && charges >= max ? undefined : () => write.act({ type: 'setCharges', entry: line.entryId, value: charges + 1 })}
        />
      )}
    </span>
  );
}

/** Lo que el personaje lleva puesto o sintonizado, en una placa: qué es, el
 *  nombre y la cifra que se mira en el turno. Quitárselo está en su ⋮. Ninguna cifra se calcula acá:
 *  el ataque y el daño son de `sheet.attacks`, la CA de `sheet.armorClass`. Un
 *  escudo no lleva cifra propia: su aporte ya está en la CA de la armadura. */
function InUseCard({
  line,
  model,
  write,
  canTransmute,
  onTransmute,
  onAsk,
}: {
  line: InventoryLine;
  model: SheetModel;
  write: SheetWriter | undefined;
  canTransmute: boolean;
  onTransmute: () => void;
  onAsk: (kind: Ask['kind']) => void;
}) {
  const t = useTexts();
  const { sheet, catalog } = model;
  const attack =
    line.kind === 'weapon'
      ? (sheet.attacks.find((a) => a.sourceEntryId === line.entryId && !a.offHand) ??
        sheet.attacks.find((a) => a.weaponId === line.itemId && !a.offHand))
      : undefined;
  const shield = line.kind === 'armor' && catalog.armor.find((a) => a.id === line.itemId)?.category === 'shield';
  // Qué lugar ocupa, en singular: «Arma», «Armadura», «Escudo».
  const label = line.attuned
    ? t.attunedNote
    : shield
      ? t.invSlot.shield
      : line.kind === 'weapon' || line.kind === 'armor'
        ? t.invSlot[line.kind]
        : line.magic
          ? t.invSlot.magic
          : t.invSlot.item;
  return (
    <li className="plaque flex min-w-0 flex-col gap-1.5 px-3.5 py-3" data-entry={line.entryId}>
      <span className="flex items-start gap-2">
        <span className="plaque-label min-w-0 flex-1 pt-1">
          {label}
          {line.quantity > 1 && <span className="tabular-nums"> ×{line.quantity}</span>}
        </span>
        {write && (
          <span className="-mt-1 -mr-1.5">
            <ItemMenu line={line} t={t} write={write} onAsk={onAsk} canTransmute={canTransmute && line.replica} onTransmute={onTransmute} />
          </span>
        )}
      </span>
      <InfoName title={line.name} description={line.description}>
        <span className="font-display text-[16px] leading-[1.25] break-words text-on-surface" data-field="name">
          {line.name}
        </span>
      </InfoName>
      {attack && (
        <span className="flex flex-wrap items-baseline gap-x-1.5">
          <span className="num text-[20px] leading-none text-gold">
            <span aria-hidden="true">{signed(attack.attackBonus)}</span>
            <span className="sr-only">{t.attackBonusLabel(signed(attack.attackBonus))}</span>
          </span>
          {attack.damageText && <span className="text-[12px] text-on-surface-variant">{attack.damageText}</span>}
        </span>
      )}
      {line.kind === 'armor' && !shield && (
        <span className="flex items-baseline gap-1.5">
          <span className="num text-[20px] leading-none text-gold">{sheet.armorClass}</span>
          <span className="text-[12px] text-on-surface-variant">{t.acShort}</span>
        </span>
      )}
      <Charges line={line} t={t} write={write} />
      {line.note && <span className="text-[12px] text-text-muted">{line.note}</span>}
    </li>
  );
}

/** Las acciones secundarias de una línea, en menú como pide §8.7. Equipar y
 *  la cantidad quedan en la fila porque son las
 *  frecuentes. Quitar no pregunta: avisa con «Deshacer». */
function ItemMenu({
  line,
  t,
  write,
  onAsk,
  canTransmute,
  onTransmute,
}: {
  line: InventoryLine;
  t: Texts;
  write: SheetWriter;
  onAsk: (kind: Ask['kind']) => void;
  canTransmute: boolean;
  onTransmute: () => void;
}) {
  const entry = line.entryId;
  const toggle = (label: string, on: boolean, act: () => void) => (
    <DropdownMenuItem onSelect={act}>
      <span className="flex-1">{label}</span>
      {on && <Check size={16} aria-hidden="true" className="text-gold" />}
    </DropdownMenuItem>
  );
  return (
    <DropdownMenu>
      <Tooltip content={t.invActions(line.name)}>
        <DropdownMenuTrigger asChild>
          <button
            type="button"
            aria-label={t.invActions(line.name)}
            className="inline-flex h-8 w-8 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant transition-colors duration-[120ms] ease-out hover:bg-plaque hover:text-gold"
          >
            <EllipsisVertical size={18} aria-hidden="true" />
          </button>
        </DropdownMenuTrigger>
      </Tooltip>
      <DropdownMenuContent align="end">
        {line.equipped && line.equippable && (
          <DropdownMenuItem onSelect={() => write.act({ type: 'equip', entry: line.entryId, value: false })}>
            {t.invUnequip}
          </DropdownMenuItem>
        )}
        <DropdownMenuItem onSelect={() => onAsk('quantity')}>{t.invExactQuantity}</DropdownMenuItem>
        <DropdownMenuItem onSelect={() => onAsk('note')}>{t.invNote}</DropdownMenuItem>
        {line.requiresAttunement &&
          toggle(line.attuned ? t.invUnattune : t.invAttune, line.attuned, () =>
            write.act({ type: 'attune', entry, value: !line.attuned }),
          )}
        {line.offHand !== null && toggle(t.invOffHand, line.offHand, () => write.act({ type: 'offHand', entry }))}
        {line.twoHanded !== null &&
          toggle(t.invTwoHanded, line.twoHanded, () => write.act({ type: 'twoHanded', entry }))}
        {line.needsBase && <DropdownMenuItem onSelect={() => onAsk('base')}>{t.invChooseBase}</DropdownMenuItem>}
        {canTransmute && <DropdownMenuItem onSelect={onTransmute}>{t.invTransmute}</DropdownMenuItem>}
        <DropdownMenuItem onSelect={() => onAsk('sell')}>{t.invSellMenu}</DropdownMenuItem>
        <DropdownMenuItem
          onSelect={() => {
            const r = write.act({ type: 'removeItem', entry });
            if (r) write.notify(t.invRemoved(line.name), { undo: () => write.restore(r.before) });
          }}
        >
          {t.invRemove}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
