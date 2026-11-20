import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState, type ReactNode } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Catalog, QuizHistory, QuizQuestion } from '../engine';
import { LangProvider } from '../i18n/context';
import { textsFor, type Lang } from '../i18n/texts';
import { QuizPage } from './QuizPage';

// El motor no entra: la prueba mira la pantalla. `quizRound` arma la ronda una
// vez; al cambiar de idioma `quizLocalize` reescribe el texto y no se sortea.
const langBox = vi.hoisted(() => ({ current: 'es' as Lang }));
const calls = vi.hoisted(() => ({ round: 0, histories: [] as unknown[] }));
const mode = vi.hoisted(() => ({ current: 'base' as 'base' | 'plantillas' }));

function question(lang: Lang, index: number): QuizQuestion {
  const es = lang === 'es';
  if (index === 0) {
    return {
      key: 'weapon:dagger',
      kind: 'weaponDamage',
      topic: 'equipment',
      subject: es ? 'Daga' : 'Dagger',
      subjectId: 'dagger',
      level: null,
      quote: null,
      options: es
        ? ['1d4 perforante', '1d6 cortante', '1d8 contundente', '1d10 perforante']
        : ['1d4 piercing', '1d6 slashing', '1d8 bludgeoning', '1d10 piercing'],
      optionIds: ['1d4|piercing', '1d6|slashing', '1d8|bludgeoning', '1d10|piercing'],
      answer: 0,
    };
  }
  return {
    key: 'condition:blinded',
    kind: 'condition',
    topic: 'rules',
    subject: es ? 'Cegado' : 'Blinded',
    subjectId: 'blinded',
    level: null,
    quote: null,
    options: es ? ['Cegado', 'Asustado', 'Sordo', 'Agarrado'] : ['Blinded', 'Frightened', 'Deafened', 'Grappled'],
    optionIds: ['blinded', 'frightened', 'deafened', 'grappled'],
    answer: 0,
  };
}

function plantillas(lang: Lang): QuizQuestion[] {
  const es = lang === 'es';
  return [
    {
      key: 'feature:warlock:c5',
      kind: 'classFeatureLevel',
      topic: 'class',
      subject: es ? 'Invocaciones Sobrenaturales' : 'Eldritch Invocations',
      subjectId: 'warlock',
      level: 9,
      quote: null,
      options: ['2', '5', '9', '12'],
      optionIds: ['2', '5', '9', '12'],
      answer: 2,
      progress: { kind: 'known', n: 7 },
    },
    {
      key: 'spell:misty-step:spellMoveDistance',
      kind: 'spellMoveDistance',
      topic: 'spells',
      subject: es ? 'Paso Brumoso' : 'Misty Step',
      subjectId: 'misty-step',
      level: null,
      quote: null,
      options: es ? ['30 pies', '60 pies', '120 pies', '500 pies'] : ['30 feet', '60 feet', '120 feet', '500 feet'],
      optionIds: ['30 pies', '60 pies', '120 pies', '500 pies'],
      answer: 0,
    },
  ];
}

const round = (lang: Lang) => (mode.current === 'plantillas' ? plantillas(lang) : [question(lang, 0), question(lang, 1)]);

vi.mock('../engine', () => ({
  quizRound: (_character: unknown, _catalog: unknown, _seed: number, history?: QuizHistory) => {
    calls.round += 1;
    calls.histories.push(history);
    return round('es');
  },
  quizRecordAnswers: (history: QuizHistory, answers: { cardId: string; correct: boolean }[]) => {
    const cards = { ...history.cards };
    for (const answer of answers) {
      const prev = cards[answer.cardId];
      cards[answer.cardId] = {
        box: answer.correct ? Math.min(5, (prev?.box ?? 1) + 1) : 1,
        lastRound: history.round,
        correct: (prev?.correct ?? 0) + (answer.correct ? 1 : 0),
        wrong: (prev?.wrong ?? 0) + (answer.correct ? 0 : 1),
      };
    }
    return { ...history, cards };
  },
  quizLocalize: () => round(langBox.current),
  computeSheet: () => ({ classLevels: { fighter: 1 } }),
}));

vi.mock('../router', () => ({
  Link: ({ children }: { children: ReactNode }) => <a>{children}</a>,
  navigate: vi.fn(),
  quizHref: (target?: string) => (target ? `/quiz/${target}` : '/quiz'),
  setLeaveGuard: vi.fn(),
}));

const catalogs = {
  es: {
    classes: [
      { id: 'fighter', name: 'Guerrero' },
      { id: 'warlock', name: 'Brujo' },
    ],
    races: [{ id: 'human', name: 'Humano' }],
    spells: [],
  },
  en: {
    classes: [
      { id: 'fighter', name: 'Fighter' },
      { id: 'warlock', name: 'Warlock' },
    ],
    races: [{ id: 'human', name: 'Human' }],
    spells: [],
  },
} as unknown as Record<Lang, Catalog>;

