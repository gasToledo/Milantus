import { useId, type CSSProperties, type ReactNode } from 'react';

// Los adornos de las cuatro placas de la banda táctica, uno por clase. Los
// dibujos están copiados tal cual del lienzo aprobado («Ficha personalizada»):
// no se redibujan ni se simplifican. La animación, las zonas seguras y el color
// (`--class-ink`, que define la placa) viven en `index.css`, bajo `.orn-*`.
// Los ids de `<defs>` llevan el de la instancia: repetidos, una placa dependería
// del filtro o la máscara de otra.

/** Un engranaje de [n] dientes: el contorno es una sola ruta, así se anima como una pieza. */
function gear(cx: number, cy: number, n: number, r1: number, r2: number) {
  const w = (2 * Math.PI) / n;
  const pts: string[] = [];
  for (let k = 0; k < n; k++) {
    for (const [da, r] of [[-0.22, r1], [-0.12, r2], [0.12, r2], [0.22, r1]] as const) {
      const a = k * w + da * w;
      pts.push((cx + r * Math.cos(a)).toFixed(1) + ' ' + (cy + r * Math.sin(a)).toFixed(1));
    }
  }
  return 'M' + pts.join('L') + 'Z';
}
const GEAR_BIG = gear(34, 34, 10, 22, 28);
const GEAR_SMALL = gear(70, 26, 8, 10, 14);
const GEAR_CORNER = gear(26, 26, 8, 11, 15);

export type OrnamentCorner = 'tl' | 'br';

