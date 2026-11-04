import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { ChevronDown, EllipsisVertical, ExternalLink, ListMusic, Music, Pause, Pencil, Play, Plus, Trash2 } from 'lucide-react';
import type { DmCampaign, MusicScene } from '../api/client';
import { queryKeys } from '../api/queries';
import { musicSource, type MusicSource } from '../engine';
import { useTexts } from '../i18n/context';
import { Button, ButtonLink } from '../ui/Button';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { useHoldDrag } from '../ui/holdDrag';
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Tooltip,
} from '../ui/primitives';
import { editCampaign } from './campaigns';
import { MusicSceneDialog } from './MusicSceneDialog';

/** El sitio del reproductor: un nombre de marca, igual en los dos idiomas. */
const SITE = 'YouTube';
/** Lo que tarda en irse solo un aviso del panel. */
const NOTICE_MS = 8000;

type Notice = { kind: 'deleted'; scene: MusicScene; index: number } | { kind: 'error' };

/**
 * La música del Modo DM (`dm/music/` de Flutter): las escenas de la campaña y
 * el reproductor de YouTube embebido. El DM también las crea, edita y borra
 * (6d), y marca cuáles ofrecer al iniciar un combate. Esas escrituras releen la
 * campaña antes del PUT (`editCampaign`) y van en fila: ver `updateScenes`. La
 * oferta al empezar un combate sigue afuera hasta 6g: acá nadie empieza uno.
 *
 * Vive en la pantalla del Modo DM y no en una sección: cambiar de sección no lo
 * desmonta, así que la música sigue; cambiar de campaña sí (va con `key`), como
 * en Flutter, donde una escena que no está en la campaña nueva se corta.
 *
 * El enlace lo interpreta el motor (`musicSource`): esta pantalla nunca arma la
 * dirección del iframe con lo que pegó el DM.
 */
