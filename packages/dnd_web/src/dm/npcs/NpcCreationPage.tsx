import { useState } from 'react';
import type { Account } from '../../api/client';
import { CreationPage } from '../../creation/CreationWizard';

/** `/dm/pnj/nuevo?nombre=…&campana=…`: el creador de personajes con lo que el
 *  diálogo «Nuevo PNJ» ya pidió. Se lee una vez: los datos no cambian mientras
 *  el creador está abierto. */
export function NpcCreationPage({ account }: { account: Account }) {
  const [params] = useState(() => new URLSearchParams(window.location.search));
  return (
    <CreationPage
      account={account}
      npc={{ name: params.get('nombre') ?? '', campaignId: params.get('campana') ?? undefined }}
    />
  );
}
