import { useRef, useMemo, useState, type ReactNode } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import {
  BookOpen,
  Church,
  Cog,
  Crosshair,
  Eye,
  Flame,
  Hand,
  Leaf,
  Minus,
  Music,
  Plus,
  Shield,
  ShieldCheck,
  Sparkles,
  Sword,
  User,
  type LucideIcon,
} from 'lucide-react';
import { accentOf, nameOf } from '../api/catalog';
import { dropPending } from '../api/characterSave';
import { createCharacter, createNpc, linkCampaignNpc, saveCharacter } from '../api/client';
import { queryKeys, useSheetCatalog } from '../api/queries';
import { codexEntries, type CodexEntry } from '../codex/entries';
import { RosterFooter } from '../dashboard/RosterPanel';
import {
  abilityModifier,
  catalogLabel,
  computeSheet,
  creationConfirm,
  creationView,
  formatAmount,
  newNpc,
  vocabularyLabel,
  type AbilityId,
  type Catalog,
  type CharacterJson,
  type ComputedSheet,
  type CreationAction,
  type CreationDraftJson,
  type CreationPending,
  type CreationSectionId,
  type CreationView,
  type JsonObject,
  type ScoreMethodId,
} from '../engine';
import { useLang, useTexts } from '../i18n/context';
import type { Lang, Texts } from '../i18n/texts';
import { characterHref, dmCampaignHref, dmNpcsHref, navigate, rosterHref } from '../router';
import { signed } from '../sheet/format';
import { coinLabels } from '../sheet/ItemCatalog';
import { ABILITIES } from '../sheet/vocabulary';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { Shell, SidebarBack } from '../ui/Shell';
import { AppBusyLabel, AppErrorView } from '../ui/status';
import {
  AfterCard,
  AfterList,
  Block,
  DetailBody,
  Option,
  SearchableList,
  Status,
  StepRail,
  Tag,
  TraitList,
  WIZARD_ASIDE,
  WizardFooter,
  type AfterRow,
} from '../ui/wizard';
import type { Account } from '../api/client';
import { DetailsStep, EquipmentStep, ProficienciesStep, ReviewStep, SpellsStep, type Focus, type StepProps } from './ChoiceSteps';

const STEPS = [
  'especie',
  'clase',
  'trasfondo',
  'caracteristicas',
  'competencias',
  'conjuros',
  'equipo',
  'detalles',
  'revision',
] as const;
type StepId = (typeof STEPS)[number];

/** Qué partes del borrador tiene que completar cada paso para seguir. */
const SECTIONS: Record<StepId, CreationSectionId[]> = {
  especie: ['species'],
  clase: ['characterClass'],
  trasfondo: ['background'],
  caracteristicas: ['scores'],
  competencias: ['proficiencies'],
  conjuros: ['spells'],
  equipo: ['equipment'],
  detalles: [],
  revision: [],
};


const CLASS_ICONS: Record<string, LucideIcon> = {
  shield: Shield,
  rage: Flame,
  dagger: Sword,
  fist: Hand,
  spellbook: BookOpen,
  holy: Church,
  leaf: Leaf,
  music: Music,
  sparkle: Sparkles,
  eye: Eye,
  oath: ShieldCheck,
  bow: Crosshair,
  gear: Cog,
};

/** La página del creador: el marco de siempre y salir pasa por la misma
 *  confirmación que en Flutter, porque hay un borrador que se puede perder. */
export function CreationPage({
  account,
  replacing,
  npc,
}: {
  account: Account;
  replacing?: CharacterJson & { id: string };
  /** Crea la ficha de un PNJ (Modo DM) en vez de un personaje del jugador. */
  npc?: { name: string; campaignId?: string };
}) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  const [touched, setTouched] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const leaveHref = npc ? (npc.campaignId ? dmCampaignHref(npc.campaignId, 'pnj') : dmNpcsHref()) : rosterHref();
  const exit = () => {
    if (touched) setConfirming(true);
    else navigate(leaveHref);
  };
  const failed = catalog.queries.filter((q) => q.isError);
  return (
    <Shell
      panel={
        <SidebarBack
          href={leaveHref}
          label={npc ? (npc.campaignId ? t.dmSectionNpcs : t.dmNpcLibrary) : t.backToCharacters}
          onClick={(e) => { e.preventDefault(); exit(); }}
        />
      }
      footer={<RosterFooter account={account} dm={npc !== undefined} />}
    >
      {catalog.data ? (
        <CreationWizard catalog={catalog.data} replacing={replacing} npc={npc} onExit={exit} onTouched={() => setTouched(true)} />
      ) : failed.length > 0 ? (
        <AppErrorView as="h1" title={t.crLoadError} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      ) : (
        <AppBusyLabel label={t.loading} />
      )}
      <AppDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={npc ? t.crDiscardNpcTitle : t.crDiscardTitle}
        description={t.crDiscardBody}
        actions={[
          { label: t.crKeepCreating },
          { label: t.crDiscard, primary: true, tone: 'crimson', onSelect: () => navigate(leaveHref) },
        ]}
      />
    </Shell>
  );
}

/**
 * El creador de personajes (`CreationWizard` de Flutter, con el circuito del
 * lienzo «Creador de personajes»: las mismas piezas que la subida de nivel).
 *
 * Toda regla es del motor (`creationView`, sobre `CreationDraft`): acá solo se
 * manda qué tocó el jugador y se dibuja lo que vuelve, incluido qué falta.
 */
