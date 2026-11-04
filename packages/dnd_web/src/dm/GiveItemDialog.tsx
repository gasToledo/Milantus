import { useState } from 'react';
import { giveItems, type ChapterItem } from '../api/client';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { ChapterItemsField } from './ChapterItemsField';

/**
 * «Dar objeto a …» desde la Mesa (`DarObjeto` del Diseño): el destinatario ya
 * está elegido, la lista es la de un capítulo (cantidad, quitar, «Agregar
 * objeto») y «Dar» se apaga con la lista vacía. Es un **aviso con un regalo en
 * la bandeja** del jugador: el DM no escribe su ficha, el objeto lo agrega él al
 * aceptar. Si [giveItems] falla el diálogo no se cierra, lo elegido se conserva
 * y «Dar» pasa a «Reintentar».
 */
export function GiveItemDialog({
  campaignId,
  member,
  onSent,
  onClose,
}: {
  campaignId: string;
  member: { memberId: string; name: string };
  onSent: (name: string) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const [items, setItems] = useState<ChapterItem[]>([]);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  const give = async () => {
    if (busy || items.length === 0) return;
    setBusy(true);
    try {
      await giveItems(campaignId, member.memberId, items);
      onSent(member.name);
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
      title={t.dmGiveItemTitle(member.name)}
      actions={[
        { label: t.cancel },
        {
          label: failed ? t.retry : t.dmGiveItem,
          primary: true,
          closes: false,
          disabled: busy || items.length === 0,
          onSelect: () => void give(),
        },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        <ChapterItemsField items={items} onItems={setItems} />
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmGiveItemError}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
