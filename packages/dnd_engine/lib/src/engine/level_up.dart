import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content.dart';
import '../domain/effects.dart';
import 'character_compiler.dart';
import 'dice.dart';
import 'validation.dart';

/// Las decisiones de una subida de nivel, todavía sin aplicar: lo que el
/// asistente va juntando paso a paso. Es serializable para que el cliente
/// React lo arme sin conocer las reglas y el motor lo resuelva (`LevelUp`).
///
/// Los mapas de elecciones (rasgos, competencias, conjuros) son **reemplazos**:
/// null deja lo que el personaje ya tenía.
class LevelUpDraft {
  /// La clase que sube; distinta de la actual es una multiclase.
  final String classId;
  final String? subclassId;

  /// Lo que salió en el dado de golpe; null es el promedio.
  final int? hpRoll;

  /// Mejora de característica (false) o dote (true), en un nivel de ASI.
  final bool asiFeat;

  /// +2 a una (true) o +1 a dos (false).
  final bool asiPlusTwo;
  final Ability? abilityA;
  final Ability? abilityB;
  final String? featId;

  final List<String>? cantripIds;
  final List<String>? spellIds;
  final Map<String, List<String>>? classCantripIds;
  final Map<String, List<String>>? classSpellIds;
  final Map<String, List<String>>? featureChoices;
  final Map<String, Map<String, List<String>>>? classFeatureChoices;
  final Map<String, List<String>>? proficiencyChoices;
  final Map<String, List<String>>? spellChoices;
  final Map<String, Map<String, List<String>>>? classSpellChoices;

  /// Lo elegido en esta subida para cada cupo de rasgo o de competencia, por
  /// el `groupId` que da la ficha. Es lo que manda el cliente React: el motor
  /// lo mezcla con lo que el personaje ya tenía ([LevelUp.build]), incluido
  /// el ámbito por clase de una multiclase, que el cliente no conoce.
  final Map<String, List<String>> featurePicks;
  final Map<String, List<String>> proficiencyPicks;

  const LevelUpDraft({
    required this.classId,
    this.subclassId,
    this.hpRoll,
    this.asiFeat = false,
    this.asiPlusTwo = true,
    this.abilityA,
    this.abilityB,
    this.featId,
    this.cantripIds,
    this.spellIds,
    this.classCantripIds,
    this.classSpellIds,
    this.featureChoices,
    this.classFeatureChoices,
    this.proficiencyChoices,
    this.spellChoices,
    this.classSpellChoices,
    this.featurePicks = const {},
    this.proficiencyPicks = const {},
  });

  /// Lo que manda el cliente. Las elecciones de conjuros todavía siguen en
  /// Flutter (ver `LevelUp.open`).
  factory LevelUpDraft.fromJson(Map<String, dynamic> j) {
    Ability? ability(Object? name) =>
        name == null ? null : Ability.values.byName(name as String);
    Map<String, List<String>> picks(Object? m) => {
          for (final e in ((m as Map?) ?? const {}).entries)
            e.key as String: [for (final id in e.value as List) id as String],
        };
    return LevelUpDraft(
      classId: j['classId'] as String,
      subclassId: j['subclassId'] as String?,
      hpRoll: (j['hpRoll'] as num?)?.toInt(),
      asiFeat: j['asiFeat'] == true,
      asiPlusTwo: j['asiPlusTwo'] != false,
      abilityA: ability(j['abilityA']),
      abilityB: ability(j['abilityB']),
      featId: j['featId'] as String?,
      featurePicks: picks(j['featurePicks']),
      proficiencyPicks: picks(j['proficiencyPicks']),
    );
  }
}

/// La subida de nivel resuelta: qué pide, qué falta y cómo queda el personaje.
///
/// Antes vivía entera en el widget de Flutter (`LevelUpScreen`); está acá para
/// que Flutter y React apliquen exactamente las mismas reglas. No muta nada:
/// [build] y [confirm] devuelven fichas nuevas.
class LevelUp {
  final Character character;
  final ContentRepository repo;
  final LevelUpDraft draft;