function CreationWizard({
  catalog,
  replacing,
  npc,
  onExit,
  onTouched,
}: {
  catalog: Catalog;
  npc?: { name: string; campaignId?: string };
  /** El personaje que se rehace: el borrador arranca con lo que no son reglas
   *  (nombre, alineamiento, personalidad) y al terminar se guarda sobre él. */
  replacing?: CharacterJson & { id: string };
  onExit: () => void;
  onTouched: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const [draft, setDraft] = useState<CreationDraftJson>(() => {
    if (npc) return { name: npc.name };
    if (!replacing) return {};
    const old = replacing as unknown as { name: string; alignment?: string | null; personalityTrait?: string };
    return { name: old.name, alignment: old.alignment ?? null, personalityTrait: old.personalityTrait ?? '' };
  });
  const [stepId, setStepId] = useState<StepId>('especie');
  const [focus, setFocus] = useState<Focus>(null);
  const view = useMemo(() => creationView(catalog, draft), [catalog, draft]);
  const sheet = useMemo(() => computeSheet(view.character, catalog), [view, catalog]);

  const client = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [failed, setFailed] = useState(false);
  // El mismo personaje en cada reintento: otro id, si la primera vez sí llegó y
  // lo que se perdió fue la respuesta, daría dos.
  const toCreate = useRef<(CharacterJson & { id: string }) | null>(null);
  // El mismo PNJ en cada reintento: crear y vincular son dos pedidos, y si falla el
  // segundo, reintentar no tiene que crear otro con la misma ficha.
  // ponytail: `act()` no limpia esto; si falló solo el vínculo y el DM cambia algo
  // antes de reintentar, ese cambio no se aplica. Salida: guardar la ficha en ese
  // reintento si alguna vez pasa.
  const createdNpc = useRef<string | null>(null);

  const create = async () => {
    setCreating(true);
    setFailed(false);
    try {
      toCreate.current ??= creationConfirm(catalog, view.draft, t.crUnnamed, replacing);
      if (npc) {
        const sheet = toCreate.current;
        // El nombre que vale es el de la ficha: el DM pudo retocarlo en Detalles.
        const name = (sheet as unknown as { name: string }).name;
        const npcId =
          createdNpc.current ?? (await createNpc(newNpc(catalog, name, 'character', null), sheet as unknown as JsonObject));
        createdNpc.current = npcId;
        if (npc.campaignId) await linkCampaignNpc(npc.campaignId, npcId);
        // No se invalida `roster`: la ficha de un PNJ no está en esa lista.
        await client.invalidateQueries({ queryKey: queryKeys.npcs });
        if (npc.campaignId) await client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(npc.campaignId) });
        navigate(dmNpcsHref(npcId));
        return;
      }
      let id = toCreate.current.id;
      if (replacing) {
        // Lo que había pendiente es de la ficha vieja: no puede llegar después
        // y pisar la rehecha.
        await dropPending(replacing.id);
        await saveCharacter(toCreate.current, { rebuilt: true });
      } else {
        // El servidor puede reasignar el id si choca: se navega con el suyo.
        id = await createCharacter(toCreate.current);
      }
      // Se espera a tener la lista nueva: la ficha se lee de ahí.
      await client.invalidateQueries({ queryKey: queryKeys.roster });
      navigate(characterHref(id));
    } catch {
      setFailed(true);
      setCreating(false);
    }
  };

  const act = (action: CreationAction) => {
    onTouched();
    toCreate.current = null;
    setFailed(false);
    setDraft(creationView(catalog, draft, action).draft);
  };

  // Quien no lanza ni recibe un cupo de conjuros no tiene nada que hacer ahí.
  const steps = STEPS.filter((s) => s !== 'conjuros' || view.spells.applicable);
  const index = Math.max(0, steps.indexOf(stepId));
  const last = steps.length - 1;
  const pendingOf = (s: StepId) => view.pending.filter((p) => SECTIONS[s].includes(p.section));
  const reachable = (i: number) => steps.slice(0, i).every((s) => pendingOf(s).length === 0);
  const pending = pendingOf(stepId);

  const go = (s: StepId) => {
    setStepId(s);
    // Al entrar, el panel explica lo que el paso ya tiene elegido.
    const d = view.draft;
    setFocus(
      s === 'especie' && d.raceId
        ? { kind: 'race', id: d.raceId }
        : s === 'clase' && d.classId
          ? { kind: 'class', id: d.classId }
          : s === 'trasfondo' && d.backgroundId
            ? { kind: 'background', id: d.backgroundId }
            : null,
    );
    window.scrollTo?.(0, 0);
  };

  const props = { t, lang, catalog, view, act, setFocus };
  const rows = afterRows(stepId, view, sheet, catalog, t);
  const message =
    pending.length === 0
      ? index === last
        ? failed
          ? npc ? t.crCreateNpcFailed : t.crCreateFailed
          : npc ? t.crCreateNpcHint : t.crCreateHint
        : null
      : pending[0]!.kind === 'assignScores'
        ? t.crMissingScore(t.abilities[ABILITIES.find((a) => view.draft.assignedScores?.[a] === undefined)!])
        : pending.length === 1
        ? pendingText(pending[0]!, t)
        : t.crPendingMore(pendingText(pending[0]!, t).replace(/\.$/, ''), pending.length - 1);

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="creation">
      <header className="flex flex-col gap-3">
        <h1 className="font-display text-[24px] text-on-surface">
          {replacing ? t.rebuildTitle((replacing as unknown as { name: string }).name) : npc ? t.wizardCreateNpc : t.rosterCreate}
        </h1>
        <StepRail
          steps={steps.map((id) => ({ id, label: t.crSteps[id] }))}
          index={index}
          reachable={reachable}
          onSelect={(id) => go(id as StepId)}
          label={t.luStepsLabel}
          progress={t.crProgress(index + 1, steps.length, t.crSteps[stepId])}
        />
      </header>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="flex min-w-0 flex-col gap-4">
          {stepId === 'especie' && <SpeciesStep {...props} />}
          {stepId === 'clase' && <ClassStep {...props} />}
          {stepId === 'trasfondo' && <BackgroundStep {...props} />}
          {stepId === 'caracteristicas' && <ScoresStep {...props} />}
          {stepId === 'competencias' && <ProficienciesStep {...props} />}
          {stepId === 'conjuros' && <SpellsStep {...props} />}
          {stepId === 'equipo' && <EquipmentStep {...props} />}
          {stepId === 'detalles' && <DetailsStep {...props} />}
          {stepId === 'revision' && <ReviewStep {...props} sheet={sheet} onChange={go} />}
        </div>
        <aside className={WIZARD_ASIDE}>
          {/* En un teléfono cada conjuro se lee en su diálogo: acá abajo quedaba
              lejos de la lista. */}
          {stepId !== 'detalles' && stepId !== 'revision' && (
            <div className={cx('flex flex-col', stepId === 'conjuros' && 'hidden lg:flex')}>
              <DetailPanel focus={focus} view={view} catalog={catalog} lang={lang} t={t} />
            </div>
          )}
          {rows.length > 0 && <AfterCard rows={rows} heading={t.luAfterHeading} field="creation-after" className="hidden lg:block" />}
        </aside>
      </div>

      <WizardFooter
        message={message}
        above={
          // En un teléfono «Así queda» va plegado arriba de los botones: la
          // columna de la derecha queda lejos de lo que se está eligiendo.
          rows.length > 0 && (
            <details className="w-full border-b border-hairline pb-2 lg:hidden" data-field="creation-after-phone">
              <summary className="flex min-h-9 cursor-pointer items-center gap-2 text-[13px]">
                <Eyebrow>{t.luAfterHeading}</Eyebrow>
              </summary>
              <div className="mt-2">
                <AfterList rows={rows} />
              </div>
            </details>
          )
        }
      >
        {index === 0 ? (
          <Button tone="secondary" className="flex-1 sm:flex-none" onClick={onExit}>
            {t.cancel}
          </Button>
        ) : (
          <Button tone="secondary" className="flex-1 sm:flex-none" onClick={() => go(steps[index - 1]!)}>
            {t.luBack}
          </Button>
        )}
        {index === last ? (
          <Button className="flex-[2] sm:flex-none" disabled={view.pending.length > 0 || creating} onClick={() => void create()}>
            {failed ? t.retry : replacing ? t.wizardRebuild : npc ? t.wizardCreateNpc : t.rosterCreate}
          </Button>
        ) : (
          <Button className="flex-[2] sm:flex-none" disabled={pending.length > 0} onClick={() => go(steps[index + 1]!)}>
            {t.luContinue}
          </Button>
        )}
      </WizardFooter>
    </div>
  );
}

