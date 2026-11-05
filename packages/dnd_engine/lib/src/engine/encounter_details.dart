import 'dart:math';

import '../data/content_repository.dart';
import '../domain/creature.dart';
import '../domain/damage_type.dart';
import '../domain/encounter.dart';
import 'encounter_difficulty.dart';
import 'encounter_npc.dart';
import 'initiative.dart';
import 'npc_stats.dart';

/// El VD con el que un combatiente entra en la cuenta de dificultad, o null
/// si no tiene: un jugador, un PNJ con ficha de personaje o sin estadísticas.
/// El de un PNJ sale de **su** bloque y no de la criatura de base: el bloque es
/// una copia que el DM pudo haber editado.
num? _challengeRating(
  Combatant c,
  EncounterNpc? npc,
  ContentRepository repo,
) {
  if (c.kind == CombatantKind.player) return null;
  if (npc != null) return npc.sheet != null ? null : npc.npc.block?.cr;
  final id = c.creatureId;
  return id == null ? null : repo.creature(id)?.cr;
}

/// La dificultad de [e] para quienes **entraron al combate** (no toda la
/// mesa). Acá solo se resuelve de dónde sale cada número; la regla es de
/// [encounterDifficulty]. [memberLevels] es `memberId` → nivel total: un
/// jugador sin nivel no suma.
EncounterDifficulty encounterDifficultyFor(
  Encounter e, {
  required Map<String, int> memberLevels,
  required Map<String, EncounterNpc> npcs,
  required ContentRepository repo,
}) {
  final party = <int>[];
  final enemies = <num?>[];
  final allies = <num?>[];
  final enemyLevels = <int>[];
  for (final c in e.combatants) {
    if (c.side == CombatantSide.neutral) continue;
    if (c.kind == CombatantKind.player) {
      final level = memberLevels[c.memberId];
      if (level != null) party.add(level);
      continue;
    }
    final npc = c.npcId == null ? null : npcs[c.npcId];
    final sheet = npc?.sheet;
    // Un PNJ con ficha es un personaje más: de aliado suma su nivel al
    // presupuesto y de enemigo lo descuenta. No tiene VD ni PX.
    if (sheet != null) {
      (c.side == CombatantSide.ally ? party : enemyLevels)
          .add(sheet.totalLevel);
      continue;
    }
    (c.side == CombatantSide.ally ? allies : enemies)
        .add(_challengeRating(c, npc, repo));
  }
  return encounterDifficulty(
    partyLevels: party,
    enemyCrs: enemies,
    allyCrs: allies,
    enemyLevels: enemyLevels,
  );
}

/// Lo que la planilla del combate muestra por fila y la banda de dificultad,
/// ya resuelto: el cliente no calcula nada. El `Map` se arma acá y no en el
/// puente porque la paridad compara el orden de las claves y el generador usa
/// este mismo código.
///
/// [members] es `memberId` → nivel y CA de la ficha real del jugador.
Map<String, dynamic> encounterDetails(
  Encounter e, {
  required Map<String, ({int level, int armorClass})> members,
  required Map<String, EncounterNpc> npcs,
  required ContentRepository repo,
}) {
  final difficulty = encounterDifficultyFor(
    e,
    memberLevels: {for (final m in members.entries) m.key: m.value.level},
    npcs: npcs,
    repo: repo,
  );
  return {
    'rows': [for (final c in e.combatants) _row(c, members, npcs, repo)],
    'difficulty': {
      'lowBudget': difficulty.lowBudget,
      'moderateBudget': difficulty.moderateBudget,
      'highBudget': difficulty.highBudget,
      'enemyXp': difficulty.enemyXp,
      'allyXp': difficulty.allyXp,
      'netXp': difficulty.netXp,
      'remainingXp': difficulty.remainingXp,
      'tier': difficulty.tier?.name,
      'characters': difficulty.characters,
      'lowestLevel': difficulty.lowestLevel,
      'highestLevel': difficulty.highestLevel,
      'enemies': difficulty.enemies,
      'enemyCharacters': difficulty.enemyCharacters,
      'uncountedEnemies': difficulty.uncountedEnemies,
      'powerfulCr': difficulty.powerfulCr,
      'manyCreatures': difficulty.manyCreatures,
    },
  };
}

