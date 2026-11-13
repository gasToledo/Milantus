import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState, type ReactNode } from 'react';
import { describe, expect, it, vi } from 'vitest';
import type { Catalog, QuizQuestion } from '../engine';
import { LangProvider } from '../i18n/context';
import type { Lang } from '../i18n/texts';
import { QuizPage } from './QuizPage';

// El motor no entra: la prueba mira la pantalla. `quizRound` arma la ronda una
// vez; al cambiar de idioma `quizLocalize` reescribe el texto y no se sortea.
const langBox = vi.hoisted(() => ({ current: 'es' as Lang }));
const calls = vi.hoisted(() => ({ round: 0 }));

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

const round = (lang: Lang) => [question(lang, 0), question(lang, 1)];

vi.mock('../engine', () => ({
  quizRound: () => {
    calls.round += 1;
    return round('es');
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
    classes: [{ id: 'fighter', name: 'Guerrero' }],
    races: [{ id: 'human', name: 'Humano' }],
    spells: [],
  },
  en: {
    classes: [{ id: 'fighter', name: 'Fighter' }],
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
  it('muestra la pregunta, traba la respuesta, cuenta el puntaje y no rearma la ronda al cambiar de idioma', async () => {
    const user = userEvent.setup();
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
});
