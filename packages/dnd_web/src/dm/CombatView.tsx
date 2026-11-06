import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { BookOpen, Dices, ExternalLink, FileText, Flame, Plus, SkipForward, X } from 'lucide-react';
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
import { dmMemberHref, dmNpcSheetHref, Link } from '../router';
import { AppDialog } from '../ui/AppDialog';
import { Button, ButtonLink } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { cx } from '../ui/cx';
import { Eyebrow, ThinBar } from '../ui/data';
import { MarkdownText } from '../ui/MarkdownText';
import { Toast, Tooltip, type ToastTone } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { AddCombatantDialog } from './combat/AddCombatantDialog';
import { DifficultyBand } from './combat/DifficultyBand';
import { NumberPromptDialog } from './combat/NumberPromptDialog';
import { SideSelector } from './combat/SideSelector';
import { retryEncounterSave, useEncounterWriter } from './combat/encounterWriter';
import { RollInitiativeDialog } from './combat/RollInitiativeDialog';
import { SIDE_TONE, SideMenu } from './combat/SideMenu';
import { DmHeader } from './DmHeader';
import { buildEntries } from './notebook';
import { npcTypeLine } from './npcs/npc';

/** Las seis columnas de la planilla de la lámina, **las mismas armando y en
 *  curso**, para que no cambie de forma al empezar: iniciativa, combatiente, PG,
 *  CA, efectos y acciones. En curso, las dos últimas del encabezado llevan juntas
 *  la cifra de daño o curación. Es la cabecera: vale desde 760 px de ancho de la
 *  planilla; debajo, la cabecera no se dibuja y cada fila se parte (`ROW`). */
const LEDGER = 'grid grid-cols-[46px_minmax(0,1fr)_132px_64px_150px_186px] gap-x-3';
/** La fila: la grilla de [LEDGER] desde 760 px, y debajo la de la lámina
 *  «Teléfono» (tres columnas, con los PG, los efectos y las acciones en líneas
 *  propias). Las dos van escritas enteras porque Tailwind no arma clases a
 *  partir de pedazos. */
