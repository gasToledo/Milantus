import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/settings_service.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';
import 'fakes/localized_app.dart';

/// El diálogo de Ajustes: la preferencia de ver la dificultad del encuentro.
void main() {
  Future<SettingsController> pumpSettings(
    WidgetTester tester,
    FakeApiServer server,
  ) async {
    final api = ApiClient(client: server.client);
    final controller = SettingsController(api, AppSettings());
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SettingsDialog(api: api, settingsController: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('la dificultad del encuentro viene prendida y se puede apagar', (
    tester,
  ) async {
    final server = FakeApiServer()
      ..providers = [
        {
          'id': 'pollinations',
          'name': 'Pollinations',
          'supportsReference': false,
        },
      ];
    final controller = await pumpSettings(tester, server);

    final interruptor = find.widgetWithText(
      SwitchListTile,
      'Mostrar la dificultad del encuentro',
    );
    expect(tester.widget<SwitchListTile>(interruptor).value, isTrue);

    await tester.tap(interruptor);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(controller.settings.showEncounterDifficulty, isFalse);
    expect(server.settings!['showEncounterDifficulty'], isFalse);
    expect(tester.takeException(), isNull);
  });

  // Antes el diálogo era solo el proveedor de retratos, y sin ninguno no
  // dejaba guardar. Ahora hay algo más que guardar.
  testWidgets('sin proveedores de retratos igual se guarda la preferencia', (
    tester,
  ) async {
    final server = FakeApiServer();
    final controller = await pumpSettings(tester, server);

    expect(find.textContaining('ningún proveedor'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(controller.settings.showEncounterDifficulty, isFalse);
    expect(controller.settings.imageProvider, AppSettings().imageProvider);
    expect(tester.takeException(), isNull);
  });

  test(
    'un documento de ajustes anterior se lee con la dificultad prendida',
    () {
      final viejo = AppSettings.fromJson({'themeMode': 'light'});
      expect(viejo.showEncounterDifficulty, isTrue);
      expect(
        AppSettings.fromJson(
          (AppSettings()..showEncounterDifficulty = false).toJson(),
        ).showEncounterDifficulty,
        isFalse,
      );
    },
  );
}
