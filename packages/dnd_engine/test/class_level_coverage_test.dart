import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Cobertura de niveles de los rasgos de clase.
///
/// El objetivo del catálogo es que el jugador vea el panorama completo al
/// elegir clase. Mago, Bardo, Hechicero y Brujo no tenían **ningún** rasgo por
/// encima del nivel 2, así que quien elegía una de ellas decidía a ciegas.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Iterable<ClassFeature> featuresOf(String id) =>
      repo.characterClass(id)!.features;

  test('el Guerrero acumula ataques hasta cuatro', () {
    // El motor toma el máximo de ExtraAttackEffect, así que cada nivel declara
    // el total y no el incremento.
    int extraAt(int level) => repo
        .characterClass('fighter')!
        .features
        .where((f) => f.level <= level)
        .expand((f) => f.effects)
        .whereType<ExtraAttackEffect>()
        .map((e) => e.extra)
        .fold(0, (a, b) => a > b ? a : b);
    expect(extraAt(4), 0);
    expect(extraAt(5), 1);
    expect(extraAt(11), 2);
    expect(extraAt(20), 3);
  });

  test('el Monje competente en todas las salvaciones a nivel 14', () {
    // Superviviente Disciplinado es el único rasgo de esta tanda con efecto
    // mecánico sobre la ficha, así que se comprueba compilado y no por texto.
    final efectos = featuresOf('monk')
        .where((f) => f.level <= 14)
        .expand((f) => f.effects)
        .whereType<SavingThrowProficiencyEffect>()
        .map((e) => e.ability)
        .toSet();
    expect(efectos, hasLength(Ability.values.length));
  });
}
