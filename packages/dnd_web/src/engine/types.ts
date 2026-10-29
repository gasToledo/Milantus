/**
 * La ficha calculada, tal como la serializa `ComputedSheet.toJson()` en
 * `packages/dnd_engine/lib/src/domain/computed_sheet.dart`.
 *
 * Está escrita **a mano** a partir de ese `toJson`, y por eso el tipo es una
 * promesa y no una garantía: si el motor agrega o cambia un campo, esto no se
 * entera solo. La red es la prueba de paridad de CI (`npm run test:parity`):
 * compara el JSON completo de JS contra el de Dart, así que un campo nuevo
 * aparece ahí aunque este archivo no lo mencione. Al sumarlo, se suma acá.
 *
 * Lo que ninguna pantalla leyó todavía queda como `JsonObject`: tipar a ojo
 * estructuras que nadie usa es inventar un contrato. Se tipan al migrar la
 * primera pantalla que las necesite, mirando el `toJson` de la clase.
 */

/** Cualquier valor JSON: lo que todavía no tiene tipo propio. */
export type JsonObject = { [key: string]: unknown };

/** Nombres de característica, los de `Ability.name` en Dart. */
export type AbilityId =
  | 'strength'
  | 'dexterity'
  | 'constitution'
  | 'intelligence'
  | 'wisdom'
  | 'charisma';

/** Solo aparecen las claves que la ficha tiene (`Map<Ability, int>` en Dart). */
export type ByAbility = Partial<Record<AbilityId, number>>;

/** Nivel (como texto, claves de objeto JSON) → cantidad. */
export type ByLevel = Record<string, number>;

/** Un aporte con su fuente: el total solo no se puede explicar en la mesa. */
export interface SourcedBonus {
  amount: number;
  source: string;
}

export interface AbilityBonus extends SourcedBonus {
  ability: AbilityId;
}

export interface WeaponExtraDamage {
  dice: string;
  type: string;
}

export interface ModeDamageBonus {
  modeId: string;
  name: string;
  amount: number;
}

export interface Attack {
  weaponId: string;
  baseWeaponId: string;
  /** Ausente en los ataques que no vienen de un objeto del inventario. */
  sourceEntryId?: string;
  name: string;
  attackBonus: number;
  proficient: boolean;
  abilityUsed: AbilityId;
  damage: string;
  damageType: string;
  damageTypeOptions: string[];
  /** Ausente cuando no hay daño extra. */
  extraDamage?: WeaponExtraDamage[];
  spellcastingFocus: boolean;
  attacksPerAction: number;
  mastery: string | null;
  offHand: boolean;
  /** `AttackAction.name` en Dart (`action`, `bonusAction`…). */
  action: string;
  critRange: number;
  modeBonuses: ModeDamageBonus[];
  /** Alcance normal y largo, en pies. Ausente en los cuerpo a cuerpo. */
  range?: [number, number];
}

export interface Spellcasting {
  ability: AbilityId;
  progression: string;
  preparation: string;
  spellList: string;
  saveDc: number;
  attackBonus: number;
  cantripsKnown: number;
  preparedCount: number;
  slotsByLevel: ByLevel;
}

export interface SpellcastingBlock {
  classId: string;
  classLevel: number;
  spellcasting: Spellcasting;
}

export interface ArmorClassFormula {
  classId: string | null;
  ability: AbilityId;
  allowShield: boolean;
}

export interface Advantage {
  roll: string;
  abilities: AbilityId[];
  skill: string | null;
  conditions: string[];
  vsSpells: boolean;
  source: string;
  conditional: boolean;
}

export interface ActiveMode {
  id: string;
  name: string;
  resourceKey: string;
  variants: JsonObject[];
  tempHpOnActivate: number;
  endsConditions: string[];
  endsWhenIncapacitated: boolean;
  blockedBy: string | null;
  available: boolean;
  active: boolean;
  activeVariant: string | null;
  requiresMode: string | null;
  multiSelect: boolean;
  resistances: string[];
  advantages: Advantage[];
  damageBonus: number;
  damageAbility: AbilityId | null;
  noSpellcasting: boolean;
}

