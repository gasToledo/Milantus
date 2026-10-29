// Presentación de un PNJ, la misma en la Biblioteca, en su ficha y en la mesa
// de una campaña (`npc_shared.dart` de Flutter). Ningún número se calcula acá:
// PG, CA, si viene herido, la especie y las clases los da el motor
// (`npcViews`); esto solo los pone en palabras.
import type { NpcView } from '../../engine';
import type { Texts } from '../../i18n/texts';
import { fold } from '../../codex/entries';

export type NpcKind = 'none' | 'block' | 'character';

/** Un tipo desconocido es «sin estadísticas», como `NpcSheetKind.fromJson`:
 *  es el que no promete una ficha que no está. */
export const kindOf = (v: NpcView): NpcKind =>
  v.npc.sheetKind === 'block' || v.npc.sheetKind === 'character' ? v.npc.sheetKind : 'none';

/**
 * La línea que dice qué es un PNJ, bajo su nombre: «Sin estadísticas»,
 * «Caballero · CA 18 · PG 52» o «Elfa · Mago 7». Con [withHurt], los PG
 * guardados de un herido en la campaña: un bloque muestra «PG 7/11» en lugar
 * del máximo y una ficha los suma al final (`npcTypeLine` de Flutter).
 */
export function npcTypeLine(v: NpcView, t: Texts, { withHurt = false } = {}): string {
  const hurt = withHurt ? v.hurt : null;
  switch (kindOf(v)) {
    case 'none':
      return t.npcKinds.none;
    case 'block': {
      if (!v.block) return t.npcKinds.block;
      const hp = hurt ? `${hurt.current}/${hurt.max}` : v.block.hp;
      return t.npcBlockLine(v.baseName ?? v.npc.name, v.block.ac, hp);
    }
    case 'character': {
      if (v.species === null) return t.npcKinds.character;
      const classes = v.classes.map((c) => `${c.name} ${c.level}`).join(' · ');
      const line = classes ? t.npcCharacterLine(v.species, classes) : v.species;
      return hurt ? `${line} · ${t.dmHpShort(hurt.current, hurt.max)}` : line;
    }
  }
}

/** Los tags sin dos que difieran en mayúsculas, el primero que se escribió
 *  gana (`Npc.normalizeTags`). El documento ya viene normalizado; esto junta
 *  los de varios PNJ para los filtros. */
export function normalizeTags(tags: Iterable<string>): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of tags) {
    const tag = raw.trim();
    if (tag && !seen.has(tag.toLowerCase())) {
      seen.add(tag.toLowerCase());
      out.push(tag);
    }
  }
  return out;
}

/** Los filtros comparan tags sin distinguir mayúsculas (`Npc.hasTag`). */
export const hasTag = (v: NpcView, tag: string): boolean =>
  (v.npc.tags ?? []).some((x) => x.toLowerCase() === tag.trim().toLowerCase());

/** La búsqueda por nombre ignora tildes y mayúsculas, como el Códice. */
export const nameMatches = (v: NpcView, query: string): boolean => fold(v.npc.name).includes(fold(query.trim()));

export type NpcStatus = NpcView['status'];

/** El color de cada estado, siempre junto con la palabra: quien no distingue
 *  el verde del rojo tiene que saber igual si el PNJ sigue vivo. */
export const STATUS_TONE: Record<NpcStatus, string> = {
  alive: 'border-verdant text-verdant',
  dead: 'border-crimson text-crimson',
  unknown: 'border-text-muted text-text-muted',
};

/** Un estado desconocido es «vivo», como `NpcStatus.fromJson`. */
export const statusOf = (raw: string | undefined): NpcStatus =>
  raw === 'dead' || raw === 'unknown' ? raw : 'alive';
