import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { BookOpen, Check, LogOut, RotateCcw, ScrollText, Shield, Sparkles, Swords, User, X, type LucideIcon } from 'lucide-react';
import { useRoster, useSheetCatalog } from '../api/queries';
import { quizLocalize, quizRound, type Catalog, type CharacterJson, type QuizQuestion } from '../engine';
import { toRosterEntry, type RosterEntry } from '../dashboard/roster';
import { useLang, useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { Link, navigate, quizHref, setLeaveGuard } from '../router';
import { spellMeta, type SpellJson } from '../sheet/SpellList';
import { AppDialog } from '../ui/AppDialog';
import { Button, ButtonLink } from '../ui/Button';
import { cx } from '../ui/cx';
import { Medallion } from '../ui/Medallion';
import { ownPortrait } from '../ui/portrait';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';
import { TutorialGate } from '../ui/tutorials';

/** El id de la ronda de reglas generales en la URL (`/v2/quiz/reglas`). */
export const RULES_TARGET = 'reglas';

/**
 * El Quiz: rondas de hasta diez preguntas que arma el motor desde el catálogo
 * y la ficha. No se guarda nada: ni puntaje ni historial, y la ronda vive en
 * el estado del componente (recargar arranca otra).
 */
export function QuizPage({ target }: { target: string | null }) {
  const t = useTexts();
  const lang = useLang();
  const roster = useRoster();
  const catalog = useSheetCatalog(lang);

  const entries = useMemo(
    () =>
      roster.data && catalog.data
        ? roster.data.map(({ character, createdAt }) => toRosterEntry(character, createdAt, catalog.data!))
        : null,
    [roster.data, catalog.data],
  );

  const failed = [roster, ...catalog.queries].filter((q) => q.isError);
  if (failed.length > 0) {
    return <AppErrorView title={t.rosterErrorTitle} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  }
  if (!entries || !catalog.data) return <AppBusyLabel label={t.rosterLoading} />;
  if (target === null) return <Picker entries={entries} />;

  const own = target === RULES_TARGET ? null : entries.find((e) => e.character.id === target);
  // Un id que no está en tu lista (ajeno o inexistente) es la vista de siempre.
  if (target !== RULES_TARGET && !own) return <Notice title={t.notFoundTitleRoute} />;
  return <Round key={target} entry={own ?? null} catalog={catalog.data} />;
}

function Picker({ entries }: { entries: RosterEntry[] }) {
  const t = useTexts();
  return (
    <div className="flex flex-col gap-4">
      <TutorialGate tutorial="quiz" />
      <h1 className="font-display text-[26px] font-normal text-on-surface">{t.quizTitle}</h1>
      <p className="text-[14px] text-on-surface-variant">{t.quizIntro}</p>
      <ul className="grid grid-cols-1 gap-2.5 min-[700px]:grid-cols-2">
        {entries.map((entry) => (
          <li key={entry.character.id}>
            <PickLink href={quizHref(entry.character.id)} target={entry.character.id}>
              <Medallion
                name={entry.character.name}
                accent={entry.accent}
                size={44}
                portrait={ownPortrait(entry.character)}
              />
              <span className="min-w-0">
                <span className="block truncate text-[15px] font-semibold">{entry.character.name}</span>
                {/* La misma línea que la lista de personajes, con el nivel de
                    cada clase como en la lámina. */}
                <span className="block truncate text-[12px] text-text-muted">
                  {[entry.raceName, ...entry.classes.map((c) => `${c.name} ${c.level}`)].filter(Boolean).join(' · ')}
                </span>
              </span>
            </PickLink>
          </li>
        ))}
        <li>
          <PickLink href={quizHref(RULES_TARGET)} target={RULES_TARGET} gold>
            <span
              aria-hidden="true"
              className="flex size-11 shrink-0 items-center justify-center rounded-full border border-hairline bg-plaque text-gold"
            >
              <Sparkles size={20} />
            </span>
            <span className="min-w-0">
              <span className="block truncate text-[15px] font-semibold">{t.quizRules}</span>
              <span className="block truncate text-[12px] text-text-muted">{t.quizRulesSubtitle}</span>
            </span>
          </PickLink>
        </li>
      </ul>
    </div>
  );
}

function PickLink({ href, target, gold = false, children }: { href: string; target: string; gold?: boolean; children: ReactNode }) {
  return (
    <Link
      href={href}
      data-quiz-target={target}
      className={cx('pick card flex items-center gap-3 p-3.5 text-on-surface no-underline', gold && 'border-gold')}
    >
      {children}
    </Link>
  );
}

/** Una semilla nueva por ronda: la ronda no se repite aunque se vuelva a elegir. */
const newSeed = (): number => Math.floor(Math.random() * 0x7fffffff);

/** Un ícono por tema: el chip de la pregunta, las placas del resultado y la
 *  lista para repasar. */
const TOPIC_ICON: Record<QuizQuestion['topic'], LucideIcon> = {
  class: Shield,
  species: User,
  background: BookOpen,
  spells: Sparkles,
  equipment: Swords,
  rules: ScrollText,
};
const TOPICS = Object.keys(TOPIC_ICON) as QuizQuestion['topic'][];

/** Un acierto o un error ya contestado; `undefined` es la que falta. */
type Outcome = 'ok' | 'bad' | undefined;
const outcomes = (questions: QuizQuestion[], picks: number[]): Outcome[] =>
  questions.map((q, i) => (picks[i] === undefined ? undefined : picks[i] === q.answer ? 'ok' : 'bad'));

// El fondo de una opción respondida se tiñe apenas del color del veredicto,
// sobre la placa: sale de las variables, así vale en el tema claro.
const TINT_OK = 'bg-[color-mix(in_srgb,var(--verdant)_9%,var(--plaque))]';
const TINT_BAD = 'bg-[color-mix(in_srgb,var(--crimson)_9%,var(--plaque))]';

function Round({ entry, catalog }: { entry: RosterEntry | null; catalog: Catalog }) {
  const t = useTexts();
  const [seed, setSeed] = useState(newSeed);
  const character = (entry?.character as unknown as CharacterJson | undefined) ?? null;
  // La ronda se sortea una sola vez por semilla. El catálogo entra en la
  // cuenta para armarla la primera vez; si después cambia el idioma, no se
  // vuelve a sortear: se reescriben los textos de estas mismas preguntas.
  const roundId = `${entry?.character.id ?? RULES_TARGET}:${seed}`;
  const [trackedRound, setTrackedRound] = useState(roundId);
  const [held, setHeld] = useState<QuizQuestion[] | null>(null);
  if (trackedRound !== roundId) {
    setTrackedRound(roundId);
    setHeld(null);
  }
  const questions = useMemo(() => {
    if (held) return quizLocalize(held, catalog);
    return quizRound(character, catalog, seed);
  }, [held, catalog, character, seed]);
  useEffect(() => {
    if (held == null) setHeld(questions);
  }, [held, questions]);
  // Qué se contestó en cada pregunta (índice de la opción); `undefined` hasta tocar.
  const [picks, setPicks] = useState<number[]>([]);
  const [index, setIndex] = useState(0);

  const who = entry?.character.name ?? t.quizRules;
  // Salir a mitad de ronda pierde lo respondido: se pregunta antes. Sin nada
  // contestado, o con la ronda terminada, no hay qué perder.
  const playing = picks.length > 0 && index < questions.length;
  const [leaving, setLeaving] = useState<(() => void) | null>(null);
  useEffect(() => {
    if (!playing) return;
    setLeaveGuard((proceed) => setLeaving(() => proceed));
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener('beforeunload', warn);
    return () => {
      setLeaveGuard(null);
      window.removeEventListener('beforeunload', warn);
    };
  }, [playing]);

  const restart = () => {
    setSeed(newSeed());
    setPicks([]);
    setIndex(0);
  };

  if (questions.length === 0) return <Notice title={t.quizTitle} body={who} />;
  const results = outcomes(questions, picks);
  if (index >= questions.length) {
    return (
      <Result
        entry={entry}
        questions={questions}
        picks={picks}
        results={results}
        catalog={catalog}
        onAgain={restart}
      />
    );
  }

  const question = questions[index]!;
  const picked = picks[index];
  const last = index === questions.length - 1;
  const TopicIcon = TOPIC_ICON[question.topic];
  const answered = results.filter(Boolean).length;
  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-4">
      <div className="flex items-center gap-3">
        <Who entry={entry} />
        <span className="ml-auto font-display text-[20px] text-gold tabular-nums" data-quiz="progress">
          {index + 1}
          {/* El total, en chico: lo que se lee de un vistazo es dónde vas. */}
          <span className="text-[14px] text-text-muted"> / {questions.length}</span>
        </span>
      </div>
      <Segments
        results={results}
        current={index}
        label={t.quizProgress(index + 1, questions.length)}
      />
      {/* `key` remonta la tarjeta en cada pregunta: entra con `.step-in`. */}
      <section key={index} className="card step-in flex flex-col gap-3.5 p-5" data-quiz="question">
        <span className="inline-flex items-center gap-1.5 self-start rounded-[var(--radius-pill)] border border-gold bg-gold-soft px-2.5 py-0.5 text-[12px] text-gold">
          <TopicIcon size={13} aria-hidden="true" />
          {t.quizTopic[question.topic]}
        </span>
        <p className="font-display text-[21px] leading-[1.35] text-on-surface">{askOf(t, question, catalog, multiclassOf(entry))}</p>
        <Quote question={question} />
        <div className="flex flex-col gap-2">
          {question.options.map((label, i) => (
            <OptionButton
              key={i}
              letter={'ABCD'[i]!}
              label={label}
              state={
                picked === undefined ? 'open' : i === question.answer ? 'correct' : i === picked ? 'wrong' : 'dim'
              }
              onPick={() => setPicks((prev) => Object.assign([...prev], { [index]: i }))}
            />
          ))}
        </div>
        {picked !== undefined && <Verdict right={picked === question.answer} question={question} catalog={catalog} />}
      </section>
      <div className="flex flex-wrap items-center justify-between gap-2">
        {/* Abandonar pasa por la misma pregunta que cualquier otra salida;
            discreto, para no competir con «Siguiente». */}
        <button
          type="button"
          onClick={() => navigate(quizHref())}
          data-action="quiz-leave"
          className="flex min-h-10 items-center gap-1.5 rounded-[var(--radius-pill)] px-2.5 text-[14px] text-on-surface-variant hover:text-on-surface"
        >
          <LogOut size={16} aria-hidden="true" />
          {t.quizLeave}
        </button>
        {/* No avanza solo: leer la respuesta no puede irse de abajo del dedo. */}
        {picked !== undefined && (
          <Button shape="pill" onClick={() => setIndex(index + 1)} data-action="quiz-next">
            {last ? t.quizSeeResult : t.quizNext}
          </Button>
        )}
      </div>
      <AppDialog
        open={leaving !== null}
        onOpenChange={(open) => !open && setLeaving(null)}
        title={t.quizLeaveTitle}
        bare
        actions={[
          { label: t.quizLeave, tone: 'crimson', onSelect: () => leaving?.() },
          // La salida segura es la principal: el botón que salta a la vista no
          // es el que borra lo respondido.
          { label: t.quizKeepPlaying, primary: true },
        ]}
      >
        <div className="flex flex-col items-center gap-3.5 text-center">
          <span className="flex size-12 items-center justify-center rounded-full border border-crimson bg-plaque text-crimson">
            <LogOut size={24} strokeWidth={1.8} aria-hidden="true" />
          </span>
          <div className="flex flex-col gap-1.5">
            <h2 aria-hidden="true" className="font-display text-[20px] text-on-surface">
              {t.quizLeaveTitle}
            </h2>
            <p className="text-[14px] leading-normal text-on-surface-variant">{t.quizLeaveBody}</p>
          </div>
          {/* Lo que se pierde, a la vista. */}
          <div className="flex w-full flex-col items-center gap-2 rounded-[var(--radius-card)] border border-hairline bg-plaque px-3.5 py-3">
            <Dots results={results} />
            <span className="text-[13px] text-on-surface tabular-nums">
              {t.quizLeaveSummary(answered, results.filter((r) => r === 'ok').length)}
            </span>
          </div>
        </div>
      </AppDialog>
    </div>
  );
}

