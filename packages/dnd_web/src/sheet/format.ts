/** Los modificadores se firman siempre: `+3`, `−1` (U+2212), nunca `3`
 *  (`diseno-web.md` §4.3). Es presentación; el número es del motor. */
export function signed(n: number): string {
  return n >= 0 ? `+${n}` : `−${-n}`;
}

/** `CharacterResource.key`: la clave con que se guarda el uso, y con la que
 *  `actOn` reconoce el recurso a gastar. Una clase sola no lleva prefijo. */
export function resourceKey(r: { classId?: string | null; id: string }): string {
  return r.classId ? `${r.classId}:${r.id}` : r.id;
}
