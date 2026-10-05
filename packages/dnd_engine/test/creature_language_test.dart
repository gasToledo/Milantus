import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

import 'support/translation_equivalence.dart';

/// Las líneas en inglés con el formato del SRD 5.2.1, para criaturas reales.
const _ingles = {
  'owl': {
    'kind': 'Tiny Beast, Unaligned',
    'senses': 'Darkvision 120 feet; Passive Perception 15',
    'speed': '5 feet, Fly 60 feet',
  },
  'goblin-warrior': {
    'kind': 'Small Fey (Goblinoid), Chaotic Neutral',
    'senses': 'Darkvision 60 feet; Passive Perception 9',
    'speed': '30 feet',
  },
  'giant-eagle': {
    'kind': 'Large Celestial, Neutral Good',
    'senses': 'Passive Perception 16',
    'speed': '10 feet, Fly 80 feet',
  },
  'swarm-of-bats': {
    'kind': 'Large Swarm of Tiny Beasts, Unaligned',
    'senses': 'Blindsight 60 feet; Passive Perception 11',
    'speed': '5 feet, Fly 30 feet',
  },
  'ogre': {
    'kind': 'Large Giant, Chaotic Evil',
    'senses': 'Darkvision 60 feet; Passive Perception 8',
    'speed': '40 feet',
  },
};

void main() {
  group('los lectores de Creature entienden los dos idiomas', () {
    test('tipo y tamaño desde la línea de perfil', () {
      expect(CreatureType.fromKind('Bestia Diminuta, sin alineamiento'),
          CreatureType.beast);
      expect(
          CreatureType.fromKind('Tiny Beast, Unaligned'), CreatureType.beast);
      // Un enjambre no tiene un tipo solo, en ningún idioma.
      expect(CreatureType.fromKind('Large Swarm of Tiny Beasts, Unaligned'),
          isNull);
      expect(CreatureType.fromKind('Enjambre Grande de bestias Diminutas'),
          isNull);
      expect(CreatureSize.fromKind('Enjambre Grande de bestias Diminutas'),
          CreatureSize.large);
      expect(CreatureType.fromKind('Medium or Small Humanoid, Neutral'),
          CreatureType.humanoid);
      expect(CreatureSize.fromKind('Gigante Grande, caótico malvado'),
          CreatureSize.large);
      expect(CreatureSize.fromKind('Large Giant, Chaotic Evil'),
          CreatureSize.large);
      expect(CreatureSize.fromKind('Large Swarm of Tiny Beasts, Unaligned'),
          CreatureSize.large);
    });
  });

  group('equivalencia mecánica', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('pack_en');
      await for (final f in Directory('lib/assets/srd_2024').list()) {
        if (f is File) await f.copy('${dir.path}/${f.uri.pathSegments.last}');
      }
    });

    tearDown(() => dir.delete(recursive: true));

    Future<void> conSuperposicion(
        Map<String, Map<String, String>> textos) async {
      final criaturas = (jsonDecode(
        await File('${dir.path}/creatures.json').readAsString(),
      ) as List)
          .cast<Map<String, dynamic>>();
      final porId = {for (final c in criaturas) c['id']: c};
      await File('${dir.path}/creatures.en.json').writeAsString(jsonEncode({
        for (final MapEntry(key: id, value: campos) in textos.entries)
          id: {
            translationFingerprintKey:
                contentFingerprint(porId[id]!, campos.keys),
            ...campos,
          },
      }));
    }

    test('kind, senses y speed en inglés deducen lo mismo que en español',
        () async {
      await conSuperposicion(_ingles);
      final es = await ContentRepository.loadFromDirectory(dir.path);
      final en = await ContentRepository.loadFromDirectory(
        dir.path,
        translation: 'en',
      );
      for (final id in _ingles.keys) {
        expect(en.creature(id)!.kind, _ingles[id]!['kind']);
      }
      expect(mechanicalDifferences(es, en), isEmpty);
    });

    test('una traducción que rompe un patrón se nota y nombra la criatura',
        () async {
      await conSuperposicion({
        'owl': {'senses': 'Night sight 120 feet; Perception 15'},
      });
      final es = await ContentRepository.loadFromDirectory(dir.path);
      final en = await ContentRepository.loadFromDirectory(
        dir.path,
        translation: 'en',
      );
      expect(mechanicalDifferences(es, en), [contains('owl')]);
    });
  });
}
