import { useMemo, useState, type MutableRefObject } from 'react';
import { itemEntry } from '../../codex/entries';
import { homebrewFormOptions, itemBaseOptions, itemDraft, itemForm, itemWithBaseKind, itemWithRarity, type Catalog, type ItemForm as Form, type JsonObject } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { Select } from '../../ui/primitives';
import { Option } from '../../ui/wizard';
import { EffectEditor } from './EffectEditor';
import { EntryPreview, HomebrewFormShell } from './HomebrewFormShell';
import { FormSection, numberError, PillGroup, TextAreaField, TextField, weightError } from './homebrewFields';

/** Radix no admite un valor vacío en un `Select`: «Mundano» viaja con este. */
const MUNDANE = '__mundane__';
/** Lo mismo para «Ninguno», que el motor guarda como `'none'`. */
const NONE = 'none';

/** Los tipos que «Otros efectos» no ofrece: la CA y la resistencia tienen su
 *  campo arriba, y cargar lo mismo por dos caminos sumaría la CA dos veces.
 *  Constante, porque el diálogo la usa como dependencia. */
const HIDDEN_KINDS = ['acBonus', 'resistance'];

/**
 * El formulario de un objeto propio (`ItemForm` de Flutter). Mismo patrón que
 * `WeaponForm`: el motor arma el objeto y los errores (`itemDraft`) con cada
 * cambio, y la vista previa es la ficha del Códice —la de equipo si es mundano,
 * la de objeto mágico si tiene rareza— en vivo, la misma que lee el jugador.
 *
 * Los efectos se cargan en tres partes (CA, resistencias y «otros»); el motor
 * los junta al armar el objeto. Que un objeto mundano no se sintonice y que
 * cambiar la familia del objeto base vacíe las bases marcadas también lo decide
 * el motor (`itemWithRarity`, `itemWithBaseKind`); acá solo se dibuja.
 *
 * ponytail: las cargas, su recarga, el tamaño del paquete y la propiedad de base
 * no se editan, solo se conservan del original (el motor lo hace en
 * `ItemDraft.build`). Se editan cuando alguien arme una varita propia.
 */
