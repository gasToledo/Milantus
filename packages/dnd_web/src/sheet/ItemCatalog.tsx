import { useMemo, useState } from 'react';
import { Minus, Plus, Search } from 'lucide-react';
import { coinParts, formatAmount, formatCost, tradePreview, type Catalog, type JsonObject } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow, Pill } from '../ui/data';
import { Tooltip } from '../ui/primitives';

/** Las familias del catálogo, en el orden de la mochila (`itemGroupOrder`). */
const FAMILIES = ['weapon', 'armor', 'ammunition', 'focus', 'magic', 'tool', 'container', 'pack', 'gear'] as const;
type Family = (typeof FAMILIES)[number];

/** Una fila del catálogo (`CatalogRow` de Flutter). */
export interface CatalogRow {
  id: string;
  name: string;
  family: Family;
  detail: string;
  weight: number;
  costCp: number;
  bundleSize: number;
}

/** Abreviaturas de las monedas en el idioma de la interfaz, para el motor. */
export function coinLabels(t: Texts): Record<string, string> {
  return Object.fromEntries(Object.entries(t.coins).map(([k, v]) => [k, v.abbr]));
}

const num = (v: unknown) => (typeof v === 'number' ? v : 0);
const str = (v: unknown) => (typeof v === 'string' ? v : '');

/**
 * Lo que puede entrar en la mochila: armas, armaduras y objetos, por nombre.
 * Es agrupar datos del catálogo, no una regla: lo mágico es lo que trae
 * rareza (`Item.isMagic`), igual que en el Códice.
 */
function catalogRows(catalog: Catalog, t: Texts, lang: string): CatalogRow[] {
  const row = (e: JsonObject, family: Family, detail: string[]): CatalogRow => ({
    id: str(e.id),
    name: str(e.name) || str(e.id),
    family,
    detail: detail.join(' · '),
    weight: num(e.weight),
    costCp: num(e.costCp),
    bundleSize: Math.max(1, num(e.bundleSize)),
  });
  const items = catalog.items.map((i) => {
    const family: Family =
      typeof i.rarity === 'string' ? 'magic' : (FAMILIES.find((f) => f === i.category) ?? 'gear');
    return row(i, family, [
      t.itemKinds[family],
      ...(num(i.bundleSize) > 1 ? [t.catalogBundleOf(num(i.bundleSize))] : []),
      ...(i.requiresAttunement === true ? [t.catalogAttunement] : []),
    ]);
  });
  return [
    ...catalog.weapons.map((w) => row(w, 'weapon', [t.itemKinds.weapon])),
    ...catalog.armor.map((a) => row(a, 'armor', [a.category === 'shield' ? t.itemKinds.shield : t.itemKinds.armor])),
    ...items,
  ].sort((a, b) => a.name.localeCompare(b.name, lang));
}

/**
 * «Agregar objeto» (`ItemCatalogDialog` de Flutter): buscador y pills de
 * familia sobre el catálogo. Cada fila tiene «Gratis» (botín: suma sin pagar y
 * el catálogo sigue abierto) y «Comprar», que se apaga y dice cuánto falta si
 * la bolsa no alcanza. La bolsa la cuenta el motor; lo único que se resta acá
 * es el precio contra ella para el aviso, y la compra la vuelve a validar el
 * motor.
 */
