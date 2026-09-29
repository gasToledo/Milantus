import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/l10n/app_locale.dart';
import 'package:dnd_app/main.dart';
import 'package:dnd_app/ui/dashboard_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fakes/fake_api_server.dart';

/// El idioma de la interfaz de punta a punta, con la aplicación entera
/// (`DndApp`) y no con una pantalla suelta: que el scope esté montado, que
/// `MaterialApp` escuche el cambio y que la elección se recuerde.
void main() {
  late String? guardado;
  late List<String> documento;

  setUp(() {
    guardado = null;
    documento = [];
    PackageInfo.setMockInitialValues(
      appName: 'dnd_app',
      packageName: 'dnd_app.test',
      version: 'test',
      buildNumber: '1',
      buildSignature: 'test',
    );
  });

  AppLocaleController idioma({String? navegador}) => AppLocaleController(
    read: () => guardado,
    write: (c) => guardado = c,
    browserLanguage: () => navegador,
    setDocumentLanguage: documento.add,
  );

  Future<void> abrir(WidgetTester tester, AppLocaleController locale) async {
    // Ancho de escritorio: el panel lateral (con el selector) a la vista.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(client: FakeApiServer().client);
    await tester.pumpWidget(
      DndApp(
        api: api,
        contentLoader: () async => ContentRepository(),
        localeController: locale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(DashboardScreen), findsOneWidget);
  }

  testWidgets('sin nada guardado, un navegador en inglés abre en inglés', (
    tester,
  ) async {
    final locale = idioma(navegador: 'en-US');
    addTearDown(locale.dispose);
    await abrir(tester, locale);

    expect(find.text('My characters'), findsWidgets);
    expect(find.text('Mis personajes'), findsNothing);
    expect(documento, ['en']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lo guardado gana sobre el idioma del navegador', (tester) async {
    guardado = 'es';
    final locale = idioma(navegador: 'en-US');
    addTearDown(locale.dispose);
    await abrir(tester, locale);

    expect(find.text('Mis personajes'), findsWidgets);
    expect(find.text('My characters'), findsNothing);
  });

  testWidgets('elegir el idioma en el panel cambia toda la interfaz y se '
      'recuerda', (tester) async {
    final locale = idioma();
    addTearDown(locale.dispose);
    await abrir(tester, locale);
    expect(find.text('Mis personajes'), findsWidgets);

    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('My characters'), findsWidgets);
    expect(find.text('Mis personajes'), findsNothing);
    expect(guardado, 'en');
    expect(documento.last, 'en');

    // Y se puede volver: el menú ofrece los dos idiomas con su propio nombre.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();

    expect(find.text('Mis personajes'), findsWidgets);
    expect(guardado, 'es');
    expect(tester.takeException(), isNull);
  });
}
