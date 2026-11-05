import { useCallback, useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, EllipsisVertical, Pencil, Plus, Trash2, X } from 'lucide-react';
import { ApiError, deleteNpc, saveCharacter, type StoredNpc } from '../../api/client';
import { dropNpcSave, flushNpcSave, retryNpcSave } from '../../api/npcSave';
import { deletePortrait, uploadNpcPortrait, uploadPortrait } from '../../api/portraits';
import { queryKeys, useDmCampaigns, useNpc, useSheetCatalog } from '../../api/queries';
import { actOn, npcViews, type CharacterJson, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { RenameDialog } from '../../dashboard/RenameDialog';
import { dmNpcSheetHref, dmNpcsHref, Link, navigate } from '../../router';
import { signed } from '../../sheet/format';
import { BackgroundEditor, DiaryEntries, type DiaryEditor } from '../../sheet/DiaryTab';
import { type SheetNotify } from '../../sheet/writer';
import { Button } from '../../ui/Button';
import { ConfirmDialog } from '../../ui/ConfirmDialog';
import { cx } from '../../ui/cx';
import { Pill, StatPlaque } from '../../ui/data';
import { Medallion } from '../../ui/Medallion';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, Toast, Tooltip, type ToastTone } from '../../ui/primitives';
import { AppBusyLabel, AppErrorView, Notice } from '../../ui/status';
import { Abbr } from '../MemberCard';
import { useNpcLinks } from './links';
import { NpcStatusSelector } from './NpcStatusSelector';
import { kindOf, npcPortrait, npcTypeLine, statusOf } from './npc';
import { NpcSpeechDialog, NpcTagDialog } from './NpcTextDialogs';
import { useNpcWriter } from './npcWriter';
import { PickManyDialog } from './PickManyDialog';

/** Cuántas acciones del bloque se ven en la tarjeta, como en Flutter: el perfil
 *  entero es del editor de bloques. */
const BLOCK_ACTIONS = 4;

const ICON_BUTTON = 'inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold';

/**
 * La ficha de un PNJ (`npc_detail_screen.dart`): quién es, cómo habla, qué se
 * sabe de él, con qué pelea y cómo está en cada campaña. Es del DM y de nadie
 * más: un PNJ ajeno y uno inexistente responden el mismo 404 y la pantalla
 * dice lo mismo. Acá se escribe el estado por campaña, se suma a otra, se
 * borra el PNJ y se escribe su texto (nombre, voz, tags, trasfondo y notas);
 * siguen en Flutter el bloque, el retrato y exportar.
 */
