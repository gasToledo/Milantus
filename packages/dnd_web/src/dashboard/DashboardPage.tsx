import { useCallback, useMemo, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ChevronDown, Plus, X } from 'lucide-react';
import { dropPending } from '../api/characterSave';
import { deleteCharacter, saveCharacter, type RosterSettings, type StoredCharacter } from '../api/client';
import { queryKeys, useRoster, useRosterSettings, useSheetCatalog } from '../api/queries';
import { patchSettings } from '../api/settingsSave';
import { actOn, migrateCharacter, type CharacterJson } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { creationHref } from '../router';
import { Button, ButtonLink } from '../ui/Button';
import { SectionRule } from '../ui/data';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
  Toast,
  ToastProvider,
  ToastViewport,
  Tooltip,
} from '../ui/primitives';
import { useReorder } from '../ui/reorder';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { DeleteDialog } from './DeleteDialog';
import { RenameDialog } from './RenameDialog';
import { RosterCard } from './RosterCard';
import {
  isFallen,
  moveGroup,
  movedOrder,
  parseSortMode,
  SORT_MODES,
  toRosterEntry,
  visibleRoster,
  type RosterEntry,
} from './roster';

/**
 * El dashboard. El orden y el favorito se leen de los ajustes de la cuenta y se
 * escriben desde acá (el selector de orden, arrastrar una tarjeta y el menú ⋮).
 * Renombrar, borrar, rehacer y el ejemplo se suman en las partes siguientes del
 * paso 5f.
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
  const client = useQueryClient();
  const [toastKey, setToastKey] = useState(0);
  const [toastOpen, setToastOpen] = useState(false);

  // Lo elegido se ve al instante y el guardado va después. Si falla, el cambio
  // queda en pantalla hasta la próxima carga, como en Flutter: revertirlo
  // desordenaría la lista bajo las manos de quien la está usando.
  const saveSettings = useCallback(
    async (patch: Partial<RosterSettings>) => {
      await client.cancelQueries({ queryKey: queryKeys.rosterSettings });
      client.setQueryData<RosterSettings>(queryKeys.rosterSettings, (old) => old && { ...old, ...patch });
      try {
        await patchSettings(patch);
      } catch {
        setToastKey((k) => k + 1);
        setToastOpen(true);
      }
    },
    [client],
  );

  // Cada ficha se calcula una vez por lista y catálogo, no en cada tecla del
  // buscador.
  const entries = useMemo((): RosterEntry[] | null => {
    if (!roster.data || !catalog.data) return null;
    const cat = catalog.data;
    return roster.data.map(({ character, createdAt }) => toRosterEntry(character, createdAt, cat));
  }, [roster.data, catalog.data]);

  const sort = parseSortMode(settings.data?.sortMode ?? 'name');
  const visible = useMemo(
    () => (entries && settings.data ? visibleRoster(entries, query, settings.data, sort) : []),
    [entries, settings.data, query, sort],
  );

  // Mover con la lista filtrada perdería el lugar de las tarjetas ocultas.
  const canMove = query.trim() === '';
  const favoriteId = settings.data?.favoriteCharacterId ?? null;
  const entryById = useMemo(() => new Map((entries ?? []).map((e) => [e.character.id, e])), [entries]);
  const visibleIds = useMemo(() => visible.map((e) => e.character.id), [visible]);
  const groupOf = (id: string) => {
    const e = entryById.get(id);
    return e ? moveGroup(e, favoriteId) : null;
  };
  const reorder = useReorder({
    ids: visibleIds,
    onMove: (from, to) => {
      // El orden al mostrar deja al favorito arriba y a los caídos al final:
      // cruzar de grupo no tendría efecto.
      if (groupOf(from) !== groupOf(to)) return;
      void saveSettings({ characterOrder: movedOrder(visibleIds, from, to), sortMode: 'manual' });
    },
  });

  const [renaming, setRenaming] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);

  type Doc = CharacterJson & { id: string };
  const replaceInRoster = async (update: (list: StoredCharacter[]) => StoredCharacter[]) => {
    // Un pedido de la lista en vuelo traería la copia de antes.
    await client.cancelQueries({ queryKey: queryKeys.roster });
    client.setQueryData<StoredCharacter[]>(queryKeys.roster, (list) => list && update(list));
  };

  // Renombrar no usa la cola de guardado: se espera al servidor para poder
  // dejar el diálogo abierto si falla. La copia de la caché ya incluye lo que
  // esté pendiente, así que se descarta la cola y se manda esa.
  const rename = async (id: string, name: string) => {
    const raw = client.getQueryData<StoredCharacter[]>(queryKeys.roster)?.find((s) => s.character.id === id)?.character;
    if (!raw || !catalog.data) throw new Error('sin ficha');
    const { character } = actOn(migrateCharacter(raw), catalog.data, { type: 'rename', name });
    await dropPending(id);
    await saveCharacter(character as Doc);
    await replaceInRoster((list) => list.map((s) => (s.character.id === id ? { ...s, character } : s)));
  };

  // Favorito y orden no se tocan: se reconcilian al mostrar, como en Flutter.
  const remove = async (id: string) => {
    await dropPending(id);
    await deleteCharacter(id);
    await replaceInRoster((list) => list.filter((s) => s.character.id !== id));
    void client.invalidateQueries({ queryKey: queryKeys.roster });
    // El botón que abrió el diálogo ya no existe: el foco pasa al título.
    setTimeout(() => titleRef.current?.focus(), 0);
  };

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
        actions={<ButtonLink href={creationHref()} internal icon={Plus}>{t.rosterCreate}</ButtonLink>}
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
            {visible.map((entry) => {
              const id = entry.character.id;
              const favorite = id === settings.data.favoriteCharacterId;
              return (
                <RosterCard
                  key={id}
                  entry={entry}
                  favorite={favorite}
                  onToggleFavorite={() => void saveSettings({ favoriteCharacterId: favorite ? null : id })}
                  onRename={() => setRenaming(id)}
                  onDelete={() => setDeleting(id)}
                  reorder={
                    canMove && !favorite
                      ? {
                          item: reorder.item(id),
                          grip: reorder.grip(id),
                          dragging: reorder.dragging === id,
                          // La marca solo en el mismo grupo: soltar en otro no hace nada.
                          over: reorder.over === id && reorder.dragging !== null && groupOf(reorder.dragging) === groupOf(id),
                        }
                      : undefined
                  }
                />
              );
            })}
          </ul>
        )}
      </>
    );
  }

  const fallen = entries?.filter(isFallen).length ?? 0;
  return (
    <ToastProvider>
      <div className="flex flex-col gap-5">
        {/* La barra de acciones del lienzo: título, buscador, orden y «Crear»
            en una fila que se envuelve sola en un teléfono. */}
        <header className="flex flex-wrap items-center gap-3.5">
          <div className="min-w-0 flex-[1_1_220px]">
            {/* El título está siempre, también mientras carga: un h1 por
                pantalla y el lector sabe dónde está desde el primer momento. */}
            <h1 ref={titleRef} tabIndex={-1} className="font-display text-[30px] leading-tight text-on-surface outline-none">{t.rosterTitle}</h1>
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
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <button
                    type="button"
                    className="flex h-9 items-center rounded-[var(--radius-pill)] border border-hairline pr-3 pl-4 text-[13px] text-on-surface data-[state=open]:border-gold"
                  >
                    <span className="text-text-muted">{t.sortLabel}:&nbsp;</span>
                    <span data-field="sort">{t.sortModes[sort]}</span>
                    <ChevronDown size={15} aria-hidden="true" className="ml-1.5 text-text-muted" />
                  </button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuRadioGroup
                    value={sort}
                    onValueChange={(mode) => void saveSettings({ sortMode: parseSortMode(mode) })}
                  >
                    {SORT_MODES.map((mode) => (
                      <DropdownMenuRadioItem key={mode} value={mode}>
                        {t.sortModes[mode]}
                      </DropdownMenuRadioItem>
                    ))}
                  </DropdownMenuRadioGroup>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          )}
          <ButtonLink href={creationHref()} internal icon={Plus} tone="soft" shape="pill">
            {t.rosterCreate}
          </ButtonLink>
        </header>
        <SectionRule className="my-0" />
        {body}
      </div>
      {renaming && entryById.get(renaming) && (
        <RenameDialog
          current={entryById.get(renaming)!.character.name}
          onSubmit={(name) => rename(renaming, name)}
          onClose={() => setRenaming(null)}
        />
      )}
      {deleting && entryById.get(deleting) && (
        <DeleteDialog
          name={entryById.get(deleting)!.character.name}
          onConfirm={() => remove(deleting)}
          onClose={() => setDeleting(null)}
        />
      )}
      <Toast key={toastKey} tone="error" message={t.sortSaveError} open={toastOpen} onOpenChange={setToastOpen} />
      <ToastViewport />
    </ToastProvider>
  );
}
