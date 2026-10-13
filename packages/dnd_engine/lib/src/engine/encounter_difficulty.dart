import 'dart:math';

/// Las tres dificultades del SRD 5.2.1 («Dificultad de los encuentros de
/// combate») y una cuarta que es de la app.
///
/// [extreme] no está en el libro: el SRD dice «sin excederlo» y no le pone
/// nombre a lo que pasa del presupuesto alto. El DM igual tiene que verlo, y
/// es justo el caso que más le importa.
enum EncounterTier { low, moderate, high, extreme }

/// Presupuesto de PX por personaje (SRD 5.2.1, pág. 221–222): baja, moderada
/// y alta para cada nivel del 1 al 20.
const _budgetByLevel = <(int, int, int)>[
  (50, 75, 100),
  (100, 150, 200),
  (150, 225, 400),
  (250, 375, 500),
  (500, 750, 1100),
  (600, 1000, 1400),
  (750, 1300, 1700),
  (1000, 1700, 2100),
  (1300, 2000, 2600),
  (1600, 2300, 3100),
  (1900, 2900, 4100),
  (2200, 3700, 4700),
  (2600, 4200, 5400),
  (2900, 4900, 6200),
  (3300, 5400, 7800),
  (3800, 6100, 9800),
  (4500, 7200, 11700),
  (5000, 8700, 14200),
  (5500, 10700, 17200),
  (6400, 13200, 22000),
];

/// Puntos de experiencia por valor de desafío (SRD 5.2.1, pág. 281).
final _xpByCr = <num, int>{
  // ponytail: el SRD dice «0 o 10» según la criatura, y el catálogo guarda el
  // VD pero no los PX. Se toma 10, que es lo que vale casi todo VD 0 que
  // ataca; si hace falta la excepción, el generador del bestiario tiene que
  // leer los PX del perfil y `Creature` guardarlos.
  0: 10,
  0.125: 25,
  0.25: 50,
  0.5: 100,
  1: 200,
  2: 450,
  3: 700,
  4: 1100,
  5: 1800,
  6: 2300,
  7: 2900,
  8: 3900,
  9: 5000,
  10: 5900,
  11: 7200,
  12: 8400,
  13: 10000,
  14: 11500,
  15: 13000,
  16: 15000,
  17: 18000,
  18: 20000,
  19: 22000,
  20: 25000,
  21: 33000,
  22: 41000,
  23: 50000,
  24: 62000,
  25: 75000,
  26: 90000,
  27: 105000,
  28: 120000,
  29: 135000,
  30: 155000,
};

/// Los PX de una criatura de valor de desafío [cr], o 0 si el VD no es uno de
/// la tabla (un homebrew con un número inventado no rompe la cuenta).
int xpForChallengeRating(num cr) => _xpByCr[cr] ?? 0;

/// Qué tan difícil es un encuentro para la mesa que lo va a pelear.
///
/// Es una guía y no un veredicto: los PX no ven cuántas acciones tiene cada
/// bando por ronda. Por eso el SRD acompaña la tabla con advertencias, y acá
/// viajan dos de ellas ([manyCreatures] y [powerfulCr]) al lado del número.
class EncounterDifficulty {
  /// Los tres presupuestos de la mesa: la suma, personaje por personaje, de
  /// lo que le toca a cada uno por su nivel, menos lo que les toca a los
  /// enemigos con ficha de personaje ([enemyCharacters]). Nunca negativos.
  final int lowBudget;
  final int moderateBudget;
  final int highBudget;

  final int enemyXp;

  /// Los PX de las criaturas que pelean del lado de la mesa. El SRD no habla
  /// de aliados; restarlos es criterio de la app.
  final int allyXp;

  /// Con cuántos personajes se armó el presupuesto.
  final int characters;

  /// El nivel más bajo y el más alto de esos personajes, o 0 sin ninguno.
  final int lowestLevel;
  final int highestLevel;

  /// Cuántos enemigos hay: criaturas, tengan VD o no, y personajes.
  final int enemies;

  /// Enemigos con ficha de personaje. No tienen VD ni PX: cuentan como un
  /// personaje del otro lado, así que **descuentan** su nivel del presupuesto
  /// igual que un aliado con ficha lo suma. Uno de cada lado y del mismo
  /// nivel se cancelan.
  final int enemyCharacters;

  /// Criaturas enemigas sin VD: no suman PX y la cuenta lo tiene que decir.
  final int uncountedEnemies;

  /// El VD más alto entre los enemigos cuando supera a [lowestLevel]
  /// («Criaturas poderosas» en el SRD), o null.
  ///
  /// Se compara contra el nivel más bajo y no contra un promedio: el aviso es
  /// sobre quién puede caer de un solo golpe.
  final num? powerfulCr;

