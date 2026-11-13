import { useMemo, useState, type ReactNode } from 'react';
import { Sparkles } from 'lucide-react';
import { useRoster, useSheetCatalog } from '../api/queries';
import { quizRound, type Catalog, type CharacterJson, type QuizQuestion } from '../engine';
import { toRosterEntry, type RosterEntry } from '../dashboard/roster';
import { useLang, useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { Link, quizHref } from '../router';
import { spellMeta, type SpellJson } from '../sheet/SpellList';
import { Button, ButtonLink } from '../ui/Button';
import { cx } from '../ui/cx';
import { Medallion } from '../ui/Medallion';
import { ownPortrait } from '../ui/portrait';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';

/** El id de la ronda de reglas generales en la URL (`/v2/quiz/reglas`). */
export const RULES_TARGET = 'reglas';

/**
 * El Quiz: rondas de diez preguntas que arma el motor desde el catálogo y la
 * ficha. No se guarda nada: ni puntaje ni historial, y la ronda vive en el
 * estado del componente (recargar arranca otra).
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

function Round({ entry, catalog }: { entry: RosterEntry | null; catalog: Catalog }) {
  const t = useTexts();
  const [seed, setSeed] = useState(newSeed);
  const questions = useMemo(
    () => quizRound((entry?.character as unknown as CharacterJson | undefined) ?? null, catalog, seed),
    [entry, catalog, seed],
  );
  // Qué se contestó en cada pregunta (índice de la opción); `undefined` hasta tocar.
  const [picks, setPicks] = useState<number[]>([]);
  const [index, setIndex] = useState(0);

  const who = entry?.character.name ?? t.quizRules;
  const restart = () => {
    setSeed(newSeed());
    setPicks([]);
    setIndex(0);
  };

  if (questions.length === 0) return <Notice title={t.quizTitle} body={who} />;
  if (index >= questions.length) return <Result who={who} questions={questions} picks={picks} onAgain={restart} />;

  const question = questions[index]!;
  const picked = picks[index];
  const last = index === questions.length - 1;
  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-3.5">
      <div className="flex items-center justify-between">
        <span className="font-display text-[16px] text-on-surface">{who}</span>
        <span className="num text-[13px] font-normal text-text-muted" data-quiz="progress">
          {t.quizProgress(index + 1, questions.length)}
        </span>
      </div>
      <div
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={questions.length}
        aria-valuenow={index + 1}
        aria-label={t.quizProgress(index + 1, questions.length)}
        className="h-1 overflow-hidden rounded-sm bg-hairline"
      >
        <div className="h-full bg-gold" style={{ width: `${((index + 1) / questions.length) * 100}%` }} />
      </div>
      {/* `key` remonta la tarjeta en cada pregunta: entra con `.step-in`. */}
      <section key={index} className="card step-in flex flex-col gap-3 p-4" data-quiz="question">
        <span className="self-start rounded-[var(--radius-pill)] border border-gold bg-gold-soft px-2.5 py-0.5 text-[12px] text-gold">
          {t.quizTopic[question.topic]}
        </span>
        <p className="text-[15px] leading-normal text-on-surface">{askOf(t, question)}</p>
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
        {picked !== undefined && <Extra question={question} catalog={catalog} />}
      </section>
      {/* No avanza solo: leer la respuesta no puede irse de abajo del dedo. */}
      {picked !== undefined && (
        <Button className="self-end" onClick={() => setIndex(index + 1)} data-action="quiz-next">
          {last ? t.quizSeeResult : t.quizNext}
        </Button>
      )}
    </div>
  );
}

