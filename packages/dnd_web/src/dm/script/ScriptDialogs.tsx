import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Minus, Plus, Swords, X } from 'lucide-react';
import type { DmMilestone, DmScriptCreature, DmScriptLink, DmScriptNote, MusicScene, ScriptNoteKind } from '../../api/client';
import { useNpcs, useSheetCatalog } from '../../api/queries';
import { scenariosQuery } from '../../api/scenarios';
import { bestiary, scriptCheckOptions, type Catalog } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { Button, ButtonLink } from '../../ui/Button';
import { cx } from '../../ui/cx';
import { Eyebrow } from '../../ui/data';
import { Select } from '../../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../../ui/status';
import { Option, SearchableList } from '../../ui/wizard';
import { StepButton } from '../ChapterItemsField';
import { isWholeNumber, NUMBER_FILTER } from '../combat/NumberPromptDialog';
import { usePreparedCombat } from './play';

const FIELD = 'text-[14px] text-on-surface rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3';

function Field({
  label,
  value,
  onChange,
  field,
  area = false,
  invalid = false,
  placeholder,
  autoFocus,
  onEnter,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  /** En `data-field`. */
  field: string;
  area?: boolean;
  invalid?: boolean;
  placeholder?: string;
  autoFocus?: boolean;
  onEnter?: () => void;
}) {
  const shared = {
    value,
    placeholder,
    autoFocus,
    'aria-invalid': invalid,
    'data-field': field,
  };
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-[12px] text-text-muted">{label}</span>
      {area ? (
        <textarea {...shared} onChange={(e) => onChange(e.target.value)} className={`${FIELD} h-[108px] resize-y py-2`} />
      ) : (
        <input
          {...shared}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && onEnter?.()}
          className={`${FIELD} h-[38px] placeholder:text-text-muted ${invalid ? '!border-crimson' : ''}`}
        />
      )}
    </label>
  );
}

function FieldError({ children }: { children: string }) {
  return (
    <p role="alert" className="-mt-2 text-[13px] text-crimson">
      {children}
    </p>
  );
}

/** El nombre de un guion: nuevo (desde la Biblioteca) o renombrado. Si
 *  [onSubmit] falla no se cierra y el botón pasa a «Reintentar». */
export function ScriptNameDialog({
  title,
  initial = '',
  confirmLabel,
  onSubmit,
  onClose,
}: {
  title: string;
  initial?: string;
  confirmLabel: string;
  onSubmit: (name: string) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [name, setName] = useState(initial);
  const [missing, setMissing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const save = async () => {
    if (busy) return;
    if (name.trim() === '') return setMissing(true);
    setBusy(true);
    try {
      await onSubmit(name.trim());
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : confirmLabel, primary: true, closes: false, disabled: busy, onSelect: () => void save() },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        <Field
          label={t.scScriptName}
          value={name}
          onChange={(value) => {
            setName(value);
            setMissing(false);
          }}
          field="script-name"
          invalid={missing}
          autoFocus
          onEnter={() => void save()}
        />
        {missing && <FieldError>{t.scNameRequired}</FieldError>}
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.scActionError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}

export type MilestoneFields = { title: string; description: string; condition?: string; endsHere?: boolean };

/** Un hito o un camino. Sin título no se guarda. */
export function MilestoneDialog({
  heading,
  milestone,
  path,
  onSave,
  onClose,
}: {
  heading: string;
  milestone: DmMilestone;
  /** Un camino de una bifurcación suma la condición y «Termina acá». */
  path: boolean;
  onSave: (fields: MilestoneFields) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const [title, setTitle] = useState(milestone.title);
  const [description, setDescription] = useState(milestone.description);
  const [condition, setCondition] = useState(milestone.condition);
  const [endsHere, setEndsHere] = useState(milestone.endsHere);
  const [missing, setMissing] = useState(false);
  const save = () => {
    if (title.trim() === '') return setMissing(true);
    onSave({ title, description, ...(path ? { condition, endsHere } : {}) });
    onClose();
  };
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={heading}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, closes: false, onSelect: save }]}
    >
      <div className="flex flex-col gap-3.5">
        <Field
          label={t.scTitle}
          value={title}
          onChange={(value) => {
            setTitle(value);
            setMissing(false);
          }}
          field="milestone-title"
          invalid={missing}
          autoFocus
          onEnter={save}
        />
        {missing && <FieldError>{t.scTitleRequired}</FieldError>}
        <Field label={t.scDescription} value={description} onChange={setDescription} field="milestone-description" area />
        {path && (
          <>
            <Field
              label={t.scCondition}
              value={condition}
              onChange={setCondition}
              field="milestone-condition"
              placeholder={t.scConditionHint}
              onEnter={save}
            />
            <Option multi selected={endsHere} title={t.scEndsHere} onClick={() => setEndsHere(!endsHere)} />
          </>
        )}
      </div>
    </AppDialog>
  );
}

