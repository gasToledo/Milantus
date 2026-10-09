import 'dart:math';

import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content_language.dart';
import '../domain/content_vocabulary.dart';
import '../domain/proficiency_labels.dart';
import '../domain/content.dart';
import '../domain/effects.dart';
import '../domain/language.dart';
import '../domain/skill.dart';
import '../domain/spell_slots.dart';
import 'character_compiler.dart';
import 'inventory_ops.dart';

enum WarningSeverity { info, warning }

/// Advertencia de reglas. **Nunca bloquea**: la app siempre informa pero deja
/// actuar (el DM puede autorizar excepciones).
class ValidationWarning {
  final String code;
  final String message;
  final WarningSeverity severity;
  const ValidationWarning(this.code, this.message,
      [this.severity = WarningSeverity.warning]);

  @override
  String toString() => '[$code] $message';
}

/// Valida un personaje contra las reglas y devuelve advertencias, sin impedir
/// nada. Recibe el repositorio para chequear competencias y referencias.
class CharacterValidator {
  final ContentRepository repo;
  const CharacterValidator(this.repo);

  /// Nombre legible del grupo de una elección huérfana, para el aviso.
  ///
  /// El aviso mostraba el id («fighter:fighting-style»), que es un dato
  /// interno. Como el rasgo que declaraba el grupo ya no está en la ficha, el
  /// nombre se busca en todo el contenido; si nada lo declara —porque se
  /// retiró—, queda el id, que es lo único que hay. Con prefijo de clase, la
  /// clase va entre paréntesis: «Estilo de Combate (Guerrero)».
  String _choiceLabel(String groupId) {
    final separator = groupId.indexOf(':');
    final klass =
        separator > 0 ? repo.classes[groupId.substring(0, separator)] : null;
    // Hay grupos legacy con `:` que no son de ninguna clase
    // (`class:wizard:signature-spells`): esos se buscan enteros.
    final rawGroup = klass == null ? groupId : groupId.substring(separator + 1);

    Iterable<Effect> allEffects() sync* {
      for (final c in repo.classes.values) {
        for (final f in c.features) {
          yield* f.effects;
        }
      }
      for (final s in repo.subclasses.values) {
        for (final f in s.features) {
          yield* f.effects;
        }
      }
      for (final r in repo.races.values) {
        yield* r.effects;
      }
      for (final b in repo.backgrounds.values) {
        yield* b.effects;
      }
      for (final f in repo.feats.values) {
        yield* f.effects;
      }
    }

    String? name;
    for (final e in allEffects()) {
      if (e is FeatureChoiceEffect && e.groupId == rawGroup) {
        name = e.name;
      } else if (e is SpellChoiceEffect &&
          e.groupId == rawGroup &&
          e.name.isNotEmpty) {
        name = e.name;
      }
      if (name != null) break;
    }
    final label = name ?? rawGroup;
    return klass == null ? label : '$label (${klass.name})';
  }

