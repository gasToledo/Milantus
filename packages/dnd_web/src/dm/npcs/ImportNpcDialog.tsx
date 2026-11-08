import { useEffect, useMemo, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { CircleAlert, TriangleAlert, Upload } from 'lucide-react';
import { ApiError, type DmCampaign } from '../../api/client';
import { queryKeys, useSheetCatalog } from '../../api/queries';
import { importNpc, previewNpcImport, type NpcImportPreview } from '../../api/transfer';
import { npcImportMissing, npcViews, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { Medallion } from '../../ui/Medallion';
import { Select } from '../../ui/primitives';
import { AppBusyLabel } from '../../ui/status';
import { npcTypeLine } from './npc';

/** El valor de «Ninguna»: Radix no admite un valor vacío en una opción. */
const NONE = '__none__';

/**
 * «Importar PNJ» (`ImportNpcDialog` de Flutter): elegir el archivo muestra
 * enseguida qué trae —sin botón «Leer»—, y recién «Importar» escribe algo.
 * El servidor lee el ZIP (`POST /api/npcs/import/preview`, que no guarda nada)
 * y sirve igual para el de un PNJ y para el de **un** personaje exportado
 * desde «Mis personajes», que entra como PNJ con ficha.
 *
 * Si la ficha usa contenido oficial que esta instalación no tiene, lo dice el
 * motor (`npcImportMissing`) y no deja importar: ni siquiera se le pregunta al
 * servidor. Importar nunca reemplaza nada: crea una copia.
 */
export function ImportNpcDialog({
  campaigns,
  onClose,
  onImported,
}: {
  campaigns: readonly DmCampaign[];
  onClose: () => void;
  onImported: (name: string) => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const catalog = useSheetCatalog(lang);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<NpcImportPreview | null>(null);
  const [reading, setReading] = useState(false);
  const [fileError, setFileError] = useState<string>();
  const [campaignId, setCampaignId] = useState(NONE);
  const [busy, setBusy] = useState(false);
  const [importError, setImportError] = useState<string>();
  // Cada elección de archivo tiene su número: la respuesta de uno anterior
  // —que llega tarde— no pisa la vista previa del que se eligió después.
  const reads = useRef(0);
  useEffect(() => () => void (reads.current = -1), []);

  const choose = async (next: File | null) => {
    const mine = ++reads.current;
    setFile(next);
    setPreview(null);
    setFileError(undefined);
    setImportError(undefined);
    setCampaignId(NONE);
    if (!next) {
      setReading(false);
      return;
    }
    setReading(true);
    try {
      const result = await previewNpcImport(next);
      if (reads.current === mine) setPreview(result);
    } catch (e) {
      if (reads.current !== mine) return;
      if (e instanceof ApiError && (e.status === 413 || e.code === 'unsupported_version')) {
        setFileError(e.status === 413 ? t.npcFileTooLarge : t.npcNewerVersion);
      } else {
        setFileError(t.npcFileInvalid);
      }
    } finally {
      if (reads.current === mine) setReading(false);
    }
  };

  // La línea de tipo y lo que falta salen del motor, igual que en Flutter: el
  // PNJ del archivo se mira con la misma maquinaria que uno de la Biblioteca.
  const view = useMemo<NpcView | null>(() => {
    if (!preview || !catalog.data) return null;
    return npcViews([{ npc: preview.npc, character: preview.character }], catalog.data)[0] ?? null;
  }, [preview, catalog.data]);
  const missing = useMemo(
    () => (preview && catalog.data ? npcImportMissing(preview.character ?? null, preview.homebrew, catalog.data) : []),
    [preview, catalog.data],
  );

  const submit = async () => {
    if (!file || !preview || busy) return;
    setBusy(true);
    setImportError(undefined);
    const chosen = campaignId === NONE ? undefined : campaignId;
    try {
      const imported = await importNpc(file, chosen);
      const brought = Object.values(preview.homebrew).some((docs) => docs.length > 0);
      await Promise.all([
        client.invalidateQueries({ queryKey: queryKeys.npcs }),
        ...(chosen ? [client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(chosen) })] : []),
        // Lo que trae el archivo ya está en la cuenta: el catálogo de esta
        // pestaña se arma con el homebrew, y sin releerlo la ficha mostraría
        // su arma como «No está en el catálogo».
        ...(brought ? [client.invalidateQueries({ queryKey: queryKeys.homebrew })] : []),
      ]);
      onImported(String(imported.npc.name ?? preview.npc.name ?? ''));
      onClose();
    } catch (e) {
      setImportError(e instanceof ApiError && e.status === 409 ? t.npcImportConflict : t.npcImportFailed);
      setBusy(false);
    }
  };

  const npc = preview?.npc;
  const tags = Array.isArray(npc?.tags) ? (npc.tags as string[]) : [];
  const notes = Array.isArray(npc?.notes) ? npc.notes.length : 0;
  const homebrewNames = preview
    ? Object.values(preview.homebrew).flatMap((docs) => docs.map((doc) => String(doc.name ?? doc.id)))
    : [];
  const summary = preview
    ? [
        preview.portraitCount > 0 ? t.npcPortraitsCount(preview.portraitCount) : null,
        typeof npc?.background === 'string' && npc.background !== '' ? t.npcBackgroundLower : null,
        notes > 0 ? t.npcNotesCount(notes) : null,
        homebrewNames.length > 0 ? t.npcHomebrewList(homebrewNames.join(', ')) : null,
      ]
        .filter(Boolean)
        .join(' · ')
    : '';

  const canImport = !!preview && !!view && missing.length === 0 && !busy;
  const campaignOptions = [{ value: NONE, label: t.npcNoCampaignOption }, ...campaigns.map((c) => ({ value: c.id, label: c.name }))];

  return (
    <AppDialog
      open
      onOpenChange={(open) => {
        if (!open && !busy) onClose();
      }}
      title={t.npcImport}
      icon={Upload}
      actions={[
        { label: t.cancel, disabled: busy },
        {
          label: importError ? t.retry : t.transferConfirm,
          primary: true,
          closes: false,
          disabled: !canImport,
          onSelect: () => void submit(),
        },
      ]}
    >
      <div className="flex flex-col gap-3">
        <label className="flex flex-col gap-2 text-[14px]">
          {t.npcPickFile}
          <input
            type="file"
            accept=".zip,application/zip"
            disabled={busy}
            data-field="npc-import-file"
            className="w-full min-w-0 rounded-[var(--radius-nav)] border border-hairline p-2 text-[13px]"
            onChange={(event) => void choose(event.currentTarget.files?.[0] ?? null)}
          />
        </label>

        {reading && <AppBusyLabel label={t.npcReadingFile} />}

        {fileError && (
          <p role="alert" className="flex items-start gap-2 text-[13px] text-crimson">
            <CircleAlert size={16} aria-hidden="true" className="mt-px shrink-0" />
            {fileError}
          </p>
        )}

        {preview && npc && view && (
          <div className="plaque flex items-start gap-3.5 rounded-[var(--radius-card)] border border-hairline p-3.5" data-field="npc-import-preview">
            <Medallion name={String(npc.name ?? '')} accent={null} size={52} portrait={null} />
            <div className="flex min-w-0 flex-col gap-1">
              <span className="font-display text-[19px] break-words text-on-surface">{String(npc.name ?? '')}</span>
              <span className="text-[12.5px] text-text-muted">{npcTypeLine(view, t)}</span>
              {tags.length > 0 && (
                <span className="mt-1 flex flex-wrap gap-1.5">
                  {tags.map((tag) => (
                    <span key={tag} className="rounded-[var(--radius-pill)] border border-hairline bg-gold-soft px-2.5 py-px text-[11px] text-gold">
                      {tag}
                    </span>
                  ))}
                </span>
              )}
              {summary && <span className="mt-1.5 text-[12.5px] text-text-muted">{summary}</span>}
            </div>
          </div>
        )}

        {missing.length > 0 && (
          <p role="alert" className="flex items-start gap-2 text-[13.5px] leading-normal text-crimson">
            <TriangleAlert size={16} aria-hidden="true" className="mt-0.5 shrink-0" />
            {t.npcCannotImport(missing.join(', '))}
          </p>
        )}

        {preview && missing.length === 0 && (
          <div className="flex flex-col gap-1.5">
            <span aria-hidden="true" className="text-[13px] text-text-muted">
              {t.npcAlsoAddToCampaign}
            </span>
            <Select
              label={t.npcAlsoAddToCampaign}
              labelAbove
              disabled={busy}
              value={campaignId}
              onValueChange={setCampaignId}
              options={campaignOptions}
              className="w-full justify-between"
            />
            <span className="text-[12.5px] leading-normal text-text-muted">{t.npcImportNeverReplaces}</span>
          </div>
        )}

        {busy && <AppBusyLabel label={t.npcImporting} />}

        {importError && (
          <p role="alert" className="flex items-start gap-2 text-[13px] text-crimson">
            <CircleAlert size={16} aria-hidden="true" className="mt-px shrink-0" />
            {importError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
