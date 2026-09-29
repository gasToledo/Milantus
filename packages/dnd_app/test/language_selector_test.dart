import 'package:dnd_app/l10n/app_locale.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/localized_app.dart';

void main() {
  late AppLocaleController controller;
  late List<String> guardado;

  setUp(() {
    guardado = [];
    controller = AppLocaleController(
      read: () => null,
      write: guardado.add,
      browserLanguage: () => null,
      setDocumentLanguage: (_) {},
    );
    addTearDown(controller.dispose);
  });

  // Reproduce lo que hace `DndApp`: el scope por encima de `MaterialApp`, que
  // escucha al controlador para cambiar `locale`.
  Widget app() => AppLocaleScope(
    controller: controller,
    child: ValueListenableBuilder<Locale>(
      valueListenable: controller,
      builder: (context, locale, _) => localizedApp(
        theme: AppTheme.dark,
        locale: locale,
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(width: 208, child: const LanguageSelector()),
              const TextField(key: ValueKey('borrador')),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('ofrece los dos idiomas, cada uno con su propio nombre', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byType(LanguageSelector));
    await tester.pumpAndSettle();

    expect(find.text('Español'), findsWidgets);
    expect(find.text('English'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('elegir English cambia el idioma, lo recuerda y no pierde el '
      'trabajo en curso', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.enterText(find.byKey(const ValueKey('borrador')), 'Thorin');
    expect(find.bySemanticsLabel('Idioma: Español'), findsOneWidget);

    await tester.tap(find.byType(LanguageSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(controller.value, const Locale('en'));
    expect(guardado, ['en']);
    expect(find.bySemanticsLabel('Language: English'), findsOneWidget);
    // El campo sigue con lo que la persona había escrito: solo cambió el texto.
    expect(find.text('Thorin'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('sin scope no hay idioma que elegir y se muestra deshabilitado', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: LanguageSelector()),
      ),
    );

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Español'), findsOneWidget);
  });
}
