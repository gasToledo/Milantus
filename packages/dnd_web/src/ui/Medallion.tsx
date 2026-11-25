import { useState, type CSSProperties } from 'react';
import { useTexts } from '../i18n/context';
import { splitFrame, thumbnailUrl } from './portrait';
import { PortraitViewer } from './PortraitViewer';

/** Dónde va la imagen dentro del círculo para que el recorte [x, y, s] lo llene.
 *  `s` es el diámetro como fracción del lado más corto, así que ese lado mide
 *  `100 / s` % del medallón y el otro sale de la proporción. Todo en %: el
 *  mismo cálculo vale para cualquier tamaño de medallón. */
function frameStyle([x, y, s]: readonly [number, number, number], ratio: number): CSSProperties {
  const width = ((ratio >= 1 ? ratio : 1) / s) * 100;
  const height = ((ratio >= 1 ? 1 : 1 / ratio) / s) * 100;
  return { width: `${width}%`, height: `${height}%`, left: `${50 - x * width}%`, top: `${50 - y * height}%` };
}

/**
 * El medallón del personaje: aro del color de su clase y, adentro, el retrato
 * si lo tiene o la inicial si no (o si el retrato no carga: uno borrado, uno de
 * otra cuenta).
 *
 * [size] en píxeles; la inicial escala con él para que el aro y la letra
 * mantengan la proporción de la ficha (64 → 28).
 */
export function Medallion({
  name,
  accent,
  size,
  muted = false,
  portrait = null,
  viewable = false,
}: {
  name: string;
  accent: string | null;
  size: number;
  /** Un caído se atenúa y pierde el color. */
  muted?: boolean;
  /** La dirección del retrato original (`portraitUrl`, `memberPortraitUrl`);
   *  el medallón pide la miniatura de su tamaño. */
  portrait?: string | null;
  /** Si tocarlo abre el retrato entero. No en una tarjeta que ya es un
   *  enlace: serían dos destinos en el mismo lugar. */
  viewable?: boolean;
}) {
  const t = useTexts();
  // La dirección que falló, no un booleano: si el retrato cambia, se vuelve a
  // intentar sin arrastrar el error del anterior.
  const [failed, setFailed] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const shown = portrait !== null && failed !== portrait ? portrait : null;
  // El encuadre viaja pegado a la dirección (`splitFrame`). La proporción de la
  // imagen se conoce recién al cargar, y es lo que hace falta para ubicarla.
  const { url: shownUrl, frame } = shown ? splitFrame(shown) : { url: null, frame: null };
  const [ratio, setRatio] = useState<{ src: string; value: number } | null>(null);
  const framed = frame && shownUrl && ratio?.src === shownUrl ? { frame, ratio: ratio.value } : null;

  // `--accent` es el único color que no sale de los tokens: viene del catálogo.
  // El degradado es el de `ClassMedallion` sin retrato: el acento arriba, que
  // se hunde hacia la placa. `color-mix` lo aclara sin inventar un color.
  const style = {
    '--accent': accent ?? 'var(--gold)',
    width: size,
    height: size,
    fontSize: Math.round(size * 0.44),
    background:
      'radial-gradient(circle at 50% 35%, color-mix(in srgb, var(--accent) 40%, transparent), var(--plaque))',
  } as CSSProperties;
  const circle = (
    <div
      aria-hidden="true"
      style={style}
      className={`font-display relative flex shrink-0 items-center justify-center overflow-hidden rounded-full border-2 border-[var(--accent)] text-on-surface ${
        muted ? 'opacity-55 grayscale' : ''
      }`}
    >
      {shown && shownUrl ? (
        <img
          // Con encuadre se pide más resolución: la imagen se agranda para que
          // el círculo recortado llene el medallón.
          src={thumbnailUrl(shownUrl, frame ? size / frame[2] : size)}
          alt=""
          onError={() => setFailed(shown)}
          onLoad={(e) => {
            const { naturalWidth: w, naturalHeight: h } = e.currentTarget;
            if (w > 0 && h > 0) setRatio({ src: shownUrl, value: w / h });
          }}
          className={framed ? 'absolute max-w-none' : 'h-full w-full object-cover'}
          style={framed ? frameStyle(framed.frame, framed.ratio) : undefined}
          data-portrait
        />
      ) : (
        Array.from(name)[0]?.toUpperCase()
      )}
    </div>
  );

  if (!viewable || !shown) return circle;
  return (
    <>
      <button
        type="button"
        aria-label={t.portraitView(name)}
        onClick={() => setOpen(true)}
        className="shrink-0 cursor-zoom-in rounded-full"
      >
        {circle}
      </button>
      <PortraitViewer src={shownUrl ?? shown} name={name} open={open} onOpenChange={setOpen} />
    </>
  );
}
