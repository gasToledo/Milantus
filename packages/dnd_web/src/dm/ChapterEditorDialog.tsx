import { useState } from 'react';
import type { DmChapter } from '../api/client';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { MentionPanel } from './mentions/MentionPanel';
import { MentionTextarea } from './mentions/MentionTextarea';
import { useMentionTargets, type MentionTarget } from './mentions/targets';

/**
 * Nombre y objetivo de un capítulo (`chapter_editor_dialog.dart`): sirve para
 * crear y para editar. **El estado no se edita acá**: Empezar y Cerrar son las acciones con consecuencias, y por
 * eso el capítulo se guarda como `{ ...capítulo, cambios }` y nunca manda
 * `completed`. Si [onSubmit] falla el diálogo **no se cierra**, lo escrito se
 * conserva y «Guardar» pasa a «Reintentar».
 */
export function ChapterEditorDialog({
  title,
  campaignId,
  initial,
  onSubmit,
  onClose,
}: {
  title: string;
  campaignId: string;
  initial: DmChapter;
  onSubmit: (chapter: DmChapter) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [name, setName] = useState(initial.name);
  const [summary, setSummary] = useState(initial.summary ?? '');
  const [missingName, setMissingName] = useState(false);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  const targets = useMentionTargets(campaignId);
  const [panel, setPanel] = useState<MentionTarget | null>(null);

  const save = async () => {
    if (busy) return;
    const trimmed = name.trim();
    if (trimmed === '') return setMissingName(true);
    setBusy(true);
    try {
      await onSubmit({
        ...initial,
        name: trimmed,
        summary: summary.trim(),
        // El nivel, el oro y los objetos se deciden al cerrar (`CloseChapterDialog`).
        // Acá se conservan los de `initial` sin tocarlos: un capítulo viejo, o
        // uno planificado en la versión anterior, no los pierde (por eso el spread).
      });
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  const field = 'text-[14px] text-on-surface rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3';
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={title}
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : t.commonSave, primary: true, closes: false, disabled: busy, onSelect: () => void save() },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmChapterName}</span>
          <input
            autoFocus
            value={name}
            onChange={(e) => {
              setName(e.target.value);
              setMissingName(false);
            }}
            onKeyDown={(e) => e.key === 'Enter' && void save()}
            aria-invalid={missingName}
            data-field="chapter-name"
            className={`${field} h-[38px] ${missingName ? '!border-crimson' : ''}`}
          />
        </label>
        {missingName && (
          <p role="alert" className="-mt-2 text-[13px] text-crimson">
            {t.dmChapterNameRequired}
          </p>
        )}
        <div className="flex flex-col gap-1.5">
          <label htmlFor="chapter-goal" className="text-[12px] text-text-muted">{t.dmChapterGoal}</label>
          <MentionTextarea
            id="chapter-goal"
            value={summary}
            onChange={setSummary}
            targets={targets}
            campaignId={campaignId}
            onOpenMention={(target) => setPanel((open) => (open?.key === target.key ? null : target))}
            openKey={panel?.key ?? null}
            placeholder={t.dmChapterGoalHint}
            data-field="chapter-goal"
            className={`${field} h-[108px] w-full resize-none py-2 placeholder:text-text-muted`}
          />
        </div>
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmChapterSaveError}
          </p>
        )}
      </div>
      <MentionPanel target={panel} inEditor onClose={() => setPanel(null)} />
    </AppDialog>
  );
}
