import 'dart:convert';
import 'dart:io';

import 'package:dnd_app/api/api_client.dart';
import 'package:dnd_app/demo/demo_characters.dart';
import 'package:dnd_app/l10n/app_locale.dart';
import 'package:dnd_app/l10n/app_localizations.dart';
import 'package:dnd_app/main.dart';
import 'package:dnd_app/ui/sheet_screen.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fakes/fake_api_server.dart';

/// El catálogo sigue al idioma de la interfaz, también en una pantalla que ya
/// estaba abierta: la ficha es una ruta empujada y guarda la referencia al
/// repositorio que recibió.
void main() {
  late Directory pack;
  // Se cargan antes: dentro de `testWidgets` el reloj es falso y leer
  // archivos no termina nunca.
  late ContentRepository catalogoEs;
  late ContentRepository catalogoEn;
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    // El pack real, con una superposición de prueba para la clase y el arma
    // de Sagan: lo que se ve en la cabecera y en el inventario.
    pack = await Directory.systemTemp.createTemp('pack_en');
    const origen = '../dnd_engine/lib/assets/srd_2024';
    await for (final f in Directory(origen).list()) {
      if (f is File) await f.copy('${pack.path}/${f.uri.pathSegments.last}');
    }
    Future<void> traducir(String catalogo, String id, String nombre) async {
      final entradas =
          (jsonDecode(await File('$origen/$catalogo.json').readAsString())
                  as List)
              .cast<Map<String, dynamic>>();
      final entrada = entradas.firstWhere((e) => e['id'] == id);
      await File('${pack.path}/$catalogo.en.json').writeAsString(
        jsonEncode({
          id: {
            translationFingerprintKey: contentFingerprint(entrada, ['name']),
            'name': nombre,
          },
        }),
      );
    }

    await traducir('classes', 'fighter', 'Fighter');
    await traducir('weapons', 'longsword', 'Longsword');
    catalogoEs = await ContentRepository.loadFromDirectory(pack.path);
    catalogoEn = await ContentRepository.loadFromDirectory(
      pack.path,
      translation: 'en',
    );
  });

  tearDownAll(() => pack.delete(recursive: true));

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'dnd_app',
      packageName: 'dnd_app.test',
      version: 'test',
      buildNumber: '1',
      buildSignature: 'test',
    );
  });

  tearDown(() => ContentLanguage.current = ContentLanguage.es);

  testWidgets('cambiar a inglés con la ficha abierta traduce el catálogo y '
      'conserva la pestaña', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final espanol = catalogoEs;
    final guerrero = espanol.characterClass('fighter')!.name;
    final espadaLarga = espanol.weapon('longsword')!.name;

    final sagan = demoSagan();
    final server = FakeApiServer()..characters[sagan.id] = sagan;
    final locale = AppLocaleController(
      read: () => 'es',
      write: (_) {},
      browserLanguage: () => null,
      setDocumentLanguage: (_) {},
    );
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      DndApp(
        api: ApiClient(client: server.client),
        // Uno nuevo cada vez, como el loader real: el arranque modifica el que
        // recibe (le suma el homebrew y lo rehace al cambiar de idioma).
        contentLoader: (t) async =>
            ContentRepository()..addAll(t == 'en' ? catalogoEn : catalogoEs),
        localeController: locale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text(sagan.name).first);
    await tester.pumpAndSettle();
    expect(find.byType(SheetScreen), findsOneWidget);
    expect(find.textContaining(guerrero), findsWidgets);

    await tester.tap(find.text(es.tabInventory).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(espadaLarga), findsWidgets);

    await locale.choose(const Locale('en'));
    await tester.pumpAndSettle();

    // La misma ficha, en la misma pestaña, con el catálogo en inglés.
    expect(find.byType(SheetScreen), findsOneWidget);
    expect(find.text(en.tabInventory), findsWidgets);
    expect(find.textContaining('Longsword'), findsWidgets);
    expect(find.textContaining(espadaLarga), findsNothing);
    expect(ContentLanguage.current, ContentLanguage.en);

    await tester.tap(find.text(en.tabCharacter).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Fighter'), findsWidgets);
    expect(find.textContaining(guerrero), findsNothing);

    // Y de vuelta al español.
    await locale.choose(const Locale('es'));
    await tester.pumpAndSettle();
    expect(find.textContaining(guerrero), findsWidgets);
    expect(ContentLanguage.current, ContentLanguage.es);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con el Códice abierto, la búsqueda encuentra por el nombre en '
      'inglés', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = AppLocaleController(
      read: () => 'es',
      write: (_) {},
      browserLanguage: () => null,
      setDocumentLanguage: (_) {},
    );
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      DndApp(
        api: ApiClient(client: FakeApiServer().client),
        contentLoader: (t) async =>
            ContentRepository()..addAll(t == 'en' ? catalogoEn : catalogoEs),
        localeController: locale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text(es.navCodex).first);
    await tester.pumpAndSettle();
    await locale.choose(const Locale('en'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Fighter');
    await tester.pumpAndSettle();
    expect(find.text('Fighter'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