/** El personaje (o las reglas generales) arriba de la pregunta y del resultado. */
function Who({ entry }: { entry: RosterEntry | null }) {
  const t = useTexts();
  if (!entry) {
    return (
      <span className="flex min-w-0 items-center gap-3">
        <span
          aria-hidden="true"
          className="flex size-10 shrink-0 items-center justify-center rounded-full border border-gold bg-plaque text-gold"
        >
          <Sparkles size={18} />
        </span>
        <span className="min-w-0">
          <span className="block truncate font-display text-[17px] text-on-surface">{t.quizRules}</span>
          <span className="block truncate text-[12px] text-text-muted">{t.quizRulesSubtitle}</span>
        </span>
      </span>
    );
  }
  return (
    <span className="flex min-w-0 items-center gap-3">
      <Medallion name={entry.character.name} accent={entry.accent} size={40} portrait={ownPortrait(entry.character)} />
      <span className="min-w-0">
        <span className="block truncate font-display text-[17px] text-on-surface">{entry.character.name}</span>
        <span className="block truncate text-[12px] text-text-muted">{subtitleOf(entry)}</span>
      </span>
    </span>
  );
}

/** «Aasimar · Bruja 2», como en la elección. */
const subtitleOf = (entry: RosterEntry): string =>
  [entry.raceName, ...entry.classes.map((c) => `${c.name} ${c.level}`)].filter(Boolean).join(' · ');

