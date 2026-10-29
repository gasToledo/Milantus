// Vocabulario cerrado del motor que la ficha necesita para **rotular**, no para
// calcular: qué característica gobierna cada habilidad (para su abreviatura) y
// cómo se clasifica un tiempo de lanzamiento. Repite `Skill.ability`
// (`dnd_engine/lib/src/domain/skill.dart`) y `Spell.actionType`
// (`content.dart`); si allá cambia, cambia acá. Ningún número sale de esto.
import type { AbilityId } from '../engine';

export const ABILITIES: readonly AbilityId[] = [
  'strength',
  'dexterity',
  'constitution',
  'intelligence',
  'wisdom',
  'charisma',
];

/** Habilidad → característica que la gobierna (`Skill.ability`). */
export const SKILL_ABILITY: Record<string, AbilityId> = {
  acrobatics: 'dexterity',
  'animal-handling': 'wisdom',
  arcana: 'intelligence',
  athletics: 'strength',
  deception: 'charisma',
  history: 'intelligence',
  insight: 'wisdom',
  intimidation: 'charisma',
  investigation: 'intelligence',
  medicine: 'wisdom',
  nature: 'intelligence',
  perception: 'wisdom',
  performance: 'charisma',
  persuasion: 'charisma',
  religion: 'intelligence',
  'sleight-of-hand': 'dexterity',
  stealth: 'dexterity',
  survival: 'wisdom',
};

/**
 * Si un conjuro se lanza como reacción. El catálogo guarda el tiempo de
 * lanzamiento como texto en español también en inglés (la traducción no lo
 * toca), y `Spell.actionType` lo clasifica por el comienzo: lo mismo acá.
 *
 * ponytail: es una copia de la clasificación del motor. Si un día hacen falta
 * los cuatro tipos de acción en React, el camino es exponer `actionType` desde
 * `js/entrypoint.dart` en vez de ampliar esta función.
 */
export function isReactionSpell(spell: { castingTime?: unknown } | undefined): boolean {
  return typeof spell?.castingTime === 'string' && spell.castingTime.toLowerCase().startsWith('reacción');
}
