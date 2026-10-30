import { useMemo, useState, type ReactNode } from 'react';
import { Check } from 'lucide-react';
import {
  computeSheet,
  levelUpView,
  rollDie,
  type AbilityId,
  type Catalog,
  type CharacterJson,
  type ComputedSheet,
  type LevelUpDraft,
  type LevelUpView,
} from '../engine';
import { codexEntries, fold, type CodexDetail } from '../codex/entries';
import { useLang, useTexts } from '../i18n/context';
import type { Lang, Texts } from '../i18n/texts';
import { characterHref, FLUTTER_HOME, navigate } from '../router';
import type { SheetModel } from '../sheet/model';
import { ABILITIES } from '../sheet/vocabulary';
import type { SheetWriter } from '../sheet/writer';
import { Button, ButtonLink } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { MarkdownText } from '../ui/MarkdownText';

type StepId = 'resumen' | 'pg' | 'subclase' | 'mejora' | 'revision';

/** Lo que muestra el panel de la derecha: la explicación de lo último que se
 *  tocó (clase, subclase, dote o rasgo ganado). */
type Focus = { kind: 'class' | 'subclass' | 'feat' | 'feature'; id: string } | null;

type OpenKey = keyof LevelUpView['open'];
const OPEN_KEYS: OpenKey[] = ['features', 'proficiencies', 'spellChoices', 'classSpells'];

/**
 * El asistente de subida de nivel de la ficha propia (`LevelUpScreen` de
 * Flutter, con el circuito rediseñado: una sola forma de elegir, un contador
 * por bloque y a la derecha qué es lo elegido y cómo queda la ficha).
 *
 * Toda regla es del motor (`levelUpView`, sobre `LevelUp`): acá solo se juntan
 * las decisiones en un borrador. Confirmar es la acción `levelUp`, que el
 * motor rechaza si la subida está incompleta. Las elecciones de rasgos,
 * competencias y conjuros todavía se hacen en Flutter: si esta subida las
 * pide, el resumen lo dice y manda allá.
 */
