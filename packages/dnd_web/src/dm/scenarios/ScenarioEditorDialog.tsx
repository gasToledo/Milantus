import { useEffect, useId, useMemo, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { ImagePlus, Search, X } from 'lucide-react';
import {
  saveScenario, scenarioCharacterPortrait, scenarioCharactersQuery, scenarioImageHref, scenarioQuery, scenariosQuery,
  type Scenario, type ScenarioCharacter,
} from '../../api/scenarios';
import { ApiError } from '../../api/client';
import { fold } from '../../codex/entries';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { Medallion } from '../../ui/Medallion';
import { AppBusyLabel } from '../../ui/status';

const ACCEPT = 'image/png,image/jpeg,image/webp,image/gif';

function readImage(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result);
      resolve(result.slice(result.indexOf(',') + 1));
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

/** La vista previa de una imagen recién elegida, que todavía no está en el
 *  servidor. La dirección se libera al cambiarla o al cerrar el diálogo. */
function useObjectUrl(file: File | null | undefined): string | null {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!(file instanceof File)) {
      setUrl(null);
      return;
    }
    const next = URL.createObjectURL(file);
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);
  return url;
}

const field =
  'w-full rounded-[var(--radius-input)] border border-hairline bg-plaque px-3 py-2 text-[14px] text-on-surface placeholder:text-text-muted';

