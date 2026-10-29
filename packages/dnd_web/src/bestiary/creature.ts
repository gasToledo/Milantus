// El perfil de una criatura del catálogo, tal como está en el JSON
// (`Creature.toJson` en el motor). Lo que el motor deriva —línea de tipo,
// desafío, iniciativa, percepción pasiva— viene aparte en `BestiaryRow`;
// acá solo está lo que se muestra tal cual.
import type { AbilityId, JsonObject } from '../engine';

export interface CreatureSpellRef {
  spellId: string;
  castAtLevel?: number;
  note?: string;
}

export interface CreatureAction {
  name: string;
  description?: string;
  /** El bono de ataque, sin signo (`"9"`). */
  attackBonus?: string | null;
  damage?: string | null;
  damageType?: string | null;
  reach?: string;
  kind?: 'action' | 'bonus' | 'reaction' | 'legendary';
  spellcasting?: {
    ability: AbilityId;
    saveDc?: number;
    attackBonus?: number;
    componentRule?: string;
    groups: { usesPerDay?: number; spells: CreatureSpellRef[] }[];
  };
}

export interface CreatureProfile {
  id: string;
  name: string;
  source?: string;
  ac: string;
  hp: string;
  hitDice?: string;
  speed?: string;
  /** Claves cortas del catálogo: `str`, `dex`… */
  abilityScores?: Partial<Record<AbilityKey, number>>;
  savingThrows?: Partial<Record<AbilityKey, number>>;
  /** Habilidad → bono ya sumado. */
  skills?: Record<string, number>;
  senses?: string;
  languages?: string;
  defenses?: string;
  legendaryActionsPerRound?: number;
  traits?: { name: string; description?: string }[];
  actions?: CreatureAction[];
}

export type AbilityKey = 'str' | 'dex' | 'con' | 'int' | 'wis' | 'cha';

/** Las seis características en el orden de un perfil, con el id que usa el
 *  motor para rotularlas (`catalogLabel('ability', …)`). */
export const ABILITY_KEYS: readonly [AbilityKey, AbilityId][] = [
  ['str', 'strength'],
  ['dex', 'dexterity'],
  ['con', 'constitution'],
  ['int', 'intelligence'],
  ['wis', 'wisdom'],
  ['cha', 'charisma'],
];

export const asProfile = (raw: JsonObject): CreatureProfile => raw as unknown as CreatureProfile;