  List<ValidationWarning> validate(Character c) {
    final w = <ValidationWarning>[];

    final race = repo.race(c.raceId);
    if (race == null) {
      w.add(ValidationWarning(
          'missing_race',
          localized(
            'Raza "${c.raceId}" no encontrada.',
            'Species "${c.raceId}" not found.',
          )));
    } else {
      // Linaje de especie: obligatorio si la especie ofrece alguno. Sin él, los
      // rasgos que dependen de la elección (resistencias, trucos) no se aplican.
      final options = repo.lineagesForRace(c.raceId);
      final lineageId = c.lineageId;
      if (lineageId == null) {
        if (options.isNotEmpty) {
          w.add(ValidationWarning(
            'lineage_pending',
            localized(
              'Falta elegir el linaje de ${race.name} '
                  '(${options.map((l) => l.name).join(", ")}).',
              'Choose a lineage for ${race.name} (${options.map((l) => l.name).join(", ")}).',
            ),
          ));
        }
      } else {
        final lineage = repo.lineage(lineageId);
        if (lineage == null) {
          w.add(ValidationWarning(
              'lineage_missing',
              localized(
                'Linaje "$lineageId" no encontrado.',
                'Lineage "$lineageId" not found.',
              )));
        } else if (lineage.raceId != c.raceId) {
          w.add(ValidationWarning(
            'lineage_wrong_race',
            localized(
              'El linaje "${lineage.name}" pertenece a ${lineage.raceId}, '
                  'no a ${c.raceId}.',
              'Lineage "${lineage.name}" belongs to ${lineage.raceId}, not ${c.raceId}.',
            ),
          ));
        } else if (_lineageUsesSpellcasting(lineage) &&
            c.speciesSpellcastingAbility == null) {
          w.add(ValidationWarning(
            'species_spellcasting_ability_pending',
            localized(
              'Falta elegir la aptitud mágica del linaje (INT, SAB o CAR).',
              'Choose the lineage’s spellcasting ability (INT, WIS, or CHA).',
            ),
          ));
        }
      }

      // Tamaño: solo lo piden las especies que ofrecen la elección. Sin ella el
      // personaje no queda roto —la ficha cae al tamaño por defecto— pero es
      // una elección del jugador que quedó sin hacer.
      final sizes = race.sizeOptions;
      final chosenSize = c.chosenSize;
      if (sizes.isNotEmpty) {
        if (chosenSize == null) {
          w.add(ValidationWarning(
            'size_pending',
            localized(
              'Falta elegir el tamaño de ${race.name} (${sizes.join(", ")}).',
              'Choose a size for ${race.name} (${sizes.map((s) => vocabularyLabel(VocabularyField.size, s)).join(", ")}).',
            ),
          ));
        } else if (!sizes.contains(chosenSize)) {
          w.add(ValidationWarning(
            'size_invalid',
            localized(
              'El tamaño "$chosenSize" no es una opción de ${race.name} '
                  '(${sizes.join(", ")}).',
              'Size "$chosenSize" isn’t an option for ${race.name} (${sizes.map((s) => vocabularyLabel(VocabularyField.size, s)).join(", ")}).',
            ),
          ));
        }
      } else if (chosenSize != null && chosenSize != race.size) {
        w.add(ValidationWarning(
          'size_not_choosable',
          localized(
            '${race.name} no elige tamaño: es ${race.size}.',
            '${race.name} doesn’t choose a size: it’s ${vocabularyLabel(VocabularyField.size, race.size)}.',
          ),
        ));
      }
    }
    final klass = repo.characterClass(c.classId);
    if (klass == null) {
      w.add(ValidationWarning(
          'missing_class',
          localized(
            'Clase "${c.classId}" no encontrada.',
            'Class "${c.classId}" not found.',
          )));
    }
    final background = repo.background(c.backgroundId);
    if (background == null) {
      w.add(ValidationWarning(
          'missing_background',
          localized(
            'Trasfondo "${c.backgroundId}" no encontrado.',
            'Background "${c.backgroundId}" not found.',
          )));
    }

    if (c.hpPerLevel.length != c.level) {
      w.add(ValidationWarning(
        'hp_entries',
        localized(
          'Faltan aportes de PG: ${c.hpPerLevel.length} registrados para ${c.level} niveles.',
          'Missing HP entries: ${c.hpPerLevel.length} recorded for ${c.level} levels.',
        ),
      ));
    }

    // Se compila para chequear valores derivados (maestrías, competencia).
    final sheet = CharacterCompiler(repo).compile(c);
    final classIds = <String>[];
    for (final id in c.classHistory.isEmpty ? [c.classId] : c.classHistory) {
      if (!classIds.contains(id)) classIds.add(id);
    }
    final initialClassId = classIds.first;
    for (final classId in classIds) {
      final classDefinition = repo.characterClass(classId);
      if (classDefinition == null) {
        if (classId != c.classId) {
          w.add(ValidationWarning(
            'missing_class',
            localized(
              'Clase "$classId" no encontrada.',
              'Class "$classId" not found.',
            ),
          ));
        }
        continue;
      }
      final multiclass = classDefinition.multiclass;
      if (multiclass != null &&
          !multiclass.meetsAbilityRequirements(sheet.abilityScores)) {
        w.add(ValidationWarning(
          'multiclass_prerequisite',
          localized(
            'Para tomar niveles de ${classDefinition.name} necesitás cumplir '
                'sus requisitos de multiclase (${multiclass.requirementLabel}).',
            'To take levels in ${classDefinition.name} you must meet its multiclass requirements (${multiclass.requirementLabel}).',
          ),
        ));
      }
    }

    // El techo normal es 20, pero un don épico lo sube a 30 y lo dice en su
    // propio efecto, así que el número sale del contenido y no de acá.
    //
    // ponytail: el techo es del personaje y no del punto. La regla fina es que
    // solo el +1 del don puede pasar de 20; con esto, un ASI común también
    // podría llegar a 21 sin que nadie avise. Distinguirlo pide rastrear de
    // dónde vino cada punto, que hoy no se guarda: si alguna vez importa, el
    // lugar es `SheetBuilder.addAbilityBonus`, que ya recibe un `source`.
    final ceiling = [
      20,
      for (final id in c.featIds)
        for (final e
            in repo.feat(id)?.effects.whereType<AbilityScoreChoiceEffect>() ??
                const <AbilityScoreChoiceEffect>[])
          e.max,
    ].reduce((a, b) => a > b ? a : b);

    for (final a in Ability.values) {
      if (sheet.abilityScores[a]! > ceiling) {
        w.add(ValidationWarning(
          'ability_over_20',
          localized(
            '${a.abbr} supera $ceiling (${sheet.abilityScores[a]}).',
            '${a.abbr} exceeds $ceiling (${sheet.abilityScores[a]}).',
          ),
        ));
      }
    }

    if (c.weaponMasteryChoices.length > sheet.weaponMasterySlots) {
      w.add(ValidationWarning(
        'too_many_masteries',
        localized(
          'Elegiste ${c.weaponMasteryChoices.length} maestrías pero tenés ${sheet.weaponMasterySlots} espacios.',
          'You chose ${c.weaponMasteryChoices.length} masteries but have ${sheet.weaponMasterySlots} slots.',
        ),
      ));
    }

    // La maestría requiere competencia con el arma. La elección se conserva por
    // si más adelante ganás la competencia, pero mientras tanto no se aplica.
    for (final weaponId in c.weaponMasteryChoices) {
      final weapon = repo.weapon(weaponId);
      if (weapon == null) continue;
      final proficient = weapon.isProficientWith(sheet.weaponProficiencies) ||
          sheet.attacks.any(
            (attack) => attack.baseWeaponId == weaponId && attack.proficient,
          );
      if (!proficient) {
        w.add(ValidationWarning(
          'mastery_not_proficient',
          localized(
            'No sos competente con ${weapon.name}: su maestría no se aplica.',
            'You aren’t proficient with ${weapon.name}: its mastery doesn’t apply.',
          ),
        ));
      }
    }

    final armorId = c.equippedArmorId;
    if (armorId != null) {
      final armor = repo.armorPiece(armorId);
      if (armor != null &&
          !armor.isShield &&
          !sheet.armorProficiencies.contains(armor.category)) {
        w.add(ValidationWarning(
          'armor_not_proficient',
          localized(
            'No tenés entrenamiento con ${armorTrainingLabel(armor.category).toLowerCase()}: desventaja y no podés lanzar conjuros.',
            'You aren’t trained with ${armorTrainingLabel(armor.category)}: Disadvantage, and you can’t cast spells.',
          ),
        ));
      }
      final strReq = armor?.strengthRequirement;
      if (strReq != null && sheet.abilityScores[Ability.strength]! < strReq) {
        w.add(ValidationWarning(
          'armor_strength',
          localized(
            '${armor!.name} requiere Fuerza $strReq: tu velocidad baja 10 pies.',
            '${armor.name} requires Strength $strReq: your Speed drops by 10 feet.',
          ),
          WarningSeverity.info,
        ));
      }
    }

    if (sheet.attacks.isEmpty) {
      w.add(ValidationWarning(
          'no_weapon',
          localized(
            'No hay arma equipada.',
            'No weapon equipped.',
          ),
          WarningSeverity.info));
    }

    final warnedEntries = <String>{};
    for (final attack in sheet.attacks) {
      final key = attack.sourceEntryId ?? attack.baseWeaponId;
      if (!attack.proficient && warnedEntries.add(key)) {
        w.add(ValidationWarning(
          'weapon_not_proficient',
          localized(
            'No sos competente con ${attack.name}: no sumás el bono de competencia al ataque.',
            'You aren’t proficient with ${attack.name}: you don’t add your Proficiency Bonus to the attack.',
          ),
        ));
      }
    }

    _validateInventory(c, sheet, w);
    _validateOffHand(c, repo, w);
    _validateFeatureChoices(c, sheet, w);
    _validateSpellChoices(c, sheet, w);
    _validateLanguages(c, w);
    _validateLanguageChoices(c, sheet, w);

    for (final a in c.assignedScores.values) {
      if (a < 3 || a > 18) {
        w.add(ValidationWarning(
          'ability_out_of_range',
          localized(
            'Una puntuación asignada ($a) está fuera del rango típico de generación (3-18).',
            'An assigned score ($a) is outside the typical generation range (3–18).',
          ),
          WarningSeverity.info,
        ));
      }
    }

    if (klass != null) {
      final raceSkillOptions = race == null
          ? const <String>[]
          : _skillChoiceOptions(
              race.skillChoiceCount,
              race.skillChoiceFrom,
            );
      final classSkillOptions = _skillChoiceOptions(
        klass.skillChoiceCount,
        klass.skillChoiceFrom,
      );
      final allowedSkills = {...raceSkillOptions, ...classSkillOptions};
      final expectedCount =
          (race?.skillChoiceCount ?? 0) + klass.skillChoiceCount;
      if (c.chosenSkills.length != expectedCount) {
        w.add(ValidationWarning(
          'skill_choice_count',
          localized(
            'Elegiste ${c.chosenSkills.length} habilidades pero corresponden $expectedCount.',
            'You chose ${c.chosenSkills.length} skills but should have $expectedCount.',
          ),
        ));
      }
      if (c.chosenSkills.toSet().length != c.chosenSkills.length) {
        w.add(ValidationWarning(
          'skill_choice_duplicate',
          localized(
            'Hay habilidades elegidas repetidas.',
            'Some chosen skills are repeated.',
          ),
        ));
      }
      for (final s in c.chosenSkills) {
        if (!allowedSkills.contains(s)) {
          w.add(ValidationWarning(
            'skill_choice_invalid',
            localized(
              'Habilidad "$s" no está entre las opciones de raza/clase.',
              'Skill "${Skill.labelFor(s)}" isn’t among the species or class options.',
            ),
          ));
        }
      }

      _validateProficiencyChoices(c, sheet, w);

      for (final classId in classIds) {
        final classDefinition = repo.characterClass(classId);
        if (classDefinition == null) continue;
        final classLevel = c.classLevel(classId);
        for (final level in classDefinition.asiLevels) {
          if (level > classLevel) continue;
          final hasChoice = c.asiChoices.any(
            (a) => (a.classId ?? initialClassId) == classId && a.level == level,
          );
          if (!hasChoice) {
            w.add(ValidationWarning(
              'asi_pending',
              localized(
                'Nivel $level: falta elegir mejora de característica o dote '
                    'de ${classDefinition.name}.',
                'Level $level: choose an Ability Score Improvement or feat for ${classDefinition.name}.',
              ),
              WarningSeverity.info,
            ));
          }
        }

        final subId = c.subclassForClass(classId);
        if (subId == null) {
          if (classLevel >= classDefinition.subclassLevel) {
            w.add(ValidationWarning(
              'subclass_pending',
              localized(
                'Nivel ${classDefinition.subclassLevel}: falta elegir '
                    'subclase de ${classDefinition.name}.',
                'Level ${classDefinition.subclassLevel}: choose a subclass for ${classDefinition.name}.',
              ),
              WarningSeverity.info,
            ));
          }
        } else {
          final sub = repo.subclass(subId);
          if (sub == null) {
            w.add(ValidationWarning(
                'subclass_missing',
                localized(
                  'Subclase "$subId" no encontrada.',
                  'Subclass "$subId" not found.',
                )));
          } else if (sub.classId != classId) {
            w.add(ValidationWarning(
              'subclass_wrong_class',
              localized(
                'La subclase ${sub.name} no pertenece a ${classDefinition.name}.',
                'Subclass ${sub.name} doesn’t belong to ${classDefinition.name}.',
              ),
            ));
          }
        }
      }
      for (final asi in c.asiChoices) {
        final classId = asi.classId ?? initialClassId;
        final classDefinition = repo.characterClass(classId);
        if (classDefinition == null ||
            !classDefinition.asiLevels.contains(asi.level)) {
          w.add(ValidationWarning(
            'asi_invalid_level',
            localized(
              'Nivel ${asi.level} no es un nivel de Mejora de Característica '
                  'de ${classDefinition?.name ?? classId}.',
              'Level ${asi.level} isn’t an Ability Score Improvement level for ${classDefinition?.name ?? classId}.',
            ),
          ));
        }
        // El +1 de un don con opciones restringidas guardado en otra
        // característica: fichas previas a que el asistente las filtrara.
        final featId = asi.featId;
        final choice = featId == null
            ? null
            : repo
                .feat(featId)
                ?.effects
                .whereType<AbilityScoreChoiceEffect>()
                .firstOrNull;
        if (choice == null) continue;
        for (final a in asi.abilityIncreases.keys) {
          if (!choice.allowed.contains(a)) {
            w.add(ValidationWarning(
              'feat_ability_not_allowed',
              localized(
                '${repo.feat(featId!)!.name} no puede subir ${a.abbr} '
                    '(solo ${choice.allowed.map((x) => x.abbr).join(", ")}).',
                '${repo.feat(featId)!.name} can’t raise ${a.abbr} (only ${choice.allowed.map((x) => x.abbr).join(", ")}).',
              ),
            ));
          }
        }
      }
    }

    for (final r in sheet.resources) {
      if (r.max <= 0) {
        w.add(ValidationWarning(
          'resource_zero_max',
          localized(
            'El recurso "${r.name}" tiene 0 usos: revisá su definición (falta "max"?).',
            'Resource "${r.name}" has 0 uses: check its definition (missing "max"?).',
          ),
        ));
      }
    }

    _validateSpells(c, sheet, w);

    final heldList = <String?>[
      repo.background(c.backgroundId)?.originFeatId,
      ...c.featIds,
      ...c.chosenFeatureOptionIds,
    ].whereType<String>().toList();
    final held = heldList.toSet();

    final counts = <String, int>{};
    for (final id in heldList) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final entry in counts.entries.where((e) => e.value > 1)) {
      final feat = repo.feat(entry.key);
      if (feat != null && !feat.repeatable) {
        w.add(ValidationWarning(
          'feat_duplicate',
          localized(
            '${feat.name}: esta dote no se puede elegir más de una vez.',
            '${feat.name}: this feat can’t be taken more than once.',
          ),
        ));
      }
    }

