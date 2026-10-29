import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { ChevronDown, ExternalLink, ListMusic, Music, Pause, Play } from 'lucide-react';
import type { MusicScene } from '../api/client';
import { musicSource, type MusicSource } from '../engine';
import { useTexts } from '../i18n/context';
import { cx } from '../ui/cx';
import { Eyebrow } from '../ui/data';
import { Tooltip } from '../ui/primitives';

/** El sitio del reproductor: un nombre de marca, igual en los dos idiomas. */
const SITE = 'YouTube';

/**
 * La música del Modo DM (`dm/music/` de Flutter), **solo para escuchar**: las
 * escenas de la campaña y el reproductor de YouTube embebido. Crear, editar,
 * reordenar, borrar y marcar «ofrecer al iniciar un combate» son escrituras y
 * siguen en Flutter (paso 6). La oferta al empezar un combate tampoco está:
 * acá nadie empieza uno.
 *
 * Vive en la pantalla del Modo DM y no en una sección: cambiar de sección no lo
 * desmonta, así que la música sigue; cambiar de campaña sí (va con `key`), como
 * en Flutter, donde una escena que no está en la campaña nueva se corta.
 *
 * El enlace lo interpreta el motor (`musicSource`): esta pantalla nunca arma la
 * dirección del iframe con lo que pegó el DM.
 */
export function MusicPlayer({ scenes }: { scenes: readonly MusicScene[] }) {
  const t = useTexts();
  const sources = useMemo(() => new Map(scenes.map((s) => [s.id, musicSource(s.url)])), [scenes]);
  const [expanded, setExpanded] = useState(false);
  const [showList, setShowList] = useState(true);
  const [currentId, setCurrentId] = useState<string | null>(null);
  const [playing, setPlaying] = useState(false);
  const [unembeddable, setUnembeddable] = useState(false);
  const frame = useRef<HTMLIFrameElement>(null);

  const current = scenes.find((s) => s.id === currentId) ?? null;
  const source = current ? (sources.get(current.id) ?? null) : null;

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
          <p className="mt-2 text-[13px] text-on-surface-variant" role="status">
            {t.dmMusicUnembeddable(SITE)}{' '}
            <a href={source.pageUrl} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-gold underline">
              {t.dmMusicOpenIn(SITE)}
              <ExternalLink size={13} aria-hidden="true" />
            </a>
          </p>
        )}

        {(showList || !current) && (
          <div className="mt-2.5">
            {current && <Eyebrow className="mb-1.5">{t.dmMusicScenes}</Eyebrow>}
            {scenes.length === 0 ? (
              <p className="text-[13px] text-text-muted">
                {t.dmMusicEmpty} {t.dmMusicEmptyHint}
              </p>
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
                      className={cx('flex items-center gap-1 rounded-[var(--radius-nav)] py-1 pr-1 pl-3', isCurrent ? 'bg-gold-soft' : 'bg-plaque')}
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
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        )}
      </section>

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
