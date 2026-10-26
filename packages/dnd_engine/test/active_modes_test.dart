import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

import 'support/weapon_attacks.dart';

/// Estados activables: el mecanismo, probado con la Furia del Bárbaro
/// (SRD 5.2.1).
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  /// Bárbaro con FUE 16 y DES 14: el hacha usa Fuerza y el estoque, sutil,
  /// también —16 le gana a 14—; con DES 18 el estoque pasa a Destreza.
  Character barbaro(
    int level, {
    int dexterity = 14,
    List<InventoryEntry> inventory = const [],
    String? subclassId,
  }) =>
      Character(
        id: 'furia',
        name: 'Prueba',
        raceId: 'human',
        classId: 'barbarian',
        subclassId: subclassId,
        backgroundId: 'soldier',
        level: level,
        assignedScores: {
          Ability.strength: 16,
          Ability.dexterity: dexterity,
          Ability.constitution: 14,
          Ability.intelligence: 8,
          Ability.wisdom: 10,
          Ability.charisma: 10,
        },
        hpPerLevel: List.filled(level, 7),
        inventory: inventory,
      );

  const hacha = InventoryEntry(
    entryId: 'hacha',
    itemId: 'greataxe',
    equipped: true,
  );

  test('activarla gasta un uso y la ficha cambia; sin usos no se activa', () {
    final c = barbaro(1, inventory: const [hacha]);
    final calma = compiler.compile(c);
    expect(calma.activeModes.single.active, isFalse);
    expect(calma.resistances, isNot(contains('slashing')));

    expect(CombatOps.activateMode(c.combat, calma, 'rage'), isTrue);
    expect(c.combat.resourceUsage['rage'], 1);

    final furia = compiler.compile(c);
    expect(furia.activeModes.single.active, isTrue);
    expect(furia.resistances,
        containsAll(['bludgeoning', 'piercing', 'slashing']));
    expect(furia.saveAdvantages(Ability.strength), isNotEmpty);
    expect(furia.skillAdvantages('athletics'), isNotEmpty);
    // Hacha a dos manos 1d12 + FUE 3, más 2 de Furia, y la ficha dice qué
    // parte es de la Furia para poder mostrarlo.
    expect(furia.weaponAttacks.single.damage, '1d12 + 5');
    expect(furia.weaponAttacks.single.modeBonuses.single.amount, 2);
    final vista = furia.activeModes.single;
    expect(vista.resistances,
        containsAll(['bludgeoning', 'piercing', 'slashing']));
    expect(vista.damageBonus, 2);
    expect(vista.damageAbility, Ability.strength);
    expect(vista.noSpellcasting, isTrue);

    // Furia ya prendida: volver a activarla no gasta otro uso.
    expect(CombatOps.activateMode(c.combat, furia, 'rage'), isTrue);
    expect(c.combat.resourceUsage['rage'], 1);

    CombatOps.deactivateMode(c.combat, 'rage');
    final usos = furia.resources.singleWhere((r) => r.id == 'rage').max;
    c.combat.resourceUsage['rage'] = usos;
    expect(
      CombatOps.activateMode(c.combat, compiler.compile(c), 'rage'),
      isFalse,
    );
    expect(c.combat.activeModes, isEmpty);
  });

  test('el daño de Furia sigue la tabla y solo va a ataques con Fuerza', () {
    int extra(int level, {int dexterity = 14, String weapon = 'greataxe'}) {
      final c = barbaro(level, dexterity: dexterity, inventory: [
        InventoryEntry(entryId: 'arma', itemId: weapon, equipped: true),
      ]);
      c.combat.activeModes['rage'] = null;
      final con = compiler.compile(c).weaponAttacks.single.damage;
      c.combat.activeModes.clear();
      final sin = compiler.compile(c).weaponAttacks.single.damage;
      int mod(String d) => int.parse(d.split('+').last.trim());
      return mod(con) - mod(sin);
    }

    expect(extra(1), 2);
    expect(extra(9), 3);
    expect(extra(16), 4);
    // El estoque es sutil: con DES 18 ataca con Destreza y la Furia no suma.
    expect(extra(1, dexterity: 18, weapon: 'rapier'), 0);
  });

  test('la armadura pesada la apaga y no deja activarla', () {
    final c = barbaro(1, inventory: const [
      InventoryEntry(entryId: 'placas', itemId: 'plate', equipped: true),
    ]);
    c.combat.activeModes['rage'] = null;
    final sheet = compiler.compile(c);
    expect(sheet.activeModes.single.available, isFalse);
    expect(sheet.activeModes.single.active, isFalse);
    expect(sheet.resistances, isNot(contains('slashing')));
    c.combat.activeModes.clear();
    expect(CombatOps.activateMode(c.combat, sheet, 'rage'), isFalse);
  });

  test('un estado que incapacita la termina y no deja volver a prenderla', () {
    final c = barbaro(1, inventory: const [hacha]);
    c.combat.currentHp = 10;
    CombatOps.activateMode(c.combat, compiler.compile(c), 'rage');
    CombatOps.startConcentration(c.combat, 'Bendición');
    // Aturdido incluye Incapacitado (SRD 5.2.1): termina la Furia y se pierde
    // la concentración.
    CombatOps.setCondition(c.combat, 'stunned', true);
    expect(c.combat.activeModes, isEmpty);
    expect(c.combat.concentratingOn, isNull);

    final sheet = compiler.compile(c);
    expect(sheet.activeModes.single.blockedBy, ActiveModeBlock.incapacitated);
    expect(CombatOps.activateMode(c.combat, sheet, 'rage'), isFalse);

    CombatOps.setCondition(c.combat, 'stunned', false);
    expect(compiler.compile(c).activeModes.single.available, isTrue);
  });

  test(
      'termina sola al caer a 0 PG, que además corta la concentración, y al descansar',
      () {
    final c = barbaro(1, inventory: const [hacha]);
    c.combat.currentHp = 5;
    final sheet = compiler.compile(c);

    CombatOps.activateMode(c.combat, sheet, 'rage');
    CombatOps.startConcentration(c.combat, 'Bendición');
    CombatOps.applyDamage(c.combat, 10);
    expect(c.combat.activeModes, isEmpty);
    expect(c.combat.concentratingOn, isNull);

    c.combat.currentHp = 5;
    CombatOps.activateMode(c.combat, sheet, 'rage');
    CombatOps.shortRest(c.combat, sheet.resources);
    expect(c.combat.activeModes, isEmpty);
  });

  group('Las subclases le agregan a la Furia', () {
    test('Corazón Salvaje: la variante se elige al activarla', () {
      final c = barbaro(3, subclassId: 'wild-heart');
      final calma = compiler.compile(c);
      expect(calma.activeModes.single.variants.map((v) => v.id),
          containsAll(['bear', 'eagle', 'wolf']));

      CombatOps.activateMode(c.combat, calma, 'rage', variant: 'bear');
      final oso = compiler.compile(c);
      // El Oso resiste todo salvo fuerza, necrótico, psíquico y radiante.
      expect(oso.resistances, containsAll(['fire', 'cold', 'acid']));
      expect(oso.resistances, isNot(contains('psychic')));

      // Cambiar de animal con la Furia prendida no gasta otro uso.
      CombatOps.activateMode(c.combat, oso, 'rage', variant: 'eagle');
      expect(c.combat.resourceUsage['rage'], 1);
      expect(compiler.compile(c).resistances, isNot(contains('fire')));
    });

    test('Árbol del Mundo: PG temporales iguales al nivel al entrar', () {
      final c = barbaro(5, subclassId: 'world-tree');
      c.combat.currentHp = 30;
      final sheet = compiler.compile(c);
      expect(sheet.activeModes.single.tempHpOnActivate, 5);
      CombatOps.activateMode(c.combat, sheet, 'rage');
      expect(c.combat.tempHp, 5);
    });

    test('Berserker 6: entrar en Furia termina asustado y lo vuelve inmune',
        () {
      final c = barbaro(6, subclassId: 'berserker');
      c.combat.conditions.add('frightened');
      CombatOps.activateMode(c.combat, compiler.compile(c), 'rage');
      expect(c.combat.conditions, isNot(contains('frightened')));
      expect(compiler.compile(c).immunities,
          containsAll(['charmed', 'frightened']));
    });

    test('Fanático: 1d6 más la mitad del nivel, necrótico o radiante', () {
      final c = barbaro(5, subclassId: 'zealot', inventory: const [hacha]);
      c.combat.activeModes['rage'] = null;
      final extra = compiler.compile(c).weaponAttacks.single.extraDamage.single;
      expect(extra.dice, '1d6 + ${5 ~/ 2}');
      expect(extra.type, 'necrotic|radiant');
      // Fuera de la Furia no está.
      c.combat.activeModes.clear();
      expect(compiler.compile(c).weaponAttacks.single.extraDamage, isEmpty);
    });
  });
}
