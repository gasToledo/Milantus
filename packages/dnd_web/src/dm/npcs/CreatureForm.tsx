import { useEffect, useMemo, useState, type MutableRefObject, type ReactNode } from 'react';
import { BookOpen, ChevronDown, ChevronRight, CircleAlert, Info, Plus, Trash2 } from 'lucide-react';
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
import { navigateBack } from '../../router';
import { signed } from '../../sheet/format';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { cx } from '../../ui/cx';
import { Eyebrow } from '../../ui/data';
import { DmHeader } from '../DmHeader';
import { Select, Tooltip } from '../../ui/primitives';
import { SpellTabs, WIZARD_ASIDE, WizardFooter } from '../../ui/wizard';

type TabKey = 'basics' | 'traits' | 'actions';

const ABILITIES = [
  ['str', 'strength'],
  ['dex', 'dexterity'],
  ['con', 'constitution'],
  ['int', 'intelligence'],
  ['wis', 'wisdom'],
  ['cha', 'charisma'],
] as const;

// Radix `Select` no acepta `value=""`: «Como en el libro» (sin tipo) y «Sin
// daño» viajan como estos centinelas y se traducen a `''` en el formulario.
const BOOK = 'book';
const NO_DAMAGE = 'none';

// Cada fila lleva un `uid` estable para que su clave de React y su estado de
// abierta no dependan de la posición: quitar una del medio no mueve las otras.
// El motor ignora las claves que no conoce.
let nextUid = 0;
const uid = () => `row-${++nextUid}`;
const withUids = (f: Form): Form => ({
  ...f,
  traits: f.traits.map((r) => ({ ...r, uid: uid() })),
  actions: f.actions.map((r) => ({ ...r, uid: uid() })),
});

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
 * El formulario del bloque de una criatura (el de un PNJ y el de una criatura
 * propia del Homebrew). No sabe de reglas: el motor arma la criatura y los errores
 * (`creatureDraft`) con cada cambio, y la vista previa es el mismo
 * `CreatureProfile` del Bestiario.
 *
 * Guardar es explícito. Salir con cambios pregunta; los errores aparecen desde
 * el primer intento de guardar y se apagan solos al corregirlos. Las filas
 * arrancan plegadas y nada las pliega solo.
 */
