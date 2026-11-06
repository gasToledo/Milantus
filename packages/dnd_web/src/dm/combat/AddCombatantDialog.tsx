import { useMemo, useState, type ReactNode } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { linkCampaignNpc, type CampaignNpc, type DmCampaign } from '../../api/client';
import { queryKeys, useNpcs } from '../../api/queries';
import { bestiary, npcViews, type Catalog, type EncounterAction, type JsonObject, type NpcEntryJson, type NpcView } from '../../engine';
import { useTexts } from '../../i18n/context';
import { AppDialog, type DialogAction } from '../../ui/AppDialog';
import { Eyebrow } from '../../ui/data';
import { AppBusyLabel, AppErrorView } from '../../ui/status';
import { Option, SearchableList } from '../../ui/wizard';
import { npcTypeLine } from '../npcs/npc';
import { MonsterQuantity, type MonsterDraft } from './MonsterQuantity';
import { isWholeNumber, NUMBER_FILTER } from './NumberPromptDialog';
import { Segmented, SideSelector } from './SideSelector';

type Tab = 'npc' | 'bestiary';
type Side = 'ally' | 'enemy' | 'neutral';

interface NpcItem {
  id: string;
  view: NpcView;
  /** Lo que se le pasa al motor: de la campaña, la fila tal cual; de la
   *  biblioteca, sin `status` (entra entero, no hereda un estado de otra mesa). */
  entry: NpcEntryJson;
  fromLibrary: boolean;
}

const TWO_COLUMNS = 'grid grid-cols-1 items-start gap-4 lg:grid-cols-[minmax(0,1fr)_300px] lg:gap-[18px]';
const PANEL = 'plaque flex min-h-[356px] flex-col gap-3 p-3.5';

/**
 * «Sumar al combate» mientras se arma: PNJ de la campaña o de la biblioteca, o
 * criaturas del Bestiario. Elegir solo llena el panel de la derecha; nada se suma
 * hasta tocar el botón, y el diálogo queda abierto para seguir sumando. Todo lo
 * que cambia el combate sale como una acción del motor (`act`).
 */
