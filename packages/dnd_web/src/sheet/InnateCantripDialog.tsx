import { useMemo, useState } from 'react';
import { nameOf } from '../api/catalog';
import { innateCantripOptions, vocabularyLabel, type CharacterJson, type InnateSpell } from '../engine';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Option, SearchableList } from '../ui/wizard';
import type { SheetModel } from './model';
import { HigherLevelNote } from './HigherLevelNote';
import { spellMeta, type SpellJson } from './SpellList';
import type { SheetWriter } from './writer';

/**
 * El cambio del truco innato (el del rasgo de la especie, tras un descanso
 * largo): `_openInnateCantripPicker` de Flutter, pero elegir una opción no
 * guarda nada; se confirma con «Cambiar». Qué trucos entran y en qué orden lo
 * dice el motor (`innateCantripOptions`); lo guardado es la acción
 * `setInnateCantrip`, que además lo vuelve a comprobar.
 */
export function InnateCantripDialog({
  model,
  write,
  innate,
  onClose,
}: {
  model: SheetModel;
  write: SheetWriter;
  innate: InnateSpell;
  onClose: () => void;
}) {
  const t = useTexts();
  const { character, catalog } = model;
  const raw = character as unknown as CharacterJson;
  const options = useMemo(
    () => innateCantripOptions(raw, catalog, innate.grantedSpellId),
    [raw, catalog, innate.grantedSpellId],
  );
  const [picked, setPicked] = useState(innate.spellId);

  const spell = (id: string) => catalog.spells.find((s) => s.id === id) as SpellJson | undefined;
  const lists = innate.replaceableFrom.map((id) => nameOf(catalog.classes, id) ?? id);
  const listNames =
    lists.length === 1
      ? t.swapListOf(lists[0]!)
      : t.swapOr(lists.slice(0, -1).join(', '), lists[lists.length - 1]!);
  const shown = spell(picked);

  const confirm = () => {
    const r = write.act({ type: 'setInnateCantrip', granted: innate.grantedSpellId, spell: picked });
    if (!r) return;
    const name = options.find((o) => o.id === picked)?.name ?? picked;
    write.notify(t.swapDone(name), { undo: () => write.restore(r.before) });
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.swapTitle(nameOf(catalog.spells, innate.grantedSpellId) ?? innate.grantedSpellId)}
      description={t.swapBody(listNames)}
      actions={[
        { label: t.cancel },
        { label: t.luChange, primary: true, disabled: picked === innate.spellId, onSelect: confirm },
      ]}
    >
      <div className="flex flex-col gap-3">
        <SearchableList items={options} textOf={(o) => o.name} label={t.swapSearch} empty={t.catalogNoMatches} height="max-h-[300px]">
          {(o) => (
            <Option
              key={o.id}
              id={o.id}
              selected={o.id === picked}
              title={o.name}
              detail={o.id === innate.grantedSpellId ? t.swapOriginal : vocabularyLabel('school', o.school)}
              onClick={() => setPicked(o.id)}
            />
          )}
        </SearchableList>
        {shown && (
          <div className="plaque flex min-h-[92px] flex-col gap-1 px-3.5 py-2.5" aria-live="polite">
            <span className="text-[12px] text-on-surface">{spellMeta(shown)}</span>
            <span className="text-[13px] leading-[1.5] text-on-surface-variant">{shown.description}</span>
            {shown.higherLevel && (
              <HigherLevelNote
                level={shown.level}
                text={shown.higherLevel}
                className="text-[13px] leading-[1.5] text-on-surface-variant"
              />
            )}
          </div>
        )}
      </div>
    </AppDialog>
  );
}