  const EncounterDifficulty({
    required this.lowBudget,
    required this.moderateBudget,
    required this.highBudget,
    required this.enemyXp,
    required this.allyXp,
    required this.characters,
    required this.lowestLevel,
    required this.highestLevel,
    required this.enemies,
    required this.enemyCharacters,
    required this.uncountedEnemies,
    required this.powerfulCr,
  });

  /// Lo que la mesa tiene enfrente una vez descontados sus aliados. Nunca
  /// negativo: que sobren aliados no vuelve el combate «menos que nada».
  int get netXp => max(0, enemyXp - allyXp);

  /// La dificultad, o null si no hay con qué calcularla: sin personajes no
  /// hay presupuesto, y sin enemigos no hay encuentro.
  ///
  /// **El presupuesto es un techo**: el encuentro es de la dificultad más
  /// baja en cuyo presupuesto entra. El SRD dice «gastá todo lo que puedas,
  /// pero sin excederlo», y su ejemplo llama moderado a 1100 PX contra un
  /// presupuesto moderado de 1125.
  ///
  /// Un presupuesto en cero no admite nada: es el que se comieron los
  /// enemigos con ficha. Si igualan o superan a la mesa no queda ninguno, y
  /// el encuentro es extremo aunque no haya un solo PX enfrente.
  EncounterTier? get tier {
    if (characters == 0 || enemies == 0) return null;
    bool fits(int budget) => budget > 0 && netXp <= budget;
    if (fits(lowBudget)) return EncounterTier.low;
    if (fits(moderateBudget)) return EncounterTier.moderate;
    if (fits(highBudget)) return EncounterTier.high;
    return EncounterTier.extreme;
  }

  /// Cuánto queda por gastar dentro del presupuesto de [tier]; negativo es lo
  /// que se pasó del alto. 0 sin dificultad.
  int get remainingXp => switch (tier) {
        null => 0,
        EncounterTier.low => lowBudget - netXp,
        EncounterTier.moderate => moderateBudget - netXp,
        EncounterTier.high || EncounterTier.extreme => highBudget - netXp,
      };

  /// «Muchas criaturas» en el SRD: más de dos enemigos por personaje.
  bool get manyCreatures => characters > 0 && enemies > characters * 2;
}

/// Calcula la dificultad de un encuentro.
///
/// [partyLevels] son los niveles de quienes pelean por la mesa y tienen
/// ficha de personaje: los jugadores y los PNJ aliados con ficha. Un nivel
/// fuera de 1–20 se ignora.
///
/// [enemyCrs] y [allyCrs] llevan un valor por criatura; `null` es una que no
/// tiene VD. Los neutrales no entran en ninguna de las dos listas.
///
/// [enemyLevels] son los enemigos con ficha de personaje: la misma cuenta que
/// [partyLevels], con el signo cambiado.
EncounterDifficulty encounterDifficulty({
  required List<int> partyLevels,
  required List<num?> enemyCrs,
  List<num?> allyCrs = const [],
  List<int> enemyLevels = const [],
}) {
  List<int> valid(List<int> all) => [
        for (final l in all)
          if (l >= 1 && l <= _budgetByLevel.length) l,
      ];
  final levels = valid(partyLevels);
  final against = valid(enemyLevels);
  var low = 0, moderate = 0, high = 0;
  for (final (sign, side) in [(1, levels), (-1, against)]) {
    for (final l in side) {
      final (a, b, c) = _budgetByLevel[l - 1];
      low += sign * a;
      moderate += sign * b;
      high += sign * c;
    }
  }
  final lowest = levels.isEmpty ? 0 : levels.reduce(min);

  int xp(List<num?> crs) => crs.fold(
      0, (sum, cr) => sum + (cr == null ? 0 : xpForChallengeRating(cr)));

  final known = enemyCrs.whereType<num>();
  final top = known.isEmpty ? null : known.reduce(max);

  return EncounterDifficulty(
    lowBudget: max(0, low),
    moderateBudget: max(0, moderate),
    highBudget: max(0, high),
    enemyXp: xp(enemyCrs),
    allyXp: xp(allyCrs),
    characters: levels.length,
    lowestLevel: lowest,
    highestLevel: levels.isEmpty ? 0 : levels.reduce(max),
    enemies: enemyCrs.length + against.length,
    enemyCharacters: against.length,
    uncountedEnemies: enemyCrs.length - known.length,
    powerfulCr: top != null && levels.isNotEmpty && top > lowest ? top : null,
  );
}