  LevelUp(this.character, this.repo, this.draft);

  CharacterClass? get klass => repo.characterClass(draft.classId);
  int get newLevel => character.totalLevel + 1;
  int get newClassLevel => character.classLevel(draft.classId) + 1;
  int get hitDie => klass?.hitDie ?? 10;
  bool get isAsi => klass?.isAsiLevel(newClassLevel) ?? false;

  bool get needsSubclass =>
      klass != null &&
      character.subclassForClass(draft.classId) == null &&
      newClassLevel >= klass!.subclassLevel;

  List<Subclass> get subclassOptions =>
      needsSubclass ? repo.subclassesForClass(draft.classId) : const [];

  /// Lo que suma el dado de golpe (sin CON: esa la suma el compilador).
  int get hpGain => draft.hpRoll ?? averageHitDie(hitDie);

  /// La dote elegida, si concede "+1 a una característica a tu elección": los
  /// dones épicos y las marcas mayores. Se pregunta por el efecto y no por la
  /// categoría, así que una dote homebrew que lo declare funciona igual.
  AbilityScoreChoiceEffect? get featAbilityChoice {
    if (!isAsi || !draft.asiFeat || draft.featId == null) return null;
    return repo
        .feat(draft.featId!)
        ?.effects
        .whereType<AbilityScoreChoiceEffect>()
        .firstOrNull;
  }

  Map<Ability, int> get abilityIncreases {
    if (!isAsi) return const {};
    final a = draft.abilityA;
    final b = draft.abilityB;
    // Una dote normal no sube nada; un don épico o una marca mayor sí, y ese
    // aumento viaja en el mismo `AsiChoice` que la dote.
    if (draft.asiFeat) {
      final boon = featAbilityChoice;
      if (boon == null || a == null) return const {};
      return {a: boon.amount};
    }
    if (draft.asiPlusTwo) return a == null ? const {} : {a: 2};
    final m = <Ability, int>{};
    if (a != null) m[a] = 1;
    if (b != null) m[b] = (m[b] ?? 0) + 1;
    return m;
  }

  bool get asiComplete {
    if (!isAsi) return true;
    if (draft.asiFeat) {
      if (draft.featId == null) return false;
      // Una dote que sube una característica no está completa sola: falta
      // decir a cuál va su +1.
      return featAbilityChoice == null || draft.abilityA != null;
    }
    if (draft.abilityA == null) return false;
    return draft.asiPlusTwo || draft.abilityB != null;
  }

  /// Si la clase elegida es una multiclase cuyo requisito no se cumple, cuál
  /// es; null si se puede.
  String? get unmetMulticlass {
    final k = klass;
    if (k == null || k.id == character.classId || k.multiclass == null) {
      return null;
    }
    final scores = before.abilityScores;
    return k.multiclass!.meetsAbilityRequirements(scores)
        ? null
        : k.multiclass!.requirementLabel;
  }

  /// Las clases en las que se puede subir, con el requisito que falta (null
  /// si se puede), por nombre.
  List<({CharacterClass klass, String? unmet})> get classOptions => [
        for (final k
            in repo.classes.values.toList()
              ..sort((a, b) => a.name.compareTo(b.name)))
          (
            klass: k,
            unmet: k.id == character.classId ||
                    k.multiclass == null ||
                    k.multiclass!.meetsAbilityRequirements(before.abilityScores)
                ? null
                : k.multiclass!.requirementLabel,
          ),
      ];