const ART: Record<string, { tl: (uid: string, big: string) => ReactNode; br: (uid: string) => ReactNode }> = {
  druid: {
    tl: (_uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 84 52" fill="none" stroke="var(--class-ink)" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true">
        <path className="orn-vine" pathLength="100" d="M2 40C14 22 26 46 40 26S66 8 82 14" />
        <path className="orn-leaf" fill="var(--class-ink)" stroke="none" d="M14 30q-8-4-9-12q9 1 9 12z" />
        <path className="orn-leaf orn-l2" fill="var(--class-ink)" stroke="none" d="M38 28q-1-9 6-14q4 9-6 14z" />
        <path className="orn-leaf orn-l3" fill="var(--class-ink)" stroke="none" d="M60 14q5-8 14-7q-3 9-14 7z" />
      </svg>
    ),
    br: () => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMinYMin meet" style={{ transform: 'rotate(180deg)' }} viewBox="0 0 84 52" fill="none" stroke="var(--class-ink)" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true">
        <path className="orn-vine" pathLength="100" d="M2 40C14 22 26 46 40 26S66 8 82 14" />
        <path className="orn-leaf orn-l2" fill="var(--class-ink)" stroke="none" d="M14 30q-8-4-9-12q9 1 9 12z" />
        <path className="orn-leaf orn-l3" fill="var(--class-ink)" stroke="none" d="M38 28q-1-9 6-14q4 9-6 14z" />
        <path className="orn-leaf" fill="var(--class-ink)" stroke="none" d="M60 14q5-8 14-7q-3 9-14 7z" />
      </svg>
    ),
  },
  artificer: {
    tl: (_uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="22 22 74 74" fill="none" stroke="var(--class-ink)" strokeWidth="1.5" strokeLinejoin="round" aria-hidden="true">
        <path className="orn-gear" d={GEAR_BIG} />
        <circle cx="34" cy="34" r="6" />
        <path className="orn-gear orn-rev" d={GEAR_SMALL} />
        <circle cx="70" cy="26" r="3.5" />
      </svg>
    ),
    br: () => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 26 34" fill="none" stroke="var(--class-ink)" strokeWidth="1.5" strokeLinejoin="round" aria-hidden="true">
        <path className="orn-gear orn-rev" d={GEAR_CORNER} />
        <circle cx="26" cy="26" r="4" />
      </svg>
    ),
  },
  bard: {
    tl: (_uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 84 52" fill="none" stroke="var(--class-ink)" strokeWidth="1.2" strokeLinecap="round" aria-hidden="true">
        <path className="orn-vine" pathLength="100" d="M2 26C26 18 52 34 82 22" />
        <path className="orn-vine" pathLength="100" d="M2 31C26 23 52 39 82 27" />
        <path className="orn-vine" pathLength="100" d="M2 36C26 28 52 44 82 32" />
        <path className="orn-vine" pathLength="100" d="M2 41C26 33 52 49 82 37" />
        <g className="orn-note" fill="var(--class-ink)" stroke="none">
          <ellipse cx="22" cy="33" rx="4.2" ry="3" transform="rotate(-20 22 33)" />
        </g>
        <g className="orn-note orn-n2" fill="var(--class-ink)" stroke="var(--class-ink)" strokeWidth="1.4">
          <path d="M25.5 32V12M45.5 31V8M25.5 12L45.5 8" strokeWidth="1.6" />
          <ellipse cx="42" cy="32" rx="4.2" ry="3" stroke="none" transform="rotate(-20 42 32)" />
        </g>
        <g className="orn-note orn-n3" fill="var(--class-ink)" stroke="none">
          <ellipse cx="64" cy="26" rx="4.2" ry="3" transform="rotate(-20 64 26)" />
          <path d="M67.5 25V9" stroke="var(--class-ink)" strokeWidth="1.6" />
        </g>
      </svg>
    ),
    br: () => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 72 38" fill="none" stroke="var(--class-ink)" strokeWidth="1.2" strokeLinecap="round" aria-hidden="true">
        <path className="orn-vine" pathLength="100" d="M70 20C48 28 24 12 2 22" />
        <path className="orn-vine" pathLength="100" d="M70 25C48 33 24 17 2 27" />
        <path className="orn-vine" pathLength="100" d="M70 30C48 38 24 22 2 32" />
        <g className="orn-note orn-n2" fill="var(--class-ink)" stroke="none">
          <ellipse cx="50" cy="28" rx="4" ry="2.9" transform="rotate(-20 50 28)" />
          <path d="M53.4 27V12" stroke="var(--class-ink)" strokeWidth="1.6" />
        </g>
        <g className="orn-note orn-n3" fill="var(--class-ink)" stroke="none">
          <ellipse cx="30" cy="23" rx="4" ry="2.9" transform="rotate(-20 30 23)" />
          <path d="M33.4 22V8" stroke="var(--class-ink)" strokeWidth="1.6" />
        </g>
      </svg>
    ),
  },
  wizard: {
    // Constelación. Como en el Brujo: la línea se traza al rojo blanco y se enfría, cada estrella llega encendida y se apaga a brasa.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeWidth="1" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-vine" pathLength="100" d="M8 10L24 30L44 18L62 36L74 14" />
        </g>
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '1.4s, 0.9s', animationDelay: '0s, 1.3s', animationTimingFunction: 'ease-out, ease-out' }} d="M8 10L24 30L44 18L62 36L74 14" />
        </g>
        <g fill="var(--class-ink)" stroke="none" filter={`url(#${uid}-pglow)`}>
          <g className="orn-note">
            <circle cx="8" cy="10" r="2.2" />
            <circle className="orn-flashfill" style={{ animationDelay: '1.0s' }} cx="8" cy="10" r="2.2" />
          </g>
          <g className="orn-note orn-n2">
            <circle cx="24" cy="30" r="2.2" />
            <circle className="orn-flashfill" style={{ animationDelay: '1.25s' }} cx="24" cy="30" r="2.2" />
          </g>
          <g className="orn-note orn-n3">
            <path d="M44 9L46 16L53 18L46 20L44 27L42 20L35 18L42 16Z" />
            <path className="orn-flashfill" style={{ animationDelay: '1.5s' }} d="M44 9L46 16L53 18L46 20L44 27L42 20L35 18L42 16Z" />
          </g>
          <g className="orn-note orn-n2">
            <circle cx="62" cy="36" r="2.2" />
            <circle className="orn-flashfill" style={{ animationDelay: '1.25s' }} cx="62" cy="36" r="2.2" />
          </g>
          <g className="orn-note orn-n3">
            <circle cx="74" cy="14" r="2.2" />
            <circle className="orn-flashfill" style={{ animationDelay: '1.5s' }} cx="74" cy="14" r="2.2" />
          </g>
        </g>
      </svg>
    ),
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 60 40" fill="none" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g fill="var(--class-ink)" filter={`url(#${uid}-pglow)`}>
          <g className="orn-note orn-n2">
            <path d="M48 8A14 14 0 1 0 48 36A20 20 0 0 1 48 8Z" />
            <path className="orn-flashfill" style={{ animationDelay: '1.25s' }} d="M48 8A14 14 0 1 0 48 36A20 20 0 0 1 48 8Z" />
          </g>
          <g className="orn-note orn-n3">
            <path d="M16 8L17.4 13.6L23 15L17.4 16.4L16 22L14.6 16.4L9 15L14.6 13.6Z" />
            <path className="orn-flashfill" style={{ animationDelay: '1.5s' }} d="M16 8L17.4 13.6L23 15L17.4 16.4L16 22L14.6 16.4L9 15L14.6 13.6Z" />
          </g>
          <g className="orn-note orn-n3">
            <circle cx="26" cy="30" r="1.6" />
            <circle className="orn-flashfill" style={{ animationDelay: '1.5s' }} cx="26" cy="30" r="1.6" />
          </g>
        </g>
      </svg>
    ),
  },
  paladin: {
    // Flor de lis de línea rodeada de destellos. El brillo es un desenfoque dentro del SVG: no sale de la tarjeta ni separa superficies.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g transform="translate(3 2) scale(2)" strokeWidth="0.6">
          <path className="orn-vine" pathLength="100" d="M10 0C12.5 3 13.5 6.5 12 10C11.3 11.7 10.6 13 10 14.5C9.4 13 8.7 11.7 8 10C6.5 6.5 7.5 3 10 0Z" />
          <path className="orn-vine" pathLength="100" d="M10 2.5V12.5" strokeWidth="0.4" />
          <path className="orn-vine" pathLength="100" d="M8.6 14.5C8.2 11 6 8 3.2 7.6C1 7.3 0 9.6 1.4 11C2.5 12 4 11.2 3.6 10" />
          <path className="orn-vine" pathLength="100" d="M11.4 14.5C11.8 11 14 8 16.8 7.6C19 7.3 20 9.6 18.6 11C17.5 12 16 11.2 16.4 10" />
          <path className="orn-vine" pathLength="100" d="M5.5 15.3H14.5M5.5 16.7H14.5" />
          <path className="orn-vine" pathLength="100" d="M8.6 17.2C8.2 18.6 9 20 10 20.4C11 20 11.8 18.6 11.4 17.2" />
        </g>
        <path className="orn-spark" style={{ animationDelay: '0.9s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M54 15.5Q54 20 58.5 20Q54 20 54 24.5Q54 20 49.5 20Q54 20 54 15.5Z" />
        <path className="orn-spark" style={{ animationDelay: '1.1s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.8" d="M60.4 6.4L63.6 9.6M63.6 6.4L60.4 9.6" />
        <circle className="orn-spark" style={{ animationDelay: '1.0s' }} filter={`url(#${uid}-pglow)`} cx="49" cy="7" r="1.2" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '1.25s' }} filter={`url(#${uid}-pglow)`} cx="50" cy="33" r="0.9" fill="var(--class-ink)" stroke="none" />
        <path className="orn-spark" style={{ animationDelay: '1.15s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M16 48.5Q16 52 19.5 52Q16 52 16 55.5Q16 52 12.5 52Q16 52 16 48.5Z" />
        <path className="orn-spark" style={{ animationDelay: '1.35s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.8" d="M4.7 45.7L7.3 48.3M7.3 45.7L4.7 48.3" />
        <circle className="orn-spark" style={{ animationDelay: '1.3s' }} filter={`url(#${uid}-pglow)`} cx="28" cy="50" r="0.8" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
    // Remate de esquina: dos y tres líneas por borde, las de afuera unidas por un cuarto de arco con un destello.
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeWidth="1.1" strokeLinecap="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <path className="orn-trim" pathLength="100" d="M2 34H34A8 8 0 0 0 42 26V2" />
        <path className="orn-trim" pathLength="100" strokeWidth="0.9" d="M12 31H32M39 24V8" />
        <path className="orn-trim" pathLength="100" strokeWidth="0.7" d="M22 28H30M36 21V14" />
        <path className="orn-spark" style={{ animationDelay: '1.1s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M39.7 26.7Q39.7 31.7 44.7 31.7Q39.7 31.7 39.7 36.7Q39.7 31.7 34.7 31.7Q39.7 31.7 39.7 26.7Z" />
      </svg>
    ),
  },
  fighter: {
    // Una espada atravesada por detrás del escudo: asoman la empuñadura a la izquierda y la hoja a la derecha.
    // La espada se dibuja primero y el escudo, relleno con el fondo, la tapa; el destello también pasa por detrás.
    // Orden: se planta el escudo, la espada entra desde el borde izquierdo (el SVG recorta, nada sale de la tarjeta) y se clava; al final, el brillo.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g className="orn-thrust">
          <path strokeWidth="1.1" fill="var(--plaque)" d="M12.5 24.2H68L75 26L68 27.8H12.5Z" />
          <path strokeWidth="0.5" d="M15 26H64" />
          <path strokeWidth="2" d="M11 19.5V32.5" />
          <path strokeWidth="2.4" d="M5.5 26H9.5" />
          <circle cx="4" cy="26" r="1.9" fill="var(--class-ink)" stroke="none" />
        </g>
        <path className="orn-glint" pathLength="100" strokeWidth="2" d="M13 26H75" />
        <g className="orn-plant">
          <path strokeWidth="1.3" fill="var(--plaque)" d="M22 8H42Q44 8 44 10V27C44 37 38 44 32 48C26 44 20 37 20 27V10Q20 8 22 8Z" />
          <path strokeWidth="0.6" d="M24.5 11H39.5Q41 11 41 12.5V27C41 35 36.5 40.5 32 44.5C27.5 40.5 23 35 23 27V12.5Q23 11 24.5 11Z" />
          <path strokeWidth="0.6" d="M32 11V44.5" />
        </g>
        <path className="orn-spark" style={{ animationDelay: '1.6s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M75 14.6Q75 18 78.4 18Q75 18 75 21.4Q75 18 71.6 18Q75 18 75 14.6Z" />
        <circle className="orn-spark" style={{ animationDelay: '1.7s' }} filter={`url(#${uid}-pglow)`} cx="70" cy="32" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '1.75s' }} filter={`url(#${uid}-pglow)`} cx="79" cy="30" r="0.7" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
    // Dos lanzas que siguen los bordes, con las puntas hacia afuera, y una rodela en la esquina donde se juntan.
    br: () => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <path className="orn-trim" pathLength="100" strokeWidth="1.2" d="M40 33H9M43 30V9" />
        <path className="orn-trim" pathLength="100" strokeWidth="0.6" d="M36 36H14M46 26V14" />
        <path className="orn-spark" style={{ animationDelay: '0.9s' }} strokeWidth="1" fill="var(--class-ink)" fillOpacity="0.3" d="M9 33Q5 30.4 1 33Q5 35.6 9 33Z" />
        <path className="orn-spark" style={{ animationDelay: '0.95s' }} strokeWidth="1" fill="var(--class-ink)" fillOpacity="0.3" d="M43 9Q40.4 5 43 1Q45.6 5 43 9Z" />
        <path className="orn-trim" pathLength="100" strokeWidth="1" d="M10.5 31.2V34.8M41.2 10.5H44.8" />
        <g className="orn-spark" style={{ animationDelay: '0.2s' }}>
          <circle cx="40" cy="30" r="6.5" fill="var(--plaque)" strokeWidth="1.2" />
          <circle cx="40" cy="30" r="4.2" strokeWidth="0.6" />
          <circle cx="40" cy="30" r="1.3" fill="var(--class-ink)" stroke="none" />
        </g>
      </svg>
    ),
  },
  cleric: {
    // Símbolo sagrado colgado del borde: una cadena de cuentas y un medallón con un sol. Entra balanceándose como un péndulo,
    // se aquieta y el halo se enciende una vez (Canalizar Divinidad); después, los destellos.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g className="orn-swing-pend">
          <circle cx="20" cy="1.0" r="1.05" fill="var(--class-ink)" stroke="none" />
          <circle cx="20" cy="4.6" r="1.05" fill="var(--class-ink)" stroke="none" />
          <circle cx="20" cy="8.2" r="1.05" fill="var(--class-ink)" stroke="none" />
          <circle cx="20" cy="11.8" r="1.05" fill="var(--class-ink)" stroke="none" />
          <circle cx="20" cy="15.4" r="1.05" fill="var(--class-ink)" stroke="none" />
          <circle cx="20" cy="19.0" r="1.05" fill="var(--class-ink)" stroke="none" />
          <circle cx="20" cy="22" r="1.4" strokeWidth="0.7" />
          <circle className="orn-halo" cx="20" cy="33" r="12.5" strokeWidth="0.6" filter={`url(#${uid}-pglow)`} />
          <circle cx="20" cy="33" r="9.5" fill="var(--plaque)" strokeWidth="1.2" />
          <circle cx="20" cy="33" r="7.2" strokeWidth="0.5" />
          <circle cx="20" cy="33" r="2.4" fill="var(--class-ink)" stroke="none" />
          <path strokeWidth="0.8" d="M20.00 29.40L20.00 26.70M22.55 30.45L23.54 29.46M23.60 33.00L26.30 33.00M22.55 35.55L23.54 36.54M20.00 36.60L20.00 39.30M17.45 35.55L16.46 36.54M16.40 33.00L13.70 33.00M17.45 30.45L16.46 29.46" />
        </g>
        <path className="orn-spark" style={{ animationDelay: '1.5s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M40 18.4Q40 22 43.6 22Q40 22 40 25.6Q40 22 36.4 22Q40 22 40 18.4Z" />
        <path className="orn-spark" style={{ animationDelay: '1.6s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M36 43.4Q36 46 38.6 46Q36 46 36 48.6Q36 46 33.4 46Q36 46 36 43.4Z" />
        <circle className="orn-spark" style={{ animationDelay: '1.65s' }} filter={`url(#${uid}-pglow)`} cx="44" cy="33" r="0.9" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '1.7s' }} filter={`url(#${uid}-pglow)`} cx="32" cy="14" r="0.7" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
    // Rosario por los dos bordes, con un sol pequeño donde se juntan.
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <path className="orn-trim" pathLength="100" strokeWidth="0.5" d="M35 32H4M42 25V2" />
        <circle className="orn-spark" style={{ animationDelay: '0.50s' }} cx="31" cy="32" r="1.1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.57s' }} cx="27" cy="32" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.64s' }} cx="23" cy="32" r="1.1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.71s' }} cx="19" cy="32" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.78s' }} cx="15" cy="32" r="1.1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.85s' }} cx="11" cy="32" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.92s' }} cx="7" cy="32" r="1.1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.50s' }} cx="42" cy="23" r="1.1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.57s' }} cx="42" cy="19" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.64s' }} cx="42" cy="15" r="1.1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.71s' }} cx="42" cy="11" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '0.78s' }} cx="42" cy="7" r="1.1" fill="var(--class-ink)" stroke="none" />
        <g className="orn-plant">
          <circle cx="40" cy="30" r="4.6" fill="var(--plaque)" strokeWidth="1" />
          <circle filter={`url(#${uid}-pglow)`} cx="40" cy="30" r="1.6" fill="var(--class-ink)" stroke="none" />
          <path strokeWidth="0.7" d="M40.00 27.60L40.00 26.00M41.70 28.30L42.40 27.60M42.40 30.00L44.00 30.00M41.70 31.70L42.40 32.40M40.00 32.40L40.00 34.00M38.30 31.70L37.60 32.40M37.60 30.00L36.00 30.00M38.30 28.30L37.60 27.60" />
        </g>
        <path className="orn-mend" style={{ animationDelay: '1.0s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.1" d="M28.6 23H33.4M31 20.6V25.4" />
        <path className="orn-mend" style={{ animationDelay: '1.2s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.9" d="M21.2 17H24.8M23 15.2V18.8" />
        <path className="orn-mend" style={{ animationDelay: '1.4s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.8" d="M32.6 12H35.4M34 10.6V13.4" />
        <circle className="orn-mend" style={{ animationDelay: '1.1s' }} filter={`url(#${uid}-pglow)`} cx="27" cy="25.5" r="0.7" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-mend" style={{ animationDelay: '1.3s' }} filter={`url(#${uid}-pglow)`} cx="36" cy="20" r="0.6" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
  },
  barbarian: {
    // Furia: un golpe en la esquina. Salta un fogonazo con una onda, la tarjeta se agrieta desde ahí con las grietas ardiendo por dentro
    // (cada tramo arranca cuando llega el anterior, a velocidad pareja) y al final saltan brasas desde el impacto.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <circle className="orn-shock" cx="5" cy="5" r="9" strokeWidth="0.8" />
        <circle className="orn-core" filter={`url(#${uid}-pglow)`} cx="5" cy="5" r="3.6" stroke="none" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.075s', animationDelay: '0.150s' }} filter={`url(#${uid}-pglow)`} strokeWidth="2.60" d="M5 5L15 8" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.225s' }} filter={`url(#${uid}-pglow)`} strokeWidth="2.24" d="M15 8L23 7" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.074s', animationDelay: '0.282s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.96" d="M23 7L32 12" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.065s', animationDelay: '0.356s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.60" d="M32 12L41 11" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.080s', animationDelay: '0.420s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.28" d="M41 11L51 16" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.051s', animationDelay: '0.500s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.90" d="M51 16L58 15" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.075s', animationDelay: '0.150s' }} filter={`url(#${uid}-pglow)`} strokeWidth="2.60" d="M5 5L8 15" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.065s', animationDelay: '0.225s' }} filter={`url(#${uid}-pglow)`} strokeWidth="2.16" d="M8 15L7 24" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.071s', animationDelay: '0.289s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.78" d="M7 24L13 32" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.065s', animationDelay: '0.361s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.37" d="M13 32L12 41" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.425s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.99" d="M12 41L16 48" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.096s', animationDelay: '0.150s' }} filter={`url(#${uid}-pglow)`} strokeWidth="2.20" d="M5 5L14 15" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.246s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.64" d="M14 15L21 19" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.076s', animationDelay: '0.304s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.31" d="M21 19L28 27" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.054s', animationDelay: '0.380s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.87" d="M28 27L35 30" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.043s', animationDelay: '0.282s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.10" d="M23 7L27 2.5" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.043s', animationDelay: '0.325s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.69" d="M27 2.5L33 1.5" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.054s', animationDelay: '0.356s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.20" d="M32 12L35 19" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.048s', animationDelay: '0.410s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.72" d="M35 19L41 22" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.054s', animationDelay: '0.289s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.00" d="M7 24L2.5 30" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.304s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.10" d="M21 19L22 27" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.048s', animationDelay: '0.361s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.65" d="M22 27L19 33" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.061s', animationDelay: '0.380s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.90" d="M28 27L36 24" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.075s', animationDelay: '0.150s' }} strokeWidth="0.91" d="M5 5L15 8" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.225s' }} strokeWidth="0.78" d="M15 8L23 7" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.074s', animationDelay: '0.282s' }} strokeWidth="0.68" d="M23 7L32 12" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.065s', animationDelay: '0.356s' }} strokeWidth="0.56" d="M32 12L41 11" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.080s', animationDelay: '0.420s' }} strokeWidth="0.45" d="M41 11L51 16" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.051s', animationDelay: '0.500s' }} strokeWidth="0.31" d="M51 16L58 15" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.075s', animationDelay: '0.150s' }} strokeWidth="0.91" d="M5 5L8 15" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.065s', animationDelay: '0.225s' }} strokeWidth="0.76" d="M8 15L7 24" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.071s', animationDelay: '0.289s' }} strokeWidth="0.62" d="M7 24L13 32" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.065s', animationDelay: '0.361s' }} strokeWidth="0.48" d="M13 32L12 41" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.425s' }} strokeWidth="0.35" d="M12 41L16 48" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.096s', animationDelay: '0.150s' }} strokeWidth="0.77" d="M5 5L14 15" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.246s' }} strokeWidth="0.57" d="M14 15L21 19" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.076s', animationDelay: '0.304s' }} strokeWidth="0.46" d="M21 19L28 27" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.054s', animationDelay: '0.380s' }} strokeWidth="0.30" d="M28 27L35 30" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.043s', animationDelay: '0.282s' }} strokeWidth="0.39" d="M23 7L27 2.5" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.043s', animationDelay: '0.325s' }} strokeWidth="0.24" d="M27 2.5L33 1.5" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.054s', animationDelay: '0.356s' }} strokeWidth="0.42" d="M32 12L35 19" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.048s', animationDelay: '0.410s' }} strokeWidth="0.25" d="M35 19L41 22" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.054s', animationDelay: '0.289s' }} strokeWidth="0.35" d="M7 24L2.5 30" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.304s' }} strokeWidth="0.39" d="M21 19L22 27" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.048s', animationDelay: '0.361s' }} strokeWidth="0.23" d="M22 27L19 33" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.061s', animationDelay: '0.380s' }} strokeWidth="0.32" d="M28 27L36 24" />
        <circle className="orn-ember" style={{ '--dx': '-19px', '--dy': '-29px', animationDelay: '0.45s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="24" cy="34" r="0.9" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '-33px', '--dy': '-31px', animationDelay: '0.49s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="38" cy="36" r="0.7" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '-39px', '--dy': '-22px', animationDelay: '0.53s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="44" cy="27" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '-11px', '--dy': '-39px', animationDelay: '0.57s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="16" cy="44" r="0.6" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '-25px', '--dy': '-37px', animationDelay: '0.61s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="30" cy="42" r="0.6" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
    // Una grieta más chica abajo, del mismo golpe, que llega un poco después.
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <circle className="orn-shock" style={{ animationDelay: '0.5s' }} cx="45" cy="35" r="6" strokeWidth="0.8" />
        <circle className="orn-core" style={{ animationDelay: '0.5s' }} filter={`url(#${uid}-pglow)`} cx="45" cy="35" r="2.4" stroke="none" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.059s', animationDelay: '0.550s' }} filter={`url(#${uid}-pglow)`} strokeWidth="2.00" d="M45 35L37 33" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.051s', animationDelay: '0.609s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.59" d="M37 33L30 34" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.659s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.25" d="M30 34L23 30" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.051s', animationDelay: '0.717s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.85" d="M23 30L16 31" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.059s', animationDelay: '0.550s' }} filter={`url(#${uid}-pglow)`} strokeWidth="2.00" d="M45 35L43 27" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.609s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.49" d="M43 27L44 19" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.666s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.00" d="M44 19L40 12" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.071s', animationDelay: '0.550s' }} filter={`url(#${uid}-pglow)`} strokeWidth="1.50" d="M45 35L38 28" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.046s', animationDelay: '0.621s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.82" d="M38 28L34 23" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.039s', animationDelay: '0.659s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.80" d="M30 34L27 38.5" />
        <path className="orn-crk" pathLength="100" style={{ animationDuration: '0.044s', animationDelay: '0.666s' }} filter={`url(#${uid}-pglow)`} strokeWidth="0.80" d="M44 19L47.5 14" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.059s', animationDelay: '0.550s' }} strokeWidth="0.70" d="M45 35L37 33" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.051s', animationDelay: '0.609s' }} strokeWidth="0.56" d="M37 33L30 34" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.659s' }} strokeWidth="0.44" d="M30 34L23 30" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.051s', animationDelay: '0.717s' }} strokeWidth="0.30" d="M23 30L16 31" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.059s', animationDelay: '0.550s' }} strokeWidth="0.70" d="M45 35L43 27" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.609s' }} strokeWidth="0.52" d="M43 27L44 19" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.058s', animationDelay: '0.666s' }} strokeWidth="0.35" d="M44 19L40 12" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.071s', animationDelay: '0.550s' }} strokeWidth="0.52" d="M45 35L38 28" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.046s', animationDelay: '0.621s' }} strokeWidth="0.29" d="M38 28L34 23" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.039s', animationDelay: '0.659s' }} strokeWidth="0.28" d="M30 34L27 38.5" />
        <path className="orn-crk orn-hot" pathLength="100" style={{ animationDuration: '0.044s', animationDelay: '0.666s' }} strokeWidth="0.28" d="M44 19L47.5 14" />
        <circle className="orn-ember" style={{ '--dx': '17px', '--dy': '9px', animationDelay: '0.67s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="28" cy="26" r="0.7" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '9px', '--dy': '15px', animationDelay: '0.71s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="36" cy="20" r="0.6" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '23px', '--dy': '-1px', animationDelay: '0.75s' } as CSSProperties} filter={`url(#${uid}-pglow)`} cx="22" cy="36" r="0.5" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
  },
  sorcerer: {
    // Sello de metamagia, de adentro hacia afuera (la magia sale de la sangre): se enciende la gema, se trazan los triángulos,
    // los anillos se abren con un rebote corto y al final aparecen las runas y las chispas en los cortes.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-seal" pathLength="100" style={{ animationDuration: '0.45s', animationDelay: '0.3s' }} strokeWidth="0.9" d="M29 17Q34.2 26 39.39 35Q29 35 18.61 35Q23.8 26 29 17" />
          <path className="orn-seal" pathLength="100" style={{ animationDuration: '0.45s', animationDelay: '0.38s' }} strokeWidth="0.9" d="M39.39 23Q36.79 33.5 29 41Q21.21 33.5 18.61 23Q29 20 39.39 23" />
        </g>
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.45s, 0.9s', animationDelay: '0.3s, 0.9s' }} strokeWidth="0.9" d="M29 17Q34.2 26 39.39 35Q29 35 18.61 35Q23.8 26 29 17" />
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.45s, 0.9s', animationDelay: '0.38s, 0.98s' }} strokeWidth="0.9" d="M39.39 23Q36.79 33.5 29 41Q21.21 33.5 18.61 23Q29 20 39.39 23" />
        </g>
        <g className="orn-bloom" style={{ animationDelay: '0.55s' }}>
          <g filter={`url(#${uid}-pglow)`}>
            <circle cx="29" cy="29" r="16" strokeWidth="0.8" strokeDasharray="1.2 2.4" />
          </g>
          <g className="orn-flash" filter={`url(#${uid}-pglow)`} style={{ animationDelay: '0.75s' }}>
            <circle cx="29" cy="29" r="16" strokeWidth="0.8" strokeDasharray="1.2 2.4" />
          </g>
        </g>
        <g className="orn-bloom" style={{ animationDelay: '0.7s' }}>
          <g filter={`url(#${uid}-pglow)`}>
            <path strokeWidth="1.2" d="M46.26 12.33A24 24 0 0 1 40.27 50.19" />
            <path strokeWidth="1.2" d="M33.99 52.48A24 24 0 0 1 5.36 33.17" />
            <path strokeWidth="1.2" d="M5.13 26.49A24 24 0 0 1 41 8.22" />
          </g>
          <g className="orn-flash" filter={`url(#${uid}-pglow)`} style={{ animationDelay: '0.9s' }}>
            <path strokeWidth="1.2" d="M46.26 12.33A24 24 0 0 1 40.27 50.19" />
            <path strokeWidth="1.2" d="M33.99 52.48A24 24 0 0 1 5.36 33.17" />
            <path strokeWidth="1.2" d="M5.13 26.49A24 24 0 0 1 41 8.22" />
          </g>
        </g>
        <g transform="translate(47.79 22.16) rotate(70)">
          <path className="orn-rune" style={{ animationDelay: '0.95s' }} d="M0 -1.6V1.6M-1.1 -0.6L1.1 0.6" />
        </g>
        <g transform="translate(46.32 39) rotate(120)">
          <path className="orn-rune" style={{ animationDelay: '1.00s' }} d="M-1.1 1.6L0 -1.6L1.1 1.6" />
        </g>
        <g transform="translate(25.53 48.7) rotate(190)">
          <path className="orn-rune" style={{ animationDelay: '1.05s' }} d="M-1.1 -1.6H1.1L-1.1 1.6H1.1" />
        </g>
        <g transform="translate(13.68 41.86) rotate(230)">
          <path className="orn-rune" style={{ animationDelay: '1.10s' }} d="M0 1.6V-1.6M-1.2 -1.6L0 0L1.2 -1.6" />
        </g>
        <g transform="translate(12.62 17.53) rotate(305)">
          <path className="orn-rune" style={{ animationDelay: '1.15s' }} d="M-1.1 -1.6V1.6M-1.1 0H1.1V1.6" />
        </g>
        <g transform="translate(23.82 9.68) rotate(345)">
          <path className="orn-rune" style={{ animationDelay: '1.20s' }} d="M0 -1.6V1.6M-1.1 -0.6L1.1 0.6" />
        </g>
        <path className="orn-gem" fill="var(--plaque)" strokeWidth="1" d="M29 25.4L31.6 29L29 32.6L26.4 29Z" />
        <circle className="orn-core" style={{ animationDelay: '0.1s' }} filter={`url(#${uid}-pglow)`} cx="29" cy="29" r="1.2" stroke="none" />
        <path className="orn-spark" style={{ animationDelay: '1.20s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M43.78 7.88L44.29 9.58L45.99 10.09L44.29 10.6L43.78 12.3L43.27 10.6L41.57 10.09L43.27 9.58Z" />
        <path className="orn-spark" style={{ animationDelay: '1.28s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M37.21 49.34L37.72 51.04L39.42 51.55L37.72 52.06L37.21 53.76L36.7 52.06L35 51.55L36.7 51.04Z" />
        <path className="orn-spark" style={{ animationDelay: '1.36s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M5.01 27.63L5.52 29.33L7.22 29.84L5.52 30.35L5.01 32.05L4.5 30.35L2.8 29.84L4.5 29.33Z" />
      </svg>
    ),
    // Un cuarto del mismo sello, que se abre desde la esquina.
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g className="orn-bloom orn-br" style={{ animationDelay: '0.6s' }}>
          <g filter={`url(#${uid}-pglow)`}>
            <path strokeWidth="0.8" strokeDasharray="1.2 2.4" d="M30.51 39.32A19.5 19.5 0 0 1 49.32 20.51" />
          </g>
          <g className="orn-flash" filter={`url(#${uid}-pglow)`} style={{ animationDelay: '0.8s' }}>
            <path strokeWidth="0.8" strokeDasharray="1.2 2.4" d="M30.51 39.32A19.5 19.5 0 0 1 49.32 20.51" />
          </g>
        </g>
        <g className="orn-bloom orn-br" style={{ animationDelay: '0.75s' }}>
          <g filter={`url(#${uid}-pglow)`}>
            <path strokeWidth="1.1" d="M23.02 39.06A27 27 0 0 1 29.32 22.64" />
            <path strokeWidth="1.1" d="M34.13 18.16A27 27 0 0 1 49.06 13.02" />
          </g>
          <g className="orn-flash" filter={`url(#${uid}-pglow)`} style={{ animationDelay: '0.95s' }}>
            <path strokeWidth="1.1" d="M23.02 39.06A27 27 0 0 1 29.32 22.64" />
            <path strokeWidth="1.1" d="M34.13 18.16A27 27 0 0 1 49.06 13.02" />
          </g>
        </g>
        <g transform="translate(27.6 33.58) rotate(286)">
          <path className="orn-rune" style={{ animationDelay: '1.00s' }} d="M0 -1.6V1.6M-1.1 -0.6L1.1 0.6" />
        </g>
        <g transform="translate(32.68 24.41) rotate(312)">
          <path className="orn-rune" style={{ animationDelay: '1.05s' }} d="M-1.1 1.6L0 -1.6L1.1 1.6" />
        </g>
        <g transform="translate(42.03 18.11) rotate(340)">
          <path className="orn-rune" style={{ animationDelay: '1.10s' }} d="M-1.1 -1.6H1.1L-1.1 1.6H1.1" />
        </g>
        <path className="orn-spark" style={{ animationDelay: '1.3s' }} filter={`url(#${uid}-pglow)`} fill="var(--class-ink)" stroke="none" d="M31.59 18.17L32.07 19.77L33.67 20.25L32.07 20.73L31.59 22.33L31.11 20.73L29.51 20.25L31.11 19.77Z" />
      </svg>
    ),
  },
  warlock: {
    // Marca del pacto: un rombo roto se traza y adentro el glifo se quema trazo a trazo; cada trazo pasa al rojo blanco,
    // se enfría y queda como brasa. Al final se encienden dos puntos a los costados.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.22s', animationDelay: '0.10s' }} strokeWidth="0.8" d="M27.68 4.84L43.32 21.16" />
        <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.22s', animationDelay: '0.18s' }} strokeWidth="0.8" d="M43.32 28.84L27.68 45.16" />
        <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.22s', animationDelay: '0.26s' }} strokeWidth="0.8" d="M20.32 45.16L4.68 28.84" />
        <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.22s', animationDelay: '0.34s' }} strokeWidth="0.8" d="M4.68 21.16L20.32 4.84" />
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.18s', animationDelay: '0.45s' }} strokeWidth="1.5" d="M24 9V41" />
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.16s', animationDelay: '0.67s' }} strokeWidth="1.5" d="M14 15L24 23L34 15" />
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.16s', animationDelay: '0.87s' }} strokeWidth="1.5" d="M13 35L17 31H31L35 35" />
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.1s', animationDelay: '1.07s' }} strokeWidth="1.5" d="M24 41L20 46M24 41L28 46" />
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.12s', animationDelay: '1.21s' }} strokeWidth="1.5" d="M24 3L27 6.5L24 10L21 6.5Z" />
        </g>
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.18s, 0.9s', animationDelay: '0.45s, 0.78s' }} strokeWidth="1.5" d="M24 9V41" />
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.16s, 0.9s', animationDelay: '0.67s, 0.98s' }} strokeWidth="1.5" d="M14 15L24 23L34 15" />
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.16s, 0.9s', animationDelay: '0.87s, 1.18s' }} strokeWidth="1.5" d="M13 35L17 31H31L35 35" />
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.1s, 0.9s', animationDelay: '1.07s, 1.32s' }} strokeWidth="1.5" d="M24 41L20 46M24 41L28 46" />
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.12s, 0.9s', animationDelay: '1.21s, 1.48s' }} strokeWidth="1.5" d="M24 3L27 6.5L24 10L21 6.5Z" />
        </g>
        <circle className="orn-spark" style={{ animationDelay: '1.35s' }} filter={`url(#${uid}-pglow)`} cx="12" cy="25" r="0.9" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '1.43s' }} filter={`url(#${uid}-pglow)`} cx="36" cy="25" r="0.9" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
    // La firma: un trazo con rulo que termina en el glifo chico, quemado igual.
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.3s', animationDelay: '0.75s' }} strokeWidth="1.2" d="M4 35C11 29 15 37 21 33S30 26 33 31S38 35 40 32" />
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.1s', animationDelay: '1.09s' }} strokeWidth="1.2" d="M44 15V31" />
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.1s', animationDelay: '1.23s' }} strokeWidth="1.2" d="M39.5 18.5L44 22L48.5 18.5" />
        </g>
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.3s, 0.9s', animationDelay: '0.75s, 1.20s' }} strokeWidth="1.2" d="M4 35C11 29 15 37 21 33S30 26 33 31S38 35 40 32" />
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.1s, 0.9s', animationDelay: '1.09s, 1.34s' }} strokeWidth="1.2" d="M44 15V31" />
          <path className="orn-burn" pathLength="100" style={{ animationDuration: '0.1s, 0.9s', animationDelay: '1.23s, 1.48s' }} strokeWidth="1.2" d="M39.5 18.5L44 22L48.5 18.5" />
        </g>
      </svg>
    ),
  },
  ranger: {
    // Brújula: se traza la rosa de los vientos, aparece la aguja desviada, oscila y se asienta en el norte;
    // recién ahí se encienden los cuatro puntos cardinales.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <path className="orn-rosefill" fill="var(--class-ink)" fillOpacity="0.45" stroke="none" d="M28 28L28 5L30.3 22.46ZM28 28L51 28L33.54 30.3ZM28 28L28 51L25.7 33.54ZM28 28L5 28L22.46 25.7Z" />
        <path className="orn-rosefill" fill="var(--class-ink)" fillOpacity="0.25" stroke="none" d="M28 28L37.9 18.1L33.54 25.7ZM28 28L37.9 37.9L30.3 33.54ZM28 28L18.1 37.9L22.46 30.3ZM28 28L18.1 18.1L25.7 22.46Z" />
        <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.6s', animationDelay: '0.1s' }} strokeWidth="1" d="M28 5L30.3 22.46L37.9 18.1L33.54 25.7L51 28L33.54 30.3L37.9 37.9L30.3 33.54L28 51L25.7 33.54L18.1 37.9L22.46 30.3L5 28L22.46 25.7L18.1 18.1L25.7 22.46Z" />
        <g className="orn-needle">
          <path className="orn-needle-n" stroke="none" d="M28 9L30.4 28H25.6Z" />
          <path fill="var(--plaque)" strokeWidth="0.9" d="M25.6 28H30.4L28 47Z" />
          <circle cx="28" cy="28" r="1.6" fill="var(--plaque)" strokeWidth="0.9" />
        </g>
        <circle className="orn-spark" style={{ animationDelay: '1.90s' }} filter={`url(#${uid}-pglow)`} cx="28" cy="1.5" r="1.1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '1.97s' }} filter={`url(#${uid}-pglow)`} cx="54.5" cy="28" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '2.04s' }} filter={`url(#${uid}-pglow)`} cx="28" cy="54.5" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-spark" style={{ animationDelay: '2.11s' }} filter={`url(#${uid}-pglow)`} cx="1.5" cy="28" r="0.8" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
    // La ruta del mapa: serpentea, da un rulo y avanza de a un punto, con paso y tamaño irregulares como un sendero a mano, hasta la cruz de la esquina.
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-pglow`} x="-2" y="-2" width="5" height="5">
            <feGaussianBlur stdDeviation="1.6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <circle className="orn-rune" style={{ animationDelay: '0.600s' }} cx="1" cy="37" r="1.03" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.630s' }} cx="2.6" cy="35.03" r="0.9" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.660s' }} cx="3.76" cy="33.51" r="0.96" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.690s' }} cx="5.02" cy="30.55" r="1.01" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.720s' }} cx="4.16" cy="28.37" r="0.72" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.750s' }} cx="3.08" cy="26.39" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.780s' }} cx="3.94" cy="23.57" r="0.9" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.810s' }} cx="6.03" cy="21.74" r="0.88" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.840s' }} cx="8.2" cy="20.65" r="0.85" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.870s' }} cx="11.09" cy="21.08" r="0.77" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.900s' }} cx="13.64" cy="22.99" r="1.02" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.930s' }} cx="15.34" cy="25.07" r="0.72" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.960s' }} cx="16" cy="27.94" r="0.83" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '0.990s' }} cx="16.73" cy="30.68" r="0.82" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.020s' }} cx="19.54" cy="32.19" r="0.93" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.050s' }} cx="21.86" cy="32.3" r="1.02" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.080s' }} cx="24" cy="31.17" r="0.88" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.110s' }} cx="25.53" cy="28.57" r="0.76" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.140s' }} cx="27.38" cy="26.15" r="0.84" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.170s' }} cx="29.06" cy="24.91" r="0.8" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.200s' }} cx="31.54" cy="23.4" r="0.83" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.230s' }} cx="33.87" cy="21.98" r="0.85" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.260s' }} cx="36.84" cy="20.44" r="0.82" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.290s' }} cx="39.43" cy="18.69" r="0.89" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.320s' }} cx="40.56" cy="16.87" r="0.91" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.350s' }} cx="41.07" cy="14.18" r="0.78" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.380s' }} cx="40.5" cy="11" r="1.02" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.410s' }} cx="38.19" cy="9.15" r="0.86" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.440s' }} cx="35.41" cy="8.43" r="1" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.470s' }} cx="32.83" cy="9.28" r="0.92" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.500s' }} cx="30.38" cy="11.62" r="0.92" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.530s' }} cx="29.56" cy="14.8" r="0.88" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.560s' }} cx="30.5" cy="17.19" r="0.88" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.590s' }} cx="31.78" cy="19.37" r="0.94" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.620s' }} cx="33.63" cy="22.01" r="1.03" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.650s' }} cx="35.37" cy="23.79" r="0.84" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.680s' }} cx="36.89" cy="25.37" r="0.95" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.710s' }} cx="38.49" cy="27.29" r="0.79" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-rune" style={{ animationDelay: '1.740s' }} cx="40.14" cy="29.32" r="0.91" fill="var(--class-ink)" stroke="none" />
        <g filter={`url(#${uid}-pglow)`}>
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.12s', animationDelay: '1.87s' }} strokeWidth="1.5" d="M39.5 29.5L45 35" />
          <path className="orn-brand" pathLength="100" style={{ animationDuration: '0.12s', animationDelay: '2.01s' }} strokeWidth="1.5" d="M45 29.5L39.5 35" />
        </g>
      </svg>
    ),
  },
  monk: {
    // Ensō: un círculo de un solo trazo de pincel, abierto, de grosor variable y que termina seco (pelos abiertos).
    // La pincelada es un relleno; la revela una máscara con un trazo grueso por la línea central que se dibuja en un gesto.
    tl: (uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" strokeLinecap="round" aria-hidden="true">
        <defs>
          <mask id={`${uid}-enso`} maskUnits="userSpaceOnUse">
            <path className="orn-stroke-in" pathLength="100" style={{ animationDuration: '1.1s', animationDelay: '0.15s' }} stroke="white" strokeWidth="10" strokeLinecap="butt" fill="none" d="M9.78 18.97L10.1 18.27L10.44 17.58L10.81 16.9L11.21 16.24L11.64 15.59L12.09 14.96L12.57 14.35L13.08 13.76L13.61 13.18L14.16 12.63L14.74 12.11L15.34 11.6L15.96 11.12L16.6 10.67L17.25 10.24L17.93 9.84L18.62 9.46L19.33 9.12L20.05 8.8L20.79 8.52L21.54 8.26L22.3 8.04L23.07 7.84L23.84 7.68L24.62 7.55L25.41 7.46L26.21 7.39L27 7.36L27.8 7.36L28.59 7.4L29.39 7.47L30.18 7.57L30.96 7.7L31.74 7.87L32.52 8.07L33.28 8.3L34.04 8.56L34.78 8.86L35.51 9.18L36.23 9.54L36.93 9.92L37.62 10.34L38.28 10.78L38.93 11.25L39.56 11.75L40.17 12.27L40.75 12.81L41.31 13.39L41.85 13.98L42.36 14.59L42.84 15.23L43.3 15.89L43.73 16.56L44.13 17.25L44.5 17.96L44.85 18.68L45.16 19.41L45.44 20.16L45.69 20.92L45.9 21.68L46.09 22.45L46.24 23.23L46.36 24.02L46.45 24.81L46.51 25.6L46.53 26.39L46.52 27.18L46.47 27.97L46.4 28.76L46.29 29.54L46.15 30.31L45.98 31.08L45.77 31.84L45.54 32.59L45.27 33.33L44.98 34.06L44.66 34.77L44.3 35.47L43.92 36.15L43.52 36.81L43.09 37.46L42.63 38.09L42.14 38.7L41.64 39.28L41.11 39.85L40.56 40.39L39.98 40.91L39.39 41.4L38.78 41.87L38.15 42.31L37.51 42.73L36.85 43.12L36.18 43.48L35.49 43.82L34.79 44.12L34.08 44.4L33.36 44.65L32.63 44.87L31.9 45.06L31.16 45.21L30.41 45.34L29.66 45.44L28.91 45.51L28.16 45.55L27.41 45.56L26.65 45.54L25.9 45.49L25.16 45.41L24.42 45.3L23.68 45.16L22.95 44.99L22.23 44.8L21.52 44.57L20.82 44.32L20.13 44.04L19.45 43.74L18.78 43.4L18.13 43.04L17.5 42.66L16.88 42.25L16.27 41.82L15.69 41.37L15.12 40.89L14.57 40.39L14.05 39.87L13.54 39.33L13.05 38.78L12.59 38.2L12.15 37.6L11.74 36.99L11.35 36.37L10.98 35.72L10.64 35.07L10.33 34.4L10.04 33.72L9.78 33.03L9.54 32.33L9.34 31.62L9.16 30.9L9.01 30.17" />
          </mask>
        </defs>
        <g mask={`url(#${uid}-enso)`}>
          <path fill="var(--class-ink)" d="M11.66 19.81L12.21 19.27L12.6 18.71L12.98 18.15L13.65 17.78L14.02 17.23L14.54 16.8L15.04 16.37L15.57 15.97L15.99 15.48L16.4 14.98L16.95 14.62L17.3 14.04L17.84 13.66L18.38 13.29L18.94 12.95L19.42 12.47L19.94 12.03L20.54 11.73L21.19 11.57L21.79 11.24L22.4 10.97L23.03 10.72L23.66 10.44L24.33 10.28L25.02 10.27L25.66 9.91L26.35 9.87L27.05 9.91L27.74 9.92L28.44 9.7L29.13 9.83L29.81 10.02L30.52 10L31.25 9.98L31.9 10.27L32.56 10.54L33.3 10.55L33.91 10.94L34.68 10.96L35.24 11.43L35.87 11.77L36.47 12.14L37.2 12.35L37.82 12.71L38.29 13.29L38.82 13.76L39.41 14.19L39.88 14.73L40.43 15.21L41 15.68L41.5 16.21L41.85 16.85L42.42 17.36L42.56 18.12L42.95 18.73L43.42 19.32L43.58 20.04L44.1 20.63L44.16 21.38L44.29 22.1L44.6 22.78L44.72 23.5L44.89 24.21L44.8 24.96L44.9 25.68L44.7 26.4L44.59 27.12L44.65 27.83L44.4 28.52L44.32 29.22L44.21 29.92L44.05 30.61L43.8 31.27L43.32 31.85L43.24 32.55L42.87 33.15L42.49 33.73L42.19 34.34L41.8 34.91L41.51 35.53L41.05 36.04L40.69 36.61L40.17 37.06L39.73 37.57L39.19 37.98L38.9 38.63L38.24 38.9L37.74 39.34L37.27 39.82L36.78 40.28L36.27 40.73L35.65 40.98L35.11 41.4L34.55 41.79L33.98 42.17L33.35 42.42L32.76 42.78L32.07 42.85L31.46 43.21L30.79 43.33L30.17 43.76L29.49 43.93L28.79 43.84L28.11 44.05L27.42 44.26L26.72 44.08L26.02 44.18L25.34 43.95L24.64 43.96L23.96 43.83L23.26 43.75L22.58 43.61L21.97 43.24L21.31 43.02L20.59 42.97L19.99 42.59L19.3 42.42L18.74 41.99L18.06 41.77L17.37 41.53L16.78 41.15L16.19 40.74L15.73 40.2L15.13 39.81L14.7 39.23L14.08 38.85L13.66 38.27L13.26 37.68L12.69 37.22L12.32 36.61L11.76 36.12L11.49 35.45L11.08 34.85L10.67 34.25L10.35 33.59L10.12 32.9L9.89 32.22L9.6 31.54L9.34 30.86L9.2 30.13L8.81 30.21L8.98 30.94L9.07 31.69L9.19 32.43L9.43 33.15L9.72 33.84L9.98 34.55L10.2 35.29L10.47 36L10.94 36.61L11.16 37.37L11.62 37.98L11.92 38.71L12.45 39.28L13 39.82L13.39 40.51L14.02 40.98L14.51 41.59L15.18 42L15.77 42.5L16.38 42.98L16.94 43.55L17.52 44.1L18.27 44.38L18.9 44.88L19.67 45.11L20.32 45.62L21.07 45.91L21.88 45.99L22.64 46.23L23.4 46.49L24.19 46.64L24.97 46.87L25.79 46.8L26.58 47L27.39 46.86L28.21 47.06L29.03 47.18L29.83 46.96L30.65 46.93L31.52 47.1L32.33 46.9L33.2 46.88L33.96 46.51L34.81 46.38L35.6 46.07L36.43 45.84L37.24 45.56L38.05 45.25L38.75 44.73L39.53 44.34L40.29 43.92L41.05 43.47L41.73 42.92L42.22 42.15L43.02 41.71L43.54 41L44.12 40.33L44.57 39.57L45.12 38.88L45.52 38.1L46.05 37.39L46.42 36.59L46.83 35.81L47.09 34.96L47.31 34.11L47.76 33.34L47.74 32.41L47.91 31.56L48.08 30.71L48.26 29.85L48.4 28.99L48.3 28.11L48.44 27.25L48.36 26.38L48.11 25.52L48.1 24.66L47.83 23.83L47.77 22.97L47.58 22.13L47.52 21.26L47.22 20.45L46.78 19.69L46.74 18.78L46.28 18.04L46.06 17.18L45.7 16.38L45.05 15.76L44.75 14.92L44.18 14.25L43.72 13.51L43.27 12.75L42.74 12.04L42.09 11.44L41.51 10.77L40.83 10.21L40.04 9.78L39.37 9.21L38.76 8.53L38 8.08L37.22 7.64L36.35 7.41L35.66 6.77L34.78 6.57L34.01 6.06L33.13 5.86L32.24 5.75L31.4 5.41L30.54 5.11L29.64 5.1L28.74 5.1L27.86 4.81L26.95 4.81L26.06 4.92L25.16 5L24.23 4.83L23.36 5.08L22.47 5.25L21.56 5.35L20.67 5.55L19.79 5.79L18.91 6.04L18.12 6.51L17.31 6.9L16.44 7.21L15.57 7.53L14.81 8.05L14.08 8.59L13.37 9.17L12.53 9.59L11.92 10.29L11.23 10.89L10.59 11.54L10.1 12.33L9.64 13.12L9.26 13.95L8.77 14.69L8.65 15.65L8.28 16.45L7.98 17.27L7.9 18.13Z" />
          <path stroke="var(--plaque)" strokeWidth="0.35" d="M28.49 46.24L27.65 46.26L26.82 46.25L25.98 46.2L25.15 46.11L24.33 45.99L23.51 45.84L22.7 45.65L21.9 45.43L21.11 45.17L20.33 44.88L19.56 44.56L18.82 44.21L18.08 43.82L17.37 43.41L16.67 42.96L15.99 42.49L15.34 41.99L14.71 41.46L14.1 40.9L13.51 40.33L12.95 39.72L12.41 39.1L11.9 38.45L11.42 37.78L10.97 37.09L10.55 36.39L10.16 35.67L9.8 34.93L9.47 34.17L9.17 33.41" />
          <path stroke="var(--plaque)" strokeWidth="0.35" d="M28.46 45.54L27.65 45.56L26.84 45.55L26.04 45.5L25.24 45.42L24.44 45.3L23.65 45.15L22.87 44.97L22.1 44.76L21.34 44.51L20.59 44.23L19.85 43.92L19.13 43.58L18.42 43.21L17.73 42.81L17.06 42.38L16.41 41.92L15.78 41.44L15.17 40.93L14.58 40.4L14.01 39.84L13.47 39.26L12.95 38.65L12.46 38.03L12 37.39L11.57 36.72L11.16 36.04L10.78 35.34L10.43 34.63L10.11 33.91L9.83 33.17" />
          <path stroke="var(--plaque)" strokeWidth="0.35" d="M28.43 44.94L27.65 44.96L26.87 44.95L26.09 44.9L25.31 44.82L24.54 44.71L23.78 44.57L23.02 44.39L22.27 44.18L21.53 43.94L20.81 43.67L20.09 43.37L19.4 43.04L18.71 42.68L18.04 42.3L17.39 41.88L16.76 41.44L16.15 40.97L15.56 40.48L14.99 39.96L14.44 39.42L13.92 38.86L13.42 38.27L12.94 37.67L12.5 37.05L12.07 36.4L11.68 35.74L11.31 35.07L10.98 34.38L10.67 33.68L10.39 32.96" />
        </g>
        <circle className="orn-ember" style={{ '--dx': '3px', '--dy': '-3px', animationDelay: '1.05s' } as CSSProperties} cx="3.5" cy="33" r="0.9" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '2px', '--dy': '-4px', animationDelay: '1.10s' } as CSSProperties} cx="5.5" cy="38.5" r="0.7" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '-1px', '--dy': '-4px', animationDelay: '1.15s' } as CSSProperties} cx="11" cy="43" r="0.5" fill="var(--class-ink)" stroke="none" />
      </svg>
    ),
    // Una rama de bambú a tinta: la pincelada hace de rama y de ella cuelgan cuatro hojas, cada una de un trazo, que brotan al final.
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" aria-hidden="true">
        <defs>
          <mask id={`${uid}-enso2`} maskUnits="userSpaceOnUse">
            <path className="orn-stroke-in" pathLength="100" style={{ animationDuration: '0.45s', animationDelay: '0.8s' }} stroke="white" strokeWidth="7" strokeLinecap="butt" fill="none" d="M5 31L5.6 31.01L6.2 31.02L6.8 31.03L7.4 31.04L8 31.04L8.6 31.05L9.2 31.04L9.8 31.03L10.4 31.02L11 31L11.6 30.97L12.2 30.94L12.8 30.9L13.4 30.85L14 30.79L14.6 30.72L15.2 30.64L15.8 30.55L16.4 30.44L17 30.33L17.6 30.21L18.2 30.07L18.8 29.92L19.4 29.76L20 29.58L20.6 29.39L21.2 29.19L21.8 28.97L22.4 28.74L23 28.5L23.6 28.24L24.2 27.97L24.8 27.69L25.4 27.39L26 27.08L26.6 26.76L27.2 26.42L27.8 26.07L28.4 25.71L29 25.33L29.6 24.94L30.2 24.55L30.8 24.14L31.4 23.72L32 23.29L32.6 22.85L33.2 22.4L33.8 21.94L34.4 21.47L35 21L35.6 20.52L36.2 20.03L36.8 19.54L37.4 19.05L38 18.54L38.6 18.04L39.2 17.53L39.8 17.02L40.4 16.51L41 16" />
          </mask>
        </defs>
        <g mask={`url(#${uid}-enso2)`}>
          <path fill="var(--class-ink)" d="M4.98 32.12L5.58 32.2L6.17 32.5L6.78 32.72L7.38 32.81L7.99 33L8.6 33.07L9.22 33.18L9.84 33.04L10.45 32.92L11.08 32.98L11.7 32.88L12.32 32.76L12.95 32.76L13.58 32.78L14.19 32.55L14.81 32.39L15.46 32.44L16.08 32.31L16.7 32.14L17.31 31.87L17.93 31.72L18.55 31.53L19.18 31.36L19.84 31.3L20.44 31.03L21.05 30.77L21.66 30.5L22.28 30.26L22.89 29.98L23.53 29.76L24.06 29.3L24.75 29.16L25.36 28.84L25.88 28.33L26.57 28.15L27.13 27.72L27.75 27.38L28.27 26.86L28.97 26.64L29.59 26.25L30.17 25.82L30.67 25.25L31.25 24.79L31.87 24.38L32.47 23.94L33.14 23.57L33.69 23.04L34.23 22.5L34.77 21.95L35.41 21.52L36 21.02L36.64 20.58L37.12 19.93L37.66 19.36L38.3 18.91L38.96 18.47L39.52 17.91L39.98 17.23L40.64 16.79L41.24 16.28L40.76 15.72L40.16 16.23L39.62 16.81L38.88 17.15L38.24 17.61L37.7 18.18L37.14 18.73L36.48 19.16L35.76 19.49L35.2 20.02L34.59 20.48L34.03 21L33.37 21.38L32.71 21.75L32.06 22.12L31.53 22.63L30.93 23.05L30.35 23.48L29.73 23.84L29.03 24.07L28.41 24.41L27.83 24.77L27.33 25.28L26.65 25.46L26.07 25.79L25.43 26.01L24.92 26.45L24.24 26.54L23.65 26.78L23.14 27.19L22.47 27.24L21.91 27.51L21.32 27.68L20.74 27.88L20.15 28.01L19.56 28.13L18.96 28.21L18.42 28.47L17.85 28.6L17.27 28.69L16.69 28.79L16.1 28.74L15.52 28.78L14.94 28.83L14.39 29.04L13.81 29.02L13.22 28.91L12.65 29.03L12.08 29.12L11.5 29.07L10.92 29.02L10.35 29.12L9.76 29.03L9.18 28.91L8.6 29.02L8.01 29.09L7.42 29.27L6.82 29.34L6.23 29.54L5.62 29.82L5.02 29.88Z" />
          <path stroke="var(--plaque)" strokeWidth="0.35" d="M26.46 26.49L26.87 26.26L27.29 26.02L27.71 25.77L28.12 25.52L28.54 25.26L28.96 25L29.38 24.73L29.79 24.46L30.21 24.18L30.63 23.89L31.05 23.6L31.47 23.3L31.88 23L32.3 22.69L32.72 22.38L33.14 22.07L33.56 21.75L33.98 21.42L34.39 21.1L34.81 20.77L35.23 20.43L35.65 20.09L36.07 19.75L36.49 19.41L36.91 19.06L37.33 18.71L37.75 18.36L38.17 18.01L38.59 17.66L39.01 17.3" />
          <path stroke="var(--plaque)" strokeWidth="0.35" d="M26.74 27.02L27.17 26.78L27.59 26.54L28.01 26.29L28.44 26.03L28.86 25.77L29.28 25.51L29.7 25.23L30.13 24.96L30.55 24.67L30.97 24.38L31.39 24.09L31.81 23.79L32.24 23.48L32.66 23.18L33.08 22.86L33.5 22.54L33.92 22.22L34.34 21.9L34.77 21.57L35.19 21.23L35.61 20.9L36.03 20.56L36.45 20.22L36.87 19.87L37.29 19.53L37.71 19.18L38.13 18.82L38.55 18.47L38.97 18.12L39.39 17.76" />
        </g>
        <circle className="orn-ember" style={{ '--dx': '-3px', '--dy': '3px', animationDelay: '1.20s' } as CSSProperties} cx="44" cy="11.5" r="0.7" fill="var(--class-ink)" stroke="none" />
        <circle className="orn-ember" style={{ '--dx': '-2px', '--dy': '4px', animationDelay: '1.25s' } as CSSProperties} cx="40.5" cy="9.5" r="0.5" fill="var(--class-ink)" stroke="none" />
        <defs>
          <mask id={`${uid}-hoja0`} maskUnits="userSpaceOnUse">
            <path className="orn-stroke-in" pathLength="100" style={{ animationDuration: '0.3s', animationDelay: '1.15s' }} stroke="white" strokeWidth="5.1" strokeLinecap="butt" fill="none" d="M23 28.5L23.03 28.79L23.06 29.09L23.1 29.38L23.13 29.67L23.17 29.97L23.21 30.26L23.26 30.54L23.31 30.83L23.36 31.11L23.42 31.39L23.48 31.67L23.55 31.95L23.62 32.22L23.71 32.48L23.79 32.75L23.89 33.01L23.99 33.27L24.1 33.52L24.22 33.77L24.35 34.01L24.48 34.25L24.62 34.49L24.77 34.72L24.92 34.95L25.09 35.18L25.26 35.4L25.43 35.62L25.61 35.83L25.8 36.04L26 36.25L26.2 36.45L26.4 36.66L26.61 36.86L26.83 37.05L27.05 37.25L27.27 37.44L27.49 37.64L27.71 37.83L27.94 38.02L28.16 38.21" />
          </mask>
        </defs>
        <path mask={`url(#${uid}-hoja0)`} fill="var(--class-ink)" d="M22.88 28.51L22.61 28.84L22.48 29.15L22.4 29.47L22.23 29.79L22.21 30.1L22.23 30.4L22.16 30.72L22.17 31.03L22.14 31.35L22.14 31.67L22.27 31.96L22.26 32.29L22.28 32.61L22.37 32.91L22.47 33.21L22.64 33.49L22.76 33.78L22.84 34.1L22.98 34.38L23.22 34.61L23.32 34.92L23.5 35.18L23.74 35.4L23.95 35.63L24.15 35.87L24.4 36.07L24.65 36.27L24.84 36.51L25.07 36.72L25.3 36.92L25.6 37.05L25.82 37.26L26.1 37.41L26.41 37.51L26.64 37.71L26.95 37.81L27.21 37.96L27.5 38.08L27.78 38.21L28.14 38.24L28.18 38.19L28.1 37.83L27.93 37.58L27.76 37.32L27.58 37.08L27.45 36.79L27.25 36.59L27.13 36.3L26.99 36.06L26.8 35.85L26.7 35.58L26.54 35.36L26.39 35.16L26.22 34.96L26.11 34.73L26.02 34.48L25.9 34.27L25.79 34.05L25.74 33.8L25.63 33.59L25.48 33.41L25.46 33.16L25.37 32.94L25.23 32.75L25.14 32.53L25.12 32.28L25.04 32.06L24.96 31.83L24.84 31.6L24.69 31.38L24.69 31.12L24.58 30.87L24.44 30.63L24.36 30.36L24.2 30.11L24.14 29.83L24.03 29.56L23.8 29.3L23.65 29.02L23.46 28.75L23.12 28.49Z" />
        <defs>
          <mask id={`${uid}-hoja1`} maskUnits="userSpaceOnUse">
            <path className="orn-stroke-in" pathLength="100" style={{ animationDuration: '0.3s', animationDelay: '1.30s' }} stroke="white" strokeWidth="5.3" strokeLinecap="butt" fill="none" d="M23 28.5L23.33 28.57L23.66 28.64L23.99 28.71L24.32 28.78L24.65 28.86L24.98 28.93L25.3 29.01L25.63 29.1L25.95 29.19L26.27 29.28L26.58 29.37L26.9 29.47L27.21 29.58L27.52 29.69L27.82 29.81L28.13 29.93L28.43 30.06L28.72 30.2L29.01 30.34L29.3 30.49L29.59 30.65L29.87 30.81L30.15 30.98L30.42 31.15L30.69 31.34L30.96 31.52L31.23 31.72L31.49 31.92L31.75 32.12L32.01 32.33L32.26 32.54L32.51 32.76L32.76 32.98L33.01 33.21L33.26 33.43L33.5 33.67L33.75 33.9L33.99 34.13L34.24 34.37L34.48 34.6" />
          </mask>
        </defs>
        <path mask={`url(#${uid}-hoja1)`} fill="var(--class-ink)" d="M22.98 28.62L23.25 28.96L23.53 29.25L23.81 29.54L24.12 29.7L24.41 29.9L24.71 30.05L25.03 30.11L25.32 30.25L25.6 30.45L25.9 30.52L26.17 30.71L26.45 30.84L26.73 30.95L27.01 31.06L27.29 31.15L27.57 31.26L27.81 31.44L28.11 31.48L28.39 31.59L28.61 31.79L28.91 31.86L29.15 32.03L29.45 32.1L29.73 32.22L29.96 32.41L30.28 32.48L30.54 32.64L30.83 32.77L31.12 32.91L31.35 33.12L31.67 33.24L31.99 33.35L32.25 33.55L32.54 33.72L32.84 33.89L33.18 34.01L33.48 34.17L33.8 34.34L34.11 34.49L34.4 34.68L34.56 34.52L34.36 34.24L34.19 33.93L34.01 33.62L33.83 33.32L33.68 32.98L33.48 32.69L33.28 32.41L33.03 32.17L32.86 31.84L32.66 31.54L32.38 31.33L32.15 31.06L31.91 30.8L31.65 30.57L31.43 30.26L31.12 30.09L30.84 29.86L30.59 29.59L30.27 29.44L29.99 29.19L29.64 29.1L29.33 28.92L29.04 28.69L28.69 28.61L28.36 28.47L28.03 28.32L27.69 28.21L27.35 28.11L27 28.04L26.63 28.03L26.3 27.92L25.93 27.94L25.58 27.92L25.25 27.82L24.89 27.81L24.53 27.87L24.17 27.88L23.79 28.03L23.41 28.18L23.02 28.38Z" />
        <defs>
          <mask id={`${uid}-hoja2`} maskUnits="userSpaceOnUse">
            <path className="orn-stroke-in" pathLength="100" style={{ animationDuration: '0.3s', animationDelay: '1.45s' }} stroke="white" strokeWidth="5.5" strokeLinecap="butt" fill="none" d="M33.08 22.49L33.23 22.83L33.37 23.16L33.52 23.5L33.67 23.84L33.82 24.17L33.98 24.5L34.14 24.83L34.3 25.16L34.46 25.48L34.63 25.8L34.81 26.11L34.99 26.42L35.17 26.72L35.37 27.02L35.56 27.32L35.77 27.6L35.98 27.88L36.19 28.16L36.42 28.43L36.65 28.69L36.89 28.95L37.13 29.2L37.38 29.45L37.64 29.68L37.91 29.92L38.18 30.14L38.45 30.37L38.74 30.58L39.02 30.79L39.32 31L39.62 31.2L39.92 31.4L40.23 31.59L40.54 31.79L40.85 31.97L41.17 32.16L41.49 32.35L41.81 32.53L42.13 32.71L42.45 32.89" />
          </mask>
        </defs>
        <path mask={`url(#${uid}-hoja2)`} fill="var(--class-ink)" d="M32.99 22.53L32.84 23L32.74 23.44L32.76 23.84L32.77 24.24L32.79 24.65L32.95 24.99L32.97 25.4L33.06 25.78L33.19 26.15L33.35 26.5L33.55 26.83L33.69 27.19L33.81 27.58L34.04 27.89L34.25 28.23L34.48 28.54L34.75 28.83L34.99 29.13L35.2 29.47L35.51 29.72L35.8 29.99L36.1 30.23L36.4 30.48L36.7 30.73L37.05 30.91L37.37 31.13L37.68 31.36L38.07 31.48L38.38 31.69L38.72 31.86L39.07 32.03L39.43 32.15L39.78 32.31L40.17 32.39L40.53 32.52L40.86 32.68L41.28 32.7L41.66 32.79L42.01 32.91L42.41 32.96L42.48 32.83L42.24 32.51L41.95 32.27L41.69 31.99L41.47 31.64L41.17 31.43L40.9 31.18L40.67 30.88L40.4 30.65L40.17 30.38L39.91 30.14L39.67 29.9L39.41 29.69L39.23 29.37L38.98 29.16L38.76 28.92L38.58 28.64L38.36 28.41L38.16 28.17L37.98 27.91L37.79 27.66L37.64 27.39L37.39 27.19L37.2 26.94L37.06 26.66L36.88 26.4L36.69 26.15L36.53 25.87L36.29 25.65L36.06 25.4L35.91 25.1L35.74 24.81L35.53 24.53L35.3 24.26L35.01 24.02L34.86 23.69L34.58 23.43L34.28 23.16L34 22.89L33.62 22.66L33.17 22.45Z" />
        <defs>
          <mask id={`${uid}-hoja3`} maskUnits="userSpaceOnUse">
            <path className="orn-stroke-in" pathLength="100" style={{ animationDuration: '0.3s', animationDelay: '1.60s' }} stroke="white" strokeWidth="4.7" strokeLinecap="butt" fill="none" d="M33.08 22.49L33.34 22.46L33.6 22.44L33.86 22.41L34.12 22.39L34.38 22.37L34.64 22.35L34.9 22.34L35.16 22.33L35.42 22.32L35.67 22.32L35.93 22.32L36.18 22.32L36.44 22.33L36.69 22.34L36.94 22.36L37.19 22.39L37.44 22.42L37.69 22.46L37.93 22.5L38.18 22.55L38.42 22.6L38.67 22.66L38.91 22.73L39.15 22.8L39.39 22.88L39.62 22.97L39.86 23.06L40.1 23.15L40.33 23.25L40.56 23.35L40.8 23.46L41.03 23.58L41.26 23.69L41.49 23.81L41.72 23.93L41.95 24.06L42.18 24.18L42.4 24.31L42.63 24.44L42.86 24.57" />
          </mask>
        </defs>
        <path mask={`url(#${uid}-hoja3)`} fill="var(--class-ink)" d="M33.09 22.6L33.37 22.82L33.65 22.96L33.92 23.08L34.18 23.16L34.44 23.23L34.69 23.19L34.95 23.27L35.2 23.38L35.44 23.33L35.68 23.37L35.92 23.38L36.15 23.5L36.38 23.43L36.61 23.54L36.84 23.52L37.06 23.55L37.28 23.6L37.51 23.55L37.71 23.68L37.95 23.65L38.18 23.64L38.39 23.7L38.61 23.76L38.85 23.74L39.06 23.85L39.3 23.84L39.53 23.9L39.75 23.98L39.98 24.05L40.23 24.08L40.49 24.11L40.72 24.21L40.95 24.29L41.22 24.33L41.51 24.32L41.76 24.39L42.03 24.44L42.3 24.5L42.57 24.55L42.85 24.59L42.87 24.54L42.7 24.32L42.51 24.11L42.32 23.93L42.13 23.72L41.93 23.54L41.76 23.29L41.56 23.1L41.34 22.94L41.1 22.82L40.89 22.63L40.68 22.45L40.44 22.32L40.19 22.21L39.94 22.09L39.72 21.92L39.44 21.87L39.2 21.71L38.94 21.63L38.67 21.57L38.41 21.45L38.15 21.32L37.86 21.36L37.6 21.24L37.32 21.23L37.04 21.21L36.77 21.14L36.49 21.23L36.21 21.14L35.94 21.25L35.66 21.26L35.39 21.31L35.12 21.28L34.85 21.41L34.59 21.52L34.32 21.51L34.06 21.63L33.8 21.75L33.55 21.92L33.31 22.1L33.07 22.37Z" />
      </svg>
    ),
  },
  rogue: {
    // Cortabolsas: la soga entra por el borde izquierdo y sale por el de arriba, floja, con una bolsa de monedas colgando.
    // Un corte finísimo cruza el cordón, la bolsa baja de golpe y se le escapan dos monedas que caen hasta salir por el borde de abajo de la tarjeta.
    tl: (_uid, big) => (
      <svg className={`orn-deco orn-tl${big}`} style={{ overflow: 'visible' }} preserveAspectRatio="xMinYMin meet" viewBox="0 0 80 60" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <g className="orn-sway">
          <path className="orn-wire" pathLength="100" strokeWidth="1.5" d="M-5 52Q26 46 70 -5" />
          <g transform="translate(40 25.89) scale(1.2)">
            <g className="orn-bell">
              <path strokeWidth="0.8" d="M0 0V1.8" />
              <g className="orn-drop">
                <path strokeWidth="0.8" d="M0 2.5V4.3" />
                <g transform="translate(0 3)">
                  <path fill="var(--plaque)" strokeWidth="1.1" d="M-2 5.8C-8 8 -9.5 15 -7 18.5C-4.5 21.5 4.5 21.5 7 18.5C9.5 15 8 8 2 5.8Z" />
                  <path fill="var(--plaque)" strokeWidth="0.9" d="M-2 5.2L-3.6 1.9L-1.2 3.2L0 1.2L1.2 3.2L3.6 1.9L2 5.2Z" />
                  <path strokeWidth="1.1" d="M-2.8 5.3Q0 6.4 2.8 5.3" />
                  <path strokeWidth="0.6" d="M-4.6 9.6Q-6 14 -4.6 18.2M3.6 10.4Q4.6 13.5 4 16.4" />
                </g>
              </g>
              <path className="orn-cut" pathLength="100" strokeWidth="0.6" d="M-6 5.2L6 -1" />
            </g>
          </g>
        </g>
        <g className="orn-coin-x" style={{ '--dx': '7px', animationDelay: '1.45s' } as CSSProperties}>
          <g className="orn-coin-y" style={{ animationDelay: '1.45s' }}>
            <ellipse cx="42" cy="35.89" rx="2.2" ry="1.3" transform="rotate(-12 42 35.89)" fill="var(--class-ink)" stroke="none" />
          </g>
        </g>
        <g className="orn-coin-x" style={{ '--dx': '13px', animationDelay: '1.55s' } as CSSProperties}>
          <g className="orn-coin-y" style={{ animationDelay: '1.55s' }}>
            <ellipse cx="42" cy="35.89" rx="2.2" ry="1.3" transform="rotate(-12 42 35.89)" fill="var(--class-ink)" stroke="none" />
          </g>
        </g>
      </svg>
    ),
    // Remate de esquina como el del Paladín, rayado en tiza, con la jerga de ladrones sobre la línea: conteo y círculo tachado
    // al pie, flecha que baja por el costado y, en la curva, el círculo con punto («gente amiga»).
    br: (uid) => (
      <svg className="orn-deco orn-br" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 50 40" fill="none" stroke="var(--class-ink)" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <defs>
          <filter id={`${uid}-chalk`} x="-0.2" y="-0.2" width="1.4" height="1.4">
            <feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves="2" seed="3" result="n" />
            <feDisplacementMap in="SourceGraphic" in2="n" scale="1.1" xChannelSelector="R" yChannelSelector="G" result="d" />
            <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.6 1.75" result="m" />
            <feComposite in="d" in2="m" operator="in" />
          </filter>
        </defs>
        <g filter={`url(#${uid}-chalk)`}>
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.45s', animationDelay: '0.70s' }} strokeWidth="1.6" d="M3 35.5L5.42 35.15L7.83 35.61L10.25 35.69L12.67 35.36L15.08 35.61L17.5 35.22L19.92 35.31L22.33 35.43L24.75 35.43L27.17 35.62L29.58 35.79L32 35.5Q42 35.5 42 25.5L42 25.5L42.07 23L41.76 20.5L41.77 18L41.84 15.5L42.1 13L41.9 10.5L41.68 8L42.29 5.5L42 3" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.05s', animationDelay: '1.18s' }} strokeWidth="1.4" d="M6 24L6.08 26.33L6.21 28.67L6 31" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.05s', animationDelay: '1.26s' }} strokeWidth="1.4" d="M9 24L9.03 26.33L8.78 28.67L9 31" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.05s', animationDelay: '1.34s' }} strokeWidth="1.4" d="M12 24L11.92 26.33L12.13 28.67L12 31" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.07s', animationDelay: '1.42s' }} strokeWidth="1.4" d="M4 29.5L6.53 28.56L8.99 27.48L11.46 26.39L14 25.5" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.16s', animationDelay: '1.61s' }} strokeWidth="1.4" d="M21.38 24.01L21.95 23.89L22.53 23.92L23.11 24.02L23.63 24.29L24.12 24.6L24.61 24.94L24.99 25.39L25.24 25.92L25.53 26.44L25.68 27.02L25.7 27.61L25.56 28.19L25.49 28.79L25.21 29.32L24.9 29.83L24.45 30.22L23.99 30.59L23.46 30.85L22.91 31.08L22.32 31.18L21.73 31.16L21.12 31.16L20.57 30.92L20.04 30.63L19.55 30.3L19.08 29.9L18.73 29.41L18.51 28.84L18.32 28.26L18.24 27.66L18.28 27.06L18.37 26.46L18.58 25.89L18.87 25.35L19.25 24.87L19.68 24.42L20.23 24.14L20.8 23.91L21.39 23.74L22 23.65" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.06s', animationDelay: '1.80s' }} strokeWidth="1.4" d="M18.6 31.2L20.26 29.31L22 27.5L23.82 25.76L25.4 23.8" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.1s', animationDelay: '1.98s' }} strokeWidth="1.4" d="M36.5 4L36.56 6.75L36.47 9.5L36.43 12.25L36.5 15" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.06s', animationDelay: '2.11s' }} strokeWidth="1.4" d="M34 12.5L35.3 13.95L36.5 15.5L37.81 14.05L39 12.5" />
          <path className="orn-scratch" pathLength="100" style={{ animationDuration: '0.16s', animationDelay: '2.29s' }} strokeWidth="1.4" d="M35.59 25.18L36.13 25.25L36.63 25.46L37.05 25.82L37.49 26.13L37.78 26.6L38.1 27.04L38.28 27.55L38.37 28.09L38.47 28.63L38.4 29.18L38.3 29.72L38.01 30.2L37.68 30.64L37.34 31.07L36.92 31.44L36.42 31.69L35.91 31.92L35.35 31.94L34.8 31.94L34.25 31.88L33.71 31.74L33.23 31.47L32.73 31.22L32.36 30.8L32.01 30.36L31.7 29.88L31.53 29.34L31.42 28.78L31.52 28.22L31.59 27.67L31.7 27.11L31.98 26.61L32.29 26.13L32.7 25.73L33.16 25.39L33.69 25.17L34.24 25.04L34.8 24.95L35.37 24.88L35.92 25.07" />
          <circle className="orn-dotin" style={{ animationDelay: '2.48s' }} cx="35" cy="28.5" r="1.1" fill="var(--class-ink)" stroke="none" />
        </g>
      </svg>
    ),
  },
};

/** El dibujo de [classId] para una esquina, o `null` si la clase no tiene
 *  estilo (homebrew). [big] es la variante de Puntos de golpe. */
export function ClassOrnament({ classId, corner, big = false }: { classId: string; corner: OrnamentCorner; big?: boolean }) {
  // Sin los signos que `useId` pone alrededor: el id va dentro de un `url(#…)`.
  const uid = useId().replace(/[^\w-]/g, '');
  if (!Object.hasOwn(ART, classId)) return null;
  const art = ART[classId]!;
  return corner === 'tl' ? art.tl(uid, big ? ' orn-big' : '') : art.br(uid);
}
