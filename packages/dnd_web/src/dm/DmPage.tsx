import { useCallback, useEffect, useRef, useState } from 'react';
import type { Account } from '../api/client';
import { useCampaignChapters, useChapterScript, useDmCampaigns } from '../api/queries';
import { RosterFooter } from '../dashboard/RosterPanel';
import { useTexts } from '../i18n/context';
import { dmCampaignHref, dmChapterHref, navigate, type DmView } from '../router';
import { Shell } from '../ui/Shell';
import { AppBusyLabel, AppErrorView, Notice } from '../ui/status';
import { defaultCampaign } from './campaigns';
import { DmHeader } from './DmHeader';
import { DmOnboarding } from './DmOnboarding';
import { DmPanel } from './DmPanel';
import { BestiaryPage } from '../bestiary/BestiaryPage';
import { AddFromBestiary } from './combat/AddFromBestiary';
import { ChapterLogView } from './ChapterLogView';
import { ChaptersView } from './ChaptersView';
import { CombatView } from './CombatView';
import { HomebrewCreatureActions } from './HomebrewCreatureActions';
import { creatureEditorExit, HomebrewCreatureView } from './HomebrewCreatureView';
import { HomebrewEditorBack } from './HomebrewEditorBack';
import { entryEditorExit, HomebrewEntryEditorView } from './homebrew/HomebrewEntryEditorView';
import { HomebrewView } from './HomebrewView';
import { MemberSheetView } from './MemberSheetView';
import { MesaView } from './MesaView';
import { MusicPlayer } from './MusicPlayer';
import { ScenarioLibraryView } from './scenarios/ScenarioLibraryView';
import { ChapterScriptView } from './script/ChapterScriptView';
import { ScriptLibraryView } from './script/ScriptLibraryView';
import { CampaignNpcsView } from './npcs/CampaignNpcsView';
import { NpcBlockBack, NpcBlockView } from './npcs/NpcBlockView';
import { NpcPortraitView } from './npcs/NpcPortraitView';
import { NpcDetailView } from './npcs/NpcDetailView';
import { NpcLibraryView } from './npcs/NpcLibraryView';
import { NpcSheetView } from './npcs/NpcSheetView';
import { TutorialGate, type Tutorial } from '../ui/tutorials';
import { SheetCustomizeContext, useSheetCustomizeHost } from '../sheet/sheetCustomize';

/**
 * El Modo DM (`/dm/...`). Acá el DM crea, edita y borra campañas y suma o
 * echa personajes de la mesa, edita capítulos, notas y escenas de música, y
 * arma, juega y termina el combate (`combat/`). Cada pedido pasa por la API de
 * campañas, cuya autorización va adentro del `WHERE`: una campaña ajena y una
 * inexistente responden igual (404), y la pantalla tampoco las distingue.
 */