export function LevelUpWizard({ model, write }: { model: SheetModel; write: SheetWriter }) {
  const t = useTexts();
  const lang = useLang();
  const { character, sheet, catalog } = model;
  const raw = character as unknown as CharacterJson;

  const [draft, setDraft] = useState<LevelUpDraft>({ classId: character.classId });
  const [hpMode, setHpMode] = useState<'average' | 'roll'>('average');
  const [rolled, setRolled] = useState<number | null>(null);
  const [stepId, setStepId] = useState<StepId>('resumen');
  const [focus, setFocus] = useState<Focus>(null);
  const [featQuery, setFeatQuery] = useState('');

  const fullDraft = useMemo<LevelUpDraft>(
    () => ({ ...draft, hpRoll: hpMode === 'roll' ? rolled : null }),
    [draft, hpMode, rolled],
  );
  const view = useMemo(() => levelUpView(raw, catalog, fullDraft), [raw, catalog, fullDraft]);
  const after = useMemo(() => computeSheet(view.character, catalog), [view, catalog]);

  const steps: StepId[] = [
    'resumen',
    'pg',
    ...(view.needsSubclass ? (['subclase'] as const) : []),
    ...(view.isAsi ? (['mejora'] as const) : []),
    'revision',
  ];
  const index = Math.max(0, steps.indexOf(stepId));
  const current = steps[index]!;
  const openParts = OPEN_KEYS.filter((k) => view.open[k] > 0);

  const pendingOf = (s: StepId): string | null => {
    switch (s) {
      case 'resumen':
        if (openParts.length > 0) return t.luOpenBlocked(openParts.map((k) => t.luOpenParts[k]).join(t.luAnd));
        return view.unmetMulticlass ? t.luRequires(view.unmetMulticlass) : null;
      case 'pg':
        return hpMode === 'roll' && rolled === null ? t.luPendingHp : null;
      case 'subclase':
        return draft.subclassId ? null : t.luPendingSubclass;
      case 'mejora':
        if (view.asiComplete) return null;
        if (!draft.asiFeat) return t.luPendingImprove;
        return draft.featId ? t.luPendingFeatAbility : t.luPendingFeat;
      case 'revision':
        // Una subclase elegida acá puede traer su propia elección (la del
        // Corazón Salvaje): la revisión no confirma y dice por qué.
        return openParts.length > 0 ? t.luOpenBlocked(openParts.map((k) => t.luOpenParts[k]).join(t.luAnd)) : null;
    }
  };
  // Se llega a un paso si los de antes están completos, como en Flutter.
  const reachable = (i: number) => steps.slice(0, i).every((s) => pendingOf(s) === null);
  const pending = pendingOf(current);

  const className = (id: string) => view.classOptions.find((c) => c.id === id)?.name ?? id;
  const chooseClass = (id: string) => {
    setFocus({ kind: 'class', id });
    if (id === draft.classId) return;
    // Otra clase cambia qué niveles piden subclase o mejora: se empieza de nuevo.
    setDraft({ classId: id });
    setHpMode('average');
    setRolled(null);
  };

  const confirm = () => {
    const r = write.act({ type: 'levelUp', draft: fullDraft });
    if (!r) return;
    navigate(characterHref(character.id));
    write.notify(t.luDone(character.name, view.newLevel), { tone: 'success', undo: () => write.restore(r.before) });
  };

  let main: ReactNode;
  switch (current) {
    case 'resumen':
      main = <SummaryStep {...{ t, view, sheet, draft, chooseClass, openParts }} setFocus={setFocus} />;
      break;
    case 'pg':
      main = (
        <Block title={t.luHpTitle(view.newLevel)} status={<Status ready={pendingOf('pg') === null} t={t} />}>
          <div className="grid gap-2 sm:grid-cols-2" role="radiogroup" aria-label={t.luHpTitle(view.newLevel)}>
            <BigOption
              selected={hpMode === 'average'}
              title={t.luAverage}
              value={`+${view.hpIfAverage}`}
              detail={t.luAverageDetail(view.averageHp, view.hitDie)}
              onSelect={() => setHpMode('average')}
            />
            <BigOption
              selected={hpMode === 'roll'}
              title={t.luRoll}
              value={view.hpIfRoll === null ? t.luRange(...view.hpRange) : `+${view.hpIfRoll}`}
              muted={view.hpIfRoll === null}
              detail={rolled === null ? t.luRollPending(view.hitDie) : t.luRollDetail(rolled)}
              onSelect={() => {
                setHpMode('roll');
                if (rolled === null) setRolled(rollDie(view.hitDie));
              }}
            >
              {hpMode === 'roll' && (
                <div className="flex flex-wrap items-center gap-2.5 border-t border-hairline pt-3">
                  <Button tone="secondary" onClick={() => setRolled(rollDie(view.hitDie))}>
                    {t.luReroll}
                  </Button>
                  <label className="flex items-center gap-2 text-[12.5px] text-on-surface-variant">
                    {t.luRollManual(view.hitDie)}
                    <input
                      type="number"
                      inputMode="numeric"
                      min={1}
                      max={view.hitDie}
                      value={rolled ?? ''}
                      onChange={(e) => {
                        const n = Number.parseInt(e.target.value, 10);
                        if (n >= 1 && n <= view.hitDie) setRolled(n);
                      }}
                      className="num h-9 w-16 rounded-[var(--radius-input)] border border-hairline bg-plaque px-2 text-center text-on-surface"
                    />
                  </label>
                </div>
              )}
            </BigOption>
          </div>
        </Block>
      );
      break;
    case 'subclase':
      main = (
        <Block title={t.luSubclassTitle} status={<Status ready={!!draft.subclassId} t={t} />}>
          <div className="flex max-h-[420px] flex-col gap-2 overflow-y-auto pr-1" role="radiogroup" aria-label={t.luSubclassTitle}>
            {view.subclassOptions.map((s) => (
              <Option
                key={s.id}
                selected={draft.subclassId === s.id}
                title={s.name}
                trailing={s.homebrew ? <Tag>{t.homebrewTag}</Tag> : undefined}
                onClick={() => {
                  setDraft((d) => ({ ...d, subclassId: s.id }));
                  setFocus({ kind: 'subclass', id: s.id });
                }}
              />
            ))}
          </div>
        </Block>
      );
      break;
    case 'mejora':
      main = <AsiStep {...{ t, view, draft, setDraft, sheet, after, featQuery, setFeatQuery, setFocus }} />;
      break;
    case 'revision':
      main = (
        <>
          <Block title={t.luReviewChosen}>
            <ReviewRow
              label={t.luReviewClass}
              value={t.luClassHint(className(draft.classId), view.newClassLevel, view.hitDie)}
              onChange={() => setStepId('resumen')}
              t={t}
            />
            <ReviewRow
              label={t.luRowHp}
              value={t.luReviewHp(hpMode === 'roll' && view.hpIfRoll !== null ? view.hpIfRoll : view.hpIfAverage, hpMode === 'average')}
              onChange={() => setStepId('pg')}
              t={t}
            />
            {view.needsSubclass && (
              <ReviewRow
                label={t.luRowSubclass}
                value={view.subclassOptions.find((s) => s.id === draft.subclassId)?.name ?? ''}
                onChange={() => setStepId('subclase')}
                t={t}
              />
            )}
            {view.isAsi && (
              <ReviewRow
                label={t.luRowAsi}
                value={[
                  draft.asiFeat ? view.featOptions.find((f) => f.id === draft.featId)?.name : null,
                  ...[draft.abilityA, draft.abilityB].filter((a): a is AbilityId => !!a).map((a) => t.abilities[a]),
                ]
                  .filter(Boolean)
                  .join(' · ')}
                onChange={() => setStepId('mejora')}
                t={t}
              />
            )}
          </Block>
          {view.gainedFeatures.length > 0 && (
            <Block title={t.luReviewAuto}>
              {view.gainedFeatures.map((f) => (
                <div key={f.name} className="flex items-center justify-between gap-3 border-t border-hairline py-2.5 first:border-t-0">
                  <span className="font-medium">{f.name}</span>
                  <Status auto t={t} />
                </div>
              ))}
            </Block>
          )}
        </>
      );
      break;
  }

  return (
    <div className="flex min-h-full flex-col gap-4" data-page="level-up">
      <header className="flex flex-col gap-3">
        <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
          <h1 className="font-display text-[24px] text-on-surface">{t.luTitle(view.newLevel)}</h1>
          <span className="text-[13px] text-on-surface-variant">
            {t.luProgress(className(draft.classId), view.newClassLevel - 1, view.newClassLevel)}
          </span>
        </div>
        <nav aria-label={t.luStepsLabel}>
          <ol className="flex flex-wrap gap-1.5">
            {steps.map((s, i) => {
              const done = i < index;
              const cur = i === index;
              return (
                <li key={s}>
                  <button
                    type="button"
                    aria-current={cur ? 'step' : undefined}
                    disabled={!reachable(i)}
                    onClick={() => setStepId(s)}
                    className={cx(
                      'flex items-center gap-2 rounded-[var(--radius-pill)] border py-1.5 pr-3 pl-1.5 text-[13px] disabled:cursor-default',
                      cur ? 'border-gold bg-gold-soft font-medium text-gold' : 'border-hairline text-on-surface-variant',
                    )}
                  >
                    <span
                      aria-hidden="true"
                      className={cx(
                        'flex h-[22px] w-[22px] items-center justify-center rounded-full text-[12px] font-bold',
                        cur ? 'bg-gold text-on-primary' : done ? 'bg-gold-soft text-gold' : 'border border-hairline bg-plaque',
                      )}
                    >
                      {done ? <Check size={12} strokeWidth={3} /> : i + 1}
                    </span>
                    {t.luSteps[s]}
                  </button>
                </li>
              );
            })}
          </ol>
        </nav>
      </header>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_360px]">
        <div className="flex min-w-0 flex-col gap-4">{main}</div>
        <aside className="flex min-w-0 flex-col gap-4">
          <DetailPanel focus={focus} view={view} catalog={catalog} lang={lang} t={t} />
          <AfterPanel before={sheet} after={after} t={t} />
        </aside>
      </div>

      {/* Una tarjeta más, flotando al pie: con fondo, filete y radio como las
          de arriba, y despegada del borde. Una franja a sangre se leía como
          parte de otra pantalla. En un teléfono el mensaje va arriba y los
          dos botones se reparten el ancho. */}
      <footer className="card sticky bottom-3 mt-auto flex flex-wrap items-center gap-x-4 gap-y-2.5 px-4 py-3">
        {(pending ?? (current === 'revision' ? t.luConfirmHint : null)) && (
          <span className="min-w-0 flex-[1_1_240px] text-[13px] text-on-surface-variant" role="status">
            {pending ?? t.luConfirmHint}
          </span>
        )}
        <span className="ml-auto flex w-full gap-2 sm:w-auto">
          {index === 0 ? (
            <ButtonLink tone="secondary" href={characterHref(character.id)} internal className="flex-1 sm:flex-none">
              {t.cancel}
            </ButtonLink>
          ) : (
            <Button tone="secondary" className="flex-1 sm:flex-none" onClick={() => setStepId(steps[index - 1]!)}>
              {t.luBack}
            </Button>
          )}
          {current === 'revision' ? (
            <Button className="flex-[2] sm:flex-none" disabled={!view.complete} onClick={confirm}>
              {t.luConfirm(view.newLevel)}
            </Button>
          ) : (
            <Button
              className="flex-[2] sm:flex-none"
              disabled={pending !== null}
              onClick={() => setStepId(steps[index + 1]!)}
            >
              {index === 0 ? t.luStart : t.luContinue}
            </Button>
          )}
        </span>
      </footer>
    </div>
  );
}

