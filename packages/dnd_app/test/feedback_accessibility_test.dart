import 'package:dnd_app/api/api_exception.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/localized_app.dart';

void main() {
  testWidgets('los avisos se anuncian como región viva', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showAppMessage(
                context,
                'Cambios guardados.',
                tone: AppMessageTone.success,
              ),
              child: const Text('Avisar'),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    await tester.tap(find.text('Avisar'));
    await tester.pump();

    expect(find.text('Cambios guardados.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Cambios guardados.',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('las estadísticas exponen una etiqueta completa', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Column(
            children: [
              StatPlaque(label: 'Velocidad', value: '30'),
              // Un rótulo abreviado por ancho dice la palabra entera en voz
              // alta: «CA: 16» no se entiende dicho.
              StatPlaque(
                label: 'CA',
                value: '16',
                semantics: 'Clase de armadura: 16',
              ),
            ],
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    expect(find.bySemanticsLabel('Velocidad: 30'), findsOneWidget);
    expect(find.bySemanticsLabel('Clase de armadura: 16'), findsOneWidget);
    expect(find.bySemanticsLabel('CA: 16'), findsNothing);
    semantics.dispose();
  });

  // La placa de característica muestra «DES» y no puede decir «de e ese» en voz
  // alta: por eso recibe la `Ability` entera y no su abreviatura.
  testWidgets('la placa de característica dice el nombre entero', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AbilityPlaque(
            ability: Ability.dexterity,
            score: 14,
            modifier: 2,
            saveProficient: true,
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    expect(find.text(Ability.dexterity.abbr), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '${Ability.dexterity.label}: modificador +2, puntuación 14, '
        'competente en salvación',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  // El idioma y el tema viven en Ajustes. En un teléfono angosto la fila les
  // deja unos 208 px:
  // los tres segmentos y el idioma tienen que entrar ahí sin desbordar, y cada
  // segmento tiene que ser un objetivo táctil de 48 px.
  group('preferencias de presentación', () {
    const contentWidth = 236.0 - 14 * 2;

    Future<AppThemeController> pump(WidgetTester tester) async {
      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LanguageSelector(),
                    const SizedBox(height: 8),
                    ThemeModeSelector(controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('tocar un segmento cambia el tema y marca cuál está activo', (
      tester,
    ) async {
      final controller = await pump(tester);
      expect(controller.value, ThemeMode.dark);

      await tester.tap(find.byTooltip('Seguir el tema del sistema'));
      await tester.pumpAndSettle();

      expect(controller.value, ThemeMode.system);
      expect(
        tester
            .widget<SegmentedButton<ThemeMode>>(
              find.byType(SegmentedButton<ThemeMode>),
            )
            .selected,
        {ThemeMode.system},
      );
    });

    // Sin `AppLocaleScope` (acá se monta el panel suelto) no hay a quién pedirle
    // el cambio: el idioma activo se muestra pero no ofrece un menú.
    testWidgets('sin scope el idioma se muestra sin menú', (tester) async {
      await pump(tester);

      expect(find.text('Español'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });
  });

  // Un botón que solo es un ícono no tiene nombre para un lector de pantalla
  // si nadie se lo pone: el tooltip es lo que se lo da.
  testWidgets('los botones de solo ícono tienen nombre accesible', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SpendRecoverButtons(
            onSpend: () {},
            onRecover: () {},
            spendTooltip: 'Gastar un uso',
            recoverTooltip: 'Recuperar un uso',
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    // El tooltip llega al árbol de semántica como `tooltip`: es lo que anuncia
    // un lector de pantalla al posarse sobre un botón que solo tiene ícono.
    for (final label in ['Gastar un uso', 'Recuperar un uso']) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(tester.getSemantics(find.byTooltip(label)).tooltip, label);
    }
    semantics.dispose();
  });

  testWidgets('un fallo explica qué pasó y deja el detalle a un toque', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppErrorView(
            message: 'No se pudo conectar con el servidor.',
            hint: 'Revisá la conexión y reintentá.',
            details: 'SocketException: connection refused (errno = 111)',
            onRetry: () => retried++,
          ),
        ),
      ),
    );

    // El detalle técnico no es el mensaje principal: está, pero plegado.
    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);

    await tester.tap(find.text('Ver detalles'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SocketException'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    expect(retried, 1);
  });

  // Un aviso de error interpolaba la excepción tal cual, y quien importaba un
  // archivo roto leía «FormatException: …» en inglés.
  test('un aviso de error no muestra el nombre de la excepción', () {
    expect(
      failureMessage(
        'No se pudo importar',
        const FormatException('El archivo no es válido.'),
      ),
      'No se pudo importar: El archivo no es válido.',
    );
    expect(
      failureMessage(
        'No se pudo guardar',
        const ApiException(404, 'Campaña no encontrada.'),
      ),
      'No se pudo guardar: Campaña no encontrada.',
    );
    // Un bug no tiene un motivo que le sirva a quien juega.
    expect(
      failureMessage('No se pudo guardar', StateError('Bad state: x')),
      'No se pudo guardar.',
    );
  });
}
