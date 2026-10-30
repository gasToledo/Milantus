import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

const _scores = {
  Ability.strength: 10,
  Ability.dexterity: 14,
  Ability.constitution: 14,
  Ability.intelligence: 10,
  Ability.wisdom: 16,
  Ability.charisma: 16,
};

void main() {
  late ContentRepository repo;
  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character monje({CombatState? combat}) => Character(
        id: 'monje',
        name: 'Monje',
        raceId: 'human',
        classId: 'monk',
        backgroundId: 'sage',
        level: 6,
        assignedScores: _scores,
        hpPerLevel: List.filled(6, 5),
        combat: combat,
      );

  SheetActionResult act(Character c, Map<String, dynamic> action) =>
      SheetActions.apply(c, repo, action, dice: Dice(Random(7)));

  test('la acción no toca la ficha de entrada y la nueva se relee igual', () {
    final c = monje(combat: CombatState(currentHp: 20, tempHp: 3));

    final r = act(c, {'type': 'damage', 'amount': 5});

    expect(c.combat.currentHp, 20);
    expect(c.combat.tempHp, 3);
    expect(r.character.combat.currentHp, 18);
    expect(r.character.combat.tempHp, 0);
    final json = r.character.toJson();
    expect(json['schemaVersion'], Character.currentSchemaVersion);
    expect(Character.fromJson(json).toJson(), json);
  });

  test('gastar o recuperar de una reserva no se sale de cero y el máximo', () {
    final c = monje();
    final focus = CharacterCompiler(repo)
        .compile(c)
        .resources
        .firstWhere((r) => r.id == 'focus_points');

    final gastado = act(c, {
      'type': 'spendResource',
      'resource': focus.key,
      'amount': focus.max + 5,
    }).character;
    expect(gastado.combat.resourceUsage[focus.key], focus.max);

    final recuperado = act(gastado, {
      'type': 'recoverResource',
      'resource': focus.key,
      'amount': focus.max + 5,
    }).character;
    expect(recuperado.combat.resourceUsage[focus.key], 0);
  });

  test('el espacio de pacto se gasta de su tabla y no pasa del máximo', () {
    final brujo = Character(
      id: 'brujo',
      name: 'Brujo',
      raceId: 'human',
      classId: 'warlock',
      backgroundId: 'sage',
      level: 3,
      assignedScores: _scores,
      hpPerLevel: const [8, 5, 5],
    );
    final pacto = CharacterCompiler(repo).compile(brujo).pactSlotsByLevel;
    final nivel = pacto.keys.single;

    var c = brujo;
    for (var i = 0; i <= pacto[nivel]!; i++) {
      c = act(c, {'type': 'spendSlot', 'level': nivel, 'pact': true}).character;
    }

    expect(c.combat.pactSlotsUsed[nivel], pacto[nivel]);
    expect(c.combat.spellSlotsUsed, isEmpty);
  });

  test('el descanso largo cura, baja el cansancio y recarga los objetos', () {
    final c = Character(
      id: 'guerrera',
      name: 'Guerrera',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      level: 2,
      assignedScores: _scores,
      hpPerLevel: const [10, 6],
      inventory: const [
        InventoryEntry(
          entryId: 'baston',
          itemId: 'baston-de-curacion',
          charges: 9,
        ),
      ],
      combat: CombatState(currentHp: 1, exhaustion: 2),
    );
    final sheet = CharacterCompiler(repo).compile(c);

    final r = act(c, {'type': 'longRest'});

    expect(r.character.combat.currentHp, sheet.maxHp);
    expect(r.character.inventory.single.charges,
        repo.item('baston-de-curacion')!.maxCharges);
    expect(r.outcome, {
      'exhaustion': 1,
      // El humano la gana al descansar (Ingenioso).
      'inspirationGained': sheet.heroicInspirationOnLongRest,
      'itemsRecharged': 1,
    });
  });

  test('una acción desconocida no devuelve una ficha', () {
    expect(
      () => act(monje(), {'type': 'fly'}),
      throwsFormatException,
    );
  });
}