/** El primer paso: en qué clase se sube y qué trae el nivel. */
function SummaryStep({
  t,
  view,
  sheet,
  draft,
  chooseClass,
  openParts,
  setFocus,
}: {
  t: Texts;
  view: LevelUpView;
  sheet: ComputedSheet;
  draft: LevelUpDraft;
  chooseClass: (id: string) => void;
  openParts: OpenKey[];
  setFocus: (f: Focus) => void;
}) {
  // La actual primero, después las que se pueden tomar y al final las que no.
  const classes = [...view.classOptions].sort(
    (a, b) =>
      Number(b.id === draft.classId) - Number(a.id === draft.classId) || Number(a.unmet !== null) - Number(b.unmet !== null),
  );
  return (
    <>
      <Block title={t.luWhichClass} status={<Status ready={view.unmetMulticlass === null} t={t} />}>
        <div
          role="radiogroup"
          aria-label={t.luWhichClass}
          className="grid auto-cols-[200px] grid-flow-col gap-2 overflow-x-auto pb-2"
        >
          {classes.map((c) => {
            const level = sheet.classLevels[c.id];
            return (
              <Option
                key={c.id}
                selected={draft.classId === c.id}
                disabled={c.unmet !== null}
                title={c.name}
                detail={
                  c.unmet !== null
                    ? t.luRequires(c.unmet)
                    : level
                      ? t.luClassHint(c.name, level + 1, c.hitDie)
                      : t.luMulticlassHint(c.hitDie)
                }
                onClick={() => chooseClass(c.id)}
              />
            );
          })}
        </div>
      </Block>

      {openParts.length > 0 && (
        <section className="card flex flex-col items-start gap-3 p-4" data-field="level-up-blocked">
          <p className="text-[14px]">{t.luOpenBlocked(openParts.map((k) => t.luOpenParts[k]).join(t.luAnd))}</p>
          <ButtonLink tone="soft" href={FLUTTER_HOME}>
            {t.luOpenInFlutter}
          </ButtonLink>
        </section>
      )}

      <Block title={t.luWhatComes(view.newLevel)}>
        <SummaryRow label={t.luRowHp} status={<Status ready={false} t={t} />} />
        {view.needsSubclass && <SummaryRow label={t.luRowSubclass} status={<Status ready={false} t={t} />} />}
        {view.isAsi && <SummaryRow label={t.luRowAsi} status={<Status ready={false} t={t} />} />}
        {view.gainedFeatures.map((f) => (
          <SummaryRow
            key={f.name}
            label={f.name}
            status={<Status auto t={t} />}
            onClick={() => setFocus({ kind: 'feature', id: f.name })}
          />
        ))}
      </Block>
    </>
  );
}