    final exclusiveGroups = <String, Set<String>>{};
    for (final id in held) {
      final feat = repo.feat(id);
      final group = feat?.effectiveExclusiveGroup;
      if (group != null) {
        exclusiveGroups.putIfAbsent(group, () => <String>{}).add(id);
      }
    }
    for (final entry
        in exclusiveGroups.entries.where((e) => e.value.length > 1)) {
      final names =
          entry.value.map((id) => repo.feat(id)?.name ?? id).join(', ');
      w.add(ValidationWarning(
        'feat_exclusive_group',
        localized(
          'Estas dotes son mutuamente excluyentes: $names.',
          'These feats are mutually exclusive: $names.',
        ),
      ));
    }

    // El set completo se necesita para las dotes que exigen otra dote: una
    // marca mayor mira si la marca base también está elegida.
    for (final id in held) {
      final feat = repo.feat(id);
      if (feat == null) continue;
      final missing = unmetFeatPrerequisite(feat, c, sheet, held: held);
      if (missing != null) {
        w.add(ValidationWarning(
          'feat_prerequisite',
          localized(
            '${feat.name}: no cumplís el prerrequisito ($missing).',
            '${feat.name}: you don’t meet the prerequisite ($missing).',
          ),
        ));
      }
      // La dote deja elegir su aptitud mágica y todavía no se eligió. Es
      // informativo, no bloqueante: los conjuros funcionan con la
      // característica que declara el contenido hasta que se resuelva.
      if (feat.spellcastingAbilityOptions.isNotEmpty &&
          !c.featSpellcastingAbilities.containsKey(feat.id)) {
        w.add(ValidationWarning(
          'feat_spellcasting_ability_pending',
          localized(
            '${feat.name}: falta elegir la aptitud mágica de sus conjuros.',
            '${feat.name}: choose the spellcasting ability for its spells.',
          ),
          WarningSeverity.info,
        ));
      }
    }

