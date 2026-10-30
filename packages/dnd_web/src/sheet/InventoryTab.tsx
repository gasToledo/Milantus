import { useMemo, useState } from 'react';
import {
  ArrowUpRight,
  Backpack,
  Box,
  Check,
  CircleHelp,
  EllipsisVertical,
  Luggage,
  Package,
  Plus,
  Shield,
  Sparkles,
  Sword,
  WandSparkles,
  Wrench,
  X,
  type LucideIcon,
} from 'lucide-react';
import { formatCost, inventoryOf, type CharacterJson, type InventoryLine } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { cx } from '../ui/cx';
import { Eyebrow, Pips, SpendRecoverButtons, ThinBar } from '../ui/data';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Tooltip } from '../ui/primitives';
import { AppEmptyState } from '../ui/status';
import { coinLabels, ItemCatalogDialog, TradeDialog, type CatalogRow, type Trade } from './ItemCatalog';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

/** Las familias en que se agrupa la mochila, en el orden de `itemGroupOrder`
 *  de Flutter: primero lo que se empuña, después lo que se gasta y al final
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

/** Ícono por familia: es lo único que distingue el tipo dentro de un grupo
 *  (`_itemIcon` en Flutter; §8.7 no permite un color por tipo). */
const GROUP_ICON: Record<Group, LucideIcon> = {
  weapon: Sword,
  armor: Shield,
  ammunition: ArrowUpRight,
  focus: Sparkles,
  magic: WandSparkles,
  tool: Wrench,
  container: Package,
  pack: Luggage,
  gear: Box,
  missing: CircleHelp,
};

/** La familia de una línea, como `itemKindLabel` de Flutter. Es agrupación y
 *  no regla: qué es arma, armadura o mágico ya lo resolvió el motor. */
function groupOf(line: InventoryLine): Group {
  if (line.kind === null) return 'missing';
  if (line.kind === 'weapon' || line.kind === 'armor') return line.kind;
  const family = line.family;
  return GROUP_ORDER.find((g) => g === family) ?? 'gear';
}

/** Monedas de mayor a menor, como se leen en la mesa. */
const COINS = ['pp', 'gp', 'ep', 'sp', 'cp'] as const;

type Filter = 'all' | 'equipped' | 'magic';

/** El diálogo de una línea que está abierto: cantidad exacta o nota. */
type Ask = { kind: 'quantity' | 'note' | 'sell'; line: InventoryLine };

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
 * se escriben las monedas y, por fila, equipar, cantidad, cargas y el menú de
 * Flutter (cantidad exacta, nota, sintonizar, mano secundaria, a dos manos,
 * vender, quitar), más «Agregar objeto» con el catálogo (`ItemCatalog.tsx`);
 * cada cambio lo hace el motor.
 */
