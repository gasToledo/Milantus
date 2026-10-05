// l10n-ignore-file: el prompt del generador de imágenes se redacta en inglés a propósito, sea cual sea el idioma de la interfaz; no es texto que se muestre.
import 'package:dnd_engine/dnd_engine.dart';

/// Estilos predeterminados para la generación de retratos.
///
/// Son los valores que se guardan en los ajustes, en castellano desde antes
/// de que hubiera inglés: no se cambian. Lo que se muestra sale de
/// `_styleLabel` (pantalla de retratos) y lo que viaja en el prompt, de
/// [_styleEnglish].
const portraitStyles = <String>[
  'Arte digital de fantasía',
  'Óleo clásico',
  'Ilustración de cómic',
  'Realista cinematográfico',
  'Acuarela',
  'Pixel art',
  'Boceto a lápiz',
];

/// Cómo se le pide cada estilo predeterminado al generador.
const _styleEnglish = <String, String>{
  'Arte digital de fantasía': 'digital fantasy art',
  'Óleo clásico': 'classic oil painting',
  'Ilustración de cómic': 'comic book illustration',
  'Realista cinematográfico': 'cinematic realism',
  'Acuarela': 'watercolor',
  'Pixel art': 'pixel art',
  'Boceto a lápiz': 'pencil sketch',
};

/// El nombre en inglés de una entrada del catálogo para el prompt.
///
/// Sale del id, que es el slug inglés de la entrada («longsword», «half-orc»),
/// y no del repositorio, que puede estar en castellano: el prompt va en
/// inglés con la interfaz en cualquier idioma, porque los generadores de
/// imágenes responden mejor así. Una entrada homebrew no tiene un id inglés,
/// así que usa su nombre tal como se escribió.
String _englishName(String id, ContentSource? source, String? name) =>
    source == ContentSource.homebrew && name != null ? name : titleCaseId(id);

/// Construye el prompt de retrato auto-completando datos ya conocidos de la
/// ficha (especie, clase, armadura, arma) y sumando texto libre y estilo.
/// Siempre en inglés (ver [_englishName]); el texto libre va tal como lo
/// escribió la persona. Puro y testeable.
String buildPortraitPrompt({
  required Character character,
  required ContentRepository repo,
  required String style,
  required String extraText,
  bool includeWeapon = true,
}) {
  final race = repo.race(character.raceId);
  final raceName = race == null
      ? ''
      : _englishName(race.id, race.source, race.name);
  final classIds = <String>[];
  for (final id in character.classHistory) {
    if (!classIds.contains(id)) classIds.add(id);
  }
  final klass = classIds
      .map((id) {
        final c = repo.characterClass(id);
        return '${_englishName(id, c?.source, c?.name)} '
            '${character.classLevel(id)}';
      })
      .join(' · ');
  final armorId = character.equippedArmorId;
  final armor = armorId == null ? null : repo.armorPiece(armorId);
  final weaponId = !includeWeapon || character.equippedWeaponIds.isEmpty
      ? null
      : character.equippedWeaponIds.first;
  final weapon = weaponId == null ? null : repo.weapon(weaponId);

  final parts = <String>[
    'Fantasy character portrait (D&D)',
    [raceName, klass].where((s) => s.isNotEmpty).join(' '),
  ];
  if (armor != null) {
    parts.add('wearing ${_englishName(armor.id, armor.source, armor.name)}');
  }
  if (weapon != null) {
    parts.add(
      'wielding ${_englishName(weapon.id, weapon.source, weapon.name)}',
    );
  }

  return _assemble(parts, extraText, style);
}

String _assemble(List<String> parts, String extraText, String style) {
  final extra = extraText.trim();
  final base = [
    ...parts,
    if (extra.isNotEmpty) extra,
  ].where((s) => s.isNotEmpty).join(', ');
  final chosen = style.trim();
  // Un estilo escrito por la persona viaja tal cual, como el texto libre.
  final styleText = _styleEnglish[chosen] ?? chosen;
  final styleClause = styleText.isEmpty ? '' : ' Style: $styleText.';
  return '$base. Bust/portrait framing, simple background.$styleClause';
}

/// El prompt de retrato de un PNJ, que se completa solo según su tipo de
/// ficha: igual que un personaje si tiene ficha ([sheet]), con la criatura de
/// la que partió si tiene bloque, y sin nada automático si no tiene
/// estadísticas — el tabernero no tiene datos visuales de los que partir, así
/// que todo va en [extraText] (la «apariencia»).
///
/// **Nunca lee el trasfondo, las notas ni «cómo habla».** El proveedor es un
/// servicio externo y esos textos son justamente donde el DM guarda los
/// secretos de la campaña. No es una opción: la función no los toca.
String buildNpcPortraitPrompt({
  required Npc npc,
  required ContentRepository repo,
  required String style,
  required String extraText,
  Character? sheet,
  bool includeWeapon = true,
}) {
  if (npc.sheetKind == NpcSheetKind.character && sheet != null) {
    return buildPortraitPrompt(
      character: sheet,
      repo: repo,
      style: style,
      extraText: extraText,
      includeWeapon: includeWeapon,
    );
  }
  final block = npc.block;
  final parts = <String>['Fantasy character portrait (D&D)'];
  if (npc.sheetKind == NpcSheetKind.block && block != null) {
    final baseId = npc.baseCreatureId;
    parts.add(
      baseId != null && repo.creature(baseId) != null
          ? _englishName(baseId, repo.creature(baseId)!.source, null)
          : npc.baseCreatureName ?? block.name,
    );
    // El tamaño y el tipo, sin el alineamiento, que no se dibuja. Salen de
    // los lectores del motor, que entienden la línea de perfil en los dos
    // idiomas: el bloque del PNJ se copió en el idioma en que se creó.
    final kind = [
      block.creatureSize?.labelEn,
      block.creatureType?.labelEn,
    ].whereType<String>().join(' ');
    if (kind.isNotEmpty) parts.add(kind);
  }
  return _assemble(parts, extraText, style);
}
