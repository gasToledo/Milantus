import { useState } from 'react';
import { Copy, Pencil, Trash2 } from 'lucide-react';
import type { CreatureProfile } from '../bestiary/creature';
import { useTexts } from '../i18n/context';
import { dmHomebrewEditHref, dmHomebrewHref, dmHomebrewNewHref, navigate } from '../router';
import { ButtonLink } from '../ui/Button';
import { Tooltip } from '../ui/primitives';
import { DeleteHomebrewDialog } from './DeleteHomebrewDialog';

const ICON_BUTTON =
  'inline-flex size-9 items-center justify-center rounded-[var(--radius-nav)] border border-hairline hover:bg-plaque';

/**
 * Lo que el perfil de una criatura del Bestiario del DM permite hacerle al
 * homebrew, al lado de «Sumar al combate» (que sigue siendo el único oro).
 * Una criatura propia se edita, se duplica y se borra; una oficial no se toca
 * ni se borra, se **copia** («Editar una copia», `dmEditCopy`). No depende de que
 * haya una campaña.
 */
export function HomebrewCreatureActions({ profile, id }: { profile: CreatureProfile; id: string }) {
  const t = useTexts();
  const [deleting, setDeleting] = useState(false);

  if (profile.source !== 'homebrew') {
    return (
      <ButtonLink internal tone="secondary" icon={Copy} href={dmHomebrewNewHref('creatures', id)} data-action="homebrew-edit-copy">
        {t.hbEditCopy}
      </ButtonLink>
    );
  }
  return (
    <>
      <div className="flex flex-wrap items-center justify-end gap-2">
        <ButtonLink internal tone="secondary" icon={Pencil} href={dmHomebrewEditHref('creatures', id)} data-action="homebrew-edit">
          {t.commonEdit}
        </ButtonLink>
        <Tooltip content={t.hbDuplicateTooltip}>
          <button type="button" aria-label={t.hbDuplicateTitle(profile.name)} onClick={() => navigate(dmHomebrewNewHref('creatures', id))} className={`${ICON_BUTTON} text-on-surface`}>
            <Copy size={16} aria-hidden="true" />
          </button>
        </Tooltip>
        <Tooltip content={t.cardDelete}>
          <button type="button" aria-label={t.hbDeleteTooltip(profile.name)} onClick={() => setDeleting(true)} className={`${ICON_BUTTON} text-crimson`}>
            <Trash2 size={16} aria-hidden="true" />
          </button>
        </Tooltip>
      </div>
      {deleting && (
        <DeleteHomebrewDialog
          category="creatures"
          id={id}
          name={profile.name}
          onClose={() => setDeleting(false)}
          onDeleted={() => navigate(dmHomebrewHref('creatures'))}
        />
      )}
    </>
  );
}
