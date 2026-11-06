import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { ArrowDown, ArrowUp, BookOpen, CheckCheck, Dices, ExternalLink, FileText, Flame, Plus, Shield, SkipForward, Tag, X } from 'lucide-react';
import { useCampaignEncounter, useCampaignMembers, useCampaignNotebook, useCampaignNpcs, useRosterSettings, useSheetCatalog } from '../api/queries';
import type { DmCampaign } from '../api/client';
import { TurnProfile } from './combat/TurnProfile';
import { asProfile } from '../bestiary/creature';
import { toRosterEntry, type RosterEntry } from '../dashboard/roster';
import {
  bestiary,
  encounterAct,
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
import { Eyebrow } from '../ui/data';
import { MarkdownText } from '../ui/MarkdownText';
import { Toast, Tooltip, type ToastTone } from '../ui/primitives';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { AddCombatantDialog } from './combat/AddCombatantDialog';
import { ConvertNpcDialog } from './combat/ConvertNpcDialog';
import { tagLabel } from './combat/conditions';
import { DifficultyBand } from './combat/DifficultyBand';
import { EffectsDialog } from './combat/EffectsDialog';
import { EndCombatDialog } from './combat/EndCombatDialog';
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
// La última columna es de 208 px y no de los 186 de la lámina: con el botón de
// efectos (44 × 44 como pide el brief) «Abrir ficha» + efectos + ✕ no entran en 186.
const LEDGER = 'grid grid-cols-[46px_minmax(0,1fr)_132px_64px_150px_208px] gap-x-3';
/** La fila: la grilla de [LEDGER] desde 760 px, y debajo la de la lámina
 *  «Teléfono» (tres columnas, con los PG, los efectos y las acciones en líneas
 *  propias). Las dos van escritas enteras porque Tailwind no arma clases a
 *  partir de pedazos. */
const ROW = 'grid grid-cols-[40px_minmax(0,1fr)_44px] gap-x-2.5 @[760px]:grid-cols-[46px_minmax(0,1fr)_132px_64px_150px_208px] @[760px]:gap-x-3';

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
 * bando y saca; anota efectos, ventaja o desventaja, PG temporales y bono a la CA
 * (`EffectsDialog`), gasta las marcas legendarias y termina el combate
 * archivándolo en el Cuaderno o descartándolo (`EndCombatDialog`).
 *
 * Los PG de un monstruo o de un PNJ son los del encuentro; los de un jugador,
 * los de **su ficha real** (`modo-dm.md`: el DM no los escribe), con el máximo
 * que la compila. De quién es el turno, quién está caído o maltrecho y cuántos
 * quedan en pie lo dice el motor (`encounterView`).
 */
export function CombatView({ campaign, onMusicOffer }: { campaign: DmCampaign; onMusicOffer: (campaignId: string, show: boolean) => void }) {
  const t = useTexts();
  const lang = useLang();
  const encounter = useCampaignEncounter(campaign.id);
  const members = useCampaignMembers(campaign.id, { live: !!encounter.data });
  const npcs = useCampaignNpcs(campaign.id);
  const notebook = useCampaignNotebook(campaign.id);
  const catalog = useSheetCatalog(lang);
  const [toast, setToast] = useState<{ key: number; tone: ToastTone; message: string; action?: { label: string; onSelect: () => void } } | null>(null);
  const [dialog, setDialog] = useState<'add' | 'discard' | 'finish' | null>(null);
  // El combatiente cuyos efectos y defensas se editan.
  const [effectsId, setEffectsId] = useState<string | null>(null);
  const [conversion, setConversion] = useState<{ encounterId: string; combatantId: string; creatureId: string; name: string } | null>(null);
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
  const writer = useEncounterWriter(campaign.id, catalog.data, onSaveFailed, onMusicOffer);

  const data = useMemo(() => {
    const cat = catalog.data;
    if (encounter.data === undefined || !members.data || !npcs.data || !notebook.data || !cat) return null;
    const byMember = new Map(members.data.map((m) => [m.memberId, toRosterEntry(m.character, '', cat)] as const));
    // Los actuales salen de la ficha cruda (no son una regla); el máximo, del
    // motor. Sin ficha calculada, el jugador va sin PG antes que con unos falsos.
    // Los temporales también son de la ficha (`modo-dm.md`): el DM los ve, no los escribe.
    const playersHp: Record<string, { current: number; max: number; temp: number }> = {};
    for (const [id, e] of byMember) if (e.sheet) playersHp[id] = { current: e.character.combat?.currentHp ?? 0, max: e.sheet.maxHp, temp: e.character.combat?.tempHp ?? 0 };
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
    return { view, rows, past, cat, pending, details, levels };
  }, [encounter.data, members.data, npcs.data, notebook.data, catalog.data, t]);

  const failed = [encounter, members, npcs, notebook, ...catalog.queries].filter((q) => q.isError);
  const effectsRow = effectsId ? data?.rows.find((r) => r.c.id === effectsId) : undefined;
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
            <ControlBar view={view} onAdd={() => setDialog('add')} onDiscard={() => setDialog('discard')} onFinish={() => setDialog('finish')} onNext={() => writer.act({ type: 'next' })} />
            {view.preparing && showDifficulty && rows.length > 0 && details && <DifficultyBand difficulty={details.difficulty} />}
            {!view.preparing && <SideWipedBanner standing={view.standing} onFinish={() => setDialog('finish')} />}
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
                      onEffects: (row) => setEffectsId(row.c.id),
                      onConvert: (row) => {
                        if (!row.c.creatureId) return;
                        setConversion({ encounterId: view.encounter.id, combatantId: row.c.id, creatureId: row.c.creatureId, name: row.c.name });
                      },
                    })
                  }
                />
                {!view.preparing && <TurnPanel row={rows.find((r) => r.c.id === view.currentId)} rows={rows} catalog={cat} campaignId={campaign.id} act={writer.act} />}
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
      {conversion && (
        <ConvertNpcDialog
          current={conversion.name}
          onConvert={(name) => writer.convert(conversion.encounterId, conversion.combatantId, conversion.creatureId, name)}
          onClose={() => setConversion(null)}
        />
      )}
      {effectsRow && data && catalog.data && npcs.data && (
        <EffectsDialog
          key={effectsRow.c.id}
          target={{
            id: effectsRow.c.id,
            name: effectsRow.c.name,
            tags: effectsRow.c.tags ?? [],
            advantage: advantageOf(effectsRow.c),
            tempHp: effectsRow.c.tempHp ?? 0,
            acBonus: effectsRow.c.acBonus ?? 0,
            playerTemp: effectsRow.c.kind === 'player' ? effectsRow.derived.temp : undefined,
            hasHp: !!effectsRow.derived.hp,
            ac: effectsRow.detail?.ac ?? null,
          }}
          // La CA con el bono la calcula el motor: se aplica la acción sobre el
          // combate en memoria (sin guardar) y se lee el total de esa fila. La
          // pantalla no suma.
          previewAc={(bonus) => {
            const cat = catalog.data!;
            const next = encounter.data ? encounterAct(cat, encounter.data, { type: 'setAcBonus', combatantId: effectsRow.c.id, value: bonus }) : null;
            if (!next) return effectsRow.detail?.acTotal ?? null;
            return encounterDetails(cat, next, data.levels, npcs.data!).rows.find((r) => r.id === effectsRow.c.id)?.acTotal ?? null;
          }}
          act={writer.act}
          onClose={() => setEffectsId(null)}
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
      {dialog === 'finish' && data?.view && (
        <EndCombatDialog
          fallen={data.rows.flatMap(({ c, derived }) => c.kind === 'npc' && c.npcId && derived.down
            ? [{ npcId: c.npcId, name: c.name, side: c.side }]
            : [])}
          onFinish={writer.close}
          onDiscard={writer.discard}
          onClose={() => setDialog(null)}
        />
      )}
      {toast && <Toast key={toast.key} tone={toast.tone} message={toast.message} action={toast.action} open onOpenChange={(open) => !open && setToast(null)} />}
    </div>
  );
}

