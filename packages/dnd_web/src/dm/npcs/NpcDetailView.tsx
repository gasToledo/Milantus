import { useMemo } from 'react';
import { ArrowLeft, ScrollText } from 'lucide-react';
import { ApiError } from '../../api/client';
import { useNpc, useSheetCatalog } from '../../api/queries';
import { npcViews, type NpcView } from '../../engine';
import { useLang, useTexts } from '../../i18n/context';
import { dmNpcSheetHref, dmNpcsHref, Link } from '../../router';
import { signed } from '../../sheet/format';
import { DiaryEntries } from '../../sheet/DiaryTab';
import { Card } from '../../ui/Card';
import { cx } from '../../ui/cx';
import { Pill, StatPlaque } from '../../ui/data';
import { MarkdownText } from '../../ui/MarkdownText';
import { Medallion } from '../../ui/Medallion';
import { AppBusyLabel, AppErrorView, Notice } from '../../ui/status';
import { Abbr } from '../MemberCard';
import { kindOf, npcTypeLine, STATUS_TONE, statusOf } from './npc';

/** Cuántas acciones del bloque se ven en la tarjeta, como en Flutter: el perfil
 *  entero es del editor de bloques. */
const BLOCK_ACTIONS = 4;

/**
 * La ficha de un PNJ (`npc_detail_screen.dart`), de solo lectura: quién es,
 * cómo habla, qué se sabe de él, con qué pelea y cómo está en cada campaña. Es
 * del DM y de nadie más: un PNJ ajeno y uno inexistente responden el mismo 404
 * y la pantalla dice lo mismo. Renombrar, tags, el bloque, el retrato, el
 * estado por campaña, exportar y borrar siguen en Flutter.
 */
