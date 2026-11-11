import { useMemo, useState, type MutableRefObject } from 'react';
import { raceEntry } from '../../codex/entries';
import { homebrewFormOptions, raceDraft, raceForm, type Catalog, type JsonObject, type RaceForm as Form } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Select } from '../../ui/primitives';
import { EffectEditor } from './EffectEditor';
import { EntryPreview, ExplainHere, HomebrewFormShell, useHomebrewRules, type Explained } from './HomebrewFormShell';
import { FormSection, numberError, PillGroup, TextAreaField, TextField } from './homebrewFields';

/**
 * El formulario de una especie propia (`RaceForm` de Flutter). No sabe de
 * reglas: el motor arma la especie y los errores (`raceDraft`) con cada cambio, y
 * la vista previa es la ficha del Códice de esa especie armada en vivo, la que
 * lee el jugador. El armazón (pie, guardia de salida, vista previa en diálogo) es
 * el de `HomebrewFormShell`.
 *
 * Las secciones quedan siempre abiertas. Los errores salen en carmesí bajo su
 * campo, recién después de un intento de guardar. El emblema no se edita: el
 * motor lo conserva del original.
 */
export function RaceForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** La especie de partida: la plantilla, una copia o la propia que se edita. */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  exitHref: string;
  onSave: (race: JsonObject) => Promise<void>;
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const [start] = useState<Form>(() => raceForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);
  // Lo último que se tocó: la clave que entiende `explain`. Nada hasta el primer toque.
  const [focus, setFocus] = useState<string | null>(null);
  const rules = useHomebrewRules();

  const draft = useMemo(() => raceDraft(initial, form), [initial, form]);
  const options = useMemo(() => homebrewFormOptions(catalog), [catalog, lang]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));

  // Los errores se muestran después del primer intento de guardar.
  const err = tried ? draft.errors : {};
  const fields: [keyof Form, string][] = [
    ['name', t.hbName],
    ['speed', t.hbSpeedFeet],
    ['skillChoiceCount', t.hbHowMany],
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
      await onSave(draft.race);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  // Un tamaño que el motor no ofrece (una especie importada) se conserva como opción.
  const sizes = options.sizes.some((s) => s.id === form.size) ? options.sizes : [...options.sizes, { id: form.size, label: form.size }];

  const entry = useMemo(() => raceEntry(draft.race, catalog, t, lang), [draft.race, catalog, t, lang]);
  const detail = useMemo(() => entry.detail(), [entry]);
  const preview = (
    <EntryPreview subtitle={[entry.subtitle, t.sources.homebrew].filter(Boolean).join(' · ')} name={draft.race.name as string} detail={detail} />
  );

  // Qué significa lo tocado (`explain` de Flutter): los textos son del motor.
  const explain = (key: string): Explained | null => {
    switch (key) {
      case 'type':
        return { kicker: t.hbCreatureType, title: form.creatureType.trim() || t.hbxNoType, text: rules.raceCreatureType };
      case 'size': {
        const rule = rules.raceSize[form.size];
        return rule ? { kicker: t.codexSize, title: sizes.find((s) => s.id === form.size)?.label ?? form.size, text: rule, note: rules.size } : null;
      }
      case 'speed':
        return { kicker: t.creatureSpeed, title: t.hbxFeet(form.speed.trim()), text: rules.raceSpeed };
      case 'skillCount':
        return {
          kicker: t.creatureSkills,
          title: t.hbxChoose(String(Number.parseInt(form.skillChoiceCount, 10) || 0)),
          text: rules.raceSkillCount,
          note: rules.skillProficiency,
        };
      case 'skillFrom':
        return { kicker: t.creatureSkills, title: t.hbxAmongWhich, text: rules.raceSkillFrom };
      case 'sizeOptions':
        return { kicker: t.codexSize, title: t.hbSizeToChoose, text: rules.raceSizeOptions };
    }
    return null;
  };
  const explanation = focus === null ? null : explain(focus);
  const here = (test: (f: string) => boolean) => (focus !== null && test(focus) ? explanation : null);

  // «Entre cuáles» aparece apenas se elige alguna, o si ya hay marcadas.
  const choosesSkills = (draft.race.skillChoiceCount as number) > 0 || form.skillChoiceFrom.length > 0;

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
      saveAction="race-save"
      onSave={() => void save()}
      previewLabel={t.hbFeatPreview}
      preview={preview}
      explanation={explanation}
    >
      <section className="card grid gap-3.5 p-4 sm:grid-cols-[3fr_2fr_2fr]">
        <TextField
          className="sm:col-span-3"
          label={t.hbName}
          dataField="race-name"
          autoFocus
          value={form.name}
          onChange={(name) => set({ name })}
          error={err.name ? t.hbReqRaceName : null}
        />
        <TextField label={t.hbCreatureType} value={form.creatureType} onChange={(creatureType) => set({ creatureType })} onFocus={() => setFocus('type')} />
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexSize}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.codexSize}
            value={form.size}
            onValueChange={(size) => {
              set({ size });
              setFocus('size');
            }}
            onOpen={() => setFocus('size')}
            options={sizes.map((s) => ({ value: s.id, label: s.label }))}
          />
        </div>
        <TextField numeric label={t.hbSpeedFeet} value={form.speed} onChange={(speed) => set({ speed })} onFocus={() => setFocus('speed')} error={numberError(err.speed, t)} />
        <ExplainHere className="sm:col-span-3" explanation={here((f) => f === 'type' || f === 'size' || f === 'speed')} />
      </section>

      <FormSection title={t.hbPresentation}>
        <TextField label={t.hbTaglineLabel} value={form.tagline} onChange={(tagline) => set({ tagline })} />
        <TextAreaField label={t.hbDescription} value={form.description} onChange={(description) => set({ description })} />
      </FormSection>

      <FormSection title={t.creatureSkills}>
        <TextField
          numeric
          className="w-[140px]"
          label={t.hbHowMany}
          value={form.skillChoiceCount}
          onChange={(skillChoiceCount) => set({ skillChoiceCount })}
          onFocus={() => setFocus('skillCount')}
          error={numberError(err.skillChoiceCount, t)}
        />
        {choosesSkills && (
          <PillGroup
            label={t.hbAmongWhich}
            options={options.skills}
            selected={form.skillChoiceFrom}
            onChange={(skillChoiceFrom) => set({ skillChoiceFrom })}
            onTouch={() => setFocus('skillFrom')}
          />
        )}
        <ExplainHere explanation={here((f) => f === 'skillCount' || f === 'skillFrom')} />
      </FormSection>

      <FormSection title={t.hbSizeToChoose}>
        <PillGroup
          hideLabel
          label={t.hbSizeToChoose}
          options={options.sizes}
          selected={form.sizeOptions}
          onChange={(sizeOptions) => set({ sizeOptions })}
          onTouch={() => setFocus('sizeOptions')}
        />
        <ExplainHere explanation={here((f) => f === 'sizeOptions')} />
      </FormSection>

      <FormSection title={t.creatureTraits}>
        <EffectEditor effects={form.effects} catalog={catalog} onChange={(effects) => set({ effects })} />
      </FormSection>
    </HomebrewFormShell>
  );
}
