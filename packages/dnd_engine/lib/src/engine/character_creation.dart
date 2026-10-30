import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/alignment.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/content.dart';
import '../domain/content_source.dart';
import '../domain/effects.dart';
import '../domain/language.dart';
import '../domain/skill.dart';
import '../domain/spell_slots.dart';
import 'character_compiler.dart';
import 'coin_ops.dart';
import 'dice.dart';
import 'inventory_ops.dart';
import 'validation.dart';

/// Las 18 habilidades de 2024, tomadas del catálogo del motor.
final allSkills2024 = Skill.allIds;

/// Opciones reales de una elección de habilidad: una lista vacía significa
/// "cualquiera de las 18" (p.ej. el Bardo en 2024), no "ninguna". Es el único
/// lugar donde vive esa regla: los pickers y el gating la comparten.
List<String> skillOptions(List<String> from) =>
    from.isEmpty ? allSkills2024 : from;

/// Modo de reparto del aumento de característica del trasfondo 2024.
enum AbilitySpreadMode { twoOne, oneOneOne }

/// Método de puntuación de características.
///
/// Dos de los cuatro no reparten un pool y por eso escriben `assignedScores`
/// directamente: `manual`, donde el usuario escribe cada número para digitalizar
/// un personaje que ya existe en papel, y `pointBuy`, donde cada característica
/// se sube y se baja contra un presupuesto compartido.
enum ScoreMethod { standardArray, roll4d6, pointBuy, manual }

/// Rango aceptado al escribir a mano. Es el rango absoluto de 5e, no el de
/// generación: si el valor sale de 3-18 el motor ya avisa (sin bloquear).
const manualScoreMin = 1;
const manualScoreMax = 30;

/// Las partes del personaje que el creador pide completar. No son los pasos
/// de ningún asistente: Flutter junta conjuros y equipo en un paso y `/v2` los
/// separa, y cada uno arma sus pasos con estas piezas.
enum CreationSection {
  species,
  characterClass,
  background,
  scores,
  proficiencies,
  spells,
  equipment,
}

/// Qué falta. El texto lo pone cada cliente: el motor no habla ningún idioma.
enum CreationPendingKind {
  pickSpecies(CreationSection.species),
  pickLineage(CreationSection.species),
  pickLineageAbility(CreationSection.species),
  pickSize(CreationSection.species),
  pickClass(CreationSection.characterClass),

  /// [CreationPending.name] es el cupo (Estilo de Combate, Invocaciones).
  featureChoice(CreationSection.characterClass),
  weaponMastery(CreationSection.characterClass),
  pickBackground(CreationSection.background),

  /// [CreationPending.name] es la dote de origen.
  pickFeatAbility(CreationSection.background),
  spread(CreationSection.background),
  assignScores(CreationSection.scores),
  classSkills(CreationSection.proficiencies),
  speciesSkills(CreationSection.proficiencies),
  originFeat(CreationSection.proficiencies),

  /// Las cuentas sueltas ([proficiencies], [expertise], [languageChoices],
  /// [spellChoices]) llevan en `need` cuántas faltan y `have` en 0.
  proficiencies(CreationSection.proficiencies),
  expertise(CreationSection.proficiencies),
  languages(CreationSection.proficiencies),
  languageChoices(CreationSection.proficiencies),
  spellChoices(CreationSection.spells),
  cantrips(CreationSection.spells),
  spells(CreationSection.spells),
  classEquipment(CreationSection.equipment),
  backgroundEquipment(CreationSection.equipment),
  equipmentChoices(CreationSection.equipment),

  /// `need` es lo que falta pagar, en cobre.
  overspent(CreationSection.equipment);

  final CreationSection section;
  const CreationPendingKind(this.section);
}

/// Una elección obligatoria sin resolver, con los números que la explican
/// («1 de 2»). Sin texto: el cliente lo arma en su idioma.
class CreationPending {
  final CreationPendingKind kind;
  final int have;
  final int need;
  final String name;

  const CreationPending(
    this.kind, {
    this.have = 0,
    this.need = 0,
    this.name = '',
  });

  CreationSection get section => kind.section;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'section': section.name,
        'have': have,
        'need': need,
        'name': name,
      };
}

/// Las listas con tope que el jugador marca y desmarca. La acción `toggle`
/// del puente JS las nombra así; Flutter las toca con sus selectores.
enum CreationPick {
  classSkill,
  speciesSkill,
  weaponMastery,
  feature,
  proficiency,
  language,
  featureLanguage,
  featureSpell,
  cantrip,
  spell,
}

/// Estado del creador de personajes. Acumula las elecciones y sabe
/// construir un [Character] con todo resuelto. La UI solo lee y escribe esto:
/// lo que una elección arrastra (cambiar de especie suelta el linaje) vive en
/// los métodos `select…`, no en el widget que la ofrece.
class CreationDraft {
  final ContentRepository repo;
  CreationDraft(this.repo);

  factory CreationDraft.fromJson(
    ContentRepository repo,
    Map<String, dynamic> json,
  ) {
    final draft = CreationDraft(repo);
    final classId = json['classId'];
    if (classId is String && repo.characterClass(classId) != null) {
      draft.classId = classId;
    }
    final raceId = json['raceId'];
    if (raceId is String && repo.race(raceId) != null) draft.raceId = raceId;
    final lineageId = json['lineageId'];
    if (lineageId is String) {
      final lineage = repo.lineage(lineageId);
      if (lineage != null && lineage.raceId == draft.raceId) {
        draft.lineageId = lineageId;
      }
    }
    final speciesSpellcastingAbility = _ability(
      json['speciesSpellcastingAbility'],
    );
    if (const {
      Ability.intelligence,
      Ability.wisdom,
      Ability.charisma,
    }.contains(speciesSpellcastingAbility)) {
      draft.speciesSpellcastingAbility = speciesSpellcastingAbility;
    }
    // Se acepta solo si sigue siendo una opción de la especie restaurada: al
    // cambiar de especie el tamaño viejo deja de valer.
    final chosenSize = json['chosenSize'];
    if (chosenSize is String && draft.sizeOptions.contains(chosenSize)) {
      draft.chosenSize = chosenSize;
    }
    final backgroundId = json['backgroundId'];
    if (backgroundId is String && repo.background(backgroundId) != null) {
      draft.backgroundId = backgroundId;
    }
    // Solo si la dote del trasfondo restaurado la sigue ofreciendo.
    final originAbility = _ability(json['originFeatSpellcastingAbility']);
    if (draft.originFeatWithAbilityChoice?.spellcastingAbilityOptions.contains(
          originAbility,
        ) ??
        false) {
      draft.originFeatSpellcastingAbility = originAbility;
    }

    // `fightingStyleId` es el formato viejo del borrador: se lee al grupo que
    // le corresponde para no perder un borrador guardado antes del cambio.
    final legacyStyle = json['fightingStyleId'];
    if (legacyStyle is String && repo.feat(legacyStyle) != null) {
      draft.featureChoices[Character.fightingStyleGroup] = [legacyStyle];
    }
    final rawChoices = json['featureChoices'];
    if (rawChoices is Map) {
      for (final e in rawChoices.entries) {
        if (e.key is! String || e.value is! List) continue;
        final ids = (e.value as List)
            .whereType<String>()
            .where((id) => repo.feat(id) != null)
            .toList();
        if (ids.isNotEmpty) draft.featureChoices[e.key as String] = ids;
      }
    }
    draft.classSkills.addAll(
      _stringList(json['classSkills']).where(allSkills2024.contains),
    );
    draft.raceSkills.addAll(
      _stringList(json['raceSkills']).where(allSkills2024.contains),
    );
    draft.weaponMasteries.addAll(
      _stringList(
        json['weaponMasteries'],
      ).where((id) => repo.weapon(id) != null),
    );
    // Se restauran sin filtrar contra las opciones vigentes: el borrador puede
    // venir de antes de elegir la dote, y el paso las poda cuando se abre.
    draft.chosenProficiencies.addAll(_stringList(json['chosenProficiencies']));
    final rawProficiencyChoices = json['proficiencyChoices'];
    if (rawProficiencyChoices is Map) {
      for (final entry in rawProficiencyChoices.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        draft.proficiencyChoices[entry.key as String] =
            (entry.value as List).whereType<String>().toList();
      }
    }
    draft.languages.addAll(
      _stringList(json['languages']).where((id) => Language.fromId(id) != null),
    );
    final rawLanguageChoices = json['languageChoices'];
    if (rawLanguageChoices is Map) {
      for (final entry in rawLanguageChoices.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        final ids = (entry.value as List)
            .whereType<String>()
            .where((id) => Language.fromId(id) != null)
            .toList();
        if (ids.isNotEmpty) draft.languageChoices[entry.key as String] = ids;
      }
    }
    final rawSpellChoices = json['spellChoices'];
    if (rawSpellChoices is Map) {
      for (final entry in rawSpellChoices.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        // Se filtra contra el catálogo, igual que `cantrips` y `spells`: un
        // borrador viejo puede nombrar un conjuro que ya no existe.
        final ids = (entry.value as List)
            .whereType<String>()
            .where((id) => repo.spell(id) != null)
            .toList();
        if (ids.isNotEmpty) draft.spellChoices[entry.key as String] = ids;
      }
    }
    final raceFeatId = json['raceFeatId'];
    if (raceFeatId is String && repo.feat(raceFeatId) != null) {
      draft.raceFeatId = raceFeatId;
    }
    draft.cantrips.addAll(
      _stringList(json['cantrips']).where((id) => repo.spell(id) != null),
    );
    draft.spells.addAll(
      _stringList(json['spells']).where((id) => repo.spell(id) != null),
    );

    draft.spreadMode = _enumByName(
      AbilitySpreadMode.values,
      json['spreadMode'],
      draft.spreadMode,
    );
    draft.spreadPlusTwo = _ability(json['spreadPlusTwo']);
    draft.spreadPlusOne = _ability(json['spreadPlusOne']);
    draft.scoreMethod = _enumByName(
      ScoreMethod.values,
      json['scoreMethod'],
      draft.scoreMethod,
    );
    final rawPool = json['pool'];
    final pool = rawPool is List
        ? rawPool
            .whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value >= 3 && value <= 18)
            .toList()
        : null;
    if (pool != null && pool.length == 6) draft.pool = pool;

