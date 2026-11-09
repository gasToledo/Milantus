import { useMemo, useState, type MutableRefObject } from 'react';
import { armorEntry } from '../../codex/entries';
import { armorDraft, armorForm, armorWithCategory, homebrewFormOptions, type ArmorForm as Form, type Catalog, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Eyebrow } from '../../ui/data';
import { Select } from '../../ui/primitives';
import { Option } from '../../ui/wizard';
import { EntryPreview, HomebrewFormShell } from './HomebrewFormShell';
import { EconomySection, FormSection, numberError, TextAreaField, TextField } from './homebrewFields';

/**
 * El formulario de una armadura propia (`ArmorForm` de Flutter). Mismo patrón
 * que `WeaponForm`: el motor arma la armadura y los errores (`armorDraft`), y
 * la vista previa es la ficha del Códice en vivo.
 *
 * Debajo de la vista previa va «En la ficha»: la CA que la ficha le daría con
 * dos Destrezas de ejemplo (`acExamples` del motor, con el tope aplicado).
 * «Tope +2» no dice nada hasta que se ve que un personaje ágil se queda en 16.
 * Un escudo no la muestra: suma a la CA de otra cosa.
 *
 * Elegir la categoría repone lo que suma la Destreza (`armorWithCategory`): es un
 * punto de partida y no un candado. El escudo no muestra «Cómo suma la
 * Destreza», pero lo guardado se conserva.
 */
export function ArmorForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** La armadura de partida: la plantilla, una copia o la propia que se edita. */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  exitHref: string;
  onSave: (armor: JsonObject) => Promise<void>;
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const [start] = useState<Form>(() => armorForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);

  const draft = useMemo(() => armorDraft(initial, form), [initial, form]);
  const options = useMemo(() => homebrewFormOptions(catalog), [catalog, lang]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));

  const shield = form.category === 'shield';
  const err = tried ? draft.errors : {};
  const fields: [string, string][] = [
    ['name', t.hbName],
    ['baseAc', shield ? t.hbShieldAc : t.hbArmorBaseAc],
    ['maxDexBonus', t.hbDexCapLabel],
    ['strengthRequirement', t.hbStrReqLabel],
    ['weight', t.hbWeightLabel],
    ['costCp', t.hbPriceLabel],
  ];
  const wrong = fields.filter(([k]) => err[k] !== undefined).map(([, label]) => label);
  const message = failed ? t.hbSaveError : wrong.length > 0 ? t.blockFix(wrong.join(', ')) : null;

  const save = async () => {
    if (Object.keys(draft.errors).length > 0) {
      setTried(true);
      return;
    }
    setSaving(true);
    try {
      await onSave(draft.armor);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  // Una categoría que el motor no ofrece (una armadura importada) se conserva como opción.
  const categories = (options.armorCategories.some((o) => o.id === form.category) ? options.armorCategories : [...options.armorCategories, { id: form.category, label: form.category }]).map(
    (o) => ({ value: o.id, label: o.label }),
  );

  const entry = useMemo(() => armorEntry(draft.armor, catalog, t, lang), [draft.armor, catalog, t, lang]);
  const detail = useMemo(() => entry.detail(), [entry]);
  const preview = (
    <div className="flex flex-col gap-3.5">
      <EntryPreview subtitle={[entry.subtitle, t.sources.homebrew].filter(Boolean).join(' · ')} name={draft.armor.name as string} detail={detail} />
      {draft.acExamples.length > 0 && (
        <div className="flex flex-col gap-2">
          <Eyebrow>{t.hbOnSheet}</Eyebrow>
          <div className="plaque grid grid-cols-2 divide-x divide-hairline rounded-[var(--radius-card)] border border-hairline">
            {draft.acExamples.map((e) => (
              <div key={e.dex} className="flex flex-col gap-0.5 px-3.5 py-3">
                <span className="text-[11px] text-text-muted">{t.hbAcWithDex(e.dex)}</span>
                <span className="font-display text-[22px] text-on-surface">{e.ac}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );

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
      saveAction="armor-save"
      onSave={() => void save()}
      previewLabel={t.hbFeatPreview}
      preview={preview}
    >
      <section className="card grid gap-3.5 p-4 sm:grid-cols-[3fr_2fr]">
        <TextField
          className="sm:col-span-2"
          label={t.hbName}
          dataField="armor-name"
          autoFocus
          value={form.name}
          onChange={(name) => set({ name })}
          error={err.name ? t.hbReqArmorName : null}
        />
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexCategory}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.codexCategory}
            value={form.category}
            onValueChange={(category) => setForm((f) => armorWithCategory(f, category))}
            options={categories}
          />
        </div>
        <TextField numeric label={shield ? t.hbShieldAc : t.hbArmorBaseAc} dataField="armor-base-ac" value={form.baseAc} onChange={(baseAc) => set({ baseAc })} error={numberError(err.baseAc, t)} />
      </section>

      {!shield && (
        <FormSection title={t.hbHowDex}>
          <Option multi id="add-dex-mod" selected={form.addDexMod} title={t.hbAddsDexMod} onClick={() => set({ addDexMod: !form.addDexMod })} />
          {form.addDexMod && (
            <TextField
              numeric
              className="w-[260px] max-w-full"
              label={t.hbDexCapLabel}
              value={form.maxDexBonus}
              onChange={(maxDexBonus) => set({ maxDexBonus })}
              error={numberError(err.maxDexBonus, t)}
            />
          )}
        </FormSection>
      )}

      <FormSection title={t.hbDemands}>
        <TextField
          numeric
          className="w-[260px] max-w-full"
          label={t.hbStrReqLabel}
          value={form.strengthRequirement}
          onChange={(strengthRequirement) => set({ strengthRequirement })}
          error={numberError(err.strengthRequirement, t)}
        />
        <Option multi id="stealth-disadvantage" selected={form.stealthDisadvantage} title={t.hbStealthLabel} onClick={() => set({ stealthDisadvantage: !form.stealthDisadvantage })} />
      </FormSection>

      <EconomySection weight={form.weight} costCp={form.costCp} errors={err} onChange={set} />

      <FormSection title={t.hbLegend}>
        <TextAreaField label={t.hbLegendArmor} value={form.description} onChange={(description) => set({ description })} />
      </FormSection>
    </HomebrewFormShell>
  );
}