export function DmPage({ view, account }: { view: DmView; account: Account }) {
  const t = useTexts();
  // Para las fichas de un miembro y de un PNJ, que se dibujan acá adentro.
  const customize = useSheetCustomizeHost();
  const campaigns = useDmCampaigns();
  const list = campaigns.data;

  // `/dm` a secas no es una pantalla: lleva a la primera campaña. Con
  // `replace` para que «atrás» no vuelva a una URL que solo redirige.
  const target = view.kind === 'home' && list ? defaultCampaign(list) : undefined;
  useEffect(() => {
    if (target) navigate(dmCampaignHref(target.id), { replace: true });
  }, [target]);

  // La ficha de un miembro es parte de la Mesa: el panel la marca como tal.
  // La página de un capítulo, «Sin capítulo» y la ruta vieja son de Capítulos.
  const current =
    (view.kind === 'campaign' || view.kind === 'member' || view.kind === 'chapter' || view.kind === 'looseEntries' || view.kind === 'legacyNotebook') && list
      ? (() => {
          const campaign = list.find((c) => c.id === view.id);
          const section = view.kind === 'campaign' ? view.section : view.kind === 'member' ? ('mesa' as const) : ('capitulos' as const);
          return campaign ? { campaign, section } : undefined;
        })()
      : undefined;

  // La música es de la última campaña abierta, no de la URL: abrir el
  // Bestiario o la Biblioteca (que no son de una campaña) no la corta.
  const currentId = current?.campaign.id;
  const [music, setMusic] = useState<{ campaignId: string; offer: boolean } | null>(null);
  useEffect(() => {
    if (currentId) setMusic((old) => old?.campaignId === currentId ? old : { campaignId: currentId, offer: false });
  }, [currentId]);
  const onMusicOffer = useCallback((campaignId: string, show: boolean) => {
    // Un guardado de la campaña anterior puede confirmarse después de salir.
    setMusic((old) => old?.campaignId === campaignId && old.offer !== show ? { campaignId, offer: show } : old);
  }, []);
  // El editor de un bloque registra acá cómo salir (preguntando si hay cambios)
  // para el «volver» del panel, que vive fuera de él.
  const leave = useRef<(() => void) | null>(null);
  const musicCampaign = list?.find((c) => c.id === (currentId ?? music?.campaignId));

  let body;
  // El tutorial de la pantalla que se está viendo, si tiene: uno por sección de
  // la campaña y uno por herramienta de la cuenta (Bestiario, Biblioteca de PNJ
  // y Homebrew), solo en su lista y no en el detalle o el editor.
  let tutorial: Tutorial | null = null;
  if (view.kind === 'bestiary') {
    tutorial = 'bestiary';
    // El Bestiario no depende de las campañas: se abre también sin ninguna y
    // cuando la lista no cargó (el panel lo dice solo).
    const campaign = musicCampaign ?? (list && defaultCampaign(list));
    // Junto a lo de la campaña van las acciones del homebrew (editar, duplicar,
    // borrar o «Editar una copia»), que no dependen de que haya una.
    body = <BestiaryPage entryId={view.entryId} dm profileAction={({ row, profile }, catalog) => (
      <div className="flex flex-wrap items-center justify-end gap-2">
        {campaign ? (
          <AddFromBestiary key={`${campaign.id}:${row.id}`} campaign={campaign} creatureId={row.id} profile={profile} catalog={catalog} onMusicOffer={onMusicOffer} />
        ) : list ? <p className="text-[13px] text-text-muted">{t.dmCreateCampaignFirst}</p> : null}
        <HomebrewCreatureActions key={row.id} id={row.id} profile={profile} />
      </div>
    )} />;
  } else if (view.kind === 'npcs') {
    if (view.npcId === null) tutorial = 'npcLibrary';
    // La Biblioteca tampoco depende de las campañas: sin la lista, los filtros
    // por campaña salen de los vínculos de cada PNJ.
    body = view.npcId === null ? <NpcLibraryView campaigns={list} /> : <NpcDetailView key={view.npcId} npcId={view.npcId} />;
  } else if (view.kind === 'scenarios') {
    body = <ScenarioLibraryView key={view.scenarioId} scenarioId={view.scenarioId} />;
  } else if (view.kind === 'scripts') {
    body = <ScriptLibraryView key={view.scriptId} scriptId={view.scriptId} />;
  } else if (view.kind === 'npcBlock') {
    body = <NpcBlockView key={view.npcId} npcId={view.npcId} leaveRef={leave} />;
  } else if (view.kind === 'npcPortrait') {
    // Sin guardia de salida: cada acción del taller ya se guarda sola.
    body = <NpcPortraitView key={view.npcId} npcId={view.npcId} />;
  } else if (view.kind === 'npcSheet') {
    body = <NpcSheetView key={view.npcId} npcId={view.npcId} tab={view.tab} screen={view.screen} />;
  } else if (view.kind === 'homebrewEditor') {
    // Cada editor es una pantalla propia: la clave deja que la nueva y la que se
    // edita no compartan estado.
    const key = `${view.category}:${view.entryId ?? 'nueva'}`;
    body =
      view.category === 'creatures' ? (
        <HomebrewCreatureView key={key} creatureId={view.entryId} leaveRef={leave} />
      ) : (
        <HomebrewEntryEditorView key={key} category={view.category} entryId={view.entryId} leaveRef={leave} />
      );
  } else if (view.kind === 'homebrew') {
    tutorial = 'homebrew';
    // Lo propio es de la cuenta, no de una campaña.
    body = <HomebrewView category={view.category} entryId={view.entryId} />;
  } else if (campaigns.isError) {
    body = (
      <>
        <DmHeader title={t.dmCampaignsLabel} />
        <AppErrorView title={t.dmCampaignsLoadFail} message={t.errorBody} onRetry={() => campaigns.refetch()} />
      </>
    );
  } else if (!list || target) {
    body = (
      <>
        <DmHeader title={t.dmCampaignsLabel} />
        <AppBusyLabel label={t.dmCampaignsLoading} />
      </>
    );
  } else if (view.kind === 'home') {
    // Sin ninguna campaña: la bienvenida, que lleva a crear la primera.
    body = (
      <>
        <DmHeader title={t.dmCampaignsLabel} />
        <DmOnboarding />
      </>
    );
  } else if (!current) {
    body = <Notice title={t.dmCampaignNotFound} body={t.dmCampaignNotFoundBody} />;
  } else if (view.kind === 'member') {
    body = <MemberSheetView key={view.memberId} campaign={current.campaign} memberId={view.memberId} tab={view.tab} />;
  } else if (view.kind === 'legacyNotebook') {
    body = <NotebookRedirect campaignId={view.id} chapterId={view.chapterId} />;
  } else if (view.kind === 'chapter' && view.tab === null) {
    body = <ChapterRedirect campaignId={view.id} chapterId={view.chapterId} />;
  } else if (view.kind === 'chapter' && view.tab === 'guion') {
    // La clave es del capítulo: qué hitos están desplegados es de cada guion.
    body = <ChapterScriptView key={`${view.id}:${view.chapterId}`} campaign={current.campaign} chapterId={view.chapterId} />;
  } else if (view.kind === 'chapter' || view.kind === 'looseEntries') {
    if (view.kind === 'chapter') tutorial = 'dmNotebook';
    // La clave es de la campaña y no del capítulo: al pasar una nota a otro, la
    // página cambia sin remontarse y el foco la sigue.
    body = <ChapterLogView key={current.campaign.id} campaign={current.campaign} chapterId={view.kind === 'chapter' ? view.chapterId : null} />;
  } else if (current.section === 'combate') {
    tutorial = 'dmCombat';
    body = <CombatView key={current.campaign.id} campaign={current.campaign} onMusicOffer={onMusicOffer} />;
  } else {
    const Section = {
      mesa: MesaView,
      capitulos: ChaptersView,
      pnj: CampaignNpcsView,
    }[current.section];
    tutorial = { mesa: 'dmTable', capitulos: 'dmChapters', pnj: 'dmNpcs' }[current.section] as Tutorial;
    body = <Section key={current.campaign.id} campaign={current.campaign} />;
  }

  return (
    <SheetCustomizeContext.Provider value={customize.value}>
      <Shell
        aside={customize.aside}
        panel={
          view.kind === 'npcBlock' ? (
            <NpcBlockBack npcId={view.npcId} leaveRef={leave} />
          ) : view.kind === 'homebrewEditor' ? (
            <HomebrewEditorBack
              exitHref={view.category === 'creatures' ? creatureEditorExit(view.entryId) : entryEditorExit(view.category, view.entryId)}
              leaveRef={leave}
            />
          ) : (
            <DmPanel campaigns={list} current={current} tool={view.kind === 'npcSheet' || view.kind === 'npcPortrait' || view.kind === 'scenarios' || view.kind === 'scripts' ? 'npcs' : view.kind === 'bestiary' || view.kind === 'npcs' || view.kind === 'homebrew' ? view.kind : undefined} />
          )
        }
        footer={<RosterFooter account={account} dm />}>
        {body}
        {tutorial && <TutorialGate tutorial={tutorial} />}
        {/* Otra campaña es otro reproductor: lo que sonaba se corta. La clave no
            puede ser el id a secas: la sección hermana ya la usa. */}
        {musicCampaign && (
          <MusicPlayer
            key={`music:${musicCampaign.id}`}
            campaignId={musicCampaign.id}
            scenes={musicCampaign.musicScenes ?? []}
            offerCombat={music?.campaignId === musicCampaign.id && music.offer}
            onDismissOffer={() => onMusicOffer(musicCampaign.id, false)}
          />
        )}
      </Shell>
    </SheetCustomizeContext.Provider>
  );
}

