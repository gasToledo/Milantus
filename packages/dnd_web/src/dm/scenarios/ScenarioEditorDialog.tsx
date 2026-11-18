import { useId, useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  saveScenario, scenarioCharactersQuery, scenarioImageHref, scenarioQuery, scenariosQuery, type Scenario,
} from '../../api/scenarios';
import { ApiError } from '../../api/client';
import { fold } from '../../codex/entries';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { Button } from '../../ui/Button';
import { AppBusyLabel } from '../../ui/status';

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

const field = 'plaque w-full px-3 py-2 text-sm text-on-surface';

export function ScenarioEditorDialog({ initial, onClose, onSaved }: {
  initial?: Scenario;
  onClose: () => void;
  onSaved?: (scenario: Scenario) => void;
}) {
  const t = useTexts();
  const client = useQueryClient();
  const inputId = useId();
  const fileInput = useRef<HTMLInputElement>(null);
  const [name, setName] = useState(initial?.name ?? '');
  const [description, setDescription] = useState(initial?.description ?? '');
  const [image, setImage] = useState<File | null | undefined>();
  const [selected, setSelected] = useState(initial?.characterKeys ?? []);
  const [characterSearch, setCharacterSearch] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [showCharacters, setShowCharacters] = useState(false);
  const characters = useQuery({ ...scenarioCharactersQuery, enabled: showCharacters });
  const search = fold(characterSearch.trim());
  const options = characters.data?.filter(({ name, campaignName }) =>
    fold(name).includes(search) || (campaignName !== null && fold(campaignName).includes(search)),
  ) ?? [];

  const toggle = (key: string) => setSelected((previous) =>
    previous.includes(key) ? previous.filter((value) => value !== key) : [...previous, key],
  );

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
          : selected.filter((key) => characters.data.some((character) => character.key === key)),
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

  return (
    <AppDialog
      open
      onOpenChange={(open) => { if (!open && !busy) onClose(); }}
      title={initial ? t.dmScenarioEdit : t.dmScenarioNew}
      actions={[
        { label: t.cancel, disabled: busy },
        { label: error ? t.retry : t.commonSave, primary: true, closes: false, onSelect: () => void save(), disabled: busy || !name.trim() },
      ]}
    >
      <div className="flex flex-col gap-4">
        <label className="flex flex-col gap-1.5 text-sm">
          {t.dmScenarioName}
          <input autoFocus required className={field} value={name} onChange={(event) => setName(event.target.value)} />
        </label>
        <label className="flex flex-col gap-1.5 text-sm">
          {t.dmScenarioDescription}
          <textarea className={field} rows={4} value={description} onChange={(event) => setDescription(event.target.value)} />
        </label>
        <div className="flex flex-col gap-1.5 text-sm">
          <label htmlFor={inputId}>{t.dmScenarioCover}</label>
          {image === undefined && initial?.hasImage && (
            <img src={scenarioImageHref(initial)} alt={t.dmScenarioCoverOf(initial.name)} className="mb-1 h-24 max-w-full self-start rounded-[var(--radius-nav)] object-contain" />
          )}
          <input
            id={inputId}
            ref={fileInput}
            type="file"
            className={field}
            accept="image/png,image/jpeg,image/webp,image/gif"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) setImage(file);
            }}
          />
          {(image instanceof File || (image === undefined && initial?.hasImage)) && (
            <Button tone="secondary" className="self-start" onClick={() => {
              setImage(null);
              if (fileInput.current) fileInput.current.value = '';
            }}>{t.dmScenarioRemoveCover}</Button>
          )}
        </div>
        <fieldset className="min-w-0 space-y-2">
          <legend className="mb-1.5 text-sm">{t.dmScenarioCharacters}</legend>
          {!showCharacters ? (
            <Button tone="secondary" onClick={() => setShowCharacters(true)}>{t.dmScenarioChooseCharacters}</Button>
          ) : characters.isError ? (
            <>
              <p role="alert" className="text-sm text-crimson">{t.dmScenarioCharactersError}</p>
              <Button tone="secondary" onClick={() => void characters.refetch()}>{t.retry}</Button>
            </>
          ) : characters.isLoading ? (
            <AppBusyLabel label={t.dmScenarioCharactersLoading} />
          ) : (
            <>
              <input
                type="search"
                className={field}
                aria-label={t.dmScenarioSearchCharacters}
                placeholder={t.dmScenarioSearchCharacters}
                value={characterSearch}
                onChange={(event) => setCharacterSearch(event.target.value)}
              />
              {options.length === 0 ? (
                <p className="text-sm text-text-muted">{t.catalogNoMatches}</p>
              ) : (
                <ul className="max-h-44 space-y-1 overflow-y-auto">
                  {options.map(({ key, name, campaignName }) => (
                    <li key={key}>
                      <label className="flex cursor-pointer items-center gap-2 rounded-[var(--radius-nav)] px-2 py-1.5 text-sm hover:bg-plaque">
                        <input
                          type="checkbox"
                          className="accent-gold"
                          checked={selected.includes(key)}
                          onChange={() => toggle(key)}
                        />
                        <span className="min-w-0 flex-1 break-words">{name}</span>
                        <span className="text-xs text-text-muted">{campaignName ?? t.dmLibraryNpcs}</span>
                      </label>
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}
        </fieldset>
        {error && <p role="alert" className="text-sm text-crimson">{error}</p>}
      </div>
    </AppDialog>
  );
}
