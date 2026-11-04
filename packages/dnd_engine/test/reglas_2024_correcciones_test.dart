import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Regresiones de las correcciones contra el PHB 2024: piso de PG, Resistencia
/// Dracónica, columnas de preparados, trucos por nivel de clase y competencias
/// de multiclase.
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  Character pj({
    required String classId,
    required List<int> hp,
    int constitution = 10,
    String raceId = 'human',
    List<String>? classHistory,
    Map<String, String> subclassIds = const {},
    List<String> featIds = const [],
    Map<String, List<String>> proficiencyChoices = const {},
  }) {
    final history = classHistory ?? List.filled(hp.length, classId);
    return Character(
      id: 'reglas-$classId',
      name: 'Prueba',
      raceId: raceId,
      classId: history.first,
      backgroundId: '',
      classHistory: history,
      subclassIds: subclassIds,
      assignedScores: {
        for (final ability in Ability.values)
          ability: ability == Ability.constitution ? constitution : 10,
      },
      hpPerLevel: hp,
      featIds: featIds,
      proficiencyChoices: proficiencyChoices,
    );
  }

  SpellcastingBlock bloque(ComputedSheet sheet, String classId) =>
      sheet.spellcastingBlocks.firstWhere((block) => block.classId == classId);

  group('PG: mínimo 1 por nivel', () {
    test(
      'CON 6 y dados de 1 no bajan los PG, y el CON nuevo se aplica atrás',
      () {
        final bajo = compiler.compile(
          pj(classId: 'wizard', hp: const [1, 1, 1], constitution: 6),
        );
        expect(bajo.abilityScores[Ability.constitution], 6);
        expect(bajo.abilityModifiers[Ability.constitution], -2);
        // max(1, 1 − 2) por nivel. Sin el piso serían 3 + (−2)×3 = −3.
        expect(bajo.maxHp, 3);

        final subido = compiler.compile(
          pj(classId: 'wizard', hp: const [1, 1, 1], constitution: 14),
        );
        expect(subido.abilityModifiers[Ability.constitution], 2);
        // Los mismos dados, con +2: max(1, 1 + 2) = 3 por nivel.
        expect(subido.maxHp, 9);
      },
    );

    test(
      'el CON negativo sigue restando cuando el dado queda por encima de 1',
      () {
        final sheet = compiler.compile(
          pj(classId: 'wizard', hp: const [4, 4, 4], constitution: 6),
        );
        // max(1, 4 − 2) = 2. El piso no anula el modificador.
        expect(sheet.maxHp, 6);
      },
    );

    test('Duro y Dureza Enana se suman después del piso, por nivel total', () {
      final base = compiler.compile(
        pj(classId: 'wizard', hp: const [1, 1, 1], constitution: 6),
      );
      final duro = compiler.compile(
        pj(
          classId: 'wizard',
          hp: const [1, 1, 1],
          constitution: 6,
          featIds: const ['tough'],
        ),
      );
      final enano = compiler.compile(
        pj(
          classId: 'wizard',
          hp: const [1, 1, 1],
          constitution: 6,
          raceId: 'dwarf',
        ),
      );
      expect(base.maxHp, 3);
      expect(duro.maxHp, 9); // 3 del piso + 2 × 3 de Duro
      expect(enano.abilityScores[Ability.constitution], 6);
      expect(enano.maxHp, 6); // 3 del piso + 1 × 3 de Dureza Enana
    });
  });

  group('Resistencia Dracónica', () {
    Character guerreroHechicero(
      int nivelesHechicero, {
      bool draconico = true,
      List<String> featIds = const [],
    }) {
      final history = [
        ...List.filled(10, 'fighter'),
        ...List.filled(nivelesHechicero, 'sorcerer'),
      ];
      return pj(
        classId: 'fighter',
        hp: List.filled(history.length, 6),
        constitution: 14,
        classHistory: history,
        subclassIds:
            draconico ? const {'sorcerer': 'draconic-sorcery'} : const {},
        featIds: featIds,
      );
    }

    test('escala con el nivel de Hechicero, no con el del personaje', () {
      final sin3 = compiler.compile(guerreroHechicero(3, draconico: false));
      final con3 = compiler.compile(guerreroHechicero(3));
      final con5 = compiler.compile(guerreroHechicero(5));
      final sin5 = compiler.compile(guerreroHechicero(5, draconico: false));
      // +3 al nivel 3 y +1 por cada nivel de Hechicero posterior: es el
      // nivel de Hechicero. Con el nivel total, el 10/3 sumaría 13.
      expect(con3.maxHp - sin3.maxHp, 3);
      expect(con5.maxHp - sin5.maxHp, 5);
    });

    test('Duro sigue sumando el nivel de personaje al lado del rasgo', () {
      final sin = compiler.compile(guerreroHechicero(3, draconico: false));
      final con = compiler.compile(guerreroHechicero(3));
      final duro = compiler.compile(
        guerreroHechicero(3, featIds: const ['tough']),
      );
      expect(con.maxHp - sin.maxHp, 3);
      expect(duro.maxHp - con.maxHp, 2 * 13);
    });
  });

  group('conjuros preparados', () {
    // Columnas del PHB 2024, niveles 1..20.
    const clerigo = [
      4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, //
      17, 17, 18, 18, 19, 20, 21, 22,
    ];
    const mago = [
      4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, //
      17, 18, 19, 21, 22, 23, 24, 25,
    ];
    const hechicero = [
      2, 4, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, //
      17, 17, 18, 18, 19, 20, 21, 22,
    ];

    int preparados(String classId, int level) => compiler
        .compile(
          pj(classId: classId, hp: List.filled(level, 5), constitution: 14),
        )
        .spellcasting!
        .preparedCount;

    test('Clérigo, Druida y Bardo comparten la columna; el Mago no', () {
      for (var level = 1; level <= 20; level++) {
        final esperado = clerigo[level - 1];
        expect(preparados('cleric', level), esperado, reason: 'clérigo $level');
        expect(preparados('druid', level), esperado, reason: 'druida $level');
        expect(preparados('bard', level), esperado, reason: 'bardo $level');
        expect(
          preparados('wizard', level),
          mago[level - 1],
          reason: 'mago $level',
        );
      }
      expect(preparados('cleric', 20), isNot(preparados('wizard', 20)));
    });

    test('el Hechicero arranca en 2 y desde el 14 sigue a Clérigo, no a Mago',
        () {
      for (var level = 1; level <= 20; level++) {
        expect(
          preparados('sorcerer', level),
          hechicero[level - 1],
          reason: 'hechicero $level',
        );
      }
      // En el 13 los tres valen 17. La columna del Mago se aparta desde el 14.
      for (final level in [14, 16, 20]) {
        expect(
          preparados('sorcerer', level),
          preparados('cleric', level),
          reason: 'nivel $level',
        );
        expect(
          preparados('sorcerer', level),
          isNot(preparados('wizard', level)),
          reason: 'nivel $level',
        );
      }
    });
  });

  group('trucos por nivel de clase', () {
    test('Guerrero 9 / Mago 1 conoce 3 trucos de Mago', () {
      final sheet = compiler.compile(
        pj(
          classId: 'fighter',
          hp: List.filled(10, 6),
          classHistory: [...List.filled(9, 'fighter'), 'wizard'],
        ),
      );
      expect(bloque(sheet, 'wizard').classLevel, 1);
      expect(bloque(sheet, 'wizard').spellcasting.cantripsKnown, 3);
    });

    test('el de un tercio y el Mago no se llevan el truco del nivel total', () {
      final sheet = compiler.compile(
        pj(
          classId: 'wizard',
          hp: List.filled(11, 5),
          classHistory: [
            ...List.filled(8, 'wizard'),
            ...List.filled(3, 'fighter'),
          ],
          subclassIds: const {'fighter': 'eldritch-knight'},
        ),
      );
      // Mago 8: base 3 + el del nivel 4. Caballero 3: base 2, el extra es
      // al nivel 10 de Guerrero. El nivel total (11) no alcanza para ninguno.
      expect(bloque(sheet, 'wizard').spellcasting.cantripsKnown, 4);
      expect(bloque(sheet, 'fighter').spellcasting.cantripsKnown, 2);

      final picaro = compiler.compile(
        pj(
          classId: 'wizard',
          hp: List.filled(12, 5),
          classHistory: [
            ...List.filled(9, 'wizard'),
            ...List.filled(3, 'rogue'),
          ],
          subclassIds: const {'rogue': 'arcane-trickster'},
        ),
      );
      expect(bloque(picaro, 'rogue').spellcasting.cantripsKnown, 3);
    });

    test('el Artífice sigue usando su nivel de clase (10 y 14)', () {
      final bajo = compiler.compile(
        pj(
          classId: 'artificer',
          hp: List.filled(15, 5),
          classHistory: [
            ...List.filled(9, 'artificer'),
            ...List.filled(6, 'fighter'),
          ],
        ),
      );
      expect(bloque(bajo, 'artificer').spellcasting.cantripsKnown, 2);

      final alto = compiler.compile(
        pj(
          classId: 'artificer',
          hp: List.filled(11, 5),
          classHistory: [...List.filled(10, 'artificer'), 'fighter'],
        ),
      );
      expect(bloque(alto, 'artificer').spellcasting.cantripsKnown, 3);
    });
  });

  group('competencias de multiclase', () {
    Character magoMas(
      String clase, {
      Map<String, List<String>> elecciones = const {},
    }) =>
        pj(
          classId: 'wizard',
          hp: const [6, 8],
          classHistory: ['wizard', clase],
          proficiencyChoices: elecciones,
        );

    test('el Druida da ligera y escudo, sin media', () {
      final sheet = compiler.compile(magoMas('druid'));
      expect(sheet.armorProficiencies, containsAll(['light', 'shield']));
      expect(sheet.armorProficiencies, isNot(contains('medium')));
    });

    test('el Monje no agrega armas ni armadura', () {
      final solo = compiler.compile(pj(classId: 'wizard', hp: const [6]));
      final conMonje = compiler.compile(magoMas('monk'));
      expect(conMonje.armorProficiencies, solo.armorProficiencies);
      expect(conMonje.weaponProficiencies, solo.weaponProficiencies);
    });

    test(
      'el Pícaro da ligera, Herramientas de Ladrón y una habilidad, sin armas',
      () {
        final reglas = repo.characterClass('rogue')!.multiclass!;
        final sheet = compiler.compile(magoMas('rogue'));
        expect(sheet.armorProficiencies, contains('light'));
        expect(sheet.toolProficiencies, contains('thieves-tools'));
        expect(sheet.weaponProficiencies, isNot(contains('martial-finesse')));
        expect(sheet.weaponProficiencies, isNot(contains('martial-light')));

        final cupo = sheet.proficiencyChoiceSlots.firstWhere(
          (slot) => slot.groupId == 'class:rogue:multiclass-skills',
        );
        expect(cupo.count, 1);
        expect(cupo.skills, reglas.skillChoiceFrom);

        final habilidad = reglas.skillChoiceFrom.first;
        final elegido = compiler.compile(
          magoMas(
            'rogue',
            elecciones: {
              'class:rogue:multiclass-skills': [habilidad],
            },
          ),
        );
        expect(elegido.skillProficiencies, contains(habilidad));

        final ajena = Skill.allIds.firstWhere(
          (id) => !reglas.skillChoiceFrom.contains(id),
        );
        final rechazada = compiler.compile(
          magoMas(
            'rogue',
            elecciones: {
              'class:rogue:multiclass-skills': [ajena],
            },
          ),
        );
        expect(rechazada.skillProficiencies, isNot(contains(ajena)));
      },
    );

    test(
      'el Explorador da sus armas y armaduras, y una habilidad de su lista',
      () {
        final reglas = repo.characterClass('ranger')!.multiclass!;
        final sheet = compiler.compile(magoMas('ranger'));
        expect(
          sheet.armorProficiencies,
          containsAll(['light', 'medium', 'shield']),
        );
        expect(sheet.weaponProficiencies, containsAll(['simple', 'martial']));

        final cupo = sheet.proficiencyChoiceSlots.firstWhere(
          (slot) => slot.groupId == 'class:ranger:multiclass-skills',
        );
        expect(cupo.count, 1);
        expect(cupo.skills, reglas.skillChoiceFrom);
        expect(cupo.skills, repo.characterClass('ranger')!.skillChoiceFrom);

        final habilidad = reglas.skillChoiceFrom.first;
        final elegido = compiler.compile(
          magoMas(
            'ranger',
            elecciones: {
              'class:ranger:multiclass-skills': [habilidad],
            },
          ),
        );
        expect(elegido.skillProficiencies, contains(habilidad));

        final ajena = Skill.allIds.firstWhere(
          (id) => !reglas.skillChoiceFrom.contains(id),
        );
        final rechazada = compiler.compile(
          magoMas(
            'ranger',
            elecciones: {
              'class:ranger:multiclass-skills': [ajena],
            },
          ),
        );
        expect(rechazada.skillProficiencies, isNot(contains(ajena)));
      },
    );
  });
}
