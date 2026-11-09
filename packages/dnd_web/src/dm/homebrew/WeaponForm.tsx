import { useMemo, useState, type MutableRefObject } from 'react';
import { weaponEntry } from '../../codex/entries';
import { homebrewFormOptions, weaponDraft, weaponForm, type Catalog, type JsonObject, type WeaponForm as Form } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Select } from '../../ui/primitives';
import { EntryPreview, HomebrewFormShell } from './HomebrewFormShell';
import { diceError, EconomySection, FormSection, numberError, PillGroup, TextAreaField, TextField } from './homebrewFields';

/** Radix no admite un valor vacío en un `Select`: «Sin maestría» viaja con este. */
const NONE = '__none__';

/**
 * El formulario de un arma propia (`WeaponForm` de Flutter). Mismo patrón que
 * `RaceForm`: el motor arma el arma y los errores (`weaponDraft`) con cada
 * cambio, y la vista previa es la ficha del Códice de armas en vivo, la misma
 * que lee el jugador (y que ya explica cada propiedad marcada). El armazón es
 * `HomebrewFormShell`.
 *
 * El dado versátil aparece con «Versátil» y el alcance con «A distancia» o
 * «Arrojadiza»; si ya traen valor se ven igual, aunque se desmarque la
 * propiedad, para que nunca quede un valor guardado sin verse. Que el alcance
 * sea obligatorio y que el largo no baje del normal lo decide el motor.
 *
 * ponytail: «a dos manos salvo montado» no se edita, solo se conserva del
 * original (el motor lo hace en `WeaponDraft.build`).
 */
export function WeaponForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** El arma de partida: la plantilla, una copia o la propia que se edita. */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  exitHref: string;
  onSave: (weapon: JsonObject) => Promise<void>;
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const [start] = useState<Form>(() => weaponForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);

  const draft = useMemo(() => weaponDraft(initial, form), [initial, form]);
  const options = useMemo(() => homebrewFormOptions(catalog), [catalog, lang]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));

  // Los errores se muestran después del primer intento de guardar.
  const err = tried ? draft.errors : {};
  const fields: [string[], string][] = [
    [['name'], t.hbName],
    [['damageDice'], t.hbDamageDie],
    [['versatileDice'], t.hbVersatile],
    [['rangeNormal'], t.hbRangeNormal],
    [['rangeLong'], t.hbRangeLong],
    [['magicBonus'], t.hbMagicBonus],
    [['weight'], t.hbWeightLabel],
    [['costCp'], t.hbPriceLabel],
  ];
  const wrong = fields.filter(([keys]) => keys.some((k) => err[k] !== undefined)).map(([, label]) => label);
  const message = failed ? t.hbSaveError : wrong.length > 0 ? t.blockFix(wrong.join(', ')) : null;

  const save = async () => {
    if (Object.keys(draft.errors).length > 0) {
      setTried(true);
      return;
    }
    setSaving(true);
    try {
      await onSave(draft.weapon);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  // Una categoría o un tipo de daño que el motor no ofrece (un arma importada) se
  // conserva como opción.
  const withCurrent = (list: { id: string; label: string }[], current: string) =>
    (list.some((o) => o.id === current) ? list : [...list, { id: current, label: current }]).map((o) => ({ value: o.id, label: o.label }));
  const categories = withCurrent(options.weaponCategories, form.category);
  const damageTypes = withCurrent(options.damageTypes, form.damageType);
  const masteries = [{ value: NONE, label: t.hbNoMastery }, ...withCurrent(options.masteries, form.mastery || NONE).filter((o) => o.value !== NONE)];

  const entry = useMemo(() => weaponEntry(draft.weapon, catalog, t, lang), [draft.weapon, catalog, t, lang]);
  const detail = useMemo(() => entry.detail(), [entry]);
  const preview = (
    <EntryPreview subtitle={[entry.subtitle, t.sources.homebrew].filter(Boolean).join(' · ')} name={draft.weapon.name as string} detail={detail} />
  );

  const needsRange = form.properties.includes('ranged') || form.properties.includes('thrown');
  const showVersatile = form.properties.includes('versatile') || form.versatileDice.trim() !== '';
  const showRange = needsRange || form.rangeNormal.trim() !== '' || form.rangeLong.trim() !== '';

  return (
    <HomebrewFormShell
      title={title}
      kicker={kicker}
      exitHref={exitHref}
      leaveRef={leaveRef}
      dirty={dirty}
      message={message}
      failed={failed}
      saving={saving}
      saveAction="weapon-save"
      onSave={() => void save()}
      previewLabel={t.hbFeatPreview}
      preview={preview}
    >
      <section className="card grid gap-3.5 p-4 sm:grid-cols-[3fr_2fr_3fr]">
        <TextField
          className="sm:col-span-3"
          label={t.hbName}
          dataField="weapon-name"
          autoFocus
          value={form.name}
          onChange={(name) => set({ name })}
          error={err.name ? t.hbReqWeaponName : null}
        />
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexCategory}</span>
          <Select labelAbove className="w-full justify-between" label={t.codexCategory} value={form.category} onValueChange={(category) => set({ category })} options={categories} />
        </div>
        <TextField numeric label={t.hbDamageDie} dataField="weapon-damage-dice" value={form.damageDice} onChange={(damageDice) => set({ damageDice })} error={diceError(err.damageDice, t)} />
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.hbDamageType}</span>
          <Select labelAbove className="w-full justify-between" label={t.hbDamageType} value={form.damageType} onValueChange={(damageType) => set({ damageType })} options={damageTypes} />
        </div>
      </section>

      <FormSection title={t.codexProperties}>
        <PillGroup hideLabel label={t.codexProperties} options={options.weaponProperties} selected={form.properties} onChange={(properties) => set({ properties })} />
        {(showVersatile || showRange) && (
          <div className="grid gap-3.5 sm:grid-cols-3">
            {showVersatile && (
              <TextField numeric label={t.hbVersatile} value={form.versatileDice} onChange={(versatileDice) => set({ versatileDice })} error={diceError(err.versatileDice, t)} />
            )}
            {showRange && (
              <>
                <TextField numeric label={t.hbRangeNormal} dataField="weapon-range-normal" value={form.rangeNormal} onChange={(rangeNormal) => set({ rangeNormal })} error={numberError(err.rangeNormal, t)} />
                <TextField
                  numeric
                  label={t.hbRangeLong}
                  dataField="weapon-range-long"
                  value={form.rangeLong}
                  onChange={(rangeLong) => set({ rangeLong })}
                  error={err.rangeLong === 'rangeLongMin' ? t.hbRangeLongMin : numberError(err.rangeLong, t)}
                />
              </>
            )}
          </div>
        )}
      </FormSection>

      <section className="card grid gap-3.5 p-4 sm:grid-cols-[3fr_2fr]">
        <h2 className="font-display text-[16px] text-on-surface sm:col-span-2">{t.hbMasteryMagic}</h2>
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexMastery}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.codexMastery}
            value={form.mastery === '' ? NONE : form.mastery}
            onValueChange={(v) => set({ mastery: v === NONE ? '' : v })}
            options={masteries}
          />
        </div>
        <TextField numeric label={t.hbMagicBonus} value={form.magicBonus} onChange={(magicBonus) => set({ magicBonus })} error={numberError(err.magicBonus, t)} />
      </section>

      <EconomySection weight={form.weight} costCp={form.costCp} errors={err} onChange={set} />

      <FormSection title={t.hbLegend}>
        <TextAreaField label={t.hbLegendWeapon} value={form.description} onChange={(description) => set({ description })} />
      </FormSection>
    </HomebrewFormShell>
  );
}
