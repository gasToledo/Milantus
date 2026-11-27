import { useState } from 'react';
import { Check, ChevronDown, MapPin, Plus, Search, X } from 'lucide-react';
import { fold } from '../../codex/entries';
import { useTexts } from '../../i18n/context';
import { cx } from '../../ui/cx';
import { Popover, PopoverContent, PopoverTrigger } from '../../ui/primitives';
import { useMentionTargets, type MentionTarget } from '../mentions/targets';
import { ScenarioEditorDialog } from '../scenarios/ScenarioEditorDialog';

type Scene = Extract<MentionTarget, { kind: 'scene' }>;

const ROW = 'flex min-h-11 w-full items-center gap-2.5 rounded-[var(--radius-nav)] px-2 py-1 text-left';
const THUMB = 'flex h-[30px] w-10 shrink-0 items-center justify-center rounded-[6px] border border-hairline bg-plaque';

/**
 * Dónde se pelea, bajo el título del combate: «En La torre de Vhalun» en oro,
 * o «Elegir lugar» apagado. Abre la lista de escenarios con buscador, primero
 * los usados en la campaña (los mismos que el selector `@`), y deja crear uno
 * nuevo con lo buscado. Se cambia en cualquier momento; al terminar, el
 * servidor guarda el nombre en el Registro.
 */
export function PlacePicker({ campaignId, scenarioId, onChange }: {
  campaignId: string;
  scenarioId: string | null;
  onChange: (scenarioId: string | null) => void;
}) {
  const t = useTexts();
  const scenes = useMentionTargets(campaignId).filter((x): x is Scene => x.kind === 'scene');
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [creating, setCreating] = useState<string | null>(null);
  const chosen = scenes.find((s) => s.scenario.id === scenarioId);

  const q = fold(query.trim());
  const hits = scenes.filter((s) => q === '' || fold(s.name).includes(q));
  const groups = [
    { label: t.encPlaceUsed, rows: hits.filter((s) => s.near) },
    { label: t.mentionGroupLibrary, rows: hits.filter((s) => !s.near) },
  ].filter((g) => g.rows.length > 0);
  const canCreate = q !== '' && !scenes.some((s) => fold(s.name) === q);

  const pick = (id: string | null) => {
    if (id !== scenarioId) onChange(id);
    setOpen(false);
    setQuery('');
  };

  return (
    <>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <button
            type="button"
            aria-label={t.encPlaceLabel}
            data-field="combat-place"
            className={cx(
              '-ml-2 inline-flex min-h-8 items-center gap-1.5 self-start rounded-[var(--radius-pill)] border border-transparent px-2.5 pl-2 text-[13.5px] transition-colors duration-[120ms] ease-out hover:border-gold',
              chosen ? 'font-semibold text-gold' : 'text-on-surface-variant',
            )}
          >
            <MapPin size={16} aria-hidden="true" />
            {chosen ? t.encPlaceAt(chosen.name) : t.encPlacePick}
            <ChevronDown size={14} aria-hidden="true" />
          </button>
        </PopoverTrigger>
        <PopoverContent align="start" className="w-[360px] p-1.5">
          <div className="relative p-0.5 pb-1.5">
            <Search size={16} aria-hidden="true" className="pointer-events-none absolute top-[12px] left-3 text-text-muted" />
            <input
              type="search"
              autoFocus
              autoComplete="off"
              aria-label={t.encPlaceSearch}
              placeholder={t.encPlaceSearch}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              className="h-9 w-full rounded-[var(--radius-nav)] border border-hairline bg-plaque pr-3 pl-9 text-[13.5px] text-on-surface placeholder:text-text-muted"
            />
          </div>
          <div role="listbox" aria-label={t.encPlaceLabel} className="max-h-[300px] overflow-y-auto">
            {chosen && (
              <button type="button" role="option" aria-selected={false} onClick={() => pick(null)} className={cx(ROW, 'hover:bg-plaque')}>
                <span className={cx(THUMB, 'text-text-muted')}><X size={14} strokeWidth={2.2} aria-hidden="true" /></span>
                <span className="text-[14px] text-on-surface">{t.encPlaceNone}</span>
              </button>
            )}
            {groups.map((group) => (
              <div key={group.label} role="group" aria-label={group.label}>
                <div className="eyebrow px-2 pt-2 pb-1">{group.label}</div>
                {group.rows.map((scene) => {
                  const on = scene.scenario.id === scenarioId;
                  return (
                    <button
                      key={scene.key}
                      type="button"
                      role="option"
                      aria-selected={on}
                      onClick={() => pick(scene.scenario.id)}
                      className={cx(ROW, on ? 'bg-gold-soft' : 'hover:bg-plaque')}
                    >
                      <span className={cx(THUMB, 'text-text-muted')}><MapPin size={16} strokeWidth={1.8} aria-hidden="true" /></span>
                      <span className={cx('min-w-0 flex-1 truncate text-[14px]', on ? 'text-gold' : 'text-on-surface')}>{scene.name}</span>
                      {on && <Check size={16} strokeWidth={2.4} aria-hidden="true" className="shrink-0 text-gold" />}
                    </button>
                  );
                })}
              </div>
            ))}
            {groups.length === 0 && !canCreate && <p className="px-2 py-3 text-[13.5px] text-on-surface-variant">{t.catalogNoMatches}</p>}
            {canCreate && (
              <div className={cx(groups.length > 0 && 'mt-1 border-t border-hairline pt-1')}>
                <button
                  type="button"
                  onClick={() => {
                    setCreating(query.trim());
                    setOpen(false);
                  }}
                  className={cx(ROW, 'hover:bg-plaque')}
                >
                  <span className={cx(THUMB, 'text-gold')}><Plus size={16} strokeWidth={2.2} aria-hidden="true" /></span>
                  <span className="min-w-0 flex-1 truncate text-[14px] text-on-surface">{t.mentionCreateScene(query.trim())}</span>
                </button>
              </div>
            )}
          </div>
        </PopoverContent>
      </Popover>
      {creating !== null && (
        <ScenarioEditorDialog
          initialName={creating}
          onSaved={(scenario) => pick(scenario.id)}
          onClose={() => setCreating(null)}
        />
      )}
    </>
  );
}
