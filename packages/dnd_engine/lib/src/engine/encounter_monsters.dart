import 'dart:math';

import '../domain/creature.dart';
import '../domain/encounter.dart';
import 'dice.dart';
import 'initiative.dart';

/// Sumar monstruos del bestiario a un encuentro.
///
/// Es una extensión en `engine/` y no un método de [Encounter] porque tira
/// dados, y `domain/` no depende de `engine/`. Vive acá y no en la pantalla
/// porque la suman dos lugares —Combate y el perfil del Bestiario— y la
/// numeración o los PG no pueden salir distintos según desde dónde se sumó.
extension EncounterMonsters on Encounter {
  /// Suma [count] copias de [creature] y devuelve el encuentro resultante.
  ///
  /// Numera sobre lo que **ya está** en la mesa: si hay «Goblin 1» y
  /// «Goblin 2», las nuevas entran como «Goblin 3», «Goblin 4». Un monstruo
  /// solo va sin número; en cuanto hay dos, todos lo llevan, y el que estaba
  /// solo pasa a «Goblin 1». Antes quedaban «Goblin» y «Goblin 2», y el
  /// primero parecía otro bicho. La numeración sigue desde el número más alto
  /// en uso y no desde la cantidad: si se sacó el 1, el nuevo no repite el 2.
  ///
  /// Con [rollHp], cada copia tira sus dados de golpe y ese resultado es
  /// también su máximo: si no, un goblin que sacó 5 se vería «5 / 7» y la
  /// barra arrancaría a media asta. Sin él, todas arrancan con el promedio
  /// del libro, que es lo que corresponde para un jefe. Un perfil sin dados
  /// (invocaciones, compañeros) no tiene nada que tirar y usa el promedio.
  ///
  /// Si el combate ya arrancó, cada copia tira su iniciativa por separado —
  /// nunca la misma para el grupo—. Si todavía se está armando, entra sin
  /// iniciativa: la tirada es de todos juntos al empezar.
  ///
  /// [random] existe para que los tests fijen la semilla.
  Encounter withMonsters(
    Creature creature,
    int count, {
    required String Function() newId,
    CombatantSide side = CombatantSide.enemy,
    bool rollHp = false,
    Random? random,
  }) {
    final rng = random ?? Random();
    final formula =
        rollHp ? DiceFormula.tryParse(creature.hitDice ?? '') : null;
    final dice = Dice(rng);
    final averageHp = creature.resolve(const CreatureVars({})).maxHp;
    final copies = [
      for (final c in combatants)
        if (c.creatureId == creature.id) c,
    ];
    // El número se lee del final del nombre sin exigir que empiece con el de
    // la criatura: ese nombre cambia con el idioma del catálogo, y «Búho 2»,
    // sumado en español, tiene que seguir contando cuando la criatura ya se
    // llama «Owl». Las copias ya son de esta criatura (`creatureId`).
    final numbered = RegExp(r' (\d+)$');
    int? numberOf(Combatant c) => c.name == creature.name
        ? 1
        : int.tryParse(numbered.firstMatch(c.name)?.group(1) ?? '');
    var next = copies.map(numberOf).whereType<int>().fold(0, max) + 1;
    final alone = copies.isEmpty && count == 1;

    // El que estaba solo y sin número pasa a «1», en su lugar de la mesa:
    // `withCombatant` lo mandaría al fondo.
    var encounter = copies.isEmpty
        ? this
        : Encounter(
            id: id,
            round: round,
            turnIndex: turnIndex,
            stage: stage,
            combatants: [
              for (final c in combatants)
                c.creatureId == creature.id && c.name == creature.name
                    ? c.copyWith(name: '${creature.name} 1')
                    : c,
            ],
          );
    for (var i = 0; i < count; i++) {
      final hp = formula?.roll(dice) ?? averageHp;
      encounter = encounter.withCombatant(
        Combatant(
          id: newId(),
          kind: CombatantKind.monster,
          name: alone ? creature.name : '${creature.name} ${next++}',
          initiative:
              encounter.isPreparing ? 0 : rollInitiative(creature, random: rng),
          creatureId: creature.id,
          currentHp: hp,
          maxHp: hp,
          side: side,
        ),
      );
    }
    return encounter;
  }
}