/** El enunciado según el tipo; `s` es el nombre de lo que se pregunta. */
function askOf(t: Texts, q: QuizQuestion): string {
  const s = q.subject ?? '';
  switch (q.kind) {
    case 'classFeatureLevel':
      return t.quizAsk.classFeatureLevel(s);
    case 'spellCastingTime':
      return t.quizAsk.spellCastingTime(s);
    case 'spellRange':
      return t.quizAsk.spellRange(s);
    case 'spellSchool':
      return t.quizAsk.spellSchool(s);
    case 'classFeatureByText':
    case 'hitDie':
    case 'savingThrows':
    case 'speciesTraitByText':
    case 'backgroundSkills':
    case 'backgroundFeat':
    case 'condition':
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
    <blockquote className="rounded-r-[var(--radius-card)] border-l-2 border-gold bg-plaque px-3.5 py-2.5 text-[14px] leading-normal text-on-surface-variant">
      {quote}
    </blockquote>
  );
}

/** En un conjuro, su línea de lanzamiento: la misma de la ficha. */
function Extra({ question, catalog }: { question: QuizQuestion; catalog: Catalog }) {
  if (question.topic !== 'spells') return null;
  const spell = catalog.spells.find((s) => s.id === question.subjectId) as SpellJson | undefined;
  if (!spell) return null;
  return <p className="text-[13px] leading-snug text-on-surface-variant">{spellMeta(spell)}</p>;
}

type OptionState = 'open' | 'correct' | 'wrong' | 'dim';

function OptionButton({ letter, label, state, onPick }: { letter: string; label: string; state: OptionState; onPick: () => void }) {
  const t = useTexts();
  const locked = state !== 'open';
  const tone = state === 'correct' ? 'border-verdant text-verdant' : state === 'wrong' ? 'border-crimson text-crimson' : '';
  return (
    <button
      type="button"
      disabled={locked}
      onClick={onPick}
      data-option={letter}
      data-state={state}
      className={cx(
        'flex min-h-12 w-full items-center gap-2.5 rounded-[var(--radius-card)] border px-3.5 py-3 text-left text-[14px]',
        // Abiertas son placas que se tocan; bloqueadas dejan de reaccionar.
        locked
          ? cx('border-hairline bg-plaque text-on-surface', tone, state === 'dim' && 'opacity-55')
          : 'pick border-hairline bg-plaque text-on-surface',
      )}
    >
      <span
        aria-hidden="true"
        className={cx(
          'flex size-[22px] shrink-0 items-center justify-center rounded-full border text-[12px]',
          tone || 'border-hairline text-on-surface-variant',
        )}
      >
        {letter}
      </span>
      <span className="min-w-0 flex-1">{label}</span>
      {state === 'wrong' && <span className="shrink-0 text-[12px]">{t.quizYourAnswer}</span>}
      {state === 'correct' && <span className="shrink-0 text-[12px]">{t.quizCorrect}</span>}
    </button>
  );
}

function Result({
  who,
  questions,
  picks,
  onAgain,
}: {
  who: string;
  questions: QuizQuestion[];
  picks: number[];
  onAgain: () => void;
}) {
  const t = useTexts();
  const missed = questions.filter((q, i) => picks[i] !== q.answer);
  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-3.5">
      <section className="card flex flex-col items-center gap-1.5 p-6">
        <span className="text-[13px] text-text-muted">{who}</span>
        <p className="font-display text-[40px] leading-none text-gold [font-variant-numeric:tabular-nums]" data-quiz="score">
          {t.quizProgress(questions.length - missed.length, questions.length)}
        </p>
      </section>
      {missed.length > 0 && (
        <section className="card flex flex-col p-4" data-quiz="review">
          <h2 className="mb-1.5 font-display text-[16px] font-normal text-on-surface">{t.quizReview}</h2>
          <ul>
            {missed.map((q, i) => (
              <li key={i} className="border-t border-hairline py-2.5">
                <p className="text-[14px] text-on-surface">{askOf(t, q)}</p>
                <p className="mt-0.5 text-[13px] text-verdant">{q.options[q.answer]}</p>
              </li>
            ))}
          </ul>
        </section>
      )}
      <div className="flex flex-wrap justify-end gap-2">
        <ButtonLink tone="secondary" shape="pill" href={quizHref()} internal>
          {t.quizPickOther}
        </ButtonLink>
        <Button shape="pill" onClick={onAgain} data-action="quiz-again">
          {t.quizAgain}
        </Button>
      </div>
    </div>
  );
}
