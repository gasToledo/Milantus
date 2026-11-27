import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { CheckCheck, EllipsisVertical, Pencil, Unlink } from 'lucide-react';
import { detachChapterScript, saveChapter, type DmChapter } from '../api/client';
import { queryKeys } from '../api/queries';
import { useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Tooltip,
} from '../ui/primitives';
import { ChapterEditorDialog } from './ChapterEditorDialog';
import { CloseChapterDialog } from './CloseChapterDialog';

export const chapterStatusLabel = (t: Texts, chapter: DmChapter): string =>
  chapter.state === 'completed' ? t.dmChapterClosed : chapter.state === 'active' ? t.dmChapterOpen : t.dmChapterPending;

/** El ⋮ de la cabecera de un capítulo, el mismo en Guion y en Registro, con sus
 *  diálogos. Un capítulo cerrado no se edita ni se cierra: sin guion que quitar,
 *  no hay menú. */
export function ChapterMenu({
  campaignId,
  chapter,
  hasScript,
  onClosed,
  onDetached,
}: {
  campaignId: string;
  chapter: DmChapter;
  hasScript: boolean;
  onClosed: (name: string) => void;
  onDetached?: () => void;
}) {
  const t = useTexts();
  const client = useQueryClient();
  const [open, setOpen] = useState<'edit' | 'close' | 'detach' | null>(null);
  const closed = chapter.state === 'completed';
  const close = () => setOpen(null);
  return (
    <>
      {(!closed || hasScript) && (
        <DropdownMenu>
          <Tooltip content={t.dmChapterActions}>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                aria-label={t.dmChapterActions}
                data-action="chapter-menu"
                className="inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-card)] border border-hairline text-on-surface-variant hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
              >
                <EllipsisVertical size={18} aria-hidden="true" />
              </button>
            </DropdownMenuTrigger>
          </Tooltip>
          <DropdownMenuContent align="end">
            {!closed && (
              <DropdownMenuItem onSelect={() => setOpen('edit')}>
                <Pencil size={15} aria-hidden="true" className="text-text-muted" />
                {t.dmEditChapter}
              </DropdownMenuItem>
            )}
            {hasScript && (
              <DropdownMenuItem onSelect={() => setOpen('detach')}>
                <Unlink size={15} aria-hidden="true" className="text-text-muted" />
                {t.scRemove}
              </DropdownMenuItem>
            )}
            {chapter.state === 'active' && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem onSelect={() => setOpen('close')}>
                  <CheckCheck size={15} aria-hidden="true" className="text-text-muted" />
                  {t.dmCloseChapter}
                </DropdownMenuItem>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      )}
      {open === 'edit' && (
        <ChapterEditorDialog
          title={t.dmEditChapter}
          campaignId={campaignId}
          initial={chapter}
          onSubmit={async (next) => {
            await saveChapter(campaignId, next);
            await client.invalidateQueries({ queryKey: queryKeys.campaignChapters(campaignId) });
          }}
          onClose={close}
        />
      )}
      {open === 'close' && <CloseChapterDialog campaignId={campaignId} chapter={chapter} onClosed={onClosed} onClose={close} />}
      {open === 'detach' && (
        <ConfirmDialog
          title={t.scRemove}
          body={t.scRemoveBody}
          confirmLabel={t.scRemove}
          errorText={t.scActionError}
          onConfirm={async () => {
            await detachChapterScript(campaignId, chapter.id);
            // El Registro agrupa por hito: sin guion vuelve a ser una lista.
            await client.invalidateQueries({ queryKey: queryKeys.chapterScript(campaignId, chapter.id) });
            void client.invalidateQueries({ queryKey: queryKeys.scripts });
            onDetached?.();
          }}
          onClose={close}
        />
      )}
    </>
  );
}
