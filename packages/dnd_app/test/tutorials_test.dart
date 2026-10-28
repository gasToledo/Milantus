import 'package:dnd_app/theme/app_theme.dart';
import 'package:dnd_app/ui/tutorials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/localized_app.dart';

/// Un navegador de mentira: lo último escrito es lo que lee el próximo
/// arranque.
class _Almacen {
  String? valor;
  Tutorials abrir() => Tutorials(read: () => valor, write: (v) => valor = v);
}

/// Monta una pantalla vacía y muestra [tutorial] desde ella.
Future<void> _mostrar(
  WidgetTester tester,
  Tutorials store,
  Tutorial tutorial,
) async {
  await tester.pumpWidget(
    localizedApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () =>
                showTutorialIfPending(context, tutorial, store: store),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'la bienvenida avanza por páginas y «Saltar todos» apaga todos, también '
    'al volver a entrar',
    (tester) async {
      final almacen = _Almacen();
      final store = almacen.abrir();
      final paginas = Tutorial.welcome.pages(l10nEs);

      await _mostrar(tester, store, Tutorial.welcome);
      expect(find.text(paginas[0].$2), findsOneWidget);
      expect(find.text(l10nEs.tutSkip), findsOneWidget);

      await tester.tap(find.text(l10nEs.tutNext));
      await tester.pumpAndSettle();
      expect(find.text(paginas[1].$2), findsOneWidget);

      await tester.tap(find.text(l10nEs.tutSkipAll));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      final recargado = almacen.abrir();
      for (final t in Tutorial.values) {
        expect(recargado.isPending(t), isFalse, reason: t.name);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un tutorial visto no vuelve a salir hasta restituirlos', (
    tester,
  ) async {
    final almacen = _Almacen();
    final store = almacen.abrir();

    await _mostrar(tester, store, Tutorial.dmCombat);
    await tester.tap(find.text(l10nEs.tutDone));
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    // Saltar uno no apaga los demás.
    expect(almacen.abrir().isPending(Tutorial.dmNpcs), isTrue);

    store.reset();
    expect(almacen.abrir().isPending(Tutorial.dmCombat), isTrue);
    expect(tester.takeException(), isNull);
  });
}