vi.mock('../api/queries', () => ({
  useRoster: () => ({
    data: [
      {
        character: {
          id: 'c1',
          name: 'Brunilda',
          raceId: 'human',
          classId: 'fighter',
          combat: { currentHp: 10 },
        },
        createdAt: '2026-01-01T00:00:00Z',
      },
    ],
    isError: false,
    refetch: vi.fn(),
  }),
  useSheetCatalog: () => ({ data: catalogs[langBox.current], queries: [] }),
}));

function Harness() {
  const [lang, setLang] = useState<Lang>('es');
  langBox.current = lang;
  return (
    <LangProvider lang={lang}>
      <button type="button" onClick={() => setLang('en')}>
        English
      </button>
      <QuizPage target="c1" />
    </LangProvider>
  );
}

describe('el Quiz', () => {
  beforeEach(() => {
    localStorage.clear();
    calls.histories = [];
  });

  it('muestra la pregunta, traba la respuesta, cuenta el puntaje y no rearma la ronda al cambiar de idioma', async () => {
    const user = userEvent.setup();
    mode.current = 'base';
    calls.round = 0;
    render(<Harness />);

    screen.getByText('¿Cuánto daño hace Daga?');
    const roundsAfterOpen = calls.round;
    expect(roundsAfterOpen).toBeGreaterThan(0);

    await user.click(screen.getByRole('button', { name: '1d6 cortante' }));
    const wrong = screen.getByRole('button', { name: /1d6 cortante/ });
    expect((wrong as HTMLButtonElement).disabled).toBe(true);
    expect(wrong.getAttribute('data-state')).toBe('wrong');
    expect(screen.getByRole('button', { name: /1d4 perforante/ }).getAttribute('data-state')).toBe('correct');

    await user.click(screen.getByRole('button', { name: 'English' }));
    expect(calls.round).toBe(roundsAfterOpen);
    screen.getByText('How much damage does the Dagger deal?');
    expect(screen.getByRole('button', { name: /1d6 slashing/ }).getAttribute('data-state')).toBe('wrong');
    expect(screen.getByRole('button', { name: /1d4 piercing/ }).getAttribute('data-state')).toBe('correct');

    await user.click(screen.getByRole('button', { name: 'Next' }));
    await user.click(screen.getByRole('button', { name: 'Blinded' }));
    await user.click(screen.getByRole('button', { name: 'See result' }));
    expect(document.querySelector('[data-quiz="score"]')?.textContent?.replace(/\s+/g, ' ').trim()).toBe('1 / 2');
  });

  it('arma las progresiones y la distancia de movimiento en español y en inglés', async () => {
    const user = userEvent.setup();
    mode.current = 'plantillas';
    render(<Harness />);

    screen.getByText('¿En qué nivel de Brujo conocés 7 Invocaciones Sobrenaturales?');
    await user.click(screen.getByRole('button', { name: 'English' }));
    screen.getByText('At what Warlock level do you know 7 Eldritch Invocations?');
    await user.click(screen.getByRole('button', { name: '9' }));
    await user.click(screen.getByRole('button', { name: 'Next' }));
    screen.getByText('How far does Misty Step let you move?');

    const es = textsFor('es').quizAsk;
    const en = textsFor('en').quizAsk;
    expect(es.classFeatureProgress.uses('Bárbaro', 'Furia', 4)).toBe('¿En qué nivel de Bárbaro tenés 4 usos de Furia?');
    expect(es.classFeatureProgress.feet('Monje', 'Movimiento sin Armadura', 20)).toBe(
      '¿En qué nivel de Monje tu Movimiento sin Armadura llega a +20 pies?',
    );
    expect(es.classFeatureProgress.spellLevel('Brujo', 'Arcanum Místico', 7)).toBe(
      '¿En qué nivel de Brujo obtenés un Arcanum Místico de nivel 7?',
    );
    expect(es.classFeatureProgress.forms('Druida', 'Forma Salvaje', 6)).toBe(
      '¿En qué nivel de Druida conocés 6 formas de Forma Salvaje?',
    );
    expect(es.classFeatureProgress.weapons('Guerrero', 'Maestría con Armas', 4)).toBe(
      '¿En qué nivel de Guerrero tu Maestría con Armas llega a 4 armas?',
    );
    expect(es.classFeatureProgress.dice('Bárbaro', 'Golpe Brutal Mejorado', '2d10')).toBe(
      '¿En qué nivel de Bárbaro tu Golpe Brutal Mejorado llega a 2d10?',
    );
    expect(es.classFeatureProgress.extraSkills('Pícaro', 'Pericia', 2)).toBe(
      '¿En qué nivel de Pícaro tu Pericia suma 2 habilidades más?',
    );
    expect(es.classFeatureLevel('Brujo', 'Invocaciones Sobrenaturales')).toBe(
      '¿En qué nivel de Brujo obtenés Invocaciones Sobrenaturales?',
    );
    expect(en.classFeatureProgress.uses('Barbarian', 'Rage', 4)).toBe('At what Barbarian level do you have 4 uses of Rage?');
    expect(en.classFeatureProgress.feet('Monk', 'Unarmored Movement', 20)).toBe(
      'At what Monk level does your Unarmored Movement reach +20 feet?',
    );
    expect(en.classFeatureProgress.spellLevel('Warlock', 'Mystic Arcanum', 7)).toBe(
      'At what Warlock level do you gain a level 7 Mystic Arcanum?',
    );
    expect(en.spellMoveDistance('Misty Step')).toBe('How far does Misty Step let you move?');
    expect(es.spellMoveDistance('Paso Brumoso')).toBe('¿Hasta qué distancia te permite moverte Paso Brumoso?');
    mode.current = 'base';
  });

  it('al responder guarda el progreso y otra ronda lo sigue', async () => {
    const user = userEvent.setup();
    mode.current = 'base';
    calls.round = 0;
    render(<Harness />);
    // El cuarto argumento es el historial: la ronda que empieza ya sumó uno.
    expect(calls.histories.at(-1)).toMatchObject({ version: 1, round: 1, cards: {} });
    const roundsAtStart = calls.round;

    await user.click(screen.getByRole('button', { name: '1d6 cortante' }));
    const saved = JSON.parse(localStorage.getItem('milantus.v2.quizHistory') ?? '');
    expect(saved.round).toBe(1);
    expect(saved.cards['weapon:dagger']).toMatchObject({ box: 1, wrong: 1 });

    await user.click(screen.getByRole('button', { name: 'Siguiente' }));
    await user.click(screen.getByRole('button', { name: 'Cegado' }));
    await user.click(screen.getByRole('button', { name: 'Ver resultado' }));
    expect(screen.getByText('En la próxima ronda va a aparecer primero 1 pregunta para repasar.')).toBeTruthy();

    await user.click(screen.getByRole('button', { name: 'Otra ronda' }));
    expect(calls.round).toBeGreaterThan(roundsAtStart);
    expect(calls.histories.at(-1)).toMatchObject({ round: 2 });
  });

  it('borrar el progreso pide confirmación y recién ahí lo limpia', async () => {
    const user = userEvent.setup();
    mode.current = 'base';
    localStorage.setItem(
      'milantus.v2.quizHistory',
      JSON.stringify({ version: 1, round: 4, cards: { 'weapon:dagger': { box: 1, lastRound: 4, correct: 0, wrong: 1 } } }),
    );
    render(<Harness />);
    await user.click(screen.getByRole('button', { name: '1d4 perforante' }));
    await user.click(screen.getByRole('button', { name: 'Siguiente' }));
    await user.click(screen.getByRole('button', { name: 'Cegado' }));
    await user.click(screen.getByRole('button', { name: 'Ver resultado' }));

    await user.click(screen.getByRole('button', { name: 'Borrar el progreso' }));
    expect(screen.getByRole('dialog', { name: '¿Borrar el progreso del Quiz?' })).toBeTruthy();
    expect(localStorage.getItem('milantus.v2.quizHistory')).toBeTruthy();
    await user.click(screen.getByRole('button', { name: 'Cancelar' }));
    expect(localStorage.getItem('milantus.v2.quizHistory')).toBeTruthy();

    await user.click(screen.getByRole('button', { name: 'Borrar el progreso' }));
    await user.click(screen.getByRole('button', { name: /^Borrar$/ }));
    expect(localStorage.getItem('milantus.v2.quizHistory')).toBeNull();
  });

  it('en la elección, borrar el progreso también pide confirmación', async () => {
    const user = userEvent.setup();
    localStorage.setItem('milantus.v2.quizHistory', JSON.stringify({ version: 1, round: 2, cards: {} }));
    render(
      <LangProvider lang="es">
        <QuizPage target={null} />
      </LangProvider>,
    );
    // La primera vez el tutorial tapa la elección.
    const skip = screen.queryByRole('button', { name: 'Saltar todos' });
    if (skip) await user.click(skip);
    await user.click(screen.getByRole('button', { name: 'Borrar el progreso' }));
    await user.click(screen.getByRole('button', { name: 'Cancelar' }));
    expect(localStorage.getItem('milantus.v2.quizHistory')).toBeTruthy();
    await user.click(screen.getByRole('button', { name: 'Borrar el progreso' }));
    await user.click(screen.getByRole('button', { name: /^Borrar$/ }));
    expect(localStorage.getItem('milantus.v2.quizHistory')).toBeNull();
  });
});
