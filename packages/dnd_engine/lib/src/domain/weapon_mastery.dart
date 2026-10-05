/// Glosario de las propiedades de maestría con armas (PHB 2024, cap. 6), en
/// español y en inglés.
///
/// El campo `mastery` de un arma guarda el identificador en inglés (`nick`,
/// `vex`), que es lo que usan los datos y las importaciones. Este glosario le
/// pone nombre oficial y texto de regla para que la ficha no muestre el
/// identificador crudo.
///
/// El glosario es **descriptivo** salvo por `nick`: el compilador la lee para
/// meter el ataque de mano secundaria dentro de la acción de Atacar. Es la
/// única con efecto mecánico; el resto vive solo en su descripción.
library;

import 'content_language.dart';

/// Una propiedad de maestría: su nombre y qué hace, en los dos idiomas.
class WeaponMastery {
  /// Identificador en inglés, el que aparece en `Weapon.mastery`.
  final String id;
  final (String, String) _name;
  final (String, String) _description;

  /// [name] y [description] van como `(español, inglés)`; el nombre es el
  /// oficial del PHB 2024 en cada idioma.
  const WeaponMastery({
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

/// Las ocho propiedades de maestría, indexadas por su identificador.
const Map<String, WeaponMastery> weaponMasteries = {
  'cleave': WeaponMastery(
    id: 'cleave',
    name: ('Hender', 'Cleave'),
    description: (
      'Si acertás a una criatura con un ataque cuerpo a cuerpo con esta '
          'arma, podés hacer un ataque cuerpo a cuerpo con ella contra una '
          'segunda criatura que esté a 5 pies o menos de la primera y dentro de '
          'tu alcance. Si acertás, la segunda criatura sufre el daño del arma, '
          'pero no sumás tu modificador de característica salvo que sea '
          'negativo. Solo una vez por turno.',
      'If you hit a creature with a melee attack with this weapon, you can '
          'make a melee attack with it against a second creature within 5 '
          'feet of the first and within your reach. On a hit, the second '
          'creature takes the weapon’s damage, but you don’t add your ability '
          'modifier unless it’s negative. Once per turn.',
    ),
  ),
  'graze': WeaponMastery(
    id: 'graze',
    name: ('Rozar', 'Graze'),
    description: (
      'Si tu tirada de ataque con esta arma falla, podés causarle a la '
          'criatura un daño igual al modificador de característica que usaste '
          'para el ataque. Es del mismo tipo que inflige el arma y solo aumenta '
          'si aumenta ese modificador.',
      'If your attack roll with this weapon misses, you can deal damage to '
          'the creature equal to the ability modifier you used for the '
          'attack. It’s the weapon’s damage type, and it only increases if '
          'that modifier does.',
    ),
  ),
  'nick': WeaponMastery(
    id: 'nick',
    name: ('Mellar', 'Nick'),
    description: (
      'Cuando hagas el ataque extra de la propiedad Ligera, podés hacerlo '
          'como parte de la acción de Atacar en vez de como acción adicional. '
          'Solo una vez por turno.',
      'When you make the extra attack of the Light property, you can make it '
          'as part of the Attack action instead of as a Bonus Action. Once per '
          'turn.',
    ),
  ),
  'push': WeaponMastery(
    id: 'push',
    name: ('Empujar', 'Push'),
    description: (
      'Si acertás a una criatura con esta arma, podés empujarla hasta 10 pies '
          'en línea recta alejándola de vos, siempre que sea Grande o más '
          'pequeña.',
      'If you hit a creature with this weapon, you can push it up to 10 feet '
          'straight away from you, as long as it’s Large or smaller.',
    ),
  ),
  'sap': WeaponMastery(
    id: 'sap',
    name: ('Debilitar', 'Sap'),
    description: (
      'Si acertás a una criatura con esta arma, tiene desventaja en su '
          'próxima tirada de ataque antes del principio de tu siguiente turno.',
      'If you hit a creature with this weapon, it has Disadvantage on its '
          'next attack roll before the start of your next turn.',
    ),
  ),
  'slow': WeaponMastery(
    id: 'slow',
    name: ('Ralentizar', 'Slow'),
    description: (
      'Si acertás a una criatura con esta arma y le causás daño, podés '
          'reducir su velocidad en 10 pies hasta el principio de tu siguiente '
          'turno. Varios ataques con esta propiedad no acumulan: la reducción '
          'nunca supera los 10 pies.',
      'If you hit a creature with this weapon and deal damage to it, you can '
          'reduce its Speed by 10 feet until the start of your next turn. '
          'Several attacks with this property don’t stack: the reduction never '
          'exceeds 10 feet.',
    ),
  ),
  'topple': WeaponMastery(
    id: 'topple',
    name: ('Derribar', 'Topple'),
    description: (
      'Si acertás a una criatura con esta arma, podés obligarla a hacer una '
          'salvación de Constitución (CD 8 + tu modificador de característica '
          'del ataque + tu bonificador por competencia). Si falla, queda '
          'derribada.',
      'If you hit a creature with this weapon, you can force it to make a '
          'Constitution saving throw (DC 8 + the ability modifier you attacked '
          'with + your Proficiency Bonus). On a failed save, it has the Prone '
          'condition.',
    ),
  ),
  'vex': WeaponMastery(
    id: 'vex',
    name: ('Molestar', 'Vex'),
    description: (
      'Si acertás a una criatura con esta arma y le causás daño, tenés '
          'ventaja en tu siguiente tirada de ataque contra ella antes del final '
          'de tu siguiente turno.',
      'If you hit a creature with this weapon and deal damage to it, you have '
          'Advantage on your next attack roll against it before the end of '
          'your next turn.',
    ),
  ),
};

/// La condición para aprovechar cualquier maestría, que el glosario no repite
/// en cada entrada.
String get weaponMasteryRule => localized(
      'Solo la aprovecha quien tiene el rasgo Maestría con armas y es '
          'competente con el arma.',
      'Only someone with the Weapon Mastery feature who is proficient with '
          'the weapon can use it.',
    );

/// Nombre de una maestría en el idioma activo, o el identificador si es
/// desconocida (puede venir de homebrew o de una importación).
String weaponMasteryName(String id) => weaponMasteries[id]?.name ?? id;
