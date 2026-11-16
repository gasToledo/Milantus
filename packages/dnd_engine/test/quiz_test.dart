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
        expect(s.range, isNot('Personal'));
        expect(correcta, vocabularyLabel(VocabularyField.range, s.range));
        expect(correcta, isNot('Personal'));
        expect(correcta, isNot('Self'));
        final rango = s.range;
        if (rango == 'Personal' || rango.startsWith('Personal (')) {
          final pelado = q.options.any((o) => o == 'Personal' || o == 'Self');
          final conForma = q.options.any(
            (o) => o.startsWith('Personal (') || o.startsWith('Self ('),
          );
          expect(pelado && conForma, isFalse, reason: q.options.join(' | '));
        }
      case QuizKind.spellMoveDistance:
        final mover = fuente.spell(q.subjectId!)!;
        expect(mover.moveFeet, isNotNull);
        expect(mover.range, 'Personal');
        expect(
          correcta,
          vocabularyLabel(VocabularyField.range, '${mover.moveFeet} pies'),
        );
      case QuizKind.spellSchool:
        final s = fuente.spell(q.subjectId!)!;
        expect(correcta, vocabularyLabel(VocabularyField.school, s.school));
      case QuizKind.spellLevel:
        final s = fuente.spell(q.subjectId!)!;
        expect(q.optionIds[q.answer], '${s.level}');
        for (final id in q.optionIds) {
          expect((int.parse(id) - s.level).abs(), lessThanOrEqualTo(3));
        }
      case QuizKind.spellFlag:
        // Exactamente una de las cuatro tiene la marca que se pregunta.
        final conMarca = [
          for (final id in q.optionIds)
            if (q.subjectId == 'ritual'
                ? fuente.spell(id)!.ritual
                : fuente.spell(id)!.concentration)
              id,
        ];
        expect(conMarca, [q.optionIds[q.answer]],
            reason: q.options.join(' | '));
      case QuizKind.classSpellList:
        final enLista = [
          for (final id in q.optionIds)
            if (fuente.spell(id)!.classes.contains(q.subjectId)) id,
        ];
        expect(enLista, [q.optionIds[q.answer]], reason: q.options.join(' | '));
        expect(
          {for (final id in q.optionIds) fuente.spell(id)!.level},
          hasLength(1),
        );
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
      case QuizKind.backgroundAbilities:
        final b = fuente.background(q.subjectId!)!;
        for (final a in b.abilityOptions) {
          expect(correcta, contains(a.label));
        }
      case QuizKind.backgroundTool:
        final b = fuente.background(q.subjectId!)!;
        expect(correcta, toolProficiencyLabel(b.toolProficiencies.single));
      case QuizKind.armorTraining:
        final k = fuente.characterClass(q.subjectId!)!;
        const palabras = {
          'light': ['ligera', 'light'],
          'medium': ['media', 'medium'],
          'heavy': ['pesada', 'heavy'],
          'shield': ['escudos', 'shields'],
        };
        final texto = correcta.toLowerCase();
        for (final MapEntry(:key, :value) in palabras.entries) {
          expect(
            value.any(texto.contains),
            k.armorProficiencies.contains(key),
            reason: '${k.id} $correcta',
          );
        }
        if (k.armorProficiencies.isEmpty) {
          expect(correcta, anyOf('Ninguna', 'None'));
        }
      case QuizKind.classSkillChoice:
        final k = fuente.characterClass(q.subjectId!)!;
        final propias = [
          for (final o in q.options)
            if (k.skillChoiceFrom.any((s) => Skill.labelFor(s) == o)) o,
        ];
        expect(propias, [correcta], reason: k.id);
      case QuizKind.classFeatureLevel:
        final cls = fuente.characterClass(q.subjectId!)!;
        expect(q.subject, isNot(contains('(')));
        final rasgos = cls.features.where(
          (f) =>
              f.level == q.level &&
              (f.name == q.subject || f.name.startsWith('${q.subject} (')),
        );
        expect(
          rasgos,
          isNotEmpty,
          reason: '${cls.id} ${q.subject} ${q.level}',
        );
        final progreso = q.progress;
        if (progreso == null) {
          expect(rasgos.any((f) => f.name == q.subject), isTrue);
        } else {
          final conParentesis = rasgos.where((f) => f.name.contains('('));
          expect(conParentesis, isNotEmpty);
          final adentro = RegExp(r'\(([^)]+)\)')
              .firstMatch(conParentesis.first.name)!
              .group(1)!;
          if (progreso.dice != null) {
            expect(adentro, progreso.dice);
          } else if (adentro.startsWith('dos ') || adentro.startsWith('two ')) {
            expect(progreso.n, 2);
          } else {
            expect(
              int.parse(RegExp(r'\d+').firstMatch(adentro)!.group(0)!),
              progreso.n,
            );
          }
        }
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
                q.kind == QuizKind.speciesTraitByText ||
                q.kind == QuizKind.spellFlag
            ? q.options[q.answer]
            : q.kind == QuizKind.classFeatureLevel
                ? '${q.subject}|${q.progress?.kind.name}|${q.progress?.n}|${q.progress?.dice}'
                : q.topic == QuizTopic.spells &&
                        q.kind != QuizKind.classSpellList
                    ? q.subjectId
                    : '${q.kind.name}:${q.subjectId}',
    ];
    expect(temas.toSet(), hasLength(temas.length));
    // Los números se muestran de menor a mayor.
    for (final q in ronda) {
      if (!const {
        QuizKind.classFeatureLevel,
        QuizKind.hitDie,
        QuizKind.armorAc,
      }.contains(q.kind)) {
        continue;
      }
      final primeros = [
        for (final o in q.options)
          int.parse(RegExp(r'\d+').firstMatch(o)!.group(0)!),
      ];
      expect(primeros, [...primeros]..sort(), reason: q.options.join(' | '));
    }
    final respuestas = [
      for (final q in ronda) '${q.kind.name}:${q.optionIds[q.answer]}',
    ];
    expect(respuestas.toSet(), hasLength(respuestas.length));
    expect(
      ronda.where(
        (q) => const {
          QuizKind.skillAbility,
          QuizKind.hitDie,
          QuizKind.savingThrows,
        }.contains(q.kind),
      ),
      hasLength(lessThanOrEqualTo(1)),
    );
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
      // Equipo tiene seis de los ocho tipos: sorteando por tipo se llevaba
      // casi toda la ronda.
      expect(
        ronda.where((q) => q.topic == QuizTopic.equipment).length,
        lessThanOrEqualTo(6),
      );
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

  /// Sin [seed], las de dieciséis semillas: la ronda no repite el nivel que
  /// responde, así que una sola no recorre todas las filas.
  List<QuizQuestion> nivelesDe(CharacterClass cls, {int? seed}) => [
        for (final s in seed == null ? List.generate(16, (i) => i + 1) : [seed])
          for (final q in quizRound(
            personaje(cls, 20, 'human', 'soldier'),
            repo,
            seed: s,
            count: 400,
          ))
            if (q.kind == QuizKind.classFeatureLevel) q,
      ];

  QuizQuestion fila(
    List<QuizQuestion> preguntas,
    String subject,
    QuizProgressKind kind,
    int n,
  ) =>
      preguntas.firstWhere(
        (q) =>
            q.subject == subject &&
            q.progress?.kind == kind &&
            q.progress?.n == n,
      );

  test('las progresiones preguntan el contador y no otro nivel vigente', () {
    final vistos = <String>{};
    for (final cls in fuente.classesSorted) {
      for (final q in nivelesDe(cls)) {
        expect(q.subject, isNot(contains('(')), reason: q.subject);
        final p = q.progress;
        if (p == null) continue;
        vistos.add('${q.subjectId}|${q.level}|${p.kind.name}|${p.n}|${p.dice}');
        // Un nivel donde ese número sigue vigente no puede ser distractor.
        final clsRepo = fuente.characterClass(q.subjectId!)!;
        final siguientes = clsRepo.features.where((f) {
          if (f.level <= q.level!) return false;
          if (!f.name.startsWith('${q.subject} (')) return false;
          final adentro = RegExp(r'\(([^)]+)\)').firstMatch(f.name)!.group(1)!;
          if (p.dice != null) return adentro != p.dice;
          final numero = RegExp(r'\d+').firstMatch(adentro);
          if (adentro.startsWith('dos ') || adentro.startsWith('two ')) {
            return 2 != p.n;
          }
          return numero == null || int.parse(numero.group(0)!) != p.n;
        }).map((f) => f.level);
        final hasta = siguientes.isEmpty
            ? 21
            : siguientes.reduce((a, b) => a < b ? a : b);
        for (final nivel in {for (final f in clsRepo.features) f.level}) {
          if (nivel <= q.level! || nivel >= hasta) continue;
          expect(
            q.options,
            isNot(contains('$nivel')),
            reason: '${q.subjectId} ${q.subject} ${p.kind.name} ${p.n}',
          );
        }
      }
    }
    expect(vistos, hasLength(37));

    final brujo = nivelesDe(fuente.characterClass('warlock')!);
    final conocidas = fila(
      brujo,
      'Invocaciones Sobrenaturales',
      QuizProgressKind.known,
      7,
    );
    expect(conocidas.level, 9);
    expect(conocidas.options, isNot(contains('11')));
    QuizQuestion enAlgunaSemilla(
      CharacterClass cls,
      bool Function(QuizQuestion q) pred,
    ) {
      for (final seed in List.generate(16, (i) => i + 1)) {
        for (final q in nivelesDe(cls, seed: seed)) {
          if (pred(q)) return q;
        }
      }
      fail('no apareció ${cls.id}');
    }

    final arcanum = enAlgunaSemilla(
      fuente.characterClass('warlock')!,
      (q) =>
          q.subject == 'Arcanum Místico' &&
          q.progress?.kind == QuizProgressKind.spellLevel &&
          q.progress?.n == 7,
    );
    expect(arcanum.level, 13);
    // La primera vez, sin contador, sigue siendo «¿en qué nivel obtenés X?».
    // Comparte clave con la pregunta por texto, así que no sale en toda semilla.
    final primera = enAlgunaSemilla(
      fuente.characterClass('warlock')!,
      (q) => q.subject == 'Invocaciones Sobrenaturales' && q.progress == null,
    );
    expect(primera.level, 1);

    final barbaro = nivelesDe(fuente.characterClass('barbarian')!);
    final furia = fila(barbaro, 'Furia', QuizProgressKind.uses, 4);
    expect(furia.level, 6);
    expect(furia.options, isNot(contains('7')));
    expect(furia.options, isNot(contains('9')));
    expect(furia.options, isNot(contains('11')));
    final golpe =
        fila(barbaro, 'Golpe Brutal Mejorado', QuizProgressKind.dice, 2);
    expect(golpe.level, 17);
    expect(golpe.progress!.dice, '2d10');

    final monje = nivelesDe(fuente.characterClass('monk')!);
    final paso =
        fila(monje, 'Movimiento sin Armadura', QuizProgressKind.feet, 20);
    expect(paso.level, 10);
    expect(paso.options, isNot(contains('13')));

    final druida = nivelesDe(fuente.characterClass('druid')!);
    final formas = fila(druida, 'Forma Salvaje', QuizProgressKind.forms, 6);
    expect(formas.level, 4);
    expect(formas.options, isNot(contains('6')));
    final usos = fila(druida, 'Forma Salvaje', QuizProgressKind.uses, 3);
    expect(usos.level, 6);
    expect(usos.options, isNot(contains('8')));

    final guerrero = nivelesDe(fuente.characterClass('fighter')!);
    final subita = fila(guerrero, 'Acción Súbita', QuizProgressKind.uses, 2);
    expect(subita.level, 17);
    expect(subita.options, isNot(contains('19')));
    final pericia = enAlgunaSemilla(
      fuente.characterClass('rogue')!,
      (q) =>
          q.subject == 'Pericia' &&
          q.progress?.kind == QuizProgressKind.extraSkills &&
          q.progress?.n == 2,
    );
    expect(pericia.level, 6);
  });

  test('en inglés la progresión usa el rasgo pelado y el mismo contador',
      () async {
    final en = await ContentRepository.loadFromDirectory(
      'lib/assets/srd_2024',
      translation: 'en',
    );
    addTearDown(() => ContentLanguage.current = ContentLanguage.es);
    ContentLanguage.current = ContentLanguage.en;
    final preguntas = [
      for (final q in quizRound(
        personaje(fuente.characterClass('warlock')!, 20, 'human', 'soldier'),
        en,
        seed: 1,
        count: 400,
      ))
        if (q.kind == QuizKind.classFeatureLevel &&
            q.progress?.kind == QuizProgressKind.known &&
            q.progress?.n == 7)
          q,
    ];
    expect(preguntas, isNotEmpty);
    expect(preguntas.first.subject, 'Eldritch Invocations');
    expect(preguntas.first.level, 9);
    expect(preguntas.first.subject, isNot(contains('(')));

    // Cambiar de idioma reescribe el rasgo y deja el contador: la UI no
    // vuelve a leer el paréntesis.
    ContentLanguage.current = ContentLanguage.es;
    final esRonda = quizRound(
      personaje(fuente.characterClass('warlock')!, 20, 'human', 'soldier'),
      repo,
      seed: 1,
      count: 400,
    );
    final original = esRonda.firstWhere(
      (q) => q.progress?.kind == QuizProgressKind.known && q.progress?.n == 7,
    );
    ContentLanguage.current = ContentLanguage.en;
    final localizada = quizLocalize([original.toJson()], en).single;
    expect(localizada.subject, 'Eldritch Invocations');
    expect(localizada.progress?.kind, QuizProgressKind.known);
    expect(localizada.progress?.n, 7);
    expect(localizada.level, original.level);
    expect(localizada.optionIds, original.optionIds);
    ContentLanguage.current = ContentLanguage.es;
  });

  test('no se pregunta el alcance Personal y sí la distancia de movimiento',
      () {
    expect(fuente.spell('misty-step')!.moveFeet, 30);
    expect(fuente.spell('misty-step')!.range, 'Personal');
    expect(fuente.spell('tree-stride')!.moveFeet, 500);
    expect(fuente.spell('dimension-door')!.moveFeet, isNull);
    expect(fuente.spell('teleport')!.moveFeet, isNull);
    expect(fuente.spell('arms-of-hadar')!.range,
        'Personal (emanación de 10 pies)');
    expect(
      fuente.spell('control-weather')!.range,
      'Personal (esfera de 5 millas)',
    );
    expect(fuente.spell('gust-of-wind')!.range, 'Personal (línea de 60 pies)');

    final c = personaje(
      fuente.characterClass('wizard')!,
      5,
      'human',
      'sage',
    ).copyWith(
      spellIds: [
        for (final s in fuente.spells.values) s.id,
      ],
    );
    final movidas = <String, QuizQuestion>{};
    for (final seed in List.generate(40, (i) => i + 1)) {
      for (final q in quizRound(c, repo, seed: seed)) {
        if (q.kind == QuizKind.spellRange) {
          expect(q.options[q.answer], isNot('Personal'));
          expect(fuente.spell(q.subjectId!)!.range, isNot('Personal'));
        }
        if (q.kind == QuizKind.spellMoveDistance) {
          movidas[q.subjectId!] = q;
        }
      }
    }
    expect(movidas.keys, containsAll(['misty-step', 'tree-stride']));
    expect(movidas.keys, isNot(contains('dimension-door')));
    expect(movidas.keys, isNot(contains('teleport')));
    expect(movidas['misty-step']!.options[movidas['misty-step']!.answer],
        '30 pies');
    expect(movidas['tree-stride']!.options[movidas['tree-stride']!.answer],
        '500 pies');
  });
}
