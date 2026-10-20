import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/theme/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes/localized_app.dart';

/// Abre un [AppDialog] sobre un andamio con el tema real.
///
/// Lo que devuelva la ruta se anota en [salida] cuando el diálogo se cierre,
/// que es después de que esta función haya vuelto: por eso una caja y no un
/// valor de retorno.
Future<void> _abrir(
  WidgetTester tester, {
  required List<DialogAction> Function(BuildContext ctx) actions,
  List<String?>? salida,
  double width = 480,
  Widget content = const Text('Cuerpo del diálogo.'),
}) async {
  await tester.pumpWidget(
    localizedApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final elegido = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AppDialog(
                    title: 'Terminar combate',
                    width: width,
                    content: content,
                    actions: actions(ctx),
                  ),
                );
                salida?.add(elegido);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

List<DialogAction> _tresAcciones(BuildContext ctx) => [
  DialogAction(
    'Cancelar',
    keyHint: 'Esc',
    onPressed: () => Navigator.of(ctx).pop(),
  ),
  DialogAction(
    'Descartar sin guardar',
    onPressed: () => Navigator.of(ctx).pop('descartar'),
  ),
  DialogAction(
    'Terminar y guardar',
    primary: true,
    onPressed: () => Navigator.of(ctx).pop('guardar'),
  ),
];

void main() {
  testWidgets('el molde muestra el título, el cuerpo y una celda por acción', (
    tester,
  ) async {
    await _abrir(tester, actions: _tresAcciones);

    expect(find.text('Terminar combate'), findsOneWidget);
    expect(find.text('Cuerpo del diálogo.'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Descartar sin guardar'), findsOneWidget);
    expect(find.text('Terminar y guardar'), findsOneWidget);
    // La tecla se dibuja solo donde se la declaró.
    expect(find.text('Esc'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('cada celda devuelve lo suyo', (tester) async {
    final salida = <String?>[];

    await _abrir(tester, actions: _tresAcciones, salida: salida);
    await tester.tap(find.text('Descartar sin guardar'));
    await tester.pumpAndSettle();
    expect(salida, ['descartar']);

    await _abrir(tester, actions: _tresAcciones, salida: salida);
    await tester.tap(find.text('Terminar y guardar'));
    await tester.pumpAndSettle();
    expect(salida, ['descartar', 'guardar']);

    // Cancelar cierra sin resultado, que es lo que distingue «no hice nada» de
    // «elegí una de las dos salidas».
    await _abrir(tester, actions: _tresAcciones, salida: salida);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(salida, ['descartar', 'guardar', null]);

    expect(tester.takeException(), isNull);
  });
}