export function InventoryTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const lang = useLang();
  const { character, sheet, catalog, write } = model;
  const [ask, setAsk] = useState<Ask | null>(null);
  const [catalogOpen, setCatalogOpen] = useState(false);
  const [buying, setBuying] = useState<CatalogRow | null>(null);
  const coins = character.coins ?? {};

  const buy = (row: CatalogRow, trade: Trade) => {
    const r = write!.act({ type: 'buy', item: row.id, quantity: trade.quantity, unitPriceCp: trade.unitCp, at: today() });
    setBuying(null);
    if (!r) return;
    if (!r.outcome.paid) {
      write!.notify(t.tradeNotPaid, { tone: 'error' });
      return;
    }
    // El catálogo se cierra para que «Deshacer» quede a mano, como en Flutter.
    setCatalogOpen(false);
    write!.notify(t.invBought(trade.quantity, row.name, trade.total), { undo: () => write!.restore(r.before) });
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
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');

  const number = useMemo(() => new Intl.NumberFormat(lang, { maximumFractionDigits: 2 }), [lang]);
  const attuned = lines.filter((l) => l.attuned).length;

  const needle = query.trim().toLowerCase();
  const visible = lines.filter(
    (l) =>
      (needle === '' || l.name.toLowerCase().includes(needle)) &&
      (filter === 'all' || (filter === 'equipped' ? l.equipped : l.magic)),
  );
  const groups = GROUP_ORDER.map((g) => ({ group: g, lines: visible.filter((l) => groupOf(l) === g) })).filter(
    (g) => g.lines.length > 0,
  );

  return (
    <div className="flex flex-col gap-4">
      <Card id="bag" title={t.bagHeading} icon={Backpack}>
        <div className="flex flex-wrap gap-x-7 gap-y-5">
          <div className="min-w-0 flex-[2_1_320px]">
            <Eyebrow className="mb-2">{t.coinsHeading}</Eyebrow>
            <dl className="grid grid-cols-5 gap-2">
              {COINS.map((c) => {
                const n = character.coins?.[c] ?? 0;
                return (
                  <div key={c} className="plaque px-1.5 pt-3 pb-2.5 text-center" data-coin={c}>
                    <dt className="text-[10px] tracking-[1.2px] text-text-muted uppercase">
                      <span aria-hidden="true">{t.coins[c].abbr}</span>
                      <span className="sr-only">{t.coins[c].name}</span>
                    </dt>
                    {/* Las que están en cero se atenúan: lo que hay se ve primero. */}
                    <dd className={cx('font-display mt-[7px] text-[22px] leading-none tabular-nums', n > 0 ? 'text-gold' : 'text-text-muted')}>
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
        <div className="mb-5 flex flex-wrap items-center gap-x-4 gap-y-3">
          <h2 id="h-pack" className="flex min-w-0 flex-[1_1_140px] items-center gap-2">
            <Backpack size={18} aria-hidden="true" className="shrink-0 text-gold" />
            <span className="font-display text-[16px] text-on-surface">{t.packHeading}</span>
            <span className="text-[12px] text-text-muted tabular-nums">{t.itemsCount(lines.length)}</span>
          </h2>
          {write && (
            <Button tone="soft" icon={Plus} onClick={() => setCatalogOpen(true)}>
              {t.catalogAddTitle}
            </Button>
          )}
          {lines.length > 0 && (
            <>
              <div role="search" className="relative min-w-[min(200px,100%)] flex-[1_1_200px] @xl:max-w-[260px]">
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
                      className="absolute inset-y-0 right-1 flex w-8 items-center justify-center text-text-muted hover:text-on-surface"
                    >
                      <X size={16} aria-hidden="true" />
                    </button>
                  </Tooltip>
                )}
              </div>
              <div
                role="group"
                aria-label={t.packFilterLabel}
                className="flex gap-1 rounded-[var(--radius-pill)] border border-hairline bg-plaque p-[3px]"
              >
                {(['all', 'equipped', 'magic'] as const).map((f) => (
                  <button
                    key={f}
                    type="button"
                    aria-pressed={filter === f}
                    onClick={() => setFilter(f)}
                    className={cx(
                      'rounded-[var(--radius-pill)] px-3 py-[5px] text-[12px]',
                      filter === f ? 'bg-gold-soft font-semibold text-gold' : 'text-on-surface-variant hover:text-on-surface',
                    )}
                  >
                    {t.packFilters[f]}
                  </button>
                ))}
              </div>
            </>
          )}
        </div>

        {lines.length === 0 ? (
          <div className="pb-2.5">
            <AppEmptyState kind="empty" message={t.packEmpty} />
          </div>
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
          // Una tabla de verdad: las columnas Cantidad, Equipado y Peso no se
          // mueven entre filas y se leen en vertical (§8.7). Debajo de 576 px
          // de tarjeta el peso se oculta para que el resto no quede apretado.
          <table className="w-full border-collapse text-left" data-field="pack">
            <thead>
              <tr className="border-b border-hairline text-[10px] tracking-[1.2px] text-text-muted uppercase">
                <th scope="col" className="px-2 pb-2.5 font-normal">
                  {t.colItem}
                </th>
                <th scope="col" className="w-12 px-2 pb-2.5 text-right font-normal @xl:w-16">
                  {t.colQuantity}
                </th>
                <th scope="col" className="w-16 px-2 pb-2.5 text-center font-normal @xl:w-24">
                  {t.colEquipped}
                </th>
                <th scope="col" className="hidden w-[72px] px-2 pb-2.5 text-right font-normal @xl:table-cell">
                  {t.colWeight}
                </th>
                {write && <td className="w-10 pb-2.5" />}
              </tr>
            </thead>
            {groups.map(({ group, lines: rows }) => (
              <tbody key={group} data-group={group}>
                <tr>
                  <th scope="colgroup" colSpan={write ? 5 : 4} className="px-2 pt-[22px] pb-2 font-normal">
                    <Eyebrow>{t.itemGroups[group]}</Eyebrow>
                  </th>
                </tr>
                {rows.map((line) => (
                  <PackRow
                    key={line.entryId}
                    line={line}
                    group={group}
                    t={t}
                    format={number.format}
                    write={write}
                    onAsk={(kind) => setAsk({ kind, line })}
                  />
                ))}
              </tbody>
            ))}
          </table>
        )}
      </section>
      {ask && write && ask.kind !== 'sell' && <EntryDialog ask={ask} write={write} onClose={() => setAsk(null)} />}
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
      {catalogOpen && write && (
        <ItemCatalogDialog
          catalog={catalog}
          coins={coins}
          onAdd={(row) => write.act({ type: 'addItem', item: row.id })}
          onBuy={setBuying}
          onClose={() => setCatalogOpen(false)}
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

/** Una moneda escrita a mano. Se guarda al salir del campo o con Enter, como
 *  en Flutter: guardar con cada tecla mandaría «1», «12», «120». */
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
      className="w-full bg-transparent text-center tabular-nums outline-none [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none"
    />
  );
}

/** Cantidad exacta o nota de una línea (`showTextPromptDialog` de Flutter). */
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
  onAsk,
}: {
  line: InventoryLine;
  group: Group;
  t: Texts;
  format: (n: number) => string;
  write: SheetWriter | undefined;
  onAsk: (kind: Ask['kind']) => void;
}) {
  const Icon = GROUP_ICON[group];
  const max = line.maxCharges;
  const charges = max === null ? null : (line.charges ?? max);
  const notes = [
    line.attuned ? t.attunedNote : null,
    max !== null && charges !== null ? t.chargesNote(charges, max) : null,
    line.note || null,
  ].filter(Boolean);
  const entry = line.entryId;
  return (
    <tr className="border-t border-hairline" data-entry={line.entryId}>
      <th scope="row" className="px-2 py-3 text-left font-normal">
        <span className="flex min-w-0 items-center gap-3.5">
          <span
            aria-hidden="true"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--radius-nav)] border border-hairline bg-plaque"
          >
            <Icon size={16} className="text-on-surface-variant" />
          </span>
          <span className="min-w-0">
            <span className="flex flex-wrap items-center gap-1.5 text-[14px] text-on-surface">
              <span className="break-words" data-field="name">
                {line.name}
              </span>
              {line.homebrew && (
                <span className="rounded-[var(--radius-pill)] border border-hairline px-1.5 text-[10px] text-on-surface-variant">
                  {t.homebrewTag}
                </span>
              )}
            </span>
            {notes.length > 0 && <span className="mt-1 block text-[12px] text-text-muted">{notes.join(' · ')}</span>}
            {write && max !== null && charges !== null && (
              // Con máximo 0 (cargas tiradas al aparecer) no hay techo; el
              // tope lo pone el motor y acá solo se apaga lo que no cambiaría.
              <SpendRecoverButtons
                spendLabel={t.invSpendCharge(line.name)}
                recoverLabel={t.invRecoverCharge(line.name)}
                onSpend={charges > 0 ? () => write.act({ type: 'setCharges', entry, value: charges - 1 }) : undefined}
                onRecover={
                  max !== 0 && charges >= max
                    ? undefined
                    : () => write.act({ type: 'setCharges', entry, value: charges + 1 })
                }
              />
            )}
          </span>
        </span>
      </th>
      <td className="num px-2 py-3 text-right text-[14px]" data-field="quantity">
        {write ? (
          // − y + en la fila: sumar una flecha es el caso frecuente. El − se
          // apaga en 1; quitar la línea está en el menú.
          <span className="inline-flex items-center gap-0.5">
            <SpendRecoverButtons
              spendLabel={t.invRemoveOne(line.name)}
              recoverLabel={t.invAddOne(line.name)}
              onSpend={
                line.quantity > 1
                  ? () => write.act({ type: 'setQuantity', entry, value: line.quantity - 1 })
                  : undefined
              }
              onRecover={() => write.act({ type: 'setQuantity', entry, value: line.quantity + 1 })}
            />
            <span className="min-w-6 text-center">{line.quantity}</span>
          </span>
        ) : (
          line.quantity
        )}
      </td>
      <td className="px-2 py-3 text-center text-[12px]" data-field="equipped">
        {write && line.equippable ? (
          <input
            type="checkbox"
            aria-label={t.invEquip(line.name)}
            checked={line.equipped}
            onChange={(e) => write.act({ type: 'equip', entry, value: e.target.checked })}
            className="h-4 w-4 accent-[var(--gold)]"
          />
        ) : line.equipped ? (
          <span className="inline-flex items-center gap-1 text-gold">
            <Check size={14} aria-hidden="true" />
            {t.equippedYes}
          </span>
        ) : (
          <>
            <span aria-hidden="true" className="text-text-muted">
              —
            </span>
            <span className="sr-only">{write && !line.equippable ? t.invNotEquippable : t.equippedNo}</span>
          </>
        )}
      </td>
      <td className="hidden px-2 py-3 text-right text-[13px] text-on-surface-variant tabular-nums @xl:table-cell">
        {format(line.weight)} {t.pounds}
      </td>
      {write && (
        <td className="py-3 text-right">
          <ItemMenu line={line} t={t} write={write} onAsk={onAsk} />
        </td>
      )}
    </tr>
  );
}

