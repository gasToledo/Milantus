import { useRef, useState, type KeyboardEvent, type PointerEvent } from 'react';
import { useTexts } from '../i18n/context';
import { AppDialog } from '../ui/AppDialog';
import { Medallion } from '../ui/Medallion';
import { withFrame, type PortraitFrame } from '../ui/portrait';

/** El lado mayor del recuadro donde se ve la imagen entera, en px. */
const BOX = 300;
/** Cuánto se corre el círculo con cada flecha, en px del recuadro. */
const STEP = 8;
/** El círculo más chico que se deja: por debajo el medallón sería puro píxel. */
const MIN_SIZE = 0.2;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/**
 * El encuadre del medallón, al estilo de los avatares de Discord: la imagen
 * queda quieta y se mueve y se agranda un círculo encima. Lo que guarda son
 * tres fracciones (`PortraitFrame`), no una imagen recortada, así se puede
 * volver a encuadrar sin perder resolución. El círculo nunca sale de la imagen.
 *
 * Se monta abierto y se desmonta al cerrar: el estado arranca siempre del
 * encuadre guardado, sin limpiarlo a mano.
 */
export function PortraitFrameDialog({
  src,
  name,
  accent,
  initial,
  onSave,
  onClose,
}: {
  /** La imagen entera (`portraitUrl`). */
  src: string;
  name: string;
  accent: string | null;
  /** El encuadre guardado; sin él, el círculo más grande y centrado, que es lo
   *  que el medallón mostraba antes. */
  initial: PortraitFrame | null;
  onSave: (frame: PortraitFrame) => void;
  onClose: () => void;
}) {
  const t = useTexts();
  const [ratio, setRatio] = useState<number | null>(null);
  const [frame, setFrame] = useState<PortraitFrame>(initial ?? [0.5, 0.5, 1]);
  const drag = useRef<{ px: number; py: number; x: number; y: number } | null>(null);

  // El recuadro: la imagen entera dentro de BOX × BOX, sin deformarla.
  const width = ratio === null ? BOX : ratio >= 1 ? BOX : BOX * ratio;
  const height = ratio === null ? BOX : ratio >= 1 ? BOX / ratio : BOX;
  const [x, y, s] = frame;
  const diameter = s * Math.min(width, height);

  /** Centro y tamaño con el círculo adentro de la imagen. */
  const fit = (nx: number, ny: number, ns: number): PortraitFrame => {
    const d = ns * Math.min(width, height);
    const mx = d / 2 / width;
    const my = d / 2 / height;
    return [clamp(nx, mx, 1 - mx), clamp(ny, my, 1 - my), ns];
  };

  const onDown = (e: PointerEvent<HTMLDivElement>) => {
    drag.current = { px: e.clientX, py: e.clientY, x, y };
    e.currentTarget.setPointerCapture(e.pointerId);
  };
  const onMove = (e: PointerEvent<HTMLDivElement>) => {
    const d = drag.current;
    if (d) setFrame(fit(d.x + (e.clientX - d.px) / width, d.y + (e.clientY - d.py) / height, s));
  };
  // El teclado mueve el círculo igual que el puntero: sin mouse también se encuadra.
  const onKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const move = { ArrowLeft: [-STEP, 0], ArrowRight: [STEP, 0], ArrowUp: [0, -STEP], ArrowDown: [0, STEP] }[e.key];
    if (!move) return;
    e.preventDefault();
    setFrame(fit(x + move[0]! / width, y + move[1]! / height, s));
  };

  const radius = diameter / 2;
  return (
    <AppDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={t.portraitFrameTitle}
      actions={[{ label: t.cancel }, { label: t.commonSave, primary: true, onSelect: () => onSave(frame) }]}
    >
      <div className="flex flex-col items-center gap-4">
        <div
          tabIndex={0}
          aria-label={t.portraitFrameArea}
          data-field="portrait-frame-area"
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={() => (drag.current = null)}
          onPointerCancel={() => (drag.current = null)}
          onKeyDown={onKey}
          className="relative cursor-grab touch-none overflow-hidden rounded-[var(--radius-card)] border border-hairline bg-plaque select-none active:cursor-grabbing"
          style={{ width, height }}
        >
          <img
            src={src}
            alt=""
            draggable={false}
            onLoad={(e) => {
              const { naturalWidth: w, naturalHeight: h } = e.currentTarget;
              if (w > 0 && h > 0) setRatio(w / h);
            }}
            className="h-full w-full"
          />
          {/* Lo de afuera del círculo se oscurece con un degradé, no con una
              sombra: el sistema no tiene más sombra que la del hover de la tarjeta. */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-0"
            style={{
              background: `radial-gradient(circle at ${x * width}px ${y * height}px, transparent ${radius - 1}px, color-mix(in srgb, var(--scaffold) 72%, transparent) ${radius}px)`,
            }}
          />
          <div
            aria-hidden="true"
            className="pointer-events-none absolute rounded-full border-2 border-gold"
            style={{ width: diameter, height: diameter, left: x * width - radius, top: y * height - radius }}
          />
        </div>

        <div className="flex w-full items-center gap-3">
          <label htmlFor="portrait-frame-size" className="text-[12.5px] text-on-surface-variant">
            {t.portraitFrameSize}
          </label>
          <input
            id="portrait-frame-size"
            data-field="portrait-frame-size"
            type="range"
            min={MIN_SIZE}
            max={1}
            step={0.01}
            value={s}
            onChange={(e) => setFrame(fit(x, y, Number(e.target.value)))}
            className="min-w-0 flex-1 accent-[var(--gold)]"
          />
          <Medallion name={name} accent={accent} size={56} portrait={withFrame(src, frame)} />
        </div>
      </div>
    </AppDialog>
  );
}