/** El avance, un segmento por pregunta: aciertos en verde, errores en rojo y
 *  la pregunta actual en dorado. Se ve cómo vas sin esperar al final. */
function Segments({ results, current, label }: { results: Outcome[]; current?: number; label: string }) {
  return (
    <div
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={results.length}
      aria-valuenow={(current ?? results.length - 1) + 1}
      aria-label={label}
      className="grid gap-1"
      style={{ gridTemplateColumns: `repeat(${results.length}, minmax(0, 1fr))` }}
    >
      {results.map((r, i) => (
        <span
          key={i}
          className={cx(
            'h-1.5 rounded-full',
            r === 'ok' ? 'bg-verdant' : r === 'bad' ? 'bg-crimson' : i === current ? 'bg-gold' : 'bg-hairline',
          )}
        />
      ))}
    </div>
  );
}

/** Los mismos resultados en puntos, para el aviso de abandonar. */
function Dots({ results }: { results: Outcome[] }) {
  return (
    <span aria-hidden="true" className="flex gap-1.5">
      {results.map((r, i) => (
        <span
          key={i}
          className={cx('size-2.5 rounded-full', r === 'ok' ? 'bg-verdant' : r === 'bad' ? 'bg-crimson' : 'bg-hairline')}
        />
      ))}
    </span>
  );
}