/** La ruta de un capítulo sin pestaña: lleva al guion, si tiene, y si no al
 *  Registro (también si no se pudo leer: ahí se dice qué falló). Con `replace`,
 *  como `/dm`. */
function ChapterRedirect({ campaignId, chapterId }: { campaignId: string; chapterId: string }) {
  const t = useTexts();
  const script = useChapterScript(campaignId, chapterId);
  const tab = script.data ? (script.data.script ? 'guion' : 'registro') : script.isError ? 'registro' : null;
  const href = tab && dmChapterHref(campaignId, chapterId, tab);
  useEffect(() => {
    if (href) navigate(href, { replace: true });
  }, [href]);
  return (
    <>
      <DmHeader title={t.dmSectionChapters} />
      <AppBusyLabel label={t.dmChaptersLoading} />
    </>
  );
}

/** La ruta vieja del Cuaderno: lleva al Registro del capítulo pedido; sin él,
 *  al que está en marcha, al primero o, sin capítulos, a la lista. */
function NotebookRedirect({ campaignId, chapterId }: { campaignId: string; chapterId: string | null }) {
  const t = useTexts();
  const chapters = useCampaignChapters(campaignId);
  const list = chapters.data;
  const to = chapterId ?? (list?.find((c) => c.state === 'active') ?? list?.[0])?.id;
  const href = list ? (to ? dmChapterHref(campaignId, to, 'registro') : dmCampaignHref(campaignId, 'capitulos')) : null;
  useEffect(() => {
    if (href) navigate(href, { replace: true });
  }, [href]);
  return (
    <>
      <DmHeader title={t.dmSectionChapters} />
      {chapters.isError ? (
        <AppErrorView title={t.dmChaptersReadFail} message={t.errorBody} onRetry={() => chapters.refetch()} />
      ) : (
        <AppBusyLabel label={t.dmChaptersLoading} />
      )}
    </>
  );
}
