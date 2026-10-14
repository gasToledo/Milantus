import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/data/settings_service.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/settings_view.dart';
import 'package:dnd_app/web/screen_awake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api_server.dart';
import 'fakes/localized_app.dart';

/// Pantalla encendida: una preferencia del dispositivo que solo actúa con una
/// pantalla de juego abierta.
void main() {
  late List<bool> applied;
  late List<bool> written;

  ScreenAwake awake({bool? stored, bool supported = true}) => ScreenAwake(
    read: () => stored,
    write: written.add,
    apply: (on) async => applied.add(on),
    supported: supported,
  );

  setUp(() {
    applied = [];
    written = [];
  });

  test('sin la preferencia, abrir una pantalla de juego no pide nada', () {
    awake().hold();
    expect(applied, isEmpty);
  });

  test('la ficha de un PNJ encima del Modo DM no la apaga al cerrarse', () {
    final a = awake(stored: true);
    a.hold(); // Modo DM
    a.hold(); // ficha del PNJ
    a.release(); // se cierra la ficha
    expect(applied, [true]);
    a.release(); // sale del Modo DM
    expect(applied, [true, false]);
  });

  test('prenderla con el Modo DM abierto actúa al instante y se recuerda', () {
    final a = awake();
    a.hold();
    a.setEnabled(true);
    expect(applied, [true]);
    expect(written, [true]);
  });

  test('donde el navegador no lo soporta nunca se pide', () {
    awake(stored: true, supported: false).hold();
    expect(applied, isEmpty);
  });

  testWidgets('Ajustes ofrece el interruptor y lo guarda en el dispositivo', (
    tester,
  ) async {
    final server = FakeApiServer();
    final a = awake();
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SettingsView(
            settingsController: SettingsController(
              ApiClient(client: server.client),
              AppSettings(),
            ),
            theme: AppThemeController(),
            screenAwake: a,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEs.settingsScreenAwake));
    await tester.pumpAndSettle();
    expect(a.enabled, isTrue);
    expect(written, [true]);
    expect(tester.takeException(), isNull);
  });
}
