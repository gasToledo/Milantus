import { BookOpen, Coins, Flag, Share2, Swords } from 'lucide-react';
import type { PlayerBattle, PlayerCampaign } from '../api/client';
import { usePlayerCampaigns } from '../api/queries';
import { chapterGrants, type JsonObject } from '../engine';
import { useTexts } from '../i18n/context';
import type { Texts } from '../i18n/texts';
import { FLUTTER_HOME } from '../router';
import { ButtonLink } from '../ui/Button';
import { Card } from '../ui/Card';
import { Eyebrow, Pill } from '../ui/data';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';
import type { SheetModel } from './model';

/**
 * Pestaña Campaña: la vuelta del vínculo con el DM. Qué mesa, qué batallas se
 * pelearon y qué capítulos se cerraron con lo que repartieron. **Solo
 * lectura, sin excepciones**: lo repartido ya llegó como aviso y el jugador lo
 * anota en su ficha (es la frontera del Modo DM, `docs/arquitectura/modo-dm.md`).
 *
 * Lo que no muestra porque el servidor no lo manda: la descripción de los
 * capítulos, los que no se cerraron y el que está en marcha.
 */
export function CampaignTab({ model }: { model: SheetModel }) {
  const t = useTexts();
  const campaigns = usePlayerCampaigns(model.character.id);

  if (campaigns.isError) {
    return <AppErrorView title={t.campaignsLoadError} message={t.errorBody} onRetry={() => campaigns.refetch()} />;
  }
  if (!campaigns.data) return <AppBusyLabel label={t.campaignsLoading} />;
  if (campaigns.data.length === 0) {
    // Vacío con salida: falta compartir la ficha, y eso todavía vive en Flutter.
    return (
      <AppEmptyState
        kind="empty"
        message={t.campaignEmpty}
        hint={t.campaignEmptyHint}
        actions={
          <ButtonLink href={FLUTTER_HOME} icon={Share2} tone="secondary">
            {t.actionShare}
          </ButtonLink>
        }
      />
    );
  }

  // Con varias campañas se apilan, sin selector: son una o dos.
  return (
    <div className="flex flex-col gap-8">
      {campaigns.data.map((pc) => (
        <CampaignBlock key={pc.memberId} pc={pc} model={model} />
      ))}
    </div>
  );
}

function CampaignBlock({ pc, model }: { pc: PlayerCampaign; model: SheetModel }) {
  const t = useTexts();
  const { campaign } = pc;
  const state = campaign.state === 'paused' || campaign.state === 'finished' ? campaign.state : 'active';
  const party = pc.party ?? [];
  const chapters = pc.chapters ?? [];
  const battles = pc.battles ?? [];
  const id = pc.memberId;

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
                      <BattleRow key={b.id ?? i} battle={b} me={model.character.name} model={model} />
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
                <ChapterRow key={c.id} chapter={c} />
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}

/** Una batalla, hundida sobre la placa: la escribió la app y no se corrige. */
function BattleRow({ battle, me, model }: { battle: PlayerBattle; me: string; model: SheetModel }) {
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
        <p className="text-[14px] text-on-surface">{battleTitle(t, monsters, model)}</p>
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
function battleTitle(t: Texts, monsters: NonNullable<PlayerBattle['monsters']>, { catalog }: SheetModel): string {
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

function ChapterRow({ chapter }: { chapter: JsonObject & { id: string; name?: string } }) {
  const t = useTexts();
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
    </li>
  );
}

/** «Mirna», «Mirna y Bardo», «Mirna, Bardo y Yina». */
function joinNames(t: Texts, names: string[]): string {
  if (names.length <= 1) return names.join('');
  return t.listAnd(names.slice(0, -1).join(', '), names[names.length - 1]!);
}