/** Una nota, con el tipo ya elegido en el menú. */
export function ScriptNoteDialog({
  kind,
  note,
  onSave,
  onClose,
}: {
  kind: ScriptNoteKind;
  note?: DmScriptNote;
  onSave: (note: DmScriptNote) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  // Los rótulos salen del motor, en el idioma activo.
  const options = useMemo(() => scriptCheckOptions(), []);
  const [title, setTitle] = useState(note?.title ?? '');
  const [body, setBody] = useState(note?.body ?? '');
  const [ability, setAbility] = useState(note?.check?.ability ?? '');
  // Radix no admite un ítem con valor vacío.
  const [skill, setSkill] = useState(note?.check?.skill ?? 'none');
  const [dc, setDc] = useState(note?.check ? String(note.check.dc) : '');
  const [tried, setTried] = useState(false);
  const dcOk = isWholeNumber(dc) && Number(dc) >= 1 && Number(dc) <= 30;
  // Cada habilidad tiene su característica (Atletismo con Fuerza,
  // Interpretación con Carisma), y se **recomienda**, no se impone: el DM puede
  // pedir Intimidación con Fuerza. Las habilidades de la característica
  // elegida van primero, la característica de la habilidad elegida se marca
  // como recomendada, y una combinación distinta lo dice debajo. Elegir una
  // habilidad sin característica trae la suya.
  const skillAbility = (id: string) => options.skills.find((s) => s.id === id)?.ability;
  const skillOptions = [
    ...options.skills.filter((s) => s.ability === ability),
    ...options.skills.filter((s) => s.ability !== ability),
  ];
  const recommended = skill === 'none' ? undefined : skillAbility(skill);
  const offCombo =
    recommended && ability !== '' && recommended !== ability
      ? t.scSkillUsually(
          options.skills.find((s) => s.id === skill)?.label ?? '',
          options.abilities.find((a) => a.code === recommended)?.label ?? '',
        )
      : null;
  const pickSkill = (id: string) => {
    setSkill(id);
    const own = skillAbility(id);
    if (ability === '' && own) setAbility(own);
  };
  const save = () => {
    if (kind === 'check' && (ability === '' || !dcOk)) return setTried(true);
    onSave({
      id: note?.id ?? crypto.randomUUID(),
      kind,
      title: kind === 'readAloud' ? '' : title.trim(),
      body,
      ...(kind === 'check' ? { check: { ability, ...(skill === 'none' ? {} : { skill }), dc: Number(dc) } } : {}),
    });
    onClose();
  };
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.scNoteKinds[kind]}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, closes: false, onSelect: save }]}
    >
      <div className="flex flex-col gap-3.5">
        {kind !== 'readAloud' && <Field label={t.scTitle} value={title} onChange={setTitle} field="note-title" autoFocus onEnter={save} />}
        {kind === 'check' && (
          <>
            <Select
              label={t.scAbility}
              value={ability}
              onValueChange={setAbility}
              options={options.abilities.map((a) => ({
                value: a.code,
                label: a.code === recommended ? t.scRecommendedAbility(a.label) : a.label,
              }))}
              className="w-full justify-between"
            />
            {tried && ability === '' && <FieldError>{t.scAbilityRequired}</FieldError>}
            <Select
              label={t.scSkill}
              value={skill}
              onValueChange={pickSkill}
              options={[{ value: 'none', label: t.scNoSkill }, ...skillOptions.map((s) => ({ value: s.id, label: s.label }))]}
              className="w-full justify-between"
            />
            {offCombo && <p className="-mt-2 text-[12.5px] text-on-surface-variant">{offCombo}</p>}
            <Field
              label={t.scDc}
              value={dc}
              onChange={(value) => NUMBER_FILTER.test(value) && setDc(value)}
              field="note-dc"
              invalid={tried && !dcOk}
              onEnter={save}
            />
            {tried && !dcOk && <FieldError>{t.scDcInvalid}</FieldError>}
          </>
        )}
        <Field label={t.scNoteText} value={body} onChange={setBody} field="note-body" area autoFocus={kind === 'readAloud'} />
      </div>
    </AppDialog>
  );
}

