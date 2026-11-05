import 'dart:math';

import '../data/content_repository.dart';
import '../domain/encounter.dart';
import 'combat_ops.dart';
import 'encounter_monsters.dart';
import 'encounter_npc.dart';
import 'npc_stats.dart';

/// Lo que se le puede hacer al combate de una campaña, como `NpcEdits` a un
/// PNJ. No muta la entrada. Devuelve `null` si no hay nada que guardar (el
/// combatiente ya no está, el combate se cerró, el cambio no cambia nada). Un
/// tipo desconocido lanza: un cliente desfasado no debe creer que guardó.
///
/// `base` es el combate actual o uno nuevo en preparación. Toda acción con
/// `combatantId` devuelve `null` sin combate o sin ese combatiente.
///
/// - `open`: abre un combate si no hay uno.
/// - `addPlayer` con `memberId`, `name`, `initiative`: un jugador, una sola vez.
/// - `addMonsters` con `creatureId`, `count`, `rollHp?`, `side?`.
/// - `addNpc` con `entry` (una entrada de PNJ), `initiative`, `side`, `revive`.
///   El bando es obligatorio salvo para un PNJ sin estadísticas. Vincular el
///   PNJ a la campaña es tarea del cliente.
/// - `setSide` con `combatantId`, `side`.
/// - `convertToNpc` con `combatantId`, `name`, `npcId`.
/// - `start` con `initiatives` (id → valor).
/// - `next`.
/// - `adjustHp` con `combatantId`, `delta`: el daño gasta primero los PG
///   temporales; la cura no los devuelve.
/// - `setTags` con `combatantId`, `tags`.
/// - `setLegendary` con `combatantId`, `actions?`, `resistances?`.
/// - `setInitiative` con `combatantId`, `initiative`.
/// - `remove` con `combatantId`.
/// - `setAdvantage` con `combatantId`, `advantage` (`advantage`,
///   `disadvantage` o `null` para quitarla).
/// - `setTempHp` con `combatantId`, `value`.
/// - `setAcBonus` con `combatantId`, `value`.
class EncounterActions {
  const EncounterActions._();