export function NpcDetailView({ npcId }: { npcId: string }) {
  const t = useTexts();
  const lang = useLang();
  const stored = useNpc(npcId);
  const catalog = useSheetCatalog(lang);
  const view = useMemo(
    () => (stored.data && catalog.data ? npcViews([stored.data], catalog.data)[0] : null),
    [stored.data, catalog.data],
  );

  const back = (
    <Link href={dmNpcsHref()} className="inline-flex items-center gap-1.5 self-start text-[13px] text-on-surface-variant hover:text-gold">
      <ArrowLeft size={16} aria-hidden="true" className="text-gold" />
      {t.dmNpcLibrary}
    </Link>
  );

  if (stored.error instanceof ApiError && stored.error.status === 404) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <Notice title={t.npcNotFound} body={t.npcNotFoundBody} />
      </div>
    );
  }
  const failed = [stored, ...catalog.queries].filter((q) => q.isError);
  if (failed.length > 0) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <AppErrorView as="h1" title={t.npcReadFail} message={t.errorBody} onRetry={() => failed.forEach((q) => q.refetch())} />
      </div>
    );
  }
  if (!view || !stored.data) {
    return (
      <div className="flex flex-col gap-4">
        {back}
        <h1 className="sr-only">{t.dmNpcLibrary}</h1>
        <AppBusyLabel label={t.npcLoading} />
      </div>
    );
  }

  const { npc } = view;
  const speech = npc.speech?.trim() ?? '';
  const background = npc.background?.trim() ?? '';
  return (
    <div className="flex flex-col gap-5" data-npc={npc.id}>
      {back}
      <header className="flex flex-wrap items-start gap-[18px]">
        <Medallion name={npc.name} accent={null} size={76} />
        <div className="flex min-w-0 flex-[1_1_300px] flex-col gap-2">
          <h1 className="font-display text-[28px] leading-tight break-words text-on-surface">{npc.name}</h1>
          <ul className="flex flex-wrap gap-1.5">
            <Pill as="li" className="text-[12px]">
              <span data-field="type">{npcTypeLine(view, t)}</span>
            </Pill>
            {(npc.tags ?? []).map((tag) => (
              <Pill as="li" key={tag} highlighted={false} className="text-[12px]">
                {tag}
              </Pill>
            ))}
          </ul>
          {/* La voz va bajo el nombre y no en una tarjeta: es lo primero que el
              DM necesita para interpretarlo, y como cita no pide rótulo. */}
          <blockquote className="mt-1 flex max-w-[620px] gap-2" aria-label={t.npcSpeech} data-field="speech">
            <span aria-hidden="true" className="font-display text-[34px] leading-[0.9] text-gold">
              “
            </span>
            <span className={cx('pt-1.5 text-[16px] leading-normal italic', speech ? 'text-on-surface' : 'text-text-muted')}>
              {speech || t.npcSpeechEmpty}
            </span>
          </blockquote>
        </div>
      </header>

      <div className="flex flex-wrap items-start gap-4">
        <div className="flex min-w-0 flex-[999_1_420px] flex-col gap-4">
          <Card id="npc-background" title={t.npcBackground} icon={ScrollText}>
            {background ? (
              <MarkdownText text={background} className="max-w-[620px] text-[15px] leading-[1.65] text-on-surface" />
            ) : (
              <p className="text-text-muted italic">{t.npcBackgroundEmpty}</p>
            )}
          </Card>
          <DiaryEntries
            entries={npc.notes ?? []}
            title={t.npcNotes}
            emptyMessage={t.npcNotesEmpty(npc.name)}
            columns="[columns:2_260px]"
          />
        </div>
        <div className="flex min-w-0 max-w-[380px] flex-[1_1_300px] flex-col gap-4">
          <Stats view={view} />
          <section className="card px-4 pt-3 pb-4" aria-labelledby="npc-campaigns" data-card="campaigns">
            <h2 id="npc-campaigns" className="font-display mb-2 text-[17px] text-on-surface">
              {t.npcInCampaigns}
            </h2>
            {stored.data.campaigns.length === 0 ? (
              <p className="text-text-muted italic">{t.npcNoCampaignsYet}</p>
            ) : (
              <ul className="flex flex-col gap-2">
                {stored.data.campaigns.map((c) => {
                  const status = statusOf(c.status);
                  return (
                    <li key={c.campaignId} className="flex items-center gap-2" data-campaign={c.campaignId}>
                      <span className="min-w-0 flex-1 break-words text-[14px] text-on-surface">{c.campaignName}</span>
                      <span
                        aria-label={`${t.npcStatusIn(c.campaignName)}: ${t.npcStatus[status]}`}
                        className={cx('shrink-0 rounded-[var(--radius-pill)] border px-2.5 py-0.5 text-[11.5px]', STATUS_TONE[status])}
                        data-status={status}
                      >
                        {t.npcStatus[status]}
                      </span>
                    </li>
                  );
                })}
              </ul>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}

/** Con qué pelea: nada, su bloque (CA, PG, VD y las primeras acciones) o los
 *  cuatro números de su ficha compilada. */
function Stats({ view }: { view: NpcView }) {
  const t = useTexts();
  const kind = kindOf(view);
  if (kind === 'none') {
    return (
      <section className="card px-4 pt-3 pb-4" data-card="stats">
        <h2 className="font-display mb-1.5 text-[17px] text-on-surface">{t.npcStats}</h2>
        <p className="text-text-muted italic">{t.npcNoStatsNote}</p>
      </section>
    );
  }
  if (kind === 'block') {
    const block = view.block;
    return (
      <section className="card px-4 pt-3 pb-4" data-card="stats">
        <div className="flex flex-wrap items-baseline gap-x-2">
          <h2 className="font-display flex-1 text-[17px] text-on-surface">{t.npcBlockTitle}</h2>
          {view.baseName && <span className="text-[12px] text-text-muted">{t.npcBasedOn(view.baseName)}</span>}
        </div>
        {block && (
          <>
            <dl className="mt-2.5 grid grid-cols-3 gap-2">
              <StatPlaque id="ac" dense label={<Abbr short={t.acShort} full={t.acFull} />} value={block.ac} />
              <StatPlaque id="hp" dense label={<Abbr short={t.hp} full={t.hitPoints} />} value={block.hp} valueClassName="text-crimson" />
              {block.crText !== null && <StatPlaque id="cr" dense label={t.creatureCr} value={block.crText} />}
            </dl>
            {block.actions.length > 0 && (
              <ul className="mt-2.5 flex flex-col gap-1 text-[13px]">
                {block.actions.slice(0, BLOCK_ACTIONS).map((a, i) => (
                  <li key={`${a.name}-${i}`}>
                    <span className="font-medium text-on-surface">{a.name}. </span>
                    <span className="text-text-muted">
                      {[a.attackBonus !== null ? `+${a.attackBonus}` : null, a.damage].filter(Boolean).join(' · ')}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </>
        )}
      </section>
    );
  }
  const sheet = view.sheet;
  return (
    <section className={cx('card px-4 pt-3 pb-4', sheet && 'relative hover:border-gold')} data-card="stats">
      <h2 className="font-display text-[17px] text-on-surface">
        {/* Como en Flutter, la tarjeta entera abre la ficha completa. Una que
            el motor no pudo leer no lleva a ningún lado. */}
        {sheet ? (
          <Link
            href={dmNpcSheetHref(view.npc.id)}
            aria-label={t.npcOpenSheet(view.npc.name)}
            className="after:absolute after:inset-0 after:rounded-[var(--radius-card)] after:content-['']"
          >
            {t.npcSheetTitle}
          </Link>
        ) : (
          t.npcSheetTitle
        )}
      </h2>
      {sheet ? (
        <dl className="mt-3 grid grid-cols-4 gap-1.5">
          <StatPlaque id="ac" dense label={<Abbr short={t.acShort} full={t.acFull} />} value={sheet.armorClass} />
          <StatPlaque id="hp" dense label={<Abbr short={t.hp} full={t.hitPoints} />} value={sheet.maxHp} />
          <StatPlaque id="initiative" dense label={<Abbr short={t.initiativeShort} full={t.initiative} />} value={signed(sheet.initiative)} />
          <StatPlaque id="passive" dense label={<Abbr short={t.dmPassiveShort} full={t.passivePerception} />} value={sheet.passivePerception} />
        </dl>
      ) : (
        <p className="mt-1.5 text-text-muted italic">{t.npcSheetReadFail}</p>
      )}
    </section>
  );
}
