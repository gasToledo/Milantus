import { useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { CircleAlert, TriangleAlert } from 'lucide-react';
import { deleteHomebrew, type Category } from '../api/homebrew';
import { queryKeys, useRoster, useSheetCatalog } from '../api/queries';
import { toRosterEntry } from '../dashboard/roster';
import { charactersUsing } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { showNotice } from '../ui/notices';
import { AppBusyLabel } from '../ui/status';

/**
 * «¿Borrar …?» de una entrada propia (`_delete` de `homebrew_sections.dart`).
 * Dice **qué fichas de Mis personajes la usan** (`charactersUsing` del motor,
 * sobre los documentos completos): es lo que vuelve el aviso una decisión y no
 * una amenaza en abstracto. Borrar no toca esas fichas: quedan con una
 * advertencia, como en Flutter.
 *
 * Si la lista de personajes todavía carga, el diálogo espera; si no se pudo
 * leer, lo dice y deja borrar igual (el borrado no depende de ella). Si el
 * borrado falla queda abierto con el error y «Reintentar».
 */
export function DeleteHomebrewDialog({
  category,
  id,
  name,
  onClose,
  onDeleted,
}: {
  category: Category;
  id: string;
  name: string;
  onClose: () => void;
  /** Adónde se vuelve cuando ya no existe: su lista. */
  onDeleted: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const roster = useRoster();
  const catalog = useSheetCatalog(lang);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);

  // Nombre y clase de cada ficha que la menciona; la línea de clase se arma como
  // en Mis personajes (`toRosterEntry`), con el motor.
  const users = useMemo(() => {
    if (!roster.data || !catalog.data) return null;
    const ids = new Set(charactersUsing(id, roster.data.map((r) => r.character)));
    const catalogData = catalog.data;
    return roster.data
      .filter((r) => ids.has(String(r.character.id)))
      .map((r) => {
        const entry = toRosterEntry(r.character, r.createdAt, catalogData);
        return { id: entry.character.id, name: entry.character.name, classes: entry.classes.map((c) => `${c.name} ${c.level}`).join(' · ') };
      });
  }, [roster.data, catalog.data, id]);

  const unknown = roster.isError || catalog.queries.some((q) => q.isError);
  const waiting = !unknown && users === null;

  const remove = async () => {
    if (busy) return;
    setBusy(true);
    setFailed(false);
    try {
      await deleteHomebrew(category, id);
      await client.invalidateQueries({ queryKey: queryKeys.homebrew });
    } catch {
      setFailed(true);
      setBusy(false);
      return;
    }
    showNotice(t.hbDeleted(name));
    onClose();
    onDeleted();
  };

  return (
    <AppDialog
      open
      onOpenChange={(open) => {
        if (!open && !busy) onClose();
      }}
      title={t.hbDeleteTitle(t.hbDeleteKinds[category], name)}
      icon={TriangleAlert}
      iconClassName="text-crimson"
      actions={[
        { label: t.cancel, disabled: busy },
        { label: failed ? t.retry : t.cardDelete, tone: 'crimson', primary: true, closes: false, disabled: busy || waiting, onSelect: () => void remove() },
      ]}
    >
      <div className="flex flex-col gap-2.5 text-[14px] leading-normal text-on-surface" data-field="homebrew-delete">
        {waiting && <AppBusyLabel label={t.hbUsersChecking} />}
        {unknown && (
          <p role="alert" className="flex items-start gap-2 text-[13px] text-crimson">
            <CircleAlert size={16} aria-hidden="true" className="mt-0.5 shrink-0" />
            {t.hbUsersUnknown}
          </p>
        )}
        {users?.length === 0 && <span>{t.hbNoUsers}</span>}
        {users && users.length > 0 && (
          <>
            <span>{t.hbUsers(users.length)}</span>
            <ul className="plaque flex flex-col rounded-[var(--radius-card)] border border-hairline">
              {users.map((u) => (
                <li key={u.id} className="flex gap-2.5 px-3 py-2">
                  <span className="flex-1 font-medium">{u.name}</span>
                  <span className="text-[13px] text-text-muted">{u.classes}</span>
                </li>
              ))}
            </ul>
            <span className="text-on-surface-variant">{t.hbUsersWarning(users.length)}</span>
          </>
        )}
        <span>{t.commonCannotUndo}</span>
        {busy && <AppBusyLabel label={t.hbDeleting} />}
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.hbDeleteFailed}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