/** Las acciones secundarias de una línea, en menú como pide §8.7 (`_itemMenu`
 *  de Flutter). Equipar y la cantidad quedan en la fila porque son las
 *  frecuentes. Quitar no pregunta: avisa con «Deshacer». */
function ItemMenu({
  line,
  t,
  write,
  onAsk,
}: {
  line: InventoryLine;
  t: Texts;
  write: SheetWriter;
  onAsk: (kind: Ask['kind']) => void;
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
            className="inline-flex h-8 w-8 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:bg-plaque hover:text-gold"
          >
            <EllipsisVertical size={18} aria-hidden="true" />
          </button>
        </DropdownMenuTrigger>
      </Tooltip>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onSelect={() => onAsk('quantity')}>{t.invExactQuantity}</DropdownMenuItem>
        <DropdownMenuItem onSelect={() => onAsk('note')}>{t.invNote}</DropdownMenuItem>
        {line.requiresAttunement &&
          toggle(line.attuned ? t.invUnattune : t.invAttune, line.attuned, () =>
            write.act({ type: 'attune', entry, value: !line.attuned }),
          )}
        {line.offHand !== null && toggle(t.invOffHand, line.offHand, () => write.act({ type: 'offHand', entry }))}
        {line.twoHanded !== null &&
          toggle(t.invTwoHanded, line.twoHanded, () => write.act({ type: 'twoHanded', entry }))}
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
