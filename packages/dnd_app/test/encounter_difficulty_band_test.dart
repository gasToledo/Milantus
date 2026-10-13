import 'package:dnd_app/api/api_models.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/dm/encounter_difficulty_band.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/localized_app.dart';

/// La banda de dificultad del combate que se arma: de dónde saca cada número
/// (la regla en sí está probada en el motor) y que entre en cualquier ancho.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Character character(String id, int level) => Character(
    id: id,
    name: id,
    raceId: 'human',
    classId: 'fighter',
    backgroundId: 'soldier',
    level: level,
    assignedScores: {for (final a in Ability.values) a: 12},
    hpPerLevel: List.filled(level, 6),
  );

  CampaignMember member(String id, int level) =>
      CampaignMember(memberId: 'm-$id', character: character(id, level));

  Combatant player(String id) => Combatant(
    id: 'c-$id',
    kind: CombatantKind.player,
    name: id,
    initiative: 0,
    memberId: 'm-$id',
  );

  Combatant monster(String id, String creatureId, {CombatantSide? side}) =>
      Combatant(
        id: id,
        kind: CombatantKind.monster,
        name: id,
        initiative: 0,
        creatureId: creatureId,
        maxHp: 10,
        currentHp: 10,
        side: side,
      );

  Combatant npcCombatant(String npcId, CombatantSide side) => Combatant(
    id: 'c-$npcId',
    kind: CombatantKind.npc,
    name: npcId,
    initiative: 0,
    npcId: npcId,
    maxHp: 10,
    currentHp: 10,
    side: side,
  );

  const ids = ['a', 'b', 'c', 'd'];
  final party = [for (final id in ids) member(id, 3)];
  final players = [for (final id in ids) player(id)];

  EncounterDifficulty of(
    List<Combatant> combatants, {
    List<CampaignNpcEntry> npcs = const [],
  }) => encounterDifficultyOf(
    Encounter(id: 'e', combatants: combatants),
    members: party,
    npcs: npcs,
    repo: repo,
  );

  int xp(String creatureId) =>
      xpForChallengeRating(repo.creature(creatureId)!.cr!);

  test('cuenta a los que entraron al combate, no a la mesa entera', () {
    final d = of([players[0], players[1], monster('g', 'goblin-warrior')]);
    expect(d.characters, 2);
    expect(d.enemyXp, xp('goblin-warrior'));
  });

  test('un monstruo aliado resta sus PX y uno neutral no cuenta', () {
    final d = of([
      ...players,
      monster('o1', 'ogre'),
      monster('o2', 'ogre'),
      monster('lobo', 'wolf', side: CombatantSide.ally),
      monster('testigo', 'ogre', side: CombatantSide.neutral),
    ]);
    expect(d.enemies, 2);
    expect(d.enemyXp, xp('ogre') * 2);
    expect(d.allyXp, xp('wolf'));
  });

  test('un PNJ aliado con ficha suma su nivel al presupuesto; como enemigo '
      'queda fuera de la cuenta', () {
    final villano = CampaignNpcEntry(
      npc: Npc(
        id: 'v',
        name: 'Villano',
        sheetKind: NpcSheetKind.character,
        characterId: 'v',
      ),
      status: NpcStatus.alive,
      sheet: character('v', 20),
    );
    final solos = of([...players, monster('g', 'goblin-warrior')]);

    final aliado = of(
      [
        ...players,
        monster('g', 'goblin-warrior'),
        npcCombatant('v', CombatantSide.ally),
      ],
      npcs: [villano],
    );
    expect(aliado.characters, 5);
    expect(aliado.highestLevel, 20);
    expect(aliado.lowBudget, greaterThan(solos.lowBudget));

    final enemigo = of(
      [...players, npcCombatant('v', CombatantSide.enemy)],
      npcs: [villano],
    );
    expect(enemigo.characters, 4);
    expect(enemigo.enemies, 1);
    expect(enemigo.uncountedEnemies, 1);
    expect(enemigo.enemyXp, 0);
  });

  test('el VD de un PNJ sale de su bloque, no de la criatura de la que se '
      'copió', () {
    final ogre = repo.creature('ogre')!;
    final crecido = Creature.fromJson({...ogre.toJson(), 'cr': 5});
    final entry = CampaignNpcEntry(
      npc: Npc(
        id: 'n',
        name: 'Grum',
        sheetKind: NpcSheetKind.block,
        block: crecido,
        baseCreatureId: ogre.id,
      ),
      status: NpcStatus.alive,
    );
    final d = of(
      [...players, npcCombatant('n', CombatantSide.enemy)],
      npcs: [entry],
    );
    expect(d.enemyXp, xpForChallengeRating(5));
    expect(d.enemyXp, isNot(xp('ogre')));
  });

  group('en pantalla', () {
    Future<void> pumpBand(
      WidgetTester tester,
      EncounterDifficulty difficulty, {
      double width = 1000,
      Locale locale = const Locale('es'),
    }) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          locale: locale,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: EncounterDifficultyBand(difficulty: difficulty),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dice la dificultad, la mesa y el aviso de muchas criaturas', (
      tester,
    ) async {
      // Nueve goblins contra cuatro de nivel 3: entra en el presupuesto bajo,
      // y son más de dos enemigos por personaje.
      final d = of([
        ...players,
        for (var i = 0; i < 9; i++) monster('g$i', 'goblin-warrior'),
      ]);
      expect(d.tier, EncounterTier.low);
      await pumpBand(tester, d);

      expect(find.text('Baja'), findsNWidgets(2)); // el veredicto y su techo
      expect(find.text('4 personajes de nivel 3'), findsOneWidget);
      expect(find.text('PX DE ENEMIGOS'), findsOneWidget);
      expect(
        find.textContaining('Muchas criaturas.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Criatura poderosa.', findRichText: true),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('con aliados rotula el neto y muestra la resta', (
      tester,
    ) async {
      final d = of([
        ...players,
        monster('o', 'ogre'),
        monster('lobo', 'wolf', side: CombatantSide.ally),
      ]);
      await pumpBand(tester, d);

      expect(find.text('PX NETOS'), findsOneWidget);
      expect(find.text('${d.netXp}'), findsOneWidget);
      expect(
        find.text('${d.enemyXp} de enemigos − ${d.allyXp} de aliados'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin jugadores pide sumarlos y no inventa un veredicto', (
      tester,
    ) async {
      final d = of([monster('g', 'goblin-warrior')]);
      await pumpBand(tester, d);

      expect(find.textContaining('Sumá a los jugadores'), findsOneWidget);
      for (final nombre in ['Baja', 'Moderada', 'Alta', 'Extrema']) {
        expect(find.text(nombre), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('una criatura de VD mayor que el nivel más bajo avisa', (
      tester,
    ) async {
      final troll = repo.creature('troll')!;
      final d = of([...players, monster('t', 'troll')]);
      expect(d.powerfulCr, troll.cr);
      await pumpBand(tester, d);

      expect(
        find.textContaining(
          'VD ${troll.cr}, por encima del nivel más bajo de la mesa (3)',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    // A nivel 1 los techos moderado y alto quedan a un 20 % de la regla: es
    // el caso que hacía pisarse los rótulos.
    testWidgets('entra en un teléfono, también en inglés y a nivel 1', (
      tester,
    ) async {
      final d = encounterDifficulty(
        partyLevels: [1, 1, 1, 1],
        enemyCrs: [...List.filled(9, 0.125), 2, null],
      );
      for (final width in [320.0, 390.0, 700.0]) {
        for (final locale in const [Locale('es'), Locale('en')]) {
          await pumpBand(tester, d, width: width, locale: locale);
          expect(tester.takeException(), isNull, reason: '$width $locale');
        }
      }
      expect(find.text('Extreme'), findsOneWidget);
    });
  });
}
