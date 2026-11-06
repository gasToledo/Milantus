import 'dnd_engine.dart';

/// Busca coincidencias exactas en claves y valores del documento. Así las
/// referencias de inventario, conjuros y rasgos viajan con la ficha aunque
/// aparezcan en campos distintos.
List<Character> charactersUsing(
  String contentId,
  Iterable<Character> characters,
) =>
    [
      for (final character in characters)
        if (_mentions(character.toJson(), contentId)) character,
    ];

bool _mentions(Object? node, String id) => switch (node) {
      String value => value == id,
      Map<Object?, Object?> map => map.keys.any((key) => key == id) ||
          map.values.any((value) => _mentions(value, id)),
      Iterable<Object?> list => list.any((value) => _mentions(value, id)),
      _ => false,
    };

/// El homebrew que usa la ficha: sin él, del otro lado no abriría.
Map<String, List<Map<String, dynamic>>> homebrewUsedBy(
  Character sheet,
  Map<String, List<Map<String, dynamic>>> all,
) =>
    {
      for (final entry in all.entries)
        if ([
          for (final doc in entry.value)
            if (charactersUsing('${doc['id']}', [sheet]).isNotEmpty) doc,
        ]
            case final used when used.isNotEmpty)
          entry.key: used,
    };
