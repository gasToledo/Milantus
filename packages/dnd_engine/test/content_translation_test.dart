import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Una entrada con la forma de una clase: rasgos sin id, efectos anidados.
Map<String, dynamic> _clase() => {
      'id': 'fighter',
      'name': 'Guerrero',
      'hitDie': 10,
      'features': [
        {'level': 1, 'name': 'Estilo de Combate', 'effects': []},
        {
          'level': 1,
          'name': 'Segundo Aliento',
          'effects': [
            {'type': 'passiveTrait', 'name': 'Segundo Aliento'},
          ],
        },
      ],
    };

Map<String, dynamic> _traduccion(
  Map<String, dynamic> entry,
  Map<String, String> textos,
) =>
    {
      translationFingerprintKey: contentFingerprint(entry, textos.keys),
      ...textos,
    };

void main() {
  group('valueAtPath', () {
    test('recorre mapas y listas por índice', () {
      final clase = _clase();
      expect(valueAtPath(clase, 'name'), 'Guerrero');
      expect(
          valueAtPath(clase, 'features.1.effects.0.name'), 'Segundo Aliento');
    });

    test('una ruta que no existe devuelve null', () {
      final clase = _clase();
      expect(valueAtPath(clase, 'features.9.name'), isNull);
      expect(valueAtPath(clase, 'features.x.name'), isNull);
      expect(valueAtPath(clase, 'name.0'), isNull);
    });
  });

  group('contentFingerprint', () {
    test('no depende del orden de las rutas', () {
      final clase = _clase();
      expect(
        contentFingerprint(clase, ['name', 'features.0.name']),
        contentFingerprint(clase, ['features.0.name', 'name']),
      );
    });

    test('cambia si cambia el español', () {
      final antes = contentFingerprint(_clase(), ['name']);
      final despues = contentFingerprint(_clase()..['name'] = 'Guerrera', [
        'name',
      ]);
      expect(despues, isNot(antes));
      expect(antes, hasLength(8));
    });
  });

  group('applyContentTranslation', () {
    test('reemplaza la raíz y los textos anidados', () {
      final clase = _clase();
      final [traducida] = applyContentTranslation([
        clase,
      ], {
        'fighter': _traduccion(clase, {
          'name': 'Fighter',
          'features.1.effects.0.name': 'Second Wind',
        }),
      });
      expect(traducida['name'], 'Fighter');
      expect(
          valueAtPath(traducida, 'features.1.effects.0.name'), 'Second Wind');
      // Lo no traducido queda en español: es el respaldo.
      expect(valueAtPath(traducida, 'features.1.name'), 'Segundo Aliento');
      expect(traducida['hitDie'], 10);
    });

    test('no muta la entrada original', () {
      final clase = _clase();
      final original = jsonEncode(clase);
      applyContentTranslation([
        clase,
      ], {
        'fighter': _traduccion(clase, {
          'name': 'Fighter',
          'features.0.name': 'Fighting Style',
        }),
      });
      expect(jsonEncode(clase), original);
    });

    test('ignora rutas e ids inexistentes y deja el español', () {
      final clase = _clase();
      final [traducida] = applyContentTranslation([
        clase,
      ], {
        'fighter': {
          'features.9.name': 'Nada',
          'hitDie': 'Diez',
          'name': 'Fighter',
        },
        'wizard': {'name': 'Wizard'},
      });
      expect(traducida['name'], 'Fighter');
      expect(traducida['hitDie'], 10);
      expect((traducida['features'] as List), hasLength(2));
    });
  });

  group('translationProblems', () {
    test('una superposición al día no tiene problemas', () {
      final clase = _clase();
      final overlay = {
        'fighter': _traduccion(clase, {'name': 'Fighter'}),
      };
      expect(
        translationProblems('classes', [clase], overlay, requireName: true),
        isEmpty,
      );
    });

    test('nombra la entrada cuyo español cambió', () {
      final overlay = {
        'fighter': _traduccion(_clase(), {'name': 'Fighter'}),
      };
      final problemas = translationProblems(
          'classes',
          [
            _clase()..['name'] = 'Guerrera',
          ],
          overlay);
      expect(problemas, [contains('classes/fighter')]);
      expect(problemas.single, contains('cambió'));
    });

    test('señala ids y rutas que ya no existen, y la huella ausente', () {
      final clase = _clase();
      final problemas = translationProblems('classes', [
        clase,
      ], {
        'fighter': {'features.9.name': 'Nada'},
        'wizard': {'name': 'Wizard'},
      });
      expect(problemas, hasLength(3));
      expect(problemas.where((p) => p.contains('wizard')), hasLength(1));
      expect(
          problemas.where((p) => p.contains('features.9.name')), hasLength(1));
      expect(problemas.where((p) => p.contains('huella')), hasLength(1));
    });

    test('con requireName exige el nombre de cada entrada', () {
      expect(
        translationProblems('classes', [_clase()], {}, requireName: true),
        [contains('classes/fighter')],
      );
    });
  });

  group('loadFromDirectory con traducción', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('pack_en');
      await for (final f in Directory('lib/assets/srd_2024').list()) {
        // Solo el español: la prueba pone su propia superposición y mira que
        // los catálogos sin superposición queden como estaban.
        if (f is File && !f.path.endsWith('.en.json')) {
          await f.copy('${dir.path}/${f.uri.pathSegments.last}');
        }
      }
    });

    tearDown(() => dir.delete(recursive: true));

    test('aplica la superposición de un catálogo y deja los demás', () async {
      final spells = (jsonDecode(
        await File('${dir.path}/spells.json').readAsString(),
      ) as List)
          .cast<Map<String, dynamic>>();
      final conjuro = spells.first;
      final id = conjuro['id'] as String;
      await File('${dir.path}/spells.en.json').writeAsString(
        jsonEncode({
          id: _traduccion(conjuro, {'name': 'Translated'}),
        }),
      );

      final espanol = await ContentRepository.loadFromDirectory(dir.path);
      final ingles = await ContentRepository.loadFromDirectory(
        dir.path,
        translation: 'en',
      );

      expect(ingles.spell(id)!.name, 'Translated');
      expect(espanol.spell(id)!.name, conjuro['name']);
      // El resto queda igual: los ids no cambian y el respaldo es el español.
      expect(ingles.spells.keys, espanol.spells.keys);
      final otro = espanol.classes.keys.first;
      expect(
        ingles.characterClass(otro)!.name,
        espanol.characterClass(otro)!.name,
      );

      // El cambio de idioma reemplaza el contenido en el mismo objeto, y la
      // revisión avisa a quien memoizó algo compilado contra él.
      final homebrew = ContentRepository(
        spells: {
          'hb': Spell.fromJson({...conjuro, 'id': 'hb', 'name': 'HB'})
        },
      );
      espanol.addAll(homebrew);
      final antes = espanol.revision;
      espanol
        ..replaceWith(ingles)
        ..addAll(homebrew);
      expect(espanol.spell(id)!.name, 'Translated');
      expect(espanol.spell('hb')!.name, 'HB');
      expect(espanol.spells.length, ingles.spells.length + 1);
      expect(espanol.revision, greaterThan(antes));
    });
  });
}
