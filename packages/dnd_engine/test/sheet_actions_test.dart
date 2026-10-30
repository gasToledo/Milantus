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

  test(
      'concentrarse en otro conjuro despide a los compañeros que dependían '
      'de la concentración, y repetir el mismo no', () {
    CombatState combat() => CombatState(
          concentratingOn: 'Hallar corcel',
          companions: [
            CompanionInstance(
              optionId: 'corcel',
              creatureId: 'warhorse',
              concentration: true,
            ),
          ],
        );

    final mismo = act(monje(combat: combat()),
        {'type': 'concentrate', 'spell': 'Hallar corcel'});
    expect(mismo.character.combat.companions, hasLength(1));

    final otro = act(
        monje(combat: combat()), {'type': 'concentrate', 'spell': 'Bendecir'});
    expect(otro.character.combat.concentratingOn, 'Bendecir');
    expect(otro.character.combat.companions, isEmpty);
    expect(otro.outcome['dismissed'], [repo.creature('warhorse')!.name]);

    final fin = act(otro.character, {'type': 'endConcentration'});
    expect(fin.character.combat.concentratingOn, isNull);
  });

  test('la mano secundaria es una sola y se marca por el arma de base', () {
    final c = monje().copyWith(inventory: const [
      InventoryEntry(entryId: 'daga', itemId: 'dagger', equipped: true),
      InventoryEntry(entryId: 'hacha', itemId: 'handaxe', equipped: true),
    ]);

    final daga = act(c, {'type': 'offHand', 'entry': 'daga'}).character;
    expect(daga.weaponOffHand, {'dagger': true});
    final hacha = act(daga, {'type': 'offHand', 'entry': 'hacha'}).character;
    expect(hacha.weaponOffHand, {'handaxe': true});
    expect(
        act(hacha, {'type': 'offHand', 'entry': 'hacha'})
            .character
            .weaponOffHand,
        isEmpty);
  });

  test('cantidad, cargas y monedas escritas a mano no se salen de rango', () {
    final max = repo.item('baston-de-curacion')!.maxCharges!;
    final c = monje().copyWith(inventory: const [
      InventoryEntry(entryId: 'baston', itemId: 'baston-de-curacion'),
    ]);
    InventoryEntry baston(Map<String, dynamic> a) =>
        act(c, {...a, 'entry': 'baston'}).character.inventory.single;

    expect(baston({'type': 'setQuantity', 'value': 0}).quantity, 1);
    expect(baston({'type': 'setCharges', 'value': max + 3}).charges, max);
    expect(baston({'type': 'setCharges', 'value': -1}).charges, 0);
    expect(
      act(c, {
        'type': 'setCoins',
        'coins': {'gp': 12, 'sp': 0, 'cp': -2},
      }).character.coins,
      {'gp': 12},
    );
  });

  test('comprar sin fondos devuelve la ficha intacta y lo dice', () {
    final c = monje().copyWith(coins: const {'cp': 1});

    final r = act(c, {
      'type': 'buy',
      'item': 'dagger',
      'quantity': 1,
      'unitPriceCp': 200,
      'at': '2026-10-30',
    });

    expect(r.outcome['paid'], isFalse);
    expect(r.character.toJson(), c.toJson());
  });

  test('una acción desconocida no devuelve una ficha', () {
    expect(
      () => act(monje(), {'type': 'fly'}),
      throwsFormatException,
    );
  });
}
