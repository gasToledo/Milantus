import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Rondas del Quiz contra el SRD real: cada pregunta tiene que ser
/// contestable (4 opciones distintas, la correcta en rango) y la respuesta
/// tiene que coincidir con el catálogo, no con un literal.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character personaje(CharacterClass cls, int level, String raceId, String bg) {
    final subs = repo.subclassesForClass(cls.id);
    final hechizos = repo.spellsSorted.where((s) => s.classes.contains(cls.id));
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

  /// Lo que dice el catálogo de la respuesta correcta, derivado de la pregunta.
  void verificar(QuizQuestion q, Character? c) {
    expect(q.options, hasLength(4));
    expect(q.options.toSet(), hasLength(4));
    expect(q.answer, inInclusiveRange(0, 3));
    final correcta = q.options[q.answer];
    switch (q.kind) {
      case QuizKind.condition:
        expect(correcta, conditionLabel(q.subjectId!));
      case QuizKind.spellCastingTime:
        final s = repo.spell(q.subjectId!)!;
        expect(correcta,
            vocabularyLabel(VocabularyField.castingTime, s.castingTime));
      case QuizKind.spellRange:
        final s = repo.spell(q.subjectId!)!;
        expect(correcta, vocabularyLabel(VocabularyField.range, s.range));
      case QuizKind.spellSchool:
        final s = repo.spell(q.subjectId!)!;
        expect(correcta, vocabularyLabel(VocabularyField.school, s.school));
      case QuizKind.hitDie:
        expect(correcta, 'd${repo.characterClass(q.subjectId!)!.hitDie}');
      case QuizKind.savingThrows:
        final k = repo.characterClass(q.subjectId!)!;
        for (final a in k.savingThrows) {
          expect(correcta, contains(a.label));
        }
      case QuizKind.backgroundSkills:
        final b = repo.background(q.subjectId!)!;
        for (final s in b.skillProficiencies) {
          expect(correcta, contains(Skill.labelFor(s)));
        }
      case QuizKind.backgroundFeat:
        final b = repo.background(q.subjectId!)!;
        expect(correcta, repo.feat(b.originFeatId!)!.name);
      case QuizKind.classFeatureLevel:
        final f = c!.classHistory
            .map(repo.characterClass)
            .expand((k) => k!.features)
            .where((f) => f.name == q.subject);
        expect(f.map((f) => f.level), contains(q.level));
        expect(correcta, '${q.level}');
      case QuizKind.skillAbility:
        expect(correcta, Skill.fromId(q.subjectId!)!.ability.label);
      case QuizKind.weaponMastery:
        expect(
            correcta, weaponMasteryName(repo.weapon(q.subjectId!)!.mastery!));
      case QuizKind.weaponDamage:
        final w = repo.weapon(q.subjectId!)!;
        expect(correcta, startsWith('${w.damageDice} '));
        expect(correcta,
            endsWith(DamageType.labelFor(w.damageType).toLowerCase()));
      case QuizKind.armorAc:
        expect(correcta, '${repo.armorPiece(q.subjectId!)!.baseAc}');
      case QuizKind.armorCategory:
        expect(correcta,
            armorTrainingLabel(repo.armorPiece(q.subjectId!)!.category));
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
    }
  }

  void verificarRonda(List<QuizQuestion> ronda, Character? c) {
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
      verificar(q, c);
    }
  }

  test('rondas de personajes de todas las clases a nivel 1 y 5', () {
    for (final cls in repo.classesSorted) {
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
          expect(ronda.length, greaterThanOrEqualTo(7),
              reason: '${cls.id} $level semilla $seed');
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
    final c = personaje(repo.characterClass('warlock')!, 5, 'aasimar', 'sage');
    List<Map<String, dynamic>> json(int seed) =>
        [for (final q in quizRound(c, repo, seed: seed)) q.toJson()];
    expect(json(11), json(11));
    expect(json(11), isNot(json(12)));
  });
}