export interface PickItem {
  id: string;
  title: string;
  detail?: string;
}

/** Elegir una cosa de una lista con buscador. Elegir no cierra: confirma el
 *  botón de la barra. */
export function PickOneDialog({
  title,
  items,
  confirmLabel,
  searchLabel,
  emptyText,
  loading,
  error,
  onPick,
  onClose,
}: {
  title: string;
  /** `undefined` mientras cargan. */
  items: PickItem[] | undefined;
  confirmLabel: string;
  searchLabel: string;
  emptyText: string;
  loading: string;
  error?: { title: string; retry: () => void };
  onPick: (id: string) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const [selected, setSelected] = useState<string | null>(null);
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      actions={[
        { label: t.cancel },
        { label: confirmLabel, primary: true, disabled: selected === null, onSelect: () => selected !== null && onPick(selected) },
      ]}
    >
      <div className="flex flex-col gap-2.5">
        {error ? (
          <AppErrorView title={error.title} message={t.errorBody} onRetry={error.retry} />
        ) : !items ? (
          <AppBusyLabel label={loading} />
        ) : items.length === 0 ? (
          <AppEmptyState kind="empty" message={emptyText} />
        ) : (
          <SearchableList items={items} textOf={(i) => i.title} label={searchLabel} height="h-[min(42vh,360px)]" empty={t.catalogNoMatches}>
            {(i) => <Option key={i.id} id={i.id} selected={selected === i.id} title={i.title} detail={i.detail} onClick={() => setSelected(i.id)} />}
          </SearchableList>
        )}
      </div>
    </AppDialog>
  );
}

type LinkProps<T extends DmScriptLink['type']> = {
  /** El id del vínculo que se arma: el mismo al reemplazar uno. */
  id: string;
  onSave: (link: Extract<DmScriptLink, { type: T }>) => void;
  onClose: () => void;
};

/** Los PNJ de la Biblioteca y no solo los de la campaña: el guion se reusa. */
export function NpcLinkDialog({ id, onSave, onClose }: LinkProps<'npc'>) {
  const t = useTexts();
  const npcs = useNpcs();
  const items = npcs.data?.map((s) => ({ id: s.npc.id, title: s.npc.name ?? '' }));
  return (
    <PickOneDialog
      title={t.scPickNpc}
      items={items}
      confirmLabel={t.scAdd}
      searchLabel={t.dmSearchNpcs}
      emptyText={t.scNoNpcs}
      loading={t.dmNpcsLoading}
      error={npcs.isError ? { title: t.dmNpcsReadFail, retry: () => void npcs.refetch() } : undefined}
      onPick={(npcId) => onSave({ type: 'npc', id, npcId, name: items!.find((i) => i.id === npcId)!.title })}
      onClose={onClose}
    />
  );
}

export function ScenarioLinkDialog({ id, onSave, onClose }: LinkProps<'scenario'>) {
  const t = useTexts();
  const scenarios = useQuery(scenariosQuery);
  const items = scenarios.data?.map((s) => ({ id: s.id, title: s.name }));
  return (
    <PickOneDialog
      title={t.scPickScenario}
      items={items}
      confirmLabel={t.scAdd}
      searchLabel={t.dmSearchByName}
      emptyText={t.scNoScenarios}
      loading={t.dmScenariosLoading}
      error={scenarios.isError ? { title: t.dmScenarioLoadError, retry: () => void scenarios.refetch() } : undefined}
      onPick={(scenarioId) => onSave({ type: 'scenario', id, scenarioId, name: items!.find((i) => i.id === scenarioId)!.title })}
      onClose={onClose}
    />
  );
}

