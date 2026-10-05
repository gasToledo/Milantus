/// Vocabulario cerrado del catálogo que se guarda **en español**: la escuela,
/// el tiempo de lanzamiento, la duración y el alcance de un conjuro, y el
/// tamaño y el tipo de una especie.
///
/// Esos valores no se cambian por ids porque el homebrew los guarda igual y
/// no lleva versión: cambiarlos obligaría a migrarlo. Tampoco se traducen en
/// la superposición del catálogo: el motor lee algunos (`Spell.actionType`
/// sale de `castingTime`), y una sola vía de traducción para el oficial y el
/// homebrew es más simple que dos. Se traducen al mostrarlos, con
/// [vocabularyLabel].
library;

import 'content_language.dart';

/// Campo con vocabulario cerrado. El nombre es la clave del JSON.
enum VocabularyField {
  school,
  castingTime,
  duration,
  range,
  size,
  creatureType
}

/// Qué campos de vocabulario tiene cada catálogo. La superposición no puede
/// traducirlos: lo verifica `translationProblems`.
const vocabularyFieldsByCatalog = <String, Set<String>>{
  'spells': {'school', 'castingTime', 'duration', 'range'},
  'races': {'size', 'creatureType'},
};

const _english = <VocabularyField, Map<String, String>>{
  VocabularyField.school: {
    'Abjuración': 'Abjuration',
    'Adivinación': 'Divination',
    'Conjuración': 'Conjuration',
    'Encantamiento': 'Enchantment',
    'Evocación': 'Evocation',
    'Ilusionismo': 'Illusion',
    'Nigromancia': 'Necromancy',
    'Transmutación': 'Transmutation',
  },
  VocabularyField.castingTime: {
    'Acción': 'Action',
    'Acción Adicional': 'Bonus Action',
    'Reacción': 'Reaction',
    'Reacción, que realizás al recibir daño de una criatura que ves':
        'Reaction, which you take in response to taking damage from a '
            'creature you can see',
  },
  VocabularyField.duration: {
    'Instantánea': 'Instantaneous',
    'Especial': 'Special',
    'Hasta disipar': 'Until dispelled',
  },
  VocabularyField.range: {
    'Toque': 'Touch',
    'Personal': 'Self',
    'Personal (toque)': 'Self (touch)',
    'Ilimitado': 'Unlimited',
    'Vista': 'Sight',
  },
  VocabularyField.size: {
    'Diminuto': 'Tiny',
    'Pequeño': 'Small',
    'Mediano': 'Medium',
    'Grande': 'Large',
    'Enorme': 'Huge',
    'Gargantuesco': 'Gargantuan',
  },
  VocabularyField.creatureType: {
    'Aberración': 'Aberration',
    'Autómata': 'Construct',
    'Bestia': 'Beast',
    'Celestial': 'Celestial',
    'Cieno': 'Ooze',
    'Constructo': 'Construct',
    'Dragón': 'Dragon',
    'Elemental': 'Elemental',
    'Feérico': 'Fey',
    'Gigante': 'Giant',
    'Humanoide': 'Humanoid',
    'Infernal': 'Fiend',
    'Monstruosidad': 'Monstrosity',
    'Muerto viviente': 'Undead',
    'Planta': 'Plant',
  },
};

/// Unidades de tiempo y distancia, en singular y plural, para los valores que
/// llevan número («1 minuto», «Concentración, hasta 10 minutos», «Personal
/// (cono 30 pies)»). «dia» sin tilde está así en el catálogo.
const _units = {
  'asalto': 'round',
  'asaltos': 'rounds',
  'minuto': 'minute',
  'minutos': 'minutes',
  'hora': 'hour',
  'horas': 'hours',
  'día': 'day',
  'días': 'days',
  'dia': 'day',
  'dias': 'days',
  'milla': 'mile',
  'millas': 'miles',
  'pies': 'feet',
};

final _quantity = RegExp(r'^(\d+) (\p{L}+)$', unicode: true);

/// «30 pies» → «30 feet», «1 hora» → «1 hour».
String? _quantityEnglish(String value) {
  final m = _quantity.firstMatch(value);
  final unit = m == null ? null : _units[m[2]];
  return unit == null ? null : '${m![1]} $unit';
}

/// Formas de área de los alcances «Personal (cono 30 pies)».
const _shapes = {
  'cono': 'cone',
  'cubo': 'cube',
  'línea': 'line',
  'esfera': 'sphere',
  'aura de': 'aura',
};

String? _patternEnglish(VocabularyField field, String value) {
  switch (field) {
    case VocabularyField.duration:
      final hasta =
          RegExp(r'^(Concentración, hasta|Hasta) (.+)$').firstMatch(value);
      if (hasta != null) {
        final rest = _quantityEnglish(hasta[2]!);
        if (rest == null) return null;
        return hasta[1] == 'Hasta'
            ? 'Up to $rest'
            : 'Concentration, up to $rest';
      }
      return _quantityEnglish(value);
    case VocabularyField.castingTime:
      return _quantityEnglish(value);
    case VocabularyField.range:
      final cone = RegExp(r'^Cono de (\d+) pies$').firstMatch(value);
      if (cone != null) return '${cone[1]}-foot cone';
      final self =
          RegExp(r'^Personal \((?:(.+?) )?(\d+) pies\)$').firstMatch(value);
      if (self != null) {
        if (self[1] == null) return 'Self (${self[2]} feet)';
        final shape = _shapes[self[1]];
        return shape == null ? null : 'Self (${self[2]}-foot $shape)';
      }
      return _quantityEnglish(value);
    case VocabularyField.school:
    case VocabularyField.size:
    case VocabularyField.creatureType:
      return null;
  }
}

/// El valor [spanish] de [field] en inglés, o null si no está en la tabla ni
/// sigue un patrón conocido (un homebrew con texto propio).
String? vocabularyEnglish(VocabularyField field, String spanish) =>
    _english[field]![spanish] ?? _patternEnglish(field, spanish);

/// [value] en el idioma activo. Un valor desconocido se muestra tal cual.
String vocabularyLabel(VocabularyField field, String value) =>
    localized(value, vocabularyEnglish(field, value) ?? value);