const ROW = 'grid grid-cols-[40px_minmax(0,1fr)_44px] gap-x-2.5 @[760px]:grid-cols-[46px_minmax(0,1fr)_132px_64px_150px_186px] @[760px]:gap-x-3';

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
 * empieza con «Tirar iniciativa» (`combat/`). **En curso** pasa el turno, daña y
 * cura con la cifra compartida, corrige la iniciativa, suma tarde, cambia el
 * bando y saca; los efectos, las marcas y terminar el combate siguen en Flutter
 * (6g5 y 6g6).
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
  const members = useCampaignMembers(campaign.id, { live: !!encounter.data });
  const npcs = useCampaignNpcs(campaign.id);
  const notebook = useCampaignNotebook(campaign.id);
  const catalog = useSheetCatalog(lang);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string; action?: { label: string; onSelect: () => void } } | null>(null);
  const [dialog, setDialog] = useState<'add' | 'discard' | null>(null);
  // La cifra de daño o curación es una sola para todo el combate. Se lee de la
  // referencia al tocar un botón: un toque no usa una cifra vieja si el campo
  // acaba de cambiar.
  const [amount, setAmount] = useState('1');
  const amountRef = useRef(amount);
  const changeAmount = (v: string) => {
    amountRef.current = v;
    setAmount(v);
  };
  // La iniciativa que se corrige, y el jugador que entra tarde y la pide.
  const [fix, setFix] = useState<{ id: string; name: string; initiative: number } | null>(null);
  const [late, setLate] = useState<{ memberId: string; name: string } | null>(null);
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
            <ControlBar view={view} onAdd={() => setDialog('add')} onDiscard={() => setDialog('discard')} onNext={() => writer.act({ type: 'next' })} />
            {view.preparing && showDifficulty && rows.length > 0 && details && <DifficultyBand difficulty={details.difficulty} />}
            {rows.length === 0 ? (
              <AppEmptyState kind="empty" message={t.encEmptyOrder} />
            ) : (
              <div className="flex flex-wrap items-start gap-4">
                <Ledger
                  view={view}
                  rows={rows}
                  catalog={cat}
                  showXp={view.preparing && showDifficulty}
                  amount={view.preparing ? undefined : { value: amount, onChange: changeAmount }}
                  rowExtras={(r) =>
                    rowParts(r, {
                      campaignId: campaign.id,
                      act: writer.act,
                      t,
                      running: !view.preparing,
                      amount: Number(amount) || 0,
                      readAmount: () => Number(amountRef.current) || 0,
                      onFix: (row) => setFix({ id: row.c.id, name: row.c.name, initiative: row.c.initiative }),
                    })
                  }
                />
                {!view.preparing && <TurnPanel row={rows.find((r) => r.c.id === view.currentId)} catalog={cat} campaignId={campaign.id} act={writer.act} />}
              </div>
            )}
            {pending.length > 0 && (
              <div className="plaque flex flex-col px-3.5 py-2.5" data-field="pending">
                <div className="flex items-center justify-between">
                  <span className="text-[12px] text-text-muted">{view.preparing ? t.encNotInCombat : t.encJoinedLate}</span>
                  {view.preparing && pending.length > 1 && (
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
                      // En curso entra con lo que tiró en la mesa: se pregunta.
                      onClick={() =>
                        view.preparing
                          ? writer.act({ type: 'addPlayer', memberId: m.memberId, name: String(m.character.name), initiative: 0 })
                          : setLate({ memberId: m.memberId, name: String(m.character.name) })
                      }
                    >
                      {view.preparing ? t.dmAddShort : t.encAddToInitiative}
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
          // En curso, «Siguiente turno» va en la placa de la ronda (`ControlBar`),
          // al lado de lo que cuenta: a pedido del usuario, que lo buscaba ahí.
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
          running={!!data?.view && !data.view.preparing}
          act={writer.act}
          onClose={() => setDialog(null)}
        />
      )}
      {fix && (
        <NumberPromptDialog
          title={t.encInitiativeOf(fix.name)}
          label={t.initiative}
          initial={fix.initiative}
          onSubmit={(n) => writer.act({ type: 'setInitiative', combatantId: fix.id, initiative: n })}
          onClose={() => setFix(null)}
        />
      )}
      {late && (
        <NumberPromptDialog
          title={t.encInitiativeOf(late.name)}
          label={t.encWhatTheyRolled}
          onSubmit={(n) => writer.act({ type: 'addPlayer', memberId: late.memberId, name: late.name, initiative: n })}
          onClose={() => setLate(null)}
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
function ControlBar({ view, onAdd, onDiscard, onNext }: { view: EncounterView; onAdd: () => void; onDiscard: () => void; onNext: () => void }) {
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
      <span className="flex-1" />
      <Button tone="soft" icon={Plus} data-action="add-combatant" onClick={onAdd}>
        {t.dmAddToCombat}
      </Button>
      <Button icon={SkipForward} data-action="next-turn" disabled={view.encounter.combatants.length === 0} onClick={onNext}>
        {t.dmNextTurn}
      </Button>
    </div>
  );
}

/** La planilla. Con poco ancho se desplaza dentro de su caja en lugar de partir
 *  las columnas: en una planilla, lo que se compara es la fila. */
function Ledger({
  view,
  rows,
  catalog,
  showXp,
  amount,
  rowExtras,
}: {
  view: EncounterView;
  rows: Row[];
  catalog: Catalog;
  showXp: boolean;
  /** La cifra de daño o curación; solo en curso. */
  amount?: { value: string; onChange: (v: string) => void };
  rowExtras: (row: Row) => RowExtras;
}) {
  const t = useTexts();
  return (
    // `@container`: la fila se parte por el ancho de la planilla y no por el de
    // la ventana, porque con el panel «Del turno» al lado la planilla es mucho
    // más angosta que la pantalla.
    <section aria-label={t.encOrder} className="card @container min-w-0 flex-[999_1_640px] overflow-hidden p-0">
      <div className={cx(LEDGER, 'eyebrow hidden items-center border-b border-hairline px-3.5 py-2.5 @[760px]:grid')}>
        <span aria-hidden="true" className="text-center">
          {t.encInitiativeShort}
        </span>
        <span aria-hidden="true">{t.encCombatant}</span>
        <span aria-hidden="true">{t.encHp}</span>
        <span aria-hidden="true" className="text-center">
          {t.encAc}
        </span>
        {amount ? (
          <div className="col-span-2 flex items-center justify-end gap-2">
            <span aria-hidden="true">{t.encDamageOrHeal}</span>
            <AmountControl value={amount.value} onChange={amount.onChange} field="amount" />
          </div>
        ) : (
          <>
            <span />
            <span />
          </>
        )}
      </div>
      {/* Con la fila partida no hay encabezado: la cifra va en su barra, como en
          la lámina «Teléfono». */}
      {amount && (
        <div className="border-b border-hairline bg-plaque px-3.5 py-2.5 @[760px]:hidden">
          <div className="plaque-label mb-1.5">{t.encDamageOrHeal}</div>
          <div className="flex items-center gap-2">
            <AmountControl value={amount.value} onChange={amount.onChange} field="amount" narrow />
          </div>
        </div>
      )}
      <ol>
        {rows.map((r, i) => (
          <LedgerRow
            key={r.c.id}
            row={r}
            catalog={catalog}
            active={r.c.id === view.currentId}
            acted={!view.preparing && view.currentIndex >= 0 && i < view.currentIndex}
            preparing={view.preparing}
            showXp={showXp}
            {...rowExtras(r)}
          />
        ))}
      </ol>
    </section>
  );
}

/** El campo de la cifra y sus tres atajos. Solo dígitos y hasta tres: es lo que
 *  cabe en una tirada de daño y no deja pegar una cifra que rompa la fila. */
function AmountControl({ value, onChange, field, narrow = false }: { value: string; onChange: (v: string) => void; field: string; narrow?: boolean }) {
  const t = useTexts();
  return (
    <>
      <Tooltip content={t.encAmountExplain}>
        <input
          type="text"
          inputMode="numeric"
          aria-label={`${t.encDamageOrHeal}. ${t.encAmountExplain}`}
          data-field={field}
          value={value}
          onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, 3))}
          className={cx('w-[52px] rounded-[8px] border border-hairline bg-surface text-center text-[14px] tracking-normal text-on-surface normal-case', narrow ? 'h-10 w-14' : 'h-[34px]')}
        />
      </Tooltip>
      {[1, 5, 10].map((n) => (
        <button
          key={n}
          type="button"
          aria-label={t.encSetAmount(n)}
          onClick={() => onChange(String(n))}
          className={cx('rounded-[var(--radius-pill)] border border-hairline px-2 text-[12.5px] tracking-normal text-on-surface normal-case', narrow ? 'min-h-10 min-w-11' : 'min-h-[30px] min-w-[34px]')}
        >
          {n}
        </button>
      ))}
    </>
  );
}

