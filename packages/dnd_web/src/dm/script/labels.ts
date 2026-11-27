import type { DmScript } from '../../api/client';

/** El número con el que se nombra cada hito: el paso `i` (desde 1) es «i» y
 *  los caminos de una bifurcación suman su letra («4a»). Es presentación, no una
 *  regla: por eso no está en el motor. El orden de las claves del `Map` es el
 *  de lectura. */
export function milestoneLabels(script: DmScript): Map<string, string> {
  return new Map(
    script.steps.flatMap((step, i): [string, string][] =>
      step.type === 'fork' ? step.paths.map((p, j) => [p.id, `${i + 1}${'abcd'[j]}`]) : [[step.id, `${i + 1}`]],
    ),
  );
}
