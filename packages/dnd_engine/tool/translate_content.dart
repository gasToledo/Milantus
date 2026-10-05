/// Completa y mantiene las superposiciones `X.en.json` del catálogo (ver
/// `lib/src/data/content_translation.dart`).
///
///     dart run tool/translate_content.dart --fill <directorio-5etools>
///     dart run tool/translate_content.dart --refresh
///
/// `--fill` agrega lo que falta y **nunca pisa una ruta ya traducida**: lo
/// escrito a mano manda. Los nombres salen de 5etools-src en la revisión
/// pineada (`docs/desarrollo/contenido-y-reglas.md` dice cuál y qué archivos
/// bajar): los ids del catálogo son sus slugs, así que el cruce es por id.
/// Lo que no puede completar lo lista, para traducirlo a mano.
///
/// `--refresh` recalcula las huellas del español de todas las entradas. Es
/// para cuando el español cambió sin cambiar el sentido (por ejemplo después
/// de `apply_voseo.dart`): imprime qué entradas tocó para revisar el diff, y
/// no se corre a ciegas, porque taparía un cambio de sentido.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';

const _dir = 'lib/assets/srd_2024';

/// De qué listas de 5etools sale el nombre de cada catálogo, en orden de
/// preferencia.
const fiveEtoolsKinds = {
  'spells': ['spell'],
  'creatures': ['monster'],
  'weapons': ['baseitem', 'item'],
  'armor': ['baseitem', 'item'],
  'items': ['item', 'baseitem'],
  'magic_items': ['item'],
  'efa_magic_items': ['item'],
  'feats': ['feat', 'optionalfeature'],
  'races': ['race'],
  'lineages': ['subrace', 'race'],
  'backgrounds': ['background'],
  'classes': ['class'],
  'subclasses': ['subclass'],
};

/// Las fuentes 2024 ganan cuando 5etools tiene el mismo nombre en dos
/// ediciones: el catálogo es 2024 y la 2014 a veces nombra distinto.
const _preferredSources = {'XPHB', 'XMM', 'XDMG', 'EFA'};

String slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r"['’]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// Índice `tipo → clave → nombre en inglés` de los archivos de 5etools.
///
/// Cada entrada se registra con más de una clave porque los ids del catálogo
/// no siempre son el slug del nombre entero: «College of Lore» es
/// `college-lore` y la subclase «Path of the Berserker» es `berserker`, su
/// `shortName`.
Map<String, Map<String, String>> indexFiveEtools(
  Iterable<Map<String, dynamic>> files,
) {
  final index = <String, Map<String, ({String name, bool preferred})>>{};
  for (final file in files) {
    for (final MapEntry(key: kind, value: list) in file.entries) {
      if (list is! List) continue;
      for (final e in list.whereType<Map<String, dynamic>>()) {
        final name = e['name'];
        if (name is! String) continue;
        final preferred = _preferredSources.contains(e['source']);
        final full = slug(name);
        final keys = {
          full,
          full.replaceAll(RegExp(r'-of(-the)?-'), '-'),
          if (e['shortName'] case final String short) slug(short),
        };
        final byKey = index.putIfAbsent(kind, () => {});
        for (final key in keys) {
          final current = byKey[key];
          if (current == null || (preferred && !current.preferred)) {
            byKey[key] = (name: name, preferred: preferred);
          }
        }
      }
    }
  }
  return {
    for (final MapEntry(key: kind, value: byKey) in index.entries)
      kind: {for (final e in byKey.entries) e.key: e.value.name},
  };
}

/// Nombre en inglés de la entrada [id] según el [index], o null.
///
/// Además del id tal cual prueba las formas que usa el catálogo y 5etools no:
/// armaduras sin la palabra (`padded` es «Padded Armor»), estilos de combate
/// con prefijo (`fs-defense`) y dotes partidas por característica
/// (`athlete-strength` es «Athlete (Strength)», como en el español).
String? englishName(
  Map<String, Map<String, String>> index,
  List<String> kinds,
  String id,
) {
  String? find(String key) {
    for (final kind in kinds) {
      final name = index[kind]?[key];
      if (name != null) return name;
    }
    return null;
  }

  final direct = find(id) ?? find('$id-armor');
  if (direct != null) return direct;
  if (id.startsWith('fs-')) return find(id.substring(3));
  final split = RegExp(
    r'^(.+)-(strength|dexterity|constitution|intelligence|wisdom|charisma)$',
  ).firstMatch(id);
  if (split != null) {
    final base = find(split[1]!);
    if (base != null) return '$base (${titleCaseId(split[2]!)})';
  }
  return null;
}

/// Campos cortos que se traducen solos por patrón, sin 5etools.
String? _patternTranslation(String path, String spanish) {
  if (path == 'range') {
    final feet = RegExp(r'^(\d+) pies$').firstMatch(spanish);
    if (feet != null) return '${feet[1]} feet';
  }
  return null;
}

