import { useMemo } from 'react';
import { useCampaignEncounter, useCampaignMembers, useCampaignNotebook, useCampaignNpcs, useSheetCatalog } from '../api/queries';
import type { DmCampaign } from '../api/client';
import { CreatureProfile } from '../bestiary/CreatureProfile';
import { asProfile } from '../bestiary/creature';
import { toRosterEntry, type RosterEntry } from '../dashboard/roster';
import { bestiary, encounterView, npcViews, type BestiaryRow, type Catalog, type CombatantJson, type EncounterView, type JsonObject, type NpcView } from '../engine';
import { useLang, useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { cx } from '../ui/cx';
import { ThinBar } from '../ui/data';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import { DmHeader } from './DmHeader';
import { buildEntries } from './notebook';
import { npcTypeLine } from './npcs/npc';

/** Las cinco columnas de la planilla, iguales en la cabecera y en cada fila. */
const LEDGER = 'grid grid-cols-[56px_minmax(0,1fr)_150px_50px_minmax(0,160px)] gap-3.5';

const SIDE_TONE: Record<string, string> = {
  ally: 'border-verdant text-verdant',
  enemy: 'border-crimson text-crimson',
  neutral: 'border-text-muted text-text-muted',
};

/** Lo que la pantalla cruza para cada fila: el combatiente, lo que derivó el
 *  motor, y de dónde sale su perfil. */
interface Row {
  c: CombatantJson;
  derived: EncounterView['rows'][number];
  member: RosterEntry | undefined;
  npc: NpcView | undefined;
  creature: { row: BestiaryRow; raw: JsonObject } | undefined;
}

/**
 * El combate abierto de la campaña (`encounter_view.dart`), de **solo lectura**:
 * el orden de iniciativa con el turno, los PG, la CA y los efectos de cada
 * combatiente, quién queda en pie, el perfil del que juega y, abajo, los
 * combates ya cerrados. Ningún control: tirar iniciativa, dañar, curar, pasar
 * el turno, sumar o sacar y cerrar siguen en Flutter.
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

  const data = useMemo(() => {
    const cat = catalog.data;
    if (encounter.data === undefined || !members.data || !npcs.data || !notebook.data || !cat) return null;
    const byMember = new Map(members.data.map((m) => [m.memberId, toRosterEntry(m.character, '', cat)] as const));
    // Los actuales salen de la ficha cruda (no son una regla); el máximo, del
    // motor. Sin ficha calculada, el jugador va sin PG antes que con unos falsos.
    const playersHp: Record<string, { current: number; max: number }> = {};
    for (const [id, e] of byMember) if (e.sheet) playersHp[id] = { current: e.character.combat?.currentHp ?? 0, max: e.sheet.maxHp };
    const view = encounter.data ? encounterView(encounter.data, playersHp) : null;
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
            member: c.memberId ? byMember.get(c.memberId) : undefined,
            npc: c.npcId ? npcById.get(c.npcId) : undefined,
            creature: row && raw ? { row, raw } : undefined,
          };
        })
      : [];
    // Los combates cerrados, del más nuevo al más viejo, redactados como en el
    // Cuaderno.
    const past = buildEntries({ notes: [], encounterLogs: notebook.data.encounterLogs, levelUps: [] }, [], t, cat).reverse();
    return { view, rows, past, cat };
  }, [encounter.data, members.data, npcs.data, notebook.data, catalog.data, t]);

  const failed = [encounter, members, npcs, notebook, ...catalog.queries].filter((q) => q.isError);
  const kicker = data?.view ? (data.view.preparing ? t.encPreparing : `${t.encRunning} · ${campaign.name}`) : campaign.name;

  let body;
  if (failed.length > 0) {
    body = <AppErrorView title={t.encReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />;
  } else if (!data) {
    body = <AppBusyLabel label={t.encLoading} />;
  } else {
    const { view, rows, past, cat } = data;
    body = (
      <>
        {!view ? (
          <AppEmptyState kind="empty" message={t.encNone} hint={t.encNoneHint} />
        ) : (
          <>
            <ControlBar view={view} />
            {rows.length === 0 ? (
              <AppEmptyState kind="empty" message={t.encEmptyOrder} />
            ) : (
              <div className="flex flex-wrap items-start gap-4">
                <Ledger view={view} rows={rows} />
                {!view.preparing && <TurnPanel row={rows.find((r) => r.c.id === view.currentId)} catalog={cat} />}
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
      <DmHeader title={t.dmSectionCombat} kicker={kicker} />
      {body}
    </div>
  );
}

/** La placa de arriba: ronda, turno y cuántos quedan en pie; o, mientras se
 *  arma, que todavía no empezó. */
function ControlBar({ view }: { view: EncounterView }) {
  const t = useTexts();
  const plaque = 'plaque flex flex-wrap items-center gap-x-[18px] gap-y-2.5 px-4 py-3';
  if (view.preparing) {
    return (
      <div className={plaque}>
        <div>
          <p className="font-display text-[20px] text-on-surface">{t.encPreparing}</p>
          <p className="mt-0.5 text-[12px] text-text-muted">{t.encPreparingNote}</p>
        </div>
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
function Ledger({ view, rows }: { view: EncounterView; rows: Row[] }) {
  const t = useTexts();
  return (
    <section aria-label={t.encOrder} className="card min-w-0 flex-[999_1_640px] overflow-x-auto p-0">
      <div className="min-w-[560px]">
        <div className={cx(LEDGER, 'eyebrow border-b border-hairline px-3.5 py-2.5')} aria-hidden="true">
          <span className="text-center">{t.encInitiativeShort}</span>
          <span>{t.encCombatant}</span>
          <span>{t.encHp}</span>
          <span className="text-center">{t.encAc}</span>
          <span>{t.encEffects}</span>
        </div>
        <ol>
          {rows.map((r, i) => (
            <LedgerRow
              key={r.c.id}
              row={r}
              active={r.c.id === view.currentId}
              acted={!view.preparing && view.currentIndex >= 0 && i < view.currentIndex}
              preparing={view.preparing}
            />
          ))}
        </ol>
      </div>
    </section>
  );
}

function LedgerRow({ row, active, acted, preparing }: { row: Row; active: boolean; acted: boolean; preparing: boolean }) {
  const t = useTexts();
  const { c, derived } = row;
  const player = c.kind === 'player';
  const mark = derived.down ? t.encSkips : active ? t.encTurnWord : acted ? t.encActed : '';
  const ac = armorClassOf(row);
  const hp = derived.hp;
  return (
    <li
      className={cx(
        LEDGER,
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
        <div className={cx('mt-[3px] text-[9px] font-semibold tracking-[.8px] uppercase', derived.down ? 'text-crimson' : active ? 'text-verdant' : 'text-text-muted')} data-field="mark">
          {mark}
        </div>
      </div>
      <div className="min-w-0">
        <div className={cx('font-display truncate text-[15px] text-on-surface', derived.down && 'line-through')}>{c.name}</div>
        <div className="mt-[3px] flex min-w-0 items-center gap-1.5">
          {!player && (
            <span className={cx('shrink-0 rounded-[var(--radius-pill)] border px-2 text-[11px]', SIDE_TONE[c.side] ?? SIDE_TONE.neutral)} data-field="side">
              {t.encSides[c.side] ?? c.side}
            </span>
          )}
          <span className={cx('truncate text-[11.5px]', derived.down ? 'text-crimson' : 'text-on-surface-variant')}>{metaOf(row, derived.down, t)}</span>
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
            {player && <div className="mt-[3px] text-[11px] text-text-muted">{t.encOnTheirSheet}</div>}
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
    </li>
  );
}

/** La CA de la fila: la de la ficha compilada de un jugador, la del bloque o
 *  la ficha de un PNJ (que da el motor), la del catálogo de un monstruo. */
function armorClassOf({ c, member, npc, creature }: Row): string | null {
  if (c.kind === 'player') return member?.sheet ? String(member.sheet.armorClass) : null;
  if (c.kind === 'npc') return npc?.armorClass ?? null;
  return typeof creature?.raw.ac === 'string' || typeof creature?.raw.ac === 'number' ? String(creature.raw.ac) : null;
}

/** La línea bajo el nombre: especie y clases de un jugador, la línea de tipo
 *  de un PNJ o de un monstruo; un caído dice que se salta su turno. */
function metaOf({ c, member, npc, creature }: Row, down: boolean, t: Texts): string {
  if (down) return t.encDownMeta;
  if (c.kind === 'player') {
    if (!member) return '';
    return t.npcCharacterLine(member.raceName, member.classes.map((k) => `${k.name} ${k.level}`).join(' · '));
  }
  if (c.kind === 'npc') return npc ? npcTypeLine(npc, t) : '';
  return creature?.row.kind ?? '';
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
    // El perfil del Bestiario es su propia tarjeta: va debajo, no adentro.
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
        {row && row.c.kind !== 'player' && (
          <dl className="grid grid-cols-3 gap-2">
            {[
              { label: t.encInitiativeShort, value: String(row.c.initiative), tone: 'text-verdant' },
              { label: t.encHp, value: row.derived.hp ? `${row.derived.hp.current}/${row.derived.hp.max}` : t.dmNoValue, tone: 'text-crimson' },
              { label: t.encAc, value: armorClassOf(row) ?? t.dmNoValue, tone: 'text-on-surface' },
            ].map((s) => (
              <div key={s.label} className="plaque px-0.5 py-2 text-center">
                <dt className="plaque-label">{s.label}</dt>
                <dd className={cx('num mt-1 text-[17px] leading-none', s.tone)}>{s.value}</dd>
              </div>
            ))}
          </dl>
        )}
        {body}
      </div>
      {row?.creature && (
        <CreatureProfile profile={asProfile(row.creature.raw)} row={row.creature.row} catalog={catalog} />
      )}
    </aside>
  );
}