  /// El personaje tal como queda al confirmar. [withFeat] en false deja
  /// fuera la dote tentativa: los prerrequisitos de una dote que sube una
  /// característica no pueden habilitarla a ella misma.
  Character build({bool withFeat = true}) {
    final c = character;
    final asiChoices = List<AsiChoice>.of(c.asiChoices);
    final featIds = List<String>.of(c.featIds);
    if (isAsi) {
      if (!draft.asiFeat) {
        asiChoices.add(AsiChoice(
          classId: draft.classId,
          level: newClassLevel,
          abilityIncreases: abilityIncreases,
        ));
      } else if (withFeat && draft.featId != null) {
        asiChoices.add(AsiChoice(
          classId: draft.classId,
          level: newClassLevel,
          featId: draft.featId,
          abilityIncreases: abilityIncreases,
        ));
        featIds.add(draft.featId!);
      }
    }
    final subclassIds = {...c.subclassIds};
    if (draft.subclassId != null) {
      subclassIds[draft.classId] = draft.subclassId!;
    }
    final (featureChoices, classFeatureChoices) = _withFeaturePicks(
      draft.featureChoices ?? c.featureChoices,
      draft.classFeatureChoices ?? c.classFeatureChoices,
    );
    final proficiencyChoices = {
      ...(draft.proficiencyChoices ?? c.proficiencyChoices),
    };
    for (final e in draft.proficiencyPicks.entries) {
      if (e.value.isEmpty) {
        proficiencyChoices.remove(e.key);
      } else {
        proficiencyChoices[e.key] = e.value;
      }
    }
    return c.copyWith(
      level: newLevel,
      classHistory: [...c.classHistory, draft.classId],
      subclassId: draft.classId == c.classId
          ? draft.subclassId ?? c.subclassId
          : c.subclassId,
      subclassIds: subclassIds,
      hpPerLevel: [...c.hpPerLevel, hpGain],
      asiChoices: asiChoices,
      featIds: featIds,
      cantripIds: draft.cantripIds,
      spellIds: draft.spellIds,
      classCantripIds: draft.classCantripIds,
      classSpellIds: draft.classSpellIds,
      featureChoices: featureChoices,
      classFeatureChoices: classFeatureChoices,
      proficiencyChoices: proficiencyChoices,
      spellChoices: draft.spellChoices,
      classSpellChoices: draft.classSpellChoices,
    );
  }

  /// Mezcla [LevelUpDraft.featurePicks] en las elecciones del personaje. Los
  /// grupos legacy de una ficha monoclase también llevan `:` (por ejemplo
  /// `class:wizard:signature-spells`) y no son mapas anidados: solo el
  /// prefijo de la clase que sube es un ámbito persistido (`wizard:class:…`).
  (Map<String, List<String>>, Map<String, Map<String, List<String>>>)
      _withFeaturePicks(Map<String, List<String>> flat,
          Map<String, Map<String, List<String>>> byClass) {
    if (draft.featurePicks.isEmpty) return (flat, byClass);
    final nextFlat = {
      for (final e in flat.entries) e.key: [...e.value]
    };
    final nextByClass = {
      for (final c in byClass.entries)
        c.key: {
          for (final e in c.value.entries) e.key: [...e.value]
        },
    };
    for (final pick in draft.featurePicks.entries) {
      final groupId = pick.key;
      if (groupId.startsWith('${draft.classId}:')) {
        final i = groupId.indexOf(':');
        final scoped = nextByClass[groupId.substring(0, i)] ??= {};
        final raw = groupId.substring(i + 1);
        if (pick.value.isEmpty) {
          scoped.remove(raw);
        } else {
          scoped[raw] = pick.value;
        }
      } else if (pick.value.isEmpty) {
        nextFlat.remove(groupId);
      } else {
        nextFlat[groupId] = pick.value;
      }
    }
    return (nextFlat, nextByClass);
  }

  late final ComputedSheet before = CharacterCompiler(repo).compile(character);
  late final Character built = build();
  late final ComputedSheet after = CharacterCompiler(repo).compile(built);

  /// Rasgos ganados exactamente en el nivel nuevo: los de clase y, si hay
  /// subclase (elegida ahora o antes), los de subclase.
  List<ClassFeature> get gainedFeatures {
    final feats = <ClassFeature>[...?klass?.featuresAt(newClassLevel)];
    final subId = draft.subclassId ?? character.subclassForClass(draft.classId);
    if (subId != null) {
      final sub = repo.subclass(subId);
      if (sub != null && sub.classId == draft.classId) {
        feats.addAll(sub.featuresAt(newClassLevel));
      }
    }
    return feats;
  }

