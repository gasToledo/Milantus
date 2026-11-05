import { useEffect, useMemo, useState, type MutableRefObject } from 'react';
import { Info } from 'lucide-react';
import { asProfile } from '../../bestiary/creature';
import { CreatureProfile } from '../../bestiary/CreatureProfile';
import {
  catalogLabel,
  creatureDraft,
  creatureForm,
  creatureFormOptions,
  type Catalog,
  type CreatureForm as Form,
  type JsonObject,
} from '../../engine';
import { useTexts } from '../../i18n/context';
import type { Texts } from '../../i18n/texts';
import { navigate } from '../../router';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { cx } from '../../ui/cx';
import { Eyebrow } from '../../ui/data';
import { DmHeader } from '../DmHeader';
import { Select } from '../../ui/primitives';
import { SpellTabs, WIZARD_ASIDE, WizardFooter } from '../../ui/wizard';

type TabKey = 'basics';

const ABILITIES = [
  ['str', 'strength'],
  ['dex', 'dexterity'],
  ['con', 'constitution'],
  ['int', 'intelligence'],
  ['wis', 'wisdom'],
  ['cha', 'charisma'],
] as const;

// Radix `Select` no acepta `value=""`: «Como en el libro» (sin tipo) viaja como
// este centinela y se traduce a `''` en el formulario.
const BOOK = 'book';

const INPUT =
  'h-[38px] w-full min-w-0 rounded-[var(--radius-input)] border bg-plaque px-3 text-[14px] text-on-surface';

/** El texto de un código de error del motor (`CreatureDraft.errors`). */
function errorText(code: string, key: string, t: Texts): string {
  if (code === 'required') return key === 'name' ? t.blockNameRequired : t.blockRowNameRequired;
  if (code === 'number') return t.blockNumberRequired;
  if (code === 'integer') return t.blockIntInvalid;
  if (code.startsWith('range:')) {
    const [, a, b] = code.split(':');
    return t.blockRange(a ?? '', b ?? '');
  }
  if (code === 'cr') return t.blockCrInvalid;
  if (code === 'negative') return t.blockNegative;
  if (code === 'dice') return t.blockDiceInvalid;
  return t.blockFormulaInvalid;
}

/**
 * El formulario del bloque de una criatura (el de un PNJ hoy; el homebrew del
 * paso 7 lo reusa). No sabe de reglas: el motor arma la criatura y los errores
 * (`creatureDraft`) con cada cambio, y la vista previa es el mismo
 * `CreatureProfile` del Bestiario.
 *
 * Guardar es explícito. Salir con cambios pregunta; los errores aparecen desde
 * el primer intento de guardar y se apagan solos al corregirlos.
 */