/** La placa de arriba: ronda, turno y cuántos quedan en pie; o, mientras se
 *  arma, que todavía no empezó. */
function ControlBar({ view, onAdd, onDiscard, onFinish, onNext }: { view: EncounterView; onAdd: () => void; onDiscard: () => void; onFinish: () => void; onNext: () => void }) {
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
      <Button tone="soft" icon={CheckCheck} data-action="finish-combat" onClick={onFinish}>
        {t.encFinish}
      </Button>
      <Button icon={SkipForward} data-action="next-turn" disabled={view.encounter.combatants.length === 0} onClick={onNext}>
        {t.dmNextTurn}
      </Button>
    </div>
  );
}

function SideWipedBanner({ standing, onFinish }: { standing: EncounterView['standing']; onFinish: () => void }) {
  const t = useTexts();
  const enemiesWiped = standing.enemies > 0 && standing.enemiesUp === 0;
  const alliesWiped = standing.allies > 0 && standing.alliesUp === 0;
  if (!enemiesWiped && !alliesWiped) return null;

  const message = enemiesWiped && alliesWiped ? t.encNobodyStanding : enemiesWiped ? t.encNoEnemyStanding : t.encNoAllyStanding;
  // Los PG se releen cada 5 s. Un diálogo automático interrumpiría al DM mientras escribe.
  return (
    <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-2 rounded-[var(--radius-nav)] border border-gold px-3 py-2">
      <span>{message} {t.encWrapUp}</span>
      <Button icon={CheckCheck} data-action="finish-combat-banner" onClick={onFinish}>
        {t.encFinish}
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
  /** Saca un efecto de la fila (la ✕ de su chip). */
  removeTag?: (tag: string) => void;
  /** Gasta o devuelve legendarias: el valor nuevo de gastadas. */
  setLegendary?: (kind: 'actions' | 'resistances', value: number) => void;
}

const advantageOf = (c: CombatantJson): 'advantage' | 'disadvantage' | null => (c.advantage === 'advantage' || c.advantage === 'disadvantage' ? c.advantage : null);
/** Lo que el DM le puso a la fila y se usa en turnos ajenos: ventaja o
 *  desventaja, temporales y bono a la CA. */
const hasMarks = ({ c, derived }: Row) => advantageOf(c) !== null || derived.temp > 0 || (c.acBonus ?? 0) > 0;
const hasLegendary = ({ detail }: Row) => (detail?.legendaryActions ?? 0) > 0 || (detail?.legendaryResistances ?? 0) > 0;

/** Las marcas de acciones (círculos) o resistencias (rombos) legendarias, para
 *  tacharlas tocándolas. Tocar una disponible la gasta junto con las anteriores y
 *  tocar una gastada la devuelve junto con las que le siguen: así se corrige un
 *  toque de más sin un botón aparte (`_LegendaryPips` de Flutter). Con la fila
 *  partida (teléfono) el área tocable es de 40 px y el rótulo va arriba y entero:
 *  a 28 px las marcas quedaban pegadas y se tachaba la de al lado. */
function LegendaryPips({ kind, max, spent, onChange }: { kind: 'actions' | 'resistances'; max: number; spent: number; onChange: (value: number) => void }) {
  const t = useTexts();
  const diamond = kind === 'resistances';
  const full = diamond ? t.encLegendaryResistances : t.encLegendaryActions;
  return (
    <div className="flex flex-wrap items-center @[760px]:flex-nowrap">
      <span className="basis-full text-[10.5px] text-on-surface-variant @[760px]:hidden">{full}</span>
      {Array.from({ length: max }, (_, i) => (
        <button
          key={i}
          type="button"
          aria-pressed={i < spent}
          aria-label={t.encLegendaryPip(full, i + 1, max)}
          data-legendary={`${kind}-${i}`}
          onClick={() => onChange(i < spent ? i : i + 1)}
          className="inline-flex h-10 w-10 items-center justify-center @[760px]:h-7 @[760px]:w-7"
        >
          {/* Disponible: llena en oro. Gastada: vacía y atenuada. */}
          <span className={cx('box-border block border-[1.5px]', diamond ? 'h-2.5 w-2.5 rotate-45' : 'h-3 w-3 rounded-full', i < spent ? 'border-text-muted' : 'border-gold bg-gold')} />
        </button>
      ))}
      <span className="ml-1.5 hidden text-[10.5px] text-on-surface-variant @[760px]:inline">{diamond ? t.encResistShort : t.encLegendaryShort}</span>
    </div>
  );
}

/** La barra de PG con los temporales pegados: el tramo carmesí es
 *  `actual / (máximo + temporales)` y el dorado `temporales / (máximo +
 *  temporales)`. Sin temporales es la barra de siempre (`ThinBar`). */
function HpBar({ current, max, temp, label }: { current: number; max: number; temp: number; label: string }) {
  const total = max + temp;
  const pct = (n: number) => (total <= 0 ? 0 : Math.min(100, Math.max(0, (n / total) * 100)));
  return (
    <div
      role="meter"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={Math.max(0, Math.min(current, max))}
      className="flex h-[5px] w-full overflow-hidden rounded-[3px] bg-hairline"
    >
      <div className="thin-bar-fill h-full bg-crimson" style={{ width: `${pct(current)}%` }} />
      {temp > 0 && <div className="thin-bar-fill ml-px h-full bg-gold" style={{ width: `${pct(temp)}%` }} />}
    </div>
  );
}

function LedgerRow({ row, catalog, active, acted, preparing, showXp, sideControl, actions, fixInitiative, removeTag, setLegendary }: { row: Row; catalog: Catalog; active: boolean; acted: boolean; preparing: boolean; showXp: boolean } & RowExtras) {
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
  const acTotal = row.detail?.acTotal ?? null;
  const bonus = c.acBonus ?? 0;
  const adv = advantageOf(c);
  const hp = derived.hp;
  // Solo en curso: mientras se arma no hay nada que gastar.
  const legendary = hasLegendary(row);
  // Lo que ya jugó esta ronda se atenúa en sus datos y **no en sus botones**: al
  // goblin que ya actuó se le sigue pegando, y un botón gris se lee como apagado.
  // Un caído se atenúa entero: ahí sí terminó (a pedido del usuario). Una fila con
  // marcas o con legendarias **no se atenúa** aunque ya haya jugado, porque lo que lleva (ventaja,
  // temporales, bono a la CA) se usa en turnos ajenos; un caído sí, siempre.
  const faded = (derived.down || (acted && !hasMarks(row) && !(legendary && !preparing))) && 'opacity-60';
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
        <div className="flex min-w-0 items-center gap-[7px]">
          <div className={cx('font-display min-w-0 truncate text-[15px] text-on-surface', derived.down && 'line-through')}>{c.name}</div>
          {/* Rellena y sin atenuar: se tiene que leer de un vistazo y de lejos. */}
          {adv && (
            <span
              className={cx('inline-flex h-[19px] shrink-0 items-center gap-[3px] rounded-[var(--radius-pill)] pr-2 pl-[5px] text-[11px] font-bold text-on-primary', adv === 'advantage' ? 'bg-verdant' : 'bg-crimson')}
              data-field="advantage"
            >
              {adv === 'advantage' ? <ArrowUp size={12} strokeWidth={3} aria-hidden="true" /> : <ArrowDown size={12} strokeWidth={3} aria-hidden="true" />}
              {adv === 'advantage' ? t.encAdvantage : t.encDisadvantage}
            </span>
          )}
        </div>
        <div className="mt-[3px] flex min-w-0 items-center gap-1.5">
          {!player &&
            (sideControl ?? (
              <span className={cx('shrink-0 rounded-[var(--radius-pill)] border px-2 text-[11px]', SIDE_TONE[c.side] ?? SIDE_TONE.neutral)} data-field="side">
                {t.encSides[c.side] ?? c.side}
              </span>
            ))}
          <span className={cx('truncate text-[11.5px]', derived.down ? 'text-crimson' : 'text-on-surface-variant')}>{[xpText, metaOf(row, derived.down, catalog, t)].filter(Boolean).join(' · ')}</span>
        </div>
        {!preparing && legendary && setLegendary && (
          <div className="mt-[3px] flex flex-wrap items-center gap-x-3">
            {(row.detail?.legendaryActions ?? 0) > 0 && (
              <LegendaryPips kind="actions" max={row.detail!.legendaryActions} spent={c.legendaryActionsSpent ?? 0} onChange={(v) => setLegendary('actions', v)} />
            )}
            {(row.detail?.legendaryResistances ?? 0) > 0 && (
              <LegendaryPips kind="resistances" max={row.detail!.legendaryResistances} spent={c.legendaryResistancesSpent ?? 0} onChange={(v) => setLegendary('resistances', v)} />
            )}
          </div>
        )}
      </div>
      <div className={cx('order-4 col-span-2 col-start-2 mt-2 @[760px]:order-3 @[760px]:col-auto @[760px]:mt-0', faded)} data-field="hp">
        {hp ? (
          <>
            <div className="flex items-baseline gap-2">
              <span className="num text-[13.5px] text-crimson" data-field="hp-value">
                {hp.current}/{hp.max}
              </span>
              {derived.temp > 0 && (
                <span className="num text-[13.5px] text-gold" aria-label={t.encTempAria(derived.temp)} data-field="hp-temp">
                  +{derived.temp}
                </span>
              )}
              {derived.bloodied && <span className="text-[9.5px] font-semibold tracking-[.8px] text-crimson uppercase">{t.encBloodied}</span>}
            </div>
            <div className="mt-[5px]">
              <HpBar current={hp.current} max={hp.max} temp={derived.temp} label={t.dmHpAria(hp.current, hp.max)} />
            </div>
          </>
        ) : (
          <span className="text-[12px] text-text-muted">{t.encNoHp}</span>
        )}
      </div>
      <div className={cx('order-3 text-center @[760px]:order-4', faded)} data-field="ac">
        <span className="plaque-label block @[760px]:hidden">{t.encAc}</span>
        {bonus > 0 ? (
          <>
            {/* Con bono, el total en oro con un escudo; debajo, la CA base y el bono. */}
            <div className="num inline-flex items-center gap-[3px] text-[15px] text-gold">
              {acTotal !== null && <Shield size={13} fill="currentColor" aria-hidden="true" />}
              {acTotal ?? ac ?? t.dmNoValue}
            </div>
            <div className="text-[10.5px] font-semibold text-gold">{acTotal !== null ? `${ac} +${bonus}` : `+${bonus}`}</div>
          </>
        ) : (
          <div className="num text-[14px] text-on-surface">{ac ?? t.dmNoValue}</div>
        )}
      </div>
      <div className={cx('order-5 col-span-2 col-start-2 mt-2 flex-wrap gap-[5px] @[760px]:col-auto @[760px]:mt-0 @[760px]:flex', (c.tags ?? []).length > 0 ? 'flex' : 'hidden', faded)}>
        {(c.tags ?? []).map((tag) => {
          const label = tagLabel(t, tag);
          return (
            <span key={tag} className="plaque inline-flex items-center gap-1 rounded-[var(--radius-pill)] py-px pr-1 pl-[9px] text-[11.5px] text-on-surface">
              {label}
              <button type="button" aria-label={t.dmRemoveTag(label)} onClick={() => removeTag?.(tag)} className="flex items-center text-on-surface-variant hover:text-on-surface">
                <X size={12} strokeWidth={2.5} aria-hidden="true" />
              </button>
            </span>
          );
        })}
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
  onEffects: (row: Row) => void;
  onConvert: (row: Row) => void;
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
function rowParts(row: Row, { campaignId, act, t, running, amount, readAmount, onFix, onEffects, onConvert }: RowCtx): RowExtras {
  const { c, detail, member } = row;
  const removeTag = (tag: string) => act({ type: 'setTags', combatantId: c.id, tags: (c.tags ?? []).filter((x) => x !== tag) });
  // Dorado y relleno si el combatiente lleva algo; apagado si no.
  const marked = (c.tags ?? []).length > 0 || hasMarks(row);
  const effects = (
    <Tooltip content={t.encEffectsAndDefenses}>
      <button
        type="button"
        aria-label={t.encEffectsAndDefenses}
        data-action="effects"
        onClick={() => onEffects(row)}
        className={cx('flex h-12 w-12 items-center justify-center rounded-[var(--radius-nav)] @[760px]:h-11 @[760px]:w-11', marked ? 'text-gold' : 'text-on-surface-variant hover:text-on-surface')}
      >
        <Tag size={19} fill={marked ? 'currentColor' : 'none'} aria-hidden="true" />
      </button>
    </Tooltip>
  );
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
      removeTag,
      actions: (
        <>
          {member && c.memberId ? <OpenSheetLink campaignId={campaignId} memberId={c.memberId} /> : <span className="text-[11px] text-text-muted">{t.encOnTheirSheet}</span>}
          {effects}
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
    removeTag,
    setLegendary: (kind, value) => act({ type: 'setLegendary', combatantId: c.id, [kind]: value }),
    sideControl: (
      <SideMenu
        side={c.side}
        name={c.name}
        canChange={detail?.canChangeSide ?? false}
        onChange={(side) => act({ type: 'setSide', combatantId: c.id, side: side as 'ally' | 'enemy' | 'neutral' })}
        onConvert={row.creature ? () => onConvert(row) : undefined}
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
        {effects}
        {remove}
      </>
    ),
  };
}

/** «Del turno»: el perfil de quien está jugando. Un jugador no tiene perfil que
 *  mostrar, y se dice en vez de abrir la ficha ajena (`modo-dm.md`): el enlace
 *  lleva a la que el DM sí puede mirar. */
function TurnPanel({ row, rows, catalog, campaignId, act }: { row: Row | undefined; rows: Row[]; catalog: Catalog; campaignId: string; act: (a: EncounterAction) => void }) {
  const t = useTexts();
  const [background, setBackground] = useState(false);
  const [tab, setTab] = useState<'turn' | 'effects'>('turn');
  // Todos los efectos de la mesa, juntos: repartidos en filas que se mueven cuando
  // entra alguien, se pasa el veneno de turno.
  const effects = rows.flatMap((r) => (r.c.tags ?? []).map((tag) => ({ id: r.c.id, name: r.c.name, tag, tags: r.c.tags ?? [] })));
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
    <aside aria-label={t.encOfTurn} className="flex min-w-0 flex-[1_1_300px] flex-col gap-3 shell:max-w-[420px]" data-field="turn-panel">
      <div className="card overflow-hidden p-0">
        {/* Las solapas: la elegida lleva borde, color **y** peso, porque el color
            solo no alcanza para quien no distingue el oro del gris. */}
        <div role="tablist" aria-label={t.encOfTurn} className="flex border-b border-hairline">
          {(
            [
              ['turn', t.encOfTurn, null],
              ['effects', t.encEffects, effects.length],
            ] as const
          ).map(([id, label, count]) => (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={tab === id}
              data-tab={id}
              onClick={() => setTab(id)}
              className={cx(
                'flex h-[41px] flex-1 items-center justify-center gap-1.5 border-b-2 text-[12.5px]',
                tab === id ? 'border-gold font-semibold text-gold' : 'border-transparent text-on-surface-variant hover:text-on-surface',
              )}
            >
              {label}
              {count !== null && <span className="text-[11px]">{count}</span>}
            </button>
          ))}
        </div>
        {tab === 'turn' ? (
          <div role="tabpanel" className="flex flex-col gap-2.5 px-4 py-3.5">
            {body}
          </div>
        ) : (
          <div role="tabpanel" className="p-1.5 pl-3.5" data-field="effects-list">
            {effects.length === 0 ? (
              <AppEmptyState kind="empty" message={t.encNoEffects} />
            ) : (
              effects.map((e) => {
                const label = tagLabel(t, e.tag);
                return (
                  <div key={`${e.id}-${e.tag}`} className="flex min-h-12 items-center">
                    <div className="min-w-0 flex-1">
                      <div className="text-[13px] text-on-surface">{label}</div>
                      <div className="truncate text-[11.5px] text-text-muted">{e.name}</div>
                    </div>
                    {/* Su rótulo nombra al combatiente: el mismo efecto se saca desde
                        dos lugares y dos botones iguales no se distinguirían. */}
                    <button
                      type="button"
                      aria-label={t.encRemoveEffect(label, e.name)}
                      onClick={() => act({ type: 'setTags', combatantId: e.id, tags: e.tags.filter((x) => x !== e.tag) })}
                      className="flex h-11 w-11 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:text-on-surface"
                    >
                      <X size={18} aria-hidden="true" />
                    </button>
                  </div>
                );
              })
            )}
          </div>
        )}
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
  const { temp, hp } = { temp: row.derived.temp, hp: row.derived.hp };
  const bonus = row.c.acBonus ?? 0;
  const ac = bonus > 0 ? (row.detail?.acTotal ?? row.detail?.ac) : row.detail?.ac;
  return (
    // Iniciativa y CA angostas y los PG con el resto, como en la lámina: «118/256»
    // no entra en un tercio.
    <dl className="grid grid-cols-[56px_minmax(0,1fr)_56px] gap-2">
      {[
        { label: t.encInitiativeShort, value: <>{row.c.initiative}</>, tone: 'text-verdant' },
        {
          label: t.encHp,
          value: hp ? (
            <>
              {hp.current}/{hp.max}
              {temp > 0 && (
                <span className="text-gold" aria-label={t.encTempAria(temp)}>
                  {' '}
                  +{temp}
                </span>
              )}
            </>
          ) : (
            t.dmNoValue
          ),
          tone: 'text-crimson',
        },
        { label: t.encAc, value: ac ?? t.dmNoValue, tone: bonus > 0 ? 'text-gold' : 'text-on-surface' },
      ].map((s) => (
        <div key={s.label} className="plaque px-0.5 py-2 text-center">
          <dt className="plaque-label">{s.label}</dt>
          <dd className={cx('num mt-1 text-[17px] leading-none', s.tone)}>{s.value}</dd>
        </div>
      ))}
    </dl>
  );
}