  /// Las dotes que se ofrecen en una mejora de característica: generales y
  /// dones épicos, sin la propia «Mejora de característica» (es la opción
  /// hermana), sin las ya tomadas que no se repiten. Cada una con el
  /// prerrequisito que falta, o null: la pantalla decide si la esconde o la
  /// muestra apagada. Los prerrequisitos se miran al nivel nuevo y sin la
  /// dote tentativa.
  List<({Feat feat, String? unmet})> get featOptions {
    final target = build(withFeat: false);
    final sheet = CharacterCompiler(repo).compile(target);
    final validator = CharacterValidator(repo);
    final held = validator.heldFeatIds(target);
    return [
      for (final f in repo.featsSorted)
        if ((f.category == 'general' || f.category == 'epic-boon') &&
            f.id != 'ability-score-improvement' &&
            (f.repeatable || !held.contains(f.id)))
          (
            feat: f,
            unmet:
                validator.unmetFeatPrerequisite(f, target, sheet, held: held),
          ),
    ];
  }

  /// Lo elegido para [groupId] en [c], con el ámbito por clase.
  static List<String> chosenFeatures(Character c, String groupId) {
    final i = groupId.indexOf(':');
    if (i > 0) {
      return c.classFeatureChoices[groupId.substring(0, i)]
              ?[groupId.substring(i + 1)] ??
          c.featureChoices[groupId] ??
          const [];
    }
    return c.featureChoices[groupId] ?? const [];
  }

  /// Cada cupo de elección de rasgo al nivel nuevo (estilo de combate,
  /// invocaciones…) con lo elegido ahora y antes, y sus opciones con el
  /// prerrequisito que falta (null si se puede). Lo ya elegido nunca se marca
  /// como inelegible: si no, no se podría soltar.
  List<
      ({
        FeatureChoiceSlot slot,
        List<String> chosen,
        List<String> original,
        List<({Feat feat, String? unmet})> options,
      })> get featureSlots {
    final validator = CharacterValidator(repo);
    return [
      for (final slot in after.featureChoiceSlots)
        if (chosenFeatures(built, slot.groupId) case final chosen)
          (
            slot: slot,
            chosen: chosen,
            original: chosenFeatures(character, slot.groupId),
            options: [
              for (final f in repo.featureChoiceOptions(slot))
                (
                  feat: f,
                  unmet: chosen.contains(f.id)
                      ? null
                      : validator.unmetFeatPrerequisite(f, built, after),
                ),
            ],
          ),
    ];
  }

  /// Los cupos de competencia y de Pericia que esta subida pone delante: los
  /// nuevos (un cupo viejo sin resolver lo reclama el aviso de la ficha, que
  /// no traba) y todos los de Pericia. [locked] es lo que no se puede elegir
  /// en ese cupo: lo que ya se tiene por otra vía y lo elegido en otro cupo.
  /// En un cupo de Pericia no se bloquea nada: ser competente es justamente
  /// el requisito, y sus opciones ya vienen filtradas.
  List<({ProficiencyChoiceSlot slot, List<String> chosen, Set<String> locked})>
      get proficiencySlots {
    final old = before.proficiencyChoiceSlots.map((s) => s.groupId).toSet();
    final choices = built.proficiencyChoices;
    final fixed = {...after.skillProficiencies, ...after.toolProficiencies};
    for (final ids in choices.values) {
      fixed.removeAll(ids);
    }
    return [
      for (final slot in [
        for (final s in after.proficiencyChoiceSlots)
          if (!old.contains(s.groupId)) s,
        ...after.expertiseChoiceSlots,
      ])
        (
          slot: slot,
          chosen: choices[slot.groupId] ?? const [],
          locked: slot.expertise
              ? const {}
              : {
                  ...fixed,
                  for (final e in choices.entries)
                    if (e.key != slot.groupId) ...e.value,
                },
        ),
    ];
  }

