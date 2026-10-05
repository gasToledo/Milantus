/// Las condiciones de las reglas 2024, con lo que le hacen a quien las
/// sufre.
///
/// Viven acá y no adentro de una pantalla porque las miran dos: el gestor de
/// estados de la ficha del jugador —donde se marcan sobre el propio personaje
/// y sobre sus compañeros invocados— y los tags del combate del Modo DM, que
/// las ofrece como atajo.
///
/// El texto es del libro y no un resumen propio: en la mesa se lee para
/// resolver una discusión, así que acortarlo le sacaría justo lo que sirve.
library;

import 'package:dnd_engine/dnd_engine.dart' show localized;

/// Una condición: cómo se llama y qué le hace a quien la sufre, en español
/// y en inglés.
class ConditionInfo {
  final String labelEs;
  final String descriptionEs;
  final String labelEn;
  final String descriptionEn;
  const ConditionInfo(
    this.labelEs,
    this.descriptionEs,
    this.labelEn,
    this.descriptionEn,
  );

  /// Nombre en el idioma activo del contenido.
  String get label => localized(labelEs, labelEn);

  /// Qué hace, en el idioma activo del contenido.
  String get description => localized(descriptionEs, descriptionEn);
}

/// La condición que nombra un tag del combate, o null si es un tag escrito a
/// mano.
///
/// Los tags guardan la **etiqueta en español** (`labelEs`), no el id: así se
/// escribieron siempre, y cambiar eso obligaría a migrar los combates. Por eso
/// se reconoce también la inglesa, sin distinguir mayúsculas, y la que se
/// guarda al marcar una sigue siendo la española en los dos idiomas.
ConditionInfo? conditionForTag(String tag) {
  final t = tag.toLowerCase();
  for (final c in conditions.values) {
    if (c.labelEs.toLowerCase() == t || c.labelEn.toLowerCase() == t) return c;
  }
  return null;
}

/// Cómo se muestra un tag: una condición en el idioma activo, y lo escrito a
/// mano tal como se escribió.
String conditionTagLabel(String tag) => conditionForTag(tag)?.label ?? tag;

