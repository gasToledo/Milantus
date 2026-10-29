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
  return (
    <div
      aria-hidden="true"
      style={style}
      className={`font-display flex shrink-0 items-center justify-center rounded-full border-2 border-[var(--accent)] text-on-surface ${
        muted ? 'opacity-55 grayscale' : ''
      }`}
    >
      {Array.from(name)[0]?.toUpperCase()}
    </div>
  );
}