const multiclassOf = (entry: RosterEntry | null): boolean => (entry?.classes.length ?? 0) > 1;

/** El nombre de la clase que el motor manda en `subjectId`. */
function classNameOf(catalog: Catalog, id: string | null): string {
  if (!id) return '';
  const name = catalog.classes.find((c) => c.id === id)?.name;
  return typeof name === 'string' ? name : '';
}

/** El enunciado según el tipo; `s` es el nombre de lo que se pregunta. */
function askOf(t: Texts, q: QuizQuestion, catalog: Catalog, multiclass: boolean): string {
  const s = q.subject ?? '';
  switch (q.kind) {
    case 'classFeatureLevel':
      return t.quizAsk.classFeatureLevel(classNameOf(catalog, q.subjectId), s);
    case 'classFeatureByText':
      return multiclass && s ? t.quizAsk.classFeatureByTextOf(s) : t.quizAsk.classFeatureByText;
    case 'hitDie':
      return t.quizAsk.hitDie(s);
    case 'savingThrows':
      return t.quizAsk.savingThrows(s);
    case 'spellCastingTime':
      return t.quizAsk.spellCastingTime(s);
    case 'spellRange':
      return t.quizAsk.spellRange(s);
    case 'spellSchool':
      return t.quizAsk.spellSchool(s);
    case 'skillAbility':
    case 'weaponMastery':
    case 'weaponDamage':
    case 'armorAc':
    case 'armorCategory':
      return t.quizAsk[q.kind](s);
    case 'speciesTraitByText':
    case 'backgroundSkills':
    case 'backgroundFeat':
    case 'condition':
    case 'masteryByText':
    case 'propertyByText':
      return t.quizAsk[q.kind];
  }
}

