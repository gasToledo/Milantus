import { useMemo, useState, type MutableRefObject } from 'react';
import { spellEntry } from '../../codex/entries';
import { homebrewFormOptions, spellDraft, spellForm, type Catalog, type JsonObject, type SpellForm as Form } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Select } from '../../ui/primitives';
import { Option } from '../../ui/wizard';
import { EntryPreview, ExplainHere, HomebrewFormShell, useHomebrewRules, type Explained } from './HomebrewFormShell';
import { FormSection, PillGroup, TextAreaField, TextField } from './homebrewFields';

/** Radix no admite un valor vacío en un `Select`: «Sin escuela» viaja con este. */
const NO_SCHOOL = '__none__';

/**
 * El formulario de un conjuro propio (`SpellForm` de Flutter). Mismo patrón que
 * `ItemForm`: el motor arma el conjuro y los errores (`spellDraft`) con cada
 * cambio, y la vista previa es la ficha del Códice de conjuros en vivo, la misma
 * que lee el jugador. El armazón es `HomebrewFormShell`.
 *
 * Los componentes se guardan como una línea («V, S, M (una pizca de ceniza)»);
 * el motor la separa en letras y material para este formulario y la vuelve a
 * armar al guardar. El tiempo de lanzamiento es una lista y no texto libre
 * porque la ficha lo reconoce por cómo empieza («Acción adicional» escrito a
 * mano perdía su ícono); uno que no está en la lista (una reacción con su
 * disparador) se ofrece con su texto, y una clase de un pack que el formulario
 * no ofrece se muestra punteada con su id, para que duplicar un conjuro no le
 * cambie nada sin que nadie lo toque.
 */
