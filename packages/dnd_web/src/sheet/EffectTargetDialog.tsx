import { useMemo, useState } from 'react';
import { nameOf } from '../api/catalog';
import { catalogLabel, inventoryOf, type CharacterJson, type TargetChoiceSlot } from '../engine';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Option, SearchableList } from '../ui/wizard';
import type { SheetModel } from './model';
import type { SheetWriter } from './writer';

/** Una fila elegible: un ejemplar de la mochila o un arma por crear. */
interface Row {
  /** `entry:<entryId>` o `weapon:<weaponId>`: un mismo id puede estar en las dos listas. */
  key: string;
  name: string;
  note: string;
  group: string;
}

/**
 * El arma vinculada a un rasgo (el arma de pacto): `_manageTargetChoice` de
 * Flutter, pero elegir no guarda nada; se confirma con «Vincular». Qué
 * ejemplares y qué armas entran lo dice el cupo del motor
 * (`targetChoiceSlots`); lo guardado son las acciones `setEffectTarget` y
 * `createEffectTarget`, que además lo vuelven a comprobar.
 */
export function EffectTargetDialog({
  model,
  write,
  slot,
  onClose,
}: {
  model: SheetModel;
  write: SheetWriter;
  slot: TargetChoiceSlot;
  onClose: () => void;
}) {
  const t = useTexts();
  const { character, catalog } = model;
  const lines = useMemo(() => inventoryOf(character as unknown as CharacterJson, catalog), [character, catalog]);

  const rows = useMemo<Row[]>(() => {
    const inPack: Row[] = slot.eligibleEntryIds.flatMap((id) => {
      const line = lines.find((l) => l.entryId === id);
      return line
        ? [{ key: `entry:${id}`, name: line.name, note: line.createdByFeature ? t.invCreatedByFeature : t.invInPack, group: t.invInPack }]
        : [];
    });
    const create: Row[] = slot.creatableWeaponIds.map((id) => {
      const w = catalog.weapons.find((e) => e.id === id);
      const type = typeof w?.damageType === 'string' ? catalogLabel('damageType', w.damageType) : '';
      return {
        key: `weapon:${id}`,
        name: nameOf(catalog.weapons, id) ?? id,
        note: t.invCreateNote(String(w?.damageDice ?? ''), type),
        group: t.invCreateWeapon,
      };
    });
    return [...inPack, ...create];
  }, [slot, lines, catalog, t]);

  const current = slot.chosenEntryIds[0];
  const currentKey = current ? `entry:${current}` : null;
  const currentLine = current ? lines.find((l) => l.entryId === current) : undefined;
  const [picked, setPicked] = useState<string | null>(currentKey);
  const full = slot.chosenEntryIds.length >= slot.count;
  // Con el cupo lleno y fijo, el motor no deja cambiar lo elegido.
  const locked = full && !slot.replaceable;

  const leaving = currentLine?.createdByFeature && picked !== null && picked !== currentKey;

  const confirm = () => {
    if (!picked) return;
    const [kind, id] = [picked.slice(0, picked.indexOf(':')), picked.slice(picked.indexOf(':') + 1)];
    const r =
      kind === 'entry'
        ? write.act({ type: 'setEffectTarget', group: slot.groupId, entry: id })
        : write.act({ type: 'createEffectTarget', group: slot.groupId, weapon: id });
    onClose();
    if (r) write.notify(t.invLinked(slot.name, rows.find((x) => x.key === picked)?.name ?? id), { undo: () => write.restore(r.before) });
  };
  const clear = () => {
    const r = write.act({ type: 'clearEffectTargets', group: slot.groupId });
    onClose();
    if (r) write.notify(t.invUnlinked(slot.name), { undo: () => write.restore(r.before) });
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={slot.name}
      width={560}
      actions={[
        ...(current && slot.replaceable
          ? [{ label: t.invClearLink, tone: 'crimson' as const, closes: false, onSelect: clear }]
          : []),
        { label: t.cancel },
        { label: t.invLink, primary: true, closes: false, disabled: picked === null || picked === currentKey, onSelect: confirm },
      ]}
    >
      <div className="flex flex-col gap-3">
        <span className="self-start rounded-[var(--radius-pill)] border border-hairline bg-gold-soft px-2.5 py-0.5 text-[11px] text-gold">
          {t.invTargetOf(slot.chosenEntryIds.length, slot.count)}
        </span>
        <SearchableList
          items={rows}
          textOf={(r) => r.name}
          groupOf={(r) => r.group}
          label={t.invTargetSearch}
          empty={t.catalogNoMatches}
          height="h-[400px]"
        >
          {(r) => (
            <Option
              key={r.key}
              id={r.key}
              selected={r.key === picked}
              disabled={locked && r.key !== currentKey}
              title={r.name}
              detail={r.note}
              onClick={() => setPicked(r.key)}
            />
          )}
        </SearchableList>
        <p role="status" className="min-h-5 text-[13px] text-on-surface-variant">
          {leaving && currentLine ? t.invTargetLeaves(currentLine.name) : ''}
        </p>
      </div>
    </AppDialog>
  );
}
