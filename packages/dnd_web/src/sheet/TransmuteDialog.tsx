import { useMemo, useState } from 'react';
import { magicBaseOptions, type InventoryLine, type MagicPlansView } from '../engine';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Eyebrow } from '../ui/data';
import { Option, SearchableList } from '../ui/wizard';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

/**
 * Transmutar una réplica en otro de los planos elegidos (`_transmuteReplica`
 * de Flutter, en un solo diálogo): radios con los planos menos el propio y, si
 * el elegido pide objeto base, debajo la lista de bases. Elegir no guarda;
 * «Transmutar» manda la acción `transmuteReplica`, que el motor vuelve a
 * comprobar.
 */
export function TransmuteDialog({
  model,
  write,
  line,
  plans,
  onClose,
}: {
  model: SheetModel;
  write: SheetWriter;
  line: InventoryLine;
  plans: MagicPlansView;
  onClose: () => void;
}) {
  const t = useTexts();
  const { catalog } = model;
  const options = plans.chosen.filter((c) => c.id !== line.itemId);
  const [plan, setPlan] = useState<string | null>(null);
  const [base, setBase] = useState<string | null>(null);

  // Un plano elegido que ya no está entre las opciones se lee del catálogo.
  const kind = (id: string) =>
    plans.options.find((o) => o.id === id)?.baseItemKind ?? ((catalog.items.find((i) => i.id === id)?.baseItemKind as string | undefined) ?? null);
  const needsBase = plan !== null && kind(plan) !== null;
  const bases = useMemo(() => (plan && needsBase ? magicBaseOptions(catalog, plan) : []), [catalog, plan, needsBase]);

  const confirm = () => {
    if (!plan) return;
    const r = write.act({ type: 'transmuteReplica', entry: line.entryId, item: plan, ...(needsBase && base ? { base } : {}) });
    onClose();
    if (r) write.notify(t.tmDone(line.name, options.find((o) => o.id === plan)?.name ?? plan), { undo: () => write.restore(r.before) });
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.tmTitle(line.name)}
      actions={[
        { label: t.cancel },
        {
          label: t.tmConfirm,
          primary: true,
          closes: false,
          disabled: plan === null || (needsBase && base === null),
          onSelect: confirm,
        },
      ]}
    >
      <div className="flex flex-col gap-3">
        <Eyebrow>{t.tmInto}</Eyebrow>
        <div role="radiogroup" aria-label={t.tmInto} className="grid auto-rows-max gap-2">
          {options.map((o) => (
            <Option
              key={o.id}
              id={o.id}
              selected={o.id === plan}
              title={o.name}
              onClick={() => {
                setPlan(o.id);
                setBase(null);
              }}
            />
          ))}
        </div>
        {needsBase && (
          <>
            <Eyebrow>{t.mpPickBase}</Eyebrow>
            <SearchableList items={bases} textOf={(b) => b.name} label={t.mpBaseLabel} empty={t.catalogNoMatches} height="max-h-[220px]">
              {(b) => <Option key={b.id} id={b.id} selected={b.id === base} title={b.name} onClick={() => setBase(b.id)} />}
            </SearchableList>
          </>
        )}
      </div>
    </AppDialog>
  );
}