function pendingText(p: CreationPending, t: Texts): string {
  return t.crPending[p.kind]({ ...p, amount: formatAmount(p.need, coinLabels(t)) });
}

/** El rótulo de procedencia, igual que en el Códice. */
function SourceTag({ source, t }: { source: string; t: Texts }) {
  const label = (t.sources as Record<string, string>)[source];
  return label ? <Tag>{label}</Tag> : null;
}

function SpeciesStep({ t, lang, catalog, view, act, setFocus }: StepProps) {
  const d = view.draft;
  const species = useMemo(() => codexEntries('races', catalog, t, lang), [catalog, t, lang]);
  const { lineages, sizes, needsLineageAbility, abilityOptions } = view.species;
  return (
    <>
      <Block title={t.crSteps.especie} status={<Status ready={!!d.raceId} t={t} />}>
        <SearchableList
          items={species}
          textOf={(e) => `${e.name} ${e.subtitle}`}
          label={t.crSearchSpecies}
          count={t.crCountSpecies(species.length)}
        >
          {(e) => (
            <Option
              key={e.id}
              id={e.id}
              selected={d.raceId === e.id}
              title={e.name}
              detail={e.subtitle}
              trailing={<SourceTag source={e.source} t={t} />}
              onClick={() => {
                act({ type: 'selectRace', id: e.id });
                setFocus({ kind: 'race', id: e.id });
              }}
            />
          )}
        </SearchableList>
      </Block>

      {lineages.length > 0 && (
        <Block title={t.crLineage} status={<Status ready={!!d.lineageId} t={t} />}>
          <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={t.crLineage}>
            {lineages.map((l) => (
              <Option
                key={l.id}
                id={l.id}
                selected={d.lineageId === l.id}
                title={l.name}
                trailing={l.homebrew ? <Tag>{t.homebrewTag}</Tag> : undefined}
                onClick={() => {
                  act({ type: 'selectLineage', id: l.id });
                  setFocus({ kind: 'lineage', id: l.id });
                }}
              />
            ))}
          </div>
        </Block>
      )}

      {needsLineageAbility && (
        <AbilityBlock
          title={t.crLineageAbility}
          options={abilityOptions}
          value={d.speciesSpellcastingAbility ?? null}
          onSelect={(ability) => act({ type: 'setSpeciesAbility', ability })}
          t={t}
        />
      )}

      {sizes.length > 0 && (
        <Block title={t.crSize} status={<Status ready={!!d.chosenSize} t={t} />}>
          <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={t.crSize}>
            {sizes.map((s) => (
              <Option
                key={s}
                id={s}
                selected={d.chosenSize === s}
                title={vocabularyLabel('size', s)}
                onClick={() => act({ type: 'setSize', id: s })}
              />
            ))}
          </div>
        </Block>
      )}
    </>
  );
}

/** Elegir una característica de una lista corta (aptitud mágica). */
function AbilityBlock({
  title,
  options,
  value,
  onSelect,
  t,
}: {
  title: string;
  options: AbilityId[];
  value: AbilityId | null;
  onSelect: (a: AbilityId) => void;
  t: Texts;
}) {
  return (
    <Block title={title} status={<Status ready={!!value} t={t} />}>
      <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={title}>
        {options.map((a) => (
          <Option key={a} id={a} selected={value === a} title={t.abilities[a]} onClick={() => onSelect(a)} />
        ))}
      </div>
    </Block>
  );
}

/** Clase: la fila, y después cada cupo que pide. Todo queda abierto: lo que se
 *  acaba de elegir se está leyendo a la derecha y no tiene que irse de abajo
 *  del dedo. */
