import { useCallback, useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ArrowLeft } from 'lucide-react';
import { ApiError, saveCharacter, type StoredNpc } from '../../api/client';
import { retryNpcSave } from '../../api/npcSave';
import { saveNpcPortraitBase64, savePortraitBase64, uploadNpcPortrait, uploadPortrait } from '../../api/portraits';
import { queryKeys, useNpc, useSheetCatalog } from '../../api/queries';
import {
  actOn,
  migrateCharacter,
  npcPortraitPrompt,
  npcViews,
  portraitPrompt,
  type Catalog,
  type CharacterJson,
  type NpcView,
} from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcsHref, Link } from '../../router';
import { PortraitWorkshop, type PortraitOwner } from '../../sheet/PortraitWorkshop';
import type { SheetNotify } from '../../sheet/writer';
import { Toast, type ToastTone } from '../../ui/primitives';
import { AppBusyLabel, AppErrorView, Notice } from '../../ui/status';
import { kindOf, npcTypeLine } from './npc';
import { useNpcWriter } from './npcWriter';

/**
 * El taller de retratos de un PNJ (`/dm/pnj/:id/retrato`). Un PNJ ajeno y uno
 * inexistente responden el mismo 404. Sin ficha (`none` y `block`) los retratos
 * y la apariencia viven en el documento del PNJ; con ficha, en la ficha.
 */
export function NpcPortraitView({ npcId }: { npcId: string }) {
  const t = useTexts();
  const lang = useLang();
  const stored = useNpc(npcId);
  const catalog = useSheetCatalog(lang);
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
  const view = useMemo(
    () => (stored.data && catalog.data ? npcViews([stored.data], catalog.data)[0] : null),
    [stored.data, catalog.data],
  );

  const back = (
    <Link href={dmNpcsHref(npcId)} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {stored.data?.npc.name || t.dmNpcLibrary}
    </Link>
  );

  let body;
  const failed = [stored, ...catalog.queries].filter((q) => q.isError);
  if (stored.error instanceof ApiError && stored.error.status === 404) {
    body = (
      <div className="flex flex-col gap-4">
        {back}
        <Notice title={t.npcNotFound} body={t.npcNotFoundBody} />
      </div>
    );
  } else if (failed.length > 0) {
    body = (
      <div className="flex flex-col gap-4">
        {back}
        <AppErrorView as="h1" title={t.npcReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      </div>
    );
  } else if (!view || !stored.data || !catalog.data) {
    body = (
      <div className="flex flex-col gap-4">
        {back}
        <h1 className="sr-only">{t.dmNpcLibrary}</h1>
        <AppBusyLabel label={t.npcLoading} />
      </div>
    );
  } else if (kindOf(view) === 'character' && !stored.data.character) {
    body = (
      <div className="flex flex-col gap-4">
        {back}
        <Notice title={t.npcNotFound} body={t.npcNotFoundBody} />
      </div>
    );
  } else {
    body = <NpcWorkshop stored={stored.data} view={view} catalog={catalog.data} notify={notify} onSaveFailed={onSaveFailed} />;
  }

  return (
    <>
      {body}
      {toast && (
        <Toast key={toast.key} tone={toast.tone} message={toast.message} action={toast.action} open onOpenChange={(open) => !open && setToast(null)} />
      )}
    </>
  );
}

function NpcWorkshop({
  stored,
  view,
  catalog,
  notify,
  onSaveFailed,
}: {
  stored: StoredNpc;
  view: NpcView;
  catalog: Catalog;
  notify: SheetNotify;
  onSaveFailed: () => void;
}) {
  const t = useTexts();
  const client = useQueryClient();
  const { npc } = view;
  const npcId = npc.id;
  const writer = useNpcWriter(npcId, onSaveFailed);
  const sheet = kindOf(view) === 'character' ? (stored.character ?? null) : null;

  const buildPrompt = useMemo(
    () =>
      sheet
        ? (style: string, details: string, includeWeapon: boolean) => portraitPrompt(sheet, catalog, style, details, includeWeapon)
        : // Un PNJ sin ficha no tiene arma que nombrar: el tercer argumento se ignora.
          (style: string, details: string) => npcPortraitPrompt(npc, catalog, style, details),
    [sheet, npc, catalog],
  );

  const common = { name: npc.name, accent: null, backHref: dmNpcsHref(npcId), backLabel: npc.name, notify, buildPrompt };

  let owner: PortraitOwner;
  if (sheet) {
    // Con ficha, el retrato es de la ficha y se escribe en ella: la acción la
    // aplica el motor sobre la ficha de la caché y se guarda como cualquier
    // ficha. Es el mismo camino que `rename` en `NpcDetailView`.
    const apply: PortraitOwner['apply'] = (action) => {
      const current = client.getQueryData<StoredNpc>(queryKeys.npc(npcId))?.character;
      if (!current) return;
      const doc = actOn(migrateCharacter(current), catalog, action).character as CharacterJson & { id: string };
      client.setQueryData<StoredNpc>(queryKeys.npc(npcId), (old) => old && { ...old, character: doc });
      // ponytail: sin cola, dos acciones muy seguidas pueden guardarse en desorden;
      // el camino de salida es una cola como la de `characterSave` si hace falta.
      saveCharacter(doc)
        .then(() =>
          Promise.all([
            client.invalidateQueries({ queryKey: queryKeys.npc(npcId) }),
            client.invalidateQueries({ queryKey: queryKeys.npcs }),
          ]),
        )
        .catch(() => notify(t.npcSaveFailed, { tone: 'error' }));
    };
    const sheetId = (sheet as { id?: string }).id ?? '';
    owner = {
      ...common,
      caption: npcTypeLine(view, t),
      paths: (sheet.portraitPaths as string[] | undefined) ?? [],
      prompts: (sheet.portraitPrompts as Record<string, string> | undefined) ?? {},
      detailsLabel: t.portraitExtraDetails,
      initialDetails: '',
      // El servidor le da 404 a la ruta de retratos del PNJ cuando tiene ficha
      // (se la reserva a los que no tienen): ese va por la ruta de su ficha.
      upload: (file) => uploadPortrait(sheetId, file),
      saveBase64: (base64) => savePortraitBase64(sheetId, base64),
      apply,
    };
  } else {
    const detail =
      kindOf(view) === 'block' ? (view.baseName ?? (npc.block?.name as string | undefined) ?? t.npcKinds.block) : t.npcKinds.none;
    owner = {
      ...common,
      caption: t.npcPortraitCaption(detail),
      paths: npc.portraitPaths ?? [],
      prompts: npc.portraitPrompts ?? {},
      detailsLabel: t.portraitAppearance,
      initialDetails: npc.appearance ?? '',
      commitDetails: (text) => {
        if (text.trim() !== (npc.appearance ?? '')) writer.edit({ type: 'setAppearance', text });
      },
      upload: (file) => uploadNpcPortrait(npcId, file),
      saveBase64: (base64) => saveNpcPortraitBase64(npcId, base64),
      apply: writer.edit,
    };
  }
  return <PortraitWorkshop owner={owner} />;
}