export interface CharacterResource {
  classId?: string;
  id: string;
  name: string;
  max: number;
  recharge: string;
  shortRestRecovery: number;
  description: string;
  saveDc?: number;
  saveAbility?: AbilityId;
  damage?: string;
  pool?: true;
}

export interface ComputedSheet {
  level: number;
  proficiencyBonus: number;
  /** Id de clase → niveles en ella. */
  classLevels: Record<string, number>;
  /** Tamaño del dado de golpe → cantidad. */
  hitDiceBySize: ByLevel;
  abilityScores: ByAbility;
  abilityModifiers: ByAbility;
  abilityBonuses: AbilityBonus[];
  d20Modifier: number;
  heroicInspirationOnLongRest: boolean;
  ignoresArmorStrength: boolean;
  halfProficiencyUnskilled: boolean;
  savingThrowProficiencies: AbilityId[];
  savingThrowBonus: number;
  savingThrowBonusByAbility: ByAbility;
  skillProficiencies: string[];
  expertiseSkills: string[];
  skillBonuses: Record<string, SourcedBonus[]>;
  armorProficiencies: string[];
  weaponProficiencies: string[];
  toolProficiencies: string[];
  maxHp: number;
  hitDie: number;
  armorClass: number;
  unarmoredDefenseOptions: ArmorClassFormula[];
  selectedUnarmoredDefenseClassId: string | null;
  carriedWeight: number;
  /** Rótulo ya traducido («Mediano»), no un id. */
  size: string;
  speed: number;
  initiative: number;
  initiativeBonuses: SourcedBonus[];
  advantages: Advantage[];
  scalingDice: { name: string; dice: string }[];
  activeModes: ActiveMode[];
  darkvision: number | null;
  /** Modo de movimiento → pies. Solo los que la ficha tiene. */
  speeds: Record<string, number>;
  senses: Record<string, number>;
  resistances: string[];
  immunities: string[];
  weaponMasterySlots: number;
  attunementSlots: number;
  attacksPerAction: number;
  attacks: Attack[];
  passives: { name: string; description: string }[];
  resources: CharacterResource[];
  companions: JsonObject[];
  innateSpells: JsonObject[];
  alwaysPreparedSpellIds: string[];
  alwaysPreparedSpellIdsByClass: Record<string, string[]>;
  spellListAdditionIds: string[];
  featureChoiceSlots: JsonObject[];
  itemChoiceSlots: JsonObject[];
  targetChoiceSlots: JsonObject[];
  proficiencyChoiceSlots: JsonObject[];
  expertiseChoiceSlots: JsonObject[];
  languages: string[];
  languageChoiceSlots: JsonObject[];
  spellChoiceSlots: JsonObject[];
  spellDamageBonuses: Record<string, SourcedBonus[]>;
  wildShape: JsonObject | null;
  spellcasting: Spellcasting | null;
  spellcastingBlocks: SpellcastingBlock[];
  normalSpellSlotsByLevel: ByLevel;
  pactSlotsByLevel: ByLevel;
  /** Puntaje antes de cualquier bonus: el asignado en la creación. */
  baseAbilityScores: ByAbility;
  abilityChecks: ByAbility;
  savingThrows: ByAbility;
  /** Id de habilidad → modificador total. */
  skillModifiers: Record<string, number>;
  passivePerception: number;
  carryingCapacity: number;
  isEncumbered: boolean;
}

/**
 * El catálogo que consume el motor: una lista de JSON por tipo, con las claves
 * de `ContentRepository.fromJsonPacks`. `items` ya trae los objetos mágicos
 * mezclados, como los arma el cargador de directorio.
 */
export interface Catalog {
  races: JsonObject[];
  classes: JsonObject[];
  subclasses: JsonObject[];
  lineages: JsonObject[];
  backgrounds: JsonObject[];
  feats: JsonObject[];
  weapons: JsonObject[];
  armor: JsonObject[];
  items: JsonObject[];
  spells: JsonObject[];
  creatures: JsonObject[];
}

/** El JSON de `Character` (ver `Character.toJson` en el motor). */
export type CharacterJson = JsonObject;
