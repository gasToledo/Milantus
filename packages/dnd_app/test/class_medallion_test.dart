import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes/localized_app.dart';

/// El emblema de clase reemplaza a la inicial cuando no hay retrato.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    localizedApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('el lector de pantalla oye el nombre entero, no la inicial', (
    tester,
  ) async {
    await pump(tester, const Medallion(name: 'Bruna Piedrahonda', size: 40));
    expect(find.text('B'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Emblema de Bruna Piedrahonda')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
