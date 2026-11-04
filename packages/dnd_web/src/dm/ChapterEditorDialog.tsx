import { useState } from 'react';
import { Minus, Plus, X } from 'lucide-react';
import { useSheetCatalog } from '../api/queries';
import type { ChapterItem, DmChapter } from '../api/client';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Eyebrow } from '../ui/data';
import { ItemPicker } from './ItemPicker';

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
  const lang = useLang();
  const catalog = useSheetCatalog(lang);
  const [name, setName] = useState(initial.name);
  const [summary, setSummary] = useState(initial.summary ?? '');
  const [level, setLevel] = useState(initial.grantsLevel ?? false);
  const [gold, setGold] = useState(initial.grantsGold ? String(initial.grantsGold) : '');
  // Lo que se reparte: los objetos del catálogo (con cantidad) y el texto libre
  // de antes, que aparece como «Sin catálogo». A quién le toca cada uno se
  // marca al cerrar, no acá.
  const [items, setItems] = useState<ChapterItem[]>(initial.grantsCatalog ?? []);
  const [free, setFree] = useState<string[]>(initial.grantsItems ?? []);
  const [picking, setPicking] = useState(false);
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
        grantsItems: free,
        grantsCatalog: items,
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
        <div className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmItems}</span>
          {(items.length > 0 || free.length > 0) && (
            <ul className="flex flex-col divide-y divide-hairline" data-field="chapter-items">
              {items.map((item, i) => (
                <li key={`${item.category}:${item.itemId}:${item.baseItemId ?? ''}`} className="flex items-center gap-2 py-1.5">
                  <span className="min-w-0 flex-1 truncate text-[14px] text-on-surface">
                    {item.name}
                    {item.homebrew && (
                      <i className="ml-2 rounded-[var(--radius-pill)] border border-gold px-2 text-[11px] text-gold not-italic">
                        {t.itemOwnTag}
                      </i>
                    )}
                  </span>
                  <span className="flex items-center gap-1">
                    <StepButton
                      label={t.itemQtyLess}
                      icon={Minus}
                      disabled={item.quantity <= 1}
                      onClick={() => setItems(items.map((o, j) => (j === i ? { ...o, quantity: o.quantity - 1 } : o)))}
                    />
                    <span className="num w-6 text-center text-[14px]">{item.quantity}</span>
                    <StepButton
                      label={t.itemQtyMore}
                      icon={Plus}
                      onClick={() => setItems(items.map((o, j) => (j === i ? { ...o, quantity: o.quantity + 1 } : o)))}
                    />
                  </span>
                  <StepButton label={t.itemRemove(item.name)} icon={X} onClick={() => setItems(items.filter((_, j) => j !== i))} />
                </li>
              ))}
              {free.map((text, i) => (
                <li key={`free:${text}`} className="flex items-center gap-2 py-1.5">
                  <span className="min-w-0 flex-1 truncate text-[14px] text-on-surface">
                    {text}
                    <i className="ml-2 rounded-[var(--radius-pill)] border border-hairline px-2 text-[11px] text-text-muted not-italic">
                      {t.itemFreeTag}
                    </i>
                  </span>
                  <StepButton label={t.itemRemove(text)} icon={X} onClick={() => setFree(free.filter((_, j) => j !== i))} />
                </li>
              ))}
            </ul>
          )}
          <Button
            tone="secondary"
            icon={Plus}
            data-action="add-chapter-item"
            disabled={!catalog.data}
            onClick={() => setPicking(true)}
            className="self-start"
          >
            {t.catalogAddTitle}
          </Button>
          <span className="text-[12px] text-text-muted">{t.dmItemsAssignHelp}</span>
        </div>
        {picking && catalog.data && (
          <ItemPicker
            catalog={catalog.data}
            chosen={items}
            onAdd={(item) => setItems((prev) => [...prev, item])}
            onClose={() => setPicking(false)}
          />
        )}
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmChapterSaveError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}

/** Un botón de ícono de la lista de objetos (− + quitar). */
function StepButton({
  label,
  icon: Icon,
  disabled,
  onClick,
}: {
  label: string;
  icon: typeof X;
  disabled?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      disabled={disabled}
      onClick={onClick}
      className="flex size-8 items-center justify-center rounded-[var(--radius-nav)] border border-hairline text-on-surface-variant hover:text-gold disabled:pointer-events-none disabled:opacity-40"
    >
      <Icon size={15} aria-hidden="true" />
    </button>
  );
}