/** La cita: la del motor, o la regla del estado, que escribe la UI. */
function Quote({ question }: { question: QuizQuestion }) {
  const t = useTexts();
  const rules = t.conditionRules as Record<string, { rule: string } | undefined>;
  const quote = question.kind === 'condition' ? rules[question.subjectId ?? '']?.rule : question.quote;
  if (!quote) return null;
  return (
    <blockquote className="relative rounded-[var(--radius-card)] border border-hairline bg-plaque py-3.5 pr-4 pl-11 text-[14px] leading-[1.55] text-on-surface-variant">
      <span aria-hidden="true" className="absolute top-1 left-3.5 font-display text-[36px] leading-none text-gold">
        “
      </span>
      {quote}
    </blockquote>
  );
}

/** El veredicto y, en un conjuro, su línea de lanzamiento: la misma de la ficha. */
function Verdict({ right, question, catalog }: { right: boolean; question: QuizQuestion; catalog: Catalog }) {
  const t = useTexts();
  const spell =
    question.topic === 'spells' ? (catalog.spells.find((s) => s.id === question.subjectId) as SpellJson | undefined) : undefined;
  const Icon = right ? Check : X;
  return (
    <div className="flex items-start gap-2.5 rounded-[var(--radius-card)] border border-hairline bg-plaque px-3.5 py-3" aria-live="polite">
      <span
        className={cx(
          'flex size-6 shrink-0 items-center justify-center rounded-full text-on-primary',
          right ? 'bg-verdant' : 'bg-crimson',
        )}
      >
        <Icon size={14} strokeWidth={2.4} aria-hidden="true" />
      </span>
      <span className="flex min-w-0 flex-col gap-0.5">
        <b className="text-[14px] font-semibold text-on-surface">{right ? t.quizRight : t.quizWrong}</b>
        {spell && <span className="text-[13px] leading-snug text-on-surface-variant">{spellMeta(spell)}</span>}
      </span>
    </div>
  );
}

type OptionState = 'open' | 'correct' | 'wrong' | 'dim';

function OptionButton({ letter, label, state, onPick }: { letter: string; label: string; state: OptionState; onPick: () => void }) {
  const t = useTexts();
  const locked = state !== 'open';
  return (
    <button
      type="button"
      disabled={locked}
      onClick={onPick}
      data-option={letter}
      data-state={state}
      className={cx(
        'flex min-h-[52px] w-full items-center gap-3 rounded-[var(--radius-card)] border px-3.5 py-2.5 text-left text-[15px] text-on-surface',
        state === 'open' && 'pick border-hairline bg-plaque hover:border-gold',
        state === 'correct' && cx('border-verdant', TINT_OK),
        state === 'wrong' && cx('border-crimson', TINT_BAD),
        state === 'dim' && 'border-hairline bg-plaque opacity-50',
      )}
    >
      <span
        aria-hidden="true"
        className={cx(
          'flex size-7 shrink-0 items-center justify-center rounded-lg border text-[13px] font-semibold',
          state === 'correct'
            ? 'border-verdant bg-verdant text-on-primary'
            : state === 'wrong'
              ? 'border-crimson bg-crimson text-on-primary'
              : 'border-hairline bg-surface text-gold',
        )}
      >
        {letter}
      </span>
      <span className="min-w-0 flex-1">{label}</span>
      {state === 'wrong' && (
        <span className="flex shrink-0 items-center gap-1 text-[12px] font-semibold text-crimson">
          <X size={14} strokeWidth={2.4} aria-hidden="true" />
          {t.quizYourAnswer}
        </span>
      )}
      {state === 'correct' && (
        <span className="flex shrink-0 items-center gap-1 text-[12px] font-semibold text-verdant">
          <Check size={14} strokeWidth={2.4} aria-hidden="true" />
          {t.quizCorrect}
        </span>
      )}
    </button>
  );
}

