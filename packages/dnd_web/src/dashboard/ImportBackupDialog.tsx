import { useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Upload } from 'lucide-react';
import { flushCharacterWrites } from '../api/characterSave';
import { ApiError } from '../api/client';
import { queryKeys } from '../api/queries';
import { waitForSettingsWrites } from '../api/settingsSave';
import { importBackup } from '../api/transfer';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

export function ImportBackupDialog({ onClose, onImported }: { onClose: () => void; onImported: (message: string) => void }) {
  const t = useTexts();
  const client = useQueryClient();
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const fileInput = useRef<HTMLInputElement>(null);

  const refresh = () => Promise.all([
    client.invalidateQueries({ queryKey: queryKeys.roster }),
    client.invalidateQueries({ queryKey: queryKeys.homebrew }),
    client.invalidateQueries({ queryKey: queryKeys.rosterSettings }),
  ]);

  const submit = async () => {
    if (!file || busy) return;
    setBusy(true);
    setError(undefined);
    try {
      await flushCharacterWrites();
      await waitForSettingsWrites();
    } catch {
      setError(t.transferUnsaved);
      setBusy(false);
      return;
    }
    try {
      const result = await importBackup(file);
      await refresh();
      onImported(t.transferImported(result.charactersImported, result.portraitsImported));
      onClose();
    } catch (e) {
      const status = e instanceof ApiError ? e.status : undefined;
      if (status === 400) setError(t.transferInvalid);
      else if (status === 409) setError(t.transferConflict);
      else if (status === 413) setError(t.transferTooLarge);
      else {
        await refresh();
        setFile(null);
        if (fileInput.current) fileInput.current.value = '';
        setError(t.transferImportError);
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => { if (!open && !busy) onClose(); }}
      title={t.transferImport}
      description={t.transferImportDescription}
      icon={Upload}
      actions={[
        { label: t.cancel, disabled: busy },
        { label: busy ? t.transferImporting : t.transferConfirm, primary: true, closes: false, disabled: !file || busy, onSelect: () => void submit() },
      ]}
    >
      <label className="flex flex-col gap-2 text-[14px]">
        {t.transferFile}
        <input
          ref={fileInput}
          type="file"
          accept=".zip,application/zip"
          disabled={busy}
          className="w-full min-w-0 rounded-[var(--radius-nav)] border border-hairline p-2"
          onChange={(event) => {
            setFile(event.currentTarget.files?.[0] ?? null);
            setError(undefined);
          }}
        />
      </label>
      {error && <p role="alert" className="mt-2 text-[13px] text-crimson">{error}</p>}
    </AppDialog>
  );
}