/** Mejora de característica o dote, con el +1 de los dones épicos. */
function AsiStep({
  t,
  view,
  draft,
  setDraft,
  sheet,
  after,
  featQuery,
  setFeatQuery,
  setFocus,
}: {
  t: Texts;
  view: LevelUpView;
  draft: LevelUpDraft;
  setDraft: (f: (d: LevelUpDraft) => LevelUpDraft) => void;
  sheet: ComputedSheet;
  after: ComputedSheet;
  featQuery: string;
  setFeatQuery: (q: string) => void;
  setFocus: (f: Focus) => void;
}) {
  const plusTwo = draft.asiPlusTwo !== false;
  const choice = view.featAbilityChoice;
  // Cuántas características se eligen: una con +2 o con la dote, dos con +1.
  const single = draft.asiFeat || plusTwo;
  const chosen = [draft.abilityA, draft.abilityB].filter((a): a is AbilityId => !!a);
  const pick = (a: AbilityId) =>
    setDraft((d) => {
      if (single) return { ...d, abilityA: a, abilityB: null };
      if (d.abilityA === a) return { ...d, abilityA: d.abilityB ?? null, abilityB: null };
      if (d.abilityB === a) return { ...d, abilityB: null };
      return d.abilityA ? { ...d, abilityB: a } : { ...d, abilityA: a };
    });
  const abilityOptions = (allowed: readonly AbilityId[]) => (
    <div className="grid gap-2 sm:grid-cols-3">
      {allowed.map((a) => {
        const on = chosen.includes(a);
        return (
          <Option
            key={a}
            multi={!single}
            selected={on}
            title={t.abilities[a]}
            detail={
              on ? `${sheet.abilityScores[a] ?? 0} → ${after.abilityScores[a] ?? 0}` : String(sheet.abilityScores[a] ?? 0)
            }
            onClick={() => pick(a)}
          />
        );
      })}
    </div>
  );

  // Sin tildes ni mayúsculas, como el Códice, y por palabras sueltas: «dos
  // armas» encuentra «Combatiente con Dos Armas» y «combatiente fuerza», su
  // variante de Fuerza.
  const words = fold(featQuery).split(/\s+/).filter(Boolean);
  const feats = view.featOptions.filter((f) => {
    const name = fold(f.name);
    return words.every((w) => name.includes(w));
  });

  return (
    <>
      <Block title={t.luAsiTitle} status={<Status ready t={t} />}>
        <div className="grid gap-2 sm:grid-cols-2" role="radiogroup" aria-label={t.luAsiTitle}>
          <Option
            selected={!draft.asiFeat}
            title={t.luAsiImprove}
            detail={t.luAsiImproveHint}
            onClick={() => setDraft((d) => ({ ...d, asiFeat: false, featId: null, abilityA: null, abilityB: null }))}
          />
          <Option
            selected={!!draft.asiFeat}
            title={t.luAsiFeat}
            detail={t.luAsiFeatHint}
            onClick={() => setDraft((d) => ({ ...d, asiFeat: true, abilityA: null, abilityB: null }))}
          />
        </div>
      </Block>

      {!draft.asiFeat ? (
        <>
          <Block title={t.luSplitTitle} status={<Status ready t={t} />}>
            <div className="grid gap-2 sm:grid-cols-2" role="radiogroup" aria-label={t.luSplitTitle}>
              <Option
                selected={plusTwo}
                title={t.luPlusTwo}
                onClick={() => setDraft((d) => ({ ...d, asiPlusTwo: true, abilityA: null, abilityB: null }))}
              />
              <Option
                selected={!plusTwo}
                title={t.luPlusOneOne}
                onClick={() => setDraft((d) => ({ ...d, asiPlusTwo: false, abilityA: null, abilityB: null }))}
              />
            </div>
          </Block>
          <Block
            title={single ? t.luWhichAbility : t.luWhichAbilities}
            status={<Status ready={view.asiComplete} count={[chosen.length, single ? 1 : 2]} t={t} />}
          >
            {abilityOptions(ABILITIES)}
          </Block>
        </>
      ) : (
        <>
          <Block title={t.luFeatTitle} status={<Status ready={!!draft.featId} t={t} />}>
            <div className="flex items-center gap-3">
              <input
                type="search"
                autoComplete="off"
                aria-label={t.luFeatSearch}
                placeholder={t.luFeatSearch}
                value={featQuery}
                onChange={(e) => setFeatQuery(e.target.value)}
                className="h-9 min-w-0 flex-1 rounded-[var(--radius-pill)] border border-hairline bg-plaque px-4 text-[13px] text-on-surface placeholder:text-text-muted"
              />
              <span className="text-[12.5px] whitespace-nowrap text-on-surface-variant">{t.luFeatCount(feats.length)}</span>
            </div>
            {feats.length === 0 ? (
              <p className="py-4 text-[13px] text-text-muted">{t.luNoFeatMatch(featQuery.trim())}</p>
            ) : (
              <div className="flex h-[300px] flex-col gap-2 overflow-y-auto pr-1" role="radiogroup" aria-label={t.luFeatTitle}>
                {feats.map((f) => (
                  <Option
                    key={f.id}
                    selected={draft.featId === f.id}
                    disabled={f.unmet !== null}
                    title={f.name}
                    detail={f.unmet !== null ? t.luRequires(f.unmet) : undefined}
                    trailing={f.homebrew ? <Tag>{t.homebrewTag}</Tag> : undefined}
                    onClick={() => {
                      setDraft((d) => ({ ...d, featId: f.id, abilityA: null, abilityB: null }));
                      setFocus({ kind: 'feat', id: f.id });
                    }}
                  />
                ))}
              </div>
            )}
          </Block>
          {choice && (
            <Block title={t.luFeatAbilityTitle(choice.amount)} status={<Status ready={view.asiComplete} t={t} />}>
              {abilityOptions(choice.allowed)}
            </Block>
          )}
        </>
      )}
    </>
  );
}