    return w;
  }

  /// Chequeos de las elecciones abiertas (Estilo de Combate, Invocaciones).
  ///
  /// No hay código de duplicado propio: las opciones son dotes y ya entran en
  /// `heldFeatIds`, así que `feat_duplicate`, `feat_exclusive_group` y
  /// `feat_prerequisite` las cubren sin repetir la regla acá.
  void _validateFeatureChoices(
      Character c, ComputedSheet sheet, List<ValidationWarning> w) {
    final slots = {for (final s in sheet.featureChoiceSlots) s.groupId: s};

    List<String> stored(String groupId) {
      final separator = groupId.indexOf(':');
      if (separator > 0) {
        final classId = groupId.substring(0, separator);
        final rawGroup = groupId.substring(separator + 1);
        return c.classFeatureChoices[classId]?[rawGroup] ??
            c.featureChoices[groupId] ??
            const [];
      }
      return c.featureChoices[groupId] ?? const [];
    }

    for (final slot in sheet.featureChoiceSlots) {
      final chosen = stored(slot.groupId);
      if (chosen.length < slot.count) {
        w.add(ValidationWarning(
          'feature_choice_pending',
          localized(
            '${slot.name}: elegiste ${chosen.length} de ${slot.count}.',
            '${slot.name}: you chose ${chosen.length} of ${slot.count}.',
          ),
          WarningSeverity.info,
        ));
      } else if (chosen.length > slot.count) {
        w.add(ValidationWarning(
          'too_many_feature_choices',
          localized(
            '${slot.name}: elegiste ${chosen.length} pero tenés ${slot.count} espacios.',
            '${slot.name}: you chose ${chosen.length} but have ${slot.count} slots.',
          ),
        ));
      }

      // Se compara contra el pozo resuelto, no contra el catálogo de dotes: un
      // rasgo puede traer sus opciones en línea (Orden Divina, Orden Primordial)
      // y esas nunca están en `feats`. Mirando solo el catálogo, la elección
      // correcta quedaba marcada como inválida y no había forma de arreglarla.
      final pool = {for (final o in repo.featureChoiceOptions(slot)) o.id};
      for (final id in chosen) {
        if (!pool.contains(id)) {
          w.add(ValidationWarning(
            'feature_choice_invalid',
            localized(
              '"$id" no es una opción de ${slot.name}.',
              '"$id" isn’t an option for ${slot.name}.',
            ),
          ));
        }
      }
    }

    // Elecciones guardadas de un rasgo que el personaje ya no tiene: pasa al
    // cambiar de clase o si el contenido que las declaraba se retiró. No se
    // borran solas, por si la pérdida es temporal.
    for (final groupId in c.featureChoices.keys) {
      if ((c.featureChoices[groupId] ?? const []).isEmpty) continue;
      if (slots.containsKey(groupId)) continue;
      w.add(ValidationWarning(
        'feature_choice_orphan',
        localized(
          'Tenés elecciones guardadas de «${_choiceLabel(groupId)}», un rasgo que ya no tenés.',
          'You have saved choices from “${_choiceLabel(groupId)}”, a feature you no longer have.',
        ),
        WarningSeverity.info,
      ));
    }
    // Con una sola clase, lo guardado por clase es la copia que dejó la
    // migración al esquema 24 y el compilador no la lee: avisar de ella era un
    // aviso sin arreglo posible (ver `Character.chosenFeatureOptionIds`).
    if (!c.hasMultipleClasses) return;
    for (final classEntry in c.classFeatureChoices.entries) {
      for (final groupId in classEntry.value.keys) {
        final scopedId = '${classEntry.key}:$groupId';
        if ((classEntry.value[groupId] ?? const []).isEmpty) continue;
        if (slots.containsKey(scopedId)) continue;
        w.add(ValidationWarning(
          'feature_choice_orphan',
          localized(
            'Tenés elecciones guardadas de «${_choiceLabel(scopedId)}», un rasgo que ya no tenés.',
            'You have saved choices from “${_choiceLabel(scopedId)}”, a feature you no longer have.',
          ),
          WarningSeverity.info,
        ));
      }
    }
  }

  /// Chequeos de la elección de conjuros (Conjuros Característicos,
  /// Descubrimientos Mágicos).
  ///
  /// No hay código propio para "lo elegí y además lo preparé": lo elegido entra
  /// en `alwaysPreparedSpellIds` y `_validateSpells` ya lo cubre con
  /// `spell_already_granted`, que es el punto único donde vive esa regla.
  void _validateSpellChoices(
      Character c, ComputedSheet sheet, List<ValidationWarning> w) {
    final slots = {for (final s in sheet.spellChoiceSlots) s.groupId: s};

    List<String> stored(String groupId) {
      final separator = groupId.indexOf(':');
      if (separator > 0) {
        final classId = groupId.substring(0, separator);
        final rawGroup = groupId.substring(separator + 1);
        return c.classSpellChoices[classId]?[rawGroup] ??
            c.spellChoices[groupId] ??
            const [];
      }
      return c.spellChoices[groupId] ?? const [];
    }

    for (final slot in sheet.spellChoiceSlots) {
      // Se lee lo guardado y no `slot.chosen`, que el compilador ya podó: si
      // se mirara el cupo, `spell_choice_invalid` no dispararía nunca. Mismo
      // criterio que `feature_choice_invalid`.
      final storedIds = stored(slot.groupId);

      if (slot.chosen.length < slot.count) {
        w.add(ValidationWarning(
          'spell_choice_pending',
          localized(
            '${slot.name}: elegiste ${slot.chosen.length} de ${slot.count}.',
            '${slot.name}: you chose ${slot.chosen.length} of ${slot.count}.',
          ),
          WarningSeverity.info,
        ));
      } else if (storedIds.length > slot.count) {
        w.add(ValidationWarning(
          'too_many_spell_choices',
          localized(
            '${slot.name}: elegiste ${storedIds.length} pero tenés ${slot.count} espacios.',
            '${slot.name}: you chose ${storedIds.length} but have ${slot.count} slots.',
          ),
        ));
      }

      for (final id in storedIds) {
        if (!slot.options.contains(id)) {
          w.add(ValidationWarning(
            'spell_choice_invalid',
            localized(
              '"$id" ya no es una opción de ${slot.name}.',
              '"$id" is no longer an option for ${slot.name}.',
            ),
          ));
        }
      }
    }

    for (final groupId in c.spellChoices.keys) {
      if ((c.spellChoices[groupId] ?? const []).isEmpty) continue;
      if (slots.containsKey(groupId)) continue;
      w.add(ValidationWarning(
        'spell_choice_orphan',
        localized(
          'Tenés conjuros elegidos de «${_choiceLabel(groupId)}», un rasgo que ya no tenés.',
          'You have spells chosen from “${_choiceLabel(groupId)}”, a feature you no longer have.',
        ),
        WarningSeverity.info,
      ));
    }
    // Mismo caso que en las elecciones de rasgo: con una sola clase, lo
    // guardado por clase es la copia de la migración y el compilador lee
    // solo `spellChoices`.
    if (!c.hasMultipleClasses) return;
    for (final classEntry in c.classSpellChoices.entries) {
      for (final groupId in classEntry.value.keys) {
        final scopedId = '${classEntry.key}:$groupId';
        if ((classEntry.value[groupId] ?? const []).isEmpty) continue;
        if (slots.containsKey(scopedId)) continue;
        w.add(ValidationWarning(
          'spell_choice_orphan',
          localized(
            'Tenés conjuros elegidos de «${_choiceLabel(scopedId)}», un rasgo que ya no tenés.',
            'You have spells chosen from “${_choiceLabel(scopedId)}”, a feature you no longer have.',
          ),
          WarningSeverity.info,
        ));
      }
    }
  }

  /// Chequeos de los idiomas del origen.
  ///
  /// Solo miran lo **elegido**: Común y lo que concede un rasgo no son
  /// decisiones del jugador y no pueden estar mal.
  void _validateLanguageChoices(
      Character c, ComputedSheet sheet, List<ValidationWarning> w) {
    final slots = {for (final s in sheet.languageChoiceSlots) s.groupId: s};

    for (final slot in sheet.languageChoiceSlots) {
      if (slot.chosen.length < slot.count) {
        w.add(ValidationWarning(
          'language_choice_pending_feature',
          localized(
            '${slot.name}: elegiste ${slot.chosen.length} de ${slot.count} '
                'idiomas.',
            '${slot.name}: you chose ${slot.chosen.length} of ${slot.count} languages.',
          ),
          WarningSeverity.info,
        ));
      }
    }

    for (final groupId in c.languageChoices.keys) {
      if ((c.languageChoices[groupId] ?? const []).isEmpty) continue;
      if (slots.containsKey(groupId)) continue;
      w.add(ValidationWarning(
        'language_choice_orphan',
        localized(
          'Tenés idiomas elegidos de "$groupId", un rasgo que ya no tenés.',
          'You have languages chosen from "$groupId", a feature you no longer have.',
        ),
        WarningSeverity.info,
      ));
    }
  }

  void _validateLanguages(Character c, List<ValidationWarning> w) {
    const cupo = Language.originChoiceCount;
    final elegidos = c.languages;

    if (elegidos.length < cupo) {
      w.add(ValidationWarning(
        'language_choice_pending',
        localized(
          'Idiomas: elegiste ${elegidos.length} de $cupo.',
          'Languages: you chose ${elegidos.length} of $cupo.',
        ),
        WarningSeverity.info,
      ));
    } else if (elegidos.length > cupo) {
      w.add(ValidationWarning(
        'too_many_languages',
        localized(
          'Idiomas: elegiste ${elegidos.length} pero te corresponden $cupo.',
          'Languages: you chose ${elegidos.length} but get $cupo.',
        ),
      ));
    }

    final vistos = <String>{};
    for (final id in elegidos) {
      if (!vistos.add(id)) {
        w.add(ValidationWarning(
          'language_duplicate',
          localized(
            '${Language.labelFor(id)} está elegido dos veces.',
            '${Language.labelFor(id)} is chosen twice.',
          ),
        ));
        continue;
      }
      // Común no se elige: ya se sabe, y gastarlo deja al personaje con un
      // idioma menos del que le corresponde.
      if (id == Language.universal.id) {
        w.add(ValidationWarning(
          'language_universal_chosen',
          localized(
            '${Language.labelFor(id)} lo sabe todo personaje: no ocupa una de '
                'tus elecciones.',
            'Every character knows ${Language.labelFor(id)}: it doesn’t take one of your choices.',
          ),
        ));
        continue;
      }
      final lang = Language.fromId(id);
      // Un id que el catálogo no conoce se deja pasar: puede venir de
      // homebrew. Lo que sí se avisa es elegir uno inusual, que por regla solo
      // llega por un rasgo.
      if (lang != null && !lang.standard) {
        w.add(ValidationWarning(
          'language_not_standard',
          localized(
            '${lang.label} no está entre los idiomas estándar: solo se obtiene '
                'por un rasgo.',
            '${lang.label} isn’t a standard language: it’s only gained through a feature.',
          ),
        ));
      }
    }
  }

  /// Chequeos de la mochila: carga y sintonización. Los dos son informativos y
  /// no recortan nada; el compilador aplica los efectos igual, porque el motor
  /// avisa y deja actuar.
  void _validateInventory(
    Character c,
    ComputedSheet sheet,
    List<ValidationWarning> w,
  ) {
    if (sheet.isEncumbered) {
      w.add(ValidationWarning(
        'encumbered',
        localized(
          'Llevás ${formatPounds(sheet.carriedWeight)} lb y tu capacidad es '
              '${sheet.carryingCapacity} lb.',
          'You’re carrying ${formatPounds(sheet.carriedWeight)} lb and your capacity is ${sheet.carryingCapacity} lb.',
        ),
        WarningSeverity.info,
      ));
    }

    final attuned = InventoryOps.attunedCount(c, repo);
    if (attuned > attunementSlots) {
      w.add(ValidationWarning(
        'attunement_over_limit',
        localized(
          'Tenés $attuned objetos sintonizados y solo podés mantener '
              '$attunementSlots.',
          'You have $attuned attuned items and can only keep $attunementSlots.',
        ),
      ));
    }
  }

  /// Chequeos del combate con dos armas (2024). Una entrada de [weaponOffHand]
  /// que no esté equipada se ignora en silencio, igual que [weaponTwoHanded]:
  /// desequipar un arma no debería ensuciar la ficha con advertencias.
  void _validateOffHand(
      Character c, ContentRepository repo, List<ValidationWarning> w) {
    // Lo empuñado sale del inventario, igual que en el compilador: la lista
    // vieja de armas equipadas ya no se llena al equipar, y validar sobre ella
    // callaba todo en una ficha nueva.
    final wielded = InventoryOps.wielded(c, repo);
    final offHand = [
      for (final unit in wielded)
        if (unit.offHand) unit.weapon
    ];
    if (offHand.isEmpty) return;

    if (offHand.length > 1) {
      w.add(ValidationWarning(
        'too_many_off_hands',
        localized(
          'Marcaste ${offHand.length} armas en la mano secundaria: solo se empuña una.',
          'You marked ${offHand.length} weapons in the off hand: only one can be wielded.',
        ),
      ));
    }

    for (final weapon in offHand) {
      if (!weapon.isLight) {
        w.add(ValidationWarning(
          'off_hand_not_light',
          localized(
            '${weapon.name} no es Ligera: el ataque de mano secundaria exige un arma Ligera.',
            '${weapon.name} isn’t Light: the off-hand attack requires a Light weapon.',
          ),
        ));
      }
    }

    // El ataque extra sale de empuñar **dos** armas Ligeras: con una sola no hay
    // nada que hacer en la mano secundaria.
    final hasLightMainHand =
        wielded.any((unit) => !unit.offHand && unit.weapon.isLight);
    if (!hasLightMainHand) {
      w.add(ValidationWarning(
        'off_hand_without_pair',
        localized(
          'No hay otra arma Ligera en la mano principal: el ataque de mano secundaria no se puede hacer.',
          'There’s no other Light weapon in the main hand: the off-hand attack can’t be made.',
        ),
        WarningSeverity.info,
      ));
    }
  }

  bool _lineageUsesSpellcasting(Lineage lineage) => lineage.features.any(
        (feature) =>
            feature.effects.any((effect) => effect is GrantSpellEffect),
      );

  /// Chequeos no bloqueantes sobre trucos y conjuros elegidos.
  /// Cuántos trucos y conjuros de clase le faltan elegir a [c] en cada bloque
  /// de lanzamiento de [sheet]. Solo cuenta lo que se **puede** elegir: si la
  /// lista se agotó, el faltante es 0, porque reclamarlo sería un aviso
  /// imposible de resolver.
  ///
  /// Es la misma regla para la advertencia de la ficha y para el paso de
  /// conjuros de la subida de nivel, que no deja confirmar con un cupo nuevo
  /// sin llenar. Vive acá para que la app no la duplique.
  List<({String classId, int cantrips, int prepared})> pendingClassSpells(
    Character c,
    ComputedSheet sheet,
  ) {
    final granted = {
      for (final s in sheet.innateSpells) s.spellId,
      ...sheet.alwaysPreparedSpellIds,
    };
    return [
      for (final block in sheet.spellcastingBlocks)
        if (_pendingFor(c, sheet, block, granted) case final p)
          (classId: block.classId, cantrips: p.cantrips, prepared: p.prepared),
    ];
  }

  ({int cantrips, int prepared}) _pendingFor(
    Character c,
    ComputedSheet sheet,
    SpellcastingBlock block,
    Set<String> granted,
  ) {
    final sc = block.spellcasting;
    final cantripIds = c.cantripIdsFor(block.classId);
    final spellIds = c.spellIdsFor(block.classId);
    final maxSlotLevel =
        sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);
    final free = [
      for (final s in repo.spellsForList(sc.spellList,
          extraSpellIds: sheet.spellListAdditionIds))
        if (!granted.contains(s.id) &&
            !cantripIds.contains(s.id) &&
            !spellIds.contains(s.id))
          s,
    ];
    final freeCantrips = free.where((s) => s.isCantrip).length;
    final freeSpells = free
        .where((s) =>
            !s.isCantrip && (maxSlotLevel == 0 || s.level <= maxSlotLevel))
        .length;
    return (
      cantrips: min(max(0, sc.cantripsKnown - cantripIds.length), freeCantrips),
      prepared: min(max(0, sc.preparedCount - spellIds.length), freeSpells),
    );
  }

  void _validateSpells(
      Character c, ComputedSheet sheet, List<ValidationWarning> w) {
    // Un rasgo que concede un conjuro ya lo da "siempre preparado": volver a
    // elegirlo desde la clase no suma nada y gasta un cupo. Vale tanto para el
    // conjuro innato (que además trae un uso gratis) como para el siempre
    // preparado de una subclase.
    final grantedSpellIds = {
      for (final s in sheet.innateSpells) s.spellId,
      ...sheet.alwaysPreparedSpellIds,
    };

    final blocks = sheet.spellcastingBlocks;
    if (blocks.isEmpty) {
      final hasSpells = c.cantripIds.isNotEmpty ||
          c.spellIds.isNotEmpty ||
          c.classCantripIds.values.any((ids) => ids.isNotEmpty) ||
          c.classSpellIds.values.any((ids) => ids.isNotEmpty);
      if (hasSpells) {
        w.add(ValidationWarning(
          'spells_without_caster',
          localized(
            'Hay conjuros elegidos pero esta clase no lanza conjuros.',
            'Spells are chosen but this class doesn’t cast spells.',
          ),
        ));
      }
      return;
    }

    for (final block in blocks) {
      final sc = block.spellcasting;
      final cantripIds = c.cantripIdsFor(block.classId);
      final spellIds = c.spellIdsFor(block.classId);
      final list = repo
          .spellsForList(sc.spellList,
              extraSpellIds: sheet.spellListAdditionIds)
          .map((s) => s.id)
          .toSet();
      final maxSlotLevel =
          sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);

      if (cantripIds.length > sc.cantripsKnown) {
        w.add(ValidationWarning(
          'too_many_cantrips',
          localized(
            'Elegiste ${cantripIds.length} trucos para ${sc.spellList} pero '
                'conocés ${sc.cantripsKnown}.',
            'You chose ${cantripIds.length} cantrips for ${sc.spellList} but know ${sc.cantripsKnown}.',
          ),
        ));
      }

      final pending = _pendingFor(c, sheet, block, grantedSpellIds);
      if (pending.cantrips > 0) {
        w.add(ValidationWarning(
          'cantrips_pending',
          localized(
            'Trucos de ${sc.spellList}: elegiste ${cantripIds.length} de '
                '${sc.cantripsKnown}.',
            '${sc.spellList} cantrips: you chose ${cantripIds.length} of ${sc.cantripsKnown}.',
          ),
          WarningSeverity.info,
        ));
      }
      if (pending.prepared > 0) {
        w.add(ValidationWarning(
          'prepared_pending',
          localized(
            'Conjuros de ${sc.spellList}: preparaste ${spellIds.length} de '
                '${sc.preparedCount}.',
            '${sc.spellList} spells: you prepared ${spellIds.length} of ${sc.preparedCount}.',
          ),
          WarningSeverity.info,
        ));
      }
      for (final id in cantripIds) {
        final sp = repo.spell(id);
        if (sp == null) {
          w.add(ValidationWarning(
              'spell_missing',
              localized(
                'Truco "$id" no encontrado.',
                'Cantrip "$id" not found.',
              )));
        } else if (!sp.isCantrip) {
          w.add(ValidationWarning(
              'cantrip_not_level_0',
              localized(
                '${sp.name} no es un truco.',
                '${sp.name} isn’t a cantrip.',
              )));
        } else if (!list.contains(id)) {
          w.add(ValidationWarning(
              'cantrip_wrong_list',
              localized(
                '${sp.name} no está en la lista de ${sc.spellList}.',
                '${sp.name} isn’t on the ${sc.spellList} list.',
              )));
        } else if (grantedSpellIds.contains(id)) {
          w.add(ValidationWarning(
              'cantrip_already_granted',
              localized(
                '${sp.name} ya lo tenés por otro rasgo: elegirlo de clase ocupa un cupo de más.',
                'You already have ${sp.name} from another feature: choosing it from your class uses an extra slot.',
              )));
        }
      }

      if (sc.preparation == SpellPreparation.prepared &&
          spellIds.length > sc.preparedCount) {
        w.add(ValidationWarning(
          'too_many_prepared',
          localized(
            'Preparaste ${spellIds.length} conjuros de ${sc.spellList} pero '
                'podés preparar ${sc.preparedCount}.',
            'You prepared ${spellIds.length} ${sc.spellList} spells but can prepare ${sc.preparedCount}.',
          ),
        ));
      }
      for (final id in spellIds) {
        final sp = repo.spell(id);
        if (sp == null) {
          w.add(ValidationWarning(
              'spell_missing',
              localized(
                'Conjuro "$id" no encontrado.',
                'Spell "$id" not found.',
              )));
          continue;
        }
        if (sp.isCantrip) {
          w.add(ValidationWarning(
              'spell_is_cantrip',
              localized(
                '${sp.name} es un truco; va en la lista de trucos.',
                '${sp.name} is a cantrip; it goes on the cantrip list.',
              )));
          continue;
        }
        if (!list.contains(id)) {
          w.add(ValidationWarning(
              'spell_wrong_list',
              localized(
                '${sp.name} no está en la lista de ${sc.spellList}.',
                '${sp.name} isn’t on the ${sc.spellList} list.',
              )));
        }
        if (grantedSpellIds.contains(id)) {
          w.add(ValidationWarning(
              'spell_already_granted',
              localized(
                '${sp.name} ya lo tenés siempre preparado por otro rasgo: prepararlo ocupa un cupo de más.',
                '${sp.name} is always prepared from another feature: preparing it uses an extra slot.',
              )));
        }
        if (maxSlotLevel > 0 && sp.level > maxSlotLevel) {
          w.add(ValidationWarning(
            'spell_level_too_high',
            localized(
              '${sp.name} (nivel ${sp.level}) supera tu mayor espacio '
                  '(nivel $maxSlotLevel).',
              '${sp.name} (level ${sp.level}) exceeds your highest slot (level $maxSlotLevel).',
            ),
            WarningSeverity.info,
          ));
        }
      }
    }
  }

  /// Ids de todas las dotes que el personaje ya tiene: la de origen del
  /// trasfondo, las elegidas (incluida la que concede la especie) y el estilo
  /// de combate. Es lo que hay que mirar para las dotes que exigen otra dote.
  Set<String> heldFeatIds(Character c) => <String?>[
        repo.background(c.backgroundId)?.originFeatId,
        ...c.featIds,
        // Todos los grupos, no solo el estilo de combate: es lo que hace que un
        // prerrequisito entre opciones (una invocación que exige otra) funcione
        // sin que la validación sepa de qué grupo se trata.
        ...c.chosenFeatureOptionIds,
      ].whereType<String>().toSet();

  /// Descripción del primer prerrequisito de [feat] que [c] no cumple, o null
  /// si los cumple todos (o si la dote no exige nada).
  ///
  /// La UI la usa para no ofrecer dotes inelegibles; `validate` la usa para
  /// avisar sobre las que ya están elegidas. Ambas comparten esta única
  /// implementación: las reglas no se duplican en la app.
  ///
  /// [held] permite pasar el set ya calculado cuando se evalúan muchas dotes
  /// seguidas, y también evaluar una dote todavía **no** elegida sin que se
  /// cuente a sí misma.
  String? unmetFeatPrerequisite(Feat feat, Character c, ComputedSheet sheet,
      {Set<String>? held}) {
    final heldIds = held ?? heldFeatIds(c);
    final exclusiveGroup = feat.effectiveExclusiveGroup;
    if (exclusiveGroup != null &&
        heldIds.any((id) =>
            id != feat.id &&
            repo.feat(id)?.effectiveExclusiveGroup == exclusiveGroup)) {
      return localized(
        'no tener otra dote del grupo "$exclusiveGroup"',
        'not having another feat from group "$exclusiveGroup"',
      );
    }
    final prereq = feat.prerequisite;
    if (prereq == null || prereq.isEmpty) return null;
    return _unmetPrerequisite(prereq, c, sheet, heldIds);
  }

  /// Devuelve una descripción del primer prerrequisito incumplido, o null si
  /// se cumplen todos.
  String? _unmetPrerequisite(FeatPrerequisite prereq, Character c,
      ComputedSheet sheet, Set<String> heldFeatIds) {
    for (final entry in prereq.minAbilityScores.entries) {
      if (sheet.abilityScores[entry.key]! < entry.value) {
        return '${entry.key.abbr} ${entry.value}';
      }
    }
    // Basta una: el PHB 2024 escribe "Fuerza o Destreza 13 o más".
    final any = prereq.anyAbilityScores;
    if (any.isNotEmpty &&
        !any.entries.any((e) => sheet.abilityScores[e.key]! >= e.value)) {
      return any.entries
          .map((e) => '${e.key.abbr} ${e.value}')
          .join(localized(' o ', ' or '));
    }
    final reqProf = prereq.requiredProficiency;
    if (reqProf != null) {
      final has = reqProf == 'spellcasting'
          ? sheet.spellcasting != null
          : (sheet.weaponProficiencies.contains(reqProf) ||
              sheet.armorProficiencies.contains(reqProf) ||
              sheet.toolProficiencies.contains(reqProf) ||
              sheet.skillProficiencies.contains(reqProf));
      if (!has) {
        return localized('competencia "$reqProf"', 'proficiency "$reqProf"');
      }
    }
    final reqFeats = prereq.requiredFeatIds;
    if (reqFeats.isNotEmpty && !reqFeats.any(heldFeatIds.contains)) {
      final names = reqFeats.map((id) => repo.feat(id)?.name ?? id);
      return localized(
        'la dote ${names.join(' o ')}',
        'the ${names.join(' or ')} feat',
      );
    }
    final reqCategory = prereq.requiredFeatCategory;
    if (reqCategory != null &&
        !heldFeatIds.any((id) => repo.feat(id)?.category == reqCategory)) {
      return localized(
        'alguna dote de categoría "$reqCategory"',
        'a feat of category "$reqCategory"',
      );
    }
    final reqFeature = prereq.requiredClassFeature;
    if (reqFeature != null) {
      final has = sheet.classLevels.entries.any((entry) {
        final classDefinition = repo.characterClass(entry.key);
        return classDefinition?.features.any(
              (feature) =>
                  feature.level <= entry.value && feature.name == reqFeature,
            ) ??
            false;
      });
      if (!has) {
        return localized(
          'el rasgo de clase "$reqFeature"',
          'the class feature "$reqFeature"',
        );
      }
    }
    final reqClass = prereq.requiredClassId;
    if (reqClass != null && !sheet.classLevels.containsKey(reqClass)) {
      return localized(
        'ser ${repo.characterClass(reqClass)?.name ?? reqClass}',
        'being a ${repo.characterClass(reqClass)?.name ?? reqClass}',
      );
    }
    if (prereq.minLevel != null && c.level < prereq.minLevel!) {
      return localized(
        'nivel ${prereq.minLevel}',
        'level ${prereq.minLevel}',
      );
    }
    return null;
  }
}