function ClassStep({ t, lang, catalog, view, act, setFocus }: StepProps) {
  const d = view.draft;
  const { featureSlots, features, weaponMasterySlots, weapons } = view.class;
  const masteries = d.weaponMasteries ?? [];
  const classes = useMemo(() => codexEntries('classes', catalog, t, lang), [catalog, t, lang]);

  return (
    <>
      <Block title={t.crSteps.clase} status={<Status ready={!!d.classId} t={t} />}>
        <div role="radiogroup" aria-label={t.crSteps.clase} className="flex gap-2 overflow-x-auto pb-2.5">
          {classes.map((c) => (
            <ClassCard
              key={c.id}
              entry={c}
              icon={CLASS_ICONS[String(catalog.classes.find((k) => k.id === c.id)?.iconId)] ?? User}
              color={accentOf(catalog, c.id)}
              selected={d.classId === c.id}
              onClick={() => {
                act({ type: 'selectClass', id: c.id });
                setFocus({ kind: 'class', id: c.id });
              }}
            />
          ))}
        </div>
      </Block>

      {featureSlots.map((slot) => {
        const single = slot.count === 1;
        const full = slot.chosen.length >= slot.count;
        return (
          <Block
            key={slot.groupId}
            title={slot.name}
            status={<Status ready={full} count={single ? undefined : [slot.chosen.length, slot.count]} t={t} />}
          >
            <SearchableList
              items={slot.options}
              textOf={(o) => o.name}
              label={t.crSearchOption(slot.name)}
              multi={!single}
              columns={2}
            >
              {(o) => {
                const on = slot.chosen.includes(o.id);
                return (
                  <Option
                    key={o.id}
                    id={o.id}
                    multi={!single}
                    selected={on}
                    disabled={!on && full && !single}
                    title={o.name}
                    onClick={() => {
                      act({ type: 'toggle', pick: 'feature', id: o.id, group: slot.groupId });
                      setFocus({ kind: 'feat', id: o.id });
                    }}
                  />
                );
              }}
            </SearchableList>
          </Block>
        );
      })}

      {weaponMasterySlots > 0 && (
          <Block
            title={t.crWeaponMastery}
            status={
              <Status
                ready={masteries.length >= weaponMasterySlots}
                count={[masteries.length, weaponMasterySlots]}
                t={t}
              />
            }
          >
            <SearchableList
              items={weapons}
              textOf={(w) => `${w.name} ${w.mastery ? catalogLabel('mastery', w.mastery) : ''}`}
              label={t.crSearchWeapon}
              count={t.crCountWeapons(weapons.length)}
              columns={2}
              multi
            >
              {(w) => {
                const on = masteries.includes(w.id);
                return (
                  <Option
                    key={w.id}
                    id={w.id}
                    multi
                    selected={on}
                    disabled={!on && masteries.length >= weaponMasterySlots}
                    title={w.name}
                    detail={w.mastery ? catalogLabel('mastery', w.mastery) : undefined}
                    onClick={() => {
                      act({ type: 'toggle', pick: 'weaponMastery', id: w.id });
                      setFocus({ kind: 'weapon', id: w.id });
                    }}
                  />
                );
              }}
            </SearchableList>
          </Block>
      )}

      {d.classId && features.length > 0 && (
        <Block title={t.crClassFeatures} status={<Status auto t={t} />}>
          <TraitList traits={features} />
        </Block>
      )}
    </>
  );
}

/** Una clase en la fila: elegida se comporta como una opción. El acento de
 *  clase pinta solo el ícono, como en toda la app. */
function ClassCard({
  entry,
  icon: Icon,
  color,
  selected,
  onClick,
}: {
  entry: CodexEntry;
  icon: LucideIcon;
  color: string | null;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={selected}
      data-option={entry.id}
      onClick={onClick}
      className={cx(
        'flex min-h-24 w-[136px] shrink-0 flex-col items-start gap-1.5 rounded-[var(--radius-card)] border p-3 text-left text-on-surface',
        selected ? 'border-gold bg-gold-soft' : 'border-hairline bg-plaque',
      )}
    >
      <Icon size={20} aria-hidden="true" style={color ? { color } : undefined} />
      <span className="font-medium">{entry.name}</span>
      <span className="text-[12.5px] text-on-surface-variant">{entry.subtitle}</span>
    </button>
  );
}

function BackgroundStep({ t, lang, catalog, view, act, setFocus }: StepProps) {
  const d = view.draft;
  const entries = useMemo(() => codexEntries('backgrounds', catalog, t, lang), [catalog, t, lang]);
  const raw = (id: string): JsonObject | undefined => catalog.backgrounds.find((b) => b.id === id);
  // Lo que decide la elección —la dote y a qué características suma— y no la
  // línea de sabor, que está en el detalle: sin esto había que abrir uno por
  // uno para comparar.
  const gist = (id: string) => {
    const b = raw(id);
    const feat = typeof b?.originFeatId === 'string' ? (nameOf(catalog.feats, b.originFeatId) ?? '') : '';
    const abilities = Array.isArray(b?.abilityOptions) ? (b.abilityOptions as AbilityId[]).map((a) => t.abilityAbbr[a]).join(' ') : '';
    return [feat, abilities].filter(Boolean).join(' · ');
  };
  const { abilityOptions, featAbilityOptions } = view.background;
  const mode = d.spreadMode ?? 'twoOne';
  const plusTwo = d.spreadPlusTwo ?? null;
  const plusOne = d.spreadPlusOne ?? null;
  const chosenSpread = Number(!!plusTwo) + Number(!!plusOne);
  return (
    <>
      <Block title={t.crSteps.trasfondo} status={<Status ready={!!d.backgroundId} t={t} />}>
        <SearchableList
          items={entries}
          textOf={(e) => `${e.name} ${gist(e.id)}`}
          label={t.crSearchBackground}
          count={t.crCountBackgrounds(entries.length)}
        >
          {(e) => (
            <Option
              key={e.id}
              id={e.id}
              selected={d.backgroundId === e.id}
              title={e.name}
              detail={gist(e.id)}
              trailing={<SourceTag source={e.source} t={t} />}
              onClick={() => {
                act({ type: 'selectBackground', id: e.id });
                setFocus({ kind: 'background', id: e.id });
              }}
            />
          )}
        </SearchableList>
      </Block>

      {featAbilityOptions.length > 0 && (
        <AbilityBlock
          title={t.crFeatAbility}
          options={featAbilityOptions}
          value={d.originFeatSpellcastingAbility ?? null}
          onSelect={(ability) => act({ type: 'setOriginFeatAbility', ability })}
          t={t}
        />
      )}

      {abilityOptions.length > 0 && (
        <Block
          title={t.crSpreadTitle}
          status={<Status ready={mode === 'oneOneOne' || chosenSpread === 2} count={[mode === 'oneOneOne' ? 2 : chosenSpread, 2]} t={t} />}
        >
          <div className="grid gap-2 sm:grid-cols-2" role="radiogroup" aria-label={t.crSpreadTitle}>
            <Option
              id="twoOne"
              selected={mode === 'twoOne'}
              title={t.crSpreadTwoOne}
              onClick={() => act({ type: 'setSpreadMode', mode: 'twoOne' })}
            />
            <Option
              id="oneOneOne"
              selected={mode === 'oneOneOne'}
              title={t.crSpreadOneOneOne}
              onClick={() => act({ type: 'setSpreadMode', mode: 'oneOneOne' })}
            />
          </div>
          {mode === 'twoOne' && (
            <>
              <Eyebrow>{t.crPlusTwo}</Eyebrow>
              <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={t.crPlusTwo}>
                {abilityOptions.map((a) => (
                  <Option
                    key={a}
                    id={`two-${a}`}
                    selected={plusTwo === a}
                    title={t.abilities[a]}
                    onClick={() => act({ type: 'setSpread', plusTwo: a, plusOne })}
                  />
                ))}
              </div>
              <Eyebrow>{t.crPlusOne}</Eyebrow>
              <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={t.crPlusOne}>
                {abilityOptions.map((a) => (
                  <Option
                    key={a}
                    id={`one-${a}`}
                    selected={plusOne === a}
                    disabled={plusTwo === a}
                    title={t.abilities[a]}
                    detail={plusTwo === a ? t.crHasPlusTwo : undefined}
                    onClick={() => act({ type: 'setSpread', plusTwo, plusOne: a })}
                  />
                ))}
              </div>
            </>
          )}
        </Block>
      )}
    </>
  );
}

