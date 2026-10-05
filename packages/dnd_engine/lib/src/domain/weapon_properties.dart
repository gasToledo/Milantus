/// Glosario de las propiedades de arma (PHB 2024, cap. 6) y de sus dos
/// categorías, en español y en inglés.
///
/// Mismo criterio que `weaponMasteries`: `Weapon.properties` guarda el id en
/// inglés (`finesse`, `two-handed`), que es lo que viaja en los datos, y acá
/// viven el nombre y la regla. Existe para explicar la elección a quien arma
/// un arma propia: «Sutil» no dice qué hace.
///
/// Es **descriptivo**. Las reglas que el compilador aplica (Sutil, Ligera, A
/// dos manos, Versátil) salen de los ids, no de estos textos.
library;

import 'content_language.dart';

/// Una propiedad de arma: su nombre y qué hace, en los dos idiomas.
class WeaponProperty {
  /// Identificador en inglés, el que aparece en `Weapon.properties`.
  final String id;
  final (String, String) _name;
  final (String, String) _description;

  /// [name] y [description] van como `(español, inglés)`.
  const WeaponProperty({
    required this.id,
    required (String, String) name,
    required (String, String) description,
  })  : _name = name,
        _description = description;

  /// Nombre en el idioma activo.
  String get name => localized(_name.$1, _name.$2);

  /// Qué hace, en el idioma activo.
  String get description => localized(_description.$1, _description.$2);
}

/// Las diez propiedades que usa el catálogo, en el orden en que se ofrecen.
const Map<String, WeaponProperty> weaponProperties = {
  'finesse': WeaponProperty(
    id: 'finesse',
    name: ('Sutil', 'Finesse'),
    description: (
      'Para el ataque y el daño usás, a elección, tu modificador de Fuerza '
          'o de Destreza, pero el mismo en las dos tiradas.',
      'For the attack and damage rolls you choose your Strength or Dexterity '
          'modifier, but the same one for both rolls.',
    ),
  ),
  'versatile': WeaponProperty(
    id: 'versatile',
    name: ('Versátil', 'Versatile'),
    description: (
      'Se puede empuñar con una o con dos manos. A dos manos, en un ataque '
          'cuerpo a cuerpo, hace el daño del dado versátil en vez del normal.',
      'It can be wielded with one or two hands. Two-handed, on a melee '
          'attack, it deals the versatile die’s damage instead of the normal '
          'one.',
    ),
  ),
  'two-handed': WeaponProperty(
    id: 'two-handed',
    name: ('A dos manos', 'Two-Handed'),
    description: (
      'Hacen falta las dos manos para atacar con ella.',
      'You need both hands to attack with it.',
    ),
  ),
  'light': WeaponProperty(
    id: 'light',
    name: ('Ligera', 'Light'),
    description: (
      'Si atacás con ella en la acción de Atacar, más tarde en el mismo '
          'turno podés hacer un ataque extra como acción adicional con otra '
          'arma Ligera. Ese ataque no suma tu modificador al daño, salvo que '
          'sea negativo.',
      'If you attack with it as part of the Attack action, later that turn '
          'you can make an extra attack as a Bonus Action with a different '
          'Light weapon. That attack doesn’t add your modifier to the damage, '
          'unless it’s negative.',
    ),
  ),
  'heavy': WeaponProperty(
    id: 'heavy',
    name: ('Pesada', 'Heavy'),
    description: (
      'Tenés desventaja al atacar con ella si es cuerpo a cuerpo y tu Fuerza '
          'es menor que 13, o si es a distancia y tu Destreza es menor que 13.',
      'You have Disadvantage on attacks with it if it’s a melee weapon and '
          'your Strength is below 13, or a ranged weapon and your Dexterity '
          'is below 13.',
    ),
  ),
  'thrown': WeaponProperty(
    id: 'thrown',
    name: ('Arrojadiza', 'Thrown'),
    description: (
      'Se puede lanzar para hacer un ataque a distancia, y sacarla es parte '
          'del ataque. Si es un arma cuerpo a cuerpo, se lanza con la misma '
          'característica con la que se ataca con ella.',
      'It can be thrown to make a ranged attack, and drawing it is part of '
          'the attack. If it’s a melee weapon, you throw it with the same '
          'ability you attack with.',
    ),
  ),
  'ranged': WeaponProperty(
    id: 'ranged',
    name: ('A distancia', 'Range'),
    description: (
      'Ataca desde lejos, con Destreza. Más allá del alcance normal el '
          'ataque tiene desventaja, y más allá del largo no se puede atacar.',
      'It attacks from afar, with Dexterity. Beyond the normal range the '
          'attack has Disadvantage, and beyond the long range you can’t '
          'attack.',
    ),
  ),
  'ammunition': WeaponProperty(
    id: 'ammunition',
    name: ('Munición', 'Ammunition'),
    description: (
      'Solo sirve si tenés munición para disparar, y cada ataque gasta una '
          'pieza. Después del combate, con 1 minuto de búsqueda recuperás la '
          'mitad de lo gastado.',
      'It only works if you have ammunition to fire, and each attack expends '
          'one piece. After the fight, a minute of searching recovers half of '
          'what you spent.',
    ),
  ),
  'reach': WeaponProperty(
    id: 'reach',
    name: ('Alcance', 'Reach'),
    description: (
      'Suma 5 pies a tu alcance al atacar con ella, también para los '
          'ataques de oportunidad.',
      'It adds 5 feet to your reach when you attack with it, including for '
          'Opportunity Attacks.',
    ),
  ),
  'loading': WeaponProperty(
    id: 'loading',
    name: ('Recarga', 'Loading'),
    description: (
      'Disparás una sola pieza de munición por acción, acción adicional o '
          'reacción, aunque normalmente puedas hacer más ataques.',
      'You fire only one piece of ammunition per action, Bonus Action, or '
          'Reaction, even if you can normally make more attacks.',
    ),
  ),
};

/// Lo que significan los dos números del alcance (`Weapon.rangeNormal` y
/// `Weapon.rangeLong`), que valen igual para A distancia y Arrojadiza.
String get weaponRangeRule => localized(
      'Hasta el alcance normal se ataca sin problema; entre el normal y el '
          'largo, con desventaja; más allá del largo no se puede atacar. Se '
          'mide en pies.',
      'Up to the normal range you attack as usual; between the normal and '
          'the long range, with Disadvantage; beyond the long range you can’t '
          'attack. Measured in feet.',
    );

/// Qué implica cada categoría de arma, por su id (`Weapon.category`).
Map<String, String> get weaponCategoryRules => localized(
      const {
        'simple':
            'Todas las clases del manual son competentes con las armas simples.',
        'martial':
            'Sin competencia con armas marciales se puede atacar igual, pero sin '
                'sumar el bonificador por competencia y sin usar su maestría.',
      },
      const {
        'simple': 'Every class in the book is proficient with Simple weapons.',
        'martial':
            'Without proficiency in Martial weapons you can still attack, but '
                'without adding your Proficiency Bonus or using their mastery.',
      },
    );
