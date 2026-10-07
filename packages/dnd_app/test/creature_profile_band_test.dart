import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/localized_app.dart';

/// La banda de cifras del perfil rotula entero solo si cada tramo tiene
/// lugar: acostada a ~540 px, «VALOR DE DESAFÍO» y «PUNTOS DE GOLPE» con los
/// dados de golpe se cortaban con puntos suspensivos.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  Future<void> pumpProfile(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final aboleth = repo.creature('aboleth')!;
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: creatureProfileBody(context, repo, aboleth),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('angosta pero acostada, abrevia', (tester) async {
    await pumpProfile(tester, 540);
    expect(find.text('PG'), findsOneWidget);
    expect(find.text('VD'), findsOneWidget);
    expect(find.text('VALOR DE DESAFÍO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con lugar, rotula entero y suma los dados de golpe', (
    tester,
  ) async {
    await pumpProfile(tester, 1000);
    final aboleth = repo.creature('aboleth')!;
    expect(find.text('PUNTOS DE GOLPE'), findsOneWidget);
    expect(find.text('VALOR DE DESAFÍO'), findsOneWidget);
    expect(find.text(aboleth.hitDice!), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
