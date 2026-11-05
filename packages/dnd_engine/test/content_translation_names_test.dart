import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Nombres oficiales sacados de 5etools-src en la revisión que fija
/// `docs/desarrollo/contenido-y-reglas.md` y que usa `translate_content.dart`.
///
/// El test no baja nada: la red en la corrida normal sería una dependencia
/// frágil, y la prosa del libro no hace falta. El fixture guarda solo nombres
/// (rasgos, acciones, entradas anidadas) de las fuentes 2024 que el índice
/// prefiere — XPHB, XMM, XDMG y EFA — para las entradas que el catálogo puede
/// cruzar por id. Los bloques de conjuro que no están en esos bestiarios
/// (espíritus invocados, cañón, etc.) van en `unmatchedMonster`: no se
/// validan, y el test falla si esa lista deja de coincidir con el catálogo.
const _revision = 'e5f3e77b303a92df10487207857200245e71957c';

/// El catálogo nombra el tipo de criatura como si fuera un rasgo. 5etools no
/// lo publica así.
const _tiposDeEspecie = {'Fey', 'Aberration', 'Humanoid', 'Construct'};

/// «Bestial Nature» agrupa las cuatro opciones que en EFA viven dentro de
/// Shifting (Beasthide, Longtooth, Swiftstride, Wildhunt). No es un rasgo.
const _rasgosDeEspecieDelProyecto = {'Bestial Nature'};

/// «Artificer Tools» traduce «Herramientas de Artífice». En EFA ese bloque no
/// es un classFeature: está en `startingProficiencies`. «Tools of the Trade»
/// es el rasgo de subclase y no se reutiliza acá.
///
/// El resto son compañeros y recursos que el catálogo cuelga del lanzamiento
/// de conjuros. No son rasgos de la clase en 5etools.
const _nombresDeClaseDelProyecto = {
  'Artificer Tools',
  'Aberrant Spirit',
  'Animated Objects',
  'Bestial Spirit',
  'Celestial Spirit',
  'Construct Spirit',
  'Draconic Spirit',
  'Elemental Spirit',
  'Familiar',
  'Fey Spirit',
  'Fiendish Spirit',
  'Focus Points',
  'Giant Insect',
  'Homunculus Servant',
  'Magic Item Plans',
  'Otherworldly Steed',
  'Sorcery Points',
  "Thieves' Cant Language",
  'Undead Spirit',
};

/// Etiquetas de un efecto interno, no el título del rasgo de subclase.
const _nombresDeEfectoDelProyecto = {
  'Bonus Cantrips',
  'Chemical Eruption',
  "Champion's Glory",
  'Fighting Style',
  'Hands of Mercy',
  'Superior Defense',
  'Ultimate Mercy',
  'Wild Magic',
};

final _marcador = RegExp(r'\{([^{}]+)\}');
final _recarga =
    RegExp(r'\s*\((?:Recharge|recarga)[^)]*\)', caseSensitive: false);
final _calificador = RegExp(r'\s*\([^)]*\)$');

