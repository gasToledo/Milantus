import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Ellipsis, Pencil, Trash2 } from 'lucide-react';
import { deleteCampaign, type DmCampaign } from '../api/client';
import { queryKeys } from '../api/queries';
import { useTexts } from '../i18n/context';
import { dmHref, navigate } from '../router';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Tooltip } from '../ui/primitives';
import { CampaignEditorDialog, type CampaignDraft } from './CampaignEditorDialog';
import { editCampaign, stateOf } from './campaigns';

/**
 * «Editar» y «Borrar» la campaña, en un menú de la cabecera. Va solo en Mesa,
 * Capítulos y Cuaderno, y a propósito **no** en PNJ ni Combate: editar o
 * borrar la campaña no tiene que ver con un combate ni con los PNJ, y al lado
 * de «Siguiente turno» era un toque de más a mano del botón que importa
 * (`dm_mode_screen.dart`).
 */
export function CampaignMenu({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const client = useQueryClient();
  const [dialog, setDialog] = useState<'edit' | 'delete' | null>(null);

  const edit = ({ name, premise, state }: CampaignDraft) =>
    editCampaign(client, campaign.id, (latest) => ({ ...latest, name, premise, state }));

  const remove = async () => {
    await deleteCampaign(campaign.id);
    // Primero se sale de la campaña y después se relee la lista: al revés, la
    // pantalla buscaría una campaña que ya no está y diría «No se encontró».
    // La borrada también se saca de la caché antes de salir: `/v2/dm` abre la
    // primera en curso de la lista, y con la copia vieja podía ser esta.
    client.setQueryData<DmCampaign[]>(queryKeys.dmCampaigns, (old) => old?.filter((c) => c.id !== campaign.id));
    navigate(dmHref(), { replace: true });
    await client.invalidateQueries({ queryKey: queryKeys.dmCampaigns });
  };

  return (
    <>
      <DropdownMenu>
        <Tooltip content={t.dmCampaignActions}>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              aria-label={t.dmCampaignActions}
              data-action="campaign-actions"
              className="inline-flex size-11 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
            >
              <Ellipsis size={20} aria-hidden="true" />
            </button>
          </DropdownMenuTrigger>
        </Tooltip>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onSelect={() => setDialog('edit')}>
            <Pencil size={15} aria-hidden="true" className="text-text-muted" />
            {t.dmEditCampaign}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => setDialog('delete')} className="text-crimson">
            <Trash2 size={15} aria-hidden="true" />
            {t.dmDeleteCampaign}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      {dialog === 'edit' && (
        <CampaignEditorDialog
          title={t.dmEditCampaign}
          initial={{ name: campaign.name, premise: campaign.premise ?? '', state: stateOf(campaign) }}
          onSubmit={edit}
          onClose={() => setDialog(null)}
        />
      )}
      {dialog === 'delete' && (
        <ConfirmDialog
          title={t.dmDeleteCampaign}
          body={t.dmDeleteCampaignBody(campaign.name)}
          confirmLabel={t.dmDeleteCampaign}
          errorText={t.dmCampaignDeleteError}
          onConfirm={remove}
          onClose={() => setDialog(null)}
        />
      )}
    </>
  );
}
