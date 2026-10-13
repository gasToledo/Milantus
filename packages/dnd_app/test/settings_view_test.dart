import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/settings_service.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';
import 'fakes/localized_app.dart';

/// La sección Ajustes: cada cambio se guarda al tocarlo, sin botón.
void main() {
  Future<SettingsController> pumpSettings(
    WidgetTester tester,
    FakeApiServer server, {
    Size size = const Size(1100, 900),
    AppThemeController? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(client: server.client);
    final controller = SettingsController(api, AppSettings());
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SettingsView(
            settingsController: controller,
            theme: theme ?? AppThemeController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('elegir el Modo DM para abrir se guarda al tocarlo', (
    tester,
  ) async {
    final server = FakeApiServer();
    final controller = await pumpSettings(tester, server);

    expect(controller.settings.startsInDmMode, isFalse);
    expect(find.text('Guardado'), findsNothing);

    await tester.tap(find.text('Modo DM').first);
    await tester.pumpAndSettle();

    expect(controller.settings.startsInDmMode, isTrue);
    expect(server.settings!['startsInDmMode'], isTrue);
    expect(find.text('Guardado'), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la dificultad del encuentro viene prendida y se puede apagar', (
    tester,
  ) async {
    final server = FakeApiServer();
    final controller = await pumpSettings(tester, server);

    final interruptor = find.widgetWithText(
      SwitchListTile,
      'Mostrar la dificultad del encuentro',
    );
    expect(tester.widget<SwitchListTile>(interruptor).value, isTrue);

    await tester.tap(interruptor);
    await tester.pumpAndSettle();

    expect(controller.settings.showEncounterDifficulty, isFalse);
    expect(server.settings!['showEncounterDifficulty'], isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el tema se cambia desde acá, con sus tres opciones', (
    tester,
  ) async {
    final theme = AppThemeController();
    await pumpSettings(tester, FakeApiServer(), theme: theme);

    expect(theme.value, ThemeMode.dark);
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();

    expect(theme.value, ThemeMode.light);
    expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // El proveedor de retratos se elige en la pantalla de retratos, que es
  // donde se usa. Acá no aparece, y tocar otro ajuste no lo pisa.
  testWidgets('no hay apartado de retratos, y guardar no toca el proveedor', (
    tester,
  ) async {
    final server = FakeApiServer();
    final controller = await pumpSettings(tester, server);
    controller.settings.imageProvider = 'otro';

    expect(find.textContaining('etrato'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(controller.settings.showEncounterDifficulty, isFalse);
    expect(server.settings!['imageProvider'], 'otro');
    expect(tester.takeException(), isNull);
  });

  testWidgets('entra en un teléfono, en español y en inglés', (tester) async {
    for (final locale in const [Locale('es'), Locale('en')]) {
      tester.view.physicalSize = const Size(340, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = ApiClient(client: FakeApiServer().client);
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          locale: locale,
          home: Scaffold(
            body: SettingsView(
              settingsController: SettingsController(api, AppSettings()),
              theme: AppThemeController(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  test('un documento de ajustes anterior abre en el Modo Jugador y muestra la '
      'dificultad', () {
    final viejo = AppSettings.fromJson({'themeMode': 'light'});
    expect(viejo.startsInDmMode, isFalse);
    expect(viejo.showEncounterDifficulty, isTrue);

    final guardado = AppSettings.fromJson(
      (AppSettings()
            ..startsInDmMode = true
            ..showEncounterDifficulty = false)
          .toJson(),
    );
    expect(guardado.startsInDmMode, isTrue);
    expect(guardado.showEncounterDifficulty, isFalse);
  });
}
