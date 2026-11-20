import { useMemo, useState, type MutableRefObject } from 'react';
import { featEntry } from '../../codex/entries';
import { catalogLabel, catalogLabelOrder, featDraft, featForm, type Catalog, type FeatForm as Form, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Select } from '../../ui/primitives';
import { EffectEditor } from './EffectEditor';
import { EntryPreview, ExplainHere, HomebrewFormShell, readWithLang, useHomebrewRules, type Explained } from './HomebrewFormShell';
import { FormSection, SwitchRow, TextAreaField, TextField } from './homebrewFields';

/**
 * El formulario de una dote propia (`FeatForm` de Flutter). No sabe de reglas:
 * el motor arma la dote y los errores (`featDraft`) con cada cambio, y la vista
 * previa es la ficha del Códice de esa dote armada en vivo, la misma que lee el
 * jugador.
 *
 * Las cuatro secciones quedan siempre abiertas. Guardar es explícito; salir con
 * cambios pregunta (lo hace `HomebrewFormShell`, el armazón que comparte con
 * especie y trasfondo), también si solo cambió la lista de efectos. El requisito
 * de la dote original no se edita: se conserva y se avisa.
 */
export function FeatForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** La dote de partida: la plantilla, una copia o la propia que se edita. */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  /** Adónde se vuelve al cancelar o descartar. */
  exitHref: string;
  onSave: (feat: JsonObject) => Promise<void>;
  /** Lo que llama el «volver» del panel lateral, que no vive acá. */
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const [start] = useState<Form>(() => featForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);
  // Lo último que se tocó: la clave que entiende `explain`. Nada hasta el primer toque.
  const [focus, setFocus] = useState<string | null>(null);
  const rules = useHomebrewRules();

  const draft = useMemo(() => featDraft(initial, form), [initial, form]);
  // También la lista de efectos: Flutter no detectaba que solo cambiaran ellos.
  const dirty = JSON.stringify(form) !== JSON.stringify(start);

  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));

  const save = async () => {
    if (Object.keys(draft.errors).length > 0) {
      setTried(true);
      return;
    }
    setSaving(true);
    try {
      await onSave(draft.feat);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  const message = failed ? t.hbSaveError : tried && draft.errors.name !== undefined ? t.blockFix(t.hbFeatName) : null;

  // Las categorías en el orden del motor; la de una dote importada con una
  // categoría que no conoce se conserva como opción para no cambiarla.
  const categories = useMemo(
    () =>
      readWithLang(lang, () => {
        const ids = catalogLabelOrder('featCategory');
        return form.category && !ids.includes(form.category) ? [...ids, form.category] : ids;
      }),
    [form.category, lang],
  );

  // Qué significa lo tocado (`explain` de Flutter): los textos son del motor.
  const explain = (key: string): Explained | null => {
    if (key === 'category') {
      const rule = rules.featCategory[form.category];
      return rule ? { kicker: t.codexCategory, title: catalogLabel('featCategory', form.category), text: rule } : null;
    }
    if (key === 'repeatable') {
      return { kicker: t.hbxRepetition, title: form.repeatable ? t.codexRepeatable : t.hbxOnce, text: rules.featRepeatable };
    }
    return null;
  };
  const explanation = focus === null ? null : explain(focus);
  const here = (test: (f: string) => boolean) => (focus !== null && test(focus) ? explanation : null);

  // La ficha del Códice, armada con lo que se tipea.
  const entry = useMemo(() => featEntry(draft.feat, catalog, t, lang), [draft.feat, catalog, t, lang]);
  const detail = useMemo(() => entry.detail(), [entry]);
  const preview = (
    <EntryPreview
      subtitle={[entry.subtitle, t.sources.homebrew].filter(Boolean).join(' · ')}
      name={draft.feat.name as string}
      detail={detail}
      note={form.description.trim() === '' ? t.hbFeatNoDescription : null}
    />
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
      saveAction="feat-save"
      onSave={() => void save()}
      previewLabel={t.hbFeatPreview}
      preview={preview}
      explanation={explanation}
    >
      <FormSection n={1} title={t.hbIdentity} className="grid gap-x-3.5 gap-y-3 sm:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]">
        <TextField
          label={t.hbFeatName}
          dataField="feat-name"
          autoFocus
          value={form.name}
          onChange={(name) => set({ name })}
          error={draft.errors.name !== undefined ? t.hbFeatNameRequired : null}
          showError={tried}
        />
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12.5px] text-on-surface-variant">{t.codexCategory}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.codexCategory}
            value={form.category}
            onValueChange={(v) => {
              set({ category: v });
              setFocus('category');
            }}
            onOpen={() => setFocus('category')}
            options={categories.map((id) => ({ value: id, label: catalogLabel('featCategory', id) }))}
          />
        </div>
        <ExplainHere className="sm:col-span-2" explanation={here((f) => f === 'category')} />
      </FormSection>

      <FormSection n={2} title={t.hbDescription}>
        <TextAreaField label={t.hbFeatDistinct} dataField="feat-description" value={form.description} onChange={(description) => set({ description })} />
      </FormSection>

      <FormSection n={3} title={t.hbGrants}>
        <EffectEditor effects={form.effects} catalog={catalog} onChange={(effects) => set({ effects })} />
      </FormSection>

      <FormSection n={4} title={t.hbPrereqRepeat}>
        <SwitchRow
          label={t.hbRepeatSwitch}
          checked={form.repeatable}
          onChange={(repeatable) => {
            set({ repeatable });
            setFocus('repeatable');
          }}
        />
        <ExplainHere explanation={here((f) => f === 'repeatable')} />
        {/* ponytail: el requisito no se edita, solo se conserva; se suma cuando
            alguien arme una dote general propia con requisito. */}
        {form.hasPrerequisite && <p className="text-[13px] text-on-surface-variant">{t.hbKeepPrereq}</p>}
      </FormSection>
    </HomebrewFormShell>
  );
}
