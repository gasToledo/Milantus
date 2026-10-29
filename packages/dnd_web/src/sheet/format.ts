/** Los modificadores se firman siempre: `+3`, `−1` (U+2212), nunca `3`
 *  (`diseno-web.md` §4.3). Es presentación; el número es del motor. */
export function signed(n: number): string {
  return n >= 0 ? `+${n}` : `−${-n}`;
}
