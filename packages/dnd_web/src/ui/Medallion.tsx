import { useState, type CSSProperties } from 'react';
import { useTexts } from '../i18n/context';
import { thumbnailUrl } from './portrait';
import { PortraitViewer } from './PortraitViewer';

/**
 * El medallón del personaje: aro del color de su clase y, adentro, el retrato
 * si lo tiene o la inicial si no (o si el retrato no carga: uno borrado, uno de
 * otra cuenta). Es el `ClassMedallion` de Flutter.
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
  /** Un caído se atenúa y pierde el color, como el retrato de Flutter. */
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
      className={`font-display flex shrink-0 items-center justify-center overflow-hidden rounded-full border-2 border-[var(--accent)] text-on-surface ${
        muted ? 'opacity-55 grayscale' : ''
      }`}
    >
      {shown ? (
        <img
          src={thumbnailUrl(shown, size)}
          alt=""
          onError={() => setFailed(shown)}
          className="h-full w-full object-cover"
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
      <PortraitViewer src={shown} name={name} open={open} onOpenChange={setOpen} />
    </>
  );
}
