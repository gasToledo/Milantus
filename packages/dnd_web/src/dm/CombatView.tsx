import { useCallback, useMemo, useState, type ReactNode } from 'react';
import { Dices, FileText, Flame, Plus, X } from 'lucide-react';
import { useCampaignEncounter, useCampaignMembers, useCampaignNotebook, useCampaignNpcs, useRosterSettings, useSheetCatalog } from '../api/queries';
import type { DmCampaign } from '../api/client';
import { TurnProfile } from './combat/TurnProfile';
import { asProfile } from '../bestiary/creature';
import { toRosterEntry, type RosterEntry } from '../dashboard/roster';
import {
  bestiary,
  encounterDetails,
  encounterInitiatives,
  encounterView,
  npcViews,
  type BestiaryRow,
  type Catalog,
  type CombatantJson,
  type EncounterAction,
  type EncounterDetails,
  type EncounterView,
  type JsonObject,
  type NpcView,
} from '../engine';
import { useLang, useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { dmMemberHref, Link } from '../router';
import { Button } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { cx } from '../ui/cx';
import { ThinBar } from '../ui/data';
import { Toast, Tooltip, type ToastTone } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { AddCombatantDialog } from './combat/AddCombatantDialog';
import { DifficultyBand } from './combat/DifficultyBand';
import { retryEncounterSave, useEncounterWriter } from './combat/encounterWriter';
import { RollInitiativeDialog } from './combat/RollInitiativeDialog';
import { SIDE_TONE, SideMenu } from './combat/SideMenu';
import { DmHeader } from './DmHeader';
import { buildEntries } from './notebook';
import { npcTypeLine } from './npcs/npc';

/** Las cinco columnas de la planilla en curso, iguales en la cabecera y en cada fila. */
const LEDGER = 'grid grid-cols-[56px_minmax(0,1fr)_150px_50px_minmax(0,160px)] gap-3.5';
/** Mientras se arma: la lámina. La columna de Efectos queda vacía y sin rótulo
 *  (es de una parte siguiente) para que la planilla no cambie de forma después. */
const LEDGER_PREPARING = 'grid grid-cols-[46px_minmax(0,1fr)_132px_64px_150px_186px] gap-3';

/** Lo que la pantalla cruza para cada fila: el combatiente, lo que derivó el
 *  motor, y de dónde sale su perfil. */
interface Row {
  c: CombatantJson;
  derived: EncounterView['rows'][number];
  /** Lo que resolvió el motor para la planilla: la CA y la línea de un monstruo. */
  detail: EncounterDetails['rows'][number] | undefined;
  member: RosterEntry | undefined;
  npc: NpcView | undefined;
  creature: { row: BestiaryRow; raw: JsonObject } | undefined;
}

/**
 * El combate abierto de la campaña (`encounter_view.dart`): el orden de
 * iniciativa con el turno, los PG, la CA y los efectos de cada combatiente,
 * quién queda en pie, el perfil del que juega y, abajo, los combates ya
 * cerrados. **Mientras se arma** el DM suma jugadores, monstruos y PNJ, cambia el
 * bando, saca y descarta, ve la dificultad y los PX (si la cuenta lo permite) y
 * empieza con «Tirar iniciativa» (`combat/`); todo lo que pasa **en curso**
 * (dañar, curar, pasar el turno, efectos, cerrar) sigue en Flutter hasta 6g4, y
 * acá en curso solo se mira.
 *
 * Los PG de un monstruo o de un PNJ son los del encuentro; los de un jugador,
 * los de **su ficha real** (`modo-dm.md`: el DM no los escribe), con el máximo
 * que la compila. De quién es el turno, quién está caído o maltrecho y cuántos
 * quedan en pie lo dice el motor (`encounterView`).
 */
export function CombatView({ campaign }: { campaign: DmCampaign }) {
  const t = useTexts();
  const lang = useLang();
  const encounter = useCampaignEncounter(campaign.id);
  const members = useCampaignMembers(campaign.id);
  const npcs = useCampaignNpcs(campaign.id);
  const notebook = useCampaignNotebook(campaign.id);
  const catalog = useSheetCatalog(lang);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string; action?: { label: string; onSelect: () => void } } | null>(null);
  const [dialog, setDialog] = useState<'add' | 'discard' | null>(null);
  // Las tiradas propuestas se calculan una sola vez, al abrir «Tirar
  // iniciativa»: recalculadas en cada redibujo, los dados volverían a tirar.
  const [roll, setRoll] = useState<Record<string, number> | null>(null);
  const settings = useRosterSettings();
  // Si la consulta carga o falla, se trata como prendida: no traba el combate.
  const showDifficulty = settings.data?.showEncounterDifficulty ?? true;
  const onSaveFailed = useCallback(
    () =>
      setToast((prev) => ({
        key: (prev?.key ?? 0) + 1,
        tone: 'error',
        message: t.dmSaveCombatFailed,
        action: { label: t.retry, onSelect: () => retryEncounterSave(campaign.id) },
      })),
    [t, campaign.id],
  );
  const writer = useEncounterWriter(campaign.id, catalog.data, onSaveFailed);

  const data = useMemo(() => {
    const cat = catalog.data;
    if (encounter.data === undefined || !members.data || !npcs.data || !notebook.data || !cat) return null;
    const byMember = new Map(members.data.map((m) => [m.memberId, toRosterEntry(m.character, '', cat)] as const));
    // Los actuales salen de la ficha cruda (no son una regla); el máximo, del
    // motor. Sin ficha calculada, el jugador va sin PG antes que con unos falsos.
    const playersHp: Record<string, { current: number; max: number }> = {};
    for (const [id, e] of byMember) if (e.sheet) playersHp[id] = { current: e.character.combat?.currentHp ?? 0, max: e.sheet.maxHp };
    const view = encounter.data ? encounterView(encounter.data, playersHp) : null;
    // Nivel y CA reales de cada jugador, solo de los que tienen ficha calculada.
    const levels: Record<string, { level: number; armorClass: number }> = {};
    for (const [id, e] of byMember) if (e.sheet) levels[id] = { level: e.sheet.level, armorClass: e.sheet.armorClass };
    const details = encounter.data ? encounterDetails(cat, encounter.data, levels, npcs.data) : null;
    const detailById = new Map((details?.rows ?? []).map((r) => [r.id, r] as const));
    const npcById = new Map(npcViews(npcs.data, cat).map((v) => [v.npc.id, v] as const));
    const raws = new Map(cat.creatures.map((c) => [c.id, c] as const));
    const rowsById = new Map(bestiary(cat).map((r) => [r.id, r] as const));
    const rows: Row[] = view
      ? view.encounter.combatants.map((c, i) => {
          // Solo un monstruo se lee del catálogo: un PNJ que nació de uno
          // conserva el `creatureId`, pero pelea con su propio bloque.
          const id = c.kind === 'monster' ? c.creatureId : undefined;
          const row = id ? rowsById.get(id) : undefined;
          const raw = id ? raws.get(id) : undefined;
          return {
            c,
            derived: view.rows[i]!,
            detail: detailById.get(c.id),
            member: c.memberId ? byMember.get(c.memberId) : undefined,
            npc: c.npcId ? npcById.get(c.npcId) : undefined,
            creature: row && raw ? { row, raw } : undefined,
          };
        })
      : [];
    // Los combates cerrados, del más nuevo al más viejo, redactados como en el
    // Cuaderno.
    const past = buildEntries({ notes: [], encounterLogs: notebook.data.encounterLogs, levelUps: [] }, [], t, cat).reverse();
    // Los jugadores que todavía no entraron, para sumarlos mientras se arma.
    const inCombat = new Set(view?.encounter.combatants.map((c) => c.memberId) ?? []);
    const pending = members.data.filter((m) => !inCombat.has(m.memberId));
    return { view, rows, past, cat, pending, details };
  }, [encounter.data, members.data, npcs.data, notebook.data, catalog.data, t]);

  const failed = [encounter, members, npcs, notebook, ...catalog.queries].filter((q) => q.isError);
  const kicker = data?.view ? (data.view.preparing ? t.encPreparing : `${t.encRunning} · ${campaign.name}`) : campaign.name;

  let body;
  if (failed.length > 0) {
    body = <AppErrorView title={t.encReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!data) {
    body = <AppBusyLabel label={t.encLoading} />;
  } else {
    const { view, rows, past, cat, pending, details } = data;
    body = (
      <>
        {!view ? (
          <AppEmptyState
            kind="empty"
            message={t.encNone}
            actions={
              <Button icon={Flame} data-action="setup-combat" onClick={() => writer.act({ type: 'open' })}>
                {t.dmSetUpCombat}
              </Button>
            }
          />
        ) : (
          <>
            <ControlBar view={view} onAdd={() => setDialog('add')} onDiscard={() => setDialog('discard')} />
            {view.preparing && showDifficulty && rows.length > 0 && details && <DifficultyBand difficulty={details.difficulty} />}
            {rows.length === 0 ? (
              <AppEmptyState kind="empty" message={t.encEmptyOrder} />
            ) : (
              <div className="flex flex-wrap items-start gap-4">
                <Ledger
                  view={view}
                  rows={rows}
                  showXp={view.preparing && showDifficulty}
                  rowExtras={(r) => (view.preparing ? preparingExtras(r, campaign.id, writer.act, t) : {})}
                />
                {!view.preparing && <TurnPanel row={rows.find((r) => r.c.id === view.currentId)} catalog={cat} />}
              </div>
            )}
            {view.preparing && pending.length > 0 && (
              <div className="plaque flex flex-col px-3.5 py-2.5" data-field="pending">
                <div className="flex items-center justify-between">
                  <span className="text-[12px] text-text-muted">{t.encNotInCombat}</span>
                  {pending.length > 1 && (
                    <button
                      type="button"
                      className="min-h-9 px-1.5 text-[13px] text-gold"
                      onClick={() => pending.forEach((m) => writer.act({ type: 'addPlayer', memberId: m.memberId, name: String(m.character.name), initiative: 0 }))}
                    >
                      {t.encAddAll}
                    </button>
                  )}
                </div>
                {pending.map((m) => (
                  <div key={m.memberId} className="flex min-h-[34px] items-center justify-between" data-pending={m.memberId}>
                    <span>{String(m.character.name)}</span>
                    <button
                      type="button"
                      className="min-h-9 px-1.5 text-[13px] text-gold"
                      onClick={() => writer.act({ type: 'addPlayer', memberId: m.memberId, name: String(m.character.name), initiative: 0 })}
                    >
                      {t.dmAddShort}
                    </button>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
        <section aria-labelledby="past-combats" className="flex flex-col gap-2.5">
          <h2 id="past-combats" className="font-display mt-2 text-[20px] text-on-surface">
            {t.encPast}
          </h2>
          {past.length === 0 ? (
            <p className="text-[14px] text-text-muted">{t.encNoPast}</p>
          ) : (
            <ul className="flex max-w-[900px] flex-col gap-2.5">
              {past.map((e) => (
                <li key={e.key} className="card px-4 py-3" data-log={e.key}>
                  <p className="font-display text-[16px] text-on-surface">{e.title}</p>
                  <p className="mt-1 text-[13px] whitespace-pre-line text-on-surface-variant">
                    {e.rounds !== undefined && `${t.roundsCount(e.rounds)} · `}
                    {e.body}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </section>
      </>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <DmHeader
        title={t.dmSectionCombat}
        kicker={kicker}
        actions={
          data?.view?.preparing && (
            <Button
              icon={Dices}
              data-action="roll-initiative"
              disabled={data.rows.length === 0}
              onClick={() => encounter.data && catalog.data && npcs.data && setRoll(encounterInitiatives(catalog.data, encounter.data, npcs.data))}
            >
              {t.dmRollInitiative}
            </Button>
          )
        }
      />
      {body}
      {roll && data?.view && (
        <RollInitiativeDialog
          combatants={data.view.encounter.combatants}
          suggested={roll}
          playerModifiers={Object.fromEntries(data.rows.flatMap((r) => (r.c.kind === 'player' && r.member?.sheet ? [[r.c.id, r.member.sheet.initiative] as const] : [])))}
          onStart={(initiatives) => writer.act({ type: 'start', initiatives })}
          onClose={() => setRoll(null)}
        />
      )}
      {dialog === 'add' && catalog.data && npcs.data && (
        <AddCombatantDialog
          campaign={campaign}
          catalog={catalog.data}
          campaignNpcs={npcs.data}
          encounter={encounter.data ?? null}
          act={writer.act}
          onClose={() => setDialog(null)}
        />
      )}
      {dialog === 'discard' && (
        <ConfirmDialog
          title={t.encDiscardTitle}
          body={t.encDiscardBody}
          confirmLabel={t.encDiscardShort}
          errorText={t.dmSaveCombatFailed}
          onConfirm={writer.discard}
          onClose={() => setDialog(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} action={toast.action} open onOpenChange={(open) => !open && setToast(null)} />}
    </div>
  );
}

/** La placa de arriba: ronda, turno y cuántos quedan en pie; o, mientras se
 *  arma, que todavía no empezó. */
function ControlBar({ view, onAdd, onDiscard }: { view: EncounterView; onAdd: () => void; onDiscard: () => void }) {
  const t = useTexts();
  const plaque = 'plaque flex flex-wrap items-center gap-x-[18px] gap-y-2.5 px-4 py-3';
  if (view.preparing) {
    return (
      <div className={plaque}>
        <div>
          <p className="font-display text-[20px] text-on-surface">{t.encPreparing}</p>
          <p className="mt-0.5 text-[12px] text-text-muted">{t.encPreparingNote}</p>
        </div>
        <span className="flex-1" />
        <Button tone="soft" icon={Plus} data-action="add-combatant" onClick={onAdd}>
          {t.dmAddToCombat}
        </Button>
        <Button tone="secondary" icon={X} data-action="discard-combat" onClick={onDiscard}>
          {t.encDiscard}
        </Button>
      </div>
    );
  }
  const s = view.standing;
  const divider = <span aria-hidden="true" className="h-[22px] w-px bg-hairline" />;
  return (
    <div className={plaque} data-field="control-bar">
      <span className="flex items-baseline gap-2">
        <span className="plaque-label">{t.encRound}</span>
        <span className="font-display text-[22px] leading-none text-gold tabular-nums" data-field="round">
          {view.encounter.round}
        </span>
      </span>
      {divider}
      <span className="text-[12.5px] text-text-muted tabular-nums" data-field="turn">
        {t.encTurnOf(view.currentIndex < 0 ? 1 : view.currentIndex + 1, view.encounter.combatants.length)}
      </span>
      {divider}
      <span className="plaque-label">{t.encStanding}</span>
      <span className="num text-[13px] text-verdant" aria-label={t.encStandingAria(t.encAllies, s.alliesUp, s.allies)} data-field="allies">
        {t.encAllies} {s.alliesUp}/{s.allies}
      </span>
      <span className="num text-[13px] text-crimson" aria-label={t.encStandingAria(t.encEnemies, s.enemiesUp, s.enemies)} data-field="enemies">
        {t.encEnemies} {s.enemiesUp}/{s.enemies}
      </span>
      {s.neutrals > 0 && <span className="text-[12.5px] text-text-muted">{t.encNeutralsCount(s.neutrals)}</span>}
    </div>
  );
}

/** La planilla. Con poco ancho se desplaza dentro de su caja en lugar de partir
 *  las columnas: en una planilla, lo que se compara es la fila. */
function Ledger({ view, rows, showXp, rowExtras }: { view: EncounterView; rows: Row[]; showXp: boolean; rowExtras: (row: Row) => RowExtras }) {
  const t = useTexts();
  return (
    <section aria-label={t.encOrder} className="card min-w-0 flex-[999_1_640px] overflow-x-auto p-0">
      <div className={view.preparing ? 'min-w-[820px]' : 'min-w-[560px]'}>
        <div className={cx(view.preparing ? LEDGER_PREPARING : LEDGER, 'eyebrow border-b border-hairline px-3.5 py-2.5')} aria-hidden="true">
          <span className="text-center">{t.encInitiativeShort}</span>
          <span>{t.encCombatant}</span>
          <span>{t.encHp}</span>
          <span className="text-center">{t.encAc}</span>
          {view.preparing ? (
            <>
              <span />
              <span />
            </>
          ) : (
            <span>{t.encEffects}</span>
          )}
        </div>
        <ol>
          {rows.map((r, i) => (
            <LedgerRow
              key={r.c.id}
              row={r}
              active={r.c.id === view.currentId}
              acted={!view.preparing && view.currentIndex >= 0 && i < view.currentIndex}
              preparing={view.preparing}
              showXp={showXp}
              {...rowExtras(r)}
            />
          ))}
        </ol>
      </div>
    </section>
  );
}

/** Lo que una fila suma mientras se arma: el control del bando y la última columna. */
interface RowExtras {
  sideControl?: ReactNode;
  actions?: ReactNode;
}

function LedgerRow({ row, active, acted, preparing, showXp, sideControl, actions }: { row: Row; active: boolean; acted: boolean; preparing: boolean; showXp: boolean } & RowExtras) {
  const t = useTexts();
  const lang = useLang();
  // Los PX van primero: la línea se recorta por el final.
  const xp = showXp && row.detail?.xp != null ? new Intl.NumberFormat(lang).format(row.detail.xp) : null;
  const xpText = xp === null ? null : row.c.side === 'ally' ? t.encAllyXpValue(xp) : t.encXpValue(xp);
  const { c, derived } = row;
  const player = c.kind === 'player';
  const mark = derived.down ? t.encSkips : active ? t.encTurnWord : acted ? t.encActed : '';
  const ac = row.detail?.ac ?? null;
  const hp = derived.hp;
  return (
    <li
      className={cx(
        preparing ? LEDGER_PREPARING : LEDGER,
        'items-center border-b border-l-[3px] border-hairline py-[9px] pr-3.5 pl-[11px] last:border-b-0',
        active ? 'border-l-verdant bg-gold-soft' : 'border-l-transparent',
        acted && 'opacity-60',
      )}
      aria-current={active ? 'true' : undefined}
      data-combatant={c.id}
    >
      <div className="text-center">
        <div className={cx('num leading-none', active ? 'text-[19px] text-verdant' : 'text-[17px] text-text-muted')}>
          {preparing ? t.dmNoValue : c.initiative}
        </div>
        {!preparing && (
          <div className={cx('mt-[3px] text-[9px] font-semibold tracking-[.8px] uppercase', derived.down ? 'text-crimson' : active ? 'text-verdant' : 'text-text-muted')} data-field="mark">
            {mark}
          </div>
        )}
      </div>
      <div className="min-w-0">
        <div className={cx('font-display truncate text-[15px] text-on-surface', derived.down && 'line-through')}>{c.name}</div>
        <div className="mt-[3px] flex min-w-0 items-center gap-1.5">
          {!player &&
            (sideControl ?? (
              <span className={cx('shrink-0 rounded-[var(--radius-pill)] border px-2 text-[11px]', SIDE_TONE[c.side] ?? SIDE_TONE.neutral)} data-field="side">
                {t.encSides[c.side] ?? c.side}
              </span>
            ))}
          <span className={cx('truncate text-[11.5px]', derived.down ? 'text-crimson' : 'text-on-surface-variant')}>{[xpText, metaOf(row, derived.down, t)].filter(Boolean).join(' · ')}</span>
        </div>
      </div>
      <div data-field="hp">
        {hp ? (
          <>
            <div className="flex items-baseline gap-2">
              <span className="num text-[13.5px] text-crimson" data-field="hp-value">
                {hp.current}/{hp.max}
              </span>
              {derived.bloodied && <span className="text-[9.5px] font-semibold tracking-[.8px] text-crimson uppercase">{t.encBloodied}</span>}
            </div>
            <div className="mt-[5px]">
              <ThinBar value={hp.current} max={hp.max} label={t.dmHpAria(hp.current, hp.max)} colorClassName="bg-crimson" />
            </div>
            {player && !preparing && <div className="mt-[3px] text-[11px] text-text-muted">{t.encOnTheirSheet}</div>}
          </>
        ) : (
          <span className="text-[12px] text-text-muted">{t.encNoHp}</span>
        )}
      </div>
      <div className="text-center" data-field="ac">
        <div className="num text-[14px] text-on-surface">{ac ?? t.dmNoValue}</div>
      </div>
      <div className="flex flex-wrap gap-[5px]">
        {(c.tags ?? []).map((tag) => (
          <span key={tag} className="plaque rounded-[var(--radius-pill)] px-[9px] py-px text-[11.5px] text-on-surface">
            {tag}
          </span>
        ))}
      </div>
      {preparing && <div className="flex items-center justify-end gap-1">{actions}</div>}
    </li>
  );
}

/** La línea bajo el nombre: especie y clases de un jugador, la línea de tipo
 *  de un PNJ o de un monstruo; un caído dice que se salta su turno. */
function metaOf({ c, member, npc, detail }: Row, down: boolean, t: Texts): string {
  if (down) return t.encDownMeta;
  if (c.kind === 'player') {
    if (!member) return '';
    return t.npcCharacterLine(member.raceName, member.classes.map((k) => `${k.name} ${k.level}`).join(' · '));
  }
  if (c.kind === 'npc') return npc ? npcTypeLine(npc, t) : '';
  return detail?.monsterLine ?? '';
}

/** Lo que una fila lleva mientras se arma: el bando (menos un jugador, que no
 *  tiene), abrir la ficha de un jugador y sacar a cualquiera. Sacar no confirma,
 *  como en Flutter: volver a sumarlo es un toque. */
function preparingExtras(row: Row, campaignId: string, act: (a: EncounterAction) => void, t: Texts): RowExtras {
  const { c, detail } = row;
  const remove = (
    <Tooltip content={t.encRemoveFromCombat}>
      <button
        type="button"
        aria-label={t.encRemoveFromCombat}
        data-action="remove-combatant"
        onClick={() => act({ type: 'remove', combatantId: c.id })}
        className="flex h-11 w-11 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-on-surface"
      >
        <X size={18} aria-hidden="true" />
      </button>
    </Tooltip>
  );
  if (c.kind === 'player') {
    return {
      actions: (
        <>
          {c.memberId && (
            <Link href={dmMemberHref(campaignId, c.memberId, 'personaje')} className="inline-flex min-h-11 items-center gap-1.5 px-1.5 text-[13px] whitespace-nowrap text-gold">
              <FileText size={16} aria-hidden="true" />
              {t.encOpenSheet}
            </Link>
          )}
          {remove}
        </>
      ),
    };
  }
  return {
    sideControl: (
      <SideMenu
        side={c.side}
        name={c.name}
        canChange={detail?.canChangeSide ?? false}
        onChange={(side) => act({ type: 'setSide', combatantId: c.id, side: side as 'ally' | 'enemy' | 'neutral' })}
      />
    ),
    actions: remove,
  };
}

/** «Del turno»: el perfil de quien está jugando. Un jugador no tiene perfil que
 *  mostrar, y se dice en vez de abrir la ficha ajena (`modo-dm.md`). */
function TurnPanel({ row, catalog }: { row: Row | undefined; catalog: Catalog }) {
  const t = useTexts();
  let body;
  if (!row) {
    body = <p className="text-[13px] text-text-muted">{t.encNobodyTurn}</p>;
  } else if (row.c.kind === 'player') {
    body = <p className="text-[13px] text-text-muted">{t.encPlayerTurn(row.c.name)}</p>;
  } else if (row.creature) {
    // Va adentro de la misma tarjeta (`TurnProfile`), con las cifras de la mesa.
    body = null;
  } else if (row.npc?.block) {
    body = (
      <ul className="flex flex-col gap-1">
        {row.npc.block.actions.map((a, i) => (
          <li key={`${a.name}-${i}`} className="text-[13px]">
            <span className="font-medium text-on-surface">{a.name}. </span>
            <span className="text-text-muted">{[a.attackBonus !== null ? `+${a.attackBonus}` : null, a.damage].filter(Boolean).join(' · ')}</span>
          </li>
        ))}
      </ul>
    );
  } else {
    body = <p className="text-[13px] text-text-muted">{t.encNoProfile(row.c.name)}</p>;
  }
  return (
    <aside aria-labelledby="turn-panel" className="flex min-w-0 flex-[1_1_300px] flex-col gap-3 shell:max-w-[420px]" data-field="turn-panel">
      <div className="card flex flex-col gap-2.5 px-4 py-3.5">
        <div className="flex items-baseline gap-2">
          <h2 id="turn-panel" className="font-display flex-1 text-[17px] text-on-surface">
            {t.encOfTurn}
          </h2>
          {row && <span className="text-[12px] text-text-muted">{row.c.name}</span>}
        </div>
        {row?.creature ? (
          <TurnProfile profile={asProfile(row.creature.raw)} row={row.creature.row} catalog={catalog} stats={<TurnStats row={row} />} />
        ) : (
          row && row.c.kind !== 'player' && <TurnStats row={row} />
        )}
        {body}
      </div>
    </aside>
  );
}

/** Iniciativa, PG y CA **de la mesa**: los PG bajan a golpes y el máximo del
 *  libro deja de ser cierto en el primer ataque. */
function TurnStats({ row }: { row: Row }) {
  const t = useTexts();
  return (
    // Iniciativa y CA angostas y los PG con el resto, como en la lámina: «118/256»
    // no entra en un tercio.
    <dl className="grid grid-cols-[56px_minmax(0,1fr)_56px] gap-2">
      {[
        { label: t.encInitiativeShort, value: String(row.c.initiative), tone: 'text-verdant' },
        { label: t.encHp, value: row.derived.hp ? `${row.derived.hp.current}/${row.derived.hp.max}` : t.dmNoValue, tone: 'text-crimson' },
        { label: t.encAc, value: row.detail?.ac ?? t.dmNoValue, tone: 'text-on-surface' },
      ].map((s) => (
        <div key={s.label} className="plaque px-0.5 py-2 text-center">
          <dt className="plaque-label">{s.label}</dt>
          <dd className={cx('num mt-1 text-[17px] leading-none', s.tone)}>{s.value}</dd>
        </div>
      ))}
    </dl>
  );
}
