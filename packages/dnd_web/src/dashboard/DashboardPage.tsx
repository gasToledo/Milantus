import { useMemo, useState } from 'react';
import { Plus, X } from 'lucide-react';
import { accentOf, nameOf } from '../api/catalog';
import { useRoster, useRosterSettings, useSheetCatalog } from '../api/queries';
import { computeSheet, type CharacterFields, type ComputedSheet } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { FLUTTER_HOME } from '../router';
import { Button, ButtonLink } from '../ui/Button';
import { SectionRule } from '../ui/data';
import { Tooltip } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { RosterCard } from './RosterCard';
import { isFallen, parseSortMode, visibleRoster, type RosterEntry } from './roster';

/**
 * El dashboard de solo lectura. El orden y el favorito se leen de los ajustes
 * de la cuenta y se muestran; cambiarlos (y crear, renombrar, borrar…) vive en
 * Flutter hasta que React escriba.
 */
export function DashboardPage() {
  const t = useTexts();
  const lang = useLang();
  const roster = useRoster();
  const settings = useRosterSettings();
  // Con el homebrew encima, como la ficha: si no, una tarjeta mostraría otra
  // CA que la ficha del mismo personaje.
  const catalog = useSheetCatalog(lang);
  const [query, setQuery] = useState('');

  // Cada ficha se calcula una vez por lista y catálogo, no en cada tecla del
  // buscador.
  const entries = useMemo((): RosterEntry[] | null => {
    if (!roster.data || !catalog.data) return null;
    const cat = catalog.data;
    return roster.data.map(({ character: raw, createdAt }): RosterEntry => {
      // `raw` es un `Character.toJson` que el servidor ya validó al guardarlo;
      // `CharacterFields` es el subconjunto que esta pantalla lee.
      const character = raw as unknown as CharacterFields;
      let sheet: ComputedSheet | null = null;
      try {
        // El motor de Dart compilado a JS: acá no se recalcula ninguna regla.
        sheet = computeSheet(raw, cat);
      } catch {
        // Un personaje que el motor no entiende no tira abajo a los demás.
      }
      // Las clases salen de la ficha calculada (en el orden en que se subió de
      // nivel); sin ella, la única que el personaje declara.
      const levels = sheet?.classLevels ?? { [character.classId]: 0 };
      return {
        character,
        sheet,
        createdAt,
        raceName: nameOf(cat.races, character.raceId) ?? character.raceId,
        classes: Object.entries(levels).map(([id, level]) => ({ name: nameOf(cat.classes, id) ?? id, level })),
        accent: accentOf(cat, character.classId),
      };
    });
  }, [roster.data, catalog.data]);

  const sort = parseSortMode(settings.data?.sortMode ?? 'name');
  const visible = useMemo(
    () => (entries && settings.data ? visibleRoster(entries, query, settings.data, sort) : []),
    [entries, settings.data, query, sort],
  );

  const failed = [roster, settings, ...catalog.queries].filter((q) => q.isError);
  let body;
  if (failed.length > 0) {
    body = (
      <AppErrorView
        title={t.rosterErrorTitle}
        message={t.errorBody}
        onRetry={() => failed.forEach((q) => q.refetch())}
      />
    );
  } else if (!entries || !settings.data) {
    body = <AppBusyLabel label={t.rosterLoading} />;
  } else if (entries.length === 0) {
    body = (
      <AppEmptyState
        kind="empty"
        message={t.rosterEmpty}
        hint={t.rosterEmptyHint}
        actions={<ButtonLink href={FLUTTER_HOME} icon={Plus}>{t.rosterCreate}</ButtonLink>}
      />
    );
  } else {
    body = (
      <>
        {visible.length === 0 ? (
          <AppEmptyState
            kind="no-match"
            message={t.rosterNoMatch(query.trim())}
            hint={t.rosterNoMatchHint}
            actions={
              <Button tone="secondary" icon={X} onClick={() => setQuery('')}>
                {t.rosterClearSearch}
              </Button>
            }
          />
        ) : (
          // `min(300px, 100%)`: en un teléfono de 360 px una columna de 300 más
          // los márgenes desbordaría; así se achica y no hay scroll
          // horizontal. Es la grilla de `diseno-web.md` §7.3, que llena todo
          // el ancho con tantas columnas como entren.
          <ul
            className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(min(300px,100%),1fr))]"
            data-field="roster"
          >
            {visible.map((entry) => (
              <RosterCard
                key={entry.character.id}
                entry={entry}
                favorite={entry.character.id === settings.data.favoriteCharacterId}
              />
            ))}
          </ul>
        )}
      </>
    );
  }

  const fallen = entries?.filter(isFallen).length ?? 0;
  return (
    <div className="flex flex-col gap-5">
      {/* La barra de acciones del lienzo: título, buscador, orden y «Crear»
          en una fila que se envuelve sola en un teléfono. */}
      <header className="flex flex-wrap items-center gap-3.5">
        <div className="min-w-0 flex-[1_1_220px]">
          {/* El título está siempre, también mientras carga: un h1 por
              pantalla y el lector sabe dónde está desde el primer momento. */}
          <h1 className="font-display text-[30px] leading-tight text-on-surface">{t.rosterTitle}</h1>
          {entries && (
            <p className="mt-1 text-[13px] text-on-surface-variant tabular-nums">
              {fallen === 0
                ? t.rosterCount(entries.length)
                : `${t.rosterCount(entries.length)} · ${t.rosterFallen(fallen)}`}
            </p>
          )}
        </div>
        {entries && entries.length > 0 && (
          <div role="search" className="flex min-w-0 flex-[1_1_320px] flex-wrap items-center gap-2.5 shell:max-w-[460px]">
            <div className="relative min-w-[min(200px,100%)] flex-1">
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
                className="h-9 w-full rounded-[var(--radius-pill)] border border-hairline bg-plaque px-4 pr-9 text-[13px] text-on-surface placeholder:text-text-muted"
              />
              {query !== '' && (
                <Tooltip content={t.rosterClearSearch}>
                  <button
                    type="button"
                    aria-label={t.rosterClearSearch}
                    onClick={() => setQuery('')}
                    className="absolute inset-y-0 right-1 flex w-8 items-center justify-center text-text-muted hover:text-on-surface"
                  >
                    <X size={16} aria-hidden="true" />
                  </button>
                </Tooltip>
              )}
            </div>
            {/* El orden se muestra, no se edita: elegirlo es una escritura. */}
            <p className="flex h-9 items-center rounded-[var(--radius-pill)] border border-hairline px-4 text-[13px] text-on-surface">
              <span className="text-text-muted">{t.sortLabel}:&nbsp;</span>
              <span data-field="sort">{t.sortModes[sort]}</span>
            </p>
          </div>
        )}
        {/* Crear no existe en React: lleva al asistente de Flutter. */}
        <ButtonLink href={FLUTTER_HOME} icon={Plus} tone="soft" shape="pill">
          {t.rosterCreate}
        </ButtonLink>
      </header>
      <SectionRule className="my-0" />
      {body}
    </div>
  );
}