export function SpellForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** El conjuro de partida: la plantilla, una copia o el propio que se edita. */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  exitHref: string;
  onSave: (spell: JsonObject) => Promise<void>;
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const [start] = useState<Form>(() => spellForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);
  // Lo último que se tocó: la clave que entiende `explain`. Nada hasta el primer toque.
  const [focus, setFocus] = useState<string | null>(null);
  const rules = useHomebrewRules();

  const draft = useMemo(() => spellDraft(initial, form), [initial, form]);
  const options = useMemo(() => homebrewFormOptions(catalog), [catalog, lang]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));

  const err = tried ? draft.errors : {};
  const message = failed ? t.hbSaveError : err.name !== undefined ? t.blockFix(t.hbName) : null;

  const save = async () => {
    if (Object.keys(draft.errors).length > 0) {
      setTried(true);
      return;
    }
    setSaving(true);
    try {
      await onSave(draft.spell);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  const schools = [{ value: NO_SCHOOL, label: t.hbNoSchool }, ...options.spellSchools.map((o) => ({ value: o.id, label: o.label }))];
  // Una escuela o un tiempo que la lista no trae se conservan como opción, con su texto.
  if (form.school !== '' && !options.spellSchools.some((o) => o.id === form.school)) schools.push({ value: form.school, label: form.school });
  const times = options.castingTimes.map((o) => ({ value: o.id, label: o.label }));
  if (!options.castingTimes.some((o) => o.id === form.castingTime)) times.push({ value: form.castingTime, label: form.castingTime });
  const levels = options.spellLevels.map((o) => ({ value: o.id, label: o.label }));

  // Qué significa lo tocado (`explain` de Flutter): los textos son del motor.
  const explain = (key: string): Explained | null => {
    switch (key) {
      case 'level': {
        const level = Number.parseInt(form.level, 10) || 0;
        const text = level === 0 ? rules.spellCantrip : rules.spellLevel[level - 1];
        return text ? { kicker: t.levelWord, title: level === 0 ? t.cantrip : t.spellLevelShort(level), text } : null;
      }
      case 'school': {
        const rule = rules.spellSchool[form.school];
        return rule ? { kicker: t.hbSchool, title: form.school, text: rule, note: rules.spellSchoolNote } : null;
      }
      case 'time':
        // Las claves del glosario son los tiempos guardados; todo otro tiempo es largo.
        return { kicker: t.hbCastingTime, title: form.castingTime, text: rules.spellCastingTime[form.castingTime] ?? rules.spellLongCasting };
      case 'concentration':
        return { kicker: t.codexDuration, title: t.concentration, text: rules.spellConcentration };
      case 'ritual':
        return { kicker: t.codexCastingTime, title: t.ritual, text: rules.spellRitual };
      case 'classes': {
        const names = form.classes.map((id) => options.spellClasses.find((o) => o.id === id)?.label ?? id);
        return { kicker: t.hbClassLists, title: names.length === 0 ? t.hbxNone : names.join(' · '), text: rules.spellClasses };
      }
    }
    const letter = key.slice('comp:'.length);
    const rule = rules.spellComponent[letter];
    return rule ? { kicker: t.hbxComponent, title: options.spellComponents.find((o) => o.id === letter)?.label ?? letter, text: rule } : null;
  };
  const explanation = focus === null ? null : explain(focus);
  const here = (test: (f: string) => boolean) => (focus !== null && test(focus) ? explanation : null);

  const entry = useMemo(() => spellEntry(draft.spell, catalog, t, lang), [draft.spell, catalog, t, lang]);
  const detail = useMemo(() => entry.detail(), [entry]);
  const preview = (
    <EntryPreview subtitle={[entry.subtitle, t.sources.homebrew].filter(Boolean).join(' · ')} name={draft.spell.name as string} detail={detail} />
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
      saveAction="spell-save"
      onSave={() => void save()}
      previewLabel={t.hbSpellPreview}
      preview={preview}
      explanation={explanation}
    >
      <section className="card grid gap-3.5 p-4 sm:grid-cols-2">
        <TextField
          className="sm:col-span-2"
          label={t.hbName}
          dataField="spell-name"
          autoFocus
          value={form.name}
          onChange={(name) => set({ name })}
          error={err.name ? t.hbReqSpellName : null}
        />
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.levelWord}</span>
          <Select labelAbove className="w-full justify-between" label={t.levelWord} value={form.level}
            onValueChange={(level) => {
              set({ level });
              setFocus('level');
            }}
            onOpen={() => setFocus('level')}
            options={levels}
          />
        </div>
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.hbSchool}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.hbSchool}
            value={form.school === '' ? NO_SCHOOL : form.school}
            onValueChange={(school) => {
              set({ school: school === NO_SCHOOL ? '' : school });
              setFocus('school');
            }}
            onOpen={() => setFocus('school')}
            options={schools}
          />
        </div>
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.hbCastingTime}</span>
          <Select labelAbove className="w-full justify-between" label={t.hbCastingTime} value={form.castingTime}
            onValueChange={(castingTime) => {
              set({ castingTime });
              setFocus('time');
            }}
            onOpen={() => setFocus('time')}
            options={times}
          />
        </div>
        <TextField label={t.hbRangeExample} dataField="spell-range" value={form.range} onChange={(range) => set({ range })} />
        <TextField className="sm:col-span-2" label={t.codexDuration} dataField="spell-duration" value={form.duration} onChange={(duration) => set({ duration })} />
        <ExplainHere className="sm:col-span-2" explanation={here((f) => f === 'level' || f === 'school' || f === 'time')} />
      </section>

      <FormSection title={t.codexComponents}>
        <PillGroup hideLabel label={t.codexComponents} options={options.spellComponents.map((o) => ({ id: o.id, label: `${o.id} · ${o.label}` }))} selected={form.components} onChange={(components) => set({ components })} onTouch={(id) => setFocus(`comp:${id}`)} />
        <ExplainHere explanation={here((f) => f.startsWith('comp:'))} />
        {form.components.includes('M') && <TextField label={t.hbMaterialExample} dataField="spell-material" value={form.material} onChange={(material) => set({ material })} />}
      </FormSection>

      <FormSection title={t.hbConcRitual}>
        <Option multi id="concentration" selected={form.concentration} title={t.concentration} onClick={() => {
            set({ concentration: !form.concentration });
            setFocus('concentration');
          }}
        />
        <Option multi id="ritual" selected={form.ritual} title={t.ritual} onClick={() => {
            set({ ritual: !form.ritual });
            setFocus('ritual');
          }}
        />
        <ExplainHere explanation={here((f) => f === 'concentration' || f === 'ritual')} />
      </FormSection>

      <FormSection title={t.hbClassLists}>
        <PillGroup hideLabel label={t.hbClassLists} options={options.spellClasses} selected={form.classes} onChange={(classes) => set({ classes })} onTouch={() => setFocus('classes')} />
        <ExplainHere explanation={here((f) => f === 'classes')} />
      </FormSection>

      <FormSection title={t.hbDescription}>
        <TextAreaField label={t.hbSpellDoes} dataField="spell-description" value={form.description} onChange={(description) => set({ description })} />
      </FormSection>
    </HomebrewFormShell>
  );
}
