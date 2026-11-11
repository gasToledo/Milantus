import { useState } from 'react';
import { BookOpen, ChevronRight, Coins, Flag, Share2, Swords } from 'lucide-react';
import type { PlayerBattle, PlayerCampaign, PlayerNote } from '../api/client';
import { usePlayerCampaigns } from '../api/queries';
import { chapterGrants, type Catalog, type JsonObject } from '../engine';
import { useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { stamp } from '../dm/notebook';
import { MarkdownText } from '../ui/MarkdownText';
import { Eyebrow, Pill } from '../ui/data';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import type { SheetModel } from './model';
import { ShareDialog } from './ShareDialog';

/**
 * Pestaña Campaña: la vuelta del vínculo con el DM. Qué mesa, qué batallas se
 * pelearon y qué capítulos se cerraron con lo que repartieron. **Solo
 * lectura, sin excepciones**: lo repartido ya llegó como aviso y el jugador lo
 * anota en su ficha (es la frontera del Modo DM, `docs/arquitectura/modo-dm.md`).
 *
 * Lo que el servidor sí manda del texto del DM, a propósito: del capítulo en
 * curso, su nombre y su objetivo, y las notas que el DM marcó para la mesa (del
 * capítulo en curso y de los cerrados). Lo que no manda y por eso no se
 * muestra: el objetivo de los capítulos cerrados, los pendientes y las notas
 * privadas.
 */
export function CampaignTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const campaigns = usePlayerCampaigns(model.character.id);
  const [sharing, setSharing] = useState(false);

  if (campaigns.isError) {
    return <AppErrorView title={t.campaignsLoadError} message={t.errorBody} onRetry={() => campaigns.refetch()} />;
  }
  if (!campaigns.data) return <AppBusyLabel label={t.campaignsLoading} />;
  if (campaigns.data.length === 0) {
    // Vacío con salida: falta compartir la ficha, y el diálogo se abre acá.
    return (
      <>
      <AppEmptyState
        kind="empty"
        message={t.campaignEmpty}
        hint={t.campaignEmptyHint}
        actions={
          <Button icon={Share2} tone="secondary" onClick={() => setSharing(true)}>
            {t.actionShare}
          </Button>
        }
      />
      {sharing && (
        <ShareDialog characterId={model.character.id} characterName={model.character.name} onClose={() => setSharing(false)} />
      )}
      </>
    );
  }

  // Con varias campañas se apilan, sin selector: son una o dos.
  return (
    <div className="flex flex-col gap-8">
      {campaigns.data.map((pc) => (
        <CampaignBlock key={pc.memberId} pc={pc} catalog={model.catalog} me={model.character.name} />
      ))}
    </div>
  );
}

/** Una mesa de [pc]: la comparten la pestaña Campaña de la ficha y la pantalla
 *  Campañas. [me] es el personaje de ese vínculo, para no listarlo entre
 *  quienes pelearon con él; [catalog] nombra las criaturas de las batallas. */
