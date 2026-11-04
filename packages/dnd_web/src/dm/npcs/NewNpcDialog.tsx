import { useMemo, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { createNpc, linkCampaignNpc } from '../../api/client';
import { queryKeys, useSheetCatalog } from '../../api/queries';
import { bestiary, newNpc } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcsHref, navigate } from '../../router';
import { AppDialog } from '../../ui/AppDialog';
import { Eyebrow } from '../../ui/data';
import { AppBusyLabel, AppErrorView } from '../../ui/status';
import { Option, SearchableList } from '../../ui/wizard';

/**
 * «Nuevo PNJ» (`_NewNpcDialog` de Flutter): nombre, qué ficha lleva y, si es un
 * bloque, de qué criatura parte. El documento lo arma el motor (`newNpc`). Crear
 * abre la ficha: el diálogo solo pidió nombre y tipo, y lo que sigue se hace ahí.
 * Con [campaignId] además lo suma a esa campaña.
 */
export function NewNpcDialog({ campaignId, onClose }: { campaignId?: string; onClose: () => void }) {
  const t = useTexts();
  const lang = useLang();
  const client = useQueryClient();
  const catalog = useSheetCatalog(lang);
  const [name, setName] = useState('');
  const [kind, setKind] = useState<'none' | 'block'>('none');
  const [base, setBase] = useState<string | null>(null);
  const [missingName, setMissingName] = useState(false);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  // Crear y vincular son dos pedidos: si falla el segundo, reintentar no tiene
  // que crear otro PNJ con el mismo nombre.
  const created = useRef<string | null>(null);

  const creatures = useMemo(() => {
    if (!catalog.data) return null;
    const byId = new Map(catalog.data.creatures.map((c) => [c.id, c] as const));
    return bestiary(catalog.data).flatMap((row) => {
      const raw = byId.get(row.id);
      return raw ? [{ id: row.id, name: String(raw.name), detail: t.npcAcHp(String(raw.ac), String(raw.hp)) }] : [];
    });
  }, [catalog.data, t]);

  const save = async () => {
    if (busy || !catalog.data) return;
    const trimmed = name.trim();
    if (trimmed === '') {
      setMissingName(true);
      return;
    }
    setBusy(true);
    try {
      const id = created.current ?? (await createNpc(newNpc(catalog.data, trimmed, kind, kind === 'block' ? base : null)));
      created.current = id;
      if (campaignId) await linkCampaignNpc(campaignId, id);
      await client.invalidateQueries({ queryKey: queryKeys.npcs });
      if (campaignId) await client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(campaignId) });
      onClose();
      navigate(dmNpcsHref(id));
    } catch {
      setFailed(true);
      setBusy(false);
    }
  };

  const failedQueries = catalog.queries.filter((q) => q.isError);
  const selectedName = creatures?.find((c) => c.id === base)?.name;

  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.npcNew}
      width={560}
      actions={[
        { label: t.cancel },
        { label: failed ? t.retry : t.npcCreate, primary: true, closes: false, disabled: busy || !catalog.data, onSelect: () => void save() },
      ]}
    >
      <div className="flex flex-col gap-3.5">
        <label className="flex flex-col gap-1.5">
          <span className="text-[12px] text-text-muted">{t.npcNameLabel}</span>
          <input
            autoFocus
            value={name}
            onChange={(e) => {
              setName(e.target.value);
              setMissingName(false);
            }}
            aria-invalid={missingName}
            data-field="npc-name"
            className={`h-[38px] rounded-[var(--radius-nav)] border bg-plaque px-3 text-[14px] text-on-surface ${missingName ? 'border-crimson' : 'border-hairline'}`}
          />
        </label>
        {missingName && (
          <p role="alert" className="-mt-2 text-[13px] text-crimson">
            {t.npcNameRequired}
          </p>
        )}

        <div className="flex flex-col gap-2">
          <Eyebrow>{t.npcWhichSheet}</Eyebrow>
          <div role="radiogroup" aria-label={t.npcWhichSheet} className="grid gap-2">
            <Option id="kind-none" selected={kind === 'none'} title={t.npcNewNone} detail={t.npcNewNoneHint} onClick={() => setKind('none')} />
            <Option id="kind-block" selected={kind === 'block'} title={t.npcNewBlock} detail={t.npcNewBlockHint} onClick={() => setKind('block')} />
            {/* Se ve apagada y dice por qué: esconderla haría creer que no existe. */}
            <Option id="kind-character" selected={false} disabled title={t.npcNewCharacter} detail={t.npcNewCharacterLater} onClick={() => {}} />
          </div>
        </div>

        {kind === 'block' && (
          <div className="step-in flex flex-col gap-2">
            <Eyebrow>{t.npcStartFromCreature}</Eyebrow>
            {failedQueries.length > 0 ? (
              <AppErrorView title={t.bestiaryLoadError} message={t.errorBody} onRetry={() => failedQueries.forEach((q) => q.refetch())} />
            ) : !creatures ? (
              <AppBusyLabel label={t.dmNpcsLoading} />
            ) : (
              <>
                {/* Fuera de la lista: el buscador no puede esconder la salida. */}
                <Option id="empty-block" selected={base === null} title={t.npcEmptyBlock} onClick={() => setBase(null)} />
                <SearchableList
                  items={creatures}
                  textOf={(c) => c.name}
                  label={t.npcSearchCreature}
                  count={selectedName}
                  height="max-h-[220px]"
                  empty={t.catalogNoMatches}
                >
                  {(c) => <Option key={c.id} id={c.id} selected={base === c.id} title={c.name} detail={c.detail} onClick={() => setBase(c.id)} />}
                </SearchableList>
              </>
            )}
          </div>
        )}

        <p className="text-[12px] text-text-muted">{t.npcTypeFixed}</p>
        {failed && (
          <p role="alert" className="text-[13px] text-crimson">
            {t.npcCreateFailed}
          </p>
        )}
      </div>
    </AppDialog>
  );
}
