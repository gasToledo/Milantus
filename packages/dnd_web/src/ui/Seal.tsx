/**
 * El sello de la marca (`diseno-web.md` §2, «La marca»): aro de radio 53 con
 * trazo 5, un rombo en cada punto cardinal y una M de esquinas vivas. Lienzo
 * de 120 × 120, el mismo del código de Flutter. El filete de los rombos es del
 * color del fondo sobre el que se dibuja (`--surface` en el panel) y corta el
 * aro en vez de apoyarse encima.
 */
export function Seal({ size = 38 }: { size?: number }) {
  const diamond = (cx: number, cy: number) =>
    `M${cx} ${cy - 7} L${cx + 7} ${cy} L${cx} ${cy + 7} L${cx - 7} ${cy} Z`;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 120 120"
      aria-hidden="true"
      focusable="false"
      fill="none"
    >
      <circle cx="60" cy="60" r="53" stroke="var(--gold)" strokeWidth="5" />
      {[
        [60, 7],
        [113, 60],
        [60, 113],
        [7, 60],
      ].map(([cx, cy]) => (
        <path
          key={`${cx}-${cy}`}
          d={diamond(cx ?? 0, cy ?? 0)}
          fill="var(--gold)"
          stroke="var(--surface)"
          strokeWidth="3"
        />
      ))}
      <polyline
        points="37,82 37,38 60,62 83,38 83,82"
        stroke="var(--gold)"
        strokeWidth="9"
        strokeLinejoin="miter"
        strokeLinecap="square"
      />
    </svg>
  );
}