export function NpcDetailView({ npcId }: { npcId: string }) {
  const t = useTexts();
  const lang = useLang();
  const stored = useNpc(npcId);
  const campaigns = useDmCampaigns();
  const [adding, setAdding] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const client = useQueryClient();
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string; action?: { label: string; onSelect: () => void } } | null>(null);
  const notify = useCallback<SheetNotify>(
    (message, options) =>
      setToast((prev) => ({
        key: (prev?.key ?? 0) + 1,
        tone: options?.tone ?? 'info',
        message,
        action: options?.undo ? { label: t.undo, onSelect: options.undo } : undefined,
      })),
    [t],
  );
  const onSaveFailed = useCallback(
    () =>
      setToast((prev) => ({
        key: (prev?.key ?? 0) + 1,
        tone: 'error',
        message: t.npcSaveFailed,
        action: { label: t.retry, onSelect: () => retryNpcSave(npcId) },
      })),
    [t, npcId],
  );
  const writer = useNpcWriter(npcId, onSaveFailed);
  const [dialog, setDialog] = useState<'name' | 'speech' | 'tag' | null>(null);
  const links = useNpcLinks(() => notify(t.npcSaveFailed, { tone: 'error' }));
  const catalog = useSheetCatalog(lang);
  const view = useMemo(
    () => (stored.data && catalog.data ? npcViews([stored.data], catalog.data)[0] : null),
    [stored.data, catalog.data],
  );

  const back = (
    <Link href={dmNpcsHref()} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.dmNpcLibrary}
    </Link>
  );

  if (stored.error instanceof ApiError && stored.error.status === 404) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <Notice title={t.npcNotFound} body={t.npcNotFoundBody} />
      </div>
    );
  }
  const failed = [stored, ...catalog.queries].filter((q) => q.isError);
  if (failed.length > 0) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <AppErrorView as="h1" title={t.npcReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      </div>
    );
  }
  if (!view || !stored.data) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <h1 className="sr-only">{t.dmNpcLibrary}</h1>
        <AppBusyLabel label={t.npcLoading} />
      </div>
    );
  }

  const { npc } = view;
  const inCampaigns = stored.data.campaigns;
  const remove = async () => {
    await dropNpcSave(npc.id);
    await deleteNpc(npc.id);
    // Primero se sale y después se relee: al revés, la pantalla pediría un PNJ que
    // ya no está y diría «No se encontró». La lista se corrige antes de salir para
    // que no se vea el borrado ni un cuadro.
    client.setQueryData<StoredNpc[]>(queryKeys.npcs, (old) => old?.filter((e) => e.npc.id !== npc.id));
    navigate(dmNpcsHref(), { replace: true });
    client.removeQueries({ queryKey: queryKeys.npc(npc.id) });
    await Promise.all([
      client.invalidateQueries({ queryKey: queryKeys.npcs, exact: true }),
      ...inCampaigns.map((l) => client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(l.campaignId) })),
    ]);
  };
  const speech = npc.speech?.trim() ?? '';
  const rename = async (name: string) => {
    writer.edit({ type: 'setName', name });
    await flushNpcSave(npc.id);
    // La biblioteca busca por el nombre del PNJ y la ficha muestra el suyo: tienen que
    // quedar iguales. El guardado de la ficha va aparte porque es otro documento.
    const sheet = stored.data?.character;
    if (sheet && catalog.data) {
      await saveCharacter(actOn(sheet, catalog.data, { type: 'rename', name }).character as CharacterJson & { id: string });
    }
    await client.invalidateQueries({ queryKey: queryKeys.npc(npc.id) });
  };

  const noteEditor: DiaryEditor = {
    // `at` lo pone esta capa y no el motor, para que el motor no dependa del reloj.
    save: (input) => void writer.edit({ type: 'saveNote', ...input, at: new Date().toISOString() }),
    remove(entry) {
      const r = writer.edit({ type: 'removeNote', entry: entry.entryId });
      if (!r) return;
      if (entry.kind === 'image' && entry.imageKey) {
        // Con imagen no se ofrece deshacer: el archivo se va y volvería roto.
        void deletePortrait(entry.imageKey).catch(() => undefined);
        return;
      }
      notify(t.diaryDeleted(entry.title || t.diaryUntitled), { undo: () => writer.restore(r.before) });
    },
    move: (from, to) => void writer.edit({ type: 'moveNote', entry: from, to }),
    // Un PNJ con ficha no puede usar la ruta de retratos del PNJ: el servidor se la
    // reserva a los que no tienen. Borrarlo se lleva las dos carpetas.
    upload: (file) => (npc.characterId ? uploadPortrait(npc.characterId, file) : uploadNpcPortrait(npc.id, file)),
  };
  return (
    <div className="@container flex flex-col gap-5" data-npc={npc.id}>
      {back}
      {/* Grilla y no `flex-wrap`: al partirse, el ⋮ caía solo debajo de la voz. Se mide
          el contenedor porque el panel lateral es invisible para el ancho de ventana;
          456 es lo que ocupan en una fila el medallón, 300 de texto y el ⋮. */}
      <header className="grid grid-cols-[1fr_auto] items-start gap-x-[18px] gap-y-4 @[456px]:grid-cols-[auto_minmax(0,1fr)_auto]">
        <Medallion name={npc.name} accent={null} size={76} portrait={npcPortrait(stored.data)} viewable />
        <div className="col-span-2 row-start-2 flex min-w-0 flex-col gap-2 @[456px]:col-span-1 @[456px]:col-start-2 @[456px]:row-start-1">
          <div className="flex items-start gap-1">
            <h1 className="font-display min-w-0 text-[28px] leading-tight break-words text-on-surface">{npc.name}</h1>
            <Tooltip content={t.renameTitle}>
              <button type="button" aria-label={t.renameTitle} data-action="npc-rename" onClick={() => setDialog('name')} className={ICON_BUTTON}>
                <Pencil size={18} aria-hidden="true" />
              </button>
            </Tooltip>
          </div>
          <ul className="flex flex-wrap items-center gap-1.5">
            <Pill as="li" className="text-[12px]">
              <span data-field="type">{npcTypeLine(view, t)}</span>
            </Pill>
            {(npc.tags ?? []).map((tag) => (
              <Pill as="li" key={tag} highlighted={false} className="text-[12px]">
                <span data-tag={tag}>{tag}</span>
                <Tooltip content={t.npcRemoveTag(tag)}>
                  <button
                    type="button"
                    aria-label={t.npcRemoveTag(tag)}
                    data-action="remove-tag"
                    onClick={() => writer.edit({ type: 'removeTag', tag })}
                    className="relative -mr-1 inline-flex size-4 items-center justify-center rounded-full text-text-muted before:absolute before:-inset-3 before:content-[''] hover:text-crimson"
                  >
                    <X size={13} aria-hidden="true" />
                  </button>
                </Tooltip>
              </Pill>
            ))}
            <li>
              <button
                type="button"
                data-action="add-tag"
                onClick={() => setDialog('tag')}
                className="relative inline-flex items-center gap-1 rounded-[var(--radius-pill)] px-2 py-0.5 text-[12px] text-on-surface-variant before:absolute before:-inset-y-3 before:inset-x-0 before:content-[''] hover:text-gold"
              >
                <Plus size={14} aria-hidden="true" />
                {t.npcTagWord}
              </button>
            </li>
          </ul>
          {/* La voz va bajo el nombre y no en una tarjeta: es lo primero que el
              DM necesita para interpretarlo, y como cita no pide rótulo. */}
          <div className="mt-1 flex max-w-[620px] items-start gap-1">
            <blockquote className="flex min-w-0 flex-1 gap-2" aria-label={t.npcSpeech} data-field="speech">
              <span aria-hidden="true" className="font-display text-[34px] leading-[0.9] text-gold">
                “
              </span>
              <span className={cx('pt-1.5 text-[16px] leading-normal italic', speech ? 'text-on-surface' : 'text-text-muted')}>
                {speech || t.npcSpeechEmpty}
              </span>
            </blockquote>
            <Tooltip content={t.npcEditSpeech}>
              <button type="button" aria-label={t.npcEditSpeech} data-action="npc-speech" onClick={() => setDialog('speech')} className={ICON_BUTTON}>
                <Pencil size={16} aria-hidden="true" />
              </button>
            </Tooltip>
          </div>
        </div>
        <DropdownMenu>
          <Tooltip content={t.npcMoreActions}>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                aria-label={t.npcMoreActions}
                data-action="npc-menu"
                className="col-start-2 row-start-1 inline-flex size-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-text-muted hover:text-gold data-[state=open]:bg-gold-soft data-[state=open]:text-gold @[456px]:col-start-3"
              >
                <EllipsisVertical size={20} aria-hidden="true" />
              </button>
            </DropdownMenuTrigger>
          </Tooltip>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onSelect={() => setDeleting(true)} className="text-crimson">
              <Trash2 size={15} aria-hidden="true" />
              {t.npcDelete}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </header>

      <div className="flex flex-wrap items-start gap-4">
        <div className="flex min-w-0 flex-[999_1_420px] flex-col gap-4">
          <BackgroundEditor
            saved={npc.background ?? ''}
            ownerName={npc.name}
            onSave={(text) => void writer.edit({ type: 'setBackground', text })}
            notify={notify}
          />
          <DiaryEntries
            entries={npc.notes ?? []}
            title={t.npcNotes}
            emptyMessage={t.npcNotesEmpty(npc.name)}
            minWidth={260}
            edit={noteEditor}
          />
        </div>
        <div className="flex min-w-0 max-w-[380px] flex-[1_1_300px] flex-col gap-4">
          <Stats view={view} />
          <section className="card px-4 pt-3 pb-4" aria-labelledby="npc-campaigns" data-card="campaigns">
            <div className="mb-2 flex items-center gap-2">
              <h2 id="npc-campaigns" className="font-display flex-1 text-[17px] text-on-surface">
                {t.npcInCampaigns}
              </h2>
              <Button tone="secondary" icon={Plus} data-action="npc-add-campaign" onClick={() => setAdding(true)}>
                {t.dmAddShort}
              </Button>
            </div>
            {stored.data.campaigns.length === 0 ? (
              <p className="text-text-muted italic">{t.npcNoCampaignsYet}</p>
            ) : (
              <ul className="flex flex-col gap-3">
                {stored.data.campaigns.map((c) => (
                  <li key={c.campaignId} className="flex flex-col gap-1.5" data-campaign={c.campaignId}>
                    <span className="break-words text-[14px] text-on-surface">{c.campaignName}</span>
                    <NpcStatusSelector
                      status={statusOf(c.status)}
                      label={t.npcStatusIn(c.campaignName)}
                      onChange={(s) => links.setStatus(c.campaignId, npc.id, s)}
                    />
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      </div>
      {adding && (
        <PickManyDialog
          title={t.npcAddToCampaign}
          items={(campaigns.data ?? [])
            .filter((c) => !stored.data!.campaigns.some((l) => l.campaignId === c.id))
            .map((c) => ({ id: c.id, title: c.name }))}
          loading={!campaigns.data}
          loadError={campaigns.isError ? t.dmCampaignsLoadFail : undefined}
          onRetryLoad={() => void campaigns.refetch()}
          emptyText={t.npcInAllCampaigns}
          errorText={t.dmLinkError}
          onSubmit={(ids) => links.linkMany(ids.map((campaignId) => ({ campaignId, npcId: npc.id })))}
          onClose={() => setAdding(false)}
        />
      )}
      {deleting && (
        <ConfirmDialog
          title={t.npcDeleteTitle(npc.name)}
          body={inCampaigns.length === 0 ? t.npcDeleteBodyLibrary : t.npcDeleteBodyCampaigns(inCampaigns.map((l) => l.campaignName).join(', '))}
          confirmLabel={t.npcDelete}
          errorText={t.npcDeleteFailed}
          onConfirm={remove}
          onClose={() => setDeleting(false)}
        />
      )}
      {dialog === 'name' && <RenameDialog current={npc.name} onSubmit={rename} onClose={() => setDialog(null)} />}
      {dialog === 'speech' && (
        <NpcSpeechDialog current={npc.speech ?? ''} onSubmit={(text) => void writer.edit({ type: 'setSpeech', text })} onClose={() => setDialog(null)} />
      )}
      {dialog === 'tag' && (
        <NpcTagDialog present={npc.tags ?? []} onSubmit={(tag) => void writer.edit({ type: 'addTag', tag })} onClose={() => setDialog(null)} />
      )}
      {toast && (
        <Toast key={toast.key} tone={toast.tone} message={toast.message} action={toast.action} open onOpenChange={(open) => !open && setToast(null)} />
      )}
    </div>
  );
}

/** Con qué pelea: nada, su bloque (CA, PG, VD y las primeras acciones) o los
 *  cuatro números de su ficha compilada. */
function Stats({ view }: { view: NpcView }) {
  const t = useTexts();
  const kind = kindOf(view);
  if (kind === 'none') {
    return (
      <section className="card px-4 pt-3 pb-4" data-card="stats">
        <h2 className="font-display mb-1.5 text-[17px] text-on-surface">{t.npcStats}</h2>
        <p className="text-text-muted italic">{t.npcNoStatsNote}</p>
      </section>
    );
  }
  if (kind === 'block') {
    const block = view.block;
    return (
      <section className="card px-4 pt-3 pb-4" data-card="stats">
        <div className="flex flex-wrap items-baseline gap-x-2">
          <h2 className="font-display flex-1 text-[17px] text-on-surface">{t.npcBlockTitle}</h2>
          {view.baseName && <span className="text-[12px] text-text-muted">{t.npcBasedOn(view.baseName)}</span>}
        </div>
        {block && (
          <>
            <dl className="mt-2.5 grid grid-cols-3 gap-2">
              <StatPlaque id="ac" dense label={<Abbr short={t.acShort} full={t.acFull} />} value={block.ac} />
              <StatPlaque id="hp" dense label={<Abbr short={t.hp} full={t.hitPoints} />} value={block.hp} valueClassName="text-crimson" />
              {block.crText !== null && <StatPlaque id="cr" dense label={t.creatureCr} value={block.crText} />}
            </dl>
            {block.actions.length > 0 && (
              <ul className="mt-2.5 flex flex-col gap-1 text-[13px]">
                {block.actions.slice(0, BLOCK_ACTIONS).map((a, i) => (
                  <li key={`${a.name}-${i}`}>
                    <span className="font-medium text-on-surface">{a.name}. </span>
                    <span className="text-text-muted">
                      {[a.attackBonus !== null ? `+${a.attackBonus}` : null, a.damage].filter(Boolean).join(' · ')}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </>
        )}
      </section>
    );
  }
  const sheet = view.sheet;
  return (
    <section className={cx('card px-4 pt-3 pb-4', sheet && 'relative hover:border-gold')} data-card="stats">
      <h2 className="font-display text-[17px] text-on-surface">
        {/* Como en Flutter, la tarjeta entera abre la ficha completa. Una que
            el motor no pudo leer no lleva a ningún lado. */}
        {sheet ? (
          <Link
            href={dmNpcSheetHref(view.npc.id)}
            aria-label={t.npcOpenSheet(view.npc.name)}
            className="after:absolute after:inset-0 after:rounded-[var(--radius-card)] after:content-['']"
          >
            {t.npcSheetTitle}
          </Link>
        ) : (
          t.npcSheetTitle
        )}
      </h2>
      {sheet ? (
        <dl className="mt-3 grid grid-cols-4 gap-1.5">
          <StatPlaque id="ac" dense label={<Abbr short={t.acShort} full={t.acFull} />} value={sheet.armorClass} />
          <StatPlaque id="hp" dense label={<Abbr short={t.hp} full={t.hitPoints} />} value={sheet.maxHp} />
          <StatPlaque id="initiative" dense label={<Abbr short={t.initiativeShort} full={t.initiative} />} value={signed(sheet.initiative)} />
          <StatPlaque id="passive" dense label={<Abbr short={t.dmPassiveShort} full={t.passivePerception} />} value={sheet.passivePerception} />
        </dl>
      ) : (
        <p className="mt-1.5 text-text-muted italic">{t.npcSheetReadFail}</p>
      )}
    </section>
  );
}
