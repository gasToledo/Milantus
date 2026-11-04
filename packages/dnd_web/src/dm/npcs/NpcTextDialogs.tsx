import { useMemo, useState } from 'react';
import { useNpcs } from '../../api/queries';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { normalizeTags } from './npc';

/** La voz: una o dos líneas para interpretarlo. Vacía se borra. */
export function NpcSpeechDialog({ current, onSubmit, onClose }: { current: string; onSubmit: (text: string) => void; onClose: () => void }) {
  const t = useTexts();
  const [text, setText] = useState(current);
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.npcSpeech}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, onSelect: () => onSubmit(text) }]}
    >
      <label className="flex flex-col gap-1.5">
        <span className="text-[12px] text-text-muted">{t.npcSpeechHint}</span>
        <textarea
          autoFocus
          rows={3}
          value={text}
          onChange={(e) => setText(e.target.value)}
          data-field="npc-speech"
          className="w-full resize-y rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 py-2 text-[14px] text-on-surface"
        />
      </label>
    </AppDialog>
  );
}

/** Un tag nuevo, con los que ya usa la biblioteca como atajo: así «Waterdeep» no
 *  termina escrito de tres formas. Si la biblioteca no carga, se escribe igual. */
export function NpcTagDialog({ present, onSubmit, onClose }: { present: readonly string[]; onSubmit: (tag: string) => void; onClose: () => void }) {
  const t = useTexts();
  const npcs = useNpcs();
  const [text, setText] = useState('');
  const query = text.trim().toLowerCase();
  const suggestions = useMemo(() => {
    const taken = new Set(present.map((p) => p.toLowerCase()));
    return normalizeTags((npcs.data ?? []).flatMap((e) => (e.npc.tags as string[] | undefined) ?? [])).filter((g) => !taken.has(g.toLowerCase()));
  }, [npcs.data, present]);
  const matching = suggestions.filter((g) => g.toLowerCase().includes(query));
  const submit = (tag: string) => {
    if (tag.trim() === '') return;
    onSubmit(tag.trim());
    onClose();
  };
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.npcAddTag}
      actions={[
        { label: t.cancel },
        { label: t.dmAddShort, primary: true, closes: false, disabled: query === '', onSelect: () => submit(text) },
      ]}
    >
      <div className="flex flex-col gap-3">
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.npcTagWord}</span>
          <input
            autoFocus
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && submit(text)}
            data-field="npc-tag"
            className="h-[38px] rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 text-[14px] text-on-surface"
          />
        </label>
        {matching.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {matching.map((g) => (
              <button
                key={g}
                type="button"
                onClick={() => submit(g)}
                data-tag-option={g}
                className="min-h-9 rounded-[var(--radius-pill)] border border-hairline px-3 text-[13px] text-on-surface-variant hover:border-gold hover:text-gold"
              >
                {g}
              </button>
            ))}
          </div>
        )}
      </div>
    </AppDialog>
  );
}
