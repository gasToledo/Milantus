import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { EntryDetail } from '../codex/CodexPage';
import { spellEntry } from '../codex/entries';
import type { Catalog, InnateSpell, JsonObject } from '../engine';
import { LangProvider } from '../i18n/context';
import { textsFor, type Lang } from '../i18n/texts';
import type { SheetModel } from './model';
import { InnateCantripDialog } from './InnateCantripDialog';
import { SpellList, type SpellJson } from './SpellList';
import type { SheetWriter } from './writer';

vi.mock('../engine', () => ({
  vocabularyLabel: (_field: string, value: string) => value,
  innateCantripOptions: () => [
    { id: 'fire-bolt', name: 'Descarga de fuego', school: 'Evocación' },
    { id: 'shocking-grasp', name: 'Toque chocante', school: 'Evocación' },
  ],
  abilityModifier: (score: number) => Math.floor((score - 10) / 2),
}));

const catalog = { classes: [] } as unknown as Catalog;

function spell(partial: SpellJson): SpellJson {
  return {
    school: 'Evocación',
    castingTime: 'Acción',
    range: '60 pies',
    components: 'V, S',
    duration: 'Instantánea',
    classes: [],
    source: '',
    ...partial,
  };
}

const cantrip = spell({
  id: 'fire-bolt',
  name: 'Descarga de fuego',
  level: 0,
  description: 'Un rayo de fuego.',
  higherLevel: 'El daño aumenta en 1d10.',
});

const leveled = spell({
  id: 'burning-hands',
  name: 'Manos ardientes',
  level: 1,
  description: 'Un cono de fuego.',
  higherLevel: 'El daño aumenta en 1d6.',
});

function withLang(lang: Lang, node: ReactNode) {
  return render(<LangProvider lang={lang}>{node}</LangProvider>);
}

describe('la mejora del conjuro', () => {
  it('en la ficha distingue el truco del conjuro con nivel', async () => {
    const user = userEvent.setup();
    withLang(
      'es',
      <SpellList
        cantripIds={['fire-bolt']}
        spellIds={['burning-hands']}
        alwaysPreparedIds={[]}
        innate={[]}
        preparation="prepared"
        preparedSwap={null}
        innateReactions={[]}
        classReactionIds={[]}
        catalog={[cantrip, leveled]}
        innateNote={() => ''}
        levelFilter={null}
        caps={null}
        damageBonuses={{}}
        casting={null}
        abilityModifiers={{}}
        abilities={[]}
      />,
    );

    await user.click(screen.getByRole('button', { name: /Manos ardientes/ }));
    expect(screen.getByText('Con un espacio de conjuro de nivel superior.')).toBeTruthy();
    expect(screen.getByText(/El daño aumenta en 1d6/)).toBeTruthy();

    await user.click(screen.getByRole('tab', { name: /Trucos/ }));
    await user.click(screen.getByRole('button', { name: /Descarga de fuego/ }));
    expect(screen.getByText('Mejora de truco.')).toBeTruthy();
    expect(screen.getByText(/El daño aumenta en 1d10/)).toBeTruthy();
  });

  it('en el Códice usa el mismo rótulo', () => {
    const abierto = (level: number, text: string, lang: Lang) => {
      const t = textsFor(lang);
      const entry = spellEntry(
        spell({
          id: level === 0 ? 'fire-bolt' : 'burning-hands',
          name: level === 0 ? 'Fire Bolt' : 'Burning Hands',
          level,
          description: 'Daño.',
          higherLevel: text,
        }) as JsonObject,
        catalog,
        t,
        lang,
      );
      const view = withLang(lang, <EntryDetail entry={entry} reading={null} />);
      return () => view.unmount();
    };

    let close = abierto(0, 'Sube el daño.', 'es');
    expect(screen.getByText('Mejora de truco.')).toBeTruthy();
    expect(screen.getByText(/Sube el daño/)).toBeTruthy();
    close();

    close = abierto(1, 'Sube con el espacio.', 'es');
    expect(screen.getByText('Con un espacio de conjuro de nivel superior.')).toBeTruthy();
    close();

    close = abierto(0, 'The damage increases.', 'en');
    expect(screen.getByText('Cantrip Upgrade.')).toBeTruthy();
    close();

    close = abierto(1, 'The damage increases.', 'en');
    expect(screen.getByText('Using a Higher-Level Spell Slot.')).toBeTruthy();
    close();
  });

  it('al cambiar un truco innato muestra la mejora con el rótulo de truco', async () => {
    const user = userEvent.setup();
    const innate: InnateSpell = {
      spellId: 'fire-bolt',
      name: 'Descarga de fuego',
      level: 0,
      ability: 'charisma',
      use: 'atWill',
      saveDc: 13,
      attackBonus: 5,
      source: 'Luz',
      grantedSpellId: 'light',
      replaceableFrom: ['wizard'],
      freeUses: 0,
    };
    const model = {
      character: {},
      catalog: {
        spells: [
          cantrip,
          spell({
            id: 'shocking-grasp',
            name: 'Toque chocante',
            level: 0,
            description: 'Un toque.',
            higherLevel: 'El daño aumenta en 1d8.',
          }),
        ],
        classes: [{ id: 'wizard', name: 'Mago' }],
      },
    } as unknown as SheetModel;

    withLang(
      'es',
      <InnateCantripDialog model={model} write={{} as SheetWriter} innate={innate} onClose={() => {}} />,
    );

    expect(screen.getByText('Mejora de truco.')).toBeTruthy();
    expect(screen.getByText(/El daño aumenta en 1d10/)).toBeTruthy();
    expect(screen.queryByText('Con un espacio de conjuro de nivel superior.')).toBeNull();

    await user.click(screen.getByRole('radio', { name: /Toque chocante/ }));
    expect(screen.getByText('Mejora de truco.')).toBeTruthy();
    expect(screen.getByText(/El daño aumenta en 1d8/)).toBeTruthy();
  });

  it('el formulario de conjuros propios nombra el espacio y el truco', () => {
    expect(textsFor('es').hbSpellHigherLevel).toBe('Mejora (espacio superior o truco)');
    expect(textsFor('en').hbSpellHigherLevel).toBe('Using a Higher-Level Spell Slot / Cantrip Upgrade');
  });
});