Map<String, dynamic> _row(
  Combatant c,
  Map<String, ({int level, int armorClass})> members,
  Map<String, EncounterNpc> npcs,
  ContentRepository repo,
) {
  final npc = c.npcId == null ? null : npcs[c.npcId];
  final creature = c.creatureId == null ? null : repo.creature(c.creatureId!);
  // El perfil de la fila: el del catálogo para un monstruo, el bloque propio
  // para un PNJ. De ahí salen los máximos de los contadores legendarios.
  final block = switch (c.kind) {
    CombatantKind.monster => creature,
    CombatantKind.npc => npc?.npc.block,
    CombatantKind.player => null,
  };
  final String? ac;
  if (c.kind == CombatantKind.player) {
    final m = members[c.memberId];
    ac = m == null ? null : '${m.armorClass}';
  } else if (npc != null) {
    ac = NpcStats.of(npc.npc, npc.sheet, repo).armorClass;
  } else {
    ac = creature?.ac;
  }
  // Solo si la CA empieza con un número: «13+spellLevel» de una invocación
  // queda en null y la pantalla muestra el texto y el bono aparte, sin que
  // React tenga que calcular.
  final leading = ac == null ? null : RegExp(r'^(\d+)(?:\s|$)').firstMatch(ac);
  final cr =
      c.side == CombatantSide.neutral ? null : _challengeRating(c, npc, repo);
  return {
    'id': c.id,
    'legendaryActions': block?.legendaryActionsPerRound ?? 0,
    'legendaryResistances': block?.legendaryResistancesPerDay ?? 0,
    'monsterLine':
        c.kind == CombatantKind.monster ? _monsterLine(creature) : null,
    'xp': cr == null ? null : xpForChallengeRating(cr),
    'ac': ac,
    'acTotal':
        leading == null ? null : int.parse(leading.group(1)!) + c.acBonus,
  };
}

/// Lo que el DM necesita de un monstruo sin abrir nada: con qué pega, o su
/// tipo si no ataca.
String? _monsterLine(Creature? creature) {
  if (creature == null) return null;
  final attack =
      creature.actions.where((a) => a.attackBonus != null).firstOrNull;
  if (attack == null) return creature.displayKind;
  return [
    '${attack.name} +${attack.attackBonus}',
    if (attack.damage != null)
      [
        attack.damage!,
        if (attack.damageType != null) DamageType.labelFor(attack.damageType!),
      ].join(' '),
    if (attack.reach.isNotEmpty) attack.reach,
  ].join(' · ');
}

/// La iniciativa que se le propone a cada combatiente al empezar: `combatId →
/// tirada`. Un jugador no tiene entrada (la canta desde la mesa), ni lo que no
/// se sabe con qué tirar.
///
/// Un PNJ con bloque tira con su bloque; uno con ficha, con la iniciativa de
/// su ficha compilada; uno sin estadísticas tira el d20 solo.
Map<String, int> suggestInitiatives(
  Encounter e, {
  required Map<String, EncounterNpc> npcs,
  required ContentRepository repo,
  Random? random,
}) {
  int? suggest(Combatant c) {
    if (c.creatureId case final id?) {
      final creature = repo.creature(id);
      return creature == null ? null : rollInitiative(creature, random: random);
    }
    final npcId = c.npcId;
    if (npcId == null) return null;
    final entry = npcs[npcId];
    if (entry == null) return null;
    if (entry.npc.block case final block?) {
      return rollInitiative(block, random: random);
    }
    if (NpcStats.of(entry.npc, entry.sheet, repo).sheet case final sheet?) {
      return rollInitiativeWith(sheet.initiative, random: random);
    }
    return rollInitiativeWith(0, random: random);
  }

  return {
    for (final c in e.combatants)
      if (suggest(c) case final n?) c.id: n,
  };
}