export function MusicPlayer({ campaignId, scenes }: { campaignId: string; scenes: readonly MusicScene[] }) {
  const t = useTexts();
  const client = useQueryClient();
  const sources = useMemo(() => new Map(scenes.map((s) => [s.id, musicSource(s.url)])), [scenes]);
  const [expanded, setExpanded] = useState(false);
  const [showList, setShowList] = useState(true);
  const [currentId, setCurrentId] = useState<string | null>(null);
  const [playing, setPlaying] = useState(false);
  const [unembeddable, setUnembeddable] = useState(false);
  const [editing, setEditing] = useState<MusicScene | 'new' | null>(null);
  const [notice, setNotice] = useState<Notice | null>(null);
  const frame = useRef<HTMLIFrameElement>(null);
  const noticeTimer = useRef<number | undefined>(undefined);
  useEffect(() => () => window.clearTimeout(noticeTimer.current), []);

  const showNotice = (next: Notice) => {
    window.clearTimeout(noticeTimer.current);
    setNotice(next);
    noticeTimer.current = window.setTimeout(() => setNotice(null), NOTICE_MS);
  };

  // Cada cambio se aplica sobre lo último del servidor y no sobre lo que cargó
  // la pantalla, y las escrituras van **en fila**: dos toques seguidos
  // releerían lo mismo y el segundo pisaría al primero. El error se atrapa en
  // la cola para que un fallo no la corte; quien llama sí lo recibe.
  const queue = useRef<Promise<unknown>>(Promise.resolve());
  const updateScenes = (change: (latest: MusicScene[]) => MusicScene[]): Promise<void> => {
    const run = queue.current.then(() =>
      editCampaign(client, campaignId, (latest) => ({ ...latest, musicScenes: change(latest.musicScenes ?? []) })),
    );
    queue.current = run.catch(() => {});
    return run;
  };
  /** Un cambio sin diálogo: si falla, el aviso lo dice y las escenas quedan como estaban. */
  const write = (change: (latest: MusicScene[]) => MusicScene[], onDone?: () => void) =>
    void updateScenes(change).then(onDone, () => {
      showNotice({ kind: 'error' });
      // Si la pantalla se adelantó (mover), vuelve a lo que hay guardado.
      void client.invalidateQueries({ queryKey: queryKeys.dmCampaigns });
    });

  const remove = (scene: MusicScene) => {
    const index = scenes.findIndex((s) => s.id === scene.id);
    write(
      (all) => all.filter((s) => s.id !== scene.id),
      () => showNotice({ kind: 'deleted', scene, index }),
    );
  };
  const undo = (scene: MusicScene, index: number) => {
    window.clearTimeout(noticeTimer.current);
    setNotice(null);
    // En su lugar, recortado al largo de ahora; y nada si ya volvió.
    write((all) => {
      if (all.some((s) => s.id === scene.id)) return all;
      const at = Math.min(index, all.length);
      return [...all.slice(0, at), scene, ...all.slice(at)];
    });
  };

  // Mover una fila: la escena `from` pasa al lugar de `to`, sobre lo último
  // del servidor. `group` aparte del de la Mesa, que está debajo del panel; y
  // solo en vertical, porque la lista tiene scroll propio y recortaría una
  // fila que se va de costado. Sin «Subir» en el menú: se toma la fila.
  // ponytail: con más de cinco escenas una fila solo llega hasta las que se
  // ven, porque el arrastre desplaza la ventana y no la lista; salida: que el
  // hook desplace también su contenedor.
  const ids = useMemo(() => scenes.map((s) => s.id), [scenes]);
  const reorder = useHoldDrag({
    ids,
    group: 'music',
    axis: 'y',
    canDrop: () => true,
    onMove: (from, to) => {
      const moved = (all: MusicScene[]) => {
        const a = all.findIndex((x) => x.id === from);
        const b = all.findIndex((x) => x.id === to);
        if (a < 0 || b < 0) return all;
        const next = [...all];
        next.splice(b, 0, ...next.splice(a, 1));
        return next;
      };
      // La lista cambia al instante: el hook suelta la fila a los 300 ms y
      // esperar al servidor la mostraría volviendo a su lugar.
      client.setQueryData<DmCampaign[]>(queryKeys.dmCampaigns, (old) =>
        old?.map((c) => (c.id === campaignId ? { ...c, musicScenes: moved(c.musicScenes ?? []) } : c)),
      );
      write(moved);
    },
  });

  const current = scenes.find((s) => s.id === currentId) ?? null;
  const source = current ? (sources.get(current.id) ?? null) : null;

  // Si la escena en curso se borró, el video se corta. Se mira la escena y no
  // el nombre: renombrarla no recarga nada.
  useEffect(() => {
    if (currentId !== null && !current) {
      setCurrentId(null);
      setPlaying(false);
    }
  }, [current, currentId]);
  // Con otro enlace el iframe cambia solo (`key`); lo que contaba el anterior
  // ya no vale.
  useEffect(() => {
    setUnembeddable(false);
    setPlaying(false);
  }, [source?.embedUrl]);

  const command = (func: 'playVideo' | 'pauseVideo') => {
    if (source) post(frame.current, source, { event: 'command', func, args: [] });
  };

  // Lo que cuenta el reproductor por `postMessage`: si suena y si el dueño del
  // video no deja verlo fuera de YouTube. Solo se escuchan los mensajes de
  // este iframe.
  useEffect(() => {
    if (!source) return;
    const origin = new URL(source.embedUrl).origin;
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== origin || event.source !== frame.current?.contentWindow || typeof event.data !== 'string') return;
      let data: { event?: string; info?: unknown };
      try {
        data = JSON.parse(event.data) as typeof data;
      } catch {
        return;
      }
      const info = data.info;
      // 101 y 150: el dueño no deja reproducirlo fuera de YouTube. 100: no
      // existe o es privado; para el DM es lo mismo.
      if (data.event === 'onError' && typeof info === 'number' && [100, 101, 150].includes(info)) {
        setUnembeddable(true);
        setPlaying(false);
      } else if (data.event === 'onStateChange' && typeof info === 'number') {
        setPlaying(info === 1);
      } else if (data.event === 'infoDelivery' && typeof info === 'object' && info !== null) {
        const state = (info as { playerState?: unknown }).playerState;
        if (typeof state === 'number') setPlaying(state === 1);
      }
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [source]);

  const play = (scene: MusicScene) => {
    if (!sources.get(scene.id)) return;
    setExpanded(true);
    if (scene.id === currentId) {
      // La misma escena se reanuda en vez de recargarse.
      command('playVideo');
      return;
    }
    setCurrentId(scene.id);
    setUnembeddable(false);
    setPlaying(false);
    // Con algo sonando, la lista se pliega: lo que importa es el video.
    setShowList(false);
  };

  // YouTube exige su reproductor a la vista: minimizado, se pausa.
  const minimize = () => {
    command('pauseVideo');
    setExpanded(false);
  };

  return (
    <div className="fixed right-4 bottom-4 z-40 flex max-w-[calc(100vw-32px)] flex-col items-end" data-music-player>
      <section
        aria-label={t.dmMusic}
        // Minimizado queda montado (el iframe sigue ahí) pero fuera del foco.
        inert={!expanded}
        className={cx('card w-[360px] max-w-full p-3', !expanded && 'sr-only')}
        data-expanded={expanded}
      >
        <div className="flex items-center gap-2">
          <div className="min-w-0 flex-1">
            <Eyebrow>{t.dmMusic}</Eyebrow>
            {current && <p className="truncate text-[14px] font-semibold text-on-surface">{current.name}</p>}
          </div>
          {current && (
            <IconAction label={t.dmMusicScenes} onClick={() => setShowList((v) => !v)} pressed={showList}>
              <ListMusic size={18} aria-hidden="true" />
            </IconAction>
          )}
          <IconAction label={t.dmMusicMinimize} onClick={minimize}>
            <ChevronDown size={18} aria-hidden="true" />
          </IconAction>
        </div>

        {/* El iframe va siempre en el mismo lugar y no se desmonta al
            minimizar: así YouTube conserva su pausa y retoma donde estaba.
            Otra escena es otro iframe (`key`), no el mismo con otro `src`. */}
        {source && (
          <div className="mt-2.5 aspect-video min-h-[200px] w-full overflow-hidden rounded-[var(--radius-nav)] bg-plaque">
            <iframe
              key={source.embedUrl}
              ref={frame}
              title={current?.name ?? t.dmMusic}
              src={`${source.embedUrl}&autoplay=1`}
              // La reproducción la pidió el DM con un clic: el navegador deja
              // arrancar con sonido si el iframe declara `autoplay`.
              allow="autoplay; encrypted-media"
              // Sin «listening», el iframe no le manda sus eventos al padre.
              onLoad={() => post(frame.current, source, { event: 'listening', id: 1, channel: 'widget' })}
              className="block h-full w-full border-0"
            />
          </div>
        )}
        {source && unembeddable && (
          <>
            <p className="mt-2.5 text-[13px] text-crimson" role="status">
              {t.dmMusicUnembeddable(SITE)}
            </p>
            <div className="mt-2.5 flex flex-wrap gap-2">
              <ButtonLink tone="secondary" href={source.pageUrl} newTab>
                {t.dmMusicOpenIn(SITE)}
              </ButtonLink>
              <Button tone="secondary" onClick={() => current && setEditing(current)}>
                {t.dmMusicChangeLink}
              </Button>
            </div>
          </>
        )}

        {(showList || !current) && (
          <div className="mt-2.5">
            {current && <Eyebrow className="mb-1.5">{t.dmMusicScenes}</Eyebrow>}
            {/* Adentro del panel y no un `Toast`: el aviso flotante sale en la
                misma esquina y taparía el reproductor. */}
            {notice && (
              <div
                role={notice.kind === 'error' ? 'alert' : 'status'}
                className="mb-2 flex items-center gap-2 rounded-[var(--radius-nav)] bg-plaque py-2 pr-2 pl-3 text-[13px]"
              >
                <span className={cx('min-w-0 flex-1', notice.kind === 'error' && 'text-crimson')}>
                  {notice.kind === 'error' ? t.dmMusicSaveError : t.dmMusicDeleted(notice.scene.name)}
                </span>
                {notice.kind === 'deleted' && (
                  <button
                    type="button"
                    onClick={() => undo(notice.scene, notice.index)}
                    className="shrink-0 px-2 py-1 font-semibold text-gold"
                  >
                    {t.undo}
                  </button>
                )}
              </div>
            )}
            {scenes.length === 0 ? (
              <p className="text-[13px] text-text-muted">{t.dmMusicEmpty}</p>
            ) : (
              // Con muchas escenas la lista scrollea sola y no empuja la
              // tarjeta fuera de la pantalla de una notebook.
              <ul className="flex max-h-[248px] flex-col gap-1.5 overflow-y-auto" aria-label={t.dmMusicScenes}>
                {scenes.map((scene) => {
                  const s = sources.get(scene.id) ?? null;
                  const isCurrent = scene.id === currentId;
                  const isPlaying = isCurrent && playing;
                  return (
                    <li
                      key={scene.id}
                      data-scene={scene.id}
                      {...reorder.item(scene.id)}
                      className={cx(
                        // Sostenerla no puede seleccionar el texto ni abrir el menú del teléfono.
                        'flex items-center gap-1 rounded-[var(--radius-nav)] py-1 pr-1 pl-3 select-none [-webkit-touch-callout:none]',
                        reorder.dragging === scene.id && reorder.animated ? 'bg-surface outline-1 outline-gold [&_*]:cursor-grabbing'
                          : isCurrent ? 'bg-gold-soft' : 'bg-plaque',
                        reorder.dragging === scene.id && !reorder.animated && 'opacity-40',
                        reorder.over === scene.id && !reorder.animated && 'outline-2 outline-offset-1 outline-gold',
                      )}
                    >
                      <div className="min-w-0 flex-1">
                        <p className={cx('truncate text-[14px] font-semibold', isCurrent ? 'text-gold' : 'text-on-surface')}>{scene.name}</p>
                        <p className="text-[12px] text-text-muted">
                          {[s ? kindLabel(t, s) : t.dmMusicUnsupported, scene.offerOnCombat ? t.dmMusicOnCombatTag : null]
                            .filter(Boolean)
                            .join(' · ')}
                        </p>
                      </div>
                      <IconAction
                        label={`${isPlaying ? t.dmMusicPause : t.dmMusicResume}: ${scene.name}`}
                        tooltip={isPlaying ? t.dmMusicPause : t.dmMusicResume}
                        disabled={!s}
                        onClick={() => (isPlaying ? command('pauseVideo') : play(scene))}
                      >
                        {isPlaying ? <Pause size={18} aria-hidden="true" /> : <Play size={18} aria-hidden="true" />}
                      </IconAction>
                      <DropdownMenu>
                        <Tooltip content={t.dmMusicSceneActions(scene.name)}>
                          <DropdownMenuTrigger asChild>
                            <button
                              type="button"
                              aria-label={t.dmMusicSceneActions(scene.name)}
                              data-action="scene-actions"
                              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:bg-plaque hover:text-on-surface data-[state=open]:bg-gold-soft data-[state=open]:text-gold"
                            >
                              <EllipsisVertical size={18} aria-hidden="true" />
                            </button>
                          </DropdownMenuTrigger>
                        </Tooltip>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onSelect={() => setEditing(scene)}>
                            <Pencil size={15} aria-hidden="true" className="text-text-muted" />
                            {t.commonEdit}
                          </DropdownMenuItem>
                          <DropdownMenuCheckboxItem
                            checked={scene.offerOnCombat === true}
                            onCheckedChange={(on) =>
                              write((all) => all.map((x) => (x.id === scene.id ? { ...x, offerOnCombat: on } : x)))
                            }
                          >
                            {t.dmMusicOfferOnCombat}
                          </DropdownMenuCheckboxItem>
                          {s && (
                            <DropdownMenuItem asChild>
                              <a href={s.pageUrl} target="_blank" rel="noreferrer">
                                <ExternalLink size={15} aria-hidden="true" className="text-text-muted" />
                                {t.dmMusicOpenIn(SITE)}
                              </a>
                            </DropdownMenuItem>
                          )}
                          <DropdownMenuSeparator />
                          <DropdownMenuItem onSelect={() => remove(scene)} className="text-crimson">
                            <Trash2 size={15} aria-hidden="true" />
                            {t.commonDelete}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </li>
                  );
                })}
              </ul>
            )}
            <Button
              tone="secondary"
              icon={Plus}
              data-action="new-scene"
              onClick={() => setEditing('new')}
              className="mt-2 min-h-10 w-full [&_svg]:text-gold"
            >
              {t.dmMusicNewScene}
            </Button>
          </div>
        )}
      </section>

      {editing && (
        <MusicSceneDialog
          current={editing === 'new' ? undefined : editing}
          onSubmit={(scene) =>
            updateScenes((all) =>
              all.some((x) => x.id === scene.id) ? all.map((x) => (x.id === scene.id ? scene : x)) : [...all, scene],
            )
          }
          onClose={() => setEditing(null)}
        />
      )}

      {!expanded && (
        <div className="card flex items-center gap-1 rounded-[var(--radius-pill)] py-1 pr-1 pl-1">
          <button
            type="button"
            onClick={() => setExpanded(true)}
            aria-expanded={false}
            className="inline-flex min-h-9 items-center gap-2 rounded-[var(--radius-pill)] px-3 text-[14px] text-on-surface hover:bg-plaque"
          >
            <Music size={16} aria-hidden="true" className="text-gold" />
            {current ? (
              <span className="max-w-[180px] truncate">
                {current.name}
                <span className="text-text-muted"> · {playing ? SITE : `${SITE} · ${t.dmMusicPausedTag}`}</span>
              </span>
            ) : (
              t.dmMusic
            )}
          </button>
          {current && source && (
            // YouTube no puede sonar escondido: reproducir lo despliega.
            <IconAction label={t.dmMusicResume} onClick={() => play(current)}>
              <Play size={18} aria-hidden="true" />
            </IconAction>
          )}
        </div>
      )}
    </div>
  );
}