export function ItemCatalogDialog({
  catalog,
  coins,
  onAdd,
  onBuy,
  onClose,
}: {
  catalog: Catalog;
  coins: Record<string, number>;
  onAdd: (row: CatalogRow) => void;
  onBuy: (row: CatalogRow) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const labels = coinLabels(t);
  const all = useMemo(() => catalogRows(catalog, t, lang), [catalog, t, lang]);
  const [query, setQuery] = useState('');
  const [family, setFamily] = useState<Family | 'all'>('all');
  const [added, setAdded] = useState(0);
  const purse = tradePreview({ coins, price: {}, quantity: 0, buying: true }, labels);
  const pounds = useMemo(() => new Intl.NumberFormat(lang, { maximumFractionDigits: 2 }), [lang]);

  const needle = query.trim().toLowerCase();
  const matches = all.filter(
    (r) => (needle === '' || r.name.toLowerCase().includes(needle)) && (family === 'all' || r.family === family),
  );
  // Solo las familias que hay: con homebrew, una pill fija ofrecería vacías.
  const present = FAMILIES.filter((f) => all.some((r) => r.family === f));

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.catalogAddTitle}
      width={560}
      actions={[{ label: t.close, primary: true }]}
    >
      <div className="flex flex-col gap-2.5">
        <div className="flex items-center justify-between gap-3">
          <Pill>{t.catalogBag(purse.purse)}</Pill>
        </div>
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
            className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque pr-3 pl-9 text-[13px] text-on-surface placeholder:text-text-muted"
          />
        </div>
        {/* En un teléfono las pills van en un renglón que se desliza: envueltas
            se comían la mitad del diálogo. */}
        <div role="group" aria-label={t.catalogAddTitle} className="flex gap-1.5 overflow-x-auto pb-1 sm:flex-wrap">
          {(['all', ...present] as const).map((f) => (
            <button
              key={f}
              type="button"
              aria-pressed={family === f}
              onClick={() => setFamily(f)}
              className={cx(
                'shrink-0 rounded-[var(--radius-pill)] border px-3 py-[3px] text-[12px]',
                family === f ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface-variant',
              )}
            >
              {f === 'all' ? t.packFilters.all : t.itemGroups[f]}
            </button>
          ))}
        </div>
        {matches.length === 0 ? (
          <p className="py-6 text-center text-[13px] text-text-muted">{t.catalogNoMatches}</p>
        ) : (
          <ul className="h-[min(46vh,420px)] divide-y divide-hairline overflow-y-auto" data-field="catalog">
            {matches.map((r) => {
              const missing = r.costCp - purse.purseCp;
              return (
                <li key={r.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 py-2" data-item={r.id}>
                  <span className="min-w-0 flex-[1_1_200px]">
                    <span className="block truncate text-[14px] text-on-surface">{r.name}</span>
                    <span className="block text-[11.5px] text-on-surface-variant">
                      {[r.detail, missing > 0 ? t.catalogMissing(formatAmount(missing, labels)) : null]
                        .filter(Boolean)
                        .join(' · ')}
                    </span>
                  </span>
                  <span className="w-14 text-right text-[12.5px] text-on-surface-variant tabular-nums">
                    {r.weight === 0 ? '—' : `${pounds.format(r.weight)} ${t.pounds}`}
                  </span>
                  <span className="w-16 text-right text-[12.5px] text-gold tabular-nums">
                    {formatCost(r.costCp, labels)}
                  </span>
                  <span className="ml-auto flex items-center gap-1">
                    <Button
                      tone="secondary"
                      aria-label={t.catalogAddFreeLabel(r.name)}
                      onClick={() => {
                        onAdd(r);
                        setAdded((n) => n + 1);
                      }}
                    >
                      {t.catalogAddFree}
                    </Button>
                    <Button
                      tone="soft"
                      aria-label={t.catalogBuyLabel(r.name)}
                      disabled={missing > 0}
                      onClick={() => onBuy(r)}
                    >
                      {t.catalogBuy}
                    </Button>
                  </span>
                </li>
              );
            })}
          </ul>
        )}
        <p className="text-[12px] text-on-surface-variant">{added === 0 ? t.catalogHint : t.catalogAdded(added)}</p>
      </div>
    </AppDialog>
  );
}

/** Lo que se acordó en «Comprar» o «Vender». */
export interface Trade {
  quantity: number;
  unitCp: number;
  /** El total ya escrito, para el aviso. */
  total: string;
}

const PRICE_COINS = ['gp', 'sp', 'cp'] as const;

/**
 * Comprar o vender (`TradeDialog` de Flutter): cantidad con − y +, precio por
 * unidad en po, pp y pc que se puede corregir (regateo, otra ciudad) y la
 * cuenta del motor: qué sale de la bolsa, el vuelto y cómo queda, o cuánto
 * falta. Tres campos y no número + moneda: la mitad de 15 po son 7 po 5 pp.
 */