/** Lo que una fila suma: el control del bando, la última columna y, en curso,
 *  corregir la iniciativa. */
interface RowExtras {
  sideControl?: ReactNode;
  actions?: ReactNode;
  fixInitiative?: () => void;
}

function LedgerRow({ row, catalog, active, acted, preparing, showXp, sideControl, actions, fixInitiative }: { row: Row; catalog: Catalog; active: boolean; acted: boolean; preparing: boolean; showXp: boolean } & RowExtras) {
  const t = useTexts();
  const lang = useLang();
  // El turno que pasa se lleva la vista con él: en una mesa con muchos
  // combatientes la fila activa queda fuera de pantalla (`_RevealWhenActive` de
  // Flutter). No en el primer dibujado, para no mover la página al entrar.
  const ref = useRef<HTMLLIElement>(null);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    if (!active || preparing) return;
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    ref.current?.scrollIntoView?.({ block: 'nearest', behavior: reduced ? 'auto' : 'smooth' });
  }, [active, preparing]);
  // Los PX van primero: la línea se recorta por el final.
  const xp = showXp && row.detail?.xp != null ? new Intl.NumberFormat(lang).format(row.detail.xp) : null;
  const xpText = xp === null ? null : row.c.side === 'ally' ? t.encAllyXpValue(xp) : t.encXpValue(xp);
  const { c, derived } = row;
  const player = c.kind === 'player';
  const mark = derived.down ? t.encSkips : active ? t.encTurnWord : acted ? t.encActed : '';
  const ac = row.detail?.ac ?? null;
  const hp = derived.hp;
  // Lo que ya jugó esta ronda se atenúa en sus datos y **no en sus botones**: al
  // goblin que ya actuó se le sigue pegando, y un botón gris se lee como apagado.
  // Un caído se atenúa entero: ahí sí terminó (a pedido del usuario).
  const faded = (acted || derived.down) && 'opacity-60';
  const fadedActions = derived.down && 'opacity-60';
  const initiativeCell = (
    <>
      <div className={cx('num leading-none', active ? 'text-[19px] text-verdant' : 'text-[17px] text-text-muted')}>{preparing ? t.dmNoValue : c.initiative}</div>
      {!preparing && (
        <div className={cx('mt-[3px] text-[9px] font-semibold tracking-[.8px] uppercase', derived.down ? 'text-crimson' : active ? 'text-verdant' : 'text-text-muted')} data-field="mark">
          {mark}
        </div>
      )}
    </>
  );
  return (
    <li
      ref={ref}
      className={cx(
        ROW,
        'items-center border-b border-l-[3px] border-hairline py-[9px] pr-3.5 pl-[11px] last:border-b-0',
        active ? 'border-l-verdant bg-gold-soft' : 'border-l-transparent',
      )}
      aria-current={active ? 'true' : undefined}
      data-combatant={c.id}
    >
      <div className={cx('order-1 text-center', faded)}>
        {fixInitiative ? (
          <Tooltip content={t.encFixInitiative}>
            <button type="button" aria-label={t.encFixInitiative} data-action="fix-initiative" onClick={fixInitiative} className="w-full rounded-[var(--radius-nav)] py-1 hover:bg-plaque">
              {initiativeCell}
            </button>
          </Tooltip>
        ) : (
          initiativeCell
        )}
      </div>
      <div className={cx('order-2 min-w-0', faded)}>
        <div className={cx('font-display truncate text-[15px] text-on-surface', derived.down && 'line-through')}>{c.name}</div>
        <div className="mt-[3px] flex min-w-0 items-center gap-1.5">
          {!player &&
            (sideControl ?? (
              <span className={cx('shrink-0 rounded-[var(--radius-pill)] border px-2 text-[11px]', SIDE_TONE[c.side] ?? SIDE_TONE.neutral)} data-field="side">
                {t.encSides[c.side] ?? c.side}
              </span>
            ))}
          <span className={cx('truncate text-[11.5px]', derived.down ? 'text-crimson' : 'text-on-surface-variant')}>{[xpText, metaOf(row, derived.down, catalog, t)].filter(Boolean).join(' · ')}</span>
        </div>
      </div>
      <div className={cx('order-4 col-span-2 col-start-2 mt-2 @[760px]:order-3 @[760px]:col-auto @[760px]:mt-0', faded)} data-field="hp">
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
          </>
        ) : (
          <span className="text-[12px] text-text-muted">{t.encNoHp}</span>
        )}
      </div>
      <div className={cx('order-3 text-center @[760px]:order-4', faded)} data-field="ac">
        <span className="plaque-label block @[760px]:hidden">{t.encAc}</span>
        <div className="num text-[14px] text-on-surface">{ac ?? t.dmNoValue}</div>
      </div>
      <div className={cx('order-5 col-span-2 col-start-2 mt-2 flex-wrap gap-[5px] @[760px]:col-auto @[760px]:mt-0 @[760px]:flex', (c.tags ?? []).length > 0 ? 'flex' : 'hidden', faded)}>
        {(c.tags ?? []).map((tag) => (
          <span key={tag} className="plaque rounded-[var(--radius-pill)] px-[9px] py-px text-[11.5px] text-on-surface">
            {tag}
          </span>
        ))}
      </div>
      <div className={cx('order-6 col-span-3 mt-1.5 flex items-center justify-end gap-1 @[760px]:col-auto @[760px]:mt-0', fadedActions)}>{actions}</div>
    </li>
  );
}

