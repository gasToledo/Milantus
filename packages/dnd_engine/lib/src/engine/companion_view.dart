import '../data/content_repository.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/creature.dart';
import '../domain/spell_slots.dart';
import 'character_compiler.dart';
import 'combat_ops.dart';

/// Los compañeros de una ficha **para leerlos**: lo que el cliente React pinta
/// en la tarjeta «Compañeros» y en el diálogo de invocar, ya resuelto contra la
/// ficha. Vive en el motor y no en el cliente porque cada número —los PG con el
/// nivel del espacio, qué espacio puede pagar, a quién reemplaza una nueva
/// invocación— es una regla, y acá se prueba con `dart test`.
///
/// Compila sin la Forma Salvaje a propósito: transformado, la ficha trae la CA
/// y las características de la bestia, y los compañeros se calculan con las del
/// personaje.
///
/// Devuelve `{options, instances, orphans}`:
/// - `options`, una por compañero que la ficha puede invocar. `free` es el uso
///   gratis del conjuro (`{name, left, max}`) y `slots` los espacios que
///   alcanzan, ambos solo si el compañero escala con el nivel del espacio.
///   `going` es la forma que se va si se invoca otro más.
/// - `instances`, una por compañero en juego cuya opción sigue existiendo, con
///   `index` (su lugar en `combat.companions`, que es lo que piden las
///   acciones). `gone` es true si su forma ya no está en el catálogo.
/// - `orphans`, los que quedaron sin opción (se sacó el conjuro que los
///   concedía).
Map<String, dynamic> companionsView(Character c, ContentRepository repo) {
  final sheet = CharacterCompiler(repo).compile(c);
  final combat = c.combat;

  final options = <Map<String, dynamic>>[];
  for (final o in sheet.companions) {
    final scales = o.scalesWithSpellLevel;
    final concentrates =
        o.spellId != null && (repo.spell(o.spellId!)?.concentration ?? false);

    CharacterResource? free;
    if (scales && o.spellId != null) {
      final id = innateSpellResourceId(o.spellId!);
      free = sheet.resources.where((r) => r.id == id && r.max > 0).firstOrNull;
    }

    // Las que se van por cortar la concentración no ocupan lugar: cuando la
    // opción concentra, `summonCompanion` las retira antes de contar.
    final active = [
      for (final i in combat.companions)
        if (i.optionId == o.id && !(concentrates && i.concentration)) i,
    ];
    final going = active.length >= o.maxActive && active.isNotEmpty
        ? _formName(o, active.first.creatureId, repo)
        : null;

    options.add({
      'id': o.id,
      'name': o.name,
      'source': o.source,
      'maxActive': o.maxActive,
      'spellId': o.spellId,
      'minSpellLevel': o.minSpellLevel,
      'scales': scales,
      'concentrates': concentrates,
      'forms': [
        for (final f in o.forms)
          {'id': f.id, 'name': f.name, 'kind': f.displayKind},
      ],
      'free': free == null
          ? null
          : {
              'name': free.name,
              'left': free.max - (combat.resourceUsage[free.key] ?? 0),
              'max': free.max,
            },
      'slots': scales
          ? [
              ..._slots(sheet.normalSpellSlotsByLevel, combat.spellSlotsUsed,
                  o.minSpellLevel, false),
              ..._slots(sheet.pactSlotsByLevel, combat.pactSlotsUsed,
                  o.minSpellLevel, true),
            ]
          : const [],
      'going': going,
    });
  }

  final instances = <Map<String, dynamic>>[];
  final orphans = <Map<String, dynamic>>[];
  for (var index = 0; index < combat.companions.length; index++) {
    final i = combat.companions[index];
    final option =
        sheet.companions.where((o) => o.id == i.optionId).firstOrNull;
    if (option == null) {
      orphans.add({
        'index': index,
        'name': repo.creature(i.creatureId)?.name ?? i.creatureId,
      });
      continue;
    }
    final form = option.form(i.creatureId);
    final view = form == null ? null : _preview(sheet, form, i.spellLevel);
    instances.add({
      'index': index,
      'optionId': i.optionId,
      'optionName': option.name,
      'creatureId': i.creatureId,
      'name': form?.name ?? repo.creature(i.creatureId)?.name ?? i.creatureId,
      'spellLevel': i.spellLevel,
      'concentration': i.concentration,
      'currentHp': i.currentHp,
      'tempHp': i.tempHp,
      'conditions': i.conditions.toList()..sort(),
      'gone': form == null,
      // Los PG y la CA salen del mismo cálculo que el perfil: el cliente no
      // tiene que leerlos de un texto.
      'maxHp': view?.maxHp,
      'armorClass': view?.armorClass,
      'profile': view?.profile,
      'row': view?.row,
    });
  }

  return {'options': options, 'instances': instances, 'orphans': orphans};
}