    final rawScores = json['assignedScores'];
    if (rawScores is Map) {
      if (draft.scoreMethod == ScoreMethod.manual) {
        // Sin pool que respetar: solo se acota el rango.
        for (final ability in Ability.values) {
          final value = rawScores[ability.name];
          if (value is num) draft.setManualScore(ability, value.toInt());
        }
      } else if (draft.scoreMethod == ScoreMethod.pointBuy) {
        // Un borrador viejo no es confiable: se acepta solo si las seis están
        // en rango y el reparto entero entra en el presupuesto. Si algo no
        // cierra se vuelve al mínimo, que siempre es válido, en vez de dejar un
        // reparto que la UI no podría haber producido.
        final scores = <Ability, int>{};
        for (final ability in Ability.values) {
          final value = rawScores[ability.name];
          if (value is num && pointBuyCost(value.toInt()) != null) {
            scores[ability] = value.toInt();
          }
        }
        final complete = scores.length == Ability.values.length;
        if (complete && pointBuySpent(scores.values) <= pointBuyBudget) {
          draft.assignedScores.addAll(scores);
        } else {
          for (final ability in Ability.values) {
            draft.assignedScores[ability] = pointBuyMin;
          }
        }
      } else {
        final available = List<int>.of(draft.pool);
        for (final ability in Ability.values) {
          final value = rawScores[ability.name];
          if (value is num && available.remove(value.toInt())) {
            draft.assignedScores[ability] = value.toInt();
          }
        }
      }
    }