/** La línea bajo el nombre: especie y clases de un jugador, la línea de tipo
 *  de un PNJ o de un monstruo; un caído dice que se salta su turno. */
function metaOf({ c, member, npc, detail }: Row, down: boolean, catalog: Catalog, t: Texts): string {
  if (down) return t.encDownMeta;
  if (c.kind === 'player') {
    if (!member) return '';
    // Lo que el jugador tiene prendido va primero: la línea se recorta por el
    // final, y en combate es lo que le cambia los números (`_playerStates`).
    const beastId = member.character.combat?.wildShapeCreatureId;
    const beast = beastId ? catalog.creatures.find((k) => k.id === beastId) : undefined;
    const states = [
      ...(beast ? [t.wildShapeAs(String(beast.name))] : []),
      ...(member.sheet?.activeModes ?? [])
        .filter((m) => m.active)
        .map((m) => {
          const variant = m.activeVariant ? m.variants.find((v) => v.id === m.activeVariant)?.name : undefined;
          return variant ? `${m.name}: ${variant}` : m.name;
        }),
    ];
    return [...states, t.npcCharacterLine(member.raceName, member.classes.map((k) => `${k.name} ${k.level}`).join(' · '))].join(' · ');
  }
  if (c.kind === 'npc') return npc ? npcTypeLine(npc, t) : '';
  return detail?.monsterLine ?? '';
}

