import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:dnd_app/creation/creation_wizard.dart';
import 'package:dnd_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'creation_helpers.dart';
import 'fakes/localized_app.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  /// Regresión: el Bardo es la única clase con `skillChoiceFrom` vacío (2024:
  /// elige libremente entre las 18). Antes eso se leía como "ninguna opción" y
  /// el picker salía vacío. La regla vive ahora en un solo lugar.
  group('skillOptions', () {
    test('lista vacía significa las 18 habilidades, no ninguna', () {
      expect(skillOptions(const []), hasLength(18));
      expect(skillOptions(const []), same(allSkills2024));
    });

    test('el Bardo puede elegir entre las 18', () {
      final bard = repo.characterClass('bard')!;
      expect(bard.skillChoiceFrom, isEmpty, reason: 'premisa del caso');
      expect(skillOptions(bard.skillChoiceFrom), hasLength(18));
    });

    test('una lista acotada se respeta tal cual', () {
      final fighter = repo.characterClass('fighter')!;
      expect(fighter.skillChoiceFrom, isNotEmpty);
      expect(skillOptions(fighter.skillChoiceFrom), fighter.skillChoiceFrom);
    });
  });

  testWidgets('el wizard abre en Especie con el stepper de 8 pasos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Crear personaje'), findsOneWidget);
    // Los 8 pasos del stepper. Por su etiqueta y no por el texto: el título
    // del paso abierto repite el nombre del primero («ESPECIE»).
    for (final s in CreationStep.values) {
      expect(
        find.bySemanticsLabel(
          RegExp('^${s.label(l10nEs)}, paso ${s.index + 1} de 8'),
        ),
        findsOneWidget,
        reason: 'falta el paso ${s.label(l10nEs)}',
      );
    }
    // Arranca bloqueado: hay que elegir especie antes de avanzar.
    final next = find.widgetWithText(FilledButton, 'Siguiente');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
  });

  // En un teléfono el detalle queda debajo de toda la grilla: al elegir, el pie
  // pedía cosas que no estaban a la vista. Y con un solo scroll para todos los
  // pasos, el siguiente abría a la altura donde había quedado el anterior.
  testWidgets(
    'en angosto, elegir baja al detalle y el paso siguiente arranca arriba',
    (tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        localizedApp(
          theme: AppTheme.dark,
          home: CreationWizard(repo: repo, onCreate: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      ScrollPosition body(CreationStep step) => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(ValueKey(step)),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      final dwarf = find.text(repo.races['dwarf']!.name).first;
      await tester.ensureVisible(dwarf);
      await tester.pumpAndSettle();
      final before = body(CreationStep.raza).pixels;
      await tester.tap(dwarf);
      await tester.pumpAndSettle();
      expect(body(CreationStep.raza).pixels, greaterThan(before));

      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
      expect(body(CreationStep.clase).pixels, 0);

      // La clase arranca sin elegir: el pie lo pide antes que nada.
      expect(
        tester.widget<Text>(find.textContaining('Falta:')).data,
        'Falta: Elegí una clase.',
      );

      // Con más de un faltante, el pie dice el primero y cuántos quedan, sin
      // cortarse y sin el punto del faltante antes del paréntesis.
      final fighter = find.text(repo.characterClass('fighter')!.name).first;
      await tester.ensureVisible(fighter);
      await tester.pumpAndSettle();
      await tester.tap(fighter);
      await tester.pumpAndSettle();
      final pending = tester.widget<Text>(find.textContaining('Falta:')).data!;
      expect(pending, endsWith('(y 1 cosa más).'));
      expect(pending, isNot(contains('. (')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pide confirmación al cerrar después de elegir opciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tapOption(tester, 'Humano');
    await pickSize(tester);
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar este personaje?'), findsOneWidget);
    expect(
      find.text('Las elecciones realizadas en el asistente se perderán.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Seguir creando'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar este personaje?'), findsNothing);
    expect(find.text('Crear personaje'), findsOneWidget);
  });

  // --- Modo dividido de Especie / Clase / Trasfondo -------------------------
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: CreationWizard(repo: repo, onCreate: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Los rasgos de una especie eran una línea de nombres pegados con comas, que
  // para quien no juega dice tan poco como una lista de conjuros sin
  // descripción.
  testWidgets('los rasgos de la especie se leen con su texto', (tester) async {
    await pumpAt(tester, const Size(1500, 1400));

    final elfo = repo.race('elf')!;
    final rasgos = elfo.effects.whereType<PassiveTraitEffect>().toList();
    expect(rasgos, isNotEmpty, reason: 'el catálogo cambió');

    await tapOption(tester, elfo.name);
    await tester.pumpAndSettle();

    expect(find.text('RASGOS'), findsOneWidget);
    for (final rasgo in rasgos) {
      expect(find.text(rasgo.name), findsWidgets, reason: rasgo.name);
      expect(
        find.textContaining(rasgo.description.split('.').first),
        findsWidgets,
        reason: 'falta el texto de ${rasgo.name}',
      );
    }
    expect(tester.takeException(), isNull);
  });

  // El Draconato tiene un rasgo pasivo (el vuelo de nivel 5), y la lista solo
  // lee los pasivos cuando hay alguno: el Aliento, que era un recurso, y la
  // visión en la oscuridad no aparecían en el paso.
  testWidgets('el Draconato muestra su Aliento y su visión en la oscuridad', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1500, 1400));
    final draconato = repo.race('dragonborn')!;
    final vision = draconato.effects.whereType<DarkvisionEffect>().single;

    await tapOption(tester, draconato.name);
    await tester.pumpAndSettle();

    expect(find.text('Ataque de Aliento'), findsOneWidget);
    expect(find.text('VISIÓN EN LA OSCURIDAD  '), findsOneWidget);
    expect(find.text('${vision.range} pies'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
