import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  test('toda clase y trasfondo tiene opciones y referencias resolubles', () {
    final sources = <StartingEquipmentOption>[
      for (final value in repo.classes.values) ...value.startingEquipment,
      for (final value in repo.backgrounds.values) ...value.startingEquipment,
    ];
    expect(repo.classes.values.every((e) => e.startingEquipment.isNotEmpty),
        isTrue);
    expect(
      repo.backgrounds.values.every((e) => e.startingEquipment.isNotEmpty),
      isTrue,
    );
    for (final option in sources) {
      expect(option.grants, isNotEmpty, reason: option.label);
      for (final grant in option.grants) {
        if (grant.itemId != null) {
          expect(repo.catalogEntry(grant.itemId!), isNotNull,
              reason: '${option.label}: ${grant.itemId}');
        }
        for (final id in grant.chooseFromItemIds) {
          expect(repo.catalogEntry(id), isNotNull,
              reason: '${option.label}: $id');
        }
      }
    }
  });

  test('Guerrero conserva sus tres alternativas', () {
    final fighter = repo.characterClass('fighter')!;
    expect(fighter.startingEquipment.map((e) => e.id), ['A', 'B', 'C']);
    expect(fighter.startingEquipment.last.grants.single.coins, {'gp': 155});
  });

  test('las alternativas monetarias no agregan objetos', () {
    final sources = [
      for (final value in repo.classes.values)
        (name: value.name, options: value.startingEquipment),
      for (final value in repo.backgrounds.values)
        (name: value.name, options: value.startingEquipment),
    ];
    for (final source in sources) {
      final option = source.options.last;
      if (option.grants.any((e) => e.coins.isNotEmpty)) {
        expect(
            option.grants.every((e) => e.itemId == null && !e.isChoice), isTrue,
            reason: source.name);
      }
    }
  });
}