function ScoresStep({ t, view, act, setFocus, catalog }: StepProps) {
  const d = view.draft;
  const method: ScoreMethodId = d.scoreMethod ?? 'standardArray';
  const s = view.scores;
  const assigned = d.assignedScores ?? {};
  const count = ABILITIES.filter((a) => assigned[a] !== undefined).length;
  const className = d.classId ? nameOf(catalog.classes, d.classId) : null;
  const hasSuggestion = Object.keys(s.suggested).length > 0;
  const methods: { id: ScoreMethodId; title: string; detail: string }[] = [
    { id: 'standardArray', title: t.crMethodStandard, detail: s.standardArray.join(' ') },
    { id: 'roll4d6', title: t.crMethodRoll, detail: t.crMethodRollDetail },
    { id: 'pointBuy', title: t.crMethodPoints, detail: t.crMethodPointsDetail(s.pointBudget) },
    { id: 'manual', title: t.crMethodManual, detail: t.crMethodManualDetail(s.manualRange[0], s.manualRange[1]) },
  ];
  return (
    <>
      <Block title={t.crMethodTitle} status={<Status ready t={t} />}>
        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-4" role="radiogroup" aria-label={t.crMethodTitle}>
          {methods.map((m) => (
            <Option
              key={m.id}
              id={m.id}
              selected={method === m.id}
              title={m.title}
              detail={m.detail}
              // Tocar el mismo no vuelve a tirar ni borra lo asignado.
              onClick={() => method !== m.id && act({ type: 'applyScoreMethod', method: m.id })}
            />
          ))}
        </div>
      </Block>

      <Block title={t.crScoresTitle} status={<Status ready={count === 6} count={[count, 6]} t={t} />}>
        <div className="flex flex-wrap items-center gap-2">
          {hasSuggestion && className && (
            <Button tone="secondary" onClick={() => act({ type: 'applySuggestedScores' })}>
              {t.crUseSuggested(className)}
            </Button>
          )}
          {method === 'roll4d6' && (
            <Button tone="secondary" onClick={() => act({ type: 'applyScoreMethod', method: 'roll4d6' })}>
              {t.crRollAgain}
            </Button>
          )}
          {method !== 'manual' && count > 0 && (
            <Button tone="secondary" onClick={() => act({ type: 'clearScores' })}>
              {t.crClear}
            </Button>
          )}
          {method === 'pointBuy' && (
            <span className="ml-auto text-[13px] tabular-nums" data-field="points-left">
              {t.crPointsLeft(s.pointsRemaining, s.pointBudget)}
            </span>
          )}
        </div>
        {method === 'manual' || method === 'pointBuy' ? (
          <div className="flex flex-col gap-2.5" data-field="scores-rows">
            {ABILITIES.map((a) => (
              <ScoreRow
                key={a}
                ability={a}
                method={method}
                base={assigned[a] ?? null}
                view={view}
                act={act}
                onFocus={() => setFocus({ kind: 'ability', id: a })}
                t={t}
              />
            ))}
          </div>
        ) : (
          <ScoreMatrix view={view} act={act} setFocus={setFocus} t={t} />
        )}
      </Block>
    </>
  );
}

// Mientras entre, la matriz es una tabla; si no, cada característica son dos
// líneas y las celdas ocupan todo el ancho. Se mide el contenedor y no la
// ventana: el panel lateral y el de la derecha le comen lugar.
const MATRIX_GRID =
  'grid grid-cols-6 gap-x-1.5 @[540px]:grid-cols-[minmax(110px,1fr)_repeat(6,44px)_36px_40px_32px]';

/** La matriz de valores: un dado por columna, y dos 14 son dos columnas. Cada
 *  fila es una elección de una. La cabecera dice qué queda libre y quién tiene
 *  cada dado; tocar uno ocupado los intercambia y tocar el propio lo suelta
 *  (todo lo resuelve el motor). */
