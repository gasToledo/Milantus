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

/// Las clases que tienen el rasgo que pide de prerrequisito la dote [f]: la
/// validación lo busca **por nombre**, así que el nombre traducido del rasgo y
/// el del prerrequisito tienen que seguir coincidiendo.
Set<String> _requiredFeatureHolders(ContentRepository repo, Feat f) {
  final name = f.prerequisite?.requiredClassFeature;
  if (name == null) return const {};
  return {
    for (final c in repo.classes.values)
      if (c.features.any((x) => x.name == name)) c.id,
  };
}

/// Las criaturas y dotes cuya mecánica deducida difiere entre el catálogo en
/// español [es] y el traducido [en], una por renglón con los dos valores.
List<String> mechanicalDifferences(ContentRepository es, ContentRepository en) {
  final diferencias = <String>[];
  for (final f in es.feats.values) {
    final otra = en.feat(f.id);
    if (otra == null) continue;
    final (a, b) =
        (_requiredFeatureHolders(es, f), _requiredFeatureHolders(en, otra));
    if (a.length != b.length || !a.containsAll(b)) {
      diferencias.add('${f.id}: requiere un rasgo de $a ≠ $b');
    }
  }
  for (final c in es.creatures.values) {
    final otra = en.creature(c.id);
    if (otra == null) continue;
    final (a, b) = (_mecanica(c), _mecanica(otra));
    if (a != b) diferencias.add('${c.id}: $a ≠ $b');
  }
  return diferencias;
}
