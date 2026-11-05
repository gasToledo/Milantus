import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  late Creature goblin;
  late Creature aboleth;
  late Creature spirit;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    goblin = repo.creature('goblin-warrior')!;
    aboleth = repo.creature('aboleth')!;
    spirit = repo.creature('construct-spirit-clay')!;
  });

  Combatant monster(String id, Creature c, CombatantSide side) => Combatant(
        id: id,
        kind: CombatantKind.monster,
        name: c.name,
        initiative: 0,
        creatureId: c.id,
        currentHp: 5,
        maxHp: 5,
        side: side,
      );

  Combatant npcOf(String id, Npc npc, {int hp = 5, CombatantSide? side}) =>
      Combatant(
        id: id,
        kind: CombatantKind.npc,
        name: npc.name,
        initiative: 0,
        npcId: npc.id,
        currentHp: hp,
        maxHp: hp,
        side: side,
      );

  Map<String, dynamic> row(Map<String, dynamic> d, String id) =>
      (d['rows'] as List).cast<Map<String, dynamic>>().firstWhere(
            (r) => r['id'] == id,
          );

  group('encounterDetails', () {
    final sagan = demoSagan();
    final allyNpc = Npc(
      id: 'aliada',
      name: 'Aliada',
      sheetKind: NpcSheetKind.character,
    );
    final enemyNpc = Npc(
      id: 'rival',
      name: 'Rival',
      sheetKind: NpcSheetKind.character,
    );
    // El catálogo recién existe en setUpAll, que corre después de armar el
    // grupo.
    late Npc blockNpc;
    late Map<String, EncounterNpc> npcs;
    setUpAll(() {
      blockNpc = Npc(
        id: 'bloque',
        name: 'Bloque',
        sheetKind: NpcSheetKind.block,
        block: aboleth,
      );
      npcs = {
        allyNpc.id: EncounterNpc(npc: allyNpc, sheet: sagan, status: 'alive'),
        enemyNpc.id: EncounterNpc(npc: enemyNpc, sheet: sagan, status: 'alive'),
        blockNpc.id: EncounterNpc(npc: blockNpc, status: 'alive'),
      };
    });
    final members = {'m1': (level: 5, armorClass: 17)};

    Encounter table() => Encounter(
          id: 'e',
          combatants: [
            const Combatant(
              id: 'p',
              kind: CombatantKind.player,
              name: 'Ana',
              initiative: 0,
              memberId: 'm1',
            ),
            npcOf('a', allyNpc, side: CombatantSide.ally),
            npcOf('r', enemyNpc, side: CombatantSide.enemy),
            monster('g', goblin, CombatantSide.enemy),
            monster('n', goblin, CombatantSide.neutral),
            npcOf('b', blockNpc, side: CombatantSide.enemy),
          ],
        );

    test('la dificultad es la de encounterDifficulty con esos insumos', () {
      final saganLevel = sagan.totalLevel;
      final expected = encounterDifficulty(
        partyLevels: [5, saganLevel],
        enemyCrs: [goblin.cr, aboleth.cr],
        enemyLevels: [saganLevel],
      );
      final d = encounterDetails(
        table(),
        members: members,
        npcs: npcs,
        repo: repo,
      )['difficulty'] as Map<String, dynamic>;
      expect(d['lowBudget'], expected.lowBudget);
      expect(d['highBudget'], expected.highBudget);
      expect(d['enemyXp'], expected.enemyXp);
      expect(d['enemyCharacters'], 1);
      expect(d['characters'], expected.characters);
      expect(d['tier'], expected.tier?.name);
    });

    test('filas: xp, legendarias y línea de monstruo', () {
      final d = encounterDetails(
        table(),
        members: members,
        npcs: npcs,
        repo: repo,
      );
      expect(row(d, 'n')['xp'], isNull);
      expect(row(d, 'p')['xp'], isNull);
      expect(row(d, 'g')['xp'], xpForChallengeRating(goblin.cr!));
      expect(row(d, 'b')['legendaryActions'], aboleth.legendaryActionsPerRound);
      expect(row(d, 'g')['legendaryActions'], 0);
      expect(row(d, 'g')['monsterLine'], isNotNull);
      expect(row(d, 'b')['monsterLine'], isNull);
      expect(row(d, 'p')['ac'], '17');
    });

    test('acTotal suma el bono con CA numérica y es null con 13+spellLevel',
        () {
      expect(spirit.ac, contains('spellLevel'));
      final e = Encounter(
        id: 'e',
        combatants: [
          monster('g', goblin, CombatantSide.enemy).copyWith(acBonus: 2),
          monster('s', spirit, CombatantSide.ally),
        ],
      );
      final d = encounterDetails(e, members: {}, npcs: {}, repo: repo);
      final goblinAc =
          int.parse(RegExp(r'^\d+').firstMatch(goblin.ac)!.group(0)!);
      expect(row(d, 'g')['acTotal'], goblinAc + 2);
      expect(row(d, 's')['acTotal'], isNull);
      expect(row(d, 's')['ac'], spirit.ac);
    });
  });

  test('sugerencias de iniciativa', () {
    final sagan = demoSagan();
    final withSheet = Npc(
      id: 'ficha',
      name: 'Ficha',
      sheetKind: NpcSheetKind.character,
    );
    final npcs = {
      withSheet.id: EncounterNpc(npc: withSheet, sheet: sagan, status: 'alive'),
    };
    final e = Encounter(
      id: 'e',
      combatants: [
        const Combatant(
          id: 'p',
          kind: CombatantKind.player,
          name: 'Ana',
          initiative: 0,
          memberId: 'm1',
        ),
        monster('g', goblin, CombatantSide.enemy),
        npcOf('f', withSheet),
      ],
    );
    final mod = goblin.initiativeModifier;
    final sheetMod = CharacterCompiler(repo).compile(sagan).initiative;
    for (var seed = 0; seed < 30; seed++) {
      final s = suggestInitiatives(
        e,
        npcs: npcs,
        repo: repo,
        random: Random(seed),
      );
      expect(s.containsKey('p'), isFalse);
      expect(s['g'], inInclusiveRange(1 + mod, 20 + mod));
      expect(s['f'], inInclusiveRange(1 + sheetMod, 20 + sheetMod));
    }
  });
}
