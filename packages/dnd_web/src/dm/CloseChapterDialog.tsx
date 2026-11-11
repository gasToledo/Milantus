import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Plus, X } from 'lucide-react';
import { closeChapter, type Allocation, type ChapterItem, type DmChapter } from '../api/client';
import { queryKeys, useCampaignMembers, useSheetCatalog } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Button } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow, Pill } from '../ui/data';
import { ItemPicker } from './ItemPicker';

/** Una fila del reparto: un objeto del catálogo o uno de texto libre, y quiénes
 *  lo reciben. `key` es solo de la lista: dos objetos iguales con bases
 *  distintas son filas distintas. */
type Entry = { key: number; item?: ChapterItem; text?: string; to: Set<string> };

/**
 * Cerrar un capítulo (`Cierre` del Diseño). Sin objetos es una confirmación
 * simple. Con objetos pide **a quién va cada uno**: una fila por objeto con un
 * chip por personaje de la mesa, y nada viene marcado de entrada porque nada se
 * asigna solo. Con un objeto sin nadie no deja cerrar y dice cuál falta.
 *
 * Todo es un aviso: el servidor deja el objeto en la bandeja del jugador y el
 * DM no escribe ninguna ficha (`modo-dm.md`). Si cerrar falla el diálogo no se
 * cierra y «Cerrar capítulo» pasa a «Reintentar». Con la mesa vacía se cierra
 * sin repartir ni mandar cuerpo, y el capítulo conserva sus listas.
 */