interface RowCtx {
  campaignId: string;
  act: (a: EncounterAction) => void;
  t: Texts;
  running: boolean;
  /** La cifra de ahora, para rotular los botones. */
  amount: number;
  /** La cifra al momento del toque. */
  readAmount: () => number;
  onFix: (row: Row) => void;
}

/** El enlace a la ficha de un jugador de la mesa. Es una pill con borde y no
 *  texto suelto: en una fila de botones, lo único sin forma de botón no se
 *  reconocía como tocable (a pedido del usuario). */
function OpenSheetLink({ campaignId, memberId }: { campaignId: string; memberId: string }) {
  const t = useTexts();
  return (
    <Link
      href={dmMemberHref(campaignId, memberId, 'personaje')}
      className="inline-flex min-h-12 items-center gap-1.5 rounded-[var(--radius-pill)] border-[1.5px] border-gold px-3 text-[13px] whitespace-nowrap text-gold hover:bg-gold-soft @[760px]:min-h-[34px]"
    >
      <FileText size={16} aria-hidden="true" />
      {t.encOpenSheet}
    </Link>
  );
}

/** Lo que una fila lleva: el bando (menos un jugador, que no tiene), dañar y
 *  curar (menos un jugador y un PNJ sin estadísticas), abrir la ficha de un
 *  jugador y sacar a cualquiera. Sacar no confirma, como en Flutter: volver a
 *  sumarlo es un toque. */
function rowParts(row: Row, { campaignId, act, t, running, amount, readAmount, onFix }: RowCtx): RowExtras {
  const { c, detail, member } = row;
  const remove = (
    <Tooltip content={t.encRemoveFromCombat}>
      <button
        type="button"
        aria-label={t.encRemoveFromCombat}
        data-action="remove-combatant"
        onClick={() => act({ type: 'remove', combatantId: c.id })}
        className="flex h-12 w-12 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-on-surface @[760px]:h-11 @[760px]:w-11"
      >
        <X size={18} aria-hidden="true" />
      </button>
    </Tooltip>
  );
  const fixInitiative = running ? () => onFix(row) : undefined;
  if (c.kind === 'player') {
    return {
      fixInitiative,
      actions: (
        <>
          {member && c.memberId ? <OpenSheetLink campaignId={campaignId} memberId={c.memberId} /> : <span className="text-[11px] text-text-muted">{t.encOnTheirSheet}</span>}
          {remove}
        </>
      ),
    };
  }
  // Se lee la cifra al tocar y un cero no manda nada.
  const hit = (sign: 1 | -1) => {
    const n = readAmount();
    if (n > 0) act({ type: 'adjustHp', combatantId: c.id, delta: sign * n });
  };
  const pill = 'num min-h-12 min-w-16 rounded-[var(--radius-pill)] border-[1.5px] px-[7px] text-[13px] @[760px]:min-h-[34px] @[760px]:min-w-[46px]';
  return {
    fixInitiative,
    sideControl: (
      <SideMenu
        side={c.side}
        name={c.name}
        canChange={detail?.canChangeSide ?? false}
        onChange={(side) => act({ type: 'setSide', combatantId: c.id, side: side as 'ally' | 'enemy' | 'neutral' })}
      />
    ),
    actions: (
      <>
        {running && row.derived.hp && (
          <>
            <Tooltip content={t.encHurt}>
              <button type="button" aria-label={t.encHurt} data-action="hurt" onClick={() => hit(-1)} className={cx(pill, 'border-crimson text-crimson')}>
                −{amount}
              </button>
            </Tooltip>
            <Tooltip content={t.encHeal}>
              <button type="button" aria-label={t.encHeal} data-action="heal" onClick={() => hit(1)} className={cx(pill, 'border-verdant text-verdant')}>
                +{amount}
              </button>
            </Tooltip>
          </>
        )}
        {remove}
      </>
    ),
  };
}

