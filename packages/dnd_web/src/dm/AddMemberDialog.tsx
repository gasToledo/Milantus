import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { addCampaignMember, ApiError, type DmCampaign } from '../api/client';
import { queryKeys } from '../api/queries';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';

/**
 * Canjear el código que el jugador sacó de «Compartir». El código se manda tal
 * como se escribió: el servidor lo normaliza. Un código que no sirve (404) deja
 * el campo como estaba, para corregirlo, y el botón sigue diciendo «Sumar»; cualquier
 * otro error es de la red o del servidor y pasa a «Reintentar». [onAdded]
 * recibe el nombre del personaje para avisar en la pantalla de atrás.
 */
export function AddMemberDialog({
  campaign,
  onAdded,
  onClose,
}: {
  campaign: DmCampaign;
  onAdded: (characterName: string) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const client = useQueryClient();
  const [code, setCode] = useState('');
  const [error, setError] = useState<'invalid' | 'failed' | null>(null);
  const [busy, setBusy] = useState(false);
  const canAdd = code.trim() !== '' && !busy;

  const add = async () => {
    if (!canAdd) return;
    setBusy(true);
    setError(null);
    try {
      const member = await addCampaignMember(campaign.id, code.trim());
      await client.invalidateQueries({ queryKey: queryKeys.campaignMembers(campaign.id) });
      onAdded(String(member.character?.name ?? t.evtSomeCharacter));
      onClose();
    } catch (e) {
      setError(e instanceof ApiError && e.status === 404 ? 'invalid' : 'failed');
      setBusy(false);
    }
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.dmAddMember}
      actions={[
        { label: t.cancel },
        {
          label: busy ? t.dmAddingMember : error === 'failed' ? t.retry : t.dmAddShort,
          primary: true,
          closes: false,
          disabled: !canAdd,
          onSelect: () => void add(),
        },
      ]}
    >
      <label className="flex flex-col gap-1.5">
        <span className="text-[12px] text-text-muted">{t.dmMemberCodeLabel}</span>
        <input
          autoFocus
          value={code}
          onChange={(e) => {
            setCode(e.target.value);
            setError(null);
          }}
          onKeyDown={(e) => e.key === 'Enter' && void add()}
          aria-invalid={error === 'invalid'}
          autoCapitalize="characters"
          autoComplete="off"
          spellCheck={false}
          data-field="member-code"
          className={`h-12 rounded-[var(--radius-nav)] border bg-plaque px-3 text-center text-[18px] font-semibold tracking-[3px] text-on-surface uppercase tabular-nums ${
            error === 'invalid' ? 'border-crimson' : 'border-hairline'
          }`}
        />
      </label>
      {error && (
        <p role="alert" className="mt-2 text-[13px] text-crimson">
          {error === 'invalid' ? t.dmMemberCodeInvalid : t.dmMemberAddError}
        </p>
      )}
    </AppDialog>
  );
}
