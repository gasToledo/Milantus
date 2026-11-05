import 'dart:convert';
import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  late Creature goblin;
  late int goblinHp;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    goblin = repo.creature('goblin-warrior')!;
    goblinHp = goblin.resolve(const CreatureVars({})).maxHp;
  });

  var counter = 0;
  String newId(String prefix) => '$prefix-${counter++}';

  Encounter? act(Encounter? e, Map<String, dynamic> action) =>
      EncounterActions.apply(e, repo, action, newId: newId);

  Encounter withGoblin() =>
      act(null, {'type': 'addMonsters', 'creatureId': goblin.id, 'count': 1})!;

  Map<String, dynamic> npcEntry(Npc npc, {String? status, int? currentHp}) => {
        'npc': npc.toJson(),
        if (status != null) 'status': status,
        if (currentHp != null) 'currentHp': currentHp,
      };

  Npc blockNpc(String id) => Npc(
        id: id,
        name: 'Garrick',
        sheetKind: NpcSheetKind.block,
        block: goblin,
      );

  group('PG temporales y daño', () {
    test('el daño gasta primero los temporales, la cura no los devuelve', () {
      var e = withGoblin();
      final id = e.combatants.single.id;
      e = act(e, {'type': 'setTempHp', 'combatantId': id, 'value': 5})!;

      e = act(e, {'type': 'adjustHp', 'combatantId': id, 'delta': -8})!;
      expect(e.combatants.single.tempHp, 0);
      expect(e.combatants.single.currentHp, goblinHp - 3);

      e = act(e, {'type': 'adjustHp', 'combatantId': id, 'delta': 1})!;
      expect(e.combatants.single.tempHp, 0);
      expect(e.combatants.single.currentHp, goblinHp - 2);

      e = act(e, {'type': 'adjustHp', 'combatantId': id, 'delta': 999})!;
      expect(e.combatants.single.currentHp, goblinHp);
      e = act(e, {'type': 'adjustHp', 'combatantId': id, 'delta': -999})!;
      expect(e.combatants.single.currentHp, 0);
    });

    test('un jugador y un PNJ sin estadísticas no tienen PG que tocar', () {
      var e = act(null, {
        'type': 'addPlayer',
        'memberId': 'm1',
        'name': 'Ana',
        'initiative': 10,
      })!;
      final npc = Npc(id: 'odile', name: 'Odile', sheetKind: NpcSheetKind.none);
      e = act(e, {'type': 'addNpc', 'entry': npcEntry(npc), 'initiative': 5})!;
      for (final c in e.combatants) {
        for (final action in [
          {'type': 'adjustHp', 'delta': -3},
          {'type': 'setTempHp', 'value': 4},
        ]) {
          expect(act(e, {...action, 'combatantId': c.id}), isNull);
        }
      }
    });
  });

  test('corregir la iniciativa reordena y el turno sigue en quien lo tenía',
      () {
    var e = act(null, {
      'type': 'addPlayer',
      'memberId': 'a',
      'name': 'A',
      'initiative': 0,
    })!;
    e = act(e, {
      'type': 'addPlayer',
      'memberId': 'b',
      'name': 'B',
      'initiative': 0,
    })!;
    final ids = e.combatants.map((c) => c.id).toList();
    e = act(e, {
      'type': 'start',
      'initiatives': {ids[0]: 20, ids[1]: 10},
    })!;
    e = act(e, {'type': 'next'})!;
    expect(e.current!.id, ids[1]);

    e = act(
        e, {'type': 'setInitiative', 'combatantId': ids[1], 'initiative': 30})!;
    expect(e.combatants.first.id, ids[1]);
    expect(e.current!.id, ids[1]);
    expect(
      act(e,
          {'type': 'setInitiative', 'combatantId': ids[1], 'initiative': 30}),
      isNull,
    );
  });

  test('setSide sin bando o con uno desconocido no guarda nada', () {
    final e = withGoblin();
    final id = e.combatants.single.id;
    expect(act(e, {'type': 'setSide', 'combatantId': id}), isNull);
    expect(
      act(e, {'type': 'setSide', 'combatantId': id, 'side': 'otro'}),
      isNull,
    );
    final ally =
        act(e, {'type': 'setSide', 'combatantId': id, 'side': 'ally'})!;
    expect(ally.combatants.single.side, CombatantSide.ally);
  });

  test('un jugador y un PNJ no entran dos veces', () {
    final player = {
      'type': 'addPlayer',
      'memberId': 'm1',
      'name': 'Ana',
      'initiative': 10,
    };
    final npc = {
      'type': 'addNpc',
      'entry': npcEntry(blockNpc('n1')),
      'initiative': 5,
      'side': 'enemy',
    };
    var e = act(act(null, player), npc)!;
    expect(act(e, player), isNull);
    expect(act(e, npc), isNull);
  });

  group('addNpc', () {
    int maxHpOf(Npc npc) => NpcStats.of(npc, null, repo).maxHp;

    Combatant added(Map<String, dynamic> entry, {bool revive = false}) =>
        act(null, {
          'type': 'addNpc',
          'entry': entry,
          'initiative': 0,
          'side': 'ally',
          'revive': revive,
        })!
            .combatants
            .single;

    test('el herido entra herido; biblioteca y revive, entero', () {
      final npc = blockNpc('n1');
      final max = maxHpOf(npc);
      expect(
        added(npcEntry(npc, status: 'alive', currentHp: 2)).currentHp,
        2,
      );
      expect(added(npcEntry(npc)).currentHp, max);
      expect(
        added(npcEntry(npc, status: 'dead', currentHp: 2), revive: true)
            .currentHp,
        max,
      );
    });

    test('sin estadísticas es neutral aunque se pida otro bando', () {
      final c = added(
        npcEntry(
          Npc(id: 'odile', name: 'Odile', sheetKind: NpcSheetKind.none),
        ),
      );
      expect(c.side, CombatantSide.neutral);
    });

    test('sin bando y con PG lanza', () {
      expect(
        () => act(null, {
          'type': 'addNpc',
          'entry': npcEntry(blockNpc('n1')),
          'initiative': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('sin combate', () {
    test('open y los add lo crean en preparación, el resto devuelve null', () {
      expect(act(null, {'type': 'open'})!.isPreparing, isTrue);
      expect(withGoblin().isPreparing, isTrue);
      for (final type in ['next', 'start']) {
        expect(
          act(null, {'type': type, 'initiatives': <String, int>{}}),
          isNull,
        );
      }
      for (final type in ['remove', 'setTags', 'adjustHp', 'setAcBonus']) {
        expect(
          act(null, {
            'type': type,
            'combatantId': 'x',
            'tags': <String>[],
            'delta': 1,
            'value': 1,
          }),
          isNull,
        );
      }
    });

    test('open con un combate abierto devuelve null', () {
      expect(act(withGoblin(), {'type': 'open'}), isNull);
    });
  });

  test('una acción desconocida o una criatura inexistente lanzan', () {
    expect(() => act(null, {'type': 'nope'}), throwsFormatException);
    expect(
      () => act(null, {
        'type': 'addMonsters',
        'creatureId': 'no-existe',
        'count': 1,
      }),
      throwsFormatException,
    );
  });

  test(
      'ventaja, temporales y bono de CA sobreviven a un golpe, a next y a JSON',
      () {
    var e = act(null, {
      'type': 'addMonsters',
      'creatureId': goblin.id,
      'count': 2,
    })!;
    final id = e.combatants.first.id;
    e = act(e, {'type': 'setTempHp', 'combatantId': id, 'value': 4})!;
    e = act(e, {'type': 'setAcBonus', 'combatantId': id, 'value': 2})!;
    e = act(e, {
      'type': 'setAdvantage',
      'combatantId': id,
      'advantage': 'disadvantage',
    })!;
    e = act(e, {
      'type': 'setTags',
      'combatantId': id,
      'tags': ['x']
    })!;
    e = act(e, {
      'type': 'start',
      'initiatives': {for (final c in e.combatants) c.id: 10},
    })!;
    e = act(e, {'type': 'next'})!;
    e = act(e, {'type': 'adjustHp', 'combatantId': id, 'delta': -1})!;
    e = Encounter.fromJson(jsonDecode(jsonEncode(e.toJson())));

    final c = e.combatants.firstWhere((c) => c.id == id);
    expect(c.advantage, CombatantAdvantage.disadvantage);
    expect(c.tempHp, 3);
    expect(c.acBonus, 2);

    e = act(e, {'type': 'setAdvantage', 'combatantId': id, 'advantage': null})!;
    expect(
      e.combatants
          .firstWhere((c) => c.id == id)
          .toJson()
          .containsKey('advantage'),
      isFalse,
    );
  });

  test('con semilla las tiradas son repetibles', () {
    Encounter roll() => EncounterActions.apply(
          null,
          repo,
          {
            'type': 'addMonsters',
            'creatureId': goblin.id,
            'count': 3,
            'rollHp': true,
          },
          newId: newId,
          random: Random(7),
        )!;
    expect(
      roll().combatants.map((c) => c.maxHp),
      roll().combatants.map((c) => c.maxHp),
    );
  });
}