void main() {
  final fixture = jsonDecode(
          File('test/fixtures/five_etools_names.json').readAsStringSync())
      as Map<String, dynamic>;

  test('el fixture es la revisión pineada de 5etools-src', () {
    final meta = fixture['_meta'] as Map<String, dynamic>;
    expect(meta['revision'], _revision);
    expect(meta['sources'], ['EFA', 'XDMG', 'XMM', 'XPHB']);
  });

  group('marcadores de fórmula', () {
    // La misma idea que `l10n_parity_test` para los ARB: si el inglés pierde
    // `{PB}`, `{INT}` o `{spellLevel}`, `resolveCreatureFormula` no sustituye
    // y la ficha muestra el texto o calcula distinto. Se compara el multiset
    // del interior de las llaves, en cada ruta que la superposición traduce.
    test('cada texto traducido conserva los marcadores del español', () {
      final distintos = <String>[];
      for (final overlay in _superposiciones()) {
        final catalogo = _catalogo(overlay);
        final porId = _porId(_espanol(overlay));
        final en = (jsonDecode(overlay.readAsStringSync()) as Map)
            .cast<String, dynamic>();
        for (final MapEntry(key: id, value: raw) in en.entries) {
          if (raw is! Map) continue;
          final entry = porId[id];
          if (entry == null) continue;
          for (final MapEntry(key: path, value: text) in raw.entries) {
            if (path == '_es' || text is! String) continue;
            final origen = _enRuta(entry, path);
            if (origen is! String) continue;
            final a = _marcadores(origen);
            final b = _marcadores(text);
            if (!_iguales(a, b)) {
              distintos.add('$catalogo/$id $path: $a ≠ $b');
            }
          }
        }
      }
      expect(distintos, isEmpty, reason: distintos.join('\n'));
    });
  });

  group('nombres contra 5etools', () {
    final razas = _conjunto(fixture['race']);
    final clases = _conjunto(fixture['classFeature']);
    final subclases = _conjunto(fixture['subclassFeature']);
    final monstruos = _conjunto(fixture['monster']);
    final items = (fixture['item'] as Map).cast<String, String>();

    test('las especies usan el nombre oficial del rasgo', () {
      final en = _overlay('races');
      expect(en.keys.toSet(), razas.keys.toSet());
      final distintos = <String>[];
      for (final MapEntry(key: id, value: raw) in en.entries) {
        final oficial = razas[id]!;
        for (final MapEntry(key: path, value: text) in raw.entries) {
          if (!path.endsWith('.name') || text is! String) continue;
          final base = _sinCalificador(text);
          if (oficial.contains(text) ||
              oficial.contains(base) ||
              _tiposDeEspecie.contains(base) ||
              _rasgosDeEspecieDelProyecto.contains(base)) {
            continue;
          }
          distintos.add('races/$id $path: «$text»');
        }
      }
      expect(distintos, isEmpty, reason: distintos.join('\n'));
    });

    test('los títulos de clase y sus efectos nombrados son oficiales', () {
      final en = _overlay('classes');
      expect(en.keys.toSet(), clases.keys.toSet());
      final distintos = <String>[];
      for (final MapEntry(key: id, value: raw) in en.entries) {
        final oficial = clases[id]!;
        for (final MapEntry(key: path, value: text) in raw.entries) {
          if (text is! String) continue;
          final titulo = RegExp(r'^features\.\d+\.name$').hasMatch(path);
          final efecto =
              RegExp(r'^features\.\d+\.effects\.\d+\.name$').hasMatch(path);
          if (!titulo && !efecto) continue;
          // «Tools of the Trade: smith» y «Weapon Mastery (4 weapons)» son
          // desambiguaciones del catálogo. El título se queda con la base.
          if (efecto && (text.contains(':') || text.contains('('))) continue;
          for (final parte in _partes(text)) {
            if (oficial.contains(parte) ||
                _nombresDeClaseDelProyecto.contains(parte)) {
              continue;
            }
            distintos.add('classes/$id $path: «$parte»');
          }
        }
      }
      expect(distintos, isEmpty, reason: distintos.join('\n'));
    });

    test('los rasgos de subclase usan el nombre oficial', () {
      final en = _overlay('subclasses');
      expect(en.keys.toSet(), subclases.keys.toSet());
      final distintos = <String>[];
      for (final MapEntry(key: id, value: raw) in en.entries) {
        final oficial = subclases[id]!;
        for (final MapEntry(key: path, value: text) in raw.entries) {
          if (text is! String) continue;
          if (RegExp(r'^features\.\d+\.name$').hasMatch(path)) {
            for (final parte in _partes(text)) {
              if (!oficial.contains(parte)) {
                distintos.add('subclasses/$id $path: «$parte»');
              }
            }
          } else if (RegExp(r'^features\.\d+\.effects\.\d+\.name$')
              .hasMatch(path)) {
            if (text.contains(':') || text.contains('(')) continue;
            if (!oficial.contains(text) &&
                !_nombresDeEfectoDelProyecto.contains(text)) {
              distintos.add('subclasses/$id $path: «$text»');
            }
          }
        }
      }
      expect(distintos, isEmpty, reason: distintos.join('\n'));
    });

    test('los rasgos y acciones de criatura usan el nombre oficial', () {
      final en = _overlay('creatures');
      final sinFuente =
          (fixture['unmatchedMonster'] as List).cast<String>().toSet();
      expect(en.keys.toSet().difference(monstruos.keys.toSet()), sinFuente);
      expect(sinFuente.intersection(monstruos.keys.toSet()), isEmpty);
      final distintos = <String>[];
      for (final MapEntry(key: id, value: oficial) in monstruos.entries) {
        final raw = en[id] as Map<String, dynamic>;
        for (final MapEntry(key: path, value: text) in raw.entries) {
          if (!path.endsWith('.name') || text is! String) continue;
          final nombre = _sinRecarga(text);
          if (_nombreDeCriatura(nombre, oficial)) continue;
          distintos.add('creatures/$id $path: «$nombre»');
        }
      }
      expect(distintos, isEmpty, reason: distintos.join('\n'));
    });

    test('Playing Cards es el nombre XPHB del set', () {
      // 2014 lo llama «Playing Card Set» y lo reimprime como «Playing Cards».
      // El resto de los objetos no entra en este fixture.
      final en = _overlay('items');
      for (final MapEntry(key: id, value: nombre) in items.entries) {
        expect(en[id]!['name'], nombre, reason: id);
      }
    });
  });
}

