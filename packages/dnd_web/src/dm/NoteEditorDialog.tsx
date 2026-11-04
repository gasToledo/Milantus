import { useState } from 'react';
import type { DmChapter, DmNote } from '../api/client';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Select } from '../ui/primitives';

/**
 * Escribir o editar una nota del Cuaderno (`note_editor_dialog.dart`). Cuelga
 * de un capítulo: el `Select` lo dice con su estado, porque dos capítulos
 * pueden llamarse parecido. Se guarda como `{ ...nota, cambios }`. Si
 * [onSubmit] falla el diálogo **no se cierra** y «Guardar» pasa a «Reintentar».
 */
export function NoteEditorDialog({
  title,
  initial,
  chapters,
  onSubmit,
  onClose,
}: {
  title: string;
  initial: DmNote;
  chapters: readonly DmChapter[];
  onSubmit: (note: DmNote) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [chapterId, setChapterId] = useState(initial.chapterId);
  const [noteTitle, setNoteTitle] = useState(initial.title);
  const [body, setBody] = useState(initial.body ?? '');
  const [missingTitle, setMissingTitle] = useState(false);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  const stateWord = (c: DmChapter) =>
    c.state === 'completed' ? t.dmChapterClosed : c.state === 'active' ? t.dmChapterOpen : t.dmChapterPending;

  const save = async () => {
    if (busy) return;
    const trimmed = noteTitle.trim();
    if (trimmed === '') return setMissingTitle(true);
    setBusy(true);
    try {
      await onSubmit({ ...initial, chapterId, title: trimmed, body: body.trim() });
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
        <Select
          label={t.dmChapter}
          value={chapterId}
          onValueChange={setChapterId}
          options={chapters.map((c) => ({ value: c.id, label: `${c.name} · ${stateWord(c)}` }))}
          className="w-full justify-between"
        />
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.diaryTitleLabel}</span>
          <input
            autoFocus
            value={noteTitle}
            onChange={(e) => {
              setNoteTitle(e.target.value);
              setMissingTitle(false);
            }}
            aria-invalid={missingTitle}
            data-field="note-title"
            className={`${field} h-[38px] ${missingTitle ? '!border-crimson' : ''}`}
          />
        </label>
        {missingTitle && (
          <p role="alert" className="-mt-2 text-[13px] text-crimson">
            {t.dmNoteTitleRequired}
          </p>
        )}
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.invNoteTitle}</span>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            data-field="note-body"
            className={`${field} h-[130px] resize-none py-2`}
          />
          <span className="text-[12px] text-text-muted">{t.dmNoteMarkdownHint}</span>
        </label>
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmNoteSaveError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
