import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_app/creation/creation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los pasos del asistente de Flutter sobre lo que falta según el motor. Las
/// reglas del borrador se prueban en `dnd_engine/test/character_creation_test`.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  CreationDraft newDraft() =>
      CreationDraft(repo)..applyScoreMethod(ScoreMethod.standardArray);

  void completeClase(CreationDraft d) {
    d.featureChoices['fighting-style'] = ['fs-defense'];
    d.weaponMasteries.addAll(
      d.proficientWeapons.take(d.weaponMasterySlots).map((w) => w.id),
    );
  }

  // --- Navegación del stepper ----------------------------------------------
  group('canGoTo / firstIncompleteStep', () {
    test('no se puede saltar a un paso con pendientes atrás', () {
      final d = newDraft();
      expect(
        d.canGoTo(CreationStep.raza),
        isTrue,
        reason: 'el primero siempre',
      );
      expect(
        d.canGoTo(CreationStep.clase),
        isFalse,
        reason: 'falta elegir especie',
      );
      expect(d.firstIncompleteStep, CreationStep.raza);
    });

    test('completar habilita el siguiente, y volver atrás sigue permitido', () {
      final d = newDraft();
      // Una especie que no pide nada más: el orden del catálogo no garantiza
      // que la primera esté completa con solo elegirla (Aasimar elige tamaño).
      d.raceId = 'dwarf';
      expect(d.pendingIn(CreationSection.species), isEmpty);
      expect(d.canGoTo(CreationStep.clase), isTrue);
      expect(
        d.canGoTo(CreationStep.trasfondo),
        isFalse,
        reason: 'todavía no hay clase',
      );
      d.classId = 'fighter';
      expect(
        d.canGoTo(CreationStep.trasfondo),
        isFalse,
        reason: 'Clase aún pide estilo y maestrías',
      );
      completeClase(d);
      expect(d.canGoTo(CreationStep.trasfondo), isTrue);
      expect(d.canGoTo(CreationStep.raza), isTrue, reason: 'volver siempre');
      expect(d.firstIncompleteStep, CreationStep.trasfondo);
    });
  });
}
