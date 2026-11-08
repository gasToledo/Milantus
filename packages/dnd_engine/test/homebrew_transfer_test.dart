import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_engine/homebrew_transfer.dart';
import 'package:test/test.dart';

void main() {
  group('parseHomebrewImport', () {
    test('lee un pack de homebrew y devuelve listas por tipo', () {
      final text = jsonEncode({
        'type': 'dnd_homebrew',
        'formatVersion': 1,
        'content': {
          'weapons': [
            {
              'id': 'hb-sword',
              'name': 'Espada rúnica',
              'source': 'homebrew',
              'category': 'martial',
              'damageDice': '1d8',
              'damageType': 'cortante',
            },
          ],
          'feats': [
            {'id': 'hb-feat', 'name': 'Dote casera', 'source': 'homebrew'},
          ],
          'creatures': [
            {
              'id': 'hb-wolf',
              'name': 'Lobo de humo',
              'source': 'homebrew',
              'ac': '13',
              'hp': '11',
            },
          ],
        },
      });
      final parsed = parseHomebrewImport(text);
      expect(parsed['weapons'], hasLength(1));
      expect(parsed['feats'], hasLength(1));
      expect(parsed['creatures'], hasLength(1));
      // Los tipos ausentes vienen como listas vacías, no null.
      expect(parsed['spells'], isEmpty);
      // Round-trip a modelo del engine.
      expect(Weapon.fromJson(parsed['weapons']!.first).name, 'Espada rúnica');
      expect(
        Creature.fromJson(parsed['creatures']!.first).name,
        'Lobo de humo',
      );
    });

    test('rechaza un archivo que no es homebrew', () {
      final text = jsonEncode({'type': 'dnd_character', 'character': {}});
      expect(() => parseHomebrewImport(text), throwsFormatException);
    });

    test('rechaza un pack homebrew de versión futura', () {
      final text = jsonEncode({
        'type': 'dnd_homebrew',
        'formatVersion': homebrewExportFormatVersion + 1,
        'content': const <String, dynamic>{},
      });

      expect(
        () => parseHomebrewImport(text),
        throwsA(isA<UnsupportedDataVersionException>()),
      );
    });

    test('lo que se exporta se vuelve a leer igual', () {
      final content = {
        for (final c in homebrewCategories) c: <Map<String, dynamic>>[],
        'feats': [
          {'id': 'hb-feat', 'name': 'Dote casera', 'source': 'homebrew'},
        ],
      };
      final now = DateTime(2026, 11, 8, 15, 30, 5);
      final text = jsonEncode(homebrewExportEnvelope(content, now));

      expect(parseHomebrewImport(text), content);
      expect(homebrewExportFileName(now), 'homebrew-2026-11-08T15-30-05.json');
    });
  });

  group('con el catálogo', () {
    late ContentRepository repo;

    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    test('countHomebrewCollisions cuenta solo los ids que ya existen', () {
      final w = repo.weapons.values.first;
      final content = {
        'weapons': [
          {'id': w.id}, // colisiona
          {'id': 'arma-nueva'}, // no colisiona
        ],
        'feats': [
          {'id': 'dote-nueva'}, // no colisiona
        ],
      };

      expect(
        countHomebrewCollisions(content, {
          'weapons': {w.id},
        }),
        1,
      );
      // Sin homebrew propio no hay colisiones.
      expect(countHomebrewCollisions(content, const {}), 0);
    });

    test('validateHomebrewInventoryIds no permite sobrescribir un id oficial',
        () {
      final official = repo.weapons.values.first;

      expect(
        () => validateHomebrewInventoryIds({
          'weapons': [official.toJson()..['source'] = 'homebrew'],
        }, repo),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('catálogo oficial'),
          ),
        ),
      );
    });

    test('validateHomebrewInventoryIds rechaza un id repetido entre catálogos',
        () {
      final weapon = repo.weapons.values.first.toJson()..['id'] = 'compartido';
      final armor = repo.armor.values.first.toJson()..['id'] = 'compartido';

      expect(
        () => validateHomebrewInventoryIds({
          'weapons': [weapon],
          'armor': [armor],
        }, repo),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('weapons y armor'),
          ),
        ),
      );
    });
  });
}
