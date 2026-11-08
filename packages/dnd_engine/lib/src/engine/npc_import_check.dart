import '../data/content_repository.dart';
import '../domain/character.dart';
import '../domain/content_language.dart';

/// El contenido oficial que la ficha de un PNJ a importar usa y este catálogo
/// no tiene.
///
/// Lo mira el cliente porque el servidor no carga el catálogo. Un PNJ que
/// venga de una instalación con más libros cargados (PHB, Forge of the
/// Artificer) no se importa a medias: se avisa qué falta y no se escribe nada.
/// El homebrew que viaja en el archivo cuenta como disponible.
List<String> missingOfficialContent(
  Character? sheet,
  Map<String, List<Map<String, dynamic>>> bundledHomebrew,
  ContentRepository repo,
) {
  if (sheet == null) return const [];
  final bundled = {
    for (final docs in bundledHomebrew.values)
      for (final doc in docs) doc['id'],
  };
  bool known(String id, bool Function(String) inRepo) =>
      inRepo(id) || bundled.contains(id);
  return [
    if (!known(sheet.raceId, (id) => repo.race(id) != null))
      localized('especie «${sheet.raceId}»', 'species “${sheet.raceId}”'),
    for (final id in sheet.classHistory.toSet())
      if (!known(id, (id) => repo.characterClass(id) != null))
        localized('clase «$id»', 'class “$id”'),
    for (final id in sheet.subclassIds.values)
      if (!known(id, (id) => repo.subclass(id) != null))
        localized('subclase «$id»', 'subclass “$id”'),
    if (!known(sheet.backgroundId, (id) => repo.background(id) != null))
      localized(
        'trasfondo «${sheet.backgroundId}»',
        'background “${sheet.backgroundId}”',
      ),
  ];
}
