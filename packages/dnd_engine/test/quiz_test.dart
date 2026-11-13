import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Rondas del Quiz contra el SRD real: cada pregunta tiene que ser
/// contestable (4 opciones distintas, la correcta en rango) y la respuesta
/// tiene que coincidir con el catálogo, no con un literal.
void main() {
  late ContentRepository repo;

  /// El catálogo contra el que se lee la respuesta. En la prueba en inglés
  /// es la superposición: los nombres ya no son los del español.
  late ContentRepository fuente;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    fuente = repo;
  });

  Character personaje(CharacterClass cls, int level, String raceId, String bg) {
    final subs = fuente.subclassesForClass(cls.id);
    final hechizos = fuente.spellsSorted.where(
      (s) => s.classes.contains(cls.id),
    );
    return Character(
      id: 'q-${cls.id}',
      name: 'Prueba',
      raceId: raceId,
      classId: cls.id,
      backgroundId: bg,
      level: level,
      subclassId:
          level >= cls.subclassLevel && subs.isNotEmpty ? subs.first.id : null,
      assignedScores: {for (final a in Ability.values) a: 12},
      hpPerLevel: List.filled(level, 6),
      cantripIds: [
        for (final s in hechizos.where((s) => s.level == 0).take(3)) s.id,
      ],
      spellIds: [
        for (final s in hechizos.where((s) => s.level == 1).take(3)) s.id,
      ],
    );
  }

  String sinParentesis(String name) =>
      name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

  /// Lo que dice el catálogo de la respuesta correcta, derivado de la pregunta.
  ///
  /// [cita] revisa que ninguna opción esté nombrada en el texto. Se apaga al
  /// retraducir: una cita en inglés puede nombrar un distractor que en
  /// español no estaba, y cambiar la opción cambiaría la ronda ya empezada.
  void verificar(QuizQuestion q, Character? c, {bool cita = true}) {
    final n = q.kind == QuizKind.armorCategory ? 3 : 4;
    expect(q.options, hasLength(n), reason: q.kind.name);
    expect(q.options.toSet(), hasLength(n));
    expect(q.answer, inInclusiveRange(0, n - 1));
    expect(q.key, isNotEmpty);
    final correcta = q.options[q.answer];
    if (cita && q.quote != null) {
      final cita = q.quote!.toLowerCase();
      for (final opcion in q.options) {
        final base = sinParentesis(opcion).toLowerCase();
        if (base.length >= 4) {
          expect(
            cita.contains(base),
            isFalse,
            reason: '${q.kind.name} «$opcion» en «${q.quote}»',
          );
        }
        for (final m in RegExp(r'\(([^)]+)\)').allMatches(opcion)) {
          final adentro = m.group(1)!.trim().toLowerCase();
          if (adentro.length >= 4) {
            expect(
              cita.contains(adentro),
              isFalse,
              reason: '${q.kind.name} ($adentro) en «${q.quote}»',
            );
          }
        }
      }
    }
    switch (q.kind) {
      case QuizKind.condition:
        expect(correcta, conditionLabel(q.subjectId!));
        const ajenos = {
          'incapacitated': ['stunned', 'paralyzed', 'petrified', 'unconscious'],
          'stunned': ['paralyzed', 'petrified', 'unconscious'],
          'paralyzed': ['unconscious', 'incapacitated'],
          'prone': ['unconscious'],
          'petrified': ['incapacitated', 'poisoned'],
          'unconscious': ['incapacitated', 'prone'],
        };
        for (final id in ajenos[q.subjectId] ?? const <String>[]) {
          expect(q.options, isNot(contains(conditionLabel(id))));
        }
      case QuizKind.spellCastingTime:
        final s = fuente.spell(q.subjectId!)!;
        expect(
          correcta,
          vocabularyLabel(VocabularyField.castingTime, s.castingTime),
        );
      case QuizKind.spellRange:
        final s = fuente.spell(q.subjectId!)!;
        expect(correcta, vocabularyLabel(VocabularyField.range, s.range));
        final rango = s.range;
        if (rango == 'Personal' || rango.startsWith('Personal (')) {
          final pelado = q.options.any((o) => o == 'Personal' || o == 'Self');
          final conForma = q.options.any(
            (o) => o.startsWith('Personal (') || o.startsWith('Self ('),
          );
          expect(pelado && conForma, isFalse, reason: q.options.join(' | '));
        }
      case QuizKind.spellSchool:
        final s = fuente.spell(q.subjectId!)!;
        expect(correcta, vocabularyLabel(VocabularyField.school, s.school));
      case QuizKind.hitDie:
        expect(correcta, 'd${fuente.characterClass(q.subjectId!)!.hitDie}');
      case QuizKind.savingThrows:
        final k = fuente.characterClass(q.subjectId!)!;
        for (final a in k.savingThrows) {
          expect(correcta, contains(a.label));
        }
      case QuizKind.backgroundSkills:
        final b = fuente.background(q.subjectId!)!;
        for (final s in b.skillProficiencies) {
          expect(correcta, contains(Skill.labelFor(s)));
        }
      case QuizKind.backgroundFeat:
        final b = fuente.background(q.subjectId!)!;
        expect(correcta, fuente.feat(b.originFeatId!)!.name);
      case QuizKind.classFeatureLevel:
        final cls = fuente.characterClass(q.subjectId!)!;
        final f = cls.features.where((f) => f.name == q.subject);
        expect(f.map((f) => f.level), contains(q.level));
        expect(correcta, '${q.level}');
      case QuizKind.skillAbility:
        expect(correcta, Skill.fromId(q.subjectId!)!.ability.label);
        expect(q.options, isNot(contains('Constitución')));
        expect(q.options, isNot(contains('Constitution')));
      case QuizKind.weaponMastery:
        expect(
          correcta,
          weaponMasteryName(fuente.weapon(q.subjectId!)!.mastery!),
        );
      case QuizKind.weaponDamage:
        final w = fuente.weapon(q.subjectId!)!;
        expect(correcta, startsWith('${w.damageDice} '));
        expect(
          correcta,
          endsWith(DamageType.labelFor(w.damageType).toLowerCase()),
        );
        if (w.versatileDice != null) {
          final versatil =
              '${w.versatileDice} ${DamageType.labelFor(w.damageType).toLowerCase()}';
          expect(
            q.options.where((o) => o == versatil || o == correcta).toList(),
            [correcta],
          );
        }
      case QuizKind.armorAc:
        final a = fuente.armorPiece(q.subjectId!)!;
        if (!a.addDexMod) {
          expect(correcta, '${a.baseAc}');
        } else if (a.maxDexBonus == null) {
          expect(
            correcta,
            anyOf(
              '${a.baseAc} + tu modificador de Destreza',
              '${a.baseAc} + your Dexterity modifier',
            ),
          );
        } else {
          expect(
            correcta,
            anyOf(
              '${a.baseAc} + tu modificador de Destreza (máx. ${a.maxDexBonus})',
              '${a.baseAc} + your Dexterity modifier (max ${a.maxDexBonus})',
            ),
          );
        }
      case QuizKind.armorCategory:
        expect(
          correcta,
          armorTrainingLabel(fuente.armorPiece(q.subjectId!)!.category),
        );
        expect(q.options, isNot(contains(armorTrainingLabel('shield'))));
      case QuizKind.masteryByText:
        expect(correcta, weaponMasteries[q.subjectId!]!.name);
        expect(q.quote, weaponMasteries[q.subjectId!]!.description);
      case QuizKind.propertyByText:
        expect(correcta, weaponProperties[q.subjectId!]!.name);
        expect(q.quote, weaponProperties[q.subjectId!]!.description);
      case QuizKind.classFeatureByText:
      case QuizKind.speciesTraitByText:
        expect(q.quote, isNotEmpty);
        expect(q.quote!.toLowerCase(), isNot(contains(correcta.toLowerCase())));
        if (q.kind == QuizKind.speciesTraitByText) {
          for (final tipo in const [
            'Humanoide',
            'Feérico',
            'Aberración',
            'Humanoid',
            'Fey',
            'Aberration',
          ]) {
            expect(q.options, isNot(contains(tipo)));
          }
        }
    }
  }

  void verificarRonda(List<QuizQuestion> ronda, Character? c,
      {bool cita = true}) {
    expect(ronda, isNotEmpty);
    // Sin tema repetido: el mismo conjuro o rasgo no sale dos veces.
    final temas = [
      for (final q in ronda)
        q.kind == QuizKind.classFeatureByText ||
                q.kind == QuizKind.speciesTraitByText
            ? q.options[q.answer]
            : q.kind == QuizKind.classFeatureLevel
                ? q.subject
                : q.topic == QuizTopic.spells
                    ? q.subjectId
                    : '${q.kind.name}:${q.subjectId}',
    ];
    expect(temas.toSet(), hasLength(temas.length));
    if (c != null) {
      final porTipo = <QuizKind, int>{};
      for (final q in ronda) {
        porTipo[q.kind] = (porTipo[q.kind] ?? 0) + 1;
      }
      expect(porTipo.values.every((n) => n <= 3), isTrue);
    }
    for (final q in ronda) {
      verificar(q, c, cita: cita);
    }
  }

  test('rondas de personajes de todas las clases a nivel 1 y 5', () {
    for (final cls in fuente.classesSorted) {
      for (final level in [1, 5]) {
        final c = personaje(
          cls,
          level,
          level == 1 ? 'human' : 'aasimar',
          level == 1 ? 'sage' : 'soldier',
        );
        for (final seed in [1, 2, 3]) {
          final ronda = quizRound(c, repo, seed: seed);
          verificarRonda(ronda, c);
          expect(
            ronda.length,
            greaterThanOrEqualTo(7),
            reason: '${cls.id} $level semilla $seed',
          );
        }
      }
    }
  });

  test('la ronda de reglas llega a diez y mezcla temas', () {
    for (final seed in [7, 8, 9]) {
      final ronda = quizRound(null, repo, seed: seed);
      expect(ronda, hasLength(10));
      expect(ronda.map((q) => q.kind).toSet().length, greaterThan(3));
      verificarRonda(ronda, null);
    }
  });

  test('la misma semilla da la misma ronda y otra da otra', () {
    final c = personaje(
      fuente.characterClass('warlock')!,
      5,
      'aasimar',
      'sage',
    );
    List<Map<String, dynamic>> json(int seed) => [
          for (final q in quizRound(c, repo, seed: seed)) q.toJson(),
        ];
    expect(json(11), json(11));
    expect(json(11), isNot(json(12)));
  });

  test('un nivel 1 puede preguntar por un rasgo que todavía no tiene', () {
    final c = personaje(
      fuente.characterClass('fighter')!,
      1,
      'human',
      'soldier',
    );
    final niveles = [
      for (final seed in List.generate(30, (i) => i))
        for (final q in quizRound(c, repo, seed: seed))
          if (q.kind == QuizKind.classFeatureLevel) q.level!,
    ];
    expect(niveles.any((n) => n > 1), isTrue);
  });

  test(
    'en multiclase el dado y las salvaciones son de la clase que se nombra',
    () {
      final c = personaje(
        fuente.characterClass('fighter')!,
        1,
        'human',
        'soldier',
      ).copyWith(classHistory: const ['fighter', 'fighter', 'wizard']);
      final vistos = <String>{};
      for (final seed in List.generate(40, (i) => i)) {
        for (final q in quizRound(c, repo, seed: seed)) {
          if (q.kind != QuizKind.hitDie && q.kind != QuizKind.savingThrows) {
            continue;
          }
          vistos.add('${q.kind.name}:${q.subjectId}');
          final cls = fuente.characterClass(q.subjectId!)!;
          expect(q.subject, cls.name);
          if (q.kind == QuizKind.hitDie) {
            expect(q.options[q.answer], 'd${cls.hitDie}');
          } else {
            for (final a in cls.savingThrows) {
              expect(q.options[q.answer], contains(a.label));
            }
          }
        }
      }
      expect(vistos, contains('hitDie:wizard'));
      expect(vistos, contains('savingThrows:wizard'));
      expect(vistos, contains('hitDie:fighter'));
    },
  );

  test(
    'la magia del legado del tiefling nombra un conjuro distinto en cada nivel',
    () {
      for (final id in [
        'tiefling-abyssal',
        'tiefling-chthonic',
        'tiefling-infernal',
      ]) {
        final rasgos = fuente.lineage(id)!.features.where((f) => f.level > 1);
        final textos = rasgos.map((f) => f.description).toSet();
        expect(textos, hasLength(rasgos.length), reason: id);
        for (final f in rasgos) {
          expect(f.description.toLowerCase(), isNot(contains('un conjuro')));
        }
      }
    },
  );

  test('la misma semilla elige las mismas preguntas en inglés', () async {
    final en = await ContentRepository.loadFromDirectory(
      'lib/assets/srd_2024',
      translation: 'en',
    );
    addTearDown(() => ContentLanguage.current = ContentLanguage.es);
    String firma(QuizQuestion q) =>
        '${q.kind.name}|${q.key}|${q.answer}|${q.options.length}';
    final c = personaje(
      fuente.characterClass('wizard')!,
      5,
      'tiefling',
      'sage',
    ).copyWith(lineageId: 'tiefling-infernal');
    List<QuizQuestion> enDe(List<QuizQuestion> esRonda) {
      ContentLanguage.current = ContentLanguage.en;
      return quizLocalize([for (final q in esRonda) q.toJson()], en);
    }

    for (final seed in [1, 4, 11]) {
      ContentLanguage.current = ContentLanguage.es;
      final esRonda = quizRound(c, repo, seed: seed);
      final enRonda = enDe(esRonda);
      expect(
        enRonda.map(firma).toList(),
        esRonda.map(firma).toList(),
        reason: 'personaje $seed',
      );
      expect(
        enRonda.map((q) => q.optionIds).toList(),
        esRonda.map((q) => q.optionIds).toList(),
      );
      fuente = en;
      verificarRonda(enRonda, c, cita: false);
      fuente = repo;
      ContentLanguage.current = ContentLanguage.es;
    }
    for (final seed in [7, 8]) {
      ContentLanguage.current = ContentLanguage.es;
      final esRonda = quizRound(null, repo, seed: seed);
      final enRonda = enDe(esRonda);
      expect(
        enRonda.map(firma).toList(),
        esRonda.map(firma).toList(),
        reason: 'reglas $seed',
      );
      fuente = en;
      verificarRonda(enRonda, null, cita: false);
      fuente = repo;
      ContentLanguage.current = ContentLanguage.en;
      fuente = en;
      verificarRonda(quizRound(null, en, seed: seed), null);
      fuente = repo;
      ContentLanguage.current = ContentLanguage.es;
    }
    for (final id in [
      'tiefling-abyssal',
      'tiefling-chthonic',
      'tiefling-infernal',
    ]) {
      final rasgos = en.lineage(id)!.features.where((f) => f.level > 1);
      expect(
        rasgos.map((f) => f.description).toSet(),
        hasLength(rasgos.length),
        reason: id,
      );
    }
  });
}
