/// Traducción del catálogo por superposición: cada catálogo `X.json` puede
/// tener un hermano `X.<idioma>.json` con solo los textos traducidos.
///
/// ```json
/// { "magic-missile": { "_es": "9f2c41aa", "name": "Magic Missile",
///                      "features.3.name": "…" } }
/// ```
///
/// La clave de primer nivel es el `id` de la entrada; adentro, cada clave es
/// la **ruta** del campo en la entrada en español, con índices para las
/// listas. Ruta y no id anidado porque los rasgos de clase no tienen id, y
/// tampoco nombre único: la Mejora de Característica se repite en cinco
/// niveles. La ruta por índice se rompe si el catálogo se reordena, y para eso
/// está la huella `_es`: el español del que salió la traducción. Si cambia,
/// [translationProblems] lo dice.
///
/// El español es siempre la fuente y el respaldo: una ruta sin traducir deja
/// el texto original, y así el inglés se puede completar de a poco.
library;

/// Clave de la huella del español dentro de cada entrada de la superposición.
const translationFingerprintKey = '_es';

/// Valor en [path] (segmentos separados por punto; los numéricos indexan
/// listas), o null si la ruta no existe.
Object? valueAtPath(Map<String, dynamic> entry, String path) {
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

/// Huella del español de [entry] en las rutas [paths]: FNV-1a de 32 bits en
/// hexadecimal. Alcanza para detectar que el texto cambió; no hace falta que
/// resista a nadie, y así el motor sigue sin dependencias.
///
/// Las rutas se ordenan para que la huella no dependa del orden de las claves
/// en el archivo, y cada ruta entra con su valor: mover un texto de un campo a
/// otro también cambia la huella.
String contentFingerprint(Map<String, dynamic> entry, Iterable<String> paths) {
  var hash = 0x811c9dc5;
  for (final path in paths.toList()..sort()) {
    final value = valueAtPath(entry, path);
    for (final unit in '$path\u0000${value ?? ''}\u0000'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Rutas traducidas de una entrada de la superposición (todo menos la huella).
Iterable<String> translatedPaths(Map<String, dynamic> translation) =>
    translation.keys.where((k) => k != translationFingerprintKey);

/// Devuelve [pack] con los textos de [overlay] aplicados encima.
///
/// No muta [pack]: copia solo las entradas traducidas, y dentro de ellas solo
/// los contenedores del camino hasta cada texto. Una ruta que no existe o que
/// no apunta a un texto se ignora y deja el español; que eso no pase en
/// silencio es trabajo de [translationProblems] y del test de integridad.
List<Map<String, dynamic>> applyContentTranslation(
  List<Map<String, dynamic>> pack,
  Map<String, dynamic> overlay,
) {
  if (overlay.isEmpty) return pack;
  return [
    for (final entry in pack)
      switch (overlay[entry['id']]) {
        final Map<String, dynamic> translation =>
          _translated(entry, translation),
        _ => entry,
      },
  ];
}

Map<String, dynamic> _translated(
  Map<String, dynamic> entry,
  Map<String, dynamic> translation,
) {
  var result = entry;
  for (final path in translatedPaths(translation)) {
    final text = translation[path];
    if (text is! String || valueAtPath(entry, path) is! String) continue;
    result = _withValue(result, path.split('.'), text) as Map<String, dynamic>;
  }
  return result;
}

/// Copia [node] con [value] en el camino [segments], copiando solo los
/// contenedores de ese camino.
Object _withValue(Object node, List<String> segments, String value) {
  if (segments.isEmpty) return value;
  final [head, ...rest] = segments;
  if (node is List) {
    final i = int.parse(head);
    return [...node]..[i] = _withValue(node[i] as Object, rest, value);
  }
  final map = node as Map<String, dynamic>;
  return {...map, head: _withValue(map[head] as Object, rest, value)};
}

/// Problemas de la superposición [overlay] del catálogo [catalog] frente a su
/// [pack] en español, uno por renglón y con la entrada que hay que revisar:
/// ids o rutas que ya no existen, rutas que no apuntan a un texto, huella
/// ausente o desfasada y, con [requireName], entradas sin `name` traducido.
List<String> translationProblems(
  String catalog,
  List<Map<String, dynamic>> pack,
  Map<String, dynamic> overlay, {
  bool requireName = false,
}) {
  final byId = {for (final e in pack) e['id'] as String: e};
  final problems = <String>[];
  for (final MapEntry(key: id, value: raw) in overlay.entries) {
    final entry = byId[id];
    if (entry == null) {
      problems.add('$catalog/$id: la entrada no existe en español.');
      continue;
    }
    if (raw is! Map<String, dynamic>) {
      problems.add('$catalog/$id: la traducción no es un objeto.');
      continue;
    }
    final paths = translatedPaths(raw).toList();
    for (final path in paths) {
      if (raw[path] is! String) {
        problems.add('$catalog/$id: «$path» no es un texto.');
      } else if (valueAtPath(entry, path) is! String) {
        problems.add('$catalog/$id: «$path» no existe en español.');
      }
    }
    final fingerprint = raw[translationFingerprintKey];
    if (fingerprint != contentFingerprint(entry, paths)) {
      problems.add(fingerprint == null
          ? '$catalog/$id: falta la huella del español.'
          : '$catalog/$id: el español cambió después de traducirlo.');
    }
  }
  if (requireName) {
    for (final id in byId.keys) {
      if ((overlay[id] as Map?)?['name'] is! String) {
        problems.add('$catalog/$id: falta el nombre traducido.');
      }
    }
  }
  return problems;
}
