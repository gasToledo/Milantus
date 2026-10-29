import { useCallback, useEffect, useState } from 'react';
import { fetchCharacter } from '../api/client';
import { loadCatalog } from '../api/catalog';
import {
  computeSheet,
  type Catalog,
  type CharacterFields,
  type ComputedSheet,
} from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { ActionButton, Notice } from '../ui/Shell';
import { CharacterSheet } from './CharacterSheet';

type State =
  | { kind: 'loading' }
  | { kind: 'error' }
  // La API responde igual para lo ajeno y lo inexistente: acá tampoco se
  // distinguen.
  | { kind: 'not-found' }
  | { kind: 'ready'; character: CharacterFields; sheet: ComputedSheet; catalog: Catalog };

export function CharacterPage({ id }: { id: string }) {
  const t = useTexts();
  const lang = useLang();
  const [state, setState] = useState<State>({ kind: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const retry = useCallback(() => {
    setState({ kind: 'loading' });
    setAttempt((n) => n + 1);
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    (async () => {
      // El personaje y el catálogo no dependen uno del otro: juntos.
      const [raw, catalog] = await Promise.all([
        fetchCharacter(id, controller.signal),
        loadCatalog(lang, controller.signal),
      ]);
      if (raw === null) return { kind: 'not-found' } as const;
      // La ficha se calcula con el motor de Dart compilado a JS: el mismo que
      // usan el servidor y Flutter. Acá no se recalcula ninguna regla.
      const sheet = computeSheet(raw, catalog);
      // `raw` es un `Character.toJson` que el servidor ya validó al guardarlo;
      // `CharacterFields` es el subconjunto que esta pantalla lee.
      return { kind: 'ready', character: raw as unknown as CharacterFields, sheet, catalog } as const;
    })()
      .then(setState)
      .catch(() => {
        if (!controller.signal.aborted) setState({ kind: 'error' });
      });
    return () => controller.abort();
  }, [id, lang, attempt]);

  switch (state.kind) {
    case 'loading':
      return <Notice title={t.loading} />;
    case 'error':
      return (
        <Notice
          title={t.errorTitle}
          body={t.errorBody}
          action={<ActionButton onClick={retry}>{t.retry}</ActionButton>}
        />
      );
    case 'not-found':
      return <Notice title={t.notFoundTitle} body={t.notFoundBody} />;
    case 'ready':
      return (
        <CharacterSheet character={state.character} sheet={state.sheet} catalog={state.catalog} />
      );
  }
}