function kindLabel(t: ReturnType<typeof useTexts>, s: MusicSource): string {
  return s.kind === 'playlist' ? t.dmMusicKindPlaylist : t.dmMusicKindVideo;
}

/** Una orden al reproductor. El destino es el origen del iframe, nunca `*`: el
 *  mensaje no tiene por qué llegarle a otra página. */
function post(frame: HTMLIFrameElement | null, source: MusicSource, message: object) {
  frame?.contentWindow?.postMessage(JSON.stringify(message), new URL(source.embedUrl).origin);
}

/** Un botón de solo ícono: su nombre accesible y el tooltip para quien ve. */
function IconAction({
  label,
  tooltip,
  onClick,
  disabled = false,
  pressed,
  children,
}: {
  label: string;
  tooltip?: string;
  onClick: () => void;
  disabled?: boolean;
  pressed?: boolean;
  children: ReactNode;
}) {
  return (
    <Tooltip content={tooltip ?? label}>
      <button
        type="button"
        aria-label={label}
        aria-pressed={pressed}
        disabled={disabled}
        onClick={onClick}
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--radius-nav)] text-on-surface-variant hover:bg-plaque hover:text-on-surface disabled:opacity-40 disabled:hover:bg-transparent"
      >
        {children}
      </button>
    </Tooltip>
  );
}
