import { useState } from 'react';
import { Eye, Lock } from 'lucide-react';
import type { DmChapter, DmNote } from '../api/client';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Select } from '../ui/primitives';
import { Option } from '../ui/wizard';

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
  // Una nota nueva arranca privada: compartir es un acto explícito.
  const [shared, setShared] = useState(initial.shared ?? false);
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
      await onSubmit({ ...initial, chapterId, title: trimmed, body: body.trim(), shared });
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
        <fieldset className="m-0 flex min-w-0 flex-col gap-1.5 border-0 p-0">
          <legend className="mb-1.5 p-0 text-[12px] text-text-muted">{t.dmNoteWhoSees}</legend>
          <div role="radiogroup" aria-label={t.dmNoteWhoSees} className="grid grid-cols-2 gap-2">
            <Option
              id="private"
              selected={!shared}
              title={t.dmNoteDmOnly}
              trailing={<Lock size={16} aria-hidden="true" className="shrink-0 text-text-muted" />}
              onClick={() => setShared(false)}
            />
            <Option
              id="shared"
              selected={shared}
              title={t.dmNoteDmAndPlayers}
              trailing={<Eye size={16} aria-hidden="true" className="shrink-0 text-gold" />}
              onClick={() => setShared(true)}
            />
          </div>
        </fieldset>
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmNoteSaveError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