function ScoreMatrix({
  view,
  act,
  setFocus,
  t,
}: {
  view: CreationView;
  act: (a: CreationAction) => void;
  setFocus: (f: Focus) => void;
  t: Texts;
}) {
  const s = view.scores;
  const assigned = view.draft.assignedScores ?? {};
  const next = ABILITIES.find((a) => assigned[a] === undefined);
  const labelCls = 'hidden text-center text-[10.5px] tracking-[1px] text-text-muted uppercase @[540px]:block';
  return (
    <div className="@container" data-field="scores-matrix">
      {/* Fija arriba: en un teléfono las seis filas no entran y el número de
          cada columna tiene que seguir a la vista. */}
      <div aria-hidden="true" className={cx(MATRIX_GRID, 'sticky top-0 z-10 items-center bg-surface py-1')}>
        <span className="hidden @[540px]:block" />
        {s.columns.map((c, i) => (
          <span
            key={i}
            className={cx(
              'flex h-12 flex-col items-center justify-center rounded-[var(--radius-nav)] font-display text-[20px] leading-[1.1] tabular-nums',
              c.holder ? 'text-text-muted' : 'bg-gold-soft text-gold',
            )}
          >
            {c.value}
            <span className="h-3 font-sans text-[10px] tracking-[0.8px] text-text-muted">
              {c.holder ? t.abilityAbbr[c.holder] : ''}
            </span>
          </span>
        ))}
        <span className={labelCls}>{t.crColBackground}</span>
        <span className={labelCls}>{t.crColTotal}</span>
        <span className={labelCls}>{t.crColModifier}</span>
      </div>
      <div className="flex flex-col gap-2.5 @[540px]:gap-1">
        {ABILITIES.map((a) => {
          const spread = view.background.spread[a];
          const total = s.preview[a];
          return (
            <div key={a} className={cx(MATRIX_GRID, 'items-center gap-y-1')} data-ability={a} role="radiogroup" aria-label={t.abilities[a]}>
              <button
                type="button"
                onClick={() => setFocus({ kind: 'ability', id: a })}
                className={cx(
                  'col-span-3 flex min-h-9 items-center gap-2 rounded-[var(--radius-nav)] px-2 text-left @[540px]:col-span-1',
                  next === a && 'bg-gold-soft',
                )}
              >
                <span className={cx('text-[13px] font-bold tracking-[1.5px]', next === a ? 'text-gold' : 'text-on-surface-variant')}>
                  {t.abilityAbbr[a]}
                </span>
                <span className="truncate text-[12px] text-text-muted">{t.abilities[a]}</span>
              </button>
              {/* En la tabla son tres columnas al final; apiladas van al lado del nombre. */}
              <span className="col-span-3 flex items-baseline justify-end gap-3 @[540px]:contents" data-field={`score-${a}`}>
                <span className="num text-center text-[12px] font-bold text-gold @[540px]:order-1">{spread ? signed(spread) : ''}</span>
                <span className={cx('text-center font-display text-[21px] tabular-nums @[540px]:order-2', total === undefined && 'text-text-muted')}>
                  {total ?? '—'}
                </span>
                <span className="num w-7 text-right font-bold tabular-nums @[540px]:order-3 @[540px]:w-auto">
                  {total === undefined ? '—' : signed(abilityModifier(total))}
                </span>
              </span>
              {s.columns.map((c, i) => {
                const on = c.holder === a;
                const other = c.holder && !on ? t.abilities[c.holder] : null;
                return (
                  <button
                    key={i}
                    type="button"
                    role="radio"
                    aria-checked={on}
                    data-value={c.value}
                    aria-label={other ? t.crSwapWith(c.value, other) : String(c.value)}
                    title={other ? t.crSwapWith(c.value, other) : undefined}
                    onClick={() => {
                      act(on ? { type: 'unassignScore', ability: a } : { type: 'assignScore', ability: a, value: c.value });
                      setFocus({ kind: 'ability', id: a });
                    }}
                    className={cx(
                      'num h-12 w-full rounded-[var(--radius-nav)] border text-[16px] tabular-nums transition-colors duration-[120ms] hover:border-gold @[540px]:h-11',
                      on
                        ? 'border-gold bg-gold font-bold text-on-primary'
                        : other
                          ? 'border-dashed border-hairline text-text-muted'
                          : 'border-hairline bg-plaque text-on-surface',
                    )}
                  >
                    {c.value}
                  </button>
                );
              })}
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Una fila de los métodos que no reparten dados: −/+ en compra de puntos y un
 *  campo a mano. */
function ScoreRow({
  ability,
  method,
  base,
  view,
  act,
  onFocus,
  t,
}: {
  ability: AbilityId;
  method: ScoreMethodId;
  base: number | null;
  view: CreationView;
  act: (a: CreationAction) => void;
  onFocus: () => void;
  t: Texts;
}) {
  const s = view.scores;
  const spread = view.background.spread[ability];
  const total = s.preview[ability];
  let control: ReactNode;
  if (method === 'manual') {
    control = (
      <input
        type="number"
        inputMode="numeric"
        min={s.manualRange[0]}
        max={s.manualRange[1]}
        aria-label={t.abilities[ability]}
        value={base ?? ''}
        onFocus={onFocus}
        onChange={(e) => {
          const n = Number.parseInt(e.target.value, 10);
          act({ type: 'setManualScore', ability, value: Number.isNaN(n) ? null : n });
        }}
        className="num h-11 w-20 rounded-[var(--radius-input)] border border-hairline bg-plaque px-2 text-center text-on-surface"
      />
    );
  } else {
    control = (
      <span className="flex items-center gap-2">
        <Button
          tone="secondary"
          aria-label={t.crLower(t.abilityAbbr[ability])}
          title={t.crLower(t.abilityAbbr[ability])}
          disabled={!s.canLower.includes(ability)}
          onClick={() => {
            act({ type: 'stepPointBuy', ability, delta: -1 });
            onFocus();
          }}
        >
          <Minus size={16} aria-hidden="true" />
        </Button>
        <span className="num w-8 text-center text-[15px] font-bold tabular-nums">{base ?? '—'}</span>
        <Button
          tone="secondary"
          aria-label={t.crRaise(t.abilityAbbr[ability])}
          title={t.crRaise(t.abilityAbbr[ability])}
          disabled={!s.canRaise.includes(ability)}
          onClick={() => {
            act({ type: 'stepPointBuy', ability, delta: 1 });
            onFocus();
          }}
        >
          <Plus size={16} aria-hidden="true" />
        </Button>
      </span>
    );
  }
  return (
    <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5" data-ability={ability}>
      <button type="button" onClick={onFocus} className="flex min-h-9 min-w-[150px] flex-1 items-baseline gap-2 text-left sm:flex-none">
        <span className="text-[13px] font-bold tracking-[1.5px] text-on-surface-variant">{t.abilityAbbr[ability]}</span>
        <span className="text-[12px] text-text-muted">{t.abilities[ability]}</span>
      </button>
      <span className="order-last w-full sm:order-none sm:w-auto">{control}</span>
      <span className="ml-auto flex items-baseline gap-3" data-field={`score-${ability}`}>
        {spread ? <span className="num text-[12px] font-bold text-gold">{signed(spread)}</span> : null}
        <span className={cx('font-display text-[22px] tabular-nums', total === undefined && 'text-text-muted')}>{total ?? '—'}</span>
        <span className="num w-7 text-right font-bold tabular-nums">{total === undefined ? '—' : signed(abilityModifier(total))}</span>
      </span>
    </div>
  );
}

/** A la derecha, arriba: la explicación de lo último que se tocó, con la misma
 *  ficha que el Códice. */
function DetailPanel({ focus, view, catalog, lang, t }: { focus: Focus; view: CreationView; catalog: Catalog; lang: Lang; t: Texts }) {
  const CATEGORY = {
    race: 'races',
    lineage: 'lineages',
    class: 'classes',
    background: 'backgrounds',
    feat: 'feats',
    weapon: 'weapons',
    spell: 'spells',
    // Un objeto del equipo puede ser arma, armadura o cualquier otra cosa.
    item: focus && catalog.weapons.some((w) => w.id === focus.id) ? 'weapons' : focus && catalog.armor.some((a) => a.id === focus.id) ? 'armor' : 'gear',
  } as const;
  const entry =
    focus && focus.kind !== 'ability' && focus.kind !== 'skill'
      ? codexEntries(CATEGORY[focus.kind], catalog, t, lang).find((e) => e.id === focus.id)
      : undefined;
  const detail = entry?.detail();

  let extra: ReactNode = null;
  if (focus?.kind === 'background') {
    // Elegir trasfondo es elegir su dote: acá se dice qué hace.
    const feat = catalog.backgrounds.find((b) => b.id === focus.id)?.originFeatId;
    const sections =
      typeof feat === 'string' ? codexEntries('feats', catalog, t, lang).find((e) => e.id === feat)?.detail().sections : undefined;
    const traits = sections?.flatMap((s) => s.traits) ?? [];
    if (traits.length > 0) {
      extra = (
        <div className="border-t border-hairline pt-3 text-[13.5px]">
          <Eyebrow className="mb-1.5">{t.crFeatDescription}</Eyebrow>
          <TraitList traits={traits} />
        </div>
      );
    }
  } else if (focus?.kind === 'weapon') {
    const mastery = view.class.weapons.find((w) => w.id === focus.id)?.mastery;
    if (mastery) {
      extra = (
        <div className="border-t border-hairline pt-3 text-[13.5px]">
          <TraitList traits={[{ name: catalogLabel('mastery', mastery), description: catalogLabel('masteryRule', mastery) }]} />
        </div>
      );
    }
  }

  const ability = focus?.kind === 'ability' ? (focus.id as AbilityId) : null;
  const skills = [...view.proficiencies.classSkills.options, ...view.proficiencies.speciesSkills.options];
  const skill = focus?.kind === 'skill' ? skills.find((o) => o.id === focus.id) : undefined;
  // Orden Divina y Orden Primordial traen sus opciones dentro del rasgo: no
  // están en el catálogo de dotes, y su descripción la da el motor.
  const inlineOption =
    focus?.kind === 'feat' && !entry ? view.class.featureSlots.flatMap((s) => s.options).find((o) => o.id === focus.id) : undefined;
  return (
    <section className="card flex flex-col gap-2.5 p-4" aria-live="polite" data-field="creation-detail">
      {ability ? (
        <div key={ability} className="step-in flex flex-col gap-2.5">
          <h2 className="font-display text-[18px] text-on-surface">{t.abilities[ability]}</h2>
          <p className="border-t border-hairline pt-3 text-[13.5px] leading-[1.55]">{view.scores.descriptions[ability]}</p>
        </div>
      ) : skill ? (
        <div key={skill.id} className="step-in flex flex-col gap-2.5">
          <h2 className="font-display text-[18px] text-on-surface">{skill.label}</h2>
          <dl className="flex flex-col gap-1 border-t border-hairline pt-3 text-[12.5px]">
            {[
              [t.crSkillAbility, skill.ability ? t.abilities[skill.ability] : ''],
              [t.crSkillBase, signed(skill.base)],
              [t.crSkillProficient, signed(skill.withProficiency)],
            ].map(([label, value]) => (
              <div key={label} className="flex gap-2">
                <dt className="text-text-muted">{label}</dt>
                <dd className="text-on-surface">{value}</dd>
              </div>
            ))}
          </dl>
        </div>
      ) : inlineOption ? (
        <div key={inlineOption.id} className="step-in flex flex-col gap-2.5">
          <h2 className="font-display text-[18px] text-on-surface">{inlineOption.name}</h2>
          <p className="border-t border-hairline pt-3 text-[13.5px] leading-[1.55]">{inlineOption.description}</p>
        </div>
      ) : entry && detail ? (
        <div key={`${focus!.kind}-${entry.id}`} className="step-in flex flex-col gap-2.5">
          <div className="flex items-center justify-between gap-2.5">
            <h2 className="font-display text-[18px] text-on-surface">{entry.name}</h2>
            <SourceTag source={entry.source} t={t} />
          </div>
          {entry.subtitle && <p className="text-[12.5px] text-on-surface-variant">{entry.subtitle}</p>}
          <DetailBody detail={detail} />
          {extra}
        </div>
      ) : (
        <p className="text-[13px] text-text-muted">{t.luDetailEmpty}</p>
      )}
    </section>
  );
}

/** «Así queda», según lo que cada paso mueve. Todo sale de la ficha que
 *  compila el motor con el borrador; acá solo se elige qué mostrar. */
function afterRows(step: StepId, view: CreationView, sheet: ComputedSheet, catalog: Catalog, t: Texts): AfterRow[] {
  const d = view.draft;
  const sc = sheet.spellcasting;
  const hp: AfterRow = {
    label: t.luRowMaxHp,
    to: sheet.maxHp,
    gold: true,
    // Sin Constitución asignada el máximo todavía no es el final.
    note: d.assignedScores?.constitution === undefined ? t.crHpWithoutCon : undefined,
  };
  switch (step) {
    case 'especie': {
      if (!d.raceId) return [];
      const known = sheet.innateSpells.map((s) => s.name);
      return [
        { label: t.codexSpeed, to: t.codexFeet(sheet.speed) },
        ...(sheet.darkvision ? [{ label: t.codexDarkvision, to: t.codexFeet(sheet.darkvision) }] : []),
        ...(known.length > 0 ? [{ label: t.crSpellsGranted, to: known.join(', '), gold: true }] : []),
      ];
    }
    case 'clase':
      if (!d.classId) return [];
      return [
        hp,
        { label: t.codexSaves, to: sheet.savingThrowProficiencies.map((a) => t.abilityAbbr[a]).join(' · '), gold: true },
        ...(sc
          ? [
              { label: t.crCantrips, to: sc.cantripsKnown },
              { label: t.crSlotsFirst, to: sc.slotsByLevel[1] ?? 0 },
            ]
          : []),
        ...(sheet.weaponMasterySlots > 0 ? [{ label: t.crWeaponMastery, to: sheet.weaponMasterySlots }] : []),
      ];
    case 'trasfondo': {
      if (!d.backgroundId) return [];
      const bg = catalog.backgrounds.find((b) => b.id === d.backgroundId);
      const spread = ABILITIES.flatMap((a) => {
        const n = view.background.spread[a];
        return n ? [{ label: t.abilities[a], to: signed(n), gold: true }] : [];
      });
      const feat = typeof bg?.originFeatId === 'string' ? nameOf(catalog.feats, bg.originFeatId) : null;
      return [
        ...spread,
        { label: t.codexSkills, to: sheet.skillProficiencies.map((s) => catalogLabel('skill', s)).join(', ') },
        ...(sheet.toolProficiencies.length > 0
          ? [{ label: t.codexTools, to: sheet.toolProficiencies.map((x) => catalogLabel('tool', x)).join(', ') }]
          : []),
        ...(feat ? [{ label: t.codexOriginFeat, to: feat }] : []),
      ];
    }
    case 'caracteristicas':
      return [
        hp,
        { label: t.crArmorClass, to: sheet.armorClass },
        { label: t.crInitiative, to: signed(sheet.initiative) },
        ...(sc
          ? [
              { label: t.luRowSpellDc, to: sc.saveDc, gold: true },
              { label: t.crSpellAttack, to: signed(sc.attackBonus) },
            ]
          : []),
      ];
    case 'competencias':
      return [
        ...sheet.skillProficiencies.map((id) => ({
          label: catalogLabel('skill', id),
          to: signed(sheet.skillModifiers[id] ?? 0),
        })),
        { label: t.crPassivePerception, to: sheet.passivePerception },
        { label: t.crLanguages, to: sheet.languages.map((l) => catalogLabel('language', l)).join(', ') },
      ];
    case 'conjuros': {
      if (!sc) return [];
      const cs = view.spells.class;
      return [
        { label: t.luRowSpellDc, to: sc.saveDc },
        { label: t.crSpellAttack, to: signed(sc.attackBonus) },
        { label: t.crSlotsFirst, to: sc.slotsByLevel[1] ?? 0 },
        ...(cs ? [{ label: t.crPrepared, to: `${cs.chosenSpells.length} / ${cs.preparedCount}`, gold: true }] : []),
      ];
    }
    case 'equipo':
      return [
        { label: t.crGold, to: formatAmount(Math.max(view.equipment.goldLeftCp, 0), coinLabels(t)), gold: true },
        { label: t.crArmorClass, to: sheet.armorClass },
        ...sheet.attacks.map((a) => ({ label: a.name, to: `${signed(a.attackBonus)} · ${a.damage}` })),
      ];
    case 'detalles':
      return [
        { label: t.crIdentity, to: (d.name ?? '').trim() || t.crUnnamed },
        { label: t.luRowMaxHp, to: sheet.maxHp },
        { label: t.crArmorClass, to: sheet.armorClass },
      ];
    case 'revision':
      return [
        ...ABILITIES.map((a) => ({
          label: t.abilities[a],
          to: `${sheet.abilityScores[a] ?? 0} (${signed(sheet.abilityModifiers[a] ?? 0)})`,
        })),
        { label: t.luRowMaxHp, to: sheet.maxHp, gold: true },
        { label: t.crArmorClass, to: sheet.armorClass },
        { label: t.crSpeed, to: t.codexFeet(sheet.speed) },
        { label: t.crInitiative, to: signed(sheet.initiative) },
        { label: t.crProficiencyBonus, to: signed(sheet.proficiencyBonus) },
        ...(sc
          ? [
              { label: t.luRowSpellDc, to: sc.saveDc },
              { label: t.crSpellAttack, to: signed(sc.attackBonus) },
              { label: t.crSlotsFirst, to: sc.slotsByLevel[1] ?? 0 },
            ]
          : []),
        { label: t.crPassivePerception, to: sheet.passivePerception },
        { label: t.crGold, to: formatAmount(Math.max(view.equipment.goldLeftCp, 0), coinLabels(t)) },
      ];
  }
}
