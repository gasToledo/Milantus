import { useState } from 'react';
import { ApiError } from '../../api/client';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';

export function ConvertNpcDialog({ current, onConvert, onClose }: {
  current: string;
  onConvert: (name: string) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [name, setName] = useState(current);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<'failed' | 'gone' | null>(null);
  const trimmed = name.trim();
  const canConvert = trimmed !== '' && !busy && error !== 'gone';

  const convert = async () => {
    if (!canConvert) return;
    setBusy(true);
    setError(null);
    try {
      await onConvert(trimmed);
      onClose();
    } catch (failure) {
      setError(failure instanceof ApiError && failure.status === 404 ? 'gone' : 'failed');
      setBusy(false);
    }
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && !busy && onClose()}
      title={t.encConvertToNpc}
      actions={[
        { label: t.cancel, disabled: busy },
        { label: error === 'failed' ? t.retry : t.encConvert, primary: true, closes: false, disabled: !canConvert, onSelect: () => void convert() },
      ]}
    >
      <label className="flex flex-col gap-1.5">
        <span className="text-[12px] text-text-muted">{t.npcNameLabel}</span>
        <input
          autoFocus
          disabled={busy}
          value={name}
          onChange={(event) => setName(event.target.value)}
          onKeyDown={(event) => event.key === 'Enter' && void convert()}
          className="h-[38px] rounded-[var(--radius-nav)] border border-hairline bg-plaque px-3 text-[14px] text-on-surface"
        />
      </label>
      {error && (
        <p role="alert" className="mt-2 text-[13px] text-crimson">
          {error === 'gone' ? t.encConvertGone : t.encConvertFailed}
        </p>
      )}
    </AppDialog>
  );
}
