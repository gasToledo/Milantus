import { useCallback, useEffect, useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, ArrowUpCircle, Printer } from 'lucide-react';
import { flushSave, hasUnsavedChanges, retrySave, useSaveState } from '../../api/characterSave';
import { ApiError } from '../../api/client';
import { canLevelUp, type CharacterJson } from '../../engine';
import { queryKeys, useNpc, useSheetCatalog } from '../../api/queries';
import { useLang, useTexts } from '../../i18n/context';
import {
  dmNpcSheetHref,
  dmNpcsHref,
  Link,
  navigate,
  NPC_SHEET_TABS,
  npcSheetRoutes,
  type NpcSheetScreen,
  type SheetTab,
} from '../../router';
import { LevelUpWizard } from '../../levelup/LevelUpWizard';
import { ChoicesPage } from '../../sheet/Choices';
import { MagicItemPlans } from '../../sheet/MagicItemPlans';
import { PrintSheet, usePrintSheet } from '../../sheet/PrintSheet';
import { SpellEditor } from '../../sheet/SpellEditor';
import { WildShapeForms } from '../../sheet/WildShapeForms';
import { Button, ButtonLink } from '../../ui/Button';
import { computeModel } from '../../sheet/compute';
import { SheetTabs } from '../../sheet/SheetTabs';
import { accentFor } from '../../sheet/model';
import { Medallion } from '../../ui/Medallion';
import { ownPortrait } from '../../ui/portrait';
import { Toast, type ToastTone } from '../../ui/primitives';
import { AppBusyLabel, AppErrorView, Notice, SaveStatusBadge } from '../../ui/status';
import { useNpcSheetWriter, type SheetNotify } from '../../sheet/writer';

/**
 * La ficha completa de un PNJ con ficha de personaje (Flutter abre
 * `SheetScreen` en `npcMode`): la misma ficha que la de un jugador, que el DM
 * escribe (PG, usos, descansos, inventario) por la cola de guardado de la
 * ficha propia. Sin Campaña ni Diario, que en un PNJ son su trasfondo y sus
 * notas y ya están en su ficha de la Biblioteca; sin compartir, sin regalos,
 * sin renombrar. Con `screen` muestra una pantalla de edición (subir de nivel,
 * conjuros, planos, elecciones, formas): son las de la ficha propia con las
 * rutas del PNJ. Sale del mismo `GET /api/npcs/:id`: un PNJ ajeno, uno
 * inexistente y uno sin ficha dicen lo mismo, «No se encontró».
 */