function Result({
  entry,
  questions,
  picks,
  results,
  catalog,
  onAgain,
}: {
  entry: RosterEntry | null;
  questions: QuizQuestion[];
  picks: number[];
  results: Outcome[];
  catalog: Catalog;
  onAgain: () => void;
}) {
  const t = useTexts();
  const right = results.filter((r) => r === 'ok').length;
  const missed = questions.map((q, i) => ({ q, pick: picks[i] })).filter(({ q, pick }) => pick !== q.answer);
  // Los aciertos de cada tema que salió en la ronda: dicen qué conviene
  // estudiar sin leer toda la lista.
  const byTopic = TOPICS.map((topic) => {
    const of = questions.map((q, i) => ({ q, r: results[i] })).filter(({ q }) => q.topic === topic);
    return { topic, total: of.length, ok: of.filter(({ r }) => r === 'ok').length };
  }).filter(({ total }) => total > 0);
  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-4">
      <section className="card flex flex-col items-center gap-3 p-6">
        <Who entry={entry} />
        <p className="font-display text-[56px] leading-none text-gold tabular-nums" data-quiz="score">
          {right}
          <span className="text-[26px] text-text-muted"> / {questions.length}</span>
        </p>
        <div className="w-full">
          <Segments results={results} label={t.quizProgress(right, questions.length)} />
        </div>
        <ul className="mt-1 grid w-full grid-cols-1 gap-2 min-[480px]:grid-cols-2">
          {byTopic.map(({ topic, total, ok }) => {
            const Icon = TOPIC_ICON[topic];
            return (
              <li
                key={topic}
                className="flex items-center gap-2 rounded-[var(--radius-card)] border border-hairline bg-plaque px-3 py-2.5"
              >
                <Icon size={13} aria-hidden="true" className="text-gold" />
                <span className="flex-1 text-[13px] text-on-surface-variant">{t.quizTopic[topic]}</span>
                <span className={cx('text-[14px] font-semibold tabular-nums', ok === total ? 'text-verdant' : 'text-on-surface')}>
                  {ok}/{total}
                </span>
              </li>
            );
          })}
        </ul>
      </section>
      {missed.length > 0 && (
        <section className="card flex flex-col px-5 pt-4 pb-1" data-quiz="review">
          <h2 className="mb-2.5 font-display text-[18px] font-normal text-on-surface">{t.quizReview}</h2>
          <ul>
            {missed.map(({ q, pick }, i) => {
              const Icon = TOPIC_ICON[q.topic];
              return (
                <li key={i} className="flex gap-3 border-t border-hairline py-3">
                  <span
                    aria-hidden="true"
                    className="flex size-7 shrink-0 items-center justify-center rounded-lg border border-hairline bg-plaque text-gold"
                  >
                    <Icon size={13} />
                  </span>
                  <span className="flex min-w-0 flex-col gap-1">
                    <span className="text-[14px] text-on-surface">{askOf(t, q, catalog, multiclassOf(entry))}</span>
                    {pick !== undefined && (
                      <span className="flex items-center gap-1.5 text-[13px] text-crimson">
                        <X size={14} strokeWidth={2.4} aria-label={t.quizYourAnswer} />
                        <s>{q.options[pick]}</s>
                      </span>
                    )}
                    <span className="flex items-center gap-1.5 text-[13px] text-verdant">
                      <Check size={14} strokeWidth={2.4} aria-label={t.quizCorrect} />
                      {q.options[q.answer]}
                    </span>
                  </span>
                </li>
              );
            })}
          </ul>
        </section>
      )}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <ButtonLink tone="secondary" shape="pill" href={quizHref()} internal>
          {t.quizPickOther}
        </ButtonLink>
        <Button shape="pill" icon={RotateCcw} onClick={onAgain} data-action="quiz-again">
          {t.quizAgain}
        </Button>
      </div>
    </div>
  );
}
