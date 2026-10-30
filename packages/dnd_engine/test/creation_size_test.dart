import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Elección de tamaño en el wizard: gating, poda al cambiar de especie y
/// round-trip del borrador.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory(
      'lib/assets/srd_2024',
    );
  });

  test('el paso Raza bloquea hasta elegir el tamaño', () {
    final d = CreationDraft(repo)..raceId = 'human';
    expect(d.sizeOptions, ['Mediano', 'Pequeño']);
    expect(faltan(d, [CreationSection.species]), [
      p(CreationPendingKind.pickSize),
    ]);

    d.chosenSize = 'Pequeño';
    expect(faltan(d, [CreationSection.species]), isEmpty);
  });

  test('una especie de tamaño fijo no bloquea', () {
    final d = CreationDraft(repo)..raceId = 'goliath';
    expect(d.sizeOptions, isEmpty);
    // El Goliat sí exige linaje, así que se comprueba que lo que falta no es
    // el tamaño.
    expect(
      faltan(d, [CreationSection.species]),
      isNot(contains(p(CreationPendingKind.pickSize))),
    );
  });

  test('un tamaño inventado no desbloquea el paso', () {
    final d = CreationDraft(repo)
      ..raceId = 'human'
      ..chosenSize = 'Enorme';
    expect(faltan(d, [CreationSection.species]), [
      p(CreationPendingKind.pickSize),
    ]);
  });

  test('el personaje construido lleva el tamaño elegido', () {
    final d = CreationDraft(repo)
      ..raceId = 'tiefling'
      ..lineageId = 'tiefling-infernal'
      ..chosenSize = 'Pequeño';
    expect(d.build().chosenSize, 'Pequeño');
  });

  test('un tamaño que la especie no ofrece no llega al personaje', () {
    // Estado alcanzable si se cambia de especie sin pasar por el selector.
    final d = CreationDraft(repo)
      ..raceId = 'goliath'
      ..chosenSize = 'Pequeño';
    expect(d.build().chosenSize, isNull);
  });

  test('el borrador conserva el tamaño al guardarse', () {
    final d = CreationDraft(repo)
      ..raceId = 'aasimar'
      ..chosenSize = 'Pequeño';
    final restored = CreationDraft.fromJson(repo, d.toJson());
    expect(restored.chosenSize, 'Pequeño');
  });

  test('al restaurar descarta un tamaño que la especie no ofrece', () {
    final d = CreationDraft(repo)..raceId = 'human';
    final json = d.toJson()..['chosenSize'] = 'Grande';
    expect(CreationDraft.fromJson(repo, json).chosenSize, isNull);
  });

  test('la ficha de previsualización refleja el tamaño elegido', () {
    // La firma del caché incluye el tamaño: sin eso, cambiarlo no recompilaba.
    final d = CreationDraft(repo)
      ..raceId = 'human'
      ..classId = 'fighter'
      ..backgroundId = 'soldier'
      ..chosenSize = 'Mediano';
    expect(d.previewSheet.size, 'Mediano');

    d.chosenSize = 'Pequeño';
    expect(d.previewSheet.size, 'Pequeño');
  });
}

/// Lo que falta en [sections], en una forma comparable: el texto lo pone cada
/// cliente, y acá alcanza con el qué y el cuánto.
List<String> faltan(CreationDraft d, List<CreationSection> sections) => [
      for (final s in sections)
        for (final x in d.pendingIn(s))
          p(x.kind, have: x.have, need: x.need, name: x.name),
    ];

String p(CreationPendingKind kind,
        {int have = 0, int need = 0, String name = ''}) =>
    '${kind.name} $have/$need $name';
