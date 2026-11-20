import type { QuizCardState, QuizHistory } from '../engine';

/** El progreso del Quiz en este navegador. No viaja con la cuenta. */
const STORAGE_KEY = 'milantus.v2.quizHistory';

// Las mismas esperas que `_quizInterval` del motor: la caja 1 vuelve en la
// ronda siguiente y cada acierto duplica.
const INTERVAL: Record<number, number> = { 1: 1, 2: 2, 3: 4, 4: 8, 5: 16 };

export function emptyQuizHistory(): QuizHistory {
  return { version: 1, round: 0, cards: {} };
}

function isCard(value: unknown): value is QuizCardState {
  if (value == null || typeof value !== 'object') return false;
  const card = value as QuizCardState;
  return (
    Number.isInteger(card.box) &&
    card.box >= 1 &&
    card.box <= 5 &&
    Number.isInteger(card.lastRound) &&
    card.lastRound >= 0 &&
    Number.isInteger(card.correct) &&
    card.correct >= 0 &&
    Number.isInteger(card.wrong) &&
    card.wrong >= 0
  );
}

/** Un documento que no es la versión 1 no se interpreta: devolverlo a medias
 *  pisaría campos de una versión que este cliente no conoce. */
function parseHistory(raw: unknown): QuizHistory | null {
  if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const history = raw as QuizHistory;
  if (history.version !== 1 || !Number.isInteger(history.round) || history.round < 0) return null;
  if (history.cards == null || typeof history.cards !== 'object' || Array.isArray(history.cards)) return null;
  const cards: Record<string, QuizCardState> = {};
  for (const [id, card] of Object.entries(history.cards)) {
    if (id && isCard(card)) cards[id] = card;
  }
  return { version: 1, round: history.round, cards };
}

/** Sin almacenamiento (o con basura) no hay historial: la ronda se sortea
 *  como si nadie hubiera respondido. */
export function loadQuizHistory(): QuizHistory {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return emptyQuizHistory();
    return parseHistory(JSON.parse(raw)) ?? emptyQuizHistory();
  } catch {
    return emptyQuizHistory();
  }
}

export function saveQuizHistory(history: QuizHistory): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(history));
  } catch {
    // Sin almacenamiento el progreso dura lo que la pestaña.
  }
}

export function resetQuizHistory(): void {
  try {
    window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // Sin almacenamiento no había nada que borrar.
  }
}

/** Cuántas tarjetas van a estar para repasar cuando empiece la próxima ronda.
 *  Una ronda muestra diez y, si hay para llenarla, deja dos para lo que no se
 *  respondió: el aviso no promete más de las que van a aparecer primero. */
export function quizDueNext(history: QuizHistory): number {
  const at = history.round + 1;
  let n = 0;
  for (const card of Object.values(history.cards)) {
    const wait = INTERVAL[card.box];
    if (wait != null && at - card.lastRound >= wait) n += 1;
  }
  if (n >= 10) return 8;
  return n;
}