export function AddCombatantDialog({
  campaign,
  catalog,
  campaignNpcs,
  encounter,
  running,
  act,
  onClose,
}: {
  campaign: DmCampaign;
  catalog: Catalog;
  campaignNpcs: CampaignNpc[];
  encounter: JsonObject | null;
  /** Con el combate en curso, un PNJ entra con la iniciativa que sacó. */
  running: boolean;
  act: (action: EncounterAction) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const [tab, setTab] = useState<Tab>(campaignNpcs.length > 0 ? 'npc' : 'bestiary');
  // La línea verde de «Sumaste…» habla de lo último que se sumó.
  const [note, setNote] = useState<string | null>(null);
  // Las dos pestañas viven siempre: cambiar de una a otra no pierde lo elegido, y el
  // botón de sumar está en la barra del diálogo, que es una sola.
  const bestiaryTab = useBestiaryTab(catalog, act, note, setNote);
  const npcTab = useNpcTab(campaign, catalog, campaignNpcs, encounter, running, act, note, setNote);
  const current = tab === 'bestiary' ? bestiaryTab : npcTab;

  return (
    <AppDialog open onOpenChange={(open) => !open && onClose()} title={t.dmAddToCombat} width={820} actions={[{ label: t.close }, { ...current.action, primary: true, closes: false }]}>
      <div className="flex flex-col gap-3.5">
        <Segmented<Tab>
          label={t.dmAddToCombat}
          className="w-full sm:w-60"
          value={tab}
          onChange={(v) => {
            setTab(v);
            setNote(null);
          }}
          options={[
            { value: 'npc', label: t.dmSectionNpcs },
            { value: 'bestiary', label: t.navBestiary },
          ]}
        />
        {current.body}
      </div>
    </AppDialog>
  );
}

interface TabParts {
  body: ReactNode;
  action: DialogAction;
}

function useBestiaryTab(catalog: Catalog, act: (action: EncounterAction) => void, note: string | null, setNote: (note: string | null) => void): TabParts {
  const t = useTexts();
  const [selected, setSelected] = useState<string | null>(null);
  const [draft, setDraft] = useState<MonsterDraft>({ count: 1, rollHp: true, side: 'enemy' });
  const { count, rollHp, side } = draft;

  const creatures = useMemo(() => {
    const byId = new Map(catalog.creatures.map((c) => [c.id as string, c] as const));
    return bestiary(catalog).flatMap((row) => {
      const raw = byId.get(row.id);
      return raw ? [{ row, raw, name: String(raw.name) }] : [];
    });
  }, [catalog]);
  const current = creatures.find((c) => c.row.id === selected);
  const hitDice = current && typeof current.raw.hitDice === 'string' && current.raw.hitDice !== '' ? current.raw.hitDice : null;

  const add = () => {
    if (!current) return;
    act({ type: 'addMonsters', creatureId: current.row.id, count, rollHp: hitDice ? rollHp : false, side });
    setNote(t.dmAddedNote(count > 1 ? `${count} × ${current.name}` : current.name));
    // La selección queda para sumar más del mismo; el contador, no.
    setDraft({ ...draft, count: 1 });
  };

  const body = (
    <div className={TWO_COLUMNS}>
      <div className="flex min-w-0 flex-col gap-2">
        <SearchableList
          items={creatures}
          textOf={(c) => `${c.name} ${c.row.kind}`}
          label={t.dmSearchBestiary}
          height="h-[356px]"
          empty={t.catalogNoMatches}
        >
          {(c) => (
            <Option
              key={c.row.id}
              id={c.row.id}
              selected={selected === c.row.id}
              title={c.name}
              detail={c.row.kind}
              trailing={<span className="text-[12px] whitespace-nowrap text-text-muted">{`VD ${c.row.crText ?? '—'}`}</span>}
              onClick={() => {
                setSelected(c.row.id);
                setNote(null);
              }}
            />
          )}
        </SearchableList>
      </div>
      <div className={PANEL} data-field="add-panel">
        {!current ? (
          <p className="text-[13px] text-text-muted">{t.dmPickToAdd}</p>
        ) : (
          <>
            <div>
              <p className="font-display text-[18px] text-on-surface">{current.name}</p>
              <p className="mt-0.5 text-[12px] text-on-surface-variant">{current.row.kind}</p>
              <p className="text-[12px] text-on-surface-variant">{t.npcAcHp(String(current.raw.ac), String(current.raw.hp))}</p>
            </div>
            <MonsterQuantity draft={draft} onChange={setDraft} hp={String(current.raw.hp)} hitDice={hitDice} />
          </>
        )}
        {note && (
          <p role="status" className="mt-auto text-[13px] text-verdant">
            {note}
          </p>
        )}
      </div>
    </div>
  );
  return {
    body,
    action: { label: count === 1 ? t.dmAddShort : t.dmAddCount(count), disabled: !current, onSelect: add },
  };
}

function useNpcTab(
  campaign: DmCampaign,
  catalog: Catalog,
  campaignNpcs: CampaignNpc[],
  encounter: JsonObject | null,
  running: boolean,
  act: (action: EncounterAction) => void,
  note: string | null,
  setNote: (note: string | null) => void,
): TabParts {
  const t = useTexts();
  const client = useQueryClient();
  // La biblioteca se pide recién al abrir esta pestaña.
  const library = useNpcs();
  const [selected, setSelected] = useState<string | null>(null);
  const [side, setSide] = useState<string | null>(null);
  const [revive, setRevive] = useState(false);
  // Solo en curso: el monstruo no la pide (el motor tira por cada copia), el PNJ sí.
  const [initiative, setInitiative] = useState('');
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);

  const inCombat = useMemo(() => {
    const list = (encounter?.combatants ?? []) as { npcId?: string }[];
    return new Set(list.flatMap((c) => (c.npcId ? [c.npcId] : [])));
  }, [encounter]);

  const items = useMemo<NpcItem[] | null>(() => {
    if (!library.data) return null;
    const own = new Set(campaignNpcs.map((n) => n.npc.id));
    const outside: NpcEntryJson[] = library.data.filter((s) => !own.has(s.npc.id)).map((s) => ({ npc: s.npc, character: s.character }));
    const make = (entries: NpcEntryJson[], fromLibrary: boolean): NpcItem[] =>
      npcViews(entries, catalog).map((view, i) => ({ id: view.npc.id, view, entry: entries[i]!, fromLibrary }));
    return [...make(campaignNpcs, false), ...make(outside, true)];
  }, [library.data, campaignNpcs, catalog]);

  const current = items?.find((i) => i.id === selected);
  const statless = current ? current.view.maxHp === 0 : false;
  const dead = current ? !current.fromLibrary && current.view.status === 'dead' : false;
  const effectiveSide = statless ? 'neutral' : side;
  const initiativeOk = !running || isWholeNumber(initiative);

  const choose = (id: string) => {
    setSelected(id);
    setSide(null);
    setRevive(false);
    setInitiative('');
    setFailed(false);
    setNote(null);
  };

  const add = async () => {
    if (busy || !current || !effectiveSide || !initiativeOk) return;
    setBusy(true);
    setFailed(false);
    try {
      // Vincular antes de sumar: si falla, el combate no gana un PNJ que la
      // campaña no tiene, y reintentar es seguro (`linkCampaignNpc`).
      if (current.fromLibrary || revive) {
        await linkCampaignNpc(campaign.id, current.id, revive ? 'alive' : undefined);
        void client.invalidateQueries({ queryKey: queryKeys.campaignNpcs(campaign.id) });
        void client.invalidateQueries({ queryKey: queryKeys.npcs });
      }
    } catch {
      setFailed(true);
      setBusy(false);
      return;
    }
    act({ type: 'addNpc', entry: current.entry, initiative: running ? Number(initiative) : 0, side: effectiveSide as Side, revive });
    setNote(t.dmAddedNote(current.view.npc.name));
    // Ya está en el combate: no queda nada que elegir.
    setSelected(null);
    setSide(null);
    setRevive(false);
    setInitiative('');
    setBusy(false);
  };

  const body = (
    <div className={TWO_COLUMNS}>
      <div className="flex min-w-0 flex-col gap-2">
        {library.isError ? (
          <AppErrorView title={t.dmNpcsReadFail} message={t.errorBody} onRetry={() => void library.refetch()} />
        ) : !items ? (
          <AppBusyLabel label={t.dmNpcsLoading} />
        ) : (
          <SearchableList
            items={items}
            textOf={(i) => i.view.npc.name}
            groupOf={(i) => (i.fromLibrary ? t.dmFromLibrary : t.dmInThisCampaign)}
            label={t.dmSearchNpcs}
            height="h-[356px]"
            empty={t.catalogNoMatches}
          >
            {(i) => {
              const isDead = !i.fromLibrary && i.view.status === 'dead';
              const taken = inCombat.has(i.id);
              return (
                <Option
                  key={i.id}
                  id={i.id}
                  selected={selected === i.id}
                  disabled={taken}
                  title={i.view.npc.name}
                  detail={[isDead ? t.dmDeadHere : null, npcTypeLine(i.view, t, { withHurt: true }), i.fromLibrary ? t.dmAlsoJoinsCampaign : null]
                    .filter(Boolean)
                    .join(' · ')}
                  trailing={taken ? <span className="text-[12px] whitespace-nowrap text-text-muted">{t.dmAlreadyInCombat}</span> : undefined}
                  onClick={() => choose(i.id)}
                />
              );
            }}
          </SearchableList>
        )}
      </div>
      <div className={PANEL} data-field="add-panel">
        {!current ? (
          <p className="text-[13px] text-text-muted">{t.dmPickToAdd}</p>
        ) : (
          <>
            <div>
              <p className="font-display text-[18px] text-on-surface">{current.view.npc.name}</p>
              <p className="mt-0.5 text-[12px] text-on-surface-variant">{npcTypeLine(current.view, t)}</p>
            </div>
            {dead && (
              <div className="rounded-[var(--radius-nav)] border border-gold p-3 text-[13px]">
                <p>{t.dmDeadNote(current.view.npc.name)}</p>
                <div className="mt-2">
                  <Option multi selected={revive} title={t.dmRevive} onClick={() => setRevive(!revive)} />
                </div>
              </div>
            )}
            <div>
              <Eyebrow className="mb-1.5">{t.dmWhichSide}</Eyebrow>
              <SideSelector value={effectiveSide} onChange={setSide} disabled={statless} />
            </div>
            {running && (
              <label className="block">
                <span className="eyebrow mb-1.5 block">{t.encWhatTheyGot}</span>
                <input
                  type="text"
                  inputMode="numeric"
                  value={initiative}
                  onChange={(e) => NUMBER_FILTER.test(e.target.value) && setInitiative(e.target.value)}
                  data-field="add-initiative"
                  className="h-10 w-full rounded-[8px] border border-hairline bg-surface px-3 text-[14px] text-on-surface"
                />
              </label>
            )}
            {failed && (
              <p role="alert" className="text-[13px] text-crimson">
                {t.dmSaveCombatFailed}
              </p>
            )}
            <p className="mt-auto text-[12px] text-text-muted">{statless ? t.dmStatlessSide : t.dmPickSideNote}</p>
          </>
        )}
        {note && (
          <p role="status" className="text-[13px] text-verdant">
            {note}
          </p>
        )}
      </div>
    </div>
  );
  return {
    body,
    action: { label: failed ? t.retry : t.dmAddShort, disabled: busy || !effectiveSide || !initiativeOk, onSelect: () => void add() },
  };
}
