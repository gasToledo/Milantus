import { useMemo, useState } from 'react';
import { Plus } from 'lucide-react';
import { effectBuild, effectKinds, type Catalog, type EffectFieldInfo, type EffectKindInfo, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { cx } from '../../ui/cx';
import { Select } from '../../ui/primitives';
import { Option } from '../../ui/wizard';

type Values = Record<string, string | number | boolean>;

const INPUT = 'h-[38px] min-w-0 rounded-[var(--radius-input)] border bg-plaque px-3 text-[14px] text-on-surface';

/** Los valores con que arranca un tipo: los que declara el motor. Cambiar de
 *  tipo cambia qué significa el número («1» de CA no es «1» pie de visión). */
const startOf = (kind: EffectKindInfo): Values => Object.fromEntries(kind.fields.map((f) => [f.id, f.default]));

/**
 * «Agregar efecto» (`_AddEffectDialog` de Flutter). El motor dice qué tipos hay,
 * qué campos pide cada uno y con qué opciones (`effectKinds`); el diálogo los
 * dibuja y manda el tipo con los valores a `effectBuild`, que devuelve el
 * efecto armado o el campo que falta. React no escribe el JSON de un efecto.
 *
 * Cancelar y Esc no tocan nada; «Agregar» con un error no cierra.
 */
export function AddEffectDialog({
  catalog,
  hiddenKinds,
  onAdd,
  onClose,
}: {
  catalog: Catalog;
  hiddenKinds?: string[];
  onAdd: (effect: JsonObject) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  // Los rótulos de las opciones siguen al idioma del motor: se piden de nuevo
  // si cambia.
  const kinds = useMemo(() => effectKinds(catalog).filter((k) => !hiddenKinds?.includes(k.id)), [catalog, lang, hiddenKinds]);
  const [kindId, setKindId] = useState(kinds[0]!.id);
  const kind = kinds.find((k) => k.id === kindId)!;
  const [values, setValues] = useState<Values>(() => startOf(kind));
  const [invalid, setInvalid] = useState<string | null>(null);

  const pickKind = (id: string) => {
    setKindId(id);
    setValues(startOf(kinds.find((k) => k.id === id)!));
    setInvalid(null);
  };
  const set = (id: string, value: string | number | boolean) => {
    setValues((v) => ({ ...v, [id]: value }));
    if (invalid === id) setInvalid(null);
  };

  const add = () => {
    const built = effectBuild(kind.id, values);
    if (!built.ok) {
      setInvalid(built.field);
      return;
    }
    onAdd(built.effect);
    onClose();
  };

  const optionLabel = (field: EffectFieldInfo, o: { id: string; label: string }) => {
    // Los rótulos que son interfaz los pone este cliente; el motor manda el id.
    if (field.id === 'spellUse') return t.effInnate[o.id] ?? o.id;
    if (field.id === 'feat' && o.id === 'any') return t.effPlayerChoice;
    return o.label;
  };

  const control = (field: EffectFieldInfo) => {
    const label = field.id === 'amount' ? (t.effUnit[kind.unit] ?? kind.unit) : (t.effField[field.id] ?? field.id);
    if (field.id === 'addProficiency') {
      return (
        <Option
          key={field.id}
          id={field.id}
          multi
          selected={values.addProficiency === true}
          title={label}
          onClick={() => set('addProficiency', values.addProficiency !== true)}
        />
      );
    }
    if (field.options) {
      return (
        <div key={field.id} className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{label}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={label}
            value={String(values[field.id])}
            onValueChange={(v) => set(field.id, v)}
            options={field.options.map((o) => ({ value: o.id, label: optionLabel(field, o) }))}
          />
        </div>
      );
    }
    if (field.id === 'amount') {
      return (
        <label key={field.id} className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{label}</span>
          <input
            type="number"
            inputMode="numeric"
            data-field="effect-amount"
            value={String(values.amount)}
            onChange={(e) => set('amount', e.target.value)}
            className={cx(INPUT, 'w-[140px] border-hairline font-bold tabular-nums')}
          />
        </label>
      );
    }
    if (field.id === 'traitDescription') {
      return (
        <label key={field.id} className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{label}</span>
          <textarea
            rows={3}
            data-field="effect-trait-description"
            value={String(values.traitDescription)}
            onChange={(e) => set('traitDescription', e.target.value)}
            className="min-w-0 rounded-[var(--radius-input)] border border-hairline bg-plaque px-3 py-2 text-[14px] text-on-surface"
          />
        </label>
      );
    }
    const bad = invalid === field.id;
    return (
      <label key={field.id} className="flex flex-col gap-1.5">
        <span className="text-[12px] text-text-muted">{label}</span>
        <input
          data-field="effect-trait-name"
          value={String(values.traitName)}
          autoFocus
          aria-invalid={bad ? true : undefined}
          onChange={(e) => set('traitName', e.target.value)}
          className={cx(INPUT, bad ? 'border-crimson' : 'border-hairline')}
        />
        {bad && (
          <span role="alert" className="text-[12.5px] text-crimson">
            {t.effTraitNameRequired}
          </span>
        )}
      </label>
    );
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.effAdd}
      icon={Plus}
      width={460}
      actions={[{ label: t.cancel }, { label: t.effConfirm, primary: true, closes: false, onSelect: add }]}
    >
      <div className="flex flex-col gap-3">
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.effKindField}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.effKindField}
            value={kindId}
            onValueChange={pickKind}
            options={kinds.map((k) => ({ value: k.id, label: t.effKindLabel[k.id] ?? k.id }))}
          />
        </div>
        {kind.fields.map(control)}
      </div>
    </AppDialog>
  );
}
