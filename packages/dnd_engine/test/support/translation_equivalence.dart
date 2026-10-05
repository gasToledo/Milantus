import 'package:dnd_engine/dnd_engine.dart';

/// Lo que el motor deduce del texto de una criatura. Si una traducción lo
/// cambia, cambió una regla y no solo un texto.
String _mecanica(Creature c) => [
      c.creatureType?.id,
      c.creatureSize?.id,
      c.passivePerceptionValue,
      c.darkvision,
      c.canFly,
      c.walkSpeed,
    ].join('/');

/// Las criaturas cuya mecánica deducida difiere entre el catálogo en español
/// [es] y el traducido [en], una por renglón con los dos valores.
List<String> mechanicalDifferences(ContentRepository es, ContentRepository en) {
  final diferencias = <String>[];
  for (final c in es.creatures.values) {
    final otra = en.creature(c.id);
    if (otra == null) continue;
    final (a, b) = (_mecanica(c), _mecanica(otra));
    if (a != b) diferencias.add('${c.id}: $a ≠ $b');
  }
  return diferencias;
}
