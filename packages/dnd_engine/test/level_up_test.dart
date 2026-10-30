import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

const _scores = {
  Ability.strength: 16,
  Ability.dexterity: 10,
  Ability.constitution: 14,
  Ability.intelligence: 8,
  Ability.wisdom: 12,
  Ability.charisma: 15,
};

void main() {
  late ContentRepository repo;
  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character pj(String classId, int level, {int currentHp = 10}) => Character(
        id: 'pj',
        name: 'PJ',
        raceId: 'human',
        classId: classId,
        backgroundId: 'soldier',
        level: level,
        assignedScores: _scores,
        hpPerLevel: List.filled(level, 6),
        combat: CombatState(currentHp: currentHp),
      );

  test(
      'la mejora +1 a dos se completa con la segunda y al confirmar los PG '
      'actuales suben lo mismo que el máximo', () {
    // Un bárbaro 3 sin senda: la subida a 4 pide subclase y mejora.
    final c = pj('barbarian', 3);
    final senda = repo.subclassesForClass('barbarian').first.id;
    Map<String, dynamic> draft(String? b) => {
          'classId': 'barbarian',
          'subclassId': senda,
          'asiPlusTwo': false,
          'abilityA': 'strength',
          'abilityB': b,
        };
    LevelUp up(String? b) => LevelUp(c, repo, LevelUpDraft.fromJson(draft(b)));

    expect(up(null).isAsi, isTrue);
    expect(up(null).needsSubclass, isTrue);
    expect(up(null).complete, isFalse);
    final listo = up('constitution');
    expect(listo.complete, isTrue);
    expect(listo.built.asiChoices.last.abilityIncreases,
        {Ability.strength: 1, Ability.constitution: 1});

    final confirmado = listo.confirm();
    expect(confirmado.combat.currentHp,
        10 + listo.after.maxHp - listo.before.maxHp);
    expect(c.combat.currentHp, 10);

    // La acción guarda lo mismo y rechaza la subida a medias.
    expect(
      SheetActions.apply(
              c, repo, {'type': 'levelUp', 'draft': draft('constitution')})
          .character
          .toJson(),
      confirmado.toJson(),
    );
    expect(
      () => SheetActions.apply(
          c, repo, {'type': 'levelUp', 'draft': draft(null)}),
      throwsFormatException,
    );
  });

  test(
      'las dotes se ofrecen con el prerrequisito que falta, y la que sube '
      'una característica pide a cuál', () {
    final c = pj('paladin', 3);
    final opciones = LevelUp(
      c,
      repo,
      const LevelUpDraft(classId: 'paladin', asiFeat: true),
    ).featOptions;
    expect(
        opciones.firstWhere((o) => o.feat.id == 'keen-mind').unmet, isNotNull);

    // Los dones épicos (nivel 19) suben una característica a elección.
    final epico = pj('paladin', 18);
    final conAumento = LevelUp(
      epico,
      repo,
      const LevelUpDraft(classId: 'paladin', asiFeat: true),
    ).featOptions.firstWhere((o) =>
        o.unmet == null &&
        o.feat.effects.whereType<AbilityScoreChoiceEffect>().isNotEmpty);
    LevelUp elegir(Ability? a) => LevelUp(
        epico,
        repo,
        LevelUpDraft(
          classId: 'paladin',
          asiFeat: true,
          featId: conAumento.feat.id,
          abilityA: a,
        ));
    expect(elegir(null).asiComplete, isFalse);
    expect(
        elegir(Ability.charisma).built.featIds, contains(conAumento.feat.id));
  });

  test('lo que la subida obliga a elegir aparece en open', () {
    final barbaro = LevelUp(
        pj('barbarian', 4), repo, const LevelUpDraft(classId: 'barbarian'));
    expect(barbaro.open,
        (features: 0, proficiencies: 0, spellChoices: 0, classSpells: 0));

    final bardo =
        LevelUp(pj('bard', 1), repo, const LevelUpDraft(classId: 'bard'));
    expect(bardo.open.proficiencies, greaterThan(0));
  });
}
