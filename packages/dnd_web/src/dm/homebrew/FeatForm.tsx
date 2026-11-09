import { useMemo, useState, type MutableRefObject } from 'react';
import { featEntry } from '../../codex/entries';
import { catalogLabel, catalogLabelOrder, featDraft, featForm, type Catalog, type FeatForm as Form, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { cx } from '../../ui/cx';
import { Select } from '../../ui/primitives';
import { Option } from '../../ui/wizard';
import { EffectEditor } from './EffectEditor';
import { EntryPreview, HomebrewFormShell } from './HomebrewFormShell';

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

  const draft = useMemo(() => featDraft(initial, form), [initial, form]);
  // También la lista de efectos: Flutter no detectaba que solo cambiaran ellos.
  const dirty = JSON.stringify(form) !== JSON.stringify(start);

  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));
  const nameInvalid = tried && draft.errors.name !== undefined;

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

  const message = failed ? t.hbSaveError : nameInvalid ? t.blockFix(t.hbFeatName) : null;

  // Las categorías en el orden del motor; la de una dote importada con una
  // categoría que no conoce se conserva como opción para no cambiarla.
  const categories = useMemo(() => {
    const ids = catalogLabelOrder('featCategory');
    return form.category && !ids.includes(form.category) ? [...ids, form.category] : ids;
  }, [form.category, lang]);

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
    >
      <section className="card grid gap-3.5 p-4 sm:grid-cols-2">
        <label className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.hbFeatName}</span>
          <input
            data-field="feat-name"
            value={form.name}
            autoFocus
            aria-invalid={nameInvalid ? true : undefined}
            onChange={(e) => set({ name: e.target.value })}
            className={cx(
              'h-[38px] w-full min-w-0 rounded-[var(--radius-input)] border bg-plaque px-3 text-[14px] text-on-surface',
              nameInvalid ? 'border-crimson' : 'border-hairline',
            )}
          />
          {nameInvalid && (
            <span role="alert" className="text-[12.5px] text-crimson">
              {t.hbFeatNameRequired}
            </span>
          )}
        </label>
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexCategory}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.codexCategory}
            value={form.category}
            onValueChange={(v) => set({ category: v })}
            options={categories.map((id) => ({ value: id, label: catalogLabel('featCategory', id) }))}
          />
        </div>
      </section>

      <section className="card flex flex-col gap-2 p-4">
        <h2 className="font-display text-[16px] text-on-surface">{t.hbDescription}</h2>
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.hbFeatDistinct}</span>
          <textarea
            rows={4}
            data-field="feat-description"
            value={form.description}
            onChange={(e) => set({ description: e.target.value })}
            className="min-w-0 rounded-[var(--radius-input)] border border-hairline bg-plaque px-3 py-2 text-[14px] text-on-surface"
          />
        </label>
      </section>

      <section className="card flex flex-col gap-2.5 p-4">
        <h2 className="font-display text-[16px] text-on-surface">{t.hbGrants}</h2>
        <EffectEditor effects={form.effects} catalog={catalog} onChange={(effects) => set({ effects })} />
      </section>

      <section className="card flex flex-col gap-2.5 p-4">
        <h2 className="font-display text-[16px] text-on-surface">{t.hbPrereqRepeat}</h2>
        <Option id="repeatable" multi selected={form.repeatable} title={t.hbRepeatSwitch} onClick={() => set({ repeatable: !form.repeatable })} />
        {/* ponytail: el requisito no se edita, solo se conserva; se suma cuando
            alguien arme una dote general propia con requisito. */}
        {form.hasPrerequisite && <p className="text-[13px] text-on-surface-variant">{t.hbKeepPrereq}</p>}
      </section>
    </HomebrewFormShell>
  );
}