export function NpcSheetView({ npcId, tab, screen }: { npcId: string; tab: SheetTab | null; screen?: NpcSheetScreen }) {
  const t = useTexts();
  const lang = useLang();
  const stored = useNpc(npcId);
  const catalog = useSheetCatalog(lang);
  const client = useQueryClient();
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string; undo?: () => void } | null>(null);
  const notify = useCallback<SheetNotify>(
    (message, options) =>
      setToast((prev) => ({ key: (prev?.key ?? 0) + 1, tone: options?.tone ?? 'info', message, undo: options?.undo })),
    [],
  );
  const write = useNpcSheetWriter(npcId, catalog.data, notify, t.actionFailed);

  // Con `screen` el `tab` también es null: no hay a dónde redirigir.
  useEffect(() => {
    if (tab === null && screen === undefined) navigate(dmNpcSheetHref(npcId), { replace: true });
  }, [npcId, tab, screen]);
  const printing = usePrintSheet();

  const raw = stored.data?.character ?? null;
  const computed = useMemo(() => (raw && catalog.data ? computeModel(raw, catalog.data) : null), [raw, catalog.data]);
  const sheetId = raw ? ((raw as { id?: string }).id ?? '') : '';
  const saveState = useSaveState(sheetId);
  const model = useMemo(() => (computed?.ok ? { ...computed.model, write: write ?? undefined } : null), [computed, write]);

  // En el nivel máximo no hay asistente: la ruta, escrita a mano, vuelve a la ficha.
  const atMaxLevel = model ? !canLevelUp(model.character as unknown as CharacterJson) : false;
  const levelUp = screen?.name === 'levelUp';
  useEffect(() => {
    if (levelUp && atMaxLevel) navigate(dmNpcSheetHref(npcId), { replace: true });
  }, [npcId, levelUp, atMaxLevel]);

  // Al volver a la pestaña se pide el PNJ de nuevo, por si se tocó en otro
  // lado: así la próxima acción parte de esa copia. Nunca con algo pendiente.
  useEffect(() => {
    const refresh = () => {
      if (document.visibilityState === 'visible' && !hasUnsavedChanges()) {
        void client.invalidateQueries({ queryKey: queryKeys.npc(npcId) });
      }
    };
    document.addEventListener('visibilitychange', refresh);
    return () => document.removeEventListener('visibilitychange', refresh);
  }, [client, npcId]);

  // Al salir se guarda primero y recién después se relee (la biblioteca y las
  // campañas): releer antes traería la copia vieja. Es lo que hace Flutter.
  useEffect(() => {
    if (!sheetId) return;
    return () => {
      void flushSave(sheetId).then(() =>
        Promise.all([
          client.invalidateQueries({ queryKey: queryKeys.npcs }),
          client.invalidateQueries({ predicate: (q) => q.queryKey[0] === 'dm' && q.queryKey[1] === 'campaigns' && q.queryKey[3] === 'npcs' }),
        ]),
      );
    };
  }, [sheetId, client]);

  const back = (
    <Link back href={dmNpcsHref(npcId)} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.luBack}
    </Link>
  );

  const failed = [stored, ...catalog.queries].filter((q) => q.isError);
  let body;
  if ((stored.error instanceof ApiError && stored.error.status === 404) || (stored.data && !raw)) {
    body = <Notice title={t.npcNotFound} body={t.npcNotFoundBody} />;
  } else if (failed.length > 0) {
    body = <AppErrorView as="h1" title={t.npcReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!computed) {
    body = <AppBusyLabel label={t.npcLoading} />;
  } else if (!computed.ok || !model) {
    body = <AppErrorView as="h1" title={t.computeErrorTitle} message={t.computeErrorBody} detail={computed.ok ? undefined : computed.detail} />;
  } else if (screen) {
    const w = model.write;
    body = !w ? (
      <AppBusyLabel label={t.npcLoading} />
    ) : screen.name === 'levelUp' ? (
      <LevelUpWizard model={model} write={w} />
    ) : screen.name === 'spells' ? (
      <SpellEditor model={model} write={w} classId={screen.classId} />
    ) : screen.name === 'plans' ? (
      <MagicItemPlans model={model} write={w} />
    ) : screen.name === 'forms' ? (
      <WildShapeForms model={model} write={w} />
    ) : (
      <ChoicesPage model={model} write={w} />
    );
  } else {
    body = (
      <SheetTabs
        model={model}
        tabs={NPC_SHEET_TABS}
        active={tab ?? 'personaje'}
        hrefOf={(tabId) => dmNpcSheetHref(npcId, tabId)}
        leading={
          <Medallion
            name={model.character.name}
            accent={accentFor(model)}
            size={64}
            portrait={ownPortrait(model.character)}
            viewable
          />
        }
      />
    );
  }

  return (
    <div className="flex flex-col gap-4" data-npc-sheet={npcId}>
      {/* La barra se parte en dos filas si no entra. */}
      <div className={`flex flex-wrap items-center gap-x-4 gap-y-2 ${screen ? 'justify-end' : 'justify-between'}`}>
        {/* Cada pantalla de edición trae su propio «volver». */}
        {!screen && back}
        {model && (
          <div className="flex flex-wrap items-center gap-2">
            <SaveStatusBadge state={saveState} onRetry={() => retrySave(sheetId)} />
            {!screen &&
              (atMaxLevel ? (
                <Button tone="secondary" icon={ArrowUpCircle} disabled>
                  {t.levelMaxReached}
                </Button>
              ) : (
                <ButtonLink
                  tone="secondary"
                  internal
                  icon={ArrowUpCircle}
                  href={npcSheetRoutes(npcId).levelUp()}
                  data-action="npc-level-up"
                >
                  {t.actionLevelUp}
                </ButtonLink>
              ))}
            {!screen && (
              <Button tone="secondary" icon={Printer} data-action="npc-print" onClick={printing.print}>
                {t.actionPrint}
              </Button>
            )}
          </div>
        )}
      </div>
      {body}
      {printing.printing && model && <PrintSheet model={model} onDone={printing.done} />}
      {toast && (
        <Toast
          key={toast.key}
          tone={toast.tone}
          message={toast.message}
          open
          onOpenChange={(open) => !open && setToast(null)}
          action={toast.undo ? { label: t.undo, onSelect: toast.undo } : undefined}
        />
      )}
    </div>
  );
}