export function CampaignBlock({ pc, catalog, me }: { pc: PlayerCampaign; catalog: Catalog; me: string }) {
  const t = useTexts();
  const { campaign } = pc;
  const state = campaign.state === 'paused' || campaign.state === 'finished' ? campaign.state : 'active';
  const party = pc.party ?? [];
  const chapters = pc.chapters ?? [];
  const battles = pc.battles ?? [];
  const id = pc.memberId;
  const current = pc.currentChapter ?? null;
  const notes = pc.sharedNotes ?? [];

  // Agrupadas por el capítulo en que se pelearon, en el orden de los
  // capítulos y de la más vieja a la más nueva (`battlesOf` en Flutter). Un
  // capítulo sin batallas no aporta un encabezado vacío; las que no caen en
  // ninguno van al final.
  const oldestFirst = [...battles].reverse();
  const shown = new Set(chapters.map((c) => c.id));
  const groups = [
    ...chapters.map((c) => ({
      key: c.id,
      title: c.name ?? '',
      list: oldestFirst.filter((b) => b.chapterId === c.id),
    })),
    { key: '-', title: t.campaignNoChapter, list: oldestFirst.filter((b) => !shown.has(b.chapterId ?? '')) },
  ].filter((g) => g.list.length > 0);
  const rounds = battles.reduce((sum, b) => sum + (b.rounds ?? 1), 0);

  return (
    <div className="flex flex-col gap-4" data-campaign={id}>
      <section aria-labelledby={`h-campaign-${id}`} className="card px-[18px] py-4">
        <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
          <h2 id={`h-campaign-${id}`} className="flex items-center gap-2.5">
            <Flag size={18} aria-hidden="true" className="shrink-0 text-gold" />
            <span className="font-display text-[22px] break-words text-on-surface">{campaign.name}</span>
          </h2>
          <Pill highlighted={state === 'active'}>{t.campaignStates[state]}</Pill>
        </div>
        {campaign.premise && (
          <p className="mt-2.5 max-w-[620px] leading-[1.55] whitespace-pre-line text-on-surface-variant">
            {campaign.premise}
          </p>
        )}
        {party.length > 0 && (
          <p className="mt-2 text-[13px] text-text-muted">{t.campaignPartyAlso(party.length, joinNames(t, party))}</p>
        )}
      </section>

      {current && (
        <section
          aria-labelledby={`h-current-${id}`}
          data-card="current-chapter"
          className="card flex flex-col gap-3 border-2 border-gold px-[18px] py-4"
        >
          <h2 id={`h-current-${id}`} className="flex items-center gap-2.5">
            <BookOpen size={18} aria-hidden="true" className="shrink-0 text-gold" />
            <span className="font-display text-[16px] text-on-surface">{t.campaignCurrentChapter}</span>
          </h2>
          <div>
            <p className="font-display text-[20px] break-words text-on-surface">{current.name}</p>
            {current.summary?.trim() && (
              <p className="mt-1.5 max-w-[620px] text-[14px] leading-[1.55] whitespace-pre-line text-on-surface-variant">
                {current.summary}
              </p>
            )}
          </div>
          <TableNotes notes={notes.filter((n) => n.chapterId === current.id)} />
        </section>
      )}

      <div className="flex flex-wrap items-start gap-4">
        <Card
          id={`battles-${id}`}
          title={t.campaignBattles}
          icon={Swords}
          className="flex-[3_1_380px]"
          trailing={
            <span className="text-[12px] text-text-muted tabular-nums">
              {battles.length === 0 ? '—' : `${battles.length} · ${t.roundsCount(rounds)}`}
            </span>
          }
        >
          {groups.length === 0 ? (
            <p className="text-[13px] text-text-muted">{t.campaignNoBattles}</p>
          ) : (
            <div className="flex flex-col gap-4">
              {groups.map((g) => (
                <div key={g.key}>
                  <Eyebrow className="mb-2">{g.title}</Eyebrow>
                  <ul className="flex flex-col gap-2.5">
                    {g.list.map((b, i) => (
                      <BattleRow key={b.id ?? i} battle={b} me={me} catalog={catalog} />
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          )}
        </Card>

        <Card
          id={`chapters-${id}`}
          title={t.campaignClosedChapters}
          icon={BookOpen}
          className="flex-[2_1_300px]"
          trailing={<span className="text-[12px] text-text-muted tabular-nums">{chapters.length}</span>}
        >
          {chapters.length === 0 ? (
            <p className="text-[13px] text-text-muted">{t.campaignNoClosedChapters}</p>
          ) : (
            <ul className="flex flex-col gap-3.5">
              {chapters.map((c) => (
                <ChapterRow key={c.id} chapter={c} notes={notes.filter((n) => n.chapterId === c.id)} />
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}

/** Una batalla, hundida sobre la placa: la escribió la app y no se corrige. */
function BattleRow({ battle, me, catalog }: { battle: PlayerBattle; me: string; catalog: Catalog }) {
  const t = useTexts();
  // Quiénes más pelearon, por nombre: si el jugador se renombró después, la
  // línea los lista a todos en vez de romperse.
  const others = (battle.players ?? []).filter((n) => n !== me);
  const monsters = battle.monsters ?? [];
  const total = monsters.reduce((s, m) => s + (m.count ?? 1), 0);
  const down = monsters.reduce((s, m) => s + (m.defeated ?? 0), 0);
  const defeated =
    total === 0
      ? t.battleNoEnemies
      : down === 0
        ? t.battleNoneDown
        : down === total
          ? total === 1
            ? t.battleOneDown
            : t.battleAllDown
          : t.battleSomeDown(down, total);
  return (
    <li className="plaque flex items-start gap-3.5 px-3.5 py-3">
      <div className="min-w-0 flex-1">
        <p className="text-[14px] text-on-surface">{battleTitle(t, monsters, catalog)}</p>
        <p className="mt-0.5 text-[12px] text-text-muted">
          {[others.length === 0 ? t.battleAlone : t.battleWith(joinNames(t, others)), defeated].join(' · ')}
        </p>
      </div>
      <span className="shrink-0 text-[12px] whitespace-nowrap text-text-muted tabular-nums">
        {t.roundsCount(battle.rounds ?? 1)}
      </span>
    </li>
  );
}

/** «Contra 3 lobos y un ogro». Un PNJ sin criatura de base llega sin nombre:
 *  el jugador no tiene por qué saberlo, se lee «un enemigo». El nombre de una
 *  criatura del catálogo sale del catálogo, en el idioma activo
 *  (`logGroupName` en Flutter). */
function battleTitle(t: Texts, monsters: NonNullable<PlayerBattle['monsters']>, catalog: Catalog): string {
  if (monsters.length === 0) return t.battleGeneric;
  const names = monsters.map((m) => {
    const count = m.count ?? 1;
    if (!m.name) return count === 1 ? t.enemyOne : t.enemiesCount(count);
    const fromCatalog = m.creatureId ? catalog.creatures.find((c) => c.id === m.creatureId)?.name : undefined;
    const name = typeof fromCatalog === 'string' ? fromCatalog : m.name;
    return count === 1 ? name : `${name} ×${count}`;
  });
  return t.battleAgainst(joinNames(t, names));
}

/** Las notas que el DM marcó para la mesa: placas hundidas, con el Markdown de
 *  la mesa. Sin notas no dibuja nada (ni el rótulo). */
function TableNotes({ notes }: { notes: PlayerNote[] }) {
  const t = useTexts();
  if (notes.length === 0) return null;
  const now = Date.now();
  return (
    <div className="flex flex-col gap-2" data-field="table-notes">
      <Eyebrow>{t.campaignTableNotes}</Eyebrow>
      {notes.map((n) => (
        <article key={n.id} data-note={n.id} className="plaque flex flex-col gap-1.5 px-3.5 py-3">
          <div className="flex items-baseline gap-2.5">
            <h3 className="font-display min-w-0 flex-1 text-[15px] break-words text-on-surface">{n.title}</h3>
            <span className="text-[12px] text-text-muted tabular-nums">
              {stamp(n.updatedAt ? Date.parse(n.updatedAt) : null, now, t)}
            </span>
          </div>
          {n.body?.trim() && (
            <MarkdownText text={n.body} className="max-w-[620px] text-[14px] leading-[1.55] text-on-surface" />
          )}
        </article>
      ))}
    </div>
  );
}

function ChapterRow({ chapter, notes }: { chapter: JsonObject & { id: string; name?: string }; notes: PlayerNote[] }) {
  const t = useTexts();
  // Plegado de entrada y solo se abre al tocarlo: nada se despliega solo.
  const [open, setOpen] = useState(false);
  // Lo repartido lo nombra el motor (`Chapter.grantsLabel`), en su idioma.
  const grants = chapterGrants(chapter);
  return (
    <li className="border-l-2 border-hairline pl-3.5" data-chapter={chapter.id}>
      <p className="font-display text-[15px] text-on-surface">{chapter.name}</p>
      {grants ? (
        <p className="mt-1.5 flex gap-1.5 text-[13px] text-text-muted">
          <Coins size={15} aria-hidden="true" className="mt-px shrink-0 text-gold" />
          <span>{t.campaignYouTook(grants)}</span>
        </p>
      ) : (
        <p className="mt-1.5 text-[13px] text-text-muted">{t.campaignNoRewards}</p>
      )}
      {notes.length > 0 && (
        <>
          <button
            type="button"
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
            className="mt-1 flex h-8 items-center gap-1.5 text-[13px] text-gold"
          >
            <ChevronRight size={14} aria-hidden="true" className={open ? 'rotate-90' : ''} />
            {t.campaignTableNotesCount(notes.length)}
          </button>
          {open && (
            <div className="mt-1.5">
              <TableNotes notes={notes} />
            </div>
          )}
        </>
      )}
    </li>
  );
}

/** «Mirna», «Mirna y Bardo», «Mirna, Bardo y Yina». */
function joinNames(t: Texts, names: string[]): string {
  if (names.length <= 1) return names.join('');
  return t.listAnd(names.slice(0, -1).join(', '), names[names.length - 1]!);
}
