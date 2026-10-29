// Las entradas del Cuaderno: notas, combates cerrados y subidas de nivel,
// intercaladas por capítulo. Es presentación (agrupar, titular, buscar), no
// reglas: repite el criterio de `notebook_view.dart` de Flutter para que el DM
// lea lo mismo en los dos clientes. Nombres de criaturas y de clases salen del
// catálogo, en el idioma activo.
import type { DmChapter, DmEncounterLog, DmLevelUp, DmNotebook } from '../api/client';
import { nameOf } from '../api/catalog';
import { fold } from '../codex/entries';
import type { Catalog } from '../engine';
import type { Texts } from '../i18n/texts';

export type EntryKind = 'note' | 'fight' | 'levelUp';

export interface Entry {
  key: string;
  kind: EntryKind;
  /** `null` sin capítulo, o de uno que el DM borró: un combate no se borra con
   *  su capítulo y no hay que perderlo. */
  chapterId: string | null;
  /** Milisegundos, o `null` si no trae fecha (van primero, como en Flutter). */
  at: number | null;
  title: string;
  /** Una nota es Markdown; lo demás lo escribió la app y va en párrafos. */
  markdown: boolean;
  body: string;
  rounds?: number;
}

/** Un monstruo del catálogo se nombra por el catálogo (`logGroupName`): así el
 *  registro sigue al idioma de la interfaz. Un PNJ trae su nombre propio. */
function groupName(m: NonNullable<DmEncounterLog['monsters']>[number], catalog: Catalog): string {
  if (m.npc || m.name === '') return m.name;
  return (m.creatureId ? nameOf(catalog.creatures, m.creatureId) : null) ?? m.name;
}

function logNames(
  group: NonNullable<DmEncounterLog['monsters']>,
  joiner: string,
  catalog: Catalog,
): string {
  return group
    .map((m) => {
      const name = groupName(m, catalog);
      return m.npc || (m.count ?? 1) <= 1 ? name : `${name} ×${m.count}`;
    })
    .join(joiner);
}

const side = (log: DmEncounterLog, s: 'enemy' | 'ally' | 'neutral') =>
  (log.monsters ?? []).filter((m) => (m.side ?? 'enemy') === s);

function fightTitle(log: DmEncounterLog, t: Texts, catalog: Catalog): string {
  const enemies = side(log, 'enemy');
  // El título nombra solo a los enemigos: «contra» un aliado no se pelea.
  return enemies.length === 0
    ? t.dmFightTitle
    : t.dmFightAgainst(enemies.map((m) => groupName(m, catalog)).join(', '));
}

function fightBody(log: DmEncounterLog, t: Texts, catalog: Catalog): string {
  const who = (log.players ?? []).length === 0 ? t.dmLogTheTable : (log.players ?? []).join(', ');
  const allies = side(log, 'ally');
  const neutrals = side(log, 'neutral');
  const extra = [
    ...(allies.length > 0 ? [t.dmLogAllies(logNames(allies, ', ', catalog))] : []),
    ...(neutrals.length > 0 ? [t.dmLogNeutrals(logNames(neutrals, ', ', catalog))] : []),
  ];
  const enemies = side(log, 'enemy');
  if (enemies.length === 0) return [t.dmLogNoEnemies(who), ...extra].join('\n\n');
  const total = enemies.reduce((n, m) => n + (m.count ?? 1), 0);
  const down = enemies.reduce((n, m) => n + (m.defeated ?? 0), 0);
  // El sujeto va siempre explícito: «cayeron todos» a secas, al lado de
  // «Sagan contra Goblin ×3», se leería como que cayó el grupo.
  const fell = down === 0 ? t.dmLogNoneFell : down === total ? t.dmLogAllFell : t.dmLogSomeFell(down, total);
  return [t.dmLogAgainst(who, logNames(enemies, ` ${t.wordAnd} `, catalog), fell), ...extra].join('\n\n');
}

const ms = (iso: string | undefined): number | null => {
  const n = iso ? Date.parse(iso) : NaN;
  return Number.isNaN(n) ? null : n;
};

/** Todas las entradas del cuaderno, de la más vieja a la más nueva: se lee como
 *  un diario. `sort` es estable: las que no traen fecha van primero en el orden
 *  en que las devolvió el servidor. */
export function buildEntries(
  notebook: DmNotebook,
  chapters: readonly DmChapter[],
  t: Texts,
  catalog: Catalog,
): Entry[] {
  const known = new Set(chapters.map((c) => c.id));
  const chapterOf = (id: string | null | undefined) => (id && known.has(id) ? id : null);
  const entries: Entry[] = [
    ...notebook.notes.map(
      (n): Entry => ({
        key: `note-${n.id}`,
        kind: 'note',
        chapterId: chapterOf(n.chapterId),
        at: ms(n.updatedAt),
        title: n.title,
        markdown: true,
        body: n.body ?? '',
      }),
    ),
    ...notebook.encounterLogs.map(
      (l, i): Entry => ({
        key: `fight-${l.id ?? i}`,
        kind: 'fight',
        chapterId: chapterOf(l.chapterId),
        at: ms(l.endedAt),
        title: fightTitle(l, t, catalog),
        markdown: false,
        body: fightBody(l, t, catalog),
        rounds: l.rounds ?? 1,
      }),
    ),
    ...notebook.levelUps.map(
      (u: DmLevelUp): Entry => ({
        key: `levelup-${u.id}`,
        kind: 'levelUp',
        chapterId: chapterOf(u.chapterId),
        at: ms(u.at),
        title: t.dmLevelUpTitle(u.characterName, u.level),
        markdown: false,
        // «Pícaro 3»; si la clase ya no está en el catálogo, queda el id.
        body: `${nameOf(catalog.classes, u.classId) ?? u.classId} ${u.classLevel}`,
      }),
    ),
  ];
  return entries.sort((a, b) => {
    if (a.at === null || b.at === null) return a.at === b.at ? 0 : a.at === null ? -1 : 1;
    return a.at - b.at;
  });
}

/** Una nota coincide por título o texto; un combate o una subida, por su título
 *  (que nombra a los enemigos o al personaje). Sin tildes ni mayúsculas. */
export function matches(entry: Entry, query: string): boolean {
  const q = fold(query.trim());
  if (q === '') return true;
  return fold(entry.title).includes(q) || (entry.kind === 'note' && fold(entry.body).includes(q));
}

/** «hoy», «ayer», «hace 5 días» o la fecha, como `_stamp` de Flutter. */
export function stamp(at: number | null, now: number, t: Texts): string {
  if (at === null) return '';
  const days = Math.floor((now - at) / 86_400_000);
  if (days <= 0) return t.dmToday;
  if (days === 1) return t.dmYesterday;
  if (days < 30) return t.dmDaysAgo(days);
  const d = new Date(at);
  return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;
}
