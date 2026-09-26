import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  late Creature goblin;
  // Los PG del libro, derivados del catálogo y no escritos a mano.
  late int goblinHp;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    goblin = repo.creature('goblin-warrior')!;
    goblinHp = goblin.resolve(const CreatureVars({})).maxHp;
  });

  var counter = 0;
  String newId() => 'c-${counter++}';

  group('withMonsters', () {
    test('numera sobre lo que ya está en la mesa', () {
      final two =
          const Encounter(id: 'e').withMonsters(goblin, 2, newId: newId);
      final four = two.withMonsters(goblin, 2, newId: newId);

      // Todos con número: antes el primero quedaba «Goblin» a secas y
      // parecía otro bicho.
      expect(four.combatants.map((c) => c.name), [
        '${goblin.name} 1',
        '${goblin.name} 2',
        '${goblin.name} 3',
        '${goblin.name} 4',
      ]);
      expect(four.combatants.map((c) => c.id).toSet(), hasLength(4));
    });

    test('uno solo va sin número, y al sumar otro pasa a ser el 1', () {
      final one =
          const Encounter(id: 'e').withMonsters(goblin, 1, newId: newId);
      expect(one.combatants.single.name, goblin.name);

      final firstId = one.combatants.single.id;
      final two = one.withMonsters(goblin, 1, newId: newId);
      expect(two.combatants.map((c) => c.name), [
        '${goblin.name} 1',
        '${goblin.name} 2',
      ]);
      // Es el mismo combatiente, renombrado en su lugar: no uno nuevo.
      expect(two.combatants.first.id, firstId);
    });

    test('sigue desde el número más alto y no repite uno en uso', () {
      final three =
          const Encounter(id: 'e').withMonsters(goblin, 3, newId: newId);
      // Se va el 1: quedan el 2 y el 3.
      final withoutFirst = Encounter(
        id: 'e',
        combatants: three.combatants.skip(1).toList(),
      );
      final next = withoutFirst.withMonsters(goblin, 1, newId: newId);
      expect(next.combatants.map((c) => c.name), [
        '${goblin.name} 2',
        '${goblin.name} 3',
        '${goblin.name} 4',
      ]);
    });

    test('sin tirar, todas las copias arrancan con el promedio del libro', () {
      final e = const Encounter(id: 'e').withMonsters(goblin, 3, newId: newId);

      for (final c in e.combatants) {
        expect(c.currentHp, goblinHp);
        expect(c.maxHp, goblinHp);
      }
    });

    test('tirando, cada copia tira sus dados y ese es su máximo', () {
      final formula = DiceFormula.tryParse(goblin.hitDice!)!;
      final e = const Encounter(id: 'e').withMonsters(
        goblin,
        6,
        newId: newId,
        rollHp: true,
        random: Random(7),
      );

      final hps = [for (final c in e.combatants) c.maxHp];
      expect(hps.toSet().length, greaterThan(1));
      for (final c in e.combatants) {
        expect(c.currentHp, c.maxHp);
        expect(
          c.maxHp,
          inInclusiveRange(
            max(1, formula.count + formula.modifier),
            formula.count * formula.sides + formula.modifier,
          ),
        );
      }
    });

    test('en preparación entran sin iniciativa y como enemigos', () {
      final e = const Encounter(id: 'e').withMonsters(goblin, 2, newId: newId);

      expect(e.isPreparing, isTrue);
      expect(e.combatants.map((c) => c.initiative), [0, 0]);
      expect(
          e.combatants.map((c) => c.side), everyElement(CombatantSide.enemy));
      expect(e.combatants.map((c) => c.creatureId), everyElement(goblin.id));
    });

    test('en curso cada copia tira su propia iniciativa', () {
      final e =
          const Encounter(id: 'e', stage: EncounterStage.running).withMonsters(
        goblin,
        6,
        newId: newId,
        side: CombatantSide.ally,
        random: Random(3),
      );

      final mod = goblin.initiativeModifier;
      for (final c in e.combatants) {
        expect(c.initiative, inInclusiveRange(1 + mod, 20 + mod));
        expect(c.side, CombatantSide.ally);
      }
      expect(
          e.combatants.map((c) => c.initiative).toSet().length, greaterThan(1));
    });
  });
}
