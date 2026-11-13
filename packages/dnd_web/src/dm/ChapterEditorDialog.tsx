import { useState } from 'react';
import type { DmChapter } from '../api/client';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

/**
 * Nombre y objetivo de un capítulo (`chapter_editor_dialog.dart`): sirve para
 * crear y para editar. **El estado no se edita acá**: Empezar y Cerrar son las acciones con consecuencias, y por
 * eso el capítulo se guarda como `{ ...capítulo, cambios }` y nunca manda
 * `completed`. Si [onSubmit] falla el diálogo **no se cierra**, lo escrito se
 * conserva y «Guardar» pasa a «Reintentar».
 */
export function ChapterEditorDialog({
  title,
  initial,
  onSubmit,
  onClose,
}: {
  title: string;
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
        // uno planificado en Flutter, no los pierde (por eso el spread).
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
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmChapterGoal}</span>
          <textarea
            value={summary}
            onChange={(e) => setSummary(e.target.value)}
            placeholder={t.dmChapterGoalHint}
            data-field="chapter-goal"
            className={`${field} h-[108px] resize-none py-2 placeholder:text-text-muted`}
          />
        </label>
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmChapterSaveError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
