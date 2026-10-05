import 'content_language.dart';

/// Alineamiento clásico (eje legal–caótico × bueno–malvado).
///
/// Es un dato **de sabor**: no participa del compilado de la ficha ni de
/// ninguna regla; solo se muestra y se exporta. Se llama `CharacterAlignment`
/// y no `Alignment` para no chocar con el `Alignment` de Flutter en la app.
enum CharacterAlignment {
  lawfulGood('Legal Bueno', 'Lawful Good'),
  neutralGood('Neutral Bueno', 'Neutral Good'),
  chaoticGood('Caótico Bueno', 'Chaotic Good'),
  lawfulNeutral('Legal Neutral', 'Lawful Neutral'),
  trueNeutral('Neutral', 'Neutral'),
  chaoticNeutral('Caótico Neutral', 'Chaotic Neutral'),
  lawfulEvil('Legal Malvado', 'Lawful Evil'),
  neutralEvil('Neutral Malvado', 'Neutral Evil'),
  chaoticEvil('Caótico Malvado', 'Chaotic Evil');

  const CharacterAlignment(this.labelEs, this.labelEn);

  final String labelEs;
  final String labelEn;

  /// Nombre en el idioma activo, para la UI.
  String get label => localized(labelEs, labelEn);

  String toJson() => name;

  /// Tolerante: ausente o desconocido devuelve null (las fichas anteriores a
  /// este campo simplemente no lo traen).
  static CharacterAlignment? fromJson(String? v) {
    if (v == null) return null;
    for (final a in CharacterAlignment.values) {
      if (a.name == v) return a;
    }
    return null;
  }
}
