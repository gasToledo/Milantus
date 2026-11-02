import { useMemo, useState, type ReactNode } from 'react';
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
import { useSheetCatalog } from '../api/queries';
import { codexEntries, type CodexEntry } from '../codex/entries';
import { RosterFooter } from '../dashboard/RosterPanel';
import {
  abilityModifier,
  catalogLabel,
  computeSheet,
  creationView,
  vocabularyLabel,
  type AbilityId,
  type Catalog,
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
import { navigate, rosterHref } from '../router';
import { signed } from '../sheet/format';
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
  WizardFooter,
  type AfterRow,
} from '../ui/wizard';
import type { Account } from '../api/client';

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

// ponytail: el último paso construido. Competencias, Conjuros y Equipo llegan
// con 5d3, y Detalles, Revisión y el alta con 5d4; hasta entonces no se avanza
// más allá ni hay enlace a esta ruta.
const LAST_BUILT = STEPS.indexOf('caracteristicas');

/** Lo que explica el panel de la derecha: lo último que se tocó. */
type Focus = { kind: 'race' | 'lineage' | 'class' | 'background' | 'feat' | 'weapon' | 'ability'; id: string } | null;

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
export function CreationPage({ account }: { account: Account }) {
  const t = useTexts();
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  const [touched, setTouched] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const exit = () => {
    if (touched) setConfirming(true);
    else navigate(rosterHref());
  };
  const failed = catalog.queries.filter((q) => q.isError);
  return (
    <Shell
      panel={<SidebarBack href={rosterHref()} label={t.backToCharacters} onClick={(e) => { e.preventDefault(); exit(); }} />}
      footer={<RosterFooter account={account} />}
    >
      {catalog.data ? (
        <CreationWizard catalog={catalog.data} onExit={exit} onTouched={() => setTouched(true)} />
      ) : failed.length > 0 ? (
        <AppErrorView as="h1" title={t.crLoadError} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      ) : (
        <AppBusyLabel label={t.loading} />
      )}
      <AppDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={t.crDiscardTitle}
        description={t.crDiscardBody}
        actions={[
          { label: t.crKeepCreating },
          { label: t.crDiscard, primary: true, tone: 'crimson', onSelect: () => navigate(rosterHref()) },
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
function CreationWizard({ catalog, onExit, onTouched }: { catalog: Catalog; onExit: () => void; onTouched: () => void }) {
  const t = useTexts();
  const lang = useLang();
  const [draft, setDraft] = useState<CreationDraftJson>({});
  const [stepId, setStepId] = useState<StepId>('especie');
  const [focus, setFocus] = useState<Focus>(null);
  const view = useMemo(() => creationView(catalog, draft), [catalog, draft]);
  const sheet = useMemo(() => computeSheet(view.character, catalog), [view, catalog]);

  const act = (action: CreationAction) => {
    onTouched();
    setDraft(creationView(catalog, draft, action).draft);
  };

  const index = STEPS.indexOf(stepId);
  const pendingOf = (s: StepId) => view.pending.filter((p) => SECTIONS[s].includes(p.section));
  const reachable = (i: number) => i <= LAST_BUILT && STEPS.slice(0, i).every((s) => pendingOf(s).length === 0);
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
      ? index === LAST_BUILT
        ? t.crNextSoon
        : null
      : pending.length === 1
        ? pendingText(pending[0]!, t)
        : t.crPendingMore(pendingText(pending[0]!, t).replace(/\.$/, ''), pending.length - 1);

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="creation">
      <header className="flex flex-col gap-3">
        <h1 className="font-display text-[24px] text-on-surface">{t.rosterCreate}</h1>
        <StepRail
          steps={STEPS.map((id) => ({ id, label: t.crSteps[id] }))}
          index={index}
          reachable={reachable}
          onSelect={(id) => go(id as StepId)}
          label={t.luStepsLabel}
          progress={t.crProgress(index + 1, STEPS.length, t.crSteps[stepId])}
        />
      </header>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="flex min-w-0 flex-col gap-4">
          {stepId === 'especie' && <SpeciesStep {...props} />}
          {stepId === 'clase' && <ClassStep {...props} />}
          {stepId === 'trasfondo' && <BackgroundStep {...props} />}
          {stepId === 'caracteristicas' && <ScoresStep {...props} />}
        </div>
        <aside className="flex min-w-0 flex-col gap-4">
          <DetailPanel focus={focus} view={view} catalog={catalog} lang={lang} t={t} />
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
          <Button tone="secondary" className="flex-1 sm:flex-none" onClick={() => go(STEPS[index - 1]!)}>
            {t.luBack}
          </Button>
        )}
        <Button
          className="flex-[2] sm:flex-none"
          disabled={pending.length > 0 || index >= LAST_BUILT}
          onClick={() => go(STEPS[index + 1]!)}
        >
          {t.luContinue}
        </Button>
      </WizardFooter>
    </div>
  );
}

function pendingText(p: CreationPending, t: Texts): string {
  return t.crPending[p.kind](p);
}

interface StepProps {
  t: Texts;
  lang: Lang;
  catalog: Catalog;
  view: CreationView;
  act: (action: CreationAction) => void;
  setFocus: (f: Focus) => void;
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
        <div className="flex flex-col gap-2.5" data-field="scores-matrix">
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
      </Block>
    </>
  );
}

/** Una fila de la matriz: una elección de una. El valor que ya tiene otra va
 *  en gris y tocarlo las intercambia (lo resuelve el motor). */
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
  } else if (method === 'pointBuy') {
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
  } else {
    control = (
      <span className="flex flex-wrap gap-1.5" role="radiogroup" aria-label={t.abilities[ability]}>
        {s.values.map((v) => {
          const on = base === v;
          return (
            <button
              key={v}
              type="button"
              role="radio"
              aria-checked={on}
              data-value={v}
              onClick={() => {
                act({ type: 'assignScore', ability, value: v });
                onFocus();
              }}
              className={cx(
                'num h-11 w-11 rounded-[var(--radius-nav)] border text-[15px] tabular-nums',
                on
                  ? 'border-gold bg-gold-soft font-bold text-gold'
                  : s.taken[ability].includes(v)
                    ? 'border-hairline bg-plaque text-text-muted'
                    : 'border-hairline bg-plaque text-on-surface',
              )}
            >
              {v}
            </button>
          );
        })}
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
  const CATEGORY = { race: 'races', lineage: 'lineages', class: 'classes', background: 'backgrounds', feat: 'feats', weapon: 'weapons' } as const;
  const entry =
    focus && focus.kind !== 'ability' ? codexEntries(CATEGORY[focus.kind], catalog, t, lang).find((e) => e.id === focus.id) : undefined;
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
  return (
    <section className="card flex flex-col gap-2.5 p-4" aria-live="polite" data-field="creation-detail">
      {ability ? (
        <div key={ability} className="step-in flex flex-col gap-2.5">
          <h2 className="font-display text-[18px] text-on-surface">{t.abilities[ability]}</h2>
          <p className="border-t border-hairline pt-3 text-[13.5px] leading-[1.55]">{view.scores.descriptions[ability]}</p>
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
    default:
      return [];
  }
}
