import type { CSSProperties } from 'react';

/**
 * El medallón del personaje: aro del color de su clase y la inicial. Sin
 * retratos todavía (la ficha tampoco los muestra): es lo que Flutter dibuja
 * cuando el personaje no tiene retrato.
 *
 * [size] en píxeles; la inicial escala con él para que el aro y la letra
 * mantengan la proporción de la ficha (64 → 28).
 */
export function Medallion({
  name,
  accent,
  size,
  muted = false,
}: {
  name: string;
  accent: string | null;
  size: number;
  /** Un caído se atenúa y pierde el color, como el retrato de Flutter. */
  muted?: boolean;
}) {
  // `--accent` es el único color que no sale de los tokens: viene del catálogo.
  const style = {
    '--accent': accent ?? 'var(--gold)',
    width: size,
    height: size,
    fontSize: Math.round(size * 0.44),
  } as CSSProperties;
  return (
    <div
      aria-hidden="true"
      style={style}
      className={`font-display flex shrink-0 items-center justify-center rounded-full border-[3px] border-[var(--accent)] bg-plaque text-gold ${
        muted ? 'opacity-55 grayscale' : ''
      }`}
    >
      {Array.from(name)[0]?.toUpperCase()}
    </div>
  );
}