export function MusicLinkDialog({ id, scenes, onSave, onClose }: LinkProps<'music'> & { scenes: readonly MusicScene[] }) {
  const t = useTexts();
  return (
    <PickOneDialog
      title={t.scPickMusic}
      items={scenes.map((s) => ({ id: s.id, title: s.name }))}
      confirmLabel={t.scAdd}
      searchLabel={t.dmSearchByName}
      emptyText={t.scNoMusic}
      loading={t.scLoading}
      onPick={(sceneId) => onSave({ type: 'music', id, sceneId, name: scenes.find((s) => s.id === sceneId)!.name })}
      onClose={onClose}
    />
  );
}

/** Un combate preparado: un nombre y qué criaturas del Bestiario, con cuántas. */
export function PreparedCombatDialog({
  id,
  link,
  onSave,
  onClose,
}: LinkProps<'encounter'> & { link?: Extract<DmScriptLink, { type: 'encounter' }> }) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  const [name, setName] = useState(link?.name ?? '');
  const [chosen, setChosen] = useState<DmScriptCreature[]>(link?.creatures ?? []);
  const [tried, setTried] = useState(false);
  const save = () => {
    if (name.trim() === '' || chosen.length === 0) return setTried(true);
    onSave({ type: 'encounter', id, name: name.trim(), creatures: chosen });
    onClose();
  };
  const setCount = (creatureId: string, count: number) =>
    setChosen((list) => list.map((c) => (c.creatureId === creatureId ? { ...c, count } : c)));
  const remove = (creatureId: string) => setChosen((list) => list.filter((c) => c.creatureId !== creatureId));
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.scLinkKinds.encounter}
      width={820}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, closes: false, onSelect: save }]}
    >
      <div className="flex flex-col gap-3.5">
        <Field label={t.scScriptName} value={name} onChange={setName} field="encounter-name" invalid={tried && name.trim() === ''} autoFocus />
        {tried && name.trim() === '' && <FieldError>{t.scNameRequired}</FieldError>}
        <div className="grid grid-cols-1 items-start gap-4 lg:grid-cols-[minmax(0,1fr)_300px] lg:gap-[18px]">
          <div className="flex min-w-0 flex-col gap-2">
            {catalog.queries.some((q) => q.isError) ? (
              <AppErrorView title={t.scActionError} onRetry={() => catalog.queries.forEach((q) => void q.refetch())} />
            ) : !catalog.data ? (
              <AppBusyLabel label={t.scLoading} />
            ) : (
              <CreatureList
                catalog={catalog.data}
                chosen={chosen}
                onToggle={(creature) =>
                  chosen.some((c) => c.creatureId === creature.creatureId) ? remove(creature.creatureId) : setChosen([...chosen, creature])
                }
              />
            )}
          </div>
          <div className="plaque flex min-h-[200px] flex-col gap-2 p-3.5" data-field="encounter-chosen">
            <Eyebrow>{t.scChosenCreatures}</Eyebrow>
            {chosen.length === 0 ? (
              <p role={tried ? 'alert' : undefined} className={`text-[13px] ${tried ? 'text-crimson' : 'text-text-muted'}`}>
                {t.scEncounterEmpty}
              </p>
            ) : (
              <ul className="flex flex-col gap-2">
                {chosen.map((c) => (
                  <li key={c.creatureId} className="flex items-center gap-2" data-creature={c.creatureId}>
                    <span className="min-w-0 flex-1 text-[13.5px] break-words text-on-surface">{c.name}</span>
                    <StepButton label={t.itemQtyLess} icon={Minus} disabled={c.count <= 1} onClick={() => setCount(c.creatureId, c.count - 1)} />
                    <span className="num w-6 text-center text-[14px]">{c.count}</span>
                    <StepButton label={t.itemQtyMore} icon={Plus} onClick={() => setCount(c.creatureId, c.count + 1)} />
                    <StepButton label={t.itemRemove(c.name)} icon={X} onClick={() => remove(c.creatureId)} />
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </div>
    </AppDialog>
  );
}

function CreatureList({
  catalog,
  chosen,
  onToggle,
}: {
  catalog: Catalog;
  chosen: readonly DmScriptCreature[];
  onToggle: (creature: DmScriptCreature) => void;
}) {
  const t = useTexts();
  const creatures = useMemo(() => {
    const byId = new Map(catalog.creatures.map((c) => [c.id as string, c] as const));
    return bestiary(catalog).flatMap((row) => {
      const raw = byId.get(row.id);
      return raw ? [{ row, name: String(raw.name), homebrew: raw.source === 'homebrew' }] : [];
    });
  }, [catalog]);
  return (
    <SearchableList
      items={creatures}
      textOf={(c) => `${c.name} ${c.row.kind}`}
      label={t.dmSearchBestiary}
      height="h-[300px]"
      empty={t.catalogNoMatches}
      multi
    >
      {(c) => (
        <Option
          key={c.row.id}
          id={c.row.id}
          multi
          selected={chosen.some((x) => x.creatureId === c.row.id)}
          title={c.name}
          detail={c.row.kind}
          trailing={<span className="text-[12px] whitespace-nowrap text-text-muted">{t.bestiaryCr(c.row.crText ?? '—')}</span>}
          onClick={() => onToggle({ creatureId: c.row.id, name: c.name, count: 1, homebrew: c.homebrew })}
        />
      )}
    </SearchableList>
  );
}

/** Por qué camino se sigue. Nada viene elegido de entrada. */
export function ChoosePathDialog({
  paths,
  labels,
  busy,
  onConfirm,
  onClose,
}: {
  paths: readonly DmMilestone[];
  /** Id de camino → «4a». */
  labels: ReadonlyMap<string, string>;
  busy: boolean;
  onConfirm: (path: string) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const [selected, setSelected] = useState<string | null>(null);
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.scChoosePath}
      width={440}
      actions={[
        { label: t.cancel },
        {
          label: selected === null ? t.scContinue : t.scContinueWith(labels.get(selected)!),
          primary: true,
          tone: 'verdant',
          closes: false,
          disabled: selected === null || busy,
          onSelect: () => selected !== null && onConfirm(selected),
        },
      ]}
    >
      <div role="radiogroup" aria-label={t.scChoosePath} className="flex flex-col gap-2">
        {paths.map((path) => (
          <label
            key={path.id}
            className={cx(
              'flex min-h-14 cursor-pointer items-center gap-3 rounded-[var(--radius-card)] py-2',
              // El píxel de más del borde elegido no corre el contenido.
              selected === path.id ? 'border-2 border-gold bg-gold-soft px-[13px]' : 'border border-hairline px-3.5',
            )}
          >
            <input
              type="radio"
              name="script-path"
              value={path.id}
              checked={selected === path.id}
              onChange={() => setSelected(path.id)}
              className="m-0 shrink-0 accent-[var(--gold)]"
            />
            <span className="flex min-w-0 flex-col">
              {path.condition && <span className="text-[12px] break-words text-text-muted">{path.condition}</span>}
              <span className="font-display text-[16px] break-words text-on-surface">
                {labels.get(path.id)}. {path.title || t.scUntitled}
              </span>
            </span>
          </label>
        ))}
      </div>
    </AppDialog>
  );
}

/** Un combate preparado, en juego: qué trae y empezarlo. */
export function PreparedCombatPreview(props: Parameters<typeof usePreparedCombat>[0]) {
  const t = useTexts();
  const combat = usePreparedCombat(props);
  return (
    <AppDialog open onOpenChange={(open) => !open && props.onClose()} title={props.link.name} width={360} actions={[{ label: t.cancel }]}>
      <div className="flex flex-col gap-3">
        <ul className="flex flex-col gap-1.5">
          {props.link.creatures.map((c) => (
            <li key={c.creatureId} className="plaque flex min-h-10 items-center gap-2.5 px-3 py-1.5">
              <span className="min-w-0 flex-1 break-words">{c.name}</span>
              <span className="num font-bold">×{c.count}</span>
            </li>
          ))}
        </ul>
        <Button
          icon={Swords}
          data-action="start-prepared-combat"
          aria-disabled={combat.blocked || undefined}
          disabled={!combat.ready || combat.busy}
          onClick={() => void combat.start()}
          className={cx('min-h-11 !bg-crimson', combat.blocked && 'opacity-45')}
        >
          {t.scStartCombat}
        </Button>
        {combat.blocked && (
          <div role="alert" className="flex flex-col items-start gap-2 text-[13px] text-text-muted">
            <p>{t.scCombatOpen}</p>
            <ButtonLink internal tone="secondary" href={combat.combatHref}>
              {t.scGoToCombat}
            </ButtonLink>
          </div>
        )}
      </div>
    </AppDialog>
  );
}
