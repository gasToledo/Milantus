import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/content_source.dart';
import '../domain/content_vocabulary.dart';
import '../domain/effects.dart';
import '../domain/language.dart';
import '../domain/proficiency_labels.dart';
import '../domain/skill.dart';
import 'character_compiler.dart';
import 'validation.dart';

/// Lo que la ficha propia deja **elegir o revisar**, como un mapa JSON de
/// lectura: las advertencias del motor y, por cada tipo de elección, sus cupos
/// con las opciones ya resueltas.
///
/// Existe para el cliente React, que no puede repetir las reglas de los
/// editores de `general_section.dart` (qué opción cumple su requisito, qué
/// competencia ya se tiene por otra vía, cuándo una aptitud mágica está
/// pendiente). Las acciones que escriben lo elegido están en
/// [SheetActions] (`setFeatureChoice`, `setLanguage`…) y aplican las mismas
/// condiciones.
///
/// Compila sin Forma Salvaje: ninguna de estas elecciones depende de la forma.
Map<String, dynamic> choicesView(Character c, ContentRepository repo) {
  final sheet = CharacterCompiler(repo).compile(c);
  final validator = CharacterValidator(repo);
  final warnings = validator.validate(c);

  String abilityLabel(Ability a) => a.label;
  Map<String, String> ability(Ability a) => {
        'id': a.name,
        'label': abilityLabel(a),
      };

  final features = [
    for (final slot in sheet.featureChoiceSlots)
      if (c.featureChoices[slot.groupId] ?? const <String>[] case final chosen)
        {
          'groupId': slot.groupId,
          'name': slot.name,
          'count': slot.count,
          'replaceable': slot.replaceable,
          'chosen': chosen,
          'pending': (slot.count - chosen.length).clamp(0, slot.count),
          'options': [
            for (final f in repo.featureChoiceOptions(slot))
              {
                'id': f.id,
                'name': f.name,
                // Las opciones de un rasgo (una invocación) no son dotes del
                // catálogo y el Códice no las conoce: su texto sale de acá,
                // como en `featSummary` de la subida de nivel.
                'description': f.description.isNotEmpty
                    ? f.description
                    : [
                        for (final e in f.effects)
                          if (e is PassiveTraitEffect) e.description,
                      ].join(' '),
                'homebrew': f.source == ContentSource.homebrew,
                // Lo ya elegido nunca va como inelegible: si no, no se podría
                // sacar una opción que dejó de cumplir su requisito.
                'unmet': chosen.contains(f.id)
                    ? null
                    : validator.unmetFeatPrerequisite(f, c, sheet),
              },
          ],
        },
  ];

  // Como el editor de Flutter: se compila sin la lista suelta de competencias
  // para que `fixed` sea solo lo que se tiene por otra vía.
  final profSheet = CharacterCompiler(repo)
      .compile(c.copyWith(chosenProficiencies: const []));
  final profSlots = [
    ...profSheet.proficiencyChoiceSlots,
    ...profSheet.expertiseChoiceSlots,
  ];
  final fixed = <String>{
    ...profSheet.skillProficiencies,
    ...profSheet.toolProficiencies,
  };
  for (final selected in c.proficiencyChoices.values) {
    fixed.removeAll(selected);
  }

  final proficiencies = [
    for (final slot in profSlots)
      {
        'groupId': slot.groupId,
        'name': slot.name,
        'count': slot.count,
        'expertise': slot.expertise,
        'replaceable': slot.replaceable,
        'chosen': slot.chosen,
        'pending': slot.pending,
        'options': [
          for (final id in slot.options)
            {
              'id': id,
              'label': slot.skills.contains(id)
                  ? Skill.labelFor(id)
                  : toolProficiencyLabel(id),
              // En un cupo de Pericia ser competente es el requisito, así que
              // `fixed` no bloquea; lo elegido en otro cupo sí, en los dos.
              'locked': !slot.chosen.contains(id) &&
                  ((!slot.expertise && fixed.contains(id)) ||
                      c.proficiencyChoices.entries
                          .where((e) => e.key != slot.groupId)
                          .any((e) => e.value.contains(id))),
            },
        ],
      },
  ];

  final spells = [
    for (final slot in sheet.spellChoiceSlots)
      {
        'groupId': slot.groupId,
        'name': slot.name,
        'count': slot.count,
        'replaceable': slot.replaceable,
        'grantsSpells': slot.grantsSpells,
        'chosen': slot.chosen,
        'pending': slot.pending,
        'options': [
          for (final id in slot.options)
            if (repo.spell(id) case final sp?)
              {'id': id, 'name': sp.name, 'level': sp.level},
        ],
      },
  ];

  final race = repo.race(c.raceId);
  final lineages = repo.lineagesForRace(c.raceId);
  final warningCodes = {for (final w in warnings) w.code};

  return {
    'warnings': [
      for (final w in warnings)
        {'code': w.code, 'message': w.message, 'severity': w.severity.name},
    ],
    // Las tres condiciones de `canReplace` en `_buildPersonaje`: cupo
    // reemplazable y ya completo, en rasgos, competencias o conjuros.
    'replaceable':
        features.any((s) => s['replaceable'] == true && s['pending'] == 0) ||
            proficiencies
                .any((s) => s['replaceable'] == true && s['pending'] == 0) ||
            spells.any((s) => s['replaceable'] == true && s['pending'] == 0),
    'features': features,
    'proficiencies': proficiencies,
    'spells': spells,
    'languages': {
      'originCount': Language.originChoiceCount,
      'origin': [
        for (final l in Language.originChoices) {'id': l.id, 'label': l.label},
      ],
      'chosenOrigin': c.languages,
      'universal': {
        'id': Language.universal.id,
        'label': Language.universal.label,
      },
      'slots': [
        for (final s in sheet.languageChoiceSlots)
          {
            'groupId': s.groupId,
            'name': s.name,
            'count': s.count,
            'chosen': s.chosen,
            'pending': s.pending,
            'options': [
              for (final id in s.options)
                {'id': id, 'label': Language.labelFor(id)},
            ],
          },
      ],
    },
    'origin': {
      'sizes': [
        for (final s in race?.sizeOptions ?? const <String>[])
          {'id': s, 'label': vocabularyLabel(VocabularyField.size, s)},
      ],
      'size': c.chosenSize,
      'lineages': [
        for (final l in lineages)
          {'id': l.id, 'name': l.name, 'description': l.description},
      ],
      'lineage': c.lineageId,
      'speciesAbilityPending':
          warningCodes.contains('species_spellcasting_ability_pending'),
      'speciesAbilityOptions': [
        for (final a in _speciesAbilities) ability(a),
      ],
      'speciesAbility': c.speciesSpellcastingAbility?.name,
      'featAbilities': [
        for (final id in validator.heldFeatIds(c))
          if (repo.feat(id) case final feat?)
            if (feat.spellcastingAbilityOptions.isNotEmpty)
              {
                'feat': id,
                'name': feat.name,
                'options': [
                  for (final a in feat.spellcastingAbilityOptions) ability(a),
                ],
                'chosen': c.featSpellcastingAbilities[id]?.name,
              },
      ],
    },
  };
}

/// Las aptitudes que ofrece la aptitud mágica de la especie (el linaje).
const _speciesAbilities = [
  Ability.intelligence,
  Ability.wisdom,
  Ability.charisma,
];