export function CreatureForm({
  initial,
  catalog,
  title,
  kicker,
  exitHref,
  onSave,
  saveFailedText,
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
  /** Lo que dice el formulario si [onSave] falla; por defecto, el del bloque de
   *  un PNJ. El Homebrew pone el suyo. */
  saveFailedText?: string;
  /** Lo que llama el «volver» del panel lateral, que no vive acá. */
  leaveRef: MutableRefObject<(() => void) | null>;
}) {
  const t = useTexts();
  const [start] = useState<Form>(() => withUids(creatureForm(initial)));
  const [form, setForm] = useState<Form>(start);
  const [tab, setTab] = useState<TabKey>('basics');
  const [tried, setTried] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);
  const [discarding, setDiscarding] = useState(false);
  const [previewing, setPreviewing] = useState(false);
  // Las filas abiertas (varias a la vez) y la recién agregada, que toma el foco.
  const [open, setOpen] = useState<Set<string>>(new Set());
  const [added, setAdded] = useState<string | null>(null);

  const draft = useMemo(() => creatureDraft(initial, form), [initial, form]);
  const dirty = JSON.stringify(form) !== JSON.stringify(start);
  const options = useMemo(() => creatureFormOptions(), []);

  // ponytail: el botón «atrás» del navegador no pregunta, igual que el creador;
  // frenarlo pide interceptar el historial del router.
  const requestLeave = () => (dirty ? setDiscarding(true) : navigateBack(exitHref));
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
  const errorKeys = Object.keys(errors);
  const inRows = (k: string) => k.startsWith('traits.') || k.startsWith('actions.');

  // Rótulo de cada campo con error, para el pie; sin repetir.
  const labelOf = (key: string): string | null => {
    if (key.startsWith('abilities.')) {
      const id = ABILITIES.find(([k]) => `abilities.${k}` === key)?.[1];
      return id ? catalogLabel('ability', id) : null;
    }
    const row = /^(traits|actions)\.\d+\.(\w+)$/.exec(key);
    if (row) {
      const [, kind, field] = row;
      if (field === 'name') return kind === 'traits' ? t.blockTraitNameField : t.blockActionNameField;
      if (field === 'attackBonus') return t.blockAttack;
      if (field === 'damage') return t.blockDamage;
      return t.blockDescription;
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
  const labels = [...new Set(errorKeys.map(labelOf).filter((x): x is string => x !== null))];
  const alerts = {
    basics: errorKeys.some((k) => !inRows(k)),
    traits: errorKeys.some((k) => k.startsWith('traits.')),
    actions: errorKeys.some((k) => k.startsWith('actions.')),
  };
  const rowInvalid = (kind: 'traits' | 'actions', i: number) => errorKeys.some((k) => k.startsWith(`${kind}.${i}.`));

  const save = async () => {
    const found = Object.keys(draft.errors);
    if (found.length > 0) {
      setTried(true);
      // Respuesta a un toque de la persona: va a la primera pestaña con errores
      // y abre las filas que los tienen.
      const has = (prefix: string) => found.some((k) => k.startsWith(prefix));
      setTab(found.some((k) => !inRows(k)) ? 'basics' : has('traits.') ? 'traits' : 'actions');
      const withErrors = (kind: 'traits' | 'actions') =>
        form[kind].flatMap((r, i) => (has(`${kind}.${i}.`) && r.uid ? [r.uid] : []));
      setOpen((o) => new Set([...o, ...withErrors('traits'), ...withErrors('actions')]));
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

  const message = failed ? (saveFailedText ?? t.blockSaveFailed) : labels.length > 0 ? t.blockFix(labels.join(' · ')) : null;

  const typeOptions = [
    ...(start.type === '' ? [{ value: BOOK, label: t.blockTypeAsBook }] : []),
    ...options.types.map((o) => ({ value: o.id, label: o.label })),
  ];

  const toggle = (id: string) =>
    setOpen((o) => {
      const next = new Set(o);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  const setTrait = (i: number, patch: Partial<Form['traits'][number]>) =>
    set({ traits: form.traits.map((r, j) => (j === i ? { ...r, ...patch } : r)) });
  const setAction = (i: number, patch: Partial<Form['actions'][number]>) =>
    set({ actions: form.actions.map((r, j) => (j === i ? { ...r, ...patch } : r)) });
  // Una fila nueva va al final, abierta y con el foco en su nombre.
  const addTrait = () => {
    const id = uid();
    set({ traits: [...form.traits, { uid: id, name: '', description: '' }] });
    setOpen((o) => new Set(o).add(id));
    setAdded(id);
  };
  const addAction = () => {
    const id = uid();
    set({
      actions: [
        ...form.actions,
        { uid: id, from: null, name: '', description: '', attackBonus: '', reach: '', damage: '', damageType: '', kind: 'action' },
      ],
    });
    setOpen((o) => new Set(o).add(id));
    setAdded(id);
  };

  const errorLine = (key: string) =>
    errors[key] && (
      <span role="alert" className="text-[12.5px] text-crimson">
        {errorText(errors[key], key, t)}
      </span>
    );
  const field = (
    key: string,
    label: string,
    value: string,
    onChange: (v: string) => void,
    opts: { numeric?: boolean; hint?: string; grow?: string; data?: string; focus?: boolean } = {},
  ) => (
    <label className={cx('flex min-w-0 flex-col gap-1.5', opts.grow)}>
      <span className="text-[12px] text-text-muted">{label}</span>
      <input
        data-field={opts.data ?? `block-${key}`}
        value={value}
        autoFocus={opts.focus}
        placeholder={opts.hint}
        inputMode={opts.numeric ? 'numeric' : undefined}
        aria-invalid={errors[key] ? true : undefined}
        onChange={(e) => onChange(e.target.value)}
        className={cx(INPUT, opts.numeric && 'tabular-nums', errors[key] ? 'border-crimson' : 'border-hairline')}
      />
      {errorLine(key)}
    </label>
  );
  const area = (key: string, label: string, value: string, onChange: (v: string) => void, rows: number, data: string) => (
    <label className="flex min-w-0 flex-col gap-1.5">
      <span className="text-[12px] text-text-muted">{label}</span>
      <textarea
        data-field={data}
        rows={rows}
        value={value}
        aria-invalid={errors[key] ? true : undefined}
        onChange={(e) => onChange(e.target.value)}
        className={cx(
          'min-w-0 rounded-[var(--radius-input)] border bg-plaque px-3 py-2 text-[14px] text-on-surface',
          errors[key] ? 'border-crimson' : 'border-hairline',
        )}
      />
      {errorLine(key)}
    </label>
  );

  const preview = <CreatureProfile profile={asProfile(draft.creature)} row={draft.row} catalog={catalog} compact />;
  const originalActions = initial.actions as { spellcasting?: unknown }[] | undefined;

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
            tabs={[
              { key: 'basics', title: t.blockBasicsTab, ready: true, alert: alerts.basics },
              { key: 'traits', title: t.creatureTraits, ready: true, badge: form.traits.length, alert: alerts.traits },
              { key: 'actions', title: t.creatureActions, ready: true, badge: form.actions.length, alert: alerts.actions },
            ]}
          />
          {tab === 'basics' && (
            <section className="card flex flex-col gap-3.5 p-4">
              {field('name', t.blockName, form.name, (v) => set({ name: v }))}
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
                {field('speed', t.creatureSpeed, form.speed, (v) => set({ speed: v }), { grow: 'flex-[1_1_180px]' })}
              </div>
              <div className="flex flex-wrap items-start gap-3">
                {field('ac', t.acShort, form.ac, (v) => set({ ac: v }), { numeric: true, grow: 'flex-[1_1_70px]' })}
                {field('hp', t.hp, form.hp, (v) => set({ hp: v }), { numeric: true, grow: 'flex-[1_1_70px]' })}
                {field('hitDice', t.blockHitDice, form.hitDice, (v) => set({ hitDice: v }), {
                  hint: t.blockHitDiceHint,
                  grow: 'flex-[2_1_130px]',
                })}
                {field('cr', t.creatureCr, form.cr, (v) => set({ cr: v }), { hint: t.blockCrHint, grow: 'flex-[1_1_70px]' })}
              </div>
              <div className="flex flex-col gap-1.5">
                <Eyebrow>{t.creatureAbilities}</Eyebrow>
                <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
                  {ABILITIES.map(([k, id]) =>
                    field(
                      `abilities.${k}`,
                      catalogLabel('ability', id),
                      form.abilities[k],
                      (v) => set({ abilities: { ...form.abilities, [k]: v } }),
                      { numeric: true, data: `block-${k}` },
                    ),
                  )}
                </div>
                {(initial.savingThrows !== undefined || initial.skills !== undefined) && (
                  <p className="mt-0.5 text-[12.5px] text-text-muted">{t.blockKept}</p>
                )}
              </div>
              <div className="flex flex-wrap items-start gap-3">
                {field('initiative', t.creatureInitiative, form.initiative, (v) => set({ initiative: v }), {
                  numeric: true,
                  hint: t.blockInitiativeHint,
                  grow: 'flex-[1_1_120px]',
                })}
                {field('passive', t.blockPassive, form.passive, (v) => set({ passive: v }), { numeric: true, grow: 'flex-[1_1_120px]' })}
                {field('legendary', t.blockLegendary, form.legendary, (v) => set({ legendary: v }), {
                  numeric: true,
                  hint: t.blockLegendaryHint,
                  grow: 'flex-[1_1_120px]',
                })}
              </div>
              {field('senses', t.creatureSenses, form.senses, (v) => set({ senses: v }), { hint: t.blockSensesHint })}
              <div className="flex flex-wrap items-start gap-3">
                {field('languages', t.creatureLanguages, form.languages, (v) => set({ languages: v }), { grow: 'flex-[1_1_220px]' })}
                {field('defenses', t.blockDefenses, form.defenses, (v) => set({ defenses: v }), { grow: 'flex-[1_1_220px]' })}
              </div>
            </section>
          )}
          {tab === 'traits' && (
            <section className="card flex flex-col gap-3 p-4">
              <ul className="flex flex-col gap-2">
                {form.traits.map((r, i) => {
                  const id = r.uid as string;
                  const name = r.name.trim() || t.blockNewTrait;
                  return (
                    <Row
                      key={id}
                      rowKey={`trait-${i}`}
                      title={name}
                      summary=""
                      isOpen={open.has(id)}
                      invalid={rowInvalid('traits', i)}
                      onToggle={() => toggle(id)}
                      removeLabel={t.blockRemoveTrait(name)}
                      onRemove={() => set({ traits: form.traits.filter((x) => x.uid !== id) })}
                    >
                      {field(`traits.${i}.name`, t.blockRowName, r.name, (v) => setTrait(i, { name: v }), {
                        data: 'block-trait-name',
                        focus: added === id,
                      })}
                      {area(`traits.${i}.description`, t.blockDescription, r.description, (v) => setTrait(i, { description: v }), 4, 'block-trait-description')}
                    </Row>
                  );
                })}
              </ul>
              <div>
                <Button tone="secondary" icon={Plus} data-action="add-trait" onClick={addTrait}>
                  {t.blockAddTrait}
                </Button>
              </div>
            </section>
          )}
          {tab === 'actions' && (
            <section className="card flex flex-col gap-3 p-4">
              <ul className="flex flex-col gap-2">
                {form.actions.map((r, i) => {
                  const id = r.uid as string;
                  const name = r.name.trim() || t.blockNewAction;
                  // La lista de conjuros no se edita: la acción solo muestra
                  // nombre y momento, y la lista viaja con su original.
                  const spells = r.from !== null && Boolean(originalActions?.[r.from]?.spellcasting);
                  const kindLabel = options.kinds.find((k) => k.id === r.kind)?.label ?? '';
                  const bonus = r.attackBonus.trim();
                  const summary = [
                    r.kind !== 'action' ? kindLabel : null,
                    bonus ? (Number.isFinite(Number(bonus)) ? signed(Number(bonus)) : bonus) : null,
                    r.damage.trim(),
                  ]
                    .filter(Boolean)
                    .join(' · ');
                  return (
                    <Row
                      key={id}
                      rowKey={`action-${i}`}
                      title={name}
                      summary={summary}
                      isOpen={open.has(id)}
                      invalid={rowInvalid('actions', i)}
                      onToggle={() => toggle(id)}
                      removeLabel={t.blockRemoveAction(name)}
                      onRemove={() => set({ actions: form.actions.filter((x) => x.uid !== id) })}
                    >
                      <div className="flex flex-wrap items-start gap-3">
                        {field(`actions.${i}.name`, t.blockRowName, r.name, (v) => setAction(i, { name: v }), {
                          data: 'block-action-name',
                          grow: 'flex-[2_1_200px]',
                          focus: added === id,
                        })}
                        <div className="flex min-w-0 flex-[1_1_150px] flex-col gap-1.5">
                          <span className="text-[12px] text-text-muted">{t.blockWhenUsed}</span>
                          <Select
                            labelAbove
                            className="w-full justify-between"
                            label={t.blockWhenUsed}
                            value={r.kind}
                            onValueChange={(v) => setAction(i, { kind: v })}
                            options={options.kinds.map((k) => ({ value: k.id, label: k.label }))}
                          />
                        </div>
                      </div>
                      {spells ? (
                        <p className="flex items-start gap-2 text-[12.5px] text-text-muted">
                          <BookOpen size={16} aria-hidden="true" className="mt-px shrink-0" />
                          <span>{t.blockSpellsKept}</span>
                        </p>
                      ) : (
                        <>
                          <div className="flex flex-wrap items-start gap-3">
                            {field(`actions.${i}.attackBonus`, t.blockAttack, r.attackBonus, (v) => setAction(i, { attackBonus: v }), {
                              numeric: true,
                              hint: t.blockAttackHint,
                              data: 'block-action-attack',
                              grow: 'flex-[1_1_140px]',
                            })}
                            {field(`actions.${i}.reach`, t.blockReach, r.reach, (v) => setAction(i, { reach: v }), {
                              hint: t.blockReachHint,
                              data: 'block-action-reach',
                              grow: 'flex-[1_1_140px]',
                            })}
                          </div>
                          <div className="flex flex-wrap items-start gap-3">
                            {field(`actions.${i}.damage`, t.blockDamage, r.damage, (v) => setAction(i, { damage: v }), {
                              hint: t.blockDamageHint,
                              data: 'block-action-damage',
                              grow: 'flex-[1_1_140px]',
                            })}
                            <div className="flex min-w-0 flex-[1_1_140px] flex-col gap-1.5">
                              <span className="text-[12px] text-text-muted">{t.blockDamageType}</span>
                              <Select
                                labelAbove
                                className="w-full justify-between"
                                label={t.blockDamageType}
                                value={r.damageType === '' ? NO_DAMAGE : r.damageType}
                                onValueChange={(v) => setAction(i, { damageType: v === NO_DAMAGE ? '' : v })}
                                options={[
                                  { value: NO_DAMAGE, label: t.blockNoDamage },
                                  ...options.damageTypes.map((d) => ({ value: d.id, label: d.label })),
                                ]}
                              />
                            </div>
                          </div>
                          {area(`actions.${i}.description`, t.blockDescription, r.description, (v) => setAction(i, { description: v }), 3, 'block-action-description')}
                        </>
                      )}
                    </Row>
                  );
                })}
              </ul>
              <div>
                <Button tone="secondary" icon={Plus} data-action="add-action" onClick={addAction}>
                  {t.blockAddAction}
                </Button>
              </div>
            </section>
          )}
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
          { label: t.blockDiscard, primary: true, tone: 'crimson', onSelect: () => navigateBack(exitHref) },
        ]}
      />
      <AppDialog open={previewing} onOpenChange={setPreviewing} title={t.blockPreviewTitle} width={560} actions={[{ label: t.close }]}>
        {preview}
      </AppDialog>
    </>
  );
}

/** Una fila plegable de rasgo o acción: cabecera con nombre y resumen, y el
 *  cuerpo cuando está abierta. Nada se pliega solo. */
function Row({
  rowKey,
  title,
  summary,
  isOpen,
  invalid,
  onToggle,
  removeLabel,
  onRemove,
  children,
}: {
  rowKey: string;
  title: string;
  summary: string;
  isOpen: boolean;
  invalid: boolean;
  onToggle: () => void;
  removeLabel: string;
  onRemove: () => void;
  children: ReactNode;
}) {
  const Chevron = isOpen ? ChevronDown : ChevronRight;
  return (
    <li
      data-row={rowKey}
      className={cx(
        'rounded-[var(--radius-card)] border bg-plaque',
        invalid ? 'border-crimson' : isOpen ? 'border-gold' : 'border-hairline',
      )}
    >
      <div className="flex items-center">
        <button
          type="button"
          aria-expanded={isOpen}
          onClick={onToggle}
          className="flex min-h-11 min-w-0 flex-1 items-center gap-2 px-3 text-left text-[14px] text-on-surface"
        >
          <Chevron size={16} aria-hidden="true" className="shrink-0 text-text-muted" />
          <span className="min-w-0 truncate">{title}</span>
          {invalid && <CircleAlert size={14} aria-hidden="true" className="shrink-0 text-crimson" />}
          {summary && <span className="ml-auto shrink-0 pl-2 text-[12.5px] text-text-muted tabular-nums">{summary}</span>}
        </button>
        <Tooltip content={removeLabel}>
          <button
            type="button"
            aria-label={removeLabel}
            onClick={onRemove}
            className="inline-flex size-11 shrink-0 items-center justify-center text-text-muted hover:text-crimson"
          >
            <Trash2 size={17} aria-hidden="true" />
          </button>
        </Tooltip>
      </div>
      {isOpen && <div className="step-in flex flex-col gap-3 rounded-b-[var(--radius-card)] bg-surface p-3">{children}</div>}
    </li>
  );
}
