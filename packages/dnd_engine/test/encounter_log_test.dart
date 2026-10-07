import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  /// Garrick (PNJ basado en Bandido) y dos goblins contra la mesa, con una
  /// aliada PNJ y un neutral sin estadísticas. Caen los dos goblins y Garrick.
  const log = EncounterLog(
    rounds: 3,
    players: ['Miera'],
    monsters: [
      EncounterLogMonsters(
        name: 'Guerrero goblin',
        count: 2,
        defeated: 2,
        creatureId: 'goblin-warrior',
      ),
      EncounterLogMonsters(
        name: 'Garrick el Tuerto',
        defeated: 1,
        npc: true,
        publicName: 'Bandido',
        creatureId: 'bandit',
      ),
      EncounterLogMonsters(
        name: 'Maerith Sombravela',
        npc: true,
      ),
      EncounterLogMonsters(
        name: 'Capitana Ilse Varn',
        defeated: 1,
        side: CombatantSide.ally,
        npc: true,
        publicName: 'Caballero',
        creatureId: 'knight',
      ),
      EncounterLogMonsters(
        name: 'Toblen',
        side: CombatantSide.neutral,
        npc: true,
      ),
    ],
  );

  group('EncounterLog — bandos', () {
    test('los caídos se cuentan solo entre los enemigos', () {
      expect(log.totalMonsters, 4);
      expect(log.totalDefeated, 3);
      expect(log.allies.single.name, 'Capitana Ilse Varn');
      expect(log.neutrals.single.name, 'Toblen');
    });

    test('bando, PNJ y nombre público sobreviven el round-trip', () {
      final r = EncounterLog.fromJson(log.toJson());
      expect(r.allies.single.npc, isTrue);
      expect(r.allies.single.publicName, 'Caballero');
      expect(r.neutrals.single.side, CombatantSide.neutral);
      expect(r.allies.single.creatureId, 'knight');
    });

    // Lo guardado no cambia: el nombre traducido es solo para mostrar.
    test('renamed nombra para mostrar sin tocar el resto', () {
      final r = log.renamed((m) => m.name.toUpperCase());
      expect(r.enemies.first.name, 'GUERRERO GOBLIN');
      expect(r.enemies.first.creatureId, 'goblin-warrior');
      expect(r.totalDefeated, log.totalDefeated);
      expect(log.enemies.first.name, 'Guerrero goblin');
    });
  });

  group('EncounterLog.playerView', () {
    final view = log.playerView();
    final body = jsonEncode(view.toJson());

    test('no contiene el nombre de ningún PNJ', () {
      for (final name in [
        'Garrick',
        'Maerith',
        'Ilse',
        'Toblen',
        'Caballero',
      ]) {
        expect(body, isNot(contains(name)), reason: name);
      }
    });

    test('el PNJ enemigo aparece con su criatura y el anónimo sin nombre', () {
      final names = [for (final m in view.monsters) m.name];
      expect(names, containsAll(['Guerrero goblin', 'Bandido', '']));
      expect(view.monsters.every((m) => !m.npc), isTrue);
      expect(view.monsters.every((m) => m.publicName == null), isTrue);
    });

    // Con el id, la pantalla del jugador nombra la criatura en su idioma. El
    // del PNJ es el de su criatura de base; el de la aliada no viaja.
    test('cada grupo lleva el id de su criatura, y el PNJ el de su base', () {
      final ids = {for (final m in view.monsters) m.name: m.creatureId};
      expect(ids['Guerrero goblin'], 'goblin-warrior');
      expect(ids['Bandido'], 'bandit');
      expect(ids[''], isNull);
      expect(body, isNot(contains('knight')));
    });

    test('aliados y neutrales no aparecen y los caídos son de enemigos', () {
      expect(view.totalMonsters, 4);
      expect(view.totalDefeated, 3);
      expect(view.players, ['Miera']);
    });

    test('junta a un PNJ con los monstruos de su misma criatura', () {
      const mixed = EncounterLog(
        monsters: [
          EncounterLogMonsters(name: 'Bandido', count: 2, defeated: 1),
          EncounterLogMonsters(
            name: 'Garrick',
            npc: true,
            publicName: 'Bandido',
            defeated: 1,
          ),
        ],
      );
      final m = mixed.playerView().monsters.single;
      expect(m.name, 'Bandido');
      expect(m.count, 3);
      expect(m.defeated, 2);
    });
  });

  group('EncounterLog — versionado', () {
    test('un registro v1 se lee con todos sus monstruos como enemigos', () {
      final v1 = <String, dynamic>{
        'schemaVersion': 1,
        'rounds': 2,
        'players': ['Sagan'],
        'monsters': [
          {'name': 'Esqueleto', 'count': 2, 'defeated': 2},
        ],
      };
      final copy = jsonDecode(jsonEncode(v1));

      final r = EncounterLog.fromJson(v1);

      expect(v1, copy);
      expect(r.enemies.single.name, 'Esqueleto');
      expect(r.totalDefeated, 2);
      expect(r.toJson()['schemaVersion'], 2);
    });

    test('rechaza una versión futura', () {
      expect(
        () => EncounterLog.fromJson({
          'schemaVersion': EncounterLog.currentSchemaVersion + 1,
        }),
        throwsA(isA<UnsupportedDataVersionException>()),
      );
    });
  });
}
