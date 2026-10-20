import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Regresión de rasgos de especie contra el SRD 5.2.1 en español.
///
/// Son aserciones de texto a propósito: el catálogo arrastraba redacciones de
/// 2014 que ningún test estructural detectaba, así que revertir el dato tiene
/// que romper el build.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  /// Descripción del rasgo pasivo `name` de la especie `raceId`.
  String? traitOf(String raceId, String name) => repo
      .race(raceId)!
      .effects
      .whereType<PassiveTraitEffect>()
      .where((t) => t.name == name)
      .map((t) => t.description)
      .firstOrNull;

  group('Enano', () {
    test('Afinidad con la Piedra dura 10 minutos y tiene usos limitados', () {
      final d = traitOf('dwarf', 'Afinidad con la Piedra');
      expect(d, isNotNull, reason: 'el SRD lo llama Afinidad con la piedra');
      // Antes decía "hasta el fin de tu turno" y no limitaba los usos.
      expect(d, contains('10 minutos'));
      expect(d, contains('competencia'));
      expect(d, isNot(contains('fin de tu turno')));
    });

    test('conserva visión en la oscuridad de 120 pies', () {
      final dark =
          repo.race('dwarf')!.effects.whereType<DarkvisionEffect>().single;
      expect(dark.range, 120);
    });
  });

  group('Orco', () {
    test('Descarga de Adrenalina se recupera en descanso corto o largo', () {
      expect(
          traitOf('orc', 'Descarga de Adrenalina'), contains('corto o largo'));
    });
  });

  group('Mediano', () {});

  group('Humano', () {
    test('Diestro se corresponde con la elección de habilidad', () {
      expect(repo.race('human')!.skillChoiceCount, 1);
    });

    test('Ingenioso deja de ser solo texto y llega a la ficha', () {
      // El texto sigue estando —el jugador tiene que poder leer el rasgo— y
      // además hay un efecto al lado que el motor sabe aplicar.
      expect(traitOf('human', 'Ingenioso'), contains('descanso largo'));
      expect(
        repo
            .race('human')!
            .effects
            .whereType<HeroicInspirationOnLongRestEffect>(),
        isNotEmpty,
      );
    });

    test('la ficha del humano la gana al descansar y la del elfo no', () {
      ComputedSheet fichaDe(String raceId) =>
          CharacterCompiler(repo).compile(Character(
            id: 'ingenioso-$raceId',
            name: 'Prueba',
            raceId: raceId,
            classId: 'fighter',
            backgroundId: 'soldier',
            level: 1,
            assignedScores: const {
              Ability.strength: 15,
              Ability.dexterity: 12,
              Ability.constitution: 14,
              Ability.intelligence: 10,
              Ability.wisdom: 12,
              Ability.charisma: 8,
            },
            hpPerLevel: const [10],
          ));

      expect(fichaDe('human').heroicInspirationOnLongRest, isTrue);
      expect(fichaDe('elf').heroicInspirationOnLongRest, isFalse);
    });
  });

  group('Aasimar (PHB 2024, fuera del SRD)', () {
    test('Manos Sanadoras tira d4 iguales al bonificador de competencia', () {
      final d = traitOf('aasimar', 'Manos Sanadoras');
      expect(d, contains('d4'));
      expect(d, contains('competencia'));
    });

    test('Portador de Luz concede el truco y Manos Sanadoras tiene recurso',
        () {
      final c = Character(
        id: 'aasimar',
        name: 'Aasimar',
        raceId: 'aasimar',
        classId: 'fighter',
        backgroundId: 'soldier',
        assignedScores: {for (final a in Ability.values) a: 12},
        hpPerLevel: const [10],
      );
      final sheet = CharacterCompiler(repo).compile(c);
      expect(sheet.innateSpells.map((s) => s.spellId), contains('light'));
      expect(sheet.resources.map((r) => r.id), contains('healing_hands'));
    });
  });

  test('cada especie conserva su tipo de criatura estructurado', () {
    expect(repo.race('human')!.creatureType, 'Humanoide');
    expect(repo.race('changeling')!.creatureType, 'Feérico');
    expect(repo.race('kalashtar')!.creatureType, 'Aberración');
    expect(repo.race('warforged')!.creatureType, 'Autómata');
  });

  group('Tiefling', () {});

  group('Goliat', () {
    test('Constitución Poderosa usa la regla 2024', () {
      final d = traitOf('goliath', 'Constitución Poderosa');
      expect(d, contains('terminar el estado agarrado'));
      expect(d, contains('capacidad de carga'));
      expect(d, isNot(contains('empujar')));
    });

    test('Forma Grande concede Fuerza y velocidad', () {
      final d = traitOf('goliath', 'Forma Grande (nivel 5)');
      expect(d, contains('ventaja en las pruebas de Fuerza'));
      expect(d, contains('velocidad aumenta 10 pies'));
    });
  });
}
