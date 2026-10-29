@TestOn('vm')
library;

import 'dart:convert';
import 'dart:mirrors';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// `ComputedSheet.toJson`: el contrato con el cliente que no corre el motor en
/// Dart. Lo que se fija es que **no se pierda ningún campo** y que los números
/// clave viajen idénticos a los getters, no la forma exacta del JSON.
///
/// `dart:mirrors` se usa acá y nunca en `lib/`, igual que en
/// `computed_sheet_copywith_test.dart`: es lo único que atrapa el campo que
/// todavía no existe.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Set<String> camposDe(Type tipo) => reflectClass(tipo)
      .declarations
      .values
      .whereType<VariableMirror>()
      .where((v) => !v.isStatic)
      .map((v) => MirrorSystem.getName(v.simpleName))
      .toSet();

  const scores = {
    Ability.strength: 15,
    Ability.dexterity: 13,
    Ability.constitution: 14,
    Ability.intelligence: 12,
    Ability.wisdom: 16,
    Ability.charisma: 10,
  };

  final fichas = <String, Character>{
    'lanzador': Character(
      id: 'json-cleric',
      name: 'Prueba',
      raceId: 'human',
      classId: 'cleric',
      backgroundId: 'hermit',
      level: 3,
      assignedScores: scores,
      hpPerLevel: const [8, 5, 5],
      featureChoices: const {
        'divine-order': ['divine-order-thaumaturge'],
      },
      inventory: const [
        InventoryEntry(entryId: 'maza', itemId: 'mace', equipped: true),
      ],
      coins: const {'gp': 250},
    ),
    'marcial': Character(
      id: 'json-fighter',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      level: 5,
      assignedScores: scores,
      backgroundAbilityBonuses: const {
        Ability.strength: 2,
        Ability.constitution: 1,
      },
      chosenSkills: const ['perception', 'survival', 'insight'],
      featureChoices: const {
        'fighting-style': ['fs-defense'],
      },
      weaponMasteryChoices: const ['longsword', 'greatsword', 'dagger'],
      hpPerLevel: const [10, 6, 6, 6, 6],
      equippedArmorId: 'leather',
      equippedWeaponIds: const ['longsword'],
    ),
    'multiclase': Character(
      id: 'json-multi',
      name: 'Prueba',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      classHistory: const [
        'fighter',
        'fighter',
        'fighter',
        'wizard',
        'wizard',
      ],
      assignedScores: scores,
      hpPerLevel: const [10, 6, 6, 5, 5],
    ),
  };

  for (final MapEntry(key: nombre, value: personaje) in fichas.entries) {
    group('ficha $nombre', () {
      late ComputedSheet sheet;
      late Map<String, dynamic> json;

      setUp(() {
        sheet = CharacterCompiler(repo).compile(personaje);
        json = sheet.toJson();
      });

      test('es JSON puro y estable', () {
        expect(jsonDecode(jsonEncode(json)), json);
        expect(jsonEncode(sheet.toJson()), jsonEncode(json));
      });

      test(
          'cada campo público de la ficha y de sus tipos clave sale en el JSON',
          () {
        expect(camposDe(ComputedSheet).difference(json.keys.toSet()), isEmpty,
            reason: 'Un campo de ComputedSheet no se serializa en toJson.');
        final lanzamiento = sheet.spellcasting;
        if (lanzamiento != null) {
          expect(
            camposDe(Spellcasting)
                .difference(lanzamiento.toJson().keys.toSet()),
            isEmpty,
            reason: 'Un campo de Spellcasting no se serializa en toJson.',
          );
        }
      });

      test('los valores clave coinciden con los getters', () {
        expect(json['level'], sheet.level);
        expect(json['armorClass'], sheet.armorClass);
        expect(json['maxHp'], sheet.maxHp);
        expect(json['proficiencyBonus'], sheet.proficiencyBonus);
        expect(json['passivePerception'], sheet.passivePerception);
        for (final a in Ability.values) {
          expect(json['abilityScores'][a.name], sheet.abilityScores[a]);
          expect(json['abilityModifiers'][a.name], sheet.abilityModifiers[a]);
          expect(json['savingThrows'][a.name], sheet.savingThrow(a));
        }
        final ataques = json['attacks'] as List;
        expect(ataques.map((a) => a['name']), sheet.attacks.map((a) => a.name));
        for (var i = 0; i < sheet.attacks.length; i++) {
          expect(ataques[i]['attackBonus'], sheet.attacks[i].attackBonus);
          expect(ataques[i]['damage'], sheet.attacks[i].damage);
        }
        expect(
          json['normalSpellSlotsByLevel'],
          {
            for (final e in sheet.normalSpellSlotsByLevel.entries)
              '${e.key}': e.value,
          },
        );
        expect(
          (json['spellcasting'] as Map?)?['slotsByLevel'],
          sheet.spellcasting == null
              ? isNull
              : {
                  for (final e in sheet.spellcasting!.slotsByLevel.entries)
                    '${e.key}': e.value,
                },
        );
      });
    });
  }

  test('un ataque con todos los opcionales serializa todos sus campos', () {
    // Una ficha real omite las claves opcionales vacías, así que el chequeo
    // de campos se hace sobre un ataque que las trae todas.
    const ataque = Attack(
      weaponId: 'longsword',
      sourceEntryId: 'espada',
      name: 'Espada',
      attackBonus: 5,
      damage: '1d8 + 3',
      damageType: 'slashing',
      extraDamage: [WeaponExtraDamage(dice: '1d8', type: 'radiant')],
      mastery: 'sap',
      range: (30, 120),
      modeBonuses: [ModeDamageBonus(modeId: 'rage', name: 'Furia', amount: 2)],
    );
    expect(camposDe(Attack).difference(ataque.toJson().keys.toSet()), isEmpty,
        reason: 'Un campo de Attack no se serializa en toJson.');
    expect(jsonDecode(jsonEncode(ataque.toJson())), ataque.toJson());
  });

  test('las tres fichas cubren lo que el test dice cubrir', () {
    // Sin esto los chequeos de arriba pasarían por vacuidad.
    final lanzador = CharacterCompiler(repo).compile(fichas['lanzador']!);
    final marcial = CharacterCompiler(repo).compile(fichas['marcial']!);
    final multi = CharacterCompiler(repo).compile(fichas['multiclase']!);
    expect(lanzador.normalSpellSlotsByLevel, isNotEmpty);
    expect(marcial.attacks, isNotEmpty);
    expect(multi.classLevels.length, 2);
    expect(multi.spellcastingBlocks, isNotEmpty);
  });
}