export function ScenarioEditorDialog({ initial, onClose, onSaved }: {
  initial?: Scenario;
  onClose: () => void;
  onSaved?: (scenario: Scenario) => void;
}) {
  const t = useTexts();
  const client = useQueryClient();
  const coverId = useId();
  const [name, setName] = useState(initial?.name ?? '');
  const [description, setDescription] = useState(initial?.description ?? '');
  // `undefined`: la portada no se tocó; `null`: se quitó; un archivo: se cambió.
  const [image, setImage] = useState<File | null | undefined>();
  const [selected, setSelected] = useState(initial?.characterKeys ?? []);
  const [characterSearch, setCharacterSearch] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [dragging, setDragging] = useState(false);
  const characters = useQuery(scenarioCharactersQuery);
  const preview = useObjectUrl(image);

  const coverSrc = image instanceof File ? preview : image === undefined && initial?.hasImage ? scenarioImageHref(initial) : null;
  const hasCover = image instanceof File || (image === undefined && !!initial?.hasImage);

  const byKey = useMemo(() => new Map((characters.data ?? []).map((c) => [c.key, c])), [characters.data]);
  // Un vínculo vencido (el PNJ se borró, el jugador se fue) no se muestra ni se
  // reenvía: el servidor rechazaría guardar una clave que ya no alcanza.
  const chosen = selected.map((key) => byKey.get(key)).filter((c): c is ScenarioCharacter => c !== undefined);

  // Los PNJ primero y después cada campaña, con el buscador sobre el nombre y
  // sobre el grupo: buscar el nombre de la mesa trae a todos los suyos.
  const groups = useMemo(() => {
    const search = fold(characterSearch.trim());
    const result = new Map<string, ScenarioCharacter[]>();
    for (const c of characters.data ?? []) {
      const group = c.campaignName ?? t.dmLibraryNpcs;
      if (!fold(c.name).includes(search) && !fold(group).includes(search)) continue;
      result.set(group, [...(result.get(group) ?? []), c]);
    }
    const npcs = result.get(t.dmLibraryNpcs);
    result.delete(t.dmLibraryNpcs);
    const campaigns = [...result].sort(([a], [b]) => a.localeCompare(b));
    return npcs ? [[t.dmLibraryNpcs, npcs] as const, ...campaigns] : campaigns;
  }, [characters.data, characterSearch, t.dmLibraryNpcs]);

  const toggle = (key: string) => setSelected((previous) =>
    previous.includes(key) ? previous.filter((value) => value !== key) : [...previous, key],
  );

  const pick = (file: File | undefined) => {
    if (file && ACCEPT.split(',').includes(file.type)) setImage(file);
  };

  const save = async () => {
    if (busy || !name.trim()) return;
    setBusy(true);
    setError('');
    try {
      const saved = await saveScenario(initial?.id, {
        name: name.trim(),
        description: description.trim(),
        // Si la selección no cambió, el servidor conserva la que haya al guardar.
        characterKeys: selected === initial?.characterKeys || !characters.data
          ? undefined
          : chosen.map((character) => character.key),
        image: image instanceof File ? await readImage(image) : image,
      });
      client.setQueryData(scenarioQuery(saved.id).queryKey, saved);
      client.setQueryData(scenariosQuery.queryKey, (previous) => previous && [
        ...previous.filter((entry) => entry.id !== saved.id), saved,
      ].sort((a, b) => a.name.localeCompare(b.name)));
      void client.invalidateQueries({ queryKey: scenariosQuery.queryKey });
      onClose();
      onSaved?.(saved);
    } catch (e) {
      setError(e instanceof ApiError && e.status === 413 ? t.dmScenarioImageTooLarge : t.dmScenarioSaveError);
    } finally {
      setBusy(false);
    }
  };

  const fileInput = (
    <input
      type="file"
      accept={ACCEPT}
      className="sr-only"
      onChange={(event) => {
        pick(event.target.files?.[0]);
        event.target.value = '';
      }}
    />
  );

  return (
    <AppDialog
      open
      width={640}
      onOpenChange={(open) => { if (!open && !busy) onClose(); }}
      title={initial ? t.dmScenarioEdit : t.dmScenarioNew}
      actions={[
        { label: t.cancel, disabled: busy },
        { label: error ? t.retry : t.commonSave, primary: true, closes: false, onSelect: () => void save(), disabled: busy || !name.trim() },
      ]}
    >
      <div className="flex flex-col gap-[18px]">
        <div role="group" aria-labelledby={coverId} className="flex flex-col gap-1.5 text-[13.5px] text-on-surface-variant">
          <span id={coverId}>{t.dmScenarioCover}</span>
          {hasCover ? (
            <div key="cover" className="fade-in flex flex-wrap items-end gap-3.5">
              <div className="aspect-video w-64 max-w-full shrink-0 overflow-hidden rounded-[var(--radius-nav)] border border-hairline bg-plaque">
                {coverSrc && <img src={coverSrc} alt={t.dmScenarioCoverOf(name || (initial?.name ?? ''))} className="h-full w-full object-cover" />}
              </div>
              <div className="flex flex-col gap-2">
                <label className="inline-flex min-h-[38px] cursor-pointer items-center justify-center rounded-[var(--radius-nav)] border border-hairline px-3.5 text-[13.5px] text-on-surface transition-colors duration-[120ms] hover:border-gold has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-gold">
                  {t.dmScenarioChangeCover}
                  {fileInput}
                </label>
                <Button tone="secondary" onClick={() => setImage(null)}>{t.dmScenarioRemoveCover}</Button>
              </div>
            </div>
          ) : (
            <label
              key="drop"
              onDragOver={(event) => { event.preventDefault(); setDragging(true); }}
              onDragLeave={() => setDragging(false)}
              onDrop={(event) => {
                event.preventDefault();
                setDragging(false);
                pick(event.dataTransfer.files[0]);
              }}
              className={`fade-in flex h-[132px] cursor-pointer flex-col items-center justify-center gap-2 rounded-[var(--radius-card)] border border-dashed bg-plaque transition-colors duration-[120ms] hover:border-gold hover:text-gold has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-gold ${
                dragging ? 'border-gold text-gold' : 'border-hairline text-on-surface-variant'
              }`}
            >
              <ImagePlus size={28} strokeWidth={1.6} aria-hidden="true" />
              <span>{t.dmScenarioDropCover}</span>
              {fileInput}
            </label>
          )}
        </div>

        <label className="flex flex-col gap-1.5 text-[13.5px] text-on-surface-variant">
          {t.dmScenarioName}
          <input autoFocus required className={field} value={name} onChange={(event) => setName(event.target.value)} />
        </label>
        <label className="flex flex-col gap-1.5 text-[13.5px] text-on-surface-variant">
          {t.dmScenarioDescription}
          <textarea className={`${field} resize-y leading-[1.55]`} rows={5} value={description} onChange={(event) => setDescription(event.target.value)} />
        </label>

        <fieldset className="flex min-w-0 flex-col gap-2.5">
          <legend className="mb-1.5 text-[13.5px] text-on-surface-variant">{t.dmScenarioCharacters}</legend>
          {chosen.length > 0 && (
            <ul className="flex flex-wrap gap-1.5">
              {chosen.map((character) => (
                <li key={character.key} className="chip-in inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-pill)] bg-gold-soft pl-1 text-[13px] font-semibold text-gold">
                  <Medallion name={character.name} accent={null} size={24} portrait={scenarioCharacterPortrait(character)} />
                  {character.name}
                  <button
                    type="button"
                    aria-label={t.dmScenarioRemoveCharacter(character.name)}
                    title={t.dmScenarioRemoveCharacter(character.name)}
                    onClick={() => toggle(character.key)}
                    className="flex h-[26px] w-[26px] items-center justify-center rounded-full hover:bg-plaque"
                  >
                    <X size={13} strokeWidth={2.6} aria-hidden="true" />
                  </button>
                </li>
              ))}
            </ul>
          )}
          {characters.isError ? (
            <div className="flex flex-wrap items-center gap-3">
              <p role="alert" className="text-[13.5px] text-crimson">{t.dmScenarioCharactersError}</p>
              <Button tone="secondary" onClick={() => void characters.refetch()}>{t.retry}</Button>
            </div>
          ) : characters.isLoading ? (
            <AppBusyLabel label={t.dmScenarioCharactersLoading} />
          ) : (
            <>
              <div className="relative">
                <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-[11px] left-3 text-text-muted" />
                <input
                  type="search"
                  autoComplete="off"
                  className={`${field} pl-9`}
                  aria-label={t.dmScenarioSearchCharacters}
                  placeholder={t.dmScenarioSearchCharacters}
                  value={characterSearch}
                  onChange={(event) => setCharacterSearch(event.target.value)}
                />
              </div>
              <div className="max-h-[232px] overflow-y-auto rounded-[var(--radius-card)] border border-hairline bg-plaque p-1.5">
                {groups.length === 0 ? (
                  <p className="px-2.5 py-3.5 text-[14px] text-on-surface-variant">{t.catalogNoMatches}</p>
                ) : (
                  groups.map(([group, rows]) => (
                    <div key={group} role="group" aria-label={group} className="py-1">
                      <div className="eyebrow px-2.5 pt-1.5 pb-1">{group}</div>
                      {rows.map((character) => (
                        <label key={character.key} className="flex min-h-10 cursor-pointer items-center gap-2.5 rounded-[var(--radius-nav)] px-2.5 text-[14px] text-on-surface hover:bg-surface">
                          <input
                            type="checkbox"
                            className="h-4 w-4 accent-gold"
                            checked={selected.includes(character.key)}
                            onChange={() => toggle(character.key)}
                          />
                          <Medallion name={character.name} accent={null} size={26} portrait={scenarioCharacterPortrait(character)} />
                          <span className="min-w-0 break-words">{character.name}</span>
                        </label>
                      ))}
                    </div>
                  ))
                )}
              </div>
            </>
          )}
        </fieldset>
        {error && <p role="alert" className="text-[13.5px] text-crimson">{error}</p>}
      </div>
    </AppDialog>
  );
}
