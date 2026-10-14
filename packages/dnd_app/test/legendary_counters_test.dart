import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/dm/dm_mode_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';
import 'fakes/localized_app.dart';

/// Los contadores legendarios en la planilla del DM: se tachan tocándolos y
/// las acciones vuelven solas al empezar el turno de la criatura.
void main() {
  late ContentRepository repo;
  late Creature dragon;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
    dragon = repo.creature('adult-red-dragon')!;
  });

  Future<FakeApiServer> pumpCombate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hp = dragon.resolve(const CreatureVars({})).maxHp;
    final server = FakeApiServer();
    server.campaigns['tumba'] = const Campaign(id: 'tumba', name: 'La Tumba');
    server.encounters['tumba'] = Encounter(
      id: 'e',
      stage: EncounterStage.running,
      combatants: [
        Combatant(
          id: 'd',
          kind: CombatantKind.monster,
          name: dragon.name,
          initiative: 20,
          creatureId: dragon.id,
          currentHp: hp,
          maxHp: hp,
        ),
        const Combatant(
          id: 'p',
          kind: CombatantKind.player,
          name: 'Sagan',
          initiative: 10,
        ),
      ],
    );
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: DmModeScreen(
          api: ApiClient(client: server.client),
          repo: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combate'));
    await tester.pumpAndSettle();
    return server;
  }

  Combatant dragonIn(FakeApiServer server) =>
      server.encounters['tumba']!.combatants.firstWhere((c) => c.id == 'd');

  testWidgets('una marca por uso, con los máximos del perfil', (tester) async {
    await pumpCombate(tester);

    final actions = dragon.legendaryActionsPerRound!;
    final resistances = dragon.legendaryResistancesPerDay!;
    expect(
      find.byTooltip('Acciones legendarias: $actions de $actions'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Resistencias legendarias: $resistances de $resistances'),
      findsOneWidget,
    );
    // El jugador no tiene perfil: ninguna marca de más.
    expect(
      find.byTooltip('Acciones legendarias: ${actions + 1} de $actions'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tachar se guarda, y las acciones vuelven en su turno', (
    tester,
  ) async {
    final server = await pumpCombate(tester);
    final actions = dragon.legendaryActionsPerRound!;
    final resistances = dragon.legendaryResistancesPerDay!;

    // El turno es del dragón: se pasa al jugador, que es cuando se gastan.
    await tester.tap(find.text('Siguiente turno'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones legendarias: 2 de $actions'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip('Resistencias legendarias: 1 de $resistances'),
    );
    await tester.pumpAndSettle();
    expect(dragonIn(server).legendaryActionsSpent, 2);
    expect(dragonIn(server).legendaryResistancesSpent, 1);

    // Tocar una gastada la devuelve, junto con las que le siguen.
    await tester.tap(find.byTooltip('Acciones legendarias: 2 de $actions'));
    await tester.pumpAndSettle();
    expect(dragonIn(server).legendaryActionsSpent, 1);

    await tester.tap(find.text('Siguiente turno'));
    await tester.pumpAndSettle();
    expect(dragonIn(server).legendaryActionsSpent, 0);
    expect(dragonIn(server).legendaryResistancesSpent, 1);
    expect(tester.takeException(), isNull);
  });

  // Visto en producción: después de actuar la fila se atenuaba, y con ella
  // las marcas que se gastan justo en los turnos ajenos.
  testWidgets('la fila del dragón no se atenúa después de actuar', (
    tester,
  ) async {
    await pumpCombate(tester);
    await tester.tap(find.text('Siguiente turno'));
    await tester.pumpAndSettle();

    double opacityOf(String name) => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.text(name),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;
    expect(opacityOf(dragon.name), 1);
    expect(tester.takeException(), isNull);
  });

  // En el teléfono las marcas medían 28 px y se tachaba la de al lado.
  testWidgets('en el teléfono cada marca mide 40 px', (tester) async {
    await pumpCombate(tester);
    tester.view.physicalSize = const Size(420, 900);
    await tester.pumpAndSettle();
    final actions = dragon.legendaryActionsPerRound!;
    final pip = find.byTooltip('Acciones legendarias: 1 de $actions');
    expect(tester.getSize(pip), const Size(40, 40));
    expect(tester.takeException(), isNull);
  });
}
