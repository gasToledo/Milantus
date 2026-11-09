import '../domain/ability.dart';
import '../domain/content.dart';
import '../domain/content_source.dart';
import '../domain/effects.dart';

/// El borrador de un trasfondo que edita un formulario (ver `RaceDraft` y
/// `FeatDraft`, el mismo patrón).
class BackgroundDraft {
  const BackgroundDraft._();

  static String _t(Object? v) => (v?.toString() ?? '').trim();

  /// Categorías de dote que pueden ser la de origen de un trasfondo: las de
  /// origen y, en Eberron, las marcas dracónicas.
  static const originFeatCategories = {'origin', 'dragonmark'};

  /// La plantilla de «Nuevo trasfondo». El id es provisorio.
  static Background empty() => const Background(
        id: 'trasfondo-propio',
        name: '',
        source: ContentSource.homebrew,
      );

  /// Lo que el formulario edita, como texto. Las características viajan por su
  /// `name` (`strength`...), el mismo id que usa el resto del motor.
  /// [hasStartingEquipment] no se edita: solo permite avisar que se conserva.
  static Map<String, dynamic> formOf(Background b) => {
        'name': b.name,
        'abilityOptions': [for (final a in b.abilityOptions) a.name],
        'originFeatId': b.originFeatId ?? '',
        'skillProficiencies': [...b.skillProficiencies],
        'toolProficiencies': [...b.toolProficiencies],
        'tagline': b.tagline ?? '',
        'description': b.description,
        'effects': [for (final e in b.effects) e.toJson()],
        'hasStartingEquipment': b.startingEquipment.isNotEmpty,
      };

  /// Arma el trasfondo sobre [original]. No lanza por datos inválidos.
  ///
  /// El equipo inicial y el emblema no se editan y se conservan: un trasfondo
  /// del catálogo duplicado sin su equipo empezaría la partida con las manos
  /// vacías.
  static Background build(Background original, Map<String, dynamic> form) {
    final tagline = _t(form['tagline']);
    final originFeat = _t(form['originFeatId']);
    final marked = {
      for (final a in (form['abilityOptions'] as List? ?? const [])) _t(a),
    };
    return Background(
      id: original.id,
      name: _t(form['name']),
      source: ContentSource.homebrew,
      // En el orden de `Ability.values`, sea cual sea el que se marcó primero.
      abilityOptions: [
        for (final a in Ability.values)
          if (marked.contains(a.name)) a,
      ],
      skillProficiencies: [
        for (final s in (form['skillProficiencies'] as List? ?? const []))
          s.toString(),
      ],
      toolProficiencies: [
        for (final s in (form['toolProficiencies'] as List? ?? const []))
          s.toString(),
      ],
      originFeatId: originFeat.isEmpty ? null : originFeat,
      tagline: tagline.isEmpty ? null : tagline,
      description: _t(form['description']),
      effects: Effect.listFromJson(form['effects']),
      startingEquipment: original.startingEquipment,
      iconId: original.iconId,
    );
  }

  /// Campo → código de error; vacío si se puede guardar. Con menos o más de
  /// tres características la creación no puede repartir el +2/+1 y el
  /// trasfondo quedaba guardado sin servir.
  static Map<String, String> errors(Map<String, dynamic> form) {
    final abilities = {
      for (final a in (form['abilityOptions'] as List? ?? const [])) _t(a),
    };
    return {
      if (_t(form['name']).isEmpty) 'name': 'required',
      if (abilities.length != 3) 'abilityOptions': 'three',
    };
  }
}
