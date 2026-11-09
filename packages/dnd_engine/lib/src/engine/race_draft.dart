import '../domain/content.dart';
import '../domain/content_source.dart';
import '../domain/effects.dart';

/// El borrador de una especie que edita un formulario: pasa una [Race] a texto
/// plano (`formOf`), arma la especie de vuelta (`build`) y dice qué campos no
/// se pueden guardar (`errors`). Mismo patrón que `FeatDraft`.
///
/// Vive en el motor porque `dnd_web` no tiene reglas propias: cuándo una
/// elección de tamaño es una elección, qué rango vale la velocidad y qué se
/// conserva de la original se decide una vez, con su test.
class RaceDraft {
  const RaceDraft._();

  static String _t(Object? v) => (v?.toString() ?? '').trim();

  /// Los tamaños que el contenido usa, en el orden en que se guardan. El valor
  /// guardado ya está en español (`Race.size`): id y valor coinciden.
  static const sizes = ['Pequeño', 'Mediano', 'Grande'];

  /// La plantilla de «Nueva especie». El id es provisorio: el definitivo sale
  /// del nombre al guardar.
  static Race empty() => const Race(
        id: 'especie-propia',
        name: '',
        source: ContentSource.homebrew,
      );

  /// Lo que el formulario edita, como texto. Los números viajan como texto para
  /// poder escribirlos a medias; los efectos, como su JSON.
  static Map<String, dynamic> formOf(Race r) => {
        'name': r.name,
        'creatureType': r.creatureType,
        'size': r.size,
        'speed': '${r.speed}',
        'tagline': r.tagline ?? '',
        'description': r.description,
        'skillChoiceCount': '${r.skillChoiceCount}',
        'skillChoiceFrom': [...r.skillChoiceFrom],
        'sizeOptions': [...r.sizeOptions],
        'effects': [for (final e in r.effects) e.toJson()],
      };

  /// Arma la especie sobre [original]. No lanza por datos inválidos: también
  /// alimenta la vista previa mientras se escribe.
  ///
  /// El emblema no se edita y se conserva: una copia sin él perdería el ícono.
  static Race build(Race original, Map<String, dynamic> form) {
    final tagline = _t(form['tagline']);
    final marked = {
      for (final s in (form['sizeOptions'] as List? ?? const [])) _t(s),
    };
    return Race(
      id: original.id,
      name: _t(form['name']),
      source: ContentSource.homebrew,
      creatureType: _t(form['creatureType']),
      description: _t(form['description']),
      tagline: tagline.isEmpty ? null : tagline,
      size: _t(form['size']),
      // Con un solo tamaño marcado no hay nada que elegir, y la creación
      // mostraría una elección de una opción: vale el tamaño de arriba.
      sizeOptions: marked.length < 2
          ? const []
          : [
              for (final s in sizes)
                if (marked.contains(s)) s,
            ],
      skillChoiceFrom: [
        for (final s in (form['skillChoiceFrom'] as List? ?? const []))
          s.toString(),
      ],
      iconId: original.iconId,
      speed: int.tryParse(_t(form['speed'])) ?? 0,
      skillChoiceCount: int.tryParse(_t(form['skillChoiceCount'])) ?? 0,
      // `fromJson` y no los efectos de la original: los que el editor no sabe
      // describir pasan tal cual.
      effects: Effect.listFromJson(form['effects']),
    );
  }

  /// Campo → código de error; vacío si se puede guardar. Los códigos son los de
  /// `CreatureDraft`: `required`, `number`, `integer` y `range:min:max`.
  static Map<String, String> errors(Map<String, dynamic> form) {
    final out = <String, String>{};
    void integer(String key, int min, int max) {
      final text = _t(form[key]);
      if (text.isEmpty) {
        out[key] = 'number';
        return;
      }
      final n = int.tryParse(text);
      if (n == null) {
        out[key] = 'integer';
      } else if (n < min || n > max) {
        out[key] = 'range:$min:$max';
      }
    }

    if (_t(form['name']).isEmpty) out['name'] = 'required';
    integer('speed', 0, 120);
    integer('skillChoiceCount', 0, 18);
    return out;
  }
}
