import { useState } from 'react';
import { FolderInput } from 'lucide-react';
import type { DmChapter } from '../api/client';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Option } from '../ui/wizard';

/**
 * Elegir el capítulo de un combate o una subida de nivel que quedó suelta.
 * Abre **sin nada elegido** y «Mover» queda apagado hasta tocar uno: nada
 * avanza solo. Están todos los capítulos, los cerrados también —un combate
 * suelto viejo casi siempre es de uno que ya cerró—, con su estado al lado.
 * Si [onMove] falla el diálogo no se cierra: queda el aviso y «Reintentar».
 */
export function MoveToChapterDialog({
  entryTitle,
  chapters,
  onMove,
  onClose,
}: {
  entryTitle: string;
  chapters: readonly DmChapter[];
  onMove: (chapterId: string) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [picked, setPicked] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const stateWord = (c: DmChapter) =>
    c.state === 'completed' ? t.dmChapterClosed : c.state === 'active' ? t.dmChapterOpen : t.dmChapterPending;

  const move = async () => {
    if (!picked || busy) return;
    setBusy(true);
    try {
      await onMove(picked);
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.dmMoveToChapter}
      icon={FolderInput}
      description={entryTitle}
      actions={[
        { label: t.cancel },
        {
          label: failed ? t.retry : t.dmMove,
          primary: true,
          closes: false,
          disabled: !picked || busy,
          onSelect: () => void move(),
        },
      ]}
    >
      <div role="radiogroup" aria-label={t.dmChapter} className="flex flex-col gap-2" data-field="move-chapter">
        {chapters.map((c) => (
          <Option
            key={c.id}
            id={c.id}
            selected={picked === c.id}
            title={c.name}
            trailing={<span className="shrink-0 text-[12px] text-text-muted">{stateWord(c)}</span>}
            onClick={() => setPicked(c.id)}
          />
        ))}
      </div>
      {failed && (
        <p role="alert" className="mt-2 text-[13px] text-crimson">
          {t.dmMoveError}
        </p>
      )}
    </AppDialog>
  );
}