/// Cómo se vería [creature] de la opción [option] invocada con un espacio de
/// [level]: `{profile, row}` con la forma de `CreatureProfile` y `BestiaryRow`
/// del cliente. Es lo que muestra el diálogo de invocar antes de pagar. Null si
/// la opción o la forma no existen.
Map<String, dynamic>? companionPreview(
  Character c,
  ContentRepository repo,
  String option,
  String creature,
  int level,
) {
  final sheet = CharacterCompiler(repo).compile(c);
  final form = sheet.companions
      .where((o) => o.id == option)
      .firstOrNull
      ?.forms
      .where((f) => f.id == creature)
      .firstOrNull;
  if (form == null) return null;
  final v = _preview(sheet, form, level);
  return {'profile': v.profile, 'row': v.row};
}

String _formName(
        CompanionOption o, String creatureId, ContentRepository repo) =>
    o.form(creatureId)?.name ?? repo.creature(creatureId)?.name ?? creatureId;

/// Los niveles con espacios libres desde [min], de menor a mayor.
List<Map<String, dynamic>> _slots(
  Map<int, int> table,
  Map<int, int> used,
  int min,
  bool pact,
) {
  final levels = table.keys.where((l) => l >= min).toList()..sort();
  return [
    for (final l in levels)
      if ((table[l] ?? 0) - (used[l] ?? 0) > 0)
        {'level': l, 'pact': pact, 'max': table[l], 'used': used[l] ?? 0},
  ];
}

({
  Map<String, dynamic> profile,
  Map<String, dynamic> row,
  int maxHp,
  int armorClass,
}) _preview(ComputedSheet sheet, Creature form, int level) {
  final r = form.resolve(CombatOps.companionVars(sheet, spellLevel: level));
  // Se parte del JSON del catálogo (mismas claves que el Bestiario) y se pisa
  // lo que depende de la ficha. Los dados de golpe se sacan: los PG de un
  // compañero son una fórmula, no una tirada.
  final profile = <String, dynamic>{
    ...form.toJson(),
    'name': r.name,
    'kind': r.kind,
    'ac': '${r.armorClass}',
    'hp': '${r.maxHp}',
    'speed': r.speed,
    'senses': r.senses,
    'defenses': r.defenses,
    'traits': [for (final t in r.traits) t.toJson()],
    'actions': [
      for (final a in r.actions)
        {
          'name': a.name,
          'description': a.description,
          'attackBonus': a.attackBonus?.toString(),
          'damage': a.damage,
          'damageType': a.damageType,
          'reach': a.reach,
          'kind': a.kind.toJson(),
          if (a.spellcasting != null) 'spellcasting': a.spellcasting!.toJson(),
        },
    ],
  }..remove('hitDice');
  final row = <String, dynamic>{
    'id': form.id,
    'kind': form.displayKind,
    'type': form.creatureType?.id,
    'typeLabel': form.creatureType?.label,
    'cr': null,
    'crText': null,
    'initiative': form.initiativeModifier,
    'passivePerception': form.passivePerceptionValue,
    'meleeReach': [for (final a in form.actions) a.isMeleeReach],
  };
  return (
    profile: profile,
    row: row,
    maxHp: r.maxHp,
    armorClass: r.armorClass,
  );
}
