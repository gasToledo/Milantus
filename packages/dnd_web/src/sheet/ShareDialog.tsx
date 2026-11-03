import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Check, Copy, Flag, KeyRound, Link2Off, TriangleAlert } from 'lucide-react';
import { createShareCode, deleteCampaignLink, type CharacterShare } from '../api/client';
import { queryKeys, useCharacterShares } from '../api/queries';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { Eyebrow } from '../ui/data';
import { AppBusyLabel } from '../ui/status';

/**
 * Le da al jugador el código con el que su DM suma este personaje a una mesa, y
 * le muestra dónde está compartido para que pueda dejar de estarlo
 * (`share_character_dialog.dart`).
 *
 * El código nace acá y no del lado del DM a propósito: el acceso a una ficha
 * solo puede empezar por una decisión de su dueño.
 */
export function ShareDialog({
  characterId,
  characterName,
  onClose,
}: {
  characterId: string;
  characterName: string;
  onClose: () => void;
}) {
  const t = useTexts();
  const client = useQueryClient();
  const shares = useCharacterShares(characterId);
  const [code, setCode] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);
  const [generateFailed, setGenerateFailed] = useState(false);
  const [copied, setCopied] = useState(false);
  const [copyFailed, setCopyFailed] = useState(false);
  const [stopping, setStopping] = useState<CharacterShare | null>(null);
  const [stopped, setStopped] = useState<string | null>(null);

  const generate = async () => {
    setGenerating(true);
    setGenerateFailed(false);
    try {
      setCode((await createShareCode(characterId)).code);
    } catch {
      setGenerateFailed(true);
    }
    setGenerating(false);
  };

  // El aviso va en el propio botón y no en un aviso flotante: ese queda detrás
  // del velo del diálogo y no se enteraba de si había copiado. Y el navegador
  // puede negar el portapapeles (Safari en iOS, por ejemplo): sin el `catch`, el
  // botón fallaba en silencio.
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(code ?? '');
      setCopied(true);
      setCopyFailed(false);
    } catch {
      setCopyFailed(true);
    }
  };

  const stop = async (share: CharacterShare) => {
    await deleteCampaignLink(share.memberId);
    await Promise.all([
      client.invalidateQueries({ queryKey: queryKeys.characterShares(characterId) }),
      client.invalidateQueries({ queryKey: queryKeys.playerCampaigns(characterId) }),
    ]);
    // Debajo de la lista y no como aviso flotante, por lo mismo que «Copiar».
    setStopped(share.campaignName);
  };

  return (
    <>
      <AppDialog
        open
        onOpenChange={(open) => !open && onClose()}
        title={t.shareTitle(characterName)}
        actions={[{ label: t.close, primary: true }]}
      >
        <div className="flex flex-col gap-4">
          <p className="text-[14px] text-on-surface-variant">{t.shareIntro}</p>

          {code === null ? (
            <Button
              tone={generating ? 'secondary' : 'primary'}
              icon={KeyRound}
              disabled={generating}
              onClick={() => void generate()}
              className={generating ? 'min-h-11 self-start text-on-surface-variant' : 'min-h-11 self-start'}
            >
              {generating ? t.shareGenerating : t.shareGenerate}
            </Button>
          ) : (
            <>
              <div
                data-field="share-code"
                className="select-all rounded-[var(--radius-card)] border border-gold bg-plaque p-4 text-center text-[30px] leading-[1.2] font-semibold tracking-[4px] text-gold tabular-nums"
              >
                {code}
              </div>
              <div className="-mt-1 flex items-center gap-2">
                <span className="min-w-0 flex-1 text-[12.5px] text-text-muted">{t.shareCodeNote}</span>
                <Button
                  tone="secondary"
                  icon={copied ? Check : Copy}
                  data-action="share-copy"
                  onClick={() => void copy()}
                  className={copied ? 'min-h-11 shrink-0 !border-verdant !text-verdant' : 'min-h-11 shrink-0'}
                >
                  {copied ? t.shareCopied : t.shareCopy}
                </Button>
              </div>
              {copyFailed && (
                <p role="alert" className="text-[13px] text-crimson">
                  {t.shareCopyFailed}
                </p>
              )}
            </>
          )}
          {generateFailed && (
            <p role="alert" className="text-[13px] text-crimson">
              {t.shareGenerateError}
            </p>
          )}

          <div className="mt-1.5 flex flex-col gap-1">
            <Eyebrow>{t.shareSharedWith}</Eyebrow>
            {shares.isError ? (
              <p role="alert" className="pt-2 text-[13px] text-crimson">
                {t.shareListError}
                <button
                  type="button"
                  onClick={() => void shares.refetch()}
                  className="ml-1.5 text-[13px] font-semibold text-gold"
                >
                  {t.retry}
                </button>
              </p>
            ) : !shares.data ? (
              <div className="pt-2">
                <AppBusyLabel label={t.shareSearching} />
              </div>
            ) : shares.data.length === 0 ? (
              <p className="pt-2 text-[12.5px] text-text-muted">{t.shareNone}</p>
            ) : (
              <ul>
                {shares.data.map((share) => (
                  <li key={share.memberId} className="flex min-h-11 items-center gap-2.5 border-t border-hairline first:border-t-0">
                    <Flag size={18} aria-hidden="true" className="shrink-0 text-gold" />
                    <span className="min-w-0 flex-1 py-1.5 text-[14px] [overflow-wrap:anywhere]">{share.campaignName}</span>
                    <button
                      type="button"
                      aria-label={t.shareStopWith(share.campaignName)}
                      title={t.shareStopWith(share.campaignName)}
                      onClick={() => setStopping(share)}
                      className="inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-crimson hover:bg-plaque"
                    >
                      <Link2Off size={18} aria-hidden="true" />
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {stopped !== null && (
              <p role="status" className="flex items-center gap-1.5 pt-1.5 text-[13px] text-on-surface">
                <Check size={15} aria-hidden="true" className="shrink-0 text-verdant" />
                {t.shareStopped(stopped)}
              </p>
            )}
          </div>
        </div>
      </AppDialog>

      {stopping && (
        <StopDialog
          share={stopping}
          characterName={characterName}
          onConfirm={() => stop(stopping)}
          onClose={() => setStopping(null)}
        />
      )}
    </>
  );
}

/** «Dejar de compartir». Si falla no se cierra: queda el error y «Reintentar»,
 *  porque cerrarlo dejaría a quien corta sin saber si pasó (`DeleteDialog`). */
function StopDialog({
  share,
  characterName,
  onConfirm,
  onClose,
}: {
  share: CharacterShare;
  characterName: string;
  onConfirm: () => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  const confirm = async () => {
    if (busy) return;
    setBusy(true);
    try {
      await onConfirm();
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
      title={t.shareStop}
      icon={TriangleAlert}
      iconClassName="text-crimson"
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : t.shareStop, tone: 'crimson', primary: true, closes: false, disabled: busy, onSelect: () => void confirm() },
      ]}
    >
      <p className="text-[14px] text-on-surface-variant">{t.shareStopBody(share.campaignName, characterName)}</p>
      {failed && (
        <p role="alert" className="mt-2 text-[13px] text-crimson">
          {t.shareStopError}
        </p>
      )}
    </AppDialog>
  );
}
