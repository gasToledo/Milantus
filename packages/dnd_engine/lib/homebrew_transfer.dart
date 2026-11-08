// l10n-ignore-file: errores sin contexto de interfaz, en los dos idiomas con `localized` (siguen a `ContentLanguage`, que cada cliente fija con el idioma de la interfaz).
import 'dart:convert';

import 'dnd_engine.dart';

/// Las ocho categorías del homebrew, en el orden en que se muestran y se
/// exportan. Es la única lista: el servidor la usa para validar rutas y los
/// clientes para armar y leer el archivo.
const homebrewCategories = [
  'weapons',
  'armor',
  'items',
  'feats',
  'races',
  'backgrounds',
  'spells',
  'creatures',
];

/// Versión del sobre `dnd_homebrew`. Es **propia** del archivo de homebrew: no
/// tiene relación con la del respaldo ZIP ni con la del paquete de PNJ.
const homebrewExportFormatVersion = 1;

/// Todo el contenido homebrew (listas JSON por categoría) envuelto en el
/// formato `dnd_homebrew`. [exportedAt] se recibe y no se lee del reloj para
/// que quien llama (y las pruebas) decida la hora.
Map<String, dynamic> homebrewExportEnvelope(
  Map<String, List<Map<String, dynamic>>> content,
  DateTime exportedAt,
) =>
    {
      'type': 'dnd_homebrew',
      'formatVersion': homebrewExportFormatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'content': content,
    };

/// `homebrew-<fecha>.json`. Los `:` se cambian porque Windows no los admite en
/// un nombre de archivo.
String homebrewExportFileName(DateTime now) =>
    'homebrew-${now.toIso8601String().replaceAll(':', '-').split('.').first}.json';

/// Parsea un export de homebrew (`dnd_homebrew`) a listas JSON por tipo.
/// Lógica pura: formato liviano, sin relación con el respaldo ZIP principal
/// (que valida y aplica el servidor con `POST /api/import`).
Map<String, List<Map<String, dynamic>>> parseHomebrewImport(String jsonText) {
  final data = jsonDecode(jsonText);
  if (data is Map<String, dynamic> && data['type'] == 'dnd_homebrew') {
    final version = data['formatVersion'];
    if (version is! int || version < 1) {
      throw FormatException(
        localized(
          'La versión de la exportación de homebrew debe ser un entero positivo.',
          'The homebrew export version must be a positive integer.',
        ),
      );
    }
    if (version > homebrewExportFormatVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'exportación de homebrew',
        found: version,
        supported: homebrewExportFormatVersion,
      );
    }
    final content = (data['content'] as Map?)?.cast<String, dynamic>() ?? {};
    return {
      for (final key in homebrewCategories)
        key: ((content[key] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
    };
  }
  throw FormatException(
    localized(
      'El archivo no es una exportación de homebrew válida.',
      'The file isn’t a valid homebrew export.',
    ),
  );
}

/// Cuántas entradas de [content] tienen un id que **ya existe** en [ownIds]
/// (homebrew propio por categoría): las que un import sobrescribiría. Cero =
/// import puramente aditivo.
int countHomebrewCollisions(
  Map<String, List<Map<String, dynamic>>> content,
  Map<String, Set<String>> ownIds,
) {
  var n = 0;
  for (final entry in content.entries) {
    final ids = ownIds[entry.key];
    if (ids == null) continue;
    for (final j in entry.value) {
      if (ids.contains(j['id'] as String?)) n++;
    }
  }
  return n;
}

/// Evita que un id de inventario cambie de significado según qué catálogo
/// lo resuelva primero. Se permite sobrescribir homebrew del mismo tipo; el
/// contenido oficial y los cruces arma/armadura/objeto son inmutables.
void validateHomebrewInventoryIds(
  Map<String, List<Map<String, dynamic>>> content,
  ContentRepository repository,
) {
  final incomingKinds = <String, String>{};
  for (final entry in content.entries) {
    if (!const {'weapons', 'armor', 'items'}.contains(entry.key)) continue;
    for (final json in entry.value) {
      final id = json['id'];
      if (id is! String || id.trim().isEmpty) {
        throw FormatException(
          localized(
            'Un arma, armadura u objeto del archivo no tiene un id válido.',
            'A weapon, armor, or item in the file doesn’t have a valid id.',
          ),
        );
      }
      final previousKind = incomingKinds[id];
      if (previousKind != null && previousKind != entry.key) {
        throw FormatException(
          localized(
            'El id "$id" aparece en $previousKind y ${entry.key}.',
            'The id "$id" appears in $previousKind and ${entry.key}.',
          ),
        );
      }
      incomingKinds[id] = entry.key;

      final matches = <({String kind, ContentSource source})>[
        if (repository.weapons[id] case final value?)
          (kind: 'weapons', source: value.source),
        if (repository.armor[id] case final value?)
          (kind: 'armor', source: value.source),
        if (repository.items[id] case final value?)
          (kind: 'items', source: value.source),
      ];
      if (matches.isEmpty) continue;
      if (matches.length > 1) {
        throw FormatException(
          localized(
            'El id "$id" ya está repetido entre los catálogos de inventario.',
            'The id "$id" is already repeated across the inventory catalogs.',
          ),
        );
      }
      final existing = matches.single;
      if (existing.kind != entry.key) {
        throw FormatException(
          localized(
            'El id "$id" ya pertenece a ${existing.kind} y no puede usarse '
                'en ${entry.key}.',
            'The id "$id" already belongs to ${existing.kind} and can’t be '
                'used in ${entry.key}.',
          ),
        );
      }
      if (existing.source != ContentSource.homebrew) {
        throw FormatException(
          localized(
            'El id "$id" pertenece al catálogo oficial y no puede '
                'sobrescribirse.',
            'The id "$id" belongs to the official catalog and can’t be '
                'overwritten.',
          ),
        );
      }
    }
  }
}

/// Una copia propia de [json], con id y nombre nuevos y origen homebrew.
///
/// Viaja por JSON porque es el mismo ida y vuelta que ya hacen el guardado y
/// la importación: lo que el formulario no edita llega igual al documento
/// nuevo. La usan el botón de duplicar de Homebrew y el «Editar una copia» del
/// Bestiario.
Map<String, dynamic> homebrewCopy(Map<String, dynamic> json) {
  final name = '${json['name']} (copia)';
  return {
    ...json,
    'id': homebrewId(name),
    'name': name,
    'source': ContentSource.homebrew.toJson(),
  };
}

/// Genera un id a partir de un nombre (slug + sufijo para evitar colisiones).
String homebrewId(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-|-$)'), '');
  final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'hb-${slug.isEmpty ? 'item' : slug}-$suffix';
}