export function CreatureForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  leaveRef,
}: {
  /** El bloque tal como está guardado (`npcBlock`). */
  initial: JsonObject;
  catalog: Catalog;
  title: string;
  kicker?: string;
  /** Adónde se vuelve al cancelar, descartar o guardar. */
  exitHref: string;
  onSave: (creature: JsonObject) => Promise<void>;
  /** Lo que llama el «volver» del panel lateral, que no vive acá. */
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const [start] = useState<Form>(() => creatureForm(initial));
  const [form, setForm] = useState<Form>(start);
  const [tab, setTab] = useState<TabKey>('basics');
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);
  const [discarding, setDiscarding] = useState(false);
  const [previewing, setPreviewing] = useState(false);

  const draft = useMemo(() => creatureDraft(initial, form), [initial, form]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const options = useMemo(() => creatureFormOptions(), []);

  // ponytail: el botón «atrás» del navegador no pregunta, igual que el creador;
  // frenarlo pide interceptar el historial del router.
  const requestLeave = () => (dirty ? setDiscarding(true) : navigate(exitHref));
  useEffect(() => {
    leaveRef.current = requestLeave;
    return () => {
      leaveRef.current = null;
    };
  });
  // Cambios sin guardar: el navegador avisa antes de cerrar o recargar.
  useEffect(() => {
    if (!dirty) return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);

  const set = (patch: Partial<Form>) => setForm((f) => ({ ...f, ...patch }));
  const errors = tried ? draft.errors : {};

  // Rótulo de cada campo con error, para el pie; sin repetir.
  const labelOf = (key: string): string | null => {
    if (key.startsWith('abilities.')) {
      const id = ABILITIES.find(([k]) => `abilities.${k}` === key)?.[1];
      return id ? catalogLabel('ability', id) : null;
    }
    const known: Record<string, string> = {
      name: t.blockName,
      ac: t.acShort,
      hp: t.hp,
      hitDice: t.blockHitDice,
      cr: t.creatureCr,
      speed: t.creatureSpeed,
      senses: t.creatureSenses,
      initiative: t.creatureInitiative,
      passive: t.blockPassive,
      legendary: t.blockLegendary,
    };
    return known[key] ?? null;
  };
  const labels = [...new Set(Object.keys(errors).map(labelOf).filter((x): x is string => x !== null))];
  const basicsAlert = Object.keys(errors).some((k) => !k.startsWith('traits.') && !k.startsWith('actions.'));

  const save = async () => {
    if (Object.keys(draft.errors).length > 0) {
      setTried(true);
      return;
    }
    setSaving(true);
    try {
      await onSave(draft.creature);
    } catch {
      setFailed(true);
      setSaving(false);
    }
  };

  const message = failed ? t.blockSaveFailed : labels.length > 0 ? t.blockFix(labels.join(' · ')) : null;

  const typeOptions = [
    ...(start.type === '' ? [{ value: BOOK, label: t.blockTypeAsBook }] : []),
    ...options.types.map((o) => ({ value: o.id, label: o.label })),
  ];

  const text = (
    key: string,
    label: string,
    value: string,
    onChange: (v: string) => void,
    opts: { numeric?: boolean; hint?: string; grow?: string } = {},
  ) => (
    <label className={cx('flex min-w-0 flex-col gap-1.5', opts.grow)}>
      <span className="text-[12px] text-text-muted">{label}</span>
      <input
        data-field={`block-${key}`}
        value={value}
        placeholder={opts.hint}
        inputMode={opts.numeric ? 'numeric' : undefined}
        aria-invalid={errors[key] ? true : undefined}
        onChange={(e) => onChange(e.target.value)}
        className={cx(INPUT, opts.numeric && 'tabular-nums', errors[key] ? 'border-crimson' : 'border-hairline')}
      />
      {errors[key] && (
        <span role="alert" className="text-[12.5px] text-crimson">
          {errorText(errors[key], key, t)}
        </span>
      )}
    </label>
  );

  const preview = <CreatureProfile profile={asProfile(draft.creature)} row={draft.row} catalog={catalog} compact />;

  return (
    <>
      <DmHeader title={title} kicker={kicker} />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_400px]">
        <div className="flex min-w-0 flex-col gap-3">
          <SpellTabs
            plain
            label={t.npcEditBlock}
            t={t}
            current={tab}
            onSelect={(k) => setTab(k as TabKey)}
            tabs={[{ key: 'basics', title: t.blockBasicsTab, ready: true, alert: basicsAlert }]}
          />
          <section className="card flex flex-col gap-3.5 p-4">
            {text('name', t.blockName, form.name, (v) => set({ name: v }))}
            <div className="flex flex-wrap items-start gap-3">
              <div className="flex min-w-0 flex-[1_1_170px] flex-col gap-1.5">
                <span className="text-[12px] text-text-muted">{t.blockType}</span>
                <Select
                  labelAbove
                  className="w-full justify-between"
                  label={t.blockType}
                  value={form.type === '' ? BOOK : form.type}
                  onValueChange={(v) => set({ type: v === BOOK ? '' : v })}
                  options={typeOptions}
                />
              </div>
              {form.type !== '' && (
                <div className="flex min-w-0 flex-[1_1_130px] flex-col gap-1.5">
                  <span className="text-[12px] text-text-muted">{t.sizeLabel}</span>
                  <Select
                    labelAbove
                    className="w-full justify-between"
                    label={t.sizeLabel}
                    value={form.size}
                    onValueChange={(v) => set({ size: v })}
                    options={options.sizes.map((o) => ({ value: o.id, label: o.label }))}
                  />
                </div>
              )}
              {text('speed', t.creatureSpeed, form.speed, (v) => set({ speed: v }), { grow: 'flex-[1_1_180px]' })}
            </div>
            <div className="flex flex-wrap items-start gap-3">
              {text('ac', t.acShort, form.ac, (v) => set({ ac: v }), { numeric: true, grow: 'flex-[1_1_70px]' })}
              {text('hp', t.hp, form.hp, (v) => set({ hp: v }), { numeric: true, grow: 'flex-[1_1_70px]' })}
              {text('hitDice', t.blockHitDice, form.hitDice, (v) => set({ hitDice: v }), {
                hint: t.blockHitDiceHint,
                grow: 'flex-[2_1_130px]',
              })}
              {text('cr', t.creatureCr, form.cr, (v) => set({ cr: v }), { hint: t.blockCrHint, grow: 'flex-[1_1_70px]' })}
            </div>
            <div className="flex flex-col gap-1.5">
              <Eyebrow>{t.creatureAbilities}</Eyebrow>
              <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
                {ABILITIES.map(([k, id]) =>
                  text(k, catalogLabel('ability', id), form.abilities[k], (v) => set({ abilities: { ...form.abilities, [k]: v } }), {
                    numeric: true,
                  }),
                )}
              </div>
              {(initial.savingThrows !== undefined || initial.skills !== undefined) && (
                <p className="mt-0.5 text-[12.5px] text-text-muted">{t.blockKept}</p>
              )}
            </div>
            <div className="flex flex-wrap items-start gap-3">
              {text('initiative', t.creatureInitiative, form.initiative, (v) => set({ initiative: v }), {
                numeric: true,
                hint: t.blockInitiativeHint,
                grow: 'flex-[1_1_120px]',
              })}
              {text('passive', t.blockPassive, form.passive, (v) => set({ passive: v }), { numeric: true, grow: 'flex-[1_1_120px]' })}
              {text('legendary', t.blockLegendary, form.legendary, (v) => set({ legendary: v }), {
                numeric: true,
                hint: t.blockLegendaryHint,
                grow: 'flex-[1_1_120px]',
              })}
            </div>
            {text('senses', t.creatureSenses, form.senses, (v) => set({ senses: v }), { hint: t.blockSensesHint })}
            <div className="flex flex-wrap items-start gap-3">
              {text('languages', t.creatureLanguages, form.languages, (v) => set({ languages: v }), { grow: 'flex-[1_1_220px]' })}
              {text('defenses', t.blockDefenses, form.defenses, (v) => set({ defenses: v }), { grow: 'flex-[1_1_220px]' })}
            </div>
          </section>
          <WizardFooter message={message} danger={message !== null}>
            <Button tone="secondary" icon={Info} className="lg:hidden" onClick={() => setPreviewing(true)}>
              {t.blockPreview}
            </Button>
            <Button tone="secondary" onClick={requestLeave}>
              {t.cancel}
            </Button>
            <Button data-action="block-save" disabled={saving} onClick={() => void save()}>
              {failed ? t.retry : t.blockSave}
            </Button>
          </WizardFooter>
        </div>
        <aside aria-label={t.blockPreviewTitle} className={cx(WIZARD_ASIDE, 'hidden lg:flex')}>
          <div className="card p-4">{preview}</div>
        </aside>
      </div>
      <AppDialog
        open={discarding}
        onOpenChange={setDiscarding}
        title={t.blockDiscardTitle}
        description={t.blockDiscardBody}
        actions={[
          { label: t.blockKeepEditing },
          { label: t.blockDiscard, primary: true, tone: 'crimson', onSelect: () => navigate(exitHref) },
        ]}
      />
      <AppDialog
        open={previewing}
        onOpenChange={setPreviewing}
        title={t.blockPreviewTitle}
        width={560}
        actions={[{ label: t.close }]}
      >
        {preview}
      </AppDialog>
    </>
  );
}
