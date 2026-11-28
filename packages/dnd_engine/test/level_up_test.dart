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

  test('la mejora no sube una característica por encima de 20', () {
    final c = Character.fromJson({
      ...pj('barbarian', 3).toJson(),
      'assignedScores':
          {..._scores, Ability.strength: 19}.map((a, v) => MapEntry(a.name, v)),
    });
    LevelUp up(Map<String, dynamic> asi) => LevelUp(
        c,
        repo,
        LevelUpDraft.fromJson({
          'classId': 'barbarian',
          'subclassId': repo.subclassesForClass('barbarian').first.id,
          ...asi,
        }));

    final masDos = up({'abilityA': 'strength'});
    expect(masDos.abilityRoom[Ability.strength], 1);
    expect(masDos.asiComplete, isFalse);
    expect(
      () => SheetActions.apply(c, repo, {
        'type': 'levelUp',
        'draft': {
          'classId': 'barbarian',
          'subclassId': repo.subclassesForClass('barbarian').first.id,
          'abilityA': 'strength',
        },
      }),
      throwsFormatException,
    );
    // El +1 que sí entra llega justo a 20.
    final repartido = up({
      'asiPlusTwo': false,
      'abilityA': 'strength',
      'abilityB': 'constitution',
    });
    expect(repartido.complete, isTrue);
    expect(repartido.after.abilityScores[Ability.strength], 20);

    // Una dote con +1 fijo a una característica en 20 se puede tomar, pero
    // ese punto se pierde, y el asistente lo sabe antes de elegirla.
    final conVeinte = Character.fromJson({
      ...pj('barbarian', 7).toJson(),
      'assignedScores':
          {..._scores, Ability.strength: 20}.map((a, v) => MapEntry(a.name, v)),
    });
    final dote = repo.featsSorted.firstWhere((f) => f.effects.any((e) =>
        e is AbilityScoreBonusEffect &&
        e.ability == Ability.strength &&
        e.amount == 1));
    final otraMejora = LevelUp(
      conVeinte,
      repo,
      LevelUpDraft(classId: 'barbarian', asiFeat: true, featId: dote.id),
    );
    expect(otraMejora.isAsi, isTrue);
    expect(otraMejora.lostFeatIncreases(dote), [Ability.strength]);
    expect(otraMejora.after.abilityScores[Ability.strength], 20);
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

  test('las elecciones de rasgo y de Pericia se resuelven con el borrador', () {
    // Un guerrero 1 sin estilo de combate y una barda que gana Pericia.
    final guerrero = pj('fighter', 1);
    final sinElegir =
        LevelUp(guerrero, repo, const LevelUpDraft(classId: 'fighter'));
    final cupo = sinElegir.featureSlots
        .firstWhere((s) => s.chosen.length < s.slot.count);
    final opcion = cupo.options.firstWhere((o) => o.unmet == null).feat.id;
    final elegido = LevelUp(
      guerrero,
      repo,
      LevelUpDraft(classId: 'fighter', featurePicks: {
        cupo.slot.groupId: [opcion],
      }),
    );
    expect(LevelUp.chosenFeatures(elegido.built, cupo.slot.groupId), [opcion]);
    expect(elegido.open.features, sinElegir.open.features - 1);

    final barda = pj('bard', 1);
    final pericia = LevelUp(barda, repo, const LevelUpDraft(classId: 'bard'))
        .proficiencySlots
        .firstWhere((s) => s.slot.expertise);
    expect(pericia.locked, isEmpty);
    final dos = pericia.slot.options.take(pericia.slot.count).toList();
    final resuelta = LevelUp(
      barda,
      repo,
      LevelUpDraft(
          classId: 'bard', proficiencyPicks: {pericia.slot.groupId: dos}),
    );
    expect(resuelta.built.proficiencyChoices[pericia.slot.groupId], dos);
    expect(resuelta.open.proficiencies, 0);
  });

  test('los conjuros de clase se eligen sin lo que ya concede un rasgo', () {
    final clerigo = Character(
      id: 'ilse',
      name: 'Ilse',
      raceId: 'dwarf',
      classId: 'cleric',
      subclassId: 'life-domain',
      backgroundId: 'acolyte',
      level: 3,
      assignedScores: _scores,
      hpPerLevel: const [8, 5, 5],
      cantripIds: const ['guidance', 'sacred-flame'],
      spellIds: const ['bless', 'cure-wounds'],
    );
    final up = LevelUp(clerigo, repo, const LevelUpDraft(classId: 'cleric'));
    expect(up.open.classSpells, greaterThan(0));
    final cs = up.classSpellcasting!;
    final o = LevelUp.classSpells(up.built, up.after, repo, cs.sc,
        classId: cs.classId);
    expect(
      o.spells
          .map((s) => s.id)
          .toSet()
          .intersection(up.after.alwaysPreparedSpellIds),
      isEmpty,
    );
    List<String> llenar(List<String> chosen, List<Spell> pool, int n) => [
          ...chosen,
          ...pool.map((s) => s.id).where((id) => !chosen.contains(id)),
        ].take(n).toList();
    final elegido = LevelUp(
      clerigo,
      repo,
      LevelUpDraft(
        classId: 'cleric',
        classCantripPicks:
            llenar(o.chosenCantrips, o.cantrips, cs.sc.cantripsKnown),
        classSpellPicks: llenar(o.chosenSpells, o.spells, cs.sc.preparedCount),
      ),
    );
    expect(elegido.open.classSpells, 0);
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