  /// Lo que esta subida **obliga** a elegir y que [LevelUpDraft.fromJson]
  /// todavía no sabe llevar (rasgos, competencias y conjuros), contado como en
  /// Flutter. Revisar una elección ya hecha es opcional y no cuenta.
  ///
  /// ponytail: Flutter todavía cuenta lo pendiente con sus contadores del
  /// widget, memoizados por firma, porque `LevelUp` recompila dos fichas en
  /// cada acceso y el asistente de Flutter lo pediría en cada build. Si se
  /// memoiza `LevelUp` en la pantalla, Flutter pasa a usar esto.
  ({int features, int proficiencies, int spellChoices, int classSpells})
      get open {
    final c = built;
    int pending(Iterable<(String, int)> slots,
            List<String> Function(String) chosen) =>
        slots.fold(
            0, (n, s) => n + (s.$2 - chosen(s.$1).length).clamp(0, s.$2));
    List<String> scoped(String groupId, Map<String, List<String>> flat,
        Map<String, Map<String, List<String>>> byClass) {
      final i = groupId.indexOf(':');
      if (i > 0) {
        return byClass[groupId.substring(0, i)]?[groupId.substring(i + 1)] ??
            flat[groupId] ??
            const [];
      }
      return flat[groupId] ?? const [];
    }

    final oldProficiency =
        before.proficiencyChoiceSlots.map((s) => s.groupId).toSet();
    final classSpells = CharacterValidator(repo)
        .pendingClassSpells(c, after)
        .where((p) => p.classId == draft.classId)
        .firstOrNull;
    return (
      features: pending(
        [for (final s in after.featureChoiceSlots) (s.groupId, s.count)],
        (g) => scoped(g, c.featureChoices, c.classFeatureChoices),
      ),
      proficiencies: pending([
        for (final s in after.proficiencyChoiceSlots)
          if (!oldProficiency.contains(s.groupId)) (s.groupId, s.count),
        for (final s in after.expertiseChoiceSlots) (s.groupId, s.count),
      ], (g) => c.proficiencyChoices[g] ?? const []),
      spellChoices: pending(
        [for (final s in after.spellChoiceSlots) (s.groupId, s.count)],
        (g) => scoped(g, c.spellChoices, c.classSpellChoices),
      ),
      classSpells: (classSpells?.cantrips ?? 0) + (classSpells?.prepared ?? 0),
    );
  }

  /// Lo que suben los PG máximos con el dado en [die]: el dado más lo que
  /// suma el resto de la ficha por nivel (CON, Dureza Enana…), medido con el
  /// compilador y no copiado de sus reglas.
  int hpIncreaseWith(int die) => after.maxHp - before.maxHp - hpGain + die;

  /// Si se puede confirmar con lo que el borrador sabe llevar: la tirada en
  /// rango, la subclase y la mejora resueltas, la multiclase permitida y nada
  /// pendiente de lo que todavía se elige en Flutter ([open]).
  bool get complete {
    final roll = draft.hpRoll;
    final o = open;
    return klass != null &&
        (roll == null || (roll >= 1 && roll <= hitDie)) &&
        (!needsSubclass || draft.subclassId != null) &&
        asiComplete &&
        unmetMulticlass == null &&
        o.features + o.proficiencies + o.spellChoices + o.classSpells == 0;
  }

  /// El personaje confirmado: [build] con los PG actuales subidos lo mismo
  /// que subió el máximo.
  Character confirm() {
    final updated = built.copyWith(
      combat: CombatState.fromJson(built.combat.toJson()),
    );
    final delta = after.maxHp - before.maxHp;
    updated.combat.currentHp =
        (updated.combat.currentHp + delta).clamp(0, after.maxHp);
    return updated;
  }
}