// l10n-ignore: texto del libro, en los dos idiomas; se lee con `label`.
const conditions = <String, ConditionInfo>{
  'blinded': ConditionInfo(
    'Cegado',
    'No podés ver y fallás automáticamente cualquier prueba que requiera vista. '
        'Los ataques contra vos tienen ventaja, y tus ataques tienen desventaja.',
    'Blinded',
    'You can’t see and automatically fail any check that requires sight. Attacks against you have Advantage, and your attacks have Disadvantage.',
  ),
  'charmed': ConditionInfo(
    'Hechizado',
    'No podés atacar a quien te hechizó ni dirigirle habilidades u efectos '
        'dañinos. Esa criatura tiene ventaja en pruebas sociales contra vos.',
    'Charmed',
    'You can’t attack the one who charmed you or target it with damaging abilities or effects. That creature has Advantage on social checks against you.',
  ),
  'deafened': ConditionInfo(
    'Ensordecido',
    'No podés oír y fallás automáticamente cualquier prueba que requiera oído.',
    'Deafened',
    'You can’t hear and automatically fail any check that requires hearing.',
  ),
  'frightened': ConditionInfo(
    'Asustado',
    'Tenés desventaja en pruebas de característica y ataques mientras la '
        'fuente de tu miedo esté a la vista. No podés acercarte voluntariamente a ella.',
    'Frightened',
    'You have Disadvantage on ability checks and attacks while the source of your fear is in sight. You can’t willingly move closer to it.',
  ),
  'grappled': ConditionInfo(
    'Agarrado',
    'Tu velocidad se vuelve 0 y no podés beneficiarte de ningún bonificador a la '
        'velocidad. La condición termina si quien te agarra queda incapacitado.',
    'Grappled',
    'Your Speed is 0 and you can’t benefit from any bonus to it. The condition ends if the grappler is Incapacitated.',
  ),
  'incapacitated': ConditionInfo(
    'Incapacitado',
    'No podés realizar acciones ni reacciones. (En 2024 tampoco te movés ni hablás.)',
    'Incapacitated',
    'You can’t take actions or Reactions. (In 2024 you also can’t move or speak.)',
  ),
  'invisible': ConditionInfo(
    'Invisible',
    'Sos imposible de ver sin magia o sentidos especiales. A efectos de '
        'esconderte, se te considera fuertemente oscurecido. Tus ataques tienen '
        'ventaja; los ataques contra vos tienen desventaja.',
    'Invisible',
    'You can’t be seen without magic or special senses. For hiding, you count as Heavily Obscured. Your attacks have Advantage; attacks against you have Disadvantage.',
  ),
  'paralyzed': ConditionInfo(
    'Paralizado',
    'Estás incapacitado y no podés moverte ni hablar. Fallás automáticamente '
        'las salvaciones de Fuerza y Destreza. Los ataques contra vos tienen '
        'ventaja, y todo impacto cuerpo a cuerpo es crítico si el atacante está a 5 pies.',
    'Paralyzed',
    'You’re Incapacitated and can’t move or speak. You automatically fail Strength and Dexterity saving throws. Attacks against you have Advantage, and any melee hit is a Critical Hit if the attacker is within 5 feet.',
  ),
  'petrified': ConditionInfo(
    'Petrificado',
    'Te transformás en sustancia sólida inanimada (junto a tu equipo). '
        'Incapacitado, no podés moverte ni hablar, sos inconsciente de tu entorno. '
        'Los ataques contra vos tienen ventaja, fallás salvaciones de Fuerza y '
        'Destreza, tenés resistencia a todo el daño e inmunidad a veneno y enfermedad.',
    'Petrified',
    'You’re turned into a solid inanimate substance (along with your gear). Incapacitated, you can’t move or speak and are unaware of your surroundings. Attacks against you have Advantage, you fail Strength and Dexterity saves, and you have Resistance to all damage and Immunity to poison and disease.',
  ),
  'poisoned': ConditionInfo(
    'Envenenado',
    'Tenés desventaja en tiradas de ataque y en pruebas de característica.',
    'Poisoned',
    'You have Disadvantage on attack rolls and ability checks.',
  ),
  'prone': ConditionInfo(
    'Derribado',
    'Solo podés moverte arrastrándote (o levantarte). Tenés desventaja al '
        'atacar. Los ataques cuerpo a cuerpo contra vos tienen ventaja; los '
        'ataques a distancia contra vos tienen desventaja.',
    'Prone',
    'You can only crawl (or stand up). You have Disadvantage on attacks. Melee attacks against you have Advantage; ranged attacks against you have Disadvantage.',
  ),
  'restrained': ConditionInfo(
    'Apresado',
    'Tu velocidad se vuelve 0. Los ataques contra vos tienen ventaja y tus '
        'ataques tienen desventaja. Tenés desventaja en salvaciones de Destreza.',
    'Restrained',
    'Your Speed is 0. Attacks against you have Advantage and your attacks have Disadvantage. You have Disadvantage on Dexterity saving throws.',
  ),
  'stunned': ConditionInfo(
    'Aturdido',
    'Estás incapacitado, no podés moverte y hablás solo entrecortadamente. '
        'Fallás automáticamente las salvaciones de Fuerza y Destreza. Los '
        'ataques contra vos tienen ventaja.',
    'Stunned',
    'You’re Incapacitated, can’t move, and can speak only falteringly. You automatically fail Strength and Dexterity saving throws. Attacks against you have Advantage.',
  ),
  'unconscious': ConditionInfo(
    'Inconsciente',
    'Estás incapacitado, no podés moverte ni hablar, y no sos consciente de tu '
        'entorno. Soltás lo que sostenías y caés derribado. Fallás automáticamente '
        'las salvaciones de Fuerza y Destreza. Los ataques contra vos tienen '
        'ventaja, y todo impacto cuerpo a cuerpo es crítico si el atacante está a 5 pies.',
    'Unconscious',
    'You’re Incapacitated, can’t move or speak, and are unaware of your surroundings. You drop what you’re holding and fall Prone. You automatically fail Strength and Dexterity saving throws. Attacks against you have Advantage, and any melee hit is a Critical Hit if the attacker is within 5 feet.',
  ),
};
