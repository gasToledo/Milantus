import { useCallback, useEffect, useMemo, useState } from 'react';
import { accentOf, loadCatalog, nameOf } from '../api/catalog';
import { fetchRoster, fetchRosterSettings, type RosterSettings } from '../api/client';
import { computeSheet, type CharacterFields, type ComputedSheet } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { FLUTTER_HOME } from '../router';
import { EmptyState } from '../ui/States';
import { ActionButton, ActionLink, Notice } from '../ui/Shell';
import { RosterCard } from './RosterCard';
import { isFallen, parseSortMode, visibleRoster, type RosterEntry } from './roster';

type State =
  | { kind: 'loading' }
  | { kind: 'error' }
  | { kind: 'ready'; entries: RosterEntry[]; settings: RosterSettings };

/**
 * El dashboard de solo lectura. El orden y el favorito se leen de los ajustes
 * de la cuenta y se muestran; cambiarlos (y crear, renombrar, borrar…) vive en
 * Flutter hasta que React escriba.
 */
export function DashboardPage() {
  const t = useTexts();
  const lang = useLang();
  const [state, setState] = useState<State>({ kind: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const [query, setQuery] = useState('');
  const retry = useCallback(() => {
    setState({ kind: 'loading' });
    setAttempt((n) => n + 1);
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    (async (): Promise<State> => {
      const { signal } = controller;
      // Independientes entre sí: juntos, como en la ficha.
      const [stored, settings, catalog] = await Promise.all([
        fetchRoster(signal),
        fetchRosterSettings(signal),
        loadCatalog(lang, signal),
      ]);
      const entries = stored.map(({ character: raw, createdAt }): RosterEntry => {
        // `raw` es un `Character.toJson` que el servidor ya validó al guardarlo;
        // `CharacterFields` es el subconjunto que esta pantalla lee.
        const character = raw as unknown as CharacterFields;
        let sheet: ComputedSheet | null = null;
        try {
          // El motor de Dart compilado a JS: acá no se recalcula ninguna regla.
          sheet = computeSheet(raw, catalog);
        } catch {
          // Un personaje que el motor no entiende no tira abajo a los demás.
        }
        // Las clases salen de la ficha calculada (en el orden en que se subió
        // de nivel); sin ella, la única que el personaje declara.
        const levels = sheet?.classLevels ?? { [character.classId]: 0 };
        return {
          character,
          sheet,
          createdAt,
          raceName: nameOf(catalog.races, character.raceId) ?? character.raceId,
          classes: Object.entries(levels).map(([id, level]) => ({
            name: nameOf(catalog.classes, id) ?? id,
            level,
          })),
          accent: accentOf(catalog, character.classId),
        };
      });
      return { kind: 'ready', entries, settings };
    })()
      .then(setState)
      .catch(() => {
        if (!controller.signal.aborted) setState({ kind: 'error' });
      });
    return () => controller.abort();
  }, [lang, attempt]);

  const ready = state.kind === 'ready' ? state : null;
  const sort = parseSortMode(ready?.settings.sortMode ?? 'name');
  const visible = useMemo(
    () => (ready ? visibleRoster(ready.entries, query, ready.settings, sort) : []),
    [ready, query, sort],
  );

  if (state.kind === 'loading') return <Notice title={t.rosterLoading} />;
  if (state.kind === 'error') {
    return (
      <Notice
        title={t.rosterErrorTitle}
        body={t.errorBody}
        action={<ActionButton onClick={retry}>{t.retry}</ActionButton>}
      />
    );
  }

  const { entries, settings } = state;
  const fallen = entries.filter(isFallen).length;
  const summary =
    fallen === 0
      ? t.rosterCount(entries.length)
      : `${t.rosterCount(entries.length)} · ${t.rosterFallen(fallen)}`;

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-wrap items-center justify-between gap-x-4 gap-y-3">
        <div>
          <h1 className="font-display text-[28px] leading-tight text-on-surface">{t.rosterTitle}</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant tabular-nums">{summary}</p>
        </div>
        {/* Crear no existe en React: lleva al asistente de Flutter. */}
        <ActionLink href={FLUTTER_HOME}>{t.rosterCreate}</ActionLink>
      </header>

      {entries.length > 0 && (
        <div
          role="search"
          className="card flex flex-wrap items-center gap-x-3 gap-y-2.5 p-3"
        >
          <div className="relative min-w-[200px] flex-1">
            <label htmlFor="roster-search" className="sr-only">
              {t.rosterSearchLabel}
            </label>
            <input
              id="roster-search"
              type="search"
              autoComplete="off"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t.rosterSearchHint}
              className="plaque h-10 w-full rounded-[var(--radius-nav)] px-3 pr-9 text-[13px] text-on-surface placeholder:text-text-muted"
            />
            {query !== '' && (
              <button
                type="button"
                aria-label={t.rosterClearSearch}
                title={t.rosterClearSearch}
                onClick={() => setQuery('')}
                className="absolute inset-y-0 right-0 flex w-9 items-center justify-center text-text-muted"
              >
                <span aria-hidden="true">✕</span>
              </button>
            )}
          </div>
          {/* El orden se muestra, no se edita: elegirlo es una escritura. */}
          <p className="plaque rounded-[var(--radius-nav)] px-3 py-2.5 text-[13px] text-on-surface-variant">
            <span className="text-text-muted">{t.sortLabel}: </span>
            <span data-field="sort">{t.sortModes[sort]}</span>
          </p>
        </div>
      )}

      {entries.length === 0 ? (
        <EmptyState
          kind="empty"
          message={t.rosterEmpty}
          hint={t.rosterEmptyHint}
          actions={<ActionLink href={FLUTTER_HOME}>{t.rosterCreate}</ActionLink>}
        />
      ) : visible.length === 0 ? (
        <EmptyState
          kind="no-match"
          message={t.rosterNoMatch(query.trim())}
          hint={t.rosterNoMatchHint}
          actions={<ActionButton onClick={() => setQuery('')}>{t.rosterClearSearch}</ActionButton>}
        />
      ) : (
        // `min(300px, 100%)`: en un teléfono de 320 px una columna de 300 más
        // los márgenes desbordaría; así la columna se achica y no hay scroll
        // horizontal. Es la grilla de `diseno-web.md` §7.3.
        <ul
          className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(min(300px,100%),1fr))]"
          data-field="roster"
        >
          {visible.map((entry) => (
            <RosterCard
              key={entry.character.id}
              entry={entry}
              favorite={entry.character.id === settings.favoriteCharacterId}
            />
          ))}
        </ul>
      )}
    </div>
  );
}
