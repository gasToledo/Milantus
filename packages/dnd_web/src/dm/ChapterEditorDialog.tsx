import { useState } from 'react';
import type { DmChapter } from '../api/client';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Eyebrow } from '../ui/data';

/**
 * Nombre, objetivo y qué reparte al cerrarse un capítulo
 * (`chapter_editor_dialog.dart`): sirve para crear y para editar. **El estado
 * no se edita acá**: Empezar y Cerrar son las acciones con consecuencias, y por
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
  const [level, setLevel] = useState(initial.grantsLevel ?? false);
  const [gold, setGold] = useState(initial.grantsGold ? String(initial.grantsGold) : '');
  // Un ítem por línea: la forma más corta de escribir una lista corta a mano.
  const [items, setItems] = useState((initial.grantsItems ?? []).join('\n'));
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
        grantsLevel: level,
        grantsGold: Number(gold) || 0,
        grantsItems: items
          .split('\n')
          .map((line) => line.trim())
          .filter((line) => line !== ''),
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
            className={`${field} h-[84px] resize-none py-2 placeholder:text-text-muted`}
          />
        </label>

        {/* Lo que sigue es lo que se reparte al cerrar, y nada de esto lo aplica
            la app: al cerrar solo se les avisa a los jugadores. */}
        <Eyebrow className="mt-1">{t.dmOnCloseCarry}</Eyebrow>
        <label className="flex items-start gap-2.5">
          <input
            type="checkbox"
            checked={level}
            onChange={(e) => setLevel(e.target.checked)}
            data-field="chapter-level"
            className="mt-0.5 size-4 accent-gold"
          />
          <span className="flex flex-col">
            <b className="text-[14px] font-medium text-on-surface">{t.dmOneLevel}</b>
            <small className="text-[12px] text-text-muted">{t.dmLevelUpNote}</small>
          </span>
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmGoldEach}</span>
          <span className="flex items-center gap-2">
            <input
              value={gold}
              // Solo dígitos: así el campo no puede producir oro negativo y no
              // hace falta ningún mensaje de error explicándolo.
              onChange={(e) => setGold(e.target.value.replace(/\D/g, ''))}
              inputMode="numeric"
              placeholder="0"
              data-field="chapter-gold"
              className={`${field} h-[38px] min-w-0 flex-1`}
            />
            <em className="text-[13px] text-text-muted not-italic">{t.coinAbbrGold}</em>
          </span>
          <span className="text-[12px] text-text-muted">{t.dmGoldHelper}</span>
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmItems}</span>
          <textarea
            value={items}
            onChange={(e) => setItems(e.target.value)}
            placeholder={t.dmItemsHint}
            data-field="chapter-items"
            className={`${field} h-[84px] resize-none py-2 placeholder:text-text-muted`}
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