/** A la derecha, arriba: qué es lo último que se tocó. Una dote o una
 *  subclase se describen con la misma ficha que el Códice (`codexEntries`):
 *  las dotes del catálogo no traen `description`, su texto vive en los
 *  rasgos de sus efectos, y armarlo dos veces dejaría dos versiones. */
function DetailPanel({
  focus,
  view,
  catalog,
  lang,
  t,
}: {
  focus: Focus;
  view: LevelUpView;
  catalog: Catalog;
  lang: Lang;
  t: Texts;
}) {
  let title: string | null = null;
  let meta: string | null = null;
  let body: string | null = null;
  let detail: CodexDetail | null = null;
  let homebrew = false;
  if (focus?.kind === 'class') {
    const c = view.classOptions.find((o) => o.id === focus.id);
    title = c?.name ?? null;
    meta = c ? (c.unmet !== null ? t.luRequires(c.unmet) : `d${c.hitDie}`) : null;
  } else if (focus?.kind === 'subclass' || focus?.kind === 'feat') {
    const entry = codexEntries(focus.kind === 'feat' ? 'feats' : 'subclasses', catalog, t, lang).find((e) => e.id === focus.id);
    title = entry?.name ?? null;
    detail = entry?.detail() ?? null;
    if (focus.kind === 'feat') {
      const f = view.featOptions.find((o) => o.id === focus.id);
      meta = f && f.unmet !== null ? t.luRequires(f.unmet) : null;
      homebrew = !!f?.homebrew;
    } else {
      homebrew = !!view.subclassOptions.find((o) => o.id === focus.id)?.homebrew;
    }
  } else if (focus?.kind === 'feature') {
    const f = view.gainedFeatures.find((o) => o.name === focus.id);
    title = f?.name ?? null;
    body = f?.description ?? null;
  }
  return (
    <section className="card flex flex-col gap-2.5 p-4" aria-live="polite" data-field="level-up-detail">
      {title === null ? (
        <p className="text-[13px] text-text-muted">{t.luDetailEmpty}</p>
      ) : (
        <>
          <div className="flex items-center justify-between gap-2.5">
            <h2 className="font-display text-[18px] text-on-surface">{title}</h2>
            {homebrew && <Tag>{t.homebrewTag}</Tag>}
          </div>
          {meta && <p className="text-[12.5px] text-crimson">{meta}</p>}
          {detail && (
            <div className="flex flex-col gap-3 border-t border-hairline pt-3 text-[13.5px]">
              {detail.facts.flat().length > 0 && (
                <dl className="flex flex-col gap-1 text-[12.5px]">
                  {detail.facts.flat().map((f) => (
                    <div key={f.label} className="flex gap-2">
                      <dt className="text-text-muted">{f.label}</dt>
                      <dd className="text-on-surface">{f.value}</dd>
                    </div>
                  ))}
                </dl>
              )}
              {detail.prose && <p className="leading-[1.55] whitespace-pre-line">{detail.prose}</p>}
              {detail.sections.map((sec) => (
                <section key={sec.title}>
                  <Eyebrow className="mb-1.5">{sec.title}</Eyebrow>
                  <ul className="flex flex-col gap-2">
                    {sec.traits.map((tr, i) => (
                      <li key={`${tr.name}-${i}`}>
                        <p className="font-medium">{tr.name}</p>
                        {tr.description && (
                          <p className="mt-0.5 leading-[1.5] whitespace-pre-line text-on-surface-variant">{tr.description}</p>
                        )}
                      </li>
                    ))}
                  </ul>
                </section>
              ))}
            </div>
          )}
          {body && (
            <div className="border-t border-hairline pt-3 text-[13.5px]">
              <MarkdownText text={body} />
            </div>
          )}
        </>
      )}
    </section>
  );
}

