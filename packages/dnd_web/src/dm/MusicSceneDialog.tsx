import { useState } from 'react';
import { Check } from 'lucide-react';
import type { MusicScene } from '../api/client';
import { musicSource } from '../engine';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Switch } from '../ui/primitives';

/**
 * Crea una escena de música o edita [current] (`music_scene_dialog.dart`). Se
 * monta solo mientras está abierto, así los campos arrancan siempre con lo
 * guardado. [onSubmit] guarda; si falla el diálogo **no se cierra** y «Guardar»
 * pasa a «Reintentar».
 *
 * Los errores aparecen recién al guardar y se apagan al escribir en su campo.
 * Un enlace que `musicSource` no reconoce no se guarda: fallaría en la mesa,
 * que es el peor momento para enterarse.
 */
export function MusicSceneDialog({
  current,
  onSubmit,
  onClose,
}: {
  current?: MusicScene;
  onSubmit: (scene: MusicScene) => Promise<void>;
  onClose: () => void;
}) {
  const t = useTexts();
  const [name, setName] = useState(current?.name ?? '');
  const [url, setUrl] = useState(current?.url ?? '');
  const [offer, setOffer] = useState(current?.offerOnCombat ?? false);
  const [missingName, setMissingName] = useState(false);
  const [badUrl, setBadUrl] = useState(false);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  // Se redibuja con cada tecla: confirma qué enlace entendió el motor.
  const recognized = musicSource(url.trim());

  const save = async () => {
    if (busy) return;
    const trimmedName = name.trim();
    const trimmedUrl = url.trim();
    const noName = trimmedName === '';
    const noUrl = musicSource(trimmedUrl) === null;
    setMissingName(noName);
    setBadUrl(noUrl);
    if (noName || noUrl) return;
    setBusy(true);
    try {
      await onSubmit({
        ...current,
        id: current?.id ?? `scene-${Date.now()}`,
        name: trimmedName,
        url: trimmedUrl,
        offerOnCombat: offer,
      });
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  const field = 'text-[14px] text-on-surface rounded-[var(--radius-nav)] border bg-plaque px-3 h-[38px]';
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={current ? t.dmMusicEditScene : t.dmMusicNewScene}
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : t.commonSave, primary: true, closes: false, disabled: busy, onSelect: () => void save() },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmMusicSceneName}</span>
          <input
            autoFocus
            value={name}
            onChange={(e) => {
              setName(e.target.value);
              setMissingName(false);
            }}
            aria-invalid={missingName}
            data-field="scene-name"
            className={`${field} ${missingName ? 'border-crimson' : 'border-hairline'}`}
          />
        </label>
        {missingName && (
          <p role="alert" className="-mt-2 text-[13px] text-crimson">
            {t.dmMusicSceneNameRequired}
          </p>
        )}
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.dmMusicSceneUrl}</span>
          <input
            type="url"
            value={url}
            onChange={(e) => {
              setUrl(e.target.value);
              setBadUrl(false);
            }}
            onKeyDown={(e) => e.key === 'Enter' && void save()}
            aria-invalid={badUrl}
            data-field="scene-url"
            className={`${field} ${badUrl ? 'border-crimson' : 'border-hairline'}`}
          />
          {recognized && (
            <span className="flex items-center gap-1.5 text-[12.5px] text-verdant">
              <Check size={14} aria-hidden="true" />
              {recognized.kind === 'playlist' ? t.dmMusicKindPlaylist : t.dmMusicKindVideo}
            </span>
          )}
        </label>
        {badUrl && (
          <p role="alert" className="-mt-2 text-[13px] text-crimson">
            {t.dmMusicUnsupportedUrl}
          </p>
        )}
        <Switch id="scene-offer" label={t.dmMusicOfferOnCombat} checked={offer} onCheckedChange={setOffer} />
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmMusicSaveSceneError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
