import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// El Aura de Protección y los Golpes Radiantes eran solo texto: Ssarak llegó
/// a Paladín 20 con las salvaciones de un nivel 5 y la espada sin el 1d8
/// radiante.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character paladin(int level, {int charisma = 16}) => Character(
        id: 'p',
        name: 'Prueba',
        raceId: 'human',
        classId: 'paladin',
        backgroundId: 'soldier',
        level: level,
        assignedScores: {
          Ability.strength: 16,
          Ability.dexterity: 10,
          Ability.constitution: 14,
          Ability.intelligence: 8,
          Ability.wisdom: 10,
          Ability.charisma: charisma,
        },
        hpPerLevel: [10, for (var i = 1; i < level; i++) 6],
        equippedWeaponIds: const ['longsword', 'longbow'],
      );

  ComputedSheet compile(Character c) => CharacterCompiler(repo).compile(c);

  group('Aura de Protección', () {
    test('a nivel 6 suma el mod. de Carisma a todas las salvaciones', () {
      final antes = compile(paladin(5));
      final despues = compile(paladin(6));
      final carisma = despues.abilityModifiers[Ability.charisma]!;
      expect(carisma, greaterThan(1));
      for (final a in Ability.values) {
        expect(despues.savingThrow(a), antes.savingThrow(a) + carisma,
            reason: a.name);
      }
    });

    test('con Carisma negativo suma igual +1', () {
      final antes = compile(paladin(5, charisma: 8));
      final despues = compile(paladin(6, charisma: 8));
      expect(despues.abilityModifiers[Ability.charisma], lessThan(1));
      expect(despues.savingThrow(Ability.strength),
          antes.savingThrow(Ability.strength) + 1);
    });
  });

  group('Golpes Radiantes', () {
    Attack attack(ComputedSheet s, String weaponId) =>
        s.attacks.firstWhere((a) => a.baseWeaponId == weaponId);

    test('a nivel 11 el arma cuerpo a cuerpo suma 1d8 radiante', () {
      expect(attack(compile(paladin(10)), 'longsword').extraDamage, isEmpty);

      final espada = attack(compile(paladin(11)), 'longsword');
      expect(espada.extraDamage.single.dice, '1d8');
      expect(espada.extraDamage.single.type, DamageType.radiant.id);
      expect(espada.damageText,
          '${espada.damage} ${DamageType.slashing.label} + 1d8 ${DamageType.radiant.label}');
    });

    test('no se suma a un arma a distancia', () {
      expect(attack(compile(paladin(11)), 'longbow').extraDamage, isEmpty);
    });
  });
}
