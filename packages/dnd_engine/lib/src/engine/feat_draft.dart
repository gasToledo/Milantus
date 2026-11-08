import '../domain/content.dart';
import '../domain/content_source.dart';
import '../domain/effects.dart';

/// El borrador de una dote que edita un formulario: pasa un [Feat] a texto
/// plano (`formOf`), arma la dote de vuelta (`build`) y dice qué campos no se
/// pueden guardar (`errors`). Es el mismo patrón que `CreatureDraft`.
///
/// Vive en el motor porque `dnd_web` no tiene reglas propias: qué conserva una
/// copia y qué hace falta para guardar se decide una vez, con su test.
class FeatDraft {
  const FeatDraft._();

  static String _t(Object? v) => (v?.toString() ?? '').trim();

  /// La plantilla de «Nueva dote»: de origen homebrew, general y sin nada más.
  /// El id es provisorio: el definitivo sale del nombre al guardar.
  static Feat empty() => const Feat(
        id: 'dote-propia',
        name: '',
        source: ContentSource.homebrew,
      );

  /// Lo que el formulario edita, como texto. Los efectos viajan como su JSON
  /// (el editor de efectos los arma y los quita, pero no los abre).
  /// [hasPrerequisite] no se edita: solo permite avisar que se conserva.
  static Map<String, dynamic> formOf(Feat f) => {
        'name': f.name,
        'category': f.category,
        'description': f.description,
        'repeatable': f.repeatable,
        'effects': [for (final e in f.effects) e.toJson()],
        'hasPrerequisite': f.prerequisite != null && !f.prerequisite!.isEmpty,
      };

  /// Arma la dote sobre [original]. No lanza por datos inválidos: también
  /// alimenta la vista previa mientras se escribe.
  ///
  /// Lo que el formulario no edita se conserva: una dote del catálogo
  /// duplicada sin su prerrequisito sería otra dote.
  static Feat build(Feat original, Map<String, dynamic> form) => Feat(
        id: original.id,
        name: _t(form['name']),
        source: ContentSource.homebrew,
        category: _t(form['category']).isEmpty
            ? original.category
            : _t(form['category']),
        description: _t(form['description']),
        // `fromJson` y no los efectos de la original: los que el editor no sabe
        // describir (elecciones, maquinaria de clase) pasan tal cual.
        effects: Effect.listFromJson(form['effects']),
        repeatable: form['repeatable'] == true,
        exclusiveGroup: original.exclusiveGroup,
        prerequisite: original.prerequisite,
        spellcastingAbilityOptions: original.spellcastingAbilityOptions,
      );

  /// Campo → código de error; vacío si se puede guardar. Hoy solo el nombre.
  static Map<String, String> errors(Map<String, dynamic> form) => {
        if (_t(form['name']).isEmpty) 'name': 'required',
      };
}