export function ItemForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** El objeto de partida: la plantilla, una copia o el propio que se edita. */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  exitHref: string;
  onSave: (item: JsonObject) => Promise<void>;
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const lang = useLang();
  const [start] = useState<Form>(() => itemForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);

  const draft = useMemo(() => itemDraft(initial, form), [initial, form]);
  const options = useMemo(() => homebrewFormOptions(catalog), [catalog, lang]);
  const bases = useMemo(() => (form.baseItemKind === NONE ? [] : itemBaseOptions(form.baseItemKind, catalog)), [form.baseItemKind, catalog, lang]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));

  const mundane = form.rarity === '';
  const err = tried ? draft.errors : {};
  const fields: [string, string][] = [
    ['name', t.hbName],
    ['weight', t.hbWeightShort],
    ['costCp', t.hbPriceCp],
    ['acBonus', t.hbAcBonusLabel],
    ['magicBonus', t.hbMagicBonusShort],
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
      await onSave(draft.item);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  // Una categoría o una rareza que el motor no ofrece (un objeto copiado del
  // catálogo es de categoría «magic») se conserva como opción, con su nombre.
  const withCurrent = (list: { id: string; label: string }[], current: string, labelOf: (id: string) => string) =>
    (list.some((o) => o.id === current) ? list : [...list, { id: current, label: labelOf(current) }]).map((o) => ({ value: o.id, label: o.label }));
  const categories = withCurrent(options.itemCategories, form.category, (id) => (t.itemKinds as Record<string, string | undefined>)[id] ?? id);
  const rarities = [
    { value: MUNDANE, label: t.hbMundane },
    ...withCurrent(options.rarities, form.rarity || MUNDANE, (id) => id).filter((o) => o.value !== MUNDANE),
  ];
  const baseKinds = [{ value: NONE, label: t.hbNoneCap }, ...withCurrent(options.baseItemKinds, form.baseItemKind, (id) => id).filter((o) => o.value !== NONE)];

  const entry = useMemo(() => itemEntry(draft.item, catalog, t, lang), [draft.item, catalog, t, lang]);
  const detail = useMemo(() => entry.detail(), [entry]);
  const preview = (
    <EntryPreview subtitle={[entry.subtitle, t.sources.homebrew].filter(Boolean).join(' · ')} name={draft.item.name as string} detail={detail} />
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
      saveAction="item-save"
      onSave={() => void save()}
      previewLabel={t.hbItemPreview}
      preview={preview}
    >
      <section className="card grid gap-3.5 p-4 sm:grid-cols-[3fr_2fr_2fr]">
        <TextField
          className="sm:col-span-3"
          label={t.hbName}
          dataField="item-name"
          autoFocus
          value={form.name}
          onChange={(name) => set({ name })}
          error={err.name ? t.hbReqItemName : null}
        />
        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexCategory}</span>
          <Select labelAbove className="w-full justify-between" label={t.codexCategory} value={form.category} onValueChange={(category) => set({ category })} options={categories} />
        </div>
        <TextField numeric label={t.hbWeightShort} dataField="item-weight" value={form.weight} onChange={(weight) => set({ weight })} error={weightError(err.weight, t)} />
        <TextField numeric label={t.hbPriceCp} dataField="item-cost" value={form.costCp} onChange={(costCp) => set({ costCp })} error={numberError(err.costCp, t)} />
      </section>

      <FormSection title={t.hbMagic}>
        <div className="flex max-w-[300px] min-w-0 flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.codexRarity}</span>
          <Select
            labelAbove
            className="w-full justify-between"
            label={t.codexRarity}
            value={mundane ? MUNDANE : form.rarity}
            onValueChange={(v) => setForm((f) => itemWithRarity(f, v === MUNDANE ? '' : v))}
            options={rarities}
          />
        </div>
        {/* Un objeto mundano no se sintoniza: la fila queda apagada y no responde,
            pero se deja tocar para que `aria-disabled` diga por qué. */}
        <Option
          multi
          id="requires-attunement"
          blocked={mundane}
          selected={form.requiresAttunement && !mundane}
          title={t.hbRequiresAttunement}
          onClick={() => {
            if (!mundane) set({ requiresAttunement: !form.requiresAttunement });
          }}
        />
        {mundane && <p className="text-[12.5px] text-text-muted">{t.hbOnlyMagicAttune}</p>}
      </FormSection>

      <FormSection title={t.hbEffectsEquipped}>
        <TextField
          numeric
          className="w-[300px] max-w-full"
          label={t.hbAcBonusLabel}
          dataField="item-ac-bonus"
          value={form.acBonus}
          onChange={(acBonus) => set({ acBonus })}
          error={numberError(err.acBonus, t)}
        />
        <PillGroup label={t.hbResistances} options={options.damageTypes} selected={form.resistances} onChange={(resistances) => set({ resistances })} />
        <div className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.hbOtherEffects}</span>
          <EffectEditor effects={form.otherEffects} catalog={catalog} hiddenKinds={HIDDEN_KINDS} onChange={(otherEffects) => set({ otherEffects })} />
        </div>
      </FormSection>

      <FormSection title={t.hbBaseItem}>
        <div className="grid gap-3.5 sm:grid-cols-[3fr_2fr]">
          <div className="flex min-w-0 flex-col gap-1.5">
            <span className="text-[12px] text-text-muted">{t.hbBaseItem}</span>
            <Select
              labelAbove
              className="w-full justify-between"
              label={t.hbBaseItem}
              value={form.baseItemKind}
              onValueChange={(kind) => setForm((f) => itemWithBaseKind(f, kind))}
              options={baseKinds}
            />
          </div>
          <TextField numeric label={t.hbMagicBonusShort} dataField="item-magic-bonus" value={form.magicBonus} onChange={(magicBonus) => set({ magicBonus })} error={numberError(err.magicBonus, t)} />
        </div>
        {/* Sin familia no hay nada que restringir. */}
        {form.baseItemKind !== NONE && (
          <>
            <PillGroup
              label={t.hbAllowedBases}
              options={bases.map((b) => ({ id: b.id, label: b.name }))}
              selected={form.eligibleBaseItemIds}
              onChange={(eligibleBaseItemIds) => set({ eligibleBaseItemIds })}
            />
            <p className="text-[12.5px] text-text-muted">{form.eligibleBaseItemIds.length === 0 ? t.hbAnyBase : t.hbOnlyMarked}</p>
          </>
        )}
      </FormSection>

      <FormSection title={t.hbDescription}>
        <TextAreaField label={t.hbDescription} dataField="item-description" value={form.description} onChange={(description) => set({ description })} />
        {form.hasCharges && <p className="text-[13px] text-on-surface-variant">{t.hbKeepCharges}</p>}
      </FormSection>
    </HomebrewFormShell>
  );
}