export function TradeDialog({
  buying,
  title,
  detail,
  bundleSize,
  catalogCp,
  maxQuantity,
  coins,
  onConfirm,
  onClose,
}: {
  buying: boolean;
  title: string;
  detail: string;
  bundleSize: number;
  /** El precio de partida por unidad: el de catálogo al comprar, la mitad al
   *  vender. «Volver» lo repone. */
  catalogCp: number;
  /** Tope al vender (lo que hay). */
  maxQuantity?: number;
  coins: Record<string, number>;
  onConfirm: (trade: Trade) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const labels = coinLabels(t);
  const partsOf = (cp: number) => {
    const p = coinParts(cp);
    return Object.fromEntries(PRICE_COINS.map((k) => [k, String(p[k] ?? 0)]));
  };
  const [quantity, setQuantity] = useState(1);
  const [price, setPrice] = useState(() => partsOf(catalogCp));
  const preview = tradePreview(
    {
      coins,
      price: Object.fromEntries(PRICE_COINS.map((k) => [k, Math.max(0, Number.parseInt(price[k], 10) || 0)])),
      quantity,
      buying,
    },
    labels,
  );
  const bundle = bundleSize > 1;
  const blocked = preview.short !== null;
  const step = (label: string, Icon: typeof Minus, onClick?: () => void) => (
    <Tooltip content={label}>
      <button
        type="button"
        aria-label={label}
        disabled={!onClick}
        onClick={onClick}
        className="flex h-9 w-9 items-center justify-center rounded-[var(--radius-nav)] border border-hairline text-on-surface-variant hover:text-gold disabled:pointer-events-none disabled:opacity-40"
      >
        <Icon size={16} aria-hidden="true" />
      </button>
    </Tooltip>
  );

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      actions={[
        { label: t.cancel },
        {
          label: buying ? t.catalogBuy : t.tradeSell,
          primary: true,
          disabled: blocked,
          onSelect: () => onConfirm({ quantity, unitCp: preview.unitCp, total: preview.total }),
        },
      ]}
    >
      <p className="text-[12.5px] text-on-surface-variant">{detail}</p>

      <div className="mt-4 flex items-center gap-2">
        <div className="min-w-0 flex-1">
          <Eyebrow className="mb-1">{t.invQuantityTitle}</Eyebrow>
          <p className="text-[12.5px] text-on-surface-variant">
            {[
              t.tradeUnits(quantity, bundle),
              bundle ? t.tradeTotalUnits(quantity * bundleSize) : null,
              maxQuantity !== undefined ? t.tradeLeft(maxQuantity - quantity) : null,
            ]
              .filter(Boolean)
              .join(' · ')}
          </p>
        </div>
        {step(t.tradeOneLess, Minus, quantity > 1 ? () => setQuantity(quantity - 1) : undefined)}
        <span className="num w-11 text-center text-[22px]" data-field="trade-quantity">
          {quantity}
        </span>
        {step(
          t.tradeOneMore,
          Plus,
          maxQuantity === undefined || quantity < maxQuantity ? () => setQuantity(quantity + 1) : undefined,
        )}
      </div>

      <Eyebrow className="mt-4 mb-2">{buying ? t.tradeBuyPrice(bundle) : t.tradeSellPrice(bundle)}</Eyebrow>
      <div className="flex flex-wrap gap-2">
        {PRICE_COINS.map((k) => (
          <label key={k} className="flex items-center gap-1.5 rounded-[var(--radius-nav)] border border-hairline bg-plaque px-2.5">
            <input
              type="number"
              inputMode="numeric"
              min={0}
              aria-label={t.coins[k].name}
              value={price[k]}
              onChange={(e) => setPrice({ ...price, [k]: e.target.value })}
              className="num h-9 w-16 bg-transparent text-right text-[14px] text-on-surface outline-none"
            />
            <span aria-hidden="true" className="text-[12px] text-text-muted">
              {t.coins[k].abbr}
            </span>
          </label>
        ))}
      </div>
      <div className="mt-1.5 flex flex-wrap items-center justify-between gap-2">
        <span className="text-[12.5px] text-on-surface-variant">
          {buying ? t.tradeCatalogPrice(formatCost(catalogCp, labels)) : t.tradeSuggested(formatAmount(catalogCp, labels))}
        </span>
        {preview.unitCp !== catalogCp && (
          <Button tone="secondary" onClick={() => setPrice(partsOf(catalogCp))}>
            {buying ? t.tradeBackCatalog : t.tradeBackSuggested}
          </Button>
        )}
      </div>

      <div className="plaque mt-4 p-4" data-field="trade-total">
        <div className="flex items-baseline justify-between gap-3">
          <Eyebrow>{buying ? t.tradeTotalBuy : t.tradeTotalSell}</Eyebrow>
          <span className="font-display text-[24px] text-gold tabular-nums">{preview.total}</span>
        </div>
        {preview.short !== null ? (
          <p className="mt-2.5 text-[13px] text-crimson">{t.tradeShort(preview.short)}</p>
        ) : (
          <>
            {preview.spent && (
              <p className="mt-2.5 text-[13px]">
                {[t.tradePaidFrom(preview.spent), preview.change ? t.tradeChange(preview.change) : null]
                  .filter(Boolean)
                  .join(' ')}
              </p>
            )}
            <p className="mt-1.5 text-[12.5px] text-on-surface-variant">
              {t.tradeBagAfter(preview.after, preview.afterCoins)}
            </p>
          </>
        )}
      </div>
    </AppDialog>
  );
}