/** A la derecha, abajo: lo que cambia en la ficha, de las dos fichas del
 *  motor. Solo se comparan números; ninguno se calcula acá. */
function AfterPanel({ before, after, t }: { before: ComputedSheet; after: ComputedSheet; t: Texts }) {
  const rows: { label: string; from: number; to: number }[] = [
    { label: t.luRowLevel, from: before.level, to: after.level },
    { label: t.luRowMaxHp, from: before.maxHp, to: after.maxHp },
    ...ABILITIES.filter((a) => before.abilityScores[a] !== after.abilityScores[a]).map((a) => ({
      label: t.abilities[a],
      from: before.abilityScores[a] ?? 0,
      to: after.abilityScores[a] ?? 0,
    })),
    ...(before.proficiencyBonus !== after.proficiencyBonus
      ? [{ label: t.luRowProf, from: before.proficiencyBonus, to: after.proficiencyBonus }]
      : []),
    ...(after.spellcasting
      ? [
          { label: t.luRowSpellDc, from: before.spellcasting?.saveDc ?? 0, to: after.spellcasting.saveDc },
          { label: t.luRowPrepared, from: before.spellcasting?.preparedCount ?? 0, to: after.spellcasting.preparedCount },
        ]
      : []),
  ];
  return (
    <section className="card p-4" aria-labelledby="lu-after" data-field="level-up-after">
      <Eyebrow className="mb-2">
        <span id="lu-after">{t.luAfterHeading}</span>
      </Eyebrow>
      <dl className="plaque divide-y divide-hairline px-3.5 py-0.5 text-[13px]">
        {rows.map((r) => (
          <div key={r.label} className="flex items-baseline justify-between gap-3 py-2">
            <dt>{r.label}</dt>
            <dd className="num font-bold tabular-nums">
              {r.from === r.to ? (
                r.to
              ) : (
                <>
                  {r.from} → <span className="text-gold">{r.to}</span>
                </>
              )}
            </dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

/** Un bloque de elección: título, un solo contador y las opciones. */
function Block({ title, status, children }: { title: string; status?: ReactNode; children: ReactNode }) {
  return (
    <section className="card flex flex-col gap-3 p-4">
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-display text-[16px] text-on-surface">{title}</h2>
        {status}
      </div>
      {children}
    </section>
  );
}

/** Los tres estados de un bloque, y ningún otro: falta (con la cuenta si la
 *  hay), listo y automático. */
function Status({ ready = false, auto = false, count, t }: { ready?: boolean; auto?: boolean; count?: [number, number]; t: Texts }) {
  const pill = 'inline-flex items-center gap-1.5 rounded-[var(--radius-pill)] border border-hairline px-[9px] py-[2px] text-[11px] whitespace-nowrap';
  if (auto) return <span className={cx(pill, 'bg-plaque text-text-muted')}>{t.luAuto}</span>;
  if (ready)
    return (
      <span className={cx(pill, 'bg-gold-soft text-gold')}>
        <Check size={11} strokeWidth={3} aria-hidden="true" />
        {t.luReady}
      </span>
    );
  return (
    <span className={cx(pill, 'bg-plaque text-on-surface')}>
      <span aria-hidden="true" className="h-[7px] w-[7px] rounded-full border-[1.5px] border-current" />
      {count ? t.luCount(count[0], count[1]) : t.luPending}
    </span>
  );
}

/** La única forma de elegir: círculo si es una, cuadrado si son varias. */
function Option({
  selected,
  multi = false,
  disabled = false,
  title,
  detail,
  trailing,
  onClick,
}: {
  selected: boolean;
  multi?: boolean;
  disabled?: boolean;
  title: string;
  detail?: string;
  trailing?: ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role={multi ? 'checkbox' : 'radio'}
      aria-checked={selected}
      disabled={disabled}
      onClick={onClick}
      className={cx(
        'flex min-h-12 w-full items-center gap-3 rounded-[var(--radius-card)] border px-3.5 py-2.5 text-left text-on-surface disabled:cursor-default',
        selected ? 'border-gold bg-gold-soft' : 'border-hairline bg-plaque',
      )}
    >
      <span
        aria-hidden="true"
        className={cx(
          'flex h-[18px] w-[18px] shrink-0 items-center justify-center border-[1.5px]',
          multi ? 'rounded-[5px]' : 'rounded-full',
          selected ? (multi ? 'border-gold bg-gold' : 'border-gold') : 'border-text-muted',
          disabled && 'opacity-45',
        )}
      >
        {selected &&
          (multi ? (
            <Check size={12} strokeWidth={3.5} className="text-on-primary" />
          ) : (
            <span className="h-2 w-2 rounded-full bg-gold" />
          ))}
      </span>
      <span className="min-w-0 flex-1">
        <span className={cx('block font-medium', disabled && 'opacity-45')}>{title}</span>
        {detail && <span className="mt-0.5 block text-[12.5px] text-on-surface-variant">{detail}</span>}
      </span>
      {trailing}
    </button>
  );
}

/** La opción de los PG: lo que suma, en grande, y lo que hace falta debajo. */
function BigOption({
  selected,
  title,
  value,
  detail,
  muted = false,
  onSelect,
  children,
}: {
  selected: boolean;
  title: string;
  value: string;
  detail: string;
  muted?: boolean;
  onSelect: () => void;
  children?: ReactNode;
}) {
  return (
    <div
      className={cx(
        'flex flex-col gap-3.5 rounded-[var(--radius-card)] border px-4 py-3.5',
        selected ? 'border-gold bg-gold-soft' : 'border-hairline bg-plaque',
      )}
    >
      <button type="button" role="radio" aria-checked={selected} onClick={onSelect} className="flex flex-col gap-3.5 text-left">
        <span className="flex items-center gap-3 font-medium text-on-surface">
          <span
            aria-hidden="true"
            className={cx(
              'flex h-[18px] w-[18px] items-center justify-center rounded-full border-[1.5px]',
              selected ? 'border-gold' : 'border-text-muted',
            )}
          >
            {selected && <span className="h-2 w-2 rounded-full bg-gold" />}
          </span>
          {title}
        </span>
        <span>
          <span
            className={cx(
              'block text-[28px] leading-[1.05] font-bold tabular-nums',
              muted ? 'text-text-muted' : selected ? 'text-gold' : 'text-on-surface',
            )}
            data-field="hp-value"
          >
            {value}
          </span>
          <span className="block text-[12.5px] text-on-surface-variant">{detail}</span>
        </span>
      </button>
      {children}
    </div>
  );
}

function SummaryRow({ label, status, onClick }: { label: string; status: ReactNode; onClick?: () => void }) {
  return (
    <div className="flex items-center justify-between gap-3 border-t border-hairline py-2.5 first:border-t-0">
      {onClick ? (
        <button type="button" onClick={onClick} className="text-left font-medium text-on-surface hover:text-gold">
          {label}
        </button>
      ) : (
        <span className="font-medium">{label}</span>
      )}
      {status}
    </div>
  );
}

function ReviewRow({ label, value, onChange, t }: { label: string; value: string; onChange: () => void; t: Texts }) {
  return (
    <div className="flex items-center gap-3.5 border-t border-hairline py-2.5 first:border-t-0">
      <span className="min-w-0 flex-1">
        <span className="block font-medium">{label}</span>
        <span className="mt-0.5 block text-[12.5px] text-on-surface-variant">{value}</span>
      </span>
      <Button tone="secondary" onClick={onChange}>
        {t.luChange}
      </Button>
    </div>
  );
}

function Tag({ children }: { children: ReactNode }) {
  return (
    <span className="shrink-0 rounded-[var(--radius-pill)] border border-hairline px-1.5 text-[10px] text-on-surface-variant">
      {children}
    </span>
  );
}
