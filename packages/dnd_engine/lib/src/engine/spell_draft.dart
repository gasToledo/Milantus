import '../domain/content.dart';
import '../domain/content_source.dart';
import 'draft_numbers.dart';

/// El borrador de un conjuro que edita un formulario (mismo patrón que
/// `ItemDraft`). Es el `_spell()`, la separación de los componentes y los
/// validadores de `SpellForm` de Flutter, llevados al motor.
class SpellDraft {
  const SpellDraft._();

  /// Los tiempos de lanzamiento que usa el catálogo, sin las reacciones con
  /// disparador (esas se conservan de a una, como opción del conjuro que las
  /// trae). Son valores guardados, en español: el formulario los rotula con
  /// `vocabularyLabel`. La ficha reconoce el tiempo por cómo empieza
  /// (`Spell.actionType`), por eso es una lista y no texto libre.
  static const castingTimes = [
    'Acción',
    'Acción Adicional',
    'Reacción',
    '1 minuto',
    '10 minutos',
    '1 hora',
    '8 horas',
    '12 horas',
    '24 horas',
  ];

  /// Las clases lanzadoras a las que el formulario deja asignar un conjuro.
  static const classIds = [
    'wizard',
    'sorcerer',
    'cleric',
    'druid',
    'bard',
    'warlock',
    'paladin',
    'ranger',
    'artificer',
  ];

  /// Las letras de componente, en el orden en que se escriben en la línea.
  static const componentLetters = ['V', 'S', 'M'];

  /// La plantilla de «Nuevo conjuro»: truco, sin escuela, de una acción, con
  /// componentes V y S. El id es provisorio: el definitivo sale del nombre al
  /// guardar.
  static Spell empty() => const Spell(
        id: 'conjuro-propio',
        name: '',
        source: ContentSource.homebrew,
        level: 0,
        castingTime: 'Acción',
        components: 'V, S',
        duration: 'Instantánea',
      );

  /// Lo que el formulario edita, como texto.
  ///
  /// Los componentes se guardan como **una línea** («V, S, M (una pizca de
  /// ceniza)»), que es como los trae el catálogo entero; acá se separan en las
  /// letras y el material para elegirlos de a uno, y [build] los vuelve a armar.
  static Map<String, dynamic> formOf(Spell s) {
    final letters = _letters(s.components);
    return {
      'name': s.name,
      'level': '${s.level}',
      'school': s.school,
      'castingTime': s.castingTime,
      'range': s.range,
      'duration': s.duration,
      'components': [
        for (final c in componentLetters)
          if (letters.contains(c)) c,
      ],
      'material': _material(s.components),
      'concentration': s.concentration,
      'ritual': s.ritual,
      'classes': [...s.classes],
      'description': s.description,
    };
  }

  /// Arma el conjuro sobre [original] (del que conserva el `id`). No lanza por
  /// datos inválidos: también alimenta la vista previa mientras se escribe.
  static Spell build(Spell original, Map<String, dynamic> form) => Spell(
        id: original.id,
        name: draftText(form['name']),
        source: ContentSource.homebrew,
        level: int.tryParse(draftText(form['level'])) ?? 0,
        school: draftText(form['school']),
        castingTime: draftText(form['castingTime']),
        range: draftText(form['range']),
        components: _componentsText(form),
        duration: draftText(form['duration']),
        concentration: form['concentration'] == true,
        ritual: form['ritual'] == true,
        description: draftText(form['description']),
        classes: [
          for (final id in (form['classes'] as List? ?? const []))
            id.toString(),
        ],
      );

  /// Campo → código de error; vacío si se puede guardar. Solo el nombre es
  /// obligatorio, como en Flutter.
  static Map<String, String> errors(Map<String, dynamic> form) => {
        if (draftText(form['name']).isEmpty) 'name': 'required',
      };

  /// Las letras marcadas, en el orden V, S, M, y el material entre paréntesis
  /// solo si M está marcada y el material no está vacío.
  static String _componentsText(Map<String, dynamic> form) {
    final marked = {
      for (final c in (form['components'] as List? ?? const [])) c.toString(),
    };
    final letters = [
      for (final c in componentLetters)
        if (marked.contains(c)) c,
    ].join(', ');
    final material = draftText(form['material']);
    return marked.contains('M') && material.isNotEmpty
        ? '$letters ($material)'
        : letters;
  }

  static Set<String> _letters(String text) {
    final head = text.split('(').first;
    return {for (final m in RegExp(r'\b[VSM]\b').allMatches(head)) m[0]!};
  }

  static String _material(String text) {
    final open = text.indexOf('(');
    final close = text.lastIndexOf(')');
    return open < 0 || close < open ? '' : text.substring(open + 1, close);
  }
}
