import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Npc block(Creature creature) => Npc(
        id: 'garrick',
        name: 'Garrick',
        sheetKind: NpcSheetKind.block,
        block: creature,
        baseCreatureId: creature.id,
      );

  group('NpcStats', () {
    test('un PNJ sin estadísticas no tiene PG ni CA', () {
      final stats = NpcStats.of(
        Npc(id: 'odile', name: 'Odile', sheetKind: NpcSheetKind.none),
        null,
        repo,
      );
      expect(stats.maxHp, 0);
      expect(stats.armorClass, isNull);
      expect(stats.hurt(NpcStatus.alive, 3), isNull);
    });

    test('un bloque entra con los PG resueltos y la CA que imprime', () {
      final bandit = repo.creature('bandit')!;
      final stats = NpcStats.of(block(bandit), null, repo);
      expect(stats.maxHp, bandit.resolve(const CreatureVars({})).maxHp);
      expect(stats.armorClass, bandit.ac);
      expect(stats.sheet, isNull);
    });

    test('un bloque con una fórmula que no se evalúa entra sin PG', () {
      final roto = Creature(
        id: 'roto',
        name: 'Roto',
        source: ContentSource.homebrew,
        ac: '10',
        hp: 'mucho',
      );
      expect(NpcStats.of(block(roto), null, repo).maxHp, 0);
    });

    test('una ficha de personaje usa la ficha compilada', () {
      final ficha = Character(
        id: 'vesna-ficha',
        name: 'Vesna',
        raceId: 'elf',
        classId: 'wizard',
        backgroundId: 'sage',
        level: 3,
        assignedScores: const {
          Ability.strength: 8,
          Ability.dexterity: 14,
          Ability.constitution: 13,
          Ability.intelligence: 15,
          Ability.wisdom: 12,
          Ability.charisma: 10,
        },
        hpPerLevel: const [6, 4, 4],
      );
      final npc = Npc(
        id: 'vesna',
        name: 'Vesna',
        sheetKind: NpcSheetKind.character,
        characterId: ficha.id,
      );
      final compilada = CharacterCompiler(repo).compile(ficha);
      final stats = NpcStats.of(npc, ficha, repo);
      expect(stats.maxHp, compilada.maxHp);
      expect(stats.armorClass, '${compilada.armorClass}');
      expect(stats.sheet?.initiative, compilada.initiative);
      // Sin la ficha a mano no se inventa nada.
      expect(NpcStats.of(npc, null, repo).maxHp, 0);
    });

    test('herido solo si sigue vivo y le faltan PG en esa campaña', () {
      final stats = NpcStats.of(block(repo.creature('bandit')!), null, repo);
      final max = stats.maxHp;
      expect(
          stats.hurt(NpcStatus.alive, max - 2), (current: max - 2, max: max));
      expect(stats.hurt(NpcStatus.unknown, 0), (current: 0, max: max));
      expect(stats.hurt(NpcStatus.alive, null), isNull,
          reason: 'null es entero');
      expect(stats.hurt(NpcStatus.alive, max), isNull);
      expect(stats.hurt(NpcStatus.alive, max + 5), isNull);
      expect(stats.hurt(NpcStatus.dead, 1), isNull);
    });
  });

  group('missingOfficialContent', () {
    test(
        'una ficha con una clase que el catálogo no tiene no se importa, '
        'salvo que el homebrew la traiga', () {
      final existente = repo.classes.keys.first;
      Character ficha(String classId) => Character(
            id: 'ficha',
            name: 'Ilse',
            raceId: repo.races.keys.first,
            classId: classId,
            backgroundId: repo.backgrounds.keys.first,
            assignedScores: const {
              Ability.strength: 10,
              Ability.dexterity: 10,
              Ability.constitution: 10,
              Ability.intelligence: 10,
              Ability.wisdom: 10,
              Ability.charisma: 10,
            },
          );

      expect(missingOfficialContent(ficha(existente), const {}, repo), isEmpty);

      final faltantes = missingOfficialContent(
        ficha('clase-de-otro-libro'),
        const {},
        repo,
      );
      expect(faltantes.single, contains('clase-de-otro-libro'));

      final conHomebrew = missingOfficialContent(
        ficha('clase-de-otro-libro'),
        {
          'classes': [
            {'id': 'clase-de-otro-libro'},
          ],
        },
        repo,
      );
      expect(conHomebrew, isEmpty);
    });
  });
}
