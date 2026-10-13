import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes/localized_app.dart';

/// Con el cupo lleno lo no elegido se bloquea, salvo cuando el cupo es de uno:
/// ahí tocar otra opción la cambia. Bloqueada, la elección se leía como sin
/// vuelta atrás y nadie adivinaba que había que desmarcar primero.
void main() {
  Future<Set<String>> pump(WidgetTester tester, int max) async {
    final selected = <String>{};
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CappedChipSelect(
              options: const {'a': 'Uno', 'b': 'Dos', 'c': 'Tres'},
              selected: selected,
              max: max,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
    return selected;
  }

  testWidgets('con un solo lugar, tocar otra opción reemplaza la elegida', (
    tester,
  ) async {
    final selected = await pump(tester, 1);

    await tester.tap(find.text('Uno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dos'));
    await tester.pumpAndSettle();

    expect(selected, {'b'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('con varios lugares, el cupo lleno sigue bloqueando', (
    tester,
  ) async {
    final selected = await pump(tester, 2);

    for (final label in ['Uno', 'Dos', 'Tres']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    expect(selected, {'a', 'b'});
    expect(tester.takeException(), isNull);
  });
}