/// Una lista vacía con cupo positivo significa "cualquier habilidad" en el
/// contenido 2024 (por ejemplo, el Bardo), no "ninguna habilidad".
Iterable<String> _skillChoiceOptions(int count, List<String> from) =>
    count > 0 && from.isEmpty ? Skill.allIds : from;

/// Competencias elegidas por dote: cantidad, repetidos y que estén entre las
/// opciones. No se mezcla con la elección de especie y clase porque la cuenta
/// esperada sale de las dotes que el personaje tenga en ese momento.
extension _ProficiencyChoiceChecks on CharacterValidator {
  void _validateProficiencyChoices(
    Character c,
    ComputedSheet sheet,
    List<ValidationWarning> w,
  ) {
    final slots = sheet.proficiencyChoiceSlots;
    final chosen = [for (final slot in slots) ...slot.chosen];

    // Los cupos de Pericia entran solo en los chequeos de cantidad, y con los
    // mismos códigos: así la ficha ofrece el mismo botón de resolver sin una
    // rama nueva. Quedan afuera del chequeo de duplicados a propósito, porque
    // una Pericia legal siempre cae sobre una habilidad que ya está en
    // `chosenSkills` —es el requisito— y dispararía siempre. Y afuera del de
    // opciones válidas porque el compilador las construye filtrando por
    // competencia, así que no pueden salirse de la lista.
    for (final slot in [...slots, ...sheet.expertiseChoiceSlots]) {
      if (slot.chosen.length < slot.count) {
        w.add(ValidationWarning(
          'proficiency_choice_count',
          localized(
            slot.name +
                ': elegiste ' +
                slot.chosen.length.toString() +
                ' de ' +
                slot.count.toString() +
                '.',
            '${slot.name}: you chose ${slot.chosen.length} of ${slot.count}.',
          ),
          WarningSeverity.info,
        ));
      } else if (slot.chosen.length > slot.count) {
        w.add(ValidationWarning(
          'too_many_proficiency_choices',
          localized(
            slot.name + ': hay m\u00e1s elecciones que espacios disponibles.',
            '${slot.name}: there are more choices than available slots.',
          ),
        ));
      }
    }
    if (slots.isEmpty && c.chosenProficiencies.isNotEmpty) {
      w.add(ValidationWarning(
        'proficiency_choice_count',
        localized(
          'Hay competencias elegidas pero ning\u00fan rasgo las concede.',
          'Proficiencies are chosen but no feature grants them.',
        ),
      ));
    }

    if (chosen.toSet().length != chosen.length ||
        chosen.any((id) => c.chosenSkills.contains(id))) {
      w.add(ValidationWarning(
        'proficiency_choice_duplicate',
        localized(
          'Hay competencias elegidas m\u00e1s de una vez.',
          'Some proficiencies are chosen more than once.',
        ),
      ));
    }

    // Ya competente por otra vía: la dote se desperdicia, pero no es un error
    // de datos, así que va como informativo.
    final allowed = {for (final s in slots) ...s.options};
    for (final id in chosen) {
      if (!allowed.contains(id)) {
        w.add(ValidationWarning(
          'proficiency_choice_invalid',
          localized(
            'La competencia "$id" no está entre las opciones de tus dotes.',
            'Proficiency "$id" isn’t among your feats’ options.',
          ),
        ));
      }
    }
  }
}
