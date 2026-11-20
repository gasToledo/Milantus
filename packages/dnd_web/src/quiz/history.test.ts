import { afterEach, describe, expect, it, vi } from 'vitest';
import { emptyQuizHistory, loadQuizHistory, quizDueNext, resetQuizHistory, saveQuizHistory } from './history';

const KEY = 'milantus.v2.quizHistory';

afterEach(() => {
  vi.unstubAllGlobals();
  localStorage.clear();
});

describe('el historial del Quiz', () => {
  it('guarda, lee y borra', () => {
    expect(loadQuizHistory()).toEqual(emptyQuizHistory());
    const history = {
      version: 1 as const,
      round: 2,
      cards: { 'weapon:dagger:weaponDamage': { box: 2, lastRound: 1, correct: 1, wrong: 0 } },
    };
    saveQuizHistory(history);
    expect(JSON.parse(localStorage.getItem(KEY) ?? '')).toEqual(history);
    expect(loadQuizHistory()).toEqual(history);
    resetQuizHistory();
    expect(localStorage.getItem(KEY)).toBeNull();
    expect(loadQuizHistory()).toEqual(emptyQuizHistory());
  });

  it('un JSON roto o de otra versión es un historial vacío', () => {
    localStorage.setItem(KEY, '{');
    expect(loadQuizHistory()).toEqual(emptyQuizHistory());
    localStorage.setItem(KEY, JSON.stringify({ version: 2, round: 4, cards: {} }));
    expect(loadQuizHistory()).toEqual(emptyQuizHistory());
    localStorage.setItem(
      KEY,
      JSON.stringify({
        version: 1,
        round: 3,
        cards: {
          ok: { box: 1, lastRound: 2, correct: 0, wrong: 1 },
          mal: { box: 9, lastRound: 2, correct: 0, wrong: 1 },
        },
      }),
    );
    expect(loadQuizHistory().cards).toEqual({
      ok: { box: 1, lastRound: 2, correct: 0, wrong: 1 },
    });
  });

  it('si el almacenamiento lanza, no hay historial y guardar no revienta', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => {
        throw new Error('bloqueado');
      },
      setItem: () => {
        throw new Error('bloqueado');
      },
      removeItem: () => {
        throw new Error('bloqueado');
      },
    });
    expect(loadQuizHistory()).toEqual(emptyQuizHistory());
    expect(() => saveQuizHistory(emptyQuizHistory())).not.toThrow();
    expect(() => resetQuizHistory()).not.toThrow();
  });

  it('la caja 2 de la ronda 1 vence para la ronda 3, no para la 2', () => {
    const history = {
      version: 1 as const,
      round: 1,
      cards: { a: { box: 2, lastRound: 1, correct: 1, wrong: 0 } },
    };
    expect(quizDueNext(history)).toBe(0);
    expect(quizDueNext({ ...history, round: 2 })).toBe(1);
    const many = {
      version: 1 as const,
      round: 1,
      cards: Object.fromEntries(
        Array.from({ length: 12 }, (_, i) => [`k${i}`, { box: 1, lastRound: 1, correct: 0, wrong: 1 }]),
      ),
    };
    expect(quizDueNext(many)).toBe(8);
  });
});
