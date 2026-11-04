import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Lo que una auditoría contra el PHB 2024 marcó como reglas mal guardadas o
/// ausentes. Cada caso fija el comportamiento, no un arreglo puntual.
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  Character pj({
    required String classId,
    String? subclassId,
    String raceId = 'human',
    String? lineageId,
    Ability? speciesSpellcastingAbility,
    int level = 3,
    int wisdom = 10,
    int charisma = 10,
    Map<String, List<String>> proficiencyChoices = const {},
  }) =>
      Character(
        id: 'auditoria',
        name: 'Prueba',
        raceId: raceId,
        lineageId: lineageId,
        speciesSpellcastingAbility: speciesSpellcastingAbility,
        classId: classId,
        subclassId: subclassId,
        backgroundId: 'soldier',
        level: level,
        assignedScores: {
          for (final a in Ability.values)
            a: switch (a) {
              Ability.wisdom => wisdom,
              Ability.charisma => charisma,
              _ => 10,
            },
        },
        hpPerLevel: List.filled(level, 8),
        proficiencyChoices: proficiencyChoices,
      );

  group('inmunidad a estados', () {
    test('el catálogo no guarda un estado como tipo de daño', () {
      final mal = <String>[];
      for (final name in [
        'classes.json',
        'subclasses.json',
        'feats.json',
        'races.json',
        'lineages.json',
        'magic_items.json',
      ]) {
        final raw = jsonDecode(
          File('lib/assets/srd_2024/$name').readAsStringSync(),
        );
        void walk(Object? node) {
          if (node is Map) {
            if (node['type'] == 'immunity' &&
                conditionIds.contains(node['damageType'])) {
              mal.add('$name: ${node['damageType']}');
            }
            for (final value in node.values) {
              walk(value);
            }
          } else if (node is List) {
            for (final value in node) {
              walk(value);
            }
          }
        }

        walk(raw);
      }
      expect(mal, isEmpty);
    });

    test('la Furia Irracional solo inmuniza mientras dura la Furia', () {
      final c = pj(classId: 'barbarian', subclassId: 'berserker', level: 6);
      final quieto = compiler.compile(c);
      expect(quieto.conditionImmunities, isNot(contains('charmed')));
      expect(quieto.immunities, isNot(contains('charmed')));

      CombatOps.activateMode(c.combat, quieto, 'rage');
      final furia = compiler.compile(c);
      expect(furia.conditionImmunities, containsAll(['charmed', 'frightened']));
      expect(furia.immunities, isNot(contains('frightened')));
    });

    test('el Alquimista es inmune al estado envenenado, no al daño', () {
      ComputedSheet hoja(int level) => compiler.compile(
          pj(classId: 'artificer', subclassId: 'alchemist', level: level));
      expect(hoja(14).conditionImmunities, isNot(contains('poisoned')));
      final quince = hoja(15);
      expect(quince.conditionImmunities, contains('poisoned'));
      expect(quince.resistances, containsAll(['acid', 'poison']));
      expect(quince.immunities, isNot(contains('poison')));
      expect(quince.immunities, isNot(contains('poisoned')));
    });
  });

  group('aptitud mágica de especie', () {
    InnateSpell de(ComputedSheet s, String spellId) =>
        s.innateSpells.firstWhere((spell) => spell.spellId == spellId);

    test('sin elección se conserva la aptitud que declara el contenido', () {
      // Una ficha guardada antes del campo no lo trae: el compilador deja la
      // del linaje, así que el número no cambia.
      expect(
        de(
                compiler.compile(pj(
                    classId: 'fighter',
                    raceId: 'elf',
                    lineageId: 'elf-drow',
                    level: 1)),
                'dancing-lights')
            .ability,
        Ability.charisma,
      );
      expect(
        de(
                compiler.compile(pj(
                    classId: 'fighter',
                    raceId: 'elf',
                    lineageId: 'elf-high',
                    level: 1)),
                'prestidigitation')
            .ability,
        Ability.intelligence,
      );
      expect(
        de(
                compiler.compile(pj(
                    classId: 'fighter',
                    raceId: 'elf',
                    lineageId: 'elf-wood',
                    level: 1)),
                'druidcraft')
            .ability,
        Ability.wisdom,
      );
      expect(
        de(
                compiler.compile(pj(
                    classId: 'fighter',
                    raceId: 'gnome',
                    lineageId: 'gnome-forest',
                    level: 1)),
                'minor-illusion')
            .ability,
        Ability.intelligence,
      );
      expect(
        de(
                compiler.compile(pj(
                    classId: 'fighter',
                    raceId: 'gnome',
                    lineageId: 'gnome-rock',
                    level: 1)),
                'mending')
            .ability,
        Ability.intelligence,
      );
      expect(
        de(
                compiler.compile(pj(
                    classId: 'fighter',
                    raceId: 'tiefling',
                    lineageId: 'tiefling-infernal',
                    level: 1)),
                'thaumaturgy')
            .ability,
        Ability.charisma,
      );
    });

    test('la elección pisa la del linaje y la de la especie', () {
      final hoja = compiler.compile(pj(
        classId: 'fighter',
        raceId: 'tiefling',
        lineageId: 'tiefling-infernal',
        speciesSpellcastingAbility: Ability.wisdom,
        level: 1,
        wisdom: 16,
      ));
      expect(de(hoja, 'thaumaturgy').ability, Ability.wisdom);
      expect(de(hoja, 'fire-bolt').ability, Ability.wisdom);
      // SAB 16 (+3), competencia +2 → CD 13. El contenido decía Carisma.
      expect(de(hoja, 'thaumaturgy').saveDc, 13);
    });
  });

  group('rasgos de subclase que faltaban', () {
    test('Manto de Majestad deja Orden siempre preparado', () {
      final antes = compiler.compile(
          pj(classId: 'bard', subclassId: 'college-glamour', level: 5));
      final despues = compiler.compile(
          pj(classId: 'bard', subclassId: 'college-glamour', level: 6));
      expect(antes.alwaysPreparedSpellIds, isNot(contains('command')));
      expect(despues.alwaysPreparedSpellIds, contains('command'));
    });

    test('el Mapa Estelar lanza Saeta Guía sin espacio, mod. de Sabiduría', () {
      CharacterResource usos(int wisdom) => compiler
          .compile(
              pj(classId: 'druid', subclassId: 'circle-stars', wisdom: wisdom))
          .resources
          .firstWhere((r) => r.id == innateSpellResourceId('guiding-bolt'));

      final alta = compiler.compile(
          pj(classId: 'druid', subclassId: 'circle-stars', wisdom: 16));
      expect(alta.alwaysPreparedSpellIds,
          containsAll(['guidance', 'guiding-bolt']));
      final saeta =
          alta.innateSpells.firstWhere((s) => s.spellId == 'guiding-bolt');
      expect(saeta.use, InnateSpellUse.abilityModifierPerLongRest);
      expect(saeta.freeUses, 3);
      expect(usos(16).max, 3);
      expect(usos(16).recharge, RechargeOn.longRest);
      // SAB 8 es −1: el rasgo dice mínimo una.
      expect(usos(8).max, 1);
    });

    test('Implementos de la Misericordia da Perspicacia, Medicina y herborista',
        () {
      final antes = compiler
          .compile(pj(classId: 'monk', subclassId: 'warrior-mercy', level: 2));
      final hoja =
          compiler.compile(pj(classId: 'monk', subclassId: 'warrior-mercy'));
      expect(antes.skillProficiencies, isNot(contains('medicine')));
      expect(hoja.skillProficiencies, containsAll(['insight', 'medicine']));
      expect(hoja.toolProficiencies, contains('herbalism-kit'));
    });

    test('Glamour de Otro Mundo suma Sabiduría a Carisma y una habilidad', () {
      final grupo = 'subclass:fey-wanderer:glamour';
      final sinElegir = compiler.compile(pj(
        classId: 'ranger',
        subclassId: 'fey-wanderer',
        wisdom: 16,
        charisma: 10,
      ));
      final cupo = sinElegir.proficiencyChoiceSlots
          .singleWhere((s) => s.groupId == grupo);
      expect(cupo.skills, ['deception', 'performance', 'persuasion']);
      expect(cupo.count, 1);
      // Todavía no eligió, pero el bono a las pruebas ya está.
      expect(sinElegir.abilityCheck(Ability.charisma), 3);
      expect(sinElegir.savingThrow(Ability.charisma), 0);
      expect(sinElegir.skillModifier('persuasion'), 3);

      final elegido = compiler.compile(pj(
        classId: 'ranger',
        subclassId: 'fey-wanderer',
        wisdom: 16,
        charisma: 10,
        proficiencyChoices: {
          grupo: ['performance']
        },
      ));
      expect(elegido.skillProficiencies, contains('performance'));
      expect(elegido.skillProficiencies, isNot(contains('deception')));
      // Competencia +2 a nivel 3, más el +3 de Sabiduría, sobre Carisma 10.
      expect(elegido.skillModifier('performance'), 5);
      expect(elegido.savingThrow(Ability.charisma), 0);

      final piso = compiler.compile(pj(
        classId: 'ranger',
        subclassId: 'fey-wanderer',
        wisdom: 8,
        charisma: 10,
      ));
      // SAB 8 es −1 y el mínimo del rasgo es +1: la prueba queda en +1.
      expect(piso.abilityCheck(Ability.charisma), 1);
      expect(piso.savingThrow(Ability.charisma), 0);
    });
  });

  group('Versátil del Humano', () {
    test('la dote de origen no acepta una general', () {
      final d = CreationDraft(repo)..selectRace('human');
      expect(d.originFeatOptions, isNotEmpty);
      expect(
        d.originFeatOptions.map((f) => f.category),
        everyElement('origin'),
      );
      expect(
        d.originFeatOptions.map((f) => f.id),
        isNot(contains('great-weapon-master')),
      );

      d.toggleRaceFeat('great-weapon-master');
      expect(d.raceFeatId, isNull);
      expect(
        d.pendingIn(CreationSection.proficiencies).map((p) => p.kind),
        contains(CreationPendingKind.originFeat),
      );

      d.toggleRaceFeat('skilled');
      expect(d.raceFeatId, 'skilled');
      expect(d.build().featIds, ['skilled']);

      d.raceFeatId = 'great-weapon-master';
      expect(d.build().featIds, isEmpty);

      final restaurado = CreationDraft.fromJson(repo, {
        'raceId': 'human',
        'raceFeatId': 'great-weapon-master',
      });
      expect(restaurado.raceFeatId, isNull);
      final origen = CreationDraft.fromJson(repo, {
        'raceId': 'human',
        'raceFeatId': 'alert',
      });
      expect(origen.raceFeatId, 'alert');
    });
  });
}