export function CloseChapterDialog({
  campaignId,
  chapter,
  onClosed,
  onClose,
}: {
  campaignId: string;
  chapter: DmChapter;
  onClosed: (name: string) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const members = useCampaignMembers(campaignId);
  const catalog = useSheetCatalog(lang);
  const [entries, setEntries] = useState<Entry[]>(() => [
    ...(chapter.grantsCatalog ?? []).map((item, key) => ({ key, item, to: new Set<string>() })),
    ...(chapter.grantsItems ?? []).map((text, i) => ({
      key: (chapter.grantsCatalog ?? []).length + i,
      text,
      to: new Set<string>(),
    })),
  ]);
  const [nextKey, setNextKey] = useState(entries.length);
  const [picking, setPicking] = useState(false);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);

  const table = members.data ?? [];
  const loading = !members.data;
  const emptyTable = members.data !== undefined && table.length === 0;
  const labelOf = (e: Entry) => e.item?.name ?? e.text ?? '';
  const missing = entries.filter((e) => e.to.size === 0);
  // Sin objetos, o sin nadie a quien dárselos, es la confirmación simple.
  const simple = entries.length === 0 || emptyTable;
  const blocked = loading || (!simple && missing.length > 0);

  const add = (entry: Omit<Entry, 'key' | 'to'>) => {
    setEntries((prev) => [...prev, { ...entry, key: nextKey, to: new Set() }]);
    setNextKey(nextKey + 1);
  };
  const toggle = (key: number, memberId: string) =>
    setEntries((prev) =>
      prev.map((e) => {
        if (e.key !== key) return e;
        const to = new Set(e.to);
        if (!to.delete(memberId)) to.add(memberId);
        return { ...e, to };
      }),
    );

  const confirm = async () => {
    if (busy || blocked) return;
    setBusy(true);
    try {
      // Sin objetos, o con la mesa vacía, se cierra sin cuerpo: no hay a quién
      // repartirle y el capítulo conserva sus listas.
      const allocations: Allocation[] | undefined = simple
        ? undefined
        : table
            .map((m) => ({
              memberId: m.memberId,
              items: entries.flatMap((e) => (e.item && e.to.has(m.memberId) ? [e.item] : [])),
              freeItems: entries.flatMap((e) => (e.text !== undefined && e.to.has(m.memberId) ? [e.text] : [])),
            }))
            .filter((a) => a.items.length > 0 || a.freeItems.length > 0);
      await closeChapter(campaignId, chapter.id, allocations);
      await Promise.all([
        client.invalidateQueries({ queryKey: queryKeys.campaignChapters(campaignId) }),
        client.invalidateQueries({ queryKey: queryKeys.campaignNotebook(campaignId) }),
      ]);
      onClosed(chapter.name);
      onClose();
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  const gold = chapter.grantsGold ?? 0;
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.dmCloseChapter}
      width={simple ? 480 : 560}
      actions={[
        { label: t.cancel },
        {
          label: failed ? t.retry : t.dmCloseChapter,
          primary: true,
          closes: false,
          disabled: busy || blocked,
          onSelect: () => void confirm(),
        },
      ]}
    >
      <div className="flex flex-col gap-3">
        <p className="text-[14px] text-on-surface-variant">
          {emptyTable ? t.dmCloseEmptyTable(chapter.name) : t.dmCloseChapterBody(chapter.name)}
        </p>
        {!simple && (gold > 0 || chapter.grantsLevel) && (
          <p className="flex flex-wrap gap-2">
            {gold > 0 && <Pill>{t.dmCloseGoldEach(gold)}</Pill>}
            {chapter.grantsLevel && <Pill>{t.dmOneLevel}</Pill>}
          </p>
        )}
        {!simple && (
          <>
            <Eyebrow className="mt-1">{t.dmCloseAssign}</Eyebrow>
            {entries.map((e) => (
              <div key={e.key} className="plaque flex flex-col gap-2 p-3" data-entry={labelOf(e)}>
                <header className="flex items-center gap-2">
                  <b className="min-w-0 flex-1 truncate text-[14px] font-medium text-on-surface">
                    {labelOf(e)}
                    {e.item && e.item.quantity > 1 && <em className="num ml-2 not-italic text-on-surface-variant">×{e.item.quantity}</em>}
                    {(e.item?.homebrew || e.text !== undefined) && (
                      <i className="ml-2 rounded-[var(--radius-pill)] border border-hairline px-2 text-[11px] font-normal text-text-muted not-italic">
                        {e.text !== undefined ? t.itemFreeTag : t.itemOwnTag}
                      </i>
                    )}
                  </b>
                  <button
                    type="button"
                    aria-label={t.itemRemove(labelOf(e))}
                    title={t.itemRemove(labelOf(e))}
                    onClick={() => setEntries((prev) => prev.filter((o) => o.key !== e.key))}
                    className="flex size-8 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold"
                  >
                    <X size={15} aria-hidden="true" />
                  </button>
                </header>
                <div className="flex flex-wrap gap-1.5">
                  {table.map((m) => {
                    const on = e.to.has(m.memberId);
                    return (
                      <button
                        key={m.memberId}
                        type="button"
                        aria-pressed={on}
                        onClick={() => toggle(e.key, m.memberId)}
                        className={cx(
                          'pick rounded-[var(--radius-pill)] border px-3 py-1 text-[12.5px]',
                          on ? 'border-gold bg-gold-soft text-gold' : 'border-hairline text-on-surface-variant hover:text-on-surface',
                        )}
                      >
                        {String(m.character.name ?? '')}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
            <Button
              tone="secondary"
              icon={Plus}
              data-action="add-close-item"
              disabled={!catalog.data}
              onClick={() => setPicking(true)}
              className="self-start"
            >
              {t.catalogAddTitle}
            </Button>
            {missing.length > 0 && (
              <p role="status" className="text-[13px] text-crimson">
                {t.dmCloseMissing(missing.map(labelOf).join(', '))}
              </p>
            )}
          </>
        )}
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.dmChapterCloseError}
          </p>
        )}
      </div>
      {picking && catalog.data && (
        <ItemPicker
          catalog={catalog.data}
          chosen={entries.flatMap((e) => (e.item ? [e.item] : []))}
          onAdd={(item) => add({ item })}
          onClose={() => setPicking(false)}
        />
      )}
    </AppDialog>
  );
}