    final classEquipmentOptionId = json['classEquipmentOptionId'];
    if (classEquipmentOptionId is String) {
      draft.classEquipmentOptionId = classEquipmentOptionId;
    }
    final backgroundEquipmentOptionId = json['backgroundEquipmentOptionId'];
    if (backgroundEquipmentOptionId is String) {
      draft.backgroundEquipmentOptionId = backgroundEquipmentOptionId;
    }
    final rawEquipmentChoices = json['equipmentChoices'];
    if (rawEquipmentChoices is Map) {
      for (final e in rawEquipmentChoices.entries) {
        if (e.key is String && e.value is String) {
          draft.equipmentChoices[e.key as String] = e.value as String;
        }
      }
    }
    // Sin filtrar contra el catálogo acá: `pruneEquipment` suelta lo que ya no
    // exista, igual que con el resto del equipo.
    final rawPurchases = json['purchases'];
    if (rawPurchases is Map) {
      for (final e in rawPurchases.entries) {
        // `num` y no `int`: el JSON que arma JavaScript no distingue.
        if (e.key is String && e.value is num && (e.value as num) > 0) {
          draft.purchases[e.key as String] = (e.value as num).toInt();
        }
      }
    }
    final armorId = json['equippedArmorId'];
    if (armorId is String && repo.armorPiece(armorId) != null) {
      draft.equippedArmorId = armorId;
    }
    draft.shieldEquipped = json['shieldEquipped'] == true;
    draft.equipmentTouched = json['equipmentTouched'] == true;
    // `weaponId` (una sola arma) es el formato viejo del borrador; se lee para
    // no perder borradores guardados antes de permitir varias armas.
    final legacyWeaponId = json['weaponId'];
    if (legacyWeaponId is String && repo.weapon(legacyWeaponId) != null) {
      draft.weaponIds.add(legacyWeaponId);
    }
    for (final id in _stringList(json['weaponIds'])) {
      if (repo.weapon(id) != null && !draft.weaponIds.contains(id)) {
        draft.weaponIds.add(id);
      }
    }
    // Cómo se empuña cada arma. Solo se leen banderas de armas realmente
    // elegidas: un borrador viejo no las trae y un id suelto no debe colarse.
    for (final entry in [
      (json['weaponOffHand'], draft.weaponOffHand),
      (json['weaponTwoHanded'], draft.weaponTwoHanded),
    ]) {
      final raw = entry.$1;
      if (raw is! Map) continue;
      for (final e in raw.entries) {
        if (e.key is String &&
            e.value is bool &&
            draft.weaponIds.contains(e.key)) {
          entry.$2[e.key as String] = e.value as bool;
        }
      }
    }
    final name = json['name'];
    if (name is String) draft.name = name;
    final alignment = json['alignment'];
    draft.alignment = CharacterAlignment.fromJson(
      alignment is String ? alignment : null,
    );
    final personalityTrait = json['personalityTrait'];
    if (personalityTrait is String) {
      draft.personalityTrait = personalityTrait;
    }
    return draft;
  }

  /// Clase elegida. Arranca vacía, igual que la especie: con un valor por
  /// defecto el paso Clase mostraba al Guerrero marcado sin que nadie lo
  /// eligiera, y se podía avanzar sin haber decidido.
  String? classId;

  /// Elecciones abiertas resueltas: id de grupo → ids de opción.
  final Map<String, List<String>> featureChoices = {};
  final Set<String> classSkills = {};
  final List<String> weaponMasteries = [];

  /// Competencias elegidas por dote (Habilidoso, Mente Aguda). Van mezcladas
  /// habilidades y herramientas, igual que en `Character`.
  final List<String> chosenProficiencies = [];
  final Map<String, List<String>> proficiencyChoices = {};

  /// Conjuros elegidos por un rasgo o una dote que los deja siempre
  /// preparados (Iniciado en la Magia).
  final Map<String, List<String>> spellChoices = {};

  /// Idiomas elegidos en el origen: dos de la tabla de estándar. Común no va
  /// acá, lo sabe todo personaje.
  final List<String> languages = [];

  /// Idiomas elegidos por un rasgo que los deja a elección (Jerga de Ladrones).
  final Map<String, List<String>> languageChoices = {};

  // Orígenes.
  String? raceId;
  String? lineageId;
  Ability? speciesSpellcastingAbility;

  /// Tamaño elegido, para las especies que lo ofrecen. Null = sin elegir.
  String? chosenSize;

  final Set<String> raceSkills = {};
  String? raceFeatId; // dote de origen de la especie (p.ej. Humano "Versátil")
  String? backgroundId;

  /// Aptitud mágica elegida para la dote de origen del trasfondo. El
  /// asistente no la pedía y el Acólito nacía con la advertencia de aptitud
  /// pendiente; la ficha ya sabía guardarla (`featSpellcastingAbilities`).
  Ability? originFeatSpellcastingAbility;

  // Conjuros elegidos (para clases lanzadoras).
  final Set<String> cantrips = {};
  final Set<String> spells = {};

  // Reparto de característica del trasfondo.
  AbilitySpreadMode spreadMode = AbilitySpreadMode.twoOne;
  Ability? spreadPlusTwo; // en modo +2/+1
  Ability? spreadPlusOne;

  // Puntuaciones.
  ScoreMethod scoreMethod = ScoreMethod.standardArray;
  List<int> pool = List.of(standardArray);
  final Map<Ability, int> assignedScores = {};

  // Equipo.
  String? classEquipmentOptionId;
  String? backgroundEquipmentOptionId;
  final Map<String, String> equipmentChoices = {};
  String? equippedArmorId;
  bool shieldEquipped = false;

  /// Armas equipadas, en orden. Varias son legítimas (por ejemplo un pícaro con
  /// dos dagas): el motor genera un ataque por cada una.
  final List<String> weaponIds = [];

  /// Cómo se empuña cada arma elegida. Cambian el ataque que produce el motor,
  /// así que viajan con el borrador como cualquier otra elección.
  final Map<String, bool> weaponOffHand = {};
  final Map<String, bool> weaponTwoHanded = {};

  /// Si el jugador ya tocó a mano qué lleva puesto. Mientras sea false, lo
  /// puesto sigue al paquete elegido (ver [pruneEquipment]); a partir del
  /// primer toque manda lo que eligió.
  bool equipmentTouched = false;

  String name = '';

  // Detalles de sabor.
  CharacterAlignment? alignment;
  String personalityTrait = '';

  Map<String, dynamic> toJson() => {
        'classId': classId,
        'featureChoices': featureChoices,
        'classSkills': classSkills.toList(),
        'weaponMasteries': weaponMasteries,
        'chosenProficiencies': chosenProficiencies,
        'proficiencyChoices': proficiencyChoices,
        'spellChoices': spellChoices,
        'languages': languages,
        'languageChoices': languageChoices,
        'raceId': raceId,
        'lineageId': lineageId,
        'speciesSpellcastingAbility': speciesSpellcastingAbility?.name,
        'chosenSize': chosenSize,
        'raceSkills': raceSkills.toList(),
        'raceFeatId': raceFeatId,
        'backgroundId': backgroundId,
        'originFeatSpellcastingAbility': originFeatSpellcastingAbility?.name,
        'cantrips': cantrips.toList(),
        'spells': spells.toList(),
        'spreadMode': spreadMode.name,
        'spreadPlusTwo': spreadPlusTwo?.name,
        'spreadPlusOne': spreadPlusOne?.name,
        'scoreMethod': scoreMethod.name,
        'pool': pool,
        'assignedScores': {
          for (final entry in assignedScores.entries)
            entry.key.name: entry.value,
        },
        'equippedArmorId': equippedArmorId,
        'classEquipmentOptionId': classEquipmentOptionId,
        'backgroundEquipmentOptionId': backgroundEquipmentOptionId,
        'equipmentChoices': equipmentChoices,
        'purchases': purchases,
        'shieldEquipped': shieldEquipped,
        'weaponIds': weaponIds,
        'weaponOffHand': weaponOffHand,
        'weaponTwoHanded': weaponTwoHanded,
        'equipmentTouched': equipmentTouched,
        'name': name,
        'alignment': alignment?.toJson(),
        'personalityTrait': personalityTrait,
      };

  CharacterClass? get klass =>
      classId == null ? null : repo.characterClass(classId!);
  Race? get race => raceId == null ? null : repo.race(raceId!);
  List<Lineage> get lineageOptions =>
      raceId == null ? const [] : repo.lineagesForRace(raceId!);
  Lineage? get lineage {
    final value = lineageId == null ? null : repo.lineage(lineageId!);
    return value?.raceId == raceId ? value : null;
  }

  /// Tamaños que ofrece la especie elegida. Vacío = no hay nada que elegir.
  List<String> get sizeOptions => race?.sizeOptions ?? const [];

  bool get lineageUsesSpellcastingAbility =>
      lineage?.features.any(
        (feature) =>
            feature.effects.any((effect) => effect is GrantSpellEffect),
      ) ??
      false;

  Background? get background =>
      backgroundId == null ? null : repo.background(backgroundId!);

  /// La dote de origen del trasfondo, si deja elegir su aptitud mágica
  /// (Iniciado en la Magia). Null si no hay trasfondo o si su dote no lo pide.
  Feat? get originFeatWithAbilityChoice {
    final feat = repo.feat(background?.originFeatId ?? '');
    return (feat?.spellcastingAbilityOptions.isNotEmpty ?? false) ? feat : null;
  }

  // --------------------------------------------------------------------------
  // Elecciones con arrastre. Lo que cada una suelta estaba en el `onTap` del
  // widget que la ofrecía; acá lo comparten Flutter y `/v2`.
  // --------------------------------------------------------------------------

  /// Otra especie suelta todo lo que dependía de la anterior: linaje, su
  /// aptitud mágica, tamaño, habilidades de especie y la dote del Humano.
  void selectRace(String id) {
    if (raceId == id) return;
    raceId = id;
    lineageId = null;
    speciesSpellcastingAbility = null;
    chosenSize = null;
    raceSkills.clear();
    raceFeatId = null;
  }

  /// Otro linaje puede no lanzar conjuros, o no con la misma lista.
  void selectLineage(String id) {
    lineageId = id;
    speciesSpellcastingAbility = null;
  }

  /// Otra clase invalida sus habilidades, maestrías, rasgos y conjuros.
  void selectClass(String id) {
    classId = id;
    classSkills.clear();
    weaponMasteries.clear();
    featureChoices.clear();
    cantrips.clear();
    spells.clear();
  }

  void selectBackground(String id) {
    if (backgroundId != id) {
      // Otra dote puede no ofrecerla, o no las mismas opciones.
      originFeatSpellcastingAbility = null;
    }
    backgroundId = id;
    spreadPlusTwo = null;
    spreadPlusOne = null;
    // El trasfondo nuevo puede conceder justo la dote de origen que ya estaba
    // elegida para la especie. El paso de aptitudes deja de ofrecerla, pero
    // volver atrás a cambiar el trasfondo dejaría la elección vieja en pie y
    // duplicada.
    final granted = repo.background(id)?.originFeatId;
    final chosen = raceFeatId;
    if (chosen != null &&
        chosen == granted &&
        !(repo.feat(chosen)?.repeatable ?? false)) {
      raceFeatId = null;
    }
  }

  /// Tocar la dote elegida la suelta; tocar otra la reemplaza.
  void toggleRaceFeat(String id) => raceFeatId = raceFeatId == id ? null : id;

  /// Ponerse o sacarse armadura o escudo. Desde el primer toque manda lo que
  /// eligió el jugador y no el paquete (ver [equipmentTouched]).
  void setArmorWorn(String id, bool on) {
    equipmentTouched = true;
    if (repo.armorPiece(id)?.isShield ?? false) {
      shieldEquipped = on;
      // Con escudo no hay mano libre: una versátil marcada a dos manos
      // seguiría calculándose con el dado mayor.
      if (on) weaponTwoHanded.clear();
    } else {
      equippedArmorId = on ? id : null;
    }
  }

  void setWeaponWielded(String id, bool on) {
    equipmentTouched = true;
    weaponIds.remove(id);
    if (on) weaponIds.add(id);
  }

  /// Solo se empuña un arma en la secundaria.
  void setOffHand(String id, bool on) {
    weaponOffHand.clear();
    if (on) weaponOffHand[id] = true;
  }

  /// Marca o desmarca [id] en una lista con tope. Con un solo lugar, tocar
  /// otra la cambia; con el cupo lleno, una nueva no entra. Es la misma regla
  /// que los selectores de Flutter (`CappedChipSelect`).
  void toggle(CreationPick pick, String id, {String? group}) {
    final max = _capOf(pick, group);
    final current = _picked(pick, group);
    final next = List.of(current);
    if (!next.remove(id)) {
      if (max == 1) {
        next
          ..clear()
          ..add(id);
      } else if (next.length < max) {
        next.add(id);
      }
    }
    _setPicked(pick, group, next);
  }

  int _capOf(CreationPick pick, String? group) => switch (pick) {
        CreationPick.classSkill => klass?.skillChoiceCount ?? 0,
        CreationPick.speciesSkill => race?.skillChoiceCount ?? 0,
        CreationPick.weaponMastery => weaponMasterySlots,
        CreationPick.feature => featureChoiceSlots
                .where((s) => s.groupId == group)
                .firstOrNull
                ?.count ??
            0,
        CreationPick.proficiency => allProficiencyChoiceSlots
                .where((s) => s.groupId == group)
                .firstOrNull
                ?.count ??
            0,
        CreationPick.language => Language.originChoiceCount,
        CreationPick.featureLanguage => languageChoiceSlots
                .where((s) => s.groupId == group)
                .firstOrNull
                ?.count ??
            0,
        CreationPick.featureSpell => spellChoiceSlots
                .where((s) => s.groupId == group)
                .firstOrNull
                ?.count ??
            0,
        CreationPick.cantrip => spellcasting?.cantripsKnown ?? 0,
        CreationPick.spell => switch (spellcasting) {
            null => 0,
            final sc when sc.preparation == SpellPreparation.prepared =>
              sc.preparedCount,
            // Un lanzador que conoce en vez de preparar no tiene cupo de
            // preparados: el tope lo da su lista.
            _ => 999,
          },
      };

  List<String> _picked(CreationPick pick, String? group) => switch (pick) {
        CreationPick.classSkill => classSkills.toList(),
        CreationPick.speciesSkill => raceSkills.toList(),
        CreationPick.weaponMastery => weaponMasteries,
        CreationPick.feature => featureChoices[group] ?? const [],
        CreationPick.proficiency => proficiencyChoices[group] ?? const [],
        CreationPick.language => languages,
        CreationPick.featureLanguage => languageChoices[group] ?? const [],
        CreationPick.featureSpell => spellChoices[group] ?? const [],
        CreationPick.cantrip => cantrips.toList(),
        CreationPick.spell => spells.toList(),
      };

  void _setPicked(CreationPick pick, String? group, List<String> ids) {
    void inGroup(Map<String, List<String>> map) {
      if (group == null) return;
      if (ids.isEmpty) {
        map.remove(group);
      } else {
        map[group] = ids;
      }
    }

    switch (pick) {
      case CreationPick.classSkill:
        classSkills
          ..clear()
          ..addAll(ids);
      case CreationPick.speciesSkill:
        raceSkills
          ..clear()
          ..addAll(ids);
      case CreationPick.weaponMastery:
        weaponMasteries
          ..clear()
          ..addAll(ids);
      case CreationPick.feature:
        inGroup(featureChoices);
      case CreationPick.proficiency:
        // El cupo existe aunque esté vacío: la poda lo vuelve a crear igual.
        if (group != null) proficiencyChoices[group] = ids;
      case CreationPick.language:
        languages
          ..clear()
          ..addAll(ids);
      case CreationPick.featureLanguage:
        inGroup(languageChoices);
      case CreationPick.featureSpell:
        inGroup(spellChoices);
      case CreationPick.cantrip:
        cantrips
          ..clear()
          ..addAll(ids);
      case CreationPick.spell:
        spells
          ..clear()
          ..addAll(ids);
    }
  }

  /// Corre todas las podas: lo que una elección anterior dejó sin sentido se
  /// suelta. Flutter las corre al abrir cada paso; `/v2`, tras cada acción.
  void pruneAll() {
    pruneProficiencyChoices();
    pruneSpellChoices();
    pruneLanguages();
    pruneEquipment();
  }

  /// Aplica una acción del puente JS (`creation` en `js/entrypoint.dart`) y
  /// después todas las podas. [dice] fija la tirada de 4d6 en la prueba de
  /// paridad. Una acción desconocida o mal formada no cambia nada.
  void apply(Map<String, dynamic> action, {Dice? dice}) {
    String? str(String key) {
      final v = action[key];
      return v is String ? v : null;
    }

    final id = str('id') ?? '';
    final on = action['on'] == true;
    final ability = _ability(action['ability']);
    switch (str('type')) {
      case 'selectRace':
        selectRace(id);
      case 'selectLineage':
        selectLineage(id);
      case 'setSpeciesAbility':
        speciesSpellcastingAbility = ability;
      case 'setSize':
        chosenSize = id;
      case 'selectClass':
        selectClass(id);
      case 'selectBackground':
        selectBackground(id);
      case 'setOriginFeatAbility':
        originFeatSpellcastingAbility = ability;
      case 'setSpreadMode':
        spreadMode =
            _enumByName(AbilitySpreadMode.values, action['mode'], spreadMode);
      case 'setSpread':
        spreadPlusTwo = _ability(action['plusTwo']);
        spreadPlusOne = _ability(action['plusOne']);
      case 'applyScoreMethod':
        applyScoreMethod(
          _enumByName(ScoreMethod.values, action['method'], scoreMethod),
          dice: dice,
        );
      case 'applySuggestedScores':
        applySuggestedScores();
      case 'clearScores':
        clearScores();
      case 'assignScore':
        final v = action['value'];
        if (ability != null && v is num) assignScore(ability, v.toInt());
      case 'stepPointBuy':
        final d = action['delta'];
        if (ability != null && d is num) stepPointBuy(ability, d.toInt());
      case 'setManualScore':
        final v = action['value'];
        if (ability != null)
          setManualScore(ability, v is num ? v.toInt() : null);
      case 'toggle':
        final pick = _enumByName<CreationPick?>(
          CreationPick.values,
          action['pick'],
          null,
        );
        if (pick != null) toggle(pick, id, group: str('group'));
      case 'toggleRaceFeat':
        toggleRaceFeat(id);
      case 'setClassEquipment':
        classEquipmentOptionId = id;
      case 'setBackgroundEquipment':
        backgroundEquipmentOptionId = id;
      case 'setEquipmentChoice':
        final key = str('key');
        if (key != null) equipmentChoices[key] = id;
      case 'buy':
        buy(id);
      case 'setPurchase':
        final q = action['quantity'];
        if (q is num) setPurchase(id, q.toInt());
      case 'setArmorWorn':
        setArmorWorn(id, on);
      case 'setWeaponWielded':
        setWeaponWielded(id, on);
      case 'setOffHand':
        setOffHand(id, on);
      case 'setTwoHanded':
        weaponTwoHanded[id] = on;
      case 'setName':
        name = str('name') ?? '';
      case 'setAlignment':
        alignment = CharacterAlignment.fromJson(str('alignment'));
      case 'setTrait':
        personalityTrait = str('text') ?? '';
    }
    pruneAll();
  }

  // --------------------------------------------------------------------------
  // Equipo.
  // --------------------------------------------------------------------------

  StartingEquipmentOption? get classEquipmentOption =>
      _option(klass?.startingEquipment ?? const [], classEquipmentOptionId);

  StartingEquipmentOption? get backgroundEquipmentOption => _option(
        background?.startingEquipment ?? const [],
        backgroundEquipmentOptionId,
      );

  StartingEquipmentOption? _option(
    List<StartingEquipmentOption> options,
    String? id,
  ) =>
      options.where((e) => e.id == id).firstOrNull;

  List<({String key, EquipmentGrant grant})> get selectedEquipmentGrants => [
        if (classEquipmentOption case final option?)
          for (final (index, grant) in option.grants.indexed)
            (key: 'class:${option.id}:$index', grant: grant),
        if (backgroundEquipmentOption case final option?)
          for (final (index, grant) in option.grants.indexed)
            (key: 'background:${option.id}:$index', grant: grant),
      ];

  /// Lo que traen las opciones de equipo elegidas, sin las compras.
  Map<String, int> get _grantedQuantities {
    final quantities = <String, int>{};
    for (final (:key, :grant) in selectedEquipmentGrants) {
      final itemId = grant.itemId ?? equipmentChoices[key];
      if (itemId != null) {
        quantities[itemId] = (quantities[itemId] ?? 0) + grant.quantity;
      }
    }
    return quantities;
  }

  /// El resumen de lo que traen las opciones: objetos y cantidad.
  List<({String itemId, int quantity})> get grantedItems => [
        for (final e in _grantedQuantities.entries)
          (itemId: e.key, quantity: e.value),
      ];

  /// Compras del paso Equipo: objeto → cantidad, en el orden en que se
  /// agregaron. Se pagan con el oro de las opciones al construir el
  /// personaje; hasta entonces son una lista que se puede rehacer.
  final Map<String, int> purchases = {};

  /// Suma uno de [itemId] a las compras.
  void buy(String itemId) => purchases[itemId] = (purchases[itemId] ?? 0) + 1;

  /// Fija la cantidad comprada; 0 la saca de la lista.
  void setPurchase(String itemId, int quantity) {
    if (quantity <= 0) {
      purchases.remove(itemId);
    } else {
      purchases[itemId] = quantity;
    }
  }

  /// Lo que cuestan las compras, al precio del manual.
  ///
  /// Sin precio editable, a diferencia de la ficha: acá todavía no hay DM con
  /// quien regatear, y el oro de partida del manual supone la tabla.
  int get purchasesCp => purchases.entries.fold(
        0,
        (sum, e) => sum + InventoryOps.catalogPriceCp(e.key, repo) * e.value,
      );

  /// Oro de las opciones menos las compras, en cobre. Negativo si cambiar de
  /// opción dejó compras que ya no se pagan: el paso no se cierra hasta
  /// ajustarlas, en vez de borrarlas sin avisar.
  int get goldLeftCp => CoinOps.totalCp(grantedCoins) - purchasesCp;

  List<InventoryEntry> get startingInventory {
    final quantities = _grantedQuantities;
    for (final e in purchases.entries) {
      quantities[e.key] = (quantities[e.key] ?? 0) + e.value;
    }
    final equipped = {
      if (equippedArmorId != null) equippedArmorId,
      if (shieldEquipped) 'shield',
      ...weaponIds,
    };
    return [
      for (final (index, entry) in quantities.entries.indexed)
        InventoryEntry(
          entryId: 'starting-$index-${entry.key}',
          itemId: entry.key,
          quantity: entry.value,
          equipped: equipped.contains(entry.key),
        ),
    ];
  }

  /// Las monedas que traen las opciones de equipo, antes de comprar.
  Map<String, int> get grantedCoins {
    final out = <String, int>{};
    for (final selected in selectedEquipmentGrants) {
      final grant = selected.grant;
      for (final entry in grant.coins.entries) {
        out[entry.key] = (out[entry.key] ?? 0) + entry.value;
      }
    }
    return out;
  }

  /// La bolsa con la que nace el personaje: lo de las opciones, pagadas las
  /// compras con la misma cuenta que la ficha. Si no alcanza, las monedas
  /// quedan enteras; [goldLeftCp] negativo ya impide terminar el paso.
  Map<String, int> get startingCoins =>
      CoinOps.pay(grantedCoins, purchasesCp) ?? grantedCoins;

  Set<String> get receivedItemIds =>
      startingInventory.map((e) => e.itemId).toSet();

  void pruneEquipment() {
    // Un objeto que ya no está en el catálogo (homebrew que se borró) no se
    // puede ni pagar ni mostrar.
    purchases.removeWhere(
      (id, quantity) => quantity <= 0 || repo.catalogEntry(id) == null,
    );
    equipmentChoices.removeWhere((key, value) {
      final grant = selectedEquipmentGrants
          .where((e) => e.key == key)
          .map((e) => e.grant)
          .firstOrNull;
      return grant == null || !grant.chooseFromItemIds.contains(value);
    });
    final received = receivedItemIds;
    if (!equipmentTouched) {
      _equipReceived(received);
      return;
    }
    if (!received.contains(equippedArmorId)) equippedArmorId = null;
    shieldEquipped = shieldEquipped && received.contains('shield');
    weaponIds.removeWhere((id) => !received.contains(id));
  }

  /// Pone lo recibido con lo que el personaje es competente. Las pastillas de
  /// «Equipo puesto» arrancaban apagadas y el Brujo nacía sin armadura ni arma
  /// aunque el paso las listara: CA 12 en vez de 13 y el aviso de «No hay arma
  /// equipada» en una ficha recién hecha.
  ///
  /// Lo que no se sabe usar no se pone: una armadura sin competencia da
  /// desventaja y corta el lanzamiento de conjuros, y el jugador no lo pidió.
  /// La competencia sale de la ficha compilada, no de una regla copiada acá.
  void _equipReceived(Set<String> received) {
    final sheet = previewSheet;
    final armors = [
      for (final id in received)
        if (repo.armorPiece(id) case final a?
            when sheet.armorProficiencies.contains(a.category))
          a,
    ];
    final body = armors.where((a) => !a.isShield).toList()
      ..sort((a, b) => b.baseAc.compareTo(a.baseAc));
    equippedArmorId = body.firstOrNull?.id;
    shieldEquipped = armors.any((a) => a.isShield);
    // Solo lo que cabe en dos manos, en el orden del paquete: el Guerrero
    // nacía empuñando mandoble, mangual, jabalinas y hachas a la vez. El
    // escudo ocupa una; el resto se recibe y queda en la mochila.
    var hands = shieldEquipped ? 1 : 2;
    weaponIds.clear();
    for (final id in received) {
      if (repo.weapon(id) case final w?
          when w.isProficientWith(sheet.weaponProficiencies)) {
        final need = w.requiresTwoHands() ? 2 : 1;
        if (need > hands) continue;
        weaponIds.add(id);
        hands -= need;
      }
    }
  }

  /// Armas con las que la clase elegida es competente. La Maestría de Armas
  /// 2024 solo puede aplicarse a estas.
  List<Weapon> get proficientWeapons {
    final k = klass;
    if (k == null) return const [];
    return repo.weaponsSorted
        .where((w) => w.isProficientWith(k.weaponProficiencies))
        .toList();
  }

  /// Si la clase elegida lanza conjuros (tiene un SpellcastingEffect a nivel 1).
  bool get isCaster =>
      klass
          ?.featuresUpTo(1)
          .any((f) => f.effects.any((e) => e is SpellcastingEffect)) ??
      false;

  ComputedSheet? _sheetCache;
  String? _sheetSig;

  /// Ficha compilada de previsualización, memoizada según lo que la afecta.
  ///
  /// Es la única fuente de lo derivado que necesita el creador: cupos de
  /// conjuros, espacios de maestría y elecciones abiertas salen de acá, no de
  /// recorrer los rasgos de la clase a mano.
  ComputedSheet get previewSheet {
    final sig = [
      classId,
      raceId,
      lineageId,
      speciesSpellcastingAbility?.name,
      chosenSize,
      backgroundId,
      originFeatSpellcastingAbility?.name,
      raceFeatId,
      spreadMode.name,
      spreadPlusTwo?.name,
      spreadPlusOne?.name,
      for (final e in featureChoices.entries) '${e.key}:${e.value.join(",")}',
      for (final e in proficiencyChoices.entries)
        '${e.key}:${e.value.join(",")}',
      for (final e in spellChoices.entries) '${e.key}:${e.value.join(",")}',
      languages.join(','),
      for (final e in languageChoices.entries) '${e.key}:${e.value.join(",")}',
      // Las habilidades elegidas viajan en `build()`, así que también son parte
      // de lo derivado: sin ellas acá la ficha compilada quedaba una elección
      // atrás y las competencias de una dote no veían lo recién tomado.
      (classSkills.toList()..sort()).join(','),
      (raceSkills.toList()..sort()).join(','),
      for (final a in Ability.values) assignedScores[a] ?? 10,
      // El catálogo puede cambiar por dentro (otro idioma) y la ficha trae
      // sus nombres.
      repo.revision,
    ].join('|');
    if (sig != _sheetSig) {
      _sheetCache = CharacterCompiler(repo).compile(build());
      _sheetSig = sig;
    }
    return _sheetCache!;
  }

  /// Espacios de Maestría de Armas que otorga la clase a nivel 1 (Guerrero 3,
  /// Bárbaro/Pícaro 2, Monje 0…).
  int get weaponMasterySlots => previewSheet.weaponMasterySlots;

  /// Elecciones abiertas a resolver a nivel 1 (Estilo de Combate del Guerrero,
  /// Invocaciones del Brujo). Las declara el contenido, así que sumar una clase
  /// o un catálogo nuevo no toca este archivo.
  List<FeatureChoiceSlot> get featureChoiceSlots =>
      previewSheet.featureChoiceSlots;

  /// Lo que se puede elegir en [slot]: las opciones cuyo prerrequisito se
  /// cumple, más las ya elegidas (soltarlas tiene que seguir siendo posible).
  List<Feat> featureChoiceOptions(FeatureChoiceSlot slot) {
    final chosen = featureChoices[slot.groupId] ?? const <String>[];
    final base = build();
    final validator = CharacterValidator(repo);
    return repo
        .featureChoiceOptions(slot)
        .where(
          (f) =>
              chosen.contains(f.id) ||
              validator.unmetFeatPrerequisite(f, base, previewSheet) == null,
        )
        .toList();
  }

  /// Dotes de origen que el personaje puede tomar por su especie (el Humano).
  /// Ninguna de las oficiales tiene prerrequisitos, pero una homebrew sí puede
  /// tenerlos.
  ///
  /// La dote tentativa se deja fuera del personaje evaluado: una dote que sube
  /// una característica no debe poder cumplir su propio prerrequisito.
  ///
  /// Tampoco se ofrece la dote de origen que ya concede el trasfondo: el
  /// personaje la tendría por dos vías y el PHB solo permite repetir las dotes
  /// que lo declaran. Sin este filtro, un Humano con trasfondo de Soldado podía
  /// elegir Atacante Salvaje y quedar con la dote duplicada.
  List<Feat> get originFeatOptions {
    if (!(race?.effects.any((e) => e is GrantFeatEffect) ?? false)) {
      return const [];
    }
    final base = build().copyWith(featIds: const []);
    final sheet = CharacterCompiler(repo).compile(base);
    final validator = CharacterValidator(repo);
    final grantedByBackground = background?.originFeatId;
    return repo.featsSorted
        .where((f) => f.category == 'origin')
        .where((f) => f.repeatable || f.id != grantedByBackground)
        .where((f) => validator.unmetFeatPrerequisite(f, base, sheet) == null)
        .toList();
  }

  /// Competencias a elegir por dote (Habilidoso, Mente Aguda). Cambian con la
  /// dote de origen elegida y con la que concede el trasfondo, así que se
  /// preguntan a la ficha en cada build en vez de guardarse.
  List<ProficiencyChoiceSlot> get proficiencyChoiceSlots =>
      previewSheet.proficiencyChoiceSlots;

  /// Cupos de Pericia (Pícaro y Bardo ya a nivel bajo). Viven en una lista
  /// aparte en la ficha, así que hay que pedirlos aparte.
  List<ProficiencyChoiceSlot> get expertiseChoiceSlots =>
      previewSheet.expertiseChoiceSlots;

  /// Todos los cupos de elección de competencia, Pericia incluida. Es lo que
  /// tienen que recorrer el podado y el conteo de pendientes: si la Pericia
  /// queda afuera, sus elecciones se borran.
  List<ProficiencyChoiceSlot> get allProficiencyChoiceSlots => [
        ...proficiencyChoiceSlots,
        ...expertiseChoiceSlots,
      ];

  /// Saca de la selección lo que dejó de ser elegible: cambiar de dote o de
  /// trasfondo puede invalidar una elección ya hecha, y dejarla puesta daría
  /// una competencia que ninguna dote concede.
  ///
  /// Recorre **las dos** listas de cupos. Si se recorriera solo la de
  /// competencias, el `removeWhere` de abajo borraría las Pericias elegidas por
  /// no encontrar su groupId entre los activos.
  void pruneProficiencyChoices() {
    final slots = allProficiencyChoiceSlots;
    final active = {for (final slot in slots) slot.groupId};
    proficiencyChoices.removeWhere((groupId, _) => !active.contains(groupId));
    for (final slot in slots) {
      final source = proficiencyChoices[slot.groupId] ?? slot.chosen;
      final chosen = <String>[];
      for (final id in source) {
        if (slot.options.contains(id) && !chosen.contains(id)) chosen.add(id);
        if (chosen.length == slot.count) break;
      }
      proficiencyChoices[slot.groupId] = chosen;
      chosenProficiencies.removeWhere(chosen.contains);
    }
  }

  /// Cupos de conjuros a elección que quedan siempre preparados (Iniciado en
  /// la Magia, y los que declare un rasgo homebrew).
  List<SpellChoiceSlot> get spellChoiceSlots => previewSheet.spellChoiceSlots;

  int get pendingSpellChoices =>
      spellChoiceSlots.fold<int>(0, (n, slot) => n + slot.pending);

  /// Saca de la selección lo que dejó de calificar, igual que
  /// [pruneProficiencyChoices]: cambiar de clase o de trasfondo puede vaciar un
  /// cupo, y dejar la elección puesta daría conjuros que ningún rasgo concede.
  void pruneSpellChoices() {
    final slots = spellChoiceSlots;
    final active = {for (final slot in slots) slot.groupId};
    spellChoices.removeWhere((groupId, _) => !active.contains(groupId));
    for (final slot in slots) {
      // `slot.chosen` ya viene revalidado por el motor contra el pozo actual.
      if (slot.chosen.isEmpty) {
        spellChoices.remove(slot.groupId);
      } else {
        spellChoices[slot.groupId] = List.of(slot.chosen);
      }
    }
  }

  /// Cuántos idiomas del origen faltan elegir. El cupo lo fija el motor.
  int get pendingLanguages =>
      (Language.originChoiceCount - languages.length).clamp(0, 99);

  /// Cupos de idioma que declara un rasgo (Jerga de Ladrones del Pícaro).
  List<LanguageChoiceSlot> get languageChoiceSlots =>
      previewSheet.languageChoiceSlots;

  int get pendingLanguageChoices =>
      languageChoiceSlots.fold<int>(0, (n, slot) => n + slot.pending);

  /// Suelta lo que dejó de ser elegible: cambiar de clase puede vaciar un cupo
  /// de rasgo, y un idioma del origen que además concede la clase pasaría a
  /// estar dos veces.
  void pruneLanguages() {
    final slots = languageChoiceSlots;
    final active = {for (final slot in slots) slot.groupId};
    languageChoices.removeWhere((groupId, _) => !active.contains(groupId));
    for (final slot in slots) {
      if (slot.chosen.isEmpty) {
        languageChoices.remove(slot.groupId);
      } else {
        languageChoices[slot.groupId] = List.of(slot.chosen);
      }
    }
  }

  /// Bloque de lanzamiento derivado (cupos de trucos/preparados y CD).
  Spellcasting? get spellcasting => isCaster ? previewSheet.spellcasting : null;

  /// Ids de conjuros ya concedidos por rasgos, fuera de lo que se elige con la
  /// magia de clase. No deben poder elegirse de nuevo: el rasgo ya los da y
  /// gastar un cupo de clase en ellos no suma nada. Cubre trucos
  /// (Prestidigitación del Alto Elfo), conjuros innatos con nivel (Detectar
  /// Magia a nivel 3) y los siempre preparados de una subclase.
  Set<String> get grantedSpellIds => {
        for (final s in previewSheet.innateSpells) s.spellId,
        ...previewSheet.alwaysPreparedSpellIds,
      };

  /// Ids que un rasgo suma a la lista elegible sin concederlos (Conjuros de la
  /// Marca). A diferencia de [grantedSpellIds], estos **sí** gastan cupo.
  Set<String> get spellListAdditionIds => previewSheet.spellListAdditionIds;

  int get hitDie => klass?.hitDie ?? 10;

  /// Reparto resultante según el modo elegido y las 3 opciones del trasfondo.
  Map<Ability, int> get abilitySpread {
    final opts = background?.abilityOptions ?? const [];
    if (opts.isEmpty) return {};
    if (spreadMode == AbilitySpreadMode.oneOneOne) {
      return {for (final a in opts) a: 1};
    }
    final m = <Ability, int>{};
    if (spreadPlusTwo != null) m[spreadPlusTwo!] = 2;
    if (spreadPlusOne != null && spreadPlusOne != spreadPlusTwo) {
      m[spreadPlusOne!] = (m[spreadPlusOne!] ?? 0) + 1;
    }
    return m;
  }

  /// Fija el pool de puntuaciones según el método. En `manual` no hay pool que
  /// repartir: se deja el anterior intacto (queda sin usar) para que volver a
  /// un método con pool no obligue a tirar de nuevo sin querer.
  void applyScoreMethod(ScoreMethod method, {Dice? dice}) {
    scoreMethod = method;
    assignedScores.clear();
    switch (method) {
      case ScoreMethod.standardArray:
        pool = List.of(standardArray);
      case ScoreMethod.roll4d6:
        pool = (dice ?? Dice()).rollAbilityScoreSet();
      case ScoreMethod.pointBuy:
        // Arranca con las seis en el mínimo, que cuesta 0. Es el único punto de
        // partida legal que no obliga a elegir antes de poder subir nada.
        for (final a in Ability.values) {
          assignedScores[a] = pointBuyMin;
        }
      case ScoreMethod.manual:
        break;
    }
  }

  /// Reparto del conjunto estándar que sugiere la clase (tabla del SRD), o
  /// vacío. Solo con ese método: con otro los valores no son esos seis.
  Map<Ability, int> get suggestedScores =>
      scoreMethod == ScoreMethod.standardArray
          ? klass?.suggestedScores ?? const {}
          : const {};

  /// Asigna de una vez el reparto sugerido por la clase.
  void applySuggestedScores() {
    final suggested = suggestedScores;
    if (suggested.isEmpty) return;
    assignedScores
      ..clear()
      ..addAll(suggested);
  }

  /// Puntos ya gastados en la compra de puntos.
  int get pointsSpent => pointBuySpent(assignedScores.values);

  /// Puntos que quedan del presupuesto de 27.
  int get pointsRemaining => pointBuyBudget - pointsSpent;

  /// Si [a] puede subir un escalón: hay techo por encima y alcanza el
  /// presupuesto para pagar la diferencia.
  bool canRaisePointBuy(Ability a) {
    final current = assignedScores[a] ?? pointBuyMin;
    if (current >= pointBuyMax) return false;
    final delta = pointBuyCost(current + 1)! - pointBuyCost(current)!;
    return delta <= pointsRemaining;
  }

  /// Si [a] puede bajar un escalón. Solo depende del piso: bajar siempre
  /// devuelve puntos.
  bool canLowerPointBuy(Ability a) =>
      (assignedScores[a] ?? pointBuyMin) > pointBuyMin;

  /// Mueve [a] en [delta] escalones dentro de la compra de puntos. Ignora el
  /// pedido si sale del rango 8-15 o si no alcanza el presupuesto, para que la
  /// UI nunca pueda dejar el reparto en un estado que el manual no permite.
  void stepPointBuy(Ability a, int delta) {
    if (delta > 0 && !canRaisePointBuy(a)) return;
    if (delta < 0 && !canLowerPointBuy(a)) return;
    final target = (assignedScores[a] ?? pointBuyMin) + delta;
    if (pointBuyCost(target) == null) return;
    assignedScores[a] = target;
  }

  /// Escribe [v] directamente en [a] (solo modo manual). `null` la deja sin
  /// asignar. Fuera de [manualScoreMin]-[manualScoreMax] se ignora.
  void setManualScore(Ability a, int? v) {
    if (v == null) {
      assignedScores.remove(a);
      return;
    }
    if (v < manualScoreMin || v > manualScoreMax) return;
    assignedScores[a] = v;
  }

  /// Valores del pool aún no asignados (para poblar los dropdowns).
  List<int> availableFor(Ability a) {
    final used = <int>[];
    for (final e in assignedScores.entries) {
      if (e.key != a) used.add(e.value);
    }
    final remaining = List.of(pool);
    for (final v in used) {
      remaining.remove(v);
    }
    return remaining..sort((x, y) => y.compareTo(x));
  }

  /// Qué otras características tienen tomado cada valor. Una tirada de 4d6
  /// puede repetir valores, y dos "14" en la lista son indistinguibles: con
  /// esto el paso puede etiquetarlos ("14 · en DES") en vez de mostrar dos
  /// entradas idénticas.
  Map<int, List<Ability>> holdersExcept(Ability a) {
    final m = <int, List<Ability>>{};
    for (final e in assignedScores.entries) {
      if (e.key == a) continue;
      (m[e.value] ??= []).add(e.key);
    }
    return m;
  }

  /// Cuántas copias de [v] quedan libres en el pool, ignorando lo que tenga [a].
  int freeCopiesOf(int v, Ability a) {
    final total = pool.where((x) => x == v).length;
    final taken = holdersExcept(a)[v]?.length ?? 0;
    return total - taken;
  }

  /// Asigna [v] a la característica [a]. Si [v] ya está tomada por otra y no
  /// queda una copia libre en el pool, **intercambia**: la otra recibe el valor
  /// que tenía [a] (o queda sin asignar si [a] no tenía). Así se puede reordenar
  /// libremente aunque estén las 6 asignadas.
  void assignScore(Ability a, int v) {
    if (availableFor(a).contains(v)) {
      assignedScores[a] = v;
      return;
    }
    // Un valor que no está en el pool no se puede asignar ni intercambiar.
    if (!pool.contains(v)) return;
    final previous = assignedScores[a];
    Ability? holder;
    for (final e in assignedScores.entries) {
      if (e.key != a && e.value == v) {
        holder = e.key;
        break;
      }
    }
    assignedScores[a] = v;
    if (holder != null) {
      if (previous != null) {
        assignedScores[holder] = previous;
      } else {
        assignedScores.remove(holder);
      }
    }
  }

  /// Borra todas las asignaciones (conserva método y pool). Escape para
  /// reordenar de cero. En compra de puntos no deja las seis vacías —eso no es
  /// un estado alcanzable— sino de vuelta en el mínimo, con el presupuesto
  /// entero disponible.
  void clearScores() {
    assignedScores.clear();
    if (scoreMethod == ScoreMethod.pointBuy) {
      for (final a in Ability.values) {
        assignedScores[a] = pointBuyMin;
      }
    }
  }

  /// Cuántas habilidades de [from] siguen elegibles tras excluir las ya tomadas
  /// en otro origen ([disabled]).
  int _selectableSkills(List<String> from, Set<String> disabled) =>
      skillOptions(from).toSet().difference(disabled).length;

  /// Las elecciones obligatorias que faltan, en el orden de las secciones.
  /// Lista vacía = se puede crear el personaje.
  ///
  /// El requerido de habilidades se acota a lo realmente elegible: si otro
  /// origen ya tomó opciones y quedan menos que el cupo, se exige solo lo
  /// posible (así el gate nunca deja al usuario sin salida).
  List<CreationPending> get pending => [
        for (final s in CreationSection.values) ...pendingIn(s),
      ];

  /// Lo que falta en [section].
  List<CreationPending> pendingIn(CreationSection section) {
    switch (section) {
      case CreationSection.species:
        if (race == null) {
          return const [CreationPending(CreationPendingKind.pickSpecies)];
        }
        if (lineageOptions.isNotEmpty && lineage == null) {
          return const [CreationPending(CreationPendingKind.pickLineage)];
        }
        if (lineageUsesSpellcastingAbility &&
            speciesSpellcastingAbility == null) {
          return const [
            CreationPending(CreationPendingKind.pickLineageAbility),
          ];
        }
        if (sizeOptions.isNotEmpty && !sizeOptions.contains(chosenSize)) {
          return const [CreationPending(CreationPendingKind.pickSize)];
        }
        return const [];

      case CreationSection.characterClass:
        final k = klass;
        if (k == null) {
          return const [CreationPending(CreationPendingKind.pickClass)];
        }
        final out = <CreationPending>[];
        // Genérico sobre lo que declara el contenido: sumar una clase con otra
        // elección abierta no toca este gating.
        for (final slot in featureChoiceSlots) {
          final chosen = featureChoices[slot.groupId]?.length ?? 0;
          if (chosen < slot.count) {
            out.add(CreationPending(
              CreationPendingKind.featureChoice,
              have: chosen,
              need: slot.count,
              name: slot.name,
            ));
          }
        }
        final slots = weaponMasterySlots;
        if (slots > 0 && weaponMasteries.length < slots) {
          out.add(CreationPending(
            CreationPendingKind.weaponMastery,
            have: weaponMasteries.length,
            need: slots,
          ));
        }
        return out;

      case CreationSection.background:
        if (background == null) {
          return const [CreationPending(CreationPendingKind.pickBackground)];
        }
        if (originFeatWithAbilityChoice case final feat?
            when originFeatSpellcastingAbility == null) {
          return [
            CreationPending(
              CreationPendingKind.pickFeatAbility,
              name: feat.name,
            ),
          ];
        }
        if (spreadMode == AbilitySpreadMode.twoOne &&
            (spreadPlusTwo == null || spreadPlusOne == null)) {
          return const [CreationPending(CreationPendingKind.spread)];
        }
        return const [];

      case CreationSection.scores:
        if (!allScoresAssigned) {
          return [
            CreationPending(
              CreationPendingKind.assignScores,
              have: Ability.values.where(assignedScores.containsKey).length,
              need: Ability.values.length,
            ),
          ];
        }
        return const [];

      case CreationSection.proficiencies:
        final out = <CreationPending>[];
        final k = klass;
        if (k != null) {
          final selectable = _selectableSkills(k.skillChoiceFrom, {
            ...raceSkills,
            ...?background?.skillProficiencies,
          });
          final need =
              k.skillChoiceCount < selectable ? k.skillChoiceCount : selectable;
          if (classSkills.length < need) {
            out.add(CreationPending(
              CreationPendingKind.classSkills,
              have: classSkills.length,
              need: k.skillChoiceCount,
            ));
          }
        }
        final r = race;
        if (r != null) {
          final selectable = _selectableSkills(r.skillChoiceFrom, {
            ...classSkills,
            ...?background?.skillProficiencies,
          });
          final need =
              r.skillChoiceCount < selectable ? r.skillChoiceCount : selectable;
          if (need > 0 && raceSkills.length < need) {
            out.add(CreationPending(
              CreationPendingKind.speciesSkills,
              have: raceSkills.length,
              need: r.skillChoiceCount,
            ));
          }
          final grantsFeat = r.effects.any((e) => e is GrantFeatEffect);
          if (grantsFeat && raceFeatId == null) {
            out.add(const CreationPending(CreationPendingKind.originFeat));
          }
        }
        // Competencias que declara una dote (Habilidoso del trasfondo o de la
        // especie, Mente Aguda). Genérico: sumar otra dote que las conceda no
        // toca este gating.
        final faltan = proficiencyChoiceSlots.fold<int>(
          0,
          (n, slot) => n + slot.pending,
        );
        if (faltan > 0) {
          out.add(CreationPending(
            CreationPendingKind.proficiencies,
            need: faltan,
          ));
        }
        // La Pericia se nombra aparte: decirle "competencia" a lo que duplica
        // el bonificador confunde, y son dos secciones distintas del paso.
        final periciasFaltan = expertiseChoiceSlots.fold<int>(
          0,
          (n, slot) => n + slot.pending,
        );
        if (periciasFaltan > 0) {
          out.add(CreationPending(
            CreationPendingKind.expertise,
            need: periciasFaltan,
          ));
        }
        if (pendingLanguages > 0) {
          out.add(CreationPending(
            CreationPendingKind.languages,
            have: languages.length,
            need: Language.originChoiceCount,
          ));
        }
        if (pendingLanguageChoices > 0) {
          out.add(CreationPending(
            CreationPendingKind.languageChoices,
            need: pendingLanguageChoices,
          ));
        }
        return out;

      case CreationSection.spells:
        // Los conjuros a elección se cuentan aunque la clase no lance: el rasgo
        // que los concede no depende de la magia de clase.
        final out = <CreationPending>[
          if (pendingSpellChoices > 0)
            CreationPending(
              CreationPendingKind.spellChoices,
              need: pendingSpellChoices,
            ),
        ];
        final sc = spellcasting;
        if (sc == null) return out;
        if (cantrips.length < sc.cantripsKnown) {
          out.add(CreationPending(
            CreationPendingKind.cantrips,
            have: cantrips.length,
            need: sc.cantripsKnown,
          ));
        }
        if (spells.length < sc.preparedCount) {
          out.add(CreationPending(
            CreationPendingKind.spells,
            have: spells.length,
            need: sc.preparedCount,
          ));
        }
        return out;

      case CreationSection.equipment:
        // El equipo no obliga (sin arma = puños, sin armadura es válido). Solo
        // se exige elegir entre opciones que existen: un trasfondo homebrew
        // sin equipo dejaba la creación trabada con un desplegable vacío.
        return [
          if (classEquipmentOption == null &&
              (klass?.startingEquipment ?? const []).isNotEmpty)
            const CreationPending(CreationPendingKind.classEquipment),
          if (backgroundEquipmentOption == null &&
              (background?.startingEquipment ?? const []).isNotEmpty)
            const CreationPending(CreationPendingKind.backgroundEquipment),
          if (selectedEquipmentGrants.any(
            (e) => e.grant.isChoice && equipmentChoices[e.key] == null,
          ))
            const CreationPending(CreationPendingKind.equipmentChoices),
          if (goldLeftCp < 0)
            CreationPending(CreationPendingKind.overspent, need: -goldLeftCp),
        ];
    }
  }

  /// Puntuación final de una característica (asignada + reparto de trasfondo),
  /// para previsualizar en vivo durante la asignación.
  int previewScore(Ability a) =>
      (assignedScores[a] ?? 0) + (abilitySpread[a] ?? 0);

  bool get allScoresAssigned =>
      Ability.values.every(assignedScores.containsKey);

  /// Construye el personaje con lo elegido hasta ahora. Sirve para la vista
  /// previa: los PG actuales quedan en cero. El personaje que se guarda sale
  /// de [create].
  ///
  /// Con [replacing] es «rehacer»: las reglas salen del creador, pero el
  /// personaje sigue siendo el mismo. Conserva el id porque de él cuelgan el
  /// vínculo con las campañas y los retratos guardados en el servidor; y
  /// conserva lo que el jugador escribió o subió (retratos, trasfondo, diario),
  /// que no es una regla y ningún paso vuelve a pedir.
  Character build({
    String unnamed = '',
    Character? replacing,
    String? id,
  }) {
    return Character(
      id: id ??
          replacing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? unnamed : name.trim(),
      status: replacing?.status ?? CharacterStatus.active,
      portraitPaths: List.of(replacing?.portraitPaths ?? const []),
      portraitPrompts: Map.of(replacing?.portraitPrompts ?? const {}),
      background: replacing?.background ?? '',
      diary: List.of(replacing?.diary ?? const []),
      tableConfig: replacing?.tableConfig ?? const TableConfig(),
      raceId: raceId ?? '',
      lineageId: lineage?.id,
      speciesSpellcastingAbility: speciesSpellcastingAbility,
      featSpellcastingAbilities: {
        if ((originFeatWithAbilityChoice, originFeatSpellcastingAbility)
            case (final feat?, final ability?))
          feat.id: ability,
      },
      // Solo viaja si la especie realmente lo ofrece: así un tamaño que quedó
      // de una especie anterior no llega al personaje.
      chosenSize: sizeOptions.contains(chosenSize) ? chosenSize : null,
      classId: classId ?? '',
      backgroundId: backgroundId ?? '',
      level: 1,
      assignedScores: {
        for (final a in Ability.values) a: assignedScores[a] ?? 10,
      },
      backgroundAbilityBonuses: abilitySpread,
      chosenSkills: [...classSkills, ...raceSkills],
      chosenProficiencies: List.of(chosenProficiencies),
      proficiencyChoices: {
        for (final e in proficiencyChoices.entries) e.key: List.of(e.value),
      },
      cantripIds: cantrips.toList(),
      spellIds: spells.toList(),
      featureChoices: {
        for (final e in featureChoices.entries) e.key: List.of(e.value),
      },
      spellChoices: {
        for (final e in spellChoices.entries) e.key: List.of(e.value),
      },
      languages: List.of(languages),
      languageChoices: {
        for (final e in languageChoices.entries) e.key: List.of(e.value),
      },
      weaponMasteryChoices: List.of(weaponMasteries),
      featIds: [if (raceFeatId != null) raceFeatId!],
      hpPerLevel: [hitDie],
      equippedArmorId: equippedArmorId,
      shieldEquipped: shieldEquipped,
      equippedWeaponIds: List.of(weaponIds),
      weaponOffHand: Map.of(weaponOffHand),
      weaponTwoHanded: Map.of(weaponTwoHanded),
      // La mochila arranca con lo elegido en el paso de equipo. Sin esto, el
      // personaje nacería con una espada equipada que no figura en su
      // inventario, que es la misma incoherencia que arregla la migración a
      // esquema 19 para las fichas viejas.
      inventory: startingInventory,
      coins: startingCoins,
      alignment: alignment,
      personalityTrait: personalityTrait.trim(),
    );
  }

  /// Lo que el creador de `/v2` muestra, en JSON: el borrador ([toJson]), lo
  /// que falta (`pending`, sin texto: lo pone el cliente), el personaje tal
  /// como quedaría (`character`, para «Así queda») y lo que deciden las
  /// reglas en cada paso. Es la salida de `creation` en el puente JS.
  ///
  /// ponytail: por ahora trae lo derivado de Especie, Clase, Trasfondo y
  /// Características; competencias, conjuros y equipo se suman con sus pasos.
  Map<String, dynamic> viewJson() {
    final draft = this;
    List<String> abilities(Iterable<Ability> list) => [
          for (final a in list) a.name,
        ];
    return {
      'draft': draft.toJson(),
      'pending': [for (final p in draft.pending) p.toJson()],
      // Un id fijo: es una vista previa, y así la paridad no depende del reloj.
      'character': draft.build(id: 'borrador').toJson(),
      'species': {
        'lineages': [
          for (final l in draft.lineageOptions)
            {
              'id': l.id,
              'name': l.name,
              'description': l.description,
              'homebrew': l.source == ContentSource.homebrew,
            },
        ],
        'sizes': draft.sizeOptions,
        'needsLineageAbility': draft.lineageUsesSpellcastingAbility,
      },
      'class': {
        'featureSlots': [
          for (final slot in draft.featureChoiceSlots)
            {
              'groupId': slot.groupId,
              'name': slot.name,
              'count': slot.count,
              'chosen': draft.featureChoices[slot.groupId] ?? const <String>[],
              'options': [
                for (final f in draft.featureChoiceOptions(slot))
                  {'id': f.id, 'name': f.name, 'description': f.description},
              ],
            },
        ],
        'weaponMasterySlots': draft.weaponMasterySlots,
        'weapons': [
          for (final w in draft.proficientWeapons)
            {'id': w.id, 'name': w.name, 'mastery': w.mastery},
        ],
      },
      'background': {
        'abilityOptions':
            abilities(draft.background?.abilityOptions ?? const []),
        'featAbilityOptions': abilities(
          draft.originFeatWithAbilityChoice?.spellcastingAbilityOptions ??
              const [],
        ),
        'spread': {
          for (final e in draft.abilitySpread.entries) e.key.name: e.value,
        },
      },
      'scores': {
        'suggested': {
          for (final e in draft.suggestedScores.entries) e.key.name: e.value,
        },
        'pointsRemaining': draft.pointsRemaining,
        'canRaise': abilities(Ability.values.where(draft.canRaisePointBuy)),
        'canLower': abilities(Ability.values.where(draft.canLowerPointBuy)),
        'preview': {
          for (final a in Ability.values)
            if (draft.assignedScores.containsKey(a))
              a.name: draft.previewScore(a),
        },
      },
    };
  }

  /// El personaje que se guarda al terminar: [build] con los PG actuales en el
  /// máximo, que es como arranca toda ficha nueva.
  Character create({
    String unnamed = '',
    Character? replacing,
    String? id,
  }) {
    final character = build(unnamed: unnamed, replacing: replacing, id: id);
    character.combat.currentHp =
        CharacterCompiler(repo).compile(character).maxHp;
    return character;
  }
}

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

Ability? _ability(Object? value) {
  if (value is! String) return null;
  for (final ability in Ability.values) {
    if (ability.name == value) return ability;
  }
  return null;
}

T _enumByName<T extends Enum?>(List<T> values, Object? name, T fallback) {
  if (name is String) {
    for (final value in values) {
      if (value?.name == name) return value;
    }
  }
  return fallback;
}
