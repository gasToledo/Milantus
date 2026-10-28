import 'package:dnd_engine/dnd_engine.dart';

/// Resumen serializable de [ComputedSheet]. `ComputedSheet` no tiene `toJson`
/// (es una jerarquía grande de objetos derivados), así que el spike serializa a
/// mano solo los campos principales: alcanza para comparar VM contra JS.
Map<String, dynamic> summarizeSheet(ComputedSheet s) => {
      'level': s.level,
      'proficiencyBonus': s.proficiencyBonus,
      'classLevels': s.classLevels,
      'abilityScores': {
        for (final e in s.abilityScores.entries) e.key.name: e.value
      },
      'abilityModifiers': {
        for (final e in s.abilityModifiers.entries) e.key.name: e.value,
      },
      'maxHp': s.maxHp,
      'armorClass': s.armorClass,
      'speed': s.speed,
      'initiative': s.initiative,
      'passivePerception': s.passivePerception,
      'attacksPerAction': s.attacksPerAction,
      'savingThrowProficiencies':
          (s.savingThrowProficiencies.map((a) => a.name).toList()..sort()),
      'skillModifiers': {
        for (final id in (s.skillProficiencies.toList()..sort()))
          id: s.skillModifier(id),
      },
      'resources': (s.resources.map((r) => r.key).toList()..sort()),
    };
