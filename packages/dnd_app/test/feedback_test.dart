import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/l10n/app_locale.dart';
import 'package:dnd_app/l10n/app_localizations.dart';
import 'package:dnd_app/main.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_app/ui/feedback.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fakes/fake_api_server.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'dnd_app',
      packageName: 'dnd_app.test',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: 'test',
    );
  });

  /// La app entera, en ventana ancha para que el panel lateral esté fijo.
  Future<FakeApiServer> mountApp(
    WidgetTester tester, {
    required bool feedbackEnabled,
    String language = 'es',
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeApiServer()..feedbackEnabled = feedbackEnabled;
    await tester.pumpWidget(
      DndApp(
        api: ApiClient(client: server.client),
        contentLoader: () async => ContentRepository(),
        localeController: AppLocaleController(
          read: () => language,
          write: (_) {},
          browserLanguage: () => null,
          setDocumentLanguage: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  // El ítem de la navegación; el ícono es el mismo en los dos idiomas.
  final button = find.byIcon(Icons.feedback_outlined);

  testWidgets('el ítem está aunque el servidor no tenga correo configurado', (
    tester,
  ) async {
    final server = await mountApp(tester, feedbackEnabled: false);

    expect(button, findsOne);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feedback-message')),
      'Algo',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    // Sin proveedor el servidor responde 503: el diálogo lo dice y queda
    // abierto con el texto.
    expect(server.feedback, isEmpty);
    expect(find.textContaining('No se pudo enviar el mensaje'), findsOne);
    expect(find.text('Algo'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el mensaje sale con el tipo elegido y los datos técnicos', (
    tester,
  ) async {
    final server = await mountApp(tester, feedbackEnabled: true);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Te respondemos a ${server.accountEmail}.'), findsOne);

    await tester.tap(find.byKey(const ValueKey('feedback-kind-bug')));
    await tester.enterText(
      find.byKey(const ValueKey('feedback-message')),
      '  La ficha no guarda  ',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    final sent = server.feedback.single;
    expect(sent['kind'], 'bug');
    expect(sent['message'], 'La ficha no guarda');
    expect(sent['context'], {
      'version': '9.9.9',
      'language': 'es',
      'theme': 'dark',
      'viewport': '1400x1000',
      'origin': 'dashboard',
    });
    expect(find.text('¡Gracias! Recibimos tu mensaje.'), findsOne);
    expect(find.byKey(const ValueKey('feedback-message')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si el envío falla, el diálogo queda abierto con el texto', (
    tester,
  ) async {
    final server = await mountApp(tester, feedbackEnabled: true)
      ..feedbackFailStatus = 502;

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feedback-message')),
      'Que se pueda ordenar el inventario',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(server.feedback, isEmpty);
    expect(
      find.text('No se pudo enviar el mensaje: No se pudo enviar el mensaje.'),
      findsOne,
    );
    expect(find.text('Que se pueda ordenar el inventario'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en inglés el error no arrastra el motivo en castellano', (
    tester,
  ) async {
    final server = await mountApp(tester, feedbackEnabled: true, language: 'en')
      ..feedbackFailStatus = 502;

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Ideas & bug reports'), findsWidgets);
    expect(find.text('An idea'), findsOne);
    expect(find.text("We'll reply to ${server.accountEmail}."), findsOne);

    await tester.enterText(
      find.byKey(const ValueKey('feedback-message')),
      'Sort the inventory',
    );
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't send the message."), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin texto no se puede enviar', (tester) async {
    final server = await mountApp(tester, feedbackEnabled: true);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feedback-message')),
      '   ',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(server.feedback, isEmpty);
    expect(find.byKey(const ValueKey('feedback-message')), findsOne);
    expect(tester.takeException(), isNull);
  });

  group('«Reportar este error» en la vista de error', () {
    Future<void> mountError(
      WidgetTester tester,
      FakeApiServer server, {
      required bool withChannel,
    }) async {
      final channel = ValueNotifier<FeedbackChannel?>(
        withChannel
            ? FeedbackChannel(
                api: ApiClient(client: server.client),
                email: server.accountEmail,
                appVersion: '9.9.9',
              )
            : null,
      );
      addTearDown(channel.dispose);
      await tester.pumpWidget(
        FeedbackScope(
          notifier: channel,
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AppErrorView(
                message: 'No se pudo cargar la ficha',
                details: 'ApiException(500)',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final report = find.byKey(const ValueKey('error-report-button'));

    testWidgets('abre el diálogo como error y manda el detalle', (
      tester,
    ) async {
      final server = FakeApiServer()..feedbackEnabled = true;
      await mountError(tester, server, withChannel: true);

      await tester.tap(report);
      await tester.pumpAndSettle();
      final bug = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('feedback-kind-bug')),
      );
      expect(bug.selected, isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('feedback-message')),
        'Abrí la ficha y apareció esto',
      );
      await tester.pump();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      final context = server.feedback.single['context'] as Map;
      expect(context['origin'], 'errorView');
      expect(
        context['errorDetail'],
        'No se pudo cargar la ficha\nApiException(500)',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin canal no aparece', (tester) async {
      await mountError(tester, FakeApiServer(), withChannel: false);

      expect(report, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
