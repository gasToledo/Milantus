import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// La dificultad de un encuentro según el SRD 5.2.1 («Dificultad de los
/// encuentros de combate»), más lo que el libro no dice y la app decidió:
/// qué hacer con los aliados y cómo llamar a lo que se pasa del alto.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  num cr(String id) => repo.creature(id)!.cr!;

  test('los tres ejemplos del SRD caen en la dificultad que el libro dice', () {
    // Ejemplo 1: baja para cuatro de nivel 1, 200 PX.
    final uno = encounterDifficulty(
      partyLevels: List.filled(4, 1),
      enemyCrs: [cr('bugbear-warrior')],
    );
    expect(uno.lowBudget, 200);
    expect(uno.enemyXp, 200);
    expect(uno.tier, EncounterTier.low);

    // Ejemplo 2: moderada para cinco de nivel 3, 1125 PX; el libro arma una
    // de 1100. Con el presupuesto leído como piso, esta misma daría baja.
    final dos = encounterDifficulty(
      partyLevels: List.filled(5, 3),
      enemyCrs: [3, 0.5, ...List.filled(6, 0.25)],
    );
    expect(dos.moderateBudget, 1125);
    expect(dos.enemyXp, 1100);
    expect(dos.tier, EncounterTier.moderate);
    expect(dos.remainingXp, 25);

    // Ejemplo 3: alta para seis de nivel 15, 46 800 PX; el libro gasta 46 000.
    final tres = encounterDifficulty(
      partyLevels: List.filled(6, 15),
      enemyCrs: [17, 17, 9, 9],
    );
    expect(tres.highBudget, 46800);
    expect(tres.enemyXp, 46000);
    expect(tres.tier, EncounterTier.high);
  });

  test('el presupuesto es un techo: justo en el límite todavía entra', () {
    EncounterTier? tier(List<num> crs) => encounterDifficulty(
          partyLevels: List.filled(4, 3),
          enemyCrs: crs,
        ).tier;

    // Cuatro de nivel 3: 600 / 900 / 1600.
    expect(tier([1, 1, 1]), EncounterTier.low); // 600
    expect(tier([1, 1, 1, 0.125]), EncounterTier.moderate); // 625
    expect(tier([2, 2]), EncounterTier.moderate); // 900
    expect(tier([2, 2, 0.125]), EncounterTier.high); // 925
    expect(tier([2, 2, 3]), EncounterTier.high); // 1600
    expect(tier([2, 2, 3, 0.125]), EncounterTier.extreme); // 1625
  });

  test('lo que se pasa del alto es extrema, y dice por cuánto', () {
    final d = encounterDifficulty(
      partyLevels: List.filled(4, 3),
      enemyCrs: [5, 0.5],
    );
    expect(d.tier, EncounterTier.extreme);
    expect(d.remainingXp, d.highBudget - d.netXp);
    expect(d.remainingXp, isNegative);
  });

  test('con niveles mezclados el presupuesto se suma personaje por personaje',
      () {
    final d = encounterDifficulty(partyLevels: [3, 3, 3, 4], enemyCrs: [1]);
    expect(d.lowBudget, 150 * 3 + 250);
    expect(d.moderateBudget, 225 * 3 + 375);
    expect(d.highBudget, 400 * 3 + 500);
    expect((d.lowestLevel, d.highestLevel), (3, 4));
  });

  test(
      'un aliado con ficha sube el presupuesto: veinte goblins contra uno de '
      'nivel 20 no son un combate difícil', () {
    final goblins = List<num?>.filled(20, cr('goblin-warrior'));
    final sola = encounterDifficulty(
      partyLevels: List.filled(4, 3),
      enemyCrs: goblins,
    );
    expect(sola.tier, EncounterTier.high);

    final acompaniada = encounterDifficulty(
      partyLevels: [...List.filled(4, 3), 20],
      enemyCrs: goblins,
    );
    expect(acompaniada.tier, EncounterTier.low);
  });

  test('los PX de una criatura aliada se restan, y el neto no baja de cero',
      () {
    final d = encounterDifficulty(
      partyLevels: List.filled(4, 3),
      enemyCrs: List.filled(5, 1),
      allyCrs: [cr('ogre')],
    );
    expect(d.enemyXp, 1000);
    expect(d.allyXp, xpForChallengeRating(cr('ogre')));
    expect(d.netXp, 1000 - d.allyXp);
    expect(d.tier, EncounterTier.low);

    final sobran = encounterDifficulty(
      partyLevels: [1],
      enemyCrs: [0.125],
      allyCrs: [5],
    );
    expect(sobran.netXp, 0);
    expect(sobran.tier, EncounterTier.low);
  });

  test(
      'un enemigo con ficha descuenta su nivel del presupuesto, y se cancela '
      'con un aliado del mismo nivel', () {
    final base = encounterDifficulty(
      partyLevels: [3, 8],
      enemyCrs: [1],
    );
    final conVillano = encounterDifficulty(
      partyLevels: [3, 8],
      enemyCrs: [1],
      enemyLevels: [3],
    );
    expect(conVillano.lowBudget, base.lowBudget - 150);
    expect(conVillano.moderateBudget, base.moderateBudget - 225);
    expect(conVillano.highBudget, base.highBudget - 400);
    expect(conVillano.enemies, 2);
    expect(conVillano.enemyCharacters, 1);
    expect(conVillano.uncountedEnemies, 0);
    // No tiene PX: lo que mueve es el techo.
    expect(conVillano.enemyXp, base.enemyXp);

    final cancelados = encounterDifficulty(
      partyLevels: [3, 8, 3],
      enemyCrs: [1],
      enemyLevels: [3],
    );
    expect(
      (cancelados.lowBudget, cancelados.moderateBudget, cancelados.highBudget),
      (base.lowBudget, base.moderateBudget, base.highBudget),
    );
  });

  test(
      'si los enemigos con ficha igualan a la mesa no queda presupuesto: es '
      'extrema aunque no haya PX enfrente', () {
    final espejo = encounterDifficulty(
      partyLevels: [3, 3, 3, 3],
      enemyCrs: [],
      enemyLevels: [3, 3, 3, 3],
    );
    expect(espejo.highBudget, 0);
    expect(espejo.netXp, 0);
    expect(espejo.tier, EncounterTier.extreme);

    // Y de más nivel que la mesa no lo vuelve negativo.
    final jefe = encounterDifficulty(
      partyLevels: [3, 3],
      enemyCrs: [],
      enemyLevels: [20],
    );
    expect(jefe.lowBudget, 0);
    expect(jefe.tier, EncounterTier.extreme);
  });

  test('sin personajes o sin enemigos no hay dificultad que decir', () {
    expect(
      encounterDifficulty(partyLevels: [], enemyCrs: [1]).tier,
      isNull,
    );
    expect(
      encounterDifficulty(partyLevels: [3], enemyCrs: []).tier,
      isNull,
    );
  });

  test('avisa cuando hay más de dos enemigos por personaje', () {
    bool many(int enemies) => encounterDifficulty(
          partyLevels: List.filled(4, 3),
          enemyCrs: List.filled(enemies, 0.25),
        ).manyCreatures;
    expect(many(8), isFalse);
    expect(many(9), isTrue);
  });

  test('avisa del VD que supera al nivel más bajo de la mesa', () {
    // El ejemplo del libro: un ogro contra un mago de nivel 1.
    final d = encounterDifficulty(
      partyLevels: [1, 5],
      enemyCrs: [cr('ogre'), 0.25],
    );
    expect(d.powerfulCr, cr('ogre'));

    // Igual al nivel no es «superior».
    expect(
      encounterDifficulty(partyLevels: [2], enemyCrs: [2]).powerfulCr,
      isNull,
    );
  });

  test('un enemigo sin VD no suma PX, pero cuenta y queda dicho', () {
    final d = encounterDifficulty(
      partyLevels: List.filled(4, 3),
      enemyCrs: [1, null],
    );
    expect(d.enemyXp, 200);
    expect(d.enemies, 2);
    expect(d.uncountedEnemies, 1);
  });

  test('los PX salen del VD como lo guarda el catálogo, entero o fracción', () {
    expect(xpForChallengeRating(cr('goblin-warrior')), 50);
    expect(xpForChallengeRating(1), 200);
    expect(xpForChallengeRating(1.0), 200);
    expect(xpForChallengeRating(30), 155000);
    // Un VD que no está en la tabla no rompe la cuenta.
    expect(xpForChallengeRating(0.3), 0);
  });
}
