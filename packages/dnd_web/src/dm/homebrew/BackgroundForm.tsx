import { useMemo, useState, type MutableRefObject } from 'react';
import { backgroundEntry } from '../../codex/entries';
import { backgroundDraft, backgroundForm, homebrewFormOptions, type BackgroundForm as Form, type Catalog, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Select } from '../../ui/primitives';
import { EffectEditor } from './EffectEditor';
import { EntryPreview, HomebrewFormShell } from './HomebrewFormShell';
import { FormSection, PillGroup, TextAreaField, TextField } from './homebrewFields';

/** Radix no admite un valor vacío en un `Select`: «(ninguna)» viaja con este. */
const NONE = '__none__';

/**
 * El formulario de un trasfondo propio (`BackgroundForm` de Flutter). Mismo
 * patrón que `RaceForm`: el motor arma el trasfondo y los errores
 * (`backgroundDraft`), la vista previa es la ficha del Códice en vivo y el
 * armazón es `HomebrewFormShell`.
 *
 * Las características son exactamente tres: con tres marcadas las demás quedan
 * apagadas, y con menos el motor no deja guardar.
 *
 * ponytail: el equipo inicial y el emblema no se editan, solo se conservan del
 * original (y se avisa del equipo). El equipo va en su propia sección cuando
 * alguien arme un trasfondo que no parta de uno del manual.
 */
export function BackgroundForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** El trasfondo de partida: la plantilla, una copia o el propio que se edita. */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  exitHref: string;
  onSave: (background: JsonObject) => Promise<void>;
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const [start] = useState<Form>(() => backgroundForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);

  const draft = useMemo(() => backgroundDraft(initial, form), [initial, form]);
  const options = useMemo(() => homebrewFormOptions(catalog), [catalog, lang]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));

  const err = tried ? draft.errors : {};
  const wrong = [...(err.name ? [t.hbName] : []), ...(err.abilityOptions ? [t.codexAbilities] : [])];
  const message = failed ? t.hbSaveError : wrong.length > 0 ? t.blockFix(wrong.join(', ')) : null;

  const save = async () => {
    if (Object.keys(draft.errors).length > 0) {
      setTried(true);
      return;
    }
    setSaving(true);
    try {
      await onSave(draft.background);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  // Ninguna, las de origen y marcas dracónicas, y —si el original ya traía una de
  // otra categoría— esa, por su nombre, en vez de como «desconocida».
  const feats = useMemo(() => {
    const list = options.originFeats.map((f) => ({ value: f.id, label: f.name }));
    const current = form.originFeatId;
    if (current && !list.some((f) => f.value === current)) {
      const name = catalog.feats.find((f) => f.id === current)?.name;
      list.push({ value: current, label: typeof name === 'string' ? name : current });
    }
    return [{ value: NONE, label: t.hbNoneParen }, ...list];
  }, [options, form.originFeatId, catalog, t]);

  const entry = useMemo(() => backgroundEntry(draft.background, catalog, t, lang), [draft.background, catalog, t, lang]);
  const detail = useMemo(() => entry.detail(), [entry]);
  const preview = (
    <EntryPreview subtitle={[entry.subtitle, t.sources.homebrew].filter(Boolean).join(' · ')} name={draft.background.name as string} detail={detail} />
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
      saveAction="background-save"
      onSave={() => void save()}
      previewLabel={t.hbFeatPreview}
      preview={preview}
    >
      <section className="card flex flex-col gap-3.5 p-4">
        <TextField
          label={t.hbName}
          dataField="background-name"
          autoFocus
          value={form.name}
          onChange={(name) => set({ name })}
          error={err.name ? t.hbReqBgName : null}
        />
        <PillGroup
          label={t.hbPick3}
          options={options.abilities}
          selected={form.abilityOptions}
          max={3}
          onChange={(abilityOptions) => set({ abilityOptions })}
          error={err.abilityOptions ? t.hbThreeAbilities : null}
        />
        <div className="flex max-w-[360px] min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexOriginFeat}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.codexOriginFeat}
            value={form.originFeatId === '' ? NONE : form.originFeatId}
            onValueChange={(v) => set({ originFeatId: v === NONE ? '' : v })}
            options={feats}
          />
        </div>
      </section>

      <FormSection title={t.hbProficiencies}>
        <PillGroup label={t.creatureSkills} options={options.skills} selected={form.skillProficiencies} onChange={(skillProficiencies) => set({ skillProficiencies })} />
        <PillGroup label={t.codexTools} options={options.tools} selected={form.toolProficiencies} onChange={(toolProficiencies) => set({ toolProficiencies })} />
      </FormSection>

      <FormSection title={t.hbPresentation}>
        <TextField label={t.hbTaglineLabelM} value={form.tagline} onChange={(tagline) => set({ tagline })} />
        <TextAreaField label={t.hbDescription} value={form.description} onChange={(description) => set({ description })} />
      </FormSection>

      <FormSection title={t.hbExtraEffects}>
        <EffectEditor effects={form.effects} catalog={catalog} onChange={(effects) => set({ effects })} />
        {form.hasStartingEquipment && <p className="text-[13px] text-on-surface-variant">{t.hbKeepEquipment}</p>}
      </FormSection>
    </HomebrewFormShell>
  );
}