/// Resultado de [fillOverlay]: la superposición nueva y lo que no se pudo
/// completar o no se tocó.
typedef FillResult = ({Map<String, dynamic> overlay, List<String> pending});

/// Agrega a [overlay] lo que falte de [pack] y devuelve una copia.
///
/// Una entrada con la huella desfasada no se toca: sumarle rutas obligaría a
/// recalcular la huella y escondería que su traducción quedó vieja. Se lista
/// en `pending` junto con los nombres que no se encontraron.
FillResult fillOverlay(
  String catalog,
  List<Map<String, dynamic>> pack,
  Map<String, dynamic> overlay,
  String? Function(String id) nameFor,
) {
  final result = <String, dynamic>{};
  final pending = <String>[];
  for (final entry in pack) {
    final id = entry['id'] as String;
    final current = {...?(overlay[id] as Map?)?.cast<String, dynamic>()};
    final paths = translatedPaths(current).toList();
    if (current.isNotEmpty &&
        current[translationFingerprintKey] !=
            contentFingerprint(entry, paths)) {
      pending.add('$catalog/$id: traducción desfasada, no se completó.');
      result[id] = current;
      continue;
    }
    final added = <String, String>{};
    if (!current.containsKey('name')) {
      final name = nameFor(id);
      if (name != null) {
        added['name'] = name;
      } else {
        pending.add('$catalog/$id: sin nombre en 5etools (${entry['name']}).');
      }
    }
    for (final MapEntry(key: path, value: spanish) in entry.entries) {
      if (spanish is! String || current.containsKey(path)) continue;
      final translated = _patternTranslation(path, spanish);
      if (translated != null) added[path] = translated;
    }
    if (current.isEmpty && added.isEmpty) continue;
    final texts = {
      for (final p in paths) p: current[p],
      ...added,
    };
    result[id] = {
      translationFingerprintKey: contentFingerprint(entry, texts.keys),
      ...texts,
    };
  }
  // Las traducciones de ids que ya no existen se conservan para que el test
  // de integridad las señale, en vez de borrarlas en silencio.
  for (final id in overlay.keys) {
    result.putIfAbsent(id, () => overlay[id]);
  }
  return (overlay: result, pending: pending);
}

/// Recalcula la huella de cada entrada de [overlay] contra [pack]. Devuelve
/// la superposición nueva y los ids cuya huella cambió.
({Map<String, dynamic> overlay, List<String> changed}) refreshOverlay(
  List<Map<String, dynamic>> pack,
  Map<String, dynamic> overlay,
) {
  final byId = {for (final e in pack) e['id'] as String: e};
  final changed = <String>[];
  final result = <String, dynamic>{};
  for (final MapEntry(key: id, value: raw) in overlay.entries) {
    final entry = byId[id];
    if (entry == null || raw is! Map<String, dynamic>) {
      result[id] = raw;
      continue;
    }
    final paths = translatedPaths(raw).toList();
    final fingerprint = contentFingerprint(entry, paths);
    if (raw[translationFingerprintKey] != fingerprint) changed.add(id);
    result[id] = {
      translationFingerprintKey: fingerprint,
      for (final p in paths) p: raw[p],
    };
  }
  return (overlay: result, changed: changed);
}

List<Map<String, dynamic>> _readPack(String catalog) =>
    (jsonDecode(File('$_dir/$catalog.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _readOverlay(String catalog) {
  final file = File('$_dir/$catalog.en.json');
  if (!file.existsSync()) return {};
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
}

void _writeOverlay(String catalog, Map<String, dynamic> overlay) {
  if (overlay.isEmpty) return;
  File('$_dir/$catalog.en.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(overlay)}\n',
  );
}

void main(List<String> args) {
  if (args.firstOrNull == '--refresh') {
    for (final catalog in fiveEtoolsKinds.keys) {
      final overlay = _readOverlay(catalog);
      if (overlay.isEmpty) continue;
      final r = refreshOverlay(_readPack(catalog), overlay);
      _writeOverlay(catalog, r.overlay);
      for (final id in r.changed) {
        stdout.writeln('$catalog/$id: huella recalculada.');
      }
    }
    return;
  }
  if (args.length != 2 || args.first != '--fill') {
    stderr.writeln(
      'Uso: dart run tool/translate_content.dart --fill <directorio-5etools>\n'
      '     dart run tool/translate_content.dart --refresh',
    );
    exit(64);
  }
  final index = indexFiveEtools([
    for (final f in Directory(args[1]).listSync().whereType<File>())
      if (f.path.endsWith('.json'))
        (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>(),
  ]);
  var pendingCount = 0;
  for (final MapEntry(key: catalog, value: kinds) in fiveEtoolsKinds.entries) {
    final r = fillOverlay(
      catalog,
      _readPack(catalog),
      _readOverlay(catalog),
      (id) => englishName(index, kinds, id),
    );
    _writeOverlay(catalog, r.overlay);
    r.pending.forEach(stdout.writeln);
    pendingCount += r.pending.length;
  }
  stdout.writeln('Pendientes para traducir a mano: $pendingCount.');
}
