import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  group('Creature.legendaryResistancesPerDay', () {
    test('toda criatura con el rasgo tiene un número, y ninguna otra', () {
      for (final c in repo.creatures.values) {
        final has =
            c.traits.any((t) => t.name.startsWith('Resistencia legendaria'));
        expect(c.legendaryResistancesPerDay != null, has, reason: c.id);
      }
    });

    test('lee el número base e ignora la guarida', () {
      expect(repo.creature('tarrasque')!.legendaryResistancesPerDay, 6);
      const lair = Creature(
        id: 'x',
        name: 'X',
        source: ContentSource.homebrew,
        ac: '10',
        hp: '10',
        traits: [
          CreatureTrait(
            name: 'Legendary Resistance (3/Day, or 4/Day in Lair)',
            description: '',
          ),
        ],
      );
      expect(lair.legendaryResistancesPerDay, 3);
    });
  });

  group('Contadores legendarios en el encuentro', () {
    Encounter mesa() => const Encounter(
          id: 'e',
          stage: EncounterStage.running,
          combatants: [
            Combatant(
              id: 'dragon',
              kind: CombatantKind.monster,
              name: 'Dragón',
              initiative: 20,
              maxHp: 10,
              currentHp: 10,
            ),
            Combatant(
              id: 'aria',
              kind: CombatantKind.player,
              name: 'Aria',
              initiative: 10,
            ),
          ],
        );

    test('sobreviven el round-trip y no se escriben en cero', () {
      final e = mesa().withLegendarySpent('dragon', actions: 2, resistances: 1);
      final r = Encounter.fromJson(e.toJson());
      expect(r.combatants.first.legendaryActionsSpent, 2);
      expect(r.combatants.first.legendaryResistancesSpent, 1);
      expect(
        mesa().toJson()['combatants'][0],
        isNot(contains('legendaryActionsSpent')),
      );
    });

    test('nunca bajan de cero', () {
      final e = mesa().withLegendarySpent('dragon', actions: -1);
      expect(e.combatants.first.legendaryActionsSpent, 0);
    });

    test('las acciones vuelven al empezar su turno; las resistencias no', () {
      // Turno del dragón → gasta en el turno de Aria → vuelve a él.
      final enAria = mesa().next().withLegendarySpent(
            'dragon',
            actions: 3,
            resistances: 2,
          );
      expect(enAria.combatants.first.legendaryActionsSpent, 3);

      final deVuelta = enAria.next();
      expect(deVuelta.current!.id, 'dragon');
      expect(deVuelta.combatants.first.legendaryActionsSpent, 0);
      expect(deVuelta.combatants.first.legendaryResistancesSpent, 2);
    });
  });
}
