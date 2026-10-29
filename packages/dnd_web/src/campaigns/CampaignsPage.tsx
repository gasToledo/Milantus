import { Share2, UserRound } from 'lucide-react';
import { usePlayerCampaignsOf, useRoster, useSheetCatalog } from '../api/queries';
import { useLang, useTexts } from '../i18n/context';
import type { CharacterFields } from '../engine';
import { characterHref, FLUTTER_HOME, Link } from '../router';
import { CampaignBlock } from '../sheet/CampaignTab';
import { ButtonLink } from '../ui/Button';
import { SectionRule } from '../ui/data';
import { AppBusyLabel, AppEmptyState, AppErrorView } from '../ui/status';

/**
 * Las campañas en las que juega la cuenta, de todos sus personajes juntos: la
 * pestaña Campaña de cada ficha, en una sola lista. **Solo lectura**, y solo
 * la vista del jugador: es la misma consulta que la ficha
 * (`GET /api/characters/:id/campaigns`), que el servidor ya poda (sin escenas
 * de música ni capítulos abiertos, batallas sin los PNJ del DM).
 *
 * No hay cuaderno, notas ni lista de miembros porque el jugador no los tiene:
 * son del Modo DM (`docs/arquitectura/modo-dm.md`). Lo más cercano a «miembros»
 * es la mesa («Jugás con…») que ya trae cada campaña. Una mesa con dos
 * personajes de la cuenta aparece dos veces: son dos vínculos.
 */
export function CampaignsPage() {
  const t = useTexts();
  const lang = useLang();
  const roster = useRoster();
  const catalog = useSheetCatalog(lang);
  const characters = roster.data?.map((c) => c.character as unknown as CharacterFields) ?? [];
  const results = usePlayerCampaignsOf(characters.map((c) => c.id));

  const failed = [roster, ...catalog.queries, ...results].filter((q) => q.isError);
  const loading = !roster.data || !catalog.data || results.some((r) => !r.data);

  let body;
  if (failed.length > 0) {
    body = (
      <AppErrorView
        title={t.campaignsPageErrorTitle}
        message={t.errorBody}
        onRetry={() => failed.forEach((q) => q.refetch())}
      />
    );
  } else if (loading) {
    body = <AppBusyLabel label={t.campaignsLoading} />;
  } else {
    const mesas = characters.flatMap((c, i) => (results[i]!.data ?? []).map((pc) => ({ character: c, pc })));
    body =
      mesas.length === 0 ? (
        <AppEmptyState
          kind="empty"
          message={t.campaignsPageEmpty}
          hint={t.campaignsPageEmptyHint}
          actions={
            // Compartir un personaje es una escritura, y vive en Flutter.
            <ButtonLink href={FLUTTER_HOME} icon={Share2} tone="secondary">
              {t.actionShare}
            </ButtonLink>
          }
        />
      ) : (
        <div className="flex flex-col gap-10">
          {mesas.map(({ character, pc }) => (
            <div key={pc.memberId} className="flex flex-col gap-3">
              <Link
                href={characterHref(character.id, 'campana')}
                className="flex w-fit items-center gap-2 text-[13px] text-on-surface-variant hover:text-gold"
              >
                <UserRound size={15} aria-hidden="true" />
                {t.campaignsWith(character.name)}
              </Link>
              <CampaignBlock pc={pc} catalog={catalog.data!} me={character.name} />
            </div>
          ))}
        </div>
      );
  }

  const count = loading ? null : results.reduce((n, r) => n + (r.data?.length ?? 0), 0);
  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="font-display text-[30px] leading-tight text-on-surface">{t.campaignsPageTitle}</h1>
        {count !== null && failed.length === 0 && (
          <p className="mt-1 text-[13px] text-on-surface-variant tabular-nums">{t.campaignsPageCount(count)}</p>
        )}
      </header>
      <SectionRule className="my-0" />
      {body}
    </div>
  );
}