  static Encounter? apply(
    Encounter? current,
    ContentRepository repo,
    Map<String, dynamic> action, {
    required String Function(String prefix) newId,
    Random? random,
  }) {
    final base = current ?? Encounter(id: newId('encounter'));

    Combatant? find() {
      if (current == null) return null;
      final id = action['combatantId'] as String?;
      for (final c in current.combatants) {
        if (c.id == id) return c;
      }
      return null;
    }

    switch (action['type']) {
      case 'open':
        return current == null ? base : null;
      case 'addPlayer':
        final memberId = action['memberId'] as String;
        if (base.combatants.any((c) => c.memberId == memberId)) return null;
        return base.withCombatant(
          Combatant(
            id: newId('c'),
            kind: CombatantKind.player,
            name: action['name'] as String,
            initiative: action['initiative'] as int,
            memberId: memberId,
          ),
        );
      case 'addMonsters':
        final creatureId = action['creatureId'] as String;
        final creature = repo.creature(creatureId);
        if (creature == null) {
          throw FormatException('No existe la criatura "$creatureId".');
        }
        return base.withMonsters(
          creature,
          action['count'] as int,
          newId: () => newId('c'),
          side: CombatantSide.fromJson(action['side'] as String?) ??
              CombatantSide.enemy,
          rollHp: action['rollHp'] as bool? ?? false,
          random: random,
        );
      case 'addNpc':
        final e = EncounterNpc.fromEntry(
          (action['entry'] as Map).cast<String, dynamic>(),
        );
        // Una sola vez por combate, contra la mesa ya guardada.
        if (base.combatants.any((c) => c.npcId == e.npc.id)) return null;
        final maxHp = NpcStats.of(e.npc, e.sheet, repo).maxHp;
        final side = CombatantSide.fromJson(action['side'] as String?);
        // Sin PG el constructor lo deja neutral; con PG el bando se elige.
        if (maxHp > 0 && side == null) {
          throw const FormatException('Falta el bando del PNJ.');
        }
        final revive = action['revive'] as bool? ?? false;
        final hp =
            e.fromLibrary || revive ? maxHp : min(e.currentHp ?? maxHp, maxHp);
        return base.withCombatant(
          Combatant(
            id: newId('c'),
            kind: CombatantKind.npc,
            name: e.npc.name,
            initiative: action['initiative'] as int,
            npcId: e.npc.id,
            currentHp: hp,
            maxHp: maxHp,
            side: side,
          ),
        );
      case 'setSide':
        if (find() == null) return null;
        // Sin bando, o con uno desconocido, no hay nada que guardar: caer a
        // enemigo cambiaba el bando de un combatiente por un cliente desfasado.
        final side = CombatantSide.fromJson(action['side'] as String?);
        if (side == null) return null;
        return current!.withSide(action['combatantId'] as String, side);
      case 'convertToNpc':
        final c = find();
        if (c == null) return null;
        return current!.withReplaced(
          c.copyWith(
            kind: CombatantKind.npc,
            name: action['name'] as String,
            npcId: action['npcId'] as String,
          ),
        );
      case 'start':
        return current?.start(
          (action['initiatives'] as Map).cast<String, num>().map(
                (k, v) => MapEntry(k, v.toInt()),
              ),
        );
      case 'next':
        return current?.next();
      case 'adjustHp':
        final c = find();
        final delta = action['delta'] as int;
        if (c == null ||
            c.kind == CombatantKind.player ||
            c.isStatless ||
            delta == 0) {
          return null;
        }
        if (delta > 0) {
          // Curar no devuelve los temporales.
          return current!.withHp(c.id, c.currentHp + delta);
        }
        final n = CombatOps.absorbDamage(c.currentHp, c.tempHp, -delta);
        final e = current!.withHp(c.id, n.hp);
        return e.withReplaced(
          e.combatants.firstWhere((x) => x.id == c.id).copyWith(
                tempHp: n.tempHp,
              ),
        );
      case 'setTags':
        if (find() == null) return null;
        return current!.withTags(
          action['combatantId'] as String,
          (action['tags'] as List).cast<String>(),
        );
      case 'setLegendary':
        if (find() == null) return null;
        return current!.withLegendarySpent(
          action['combatantId'] as String,
          actions: action['actions'] as int?,
          resistances: action['resistances'] as int?,
        );
      case 'setInitiative':
        final c = find();
        final n = action['initiative'] as int;
        if (c == null || c.initiative == n) return null;
        // `withCombatant` con el mismo id reemplaza y reordena, y el turno
        // sigue en quien lo tenía.
        // ponytail: corregir a mitad de ronda puede hacer que alguien actúe
        // dos veces o se saltee esa ronda; es una corrección puntual del DM,
        // que ve el orden nuevo.
        return current!.withCombatant(c.copyWith(initiative: n));
      case 'remove':
        if (find() == null) return null;
        return current!.withoutCombatant(action['combatantId'] as String);
      case 'setAdvantage':
        if (find() == null) return null;
        return current!.withAdvantage(
          action['combatantId'] as String,
          CombatantAdvantage.fromJson(action['advantage'] as String?),
        );
      case 'setTempHp':
        final c = find();
        if (c == null || c.kind == CombatantKind.player || c.isStatless) {
          return null;
        }
        // Fija el valor exacto y no toma el mayor como la ficha: el DM tiene
        // que poder corregir un número mal cargado.
        return current!.withTempHp(c.id, action['value'] as int);
      case 'setAcBonus':
        if (find() == null) return null;
        return current!.withAcBonus(
          action['combatantId'] as String,
          action['value'] as int,
        );
      default:
        throw FormatException(
          'Acción de combate desconocida: ${action['type']}',
        );
    }
  }
}