/** «Del turno»: el perfil de quien está jugando. Un jugador no tiene perfil que
 *  mostrar, y se dice en vez de abrir la ficha ajena (`modo-dm.md`): el enlace
 *  lleva a la que el DM sí puede mirar. */
function TurnPanel({ row, catalog, campaignId, act }: { row: Row | undefined; catalog: Catalog; campaignId: string; act: (a: EncounterAction) => void }) {
  const t = useTexts();
  const [background, setBackground] = useState(false);
  // El bando de quien juega: se cambia desde acá igual que desde la fila, y un
  // PNJ sin estadísticas dice por qué no se puede.
  const side = (r: Row) =>
    r.detail?.canChangeSide ? (
      <SideSelector value={r.c.side} onChange={(s) => act({ type: 'setSide', combatantId: r.c.id, side: s as 'ally' | 'enemy' | 'neutral' })} />
    ) : (
      <p className="text-[12px] text-text-muted">{t.encNeutralNoStats}</p>
    );
  let body;
  if (!row) {
    body = <p className="text-[13px] text-text-muted">{t.encNobodyTurn}</p>;
  } else if (row.c.kind === 'player') {
    body = (
      <div className="flex flex-col items-start gap-1">
        <p className="text-[13px] text-text-muted">{t.encPlayerTurn(row.c.name)}</p>
        {row.member && row.c.memberId && <OpenSheetLink campaignId={campaignId} memberId={row.c.memberId} />}
      </div>
    );
  } else if (row.creature) {
    // Va adentro de la misma tarjeta (`TurnProfile`), con las cifras de la mesa.
    body = <TurnProfile profile={asProfile(row.creature.raw)} row={row.creature.row} catalog={catalog} stats={<TurnStats row={row} />} side={side(row)} />;
  } else if (row.npc) {
    const n = row.npc.npc;
    body = (
      <TurnProfile
        title={row.c.name}
        typeLine={npcTypeLine(row.npc, t)}
        profile={n.block ? asProfile(n.block) : undefined}
        catalog={catalog}
        stats={<TurnStats row={row} />}
        side={side(row)}
        titleExtra={
          n.sheetKind === 'character' ? (
            <ButtonLink tone="secondary" internal icon={ExternalLink} href={dmNpcSheetHref(n.id, 'combate')}>
              {t.encOpenSheet}
            </ButtonLink>
          ) : undefined
        }
      >
        {n.speech && (
          <div>
            <Eyebrow className="mb-1">{t.npcSpeech}</Eyebrow>
            <p className="text-[13px] text-on-surface-variant italic">{n.speech}</p>
          </div>
        )}
        {n.background && (
          <button type="button" onClick={() => setBackground(true)} className="inline-flex min-h-9 items-center gap-1.5 self-start text-[13px] text-gold">
            <BookOpen size={16} aria-hidden="true" />
            {t.stepBackground}
          </button>
        )}
      </TurnProfile>
    );
  } else {
    body = (
      <>
        {row && <TurnStats row={row} />}
        <p className="text-[13px] text-text-muted">{t.encNoProfile(row!.c.name)}</p>
      </>
    );
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
        {body}
      </div>
      {background && row?.npc?.npc.background && (
        <AppDialog open onOpenChange={(open) => !open && setBackground(false)} title={t.encBackgroundOf(row.c.name)} actions={[{ label: t.close }]}>
          <MarkdownText text={row.npc.npc.background} />
        </AppDialog>
      )}
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