Map<String, dynamic> _overlay(String catalogo) => (jsonDecode(
            File('lib/assets/srd_2024/$catalogo.en.json').readAsStringSync())
        as Map)
    .cast<String, dynamic>();

List<File> _superposiciones() => Directory('lib/assets/srd_2024')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.en.json'))
    .toList();

String _catalogo(File overlay) =>
    overlay.uri.pathSegments.last.replaceFirst('.en.json', '');

File _espanol(File overlay) =>
    File(overlay.path.replaceFirst('.en.json', '.json'));

Map<String, Map<String, dynamic>> _porId(File espanol) => {
      for (final e in (jsonDecode(espanol.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>())
        e['id'] as String: e,
    };

Object? _enRuta(Map<String, dynamic> entry, String path) {
  Object? node = entry;
  for (final segment in path.split('.')) {
    node = switch (node) {
      Map() => node[segment],
      List() => switch (int.tryParse(segment)) {
          final i? when i >= 0 && i < node.length => node[i],
          _ => null,
        },
      _ => null,
    };
    if (node == null) return null;
  }
  return node;
}

List<String> _marcadores(String texto) =>
    [for (final m in _marcador.allMatches(texto)) m.group(1)!]..sort();

bool _iguales(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, Set<String>> _conjunto(Object? raw) => {
      for (final MapEntry(key: id, value: names)
          in (raw as Map).cast<String, dynamic>().entries)
        id: (names as List).cast<String>().toSet(),
    };

/// Quita un calificador final del catálogo: «(level 5)», «(Tool)», «(4 weapons)».
String _sinCalificador(String name) =>
    name.replaceFirst(_calificador, '').trim();

/// «Channel Divinity: Peerless Athlete / Inspiring Smite» son dos rasgos.
Iterable<String> _partes(String name) sync* {
  var text = name;
  const prefijo = 'Channel Divinity:';
  if (text.startsWith(prefijo)) text = text.substring(prefijo.length).trim();
  for (final parte in text.split('/')) {
    final base = _sinCalificador(parte.trim());
    if (base.isNotEmpty) yield base;
  }
}

String _sinRecarga(String name) =>
    name.replaceAll(_recarga, '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// El nombre oficial, o el mismo nombre con el paréntesis de usos seguido de
/// `; …` (la bruja nocturna cierra antes de «Requires Soul Bag»).
bool _nombreDeCriatura(String nombre, Set<String> oficial) {
  if (oficial.contains(nombre)) return true;
  if (!nombre.endsWith(')')) return false;
  final abierto = '${nombre.substring(0, nombre.length - 1)};';
  return oficial.any((o) => o.startsWith(abierto));
}
