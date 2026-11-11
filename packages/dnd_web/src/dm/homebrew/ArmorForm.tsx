import { useMemo, useState, type MutableRefObject } from 'react';
import { armorEntry } from '../../codex/entries';
import { armorDraft, armorForm, armorWithCategory, homebrewFormOptions, type ArmorForm as Form, type Catalog, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Eyebrow } from '../../ui/data';
import { Select } from '../../ui/primitives';
import { Option } from '../../ui/wizard';
import { EntryPreview, ExplainHere, HomebrewFormShell, useHomebrewRules, type Explained } from './HomebrewFormShell';
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
  // Lo último que se tocó: la clave que entiende `explain`. Nada hasta el primer toque.
  const [focus, setFocus] = useState<string | null>(null);
  const rules = useHomebrewRules();

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

  // Qué significa lo tocado (`explain` de Flutter): los textos son del motor.
  const explain = (key: string): Explained | null => {
    switch (key) {
      case 'category': {
        const rule = rules.armorCategory[form.category];
        const label = options.armorCategories.find((o) => o.id === form.category)?.label ?? form.category;
        return rule ? { kicker: t.codexCategory, title: label, text: rule, note: rules.armorTraining } : null;
      }
      case 'baseAc':
        return { kicker: t.hbArmorBaseAc, title: form.baseAc.trim() || t.hbxNotFilled, text: shield ? rules.shieldBaseAc : rules.armorBaseAc };
      case 'addDex':
        return { kicker: t.hbxDexterity, title: form.addDexMod ? t.hbxAddsDex : t.hbxNoDex, text: rules.armorAddDex };
      case 'maxDex': {
        const cap = form.maxDexBonus.trim();
        return { kicker: t.hbxDexCap, title: cap === '' ? t.hbxNoCap : t.hbxUpTo(cap), text: rules.armorMaxDex };
      }
      case 'strength': {
        const str = form.strengthRequirement.trim();
        return { kicker: t.hbxDemand, title: str === '' ? t.hbxNoStrReq : t.hbxStrength(str), text: rules.armorStrength };
      }
      case 'stealth':
        return { kicker: t.hbxDemand, title: form.stealthDisadvantage ? t.hbxStealthDisadv : t.hbxNoStealthDisadv, text: rules.armorStealth };
    }
    return null;
  };
  const explanation = focus === null ? null : explain(focus);
  const here = (test: (f: string) => boolean) => (focus !== null && test(focus) ? explanation : null);

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
      explanation={explanation}
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
            onValueChange={(category) => {
              setForm((f) => armorWithCategory(f, category));
              setFocus('category');
            }}
            onOpen={() => setFocus('category')}
            options={categories}
          />
        </div>
        <TextField
          numeric
          label={shield ? t.hbShieldAc : t.hbArmorBaseAc}
          dataField="armor-base-ac"
          value={form.baseAc}
          onChange={(baseAc) => set({ baseAc })}
          onFocus={() => setFocus('baseAc')}
          error={numberError(err.baseAc, t)}
        />
        <ExplainHere className="sm:col-span-2" explanation={here((f) => f === 'category' || f === 'baseAc')} />
      </section>

      {!shield && (
        <FormSection title={t.hbHowDex}>
          <Option multi id="add-dex-mod" selected={form.addDexMod} title={t.hbAddsDexMod} onClick={() => {
              set({ addDexMod: !form.addDexMod });
              setFocus('addDex');
            }}
          />
          {form.addDexMod && (
            <TextField
              numeric
              className="w-[260px] max-w-full"
              label={t.hbDexCapLabel}
              value={form.maxDexBonus}
              onChange={(maxDexBonus) => set({ maxDexBonus })}
              onFocus={() => setFocus('maxDex')}
              error={numberError(err.maxDexBonus, t)}
            />
          )}
          <ExplainHere explanation={here((f) => f === 'addDex' || f === 'maxDex')} />
        </FormSection>
      )}

      <FormSection title={t.hbDemands}>
        <TextField
          numeric
          className="w-[260px] max-w-full"
          label={t.hbStrReqLabel}
          value={form.strengthRequirement}
          onChange={(strengthRequirement) => set({ strengthRequirement })}
          onFocus={() => setFocus('strength')}
          error={numberError(err.strengthRequirement, t)}
        />
        <Option multi id="stealth-disadvantage" selected={form.stealthDisadvantage} title={t.hbStealthLabel} onClick={() => {
            set({ stealthDisadvantage: !form.stealthDisadvantage });
            setFocus('stealth');
          }}
        />
        <ExplainHere explanation={here((f) => f === 'strength' || f === 'stealth')} />
      </FormSection>

      <EconomySection weight={form.weight} costCp={form.costCp} errors={err} onChange={set} />

      <FormSection title={t.hbLegend}>
        <TextAreaField label={t.hbLegendArmor} value={form.description} onChange={(description) => set({ description })} />
      </FormSection>
    </HomebrewFormShell>
  );
}
