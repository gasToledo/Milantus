import { useState } from 'react';
import { Check, CircleAlert, Download } from 'lucide-react';
import { flushCharacterWrites } from '../../api/characterSave';
import { flushNpcSave } from '../../api/npcSave';
import { exportNpc } from '../../api/transfer';
import { useTexts } from '../../i18n/context';
import { AppDialog } from '../../ui/AppDialog';
import { Eyebrow } from '../../ui/data';
import { Option } from '../../ui/wizard';
import type { NpcKind } from './npc';

/**
 * «Exportar PNJ» (`ExportNpcDialog` de Flutter): qué viaja en el archivo. Se
 * abre con trasfondo y tags marcados y las notas no, porque son de las mesas
 * del DM: que salgan tiene que ser una decisión. El ZIP lo arma el servidor
 * (`GET /api/npcs/:id/export`); acá solo se espera a que lo último que se
 * escribió esté guardado —el servidor exporta lo que tiene guardado— y se baja.
 *
 * Si algo falla el diálogo no se cierra y el botón pasa a «Reintentar», que
 * repite todo. Si sale bien se cierra sin aviso: la descarga del navegador ya
 * lo dice.
 */
export function ExportNpcDialog({
  npcId,
  name,
  kind,
  tags,
  sheetId,
  onClose,
}: {
  npcId: string;
  name: string;
  kind: NpcKind;
  tags: readonly string[];
  /** El id de la ficha de un PNJ con ficha, para esperar también su guardado. */
  sheetId?: string;
  onClose: () => void;
}) {
  const t = useTexts();
  const [background, setBackground] = useState(true);
  const [withTags, setWithTags] = useState(true);
  const [notes, setNotes] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);

  const download = async () => {
    if (busy) return;
    setBusy(true);
    setFailed(false);
    try {
      await flushNpcSave(npcId);
      if (kind === 'character' && sheetId) await flushCharacterWrites([sheetId]);
      await exportNpc(npcId, { background, tags: withTags, notes });
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  const always = (text: string) => (
    <li className="flex items-center gap-2.5 text-[14px] text-on-surface">
      <Check size={16} aria-hidden="true" className="shrink-0 text-gold" />
      {text}
    </li>
  );

  return (
    <AppDialog
      open
      onOpenChange={(open) => {
        if (!open && !busy) onClose();
      }}
      title={t.npcExportTitle}
      icon={Download}
      actions={[
        { label: t.cancel, disabled: busy },
        {
          label: busy ? t.npcExportPreparing : failed ? t.retry : t.npcDownloadZip,
          primary: true,
          closes: false,
          disabled: busy,
          onSelect: () => void download(),
        },
      ]}
    >
      <div className="flex flex-col gap-3">
        <p className="font-display text-[18px] text-on-surface">{name}</p>
        <Eyebrow>{t.npcExportWhatTravels}</Eyebrow>
        <ul className="flex flex-col gap-1.5">
          {always(t.npcExportAlways)}
          {always(kind === 'none' ? t.npcExportNone : kind === 'block' ? t.npcExportBlock : t.npcExportCharacter)}
        </ul>
        <div className="flex flex-col gap-1.5">
          <Option id="background" multi selected={background} disabled={busy} title={t.npcExportBackground} onClick={() => setBackground(!background)} />
          <Option
            id="tags"
            multi
            selected={withTags}
            disabled={busy}
            title={t.npcExportTags}
            detail={tags.length > 0 ? tags.join(', ') : undefined}
            onClick={() => setWithTags(!withTags)}
          />
          <Option id="notes" multi selected={notes} disabled={busy} title={t.npcExportNotes} detail={t.npcNotesNote} onClick={() => setNotes(!notes)} />
        </div>
        <p className="text-[12.5px] leading-normal text-text-muted">{t.npcExportNever}</p>
        {failed && (
          <p role="alert" className="flex items-start gap-2 text-[13px] text-crimson">
            <CircleAlert size={16} aria-hidden="true" className="mt-px shrink-0" />
            {t.npcExportFailed}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
