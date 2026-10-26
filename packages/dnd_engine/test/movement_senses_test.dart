import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Velocidades además de caminar y sentidos además de la visión en la
/// oscuridad (SRD 5.2.1 y PHB 2024).
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  ComputedSheet ficha(
    String classId,
    int level, {
    String raceId = 'human',
    String? subclassId,
  }) =>
      compiler.compile(Character(
        id: 'p',
        name: 'Prueba',
        raceId: raceId,
        classId: classId,
        subclassId: subclassId,
        backgroundId: 'soldier',
        level: level,
        assignedScores: {for (final a in Ability.values) a: 12},
        hpPerLevel: List.filled(level, 6),
      ));

  test('«igual a tu velocidad» se resuelve con la velocidad final', () {
    // Errante suma 10 a caminar y da trepar y nado iguales: 40, no 30.
    final explorador = ficha('ranger', 6);
    expect(explorador.speed, 40);
    expect(explorador.speeds[MovementMode.climb], 40);
    expect(explorador.speeds[MovementMode.swim], 40);
    // El Cansancio resta a todas, no solo a caminar.
    final cansado = applyExhaustion(explorador, 2);
    expect(cansado.speeds[MovementMode.climb], 30);

    expect(ficha('ranger', 18).senses[Sense.blindsight], 30);
  });

  test('la visión en la oscuridad que se suma no depende de la especie', () {
    // Vista Umbral: 60 a quien no tenía; +60 a quien ya tenía.
    expect(ficha('ranger', 3, subclassId: 'gloom-stalker').darkvision, 60);
    final base = ficha('ranger', 3, raceId: 'dwarf').darkvision!;
    final enano =
        ficha('ranger', 3, raceId: 'dwarf', subclassId: 'gloom-stalker');
    expect(enano.darkvision, base + 60);
  });

  test('la telepatía del Kalashtar crece con el nivel', () {
    expect(
        ficha('fighter', 3, raceId: 'kalashtar').senses[Sense.telepathy], 30);
  });

  test('la Forma Salvaje toma las velocidades y sentidos de la bestia', () {
    final trepadora = repo.creatures.values.firstWhere(
        (c) => c.isBeast && c.otherSpeeds.containsKey(MovementMode.climb));
    final druida = ficha('druid', 2);
    final bestia = applyWildShape(druida, trepadora);
    expect(bestia.speeds, trepadora.otherSpeeds);
    expect(bestia.senses, trepadora.otherSenses);
  });
}
