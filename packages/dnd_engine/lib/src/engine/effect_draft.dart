import '../data/content_repository.dart';
import '../domain/ability.dart';
import '../domain/content_language.dart';
import '../domain/damage_type.dart';
import '../domain/effects.dart';
import '../domain/language.dart';
import '../domain/name_sort.dart';
import '../domain/proficiency_labels.dart';
import '../domain/skill.dart';
import '../domain/spell_slots.dart';

/// Qué es el número de un tipo de efecto, para que cada cliente lo rotule en su
/// idioma («Pies», «Alcance en pies», «Valor»). El motor no escribe interfaz.
enum EffectUnit { feet, rangeFeet, value }

/// Los tipos de efecto que un editor sabe armar, en el orden en que se
/// ofrecen: primero lo que toca los números de la ficha, después lo que concede
/// competencias, después la magia y por último lo narrativo.
///
/// Es la versión del motor de `_EffectKind` del editor de Flutter, para que
/// `dnd_web` dibuje los campos que el motor declara y no arme nunca el JSON de
/// un efecto a mano.
///
/// ponytail: Flutter todavía arma sus efectos con su propia copia en
/// `effect_editor.dart`; el techo es que agregar un tipo pide tocar las dos. La
/// salida es que el diálogo de Flutter delegue en [EffectDraft].
enum EffectKind {
  abilityBonus(['ability', 'amount']),
  setAbilityScore(['ability', 'amount']),
  hpPerLevel(['amount']),
  hpFlat(['amount']),
  acBonus(['amount']),
  // El bonificador por competencia va como casilla y no como número: sube con
  // el nivel, y un número fijo quedaría viejo al subir.
  initiativeBonus(['amount', 'addProficiency']),
  speedBonus(['amount']),
  setSpeed(['amount']),
  darkvision(['amount']),
  skillProf(['skill']),
  saveProf(['ability']),
  saveBonus(['amount']),
  weaponProf(['weapon']),
  armorProf(['armor']),
  toolProf(['tool']),
  language(['language']),
  // Desplegable y no texto libre: escrito a mano, «fuego» no coincide con el id
  // `fire` y el efecto quedaba guardado sin hacer nada.
  resistance(['damageType']),
  immunity(['damageType']),
  conditionImmunity(['condition']),
  grantSpell(['spell', 'spellUse', 'castAbility']),
  alwaysPrepared(['spell']),
  spellListAddition(['spell']),
  grantFeat(['feat']),
  extraAttack(['amount']),
  masterySlots(['amount']),
  passive(['traitName', 'traitDescription']);

  /// Los campos que pide, en orden. Los ids son los de [EffectDraft.build].
  final List<String> fields;
  const EffectKind(this.fields);

  String get id => name;

  /// El valor con el que arranca el número: el más común en el manual. Con un
  /// 1 para todo, la visión en la oscuridad nacía de un pie.
  int get start => switch (this) {
        speedBonus => 10,
        setSpeed => 30,
        darkvision => 60,
        _ => 1,
      };

  EffectUnit get unit => switch (this) {
        speedBonus || setSpeed => EffectUnit.feet,
        darkvision => EffectUnit.rangeFeet,
        _ => EffectUnit.value,
      };

  static EffectKind? byId(String id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }
}

/// Un campo que no se puede armar. [field] es el id del campo y [code] por qué
/// (hoy solo `required`); el cliente lo traduce a texto.
class EffectFieldError implements Exception {
  final String field;
  final String code;
  const EffectFieldError(this.field, [this.code = 'required']);
  @override
  String toString() => 'EffectFieldError($field, $code)';
}

/// El valor de la dote que significa «la elige el jugador». Va como texto y no
/// como null porque un desplegable no acepta una opción nula.
const anyFeatChoice = 'any';

/// Arma efectos desde los valores de un formulario y dice qué opciones ofrece
/// cada campo. No guarda estado: el cliente manda el tipo y los valores.
class EffectDraft {
  const EffectDraft._();

  static List<({String id, String label})> _sorted(
    Iterable<({String id, String label})> options,
  ) =>
      sortedByName(options, (o) => o.label);

  /// Las opciones de un campo con lista, o null si no la tiene (el número, la
  /// casilla y el texto). Salen del catálogo **fusionado** [repo], así que
  /// incluyen el homebrew.
  ///
  /// Los rótulos que son interfaz (cómo se usa un conjuro, «a elección del
  /// jugador») llevan el id: los pone cada cliente con sus textos.
  static List<({String id, String label})>? options(
    String field,
    ContentRepository repo,
  ) =>
      switch (field) {
        // El nombre completo y no la abreviatura: acá se está eligiendo, y «STR»
        // obliga a saber inglés para tomar la decisión.
        'ability' || 'castAbility' => [
            for (final a in Ability.values) (id: a.name, label: a.label),
          ],
        'skill' => _sorted([
            for (final s in Skill.values) (id: s.id, label: s.label),
          ]),
        'weapon' => [
            for (final id in weaponProficiencyIds)
              (id: id, label: weaponProficiencyLabel(id)),
            // Un rasgo también puede conceder **un arma concreta** (el Bardo con el
            // estoque), y ahí el id es el del arma, no una categoría.
            for (final w in repo.weaponsSorted) (id: w.id, label: w.name),
          ],
        'armor' => [
            for (final id in armorTrainingIds)
              (id: id, label: armorTrainingLabel(id)),
          ],
        'tool' => [
            for (final id in toolProficiencyIds)
              (id: id, label: toolProficiencyLabel(id)),
          ],
        'language' => [
            for (final l in Language.values) (id: l.id, label: l.label),
          ],
        'damageType' => _sorted([
            for (final t in DamageType.values) (id: t.id, label: t.label),
          ]),
        'condition' => [
            for (final id in conditionIds) (id: id, label: conditionLabel(id)),
          ],
        'spell' => [
            for (final s in repo.spellsSorted)
              (
                id: s.id,
                label: s.isCantrip
                    ? localized('${s.name} (truco)', '${s.name} (cantrip)')
                    : localized(
                        '${s.name} (nivel ${s.level})',
                        '${s.name} (level ${s.level})',
                      ),
              ),
          ],
        'spellUse' => [
            for (final u in InnateSpellUse.values)
              (id: u.toJson(), label: u.toJson()),
          ],
        'feat' => [
            (id: anyFeatChoice, label: anyFeatChoice),
            for (final f in repo.featsSorted) (id: f.id, label: f.name),
          ],
        _ => null,
      };

  /// El valor inicial de un campo, los de Flutter: la primera opción de cada
  /// lista y la Fuerza. La dote es la excepción que ya era de Flutter: arranca
  /// en la primera del catálogo y no en «a elección», que es la primera opción
  /// de la lista pero no la más común.
  static Object defaultOf(
          String field, EffectKind kind, ContentRepository repo) =>
      switch (field) {
        'ability' || 'castAbility' => Ability.strength.name,
        'amount' => kind.start,
        'addProficiency' => false,
        'traitName' || 'traitDescription' => '',
        'spellUse' => InnateSpellUse.atWill.toJson(),
        'feat' => repo.featsSorted.firstOrNull?.id ?? anyFeatChoice,
        _ => options(field, repo)!.first.id,
      };

  /// Los tipos con sus campos y opciones, para que el cliente dibuje el diálogo.
  static List<Map<String, Object?>> kinds(ContentRepository repo) => [
        for (final k in EffectKind.values)
          {
            'id': k.id,
            'start': k.start,
            'unit': k.unit.name,
            'fields': [
              for (final f in k.fields)
                {
                  'id': f,
                  'default': defaultOf(f, k, repo),
                  if (options(f, repo) case final list?)
                    'options': [
                      for (final o in list) {'id': o.id, 'label': o.label},
                    ],
                },
            ],
          },
      ];

  static String _text(Object? v) => (v?.toString() ?? '').trim();

  /// Vacío o no entero vale 0, como en Flutter.
  static int _amount(Object? v) =>
      v is num ? v.toInt() : int.tryParse(_text(v)) ?? 0;

  static Ability _ability(Object? v) => Ability.values.firstWhere(
        (a) => a.name == _text(v),
        orElse: () => Ability.strength,
      );

  /// Arma el efecto de [kind] con [values] (campo → valor). Un campo ausente
  /// toma el valor por defecto que no depende del catálogo. Lanza
  /// [EffectFieldError] si falta algo sin lo cual el efecto no existe.
  static Effect build(EffectKind kind, Map<String, Object?> values) {
    final ability = _ability(values['ability']);
    final amount = _amount(values['amount']);
    String choice(String field, String fallback) {
      final v = _text(values[field]);
      return v.isEmpty ? fallback : v;
    }

    String spell() {
      final id = _text(values['spell']);
      // Sin conjuro elegido no hay efecto: el catálogo no se consulta acá.
      if (id.isEmpty) throw const EffectFieldError('spell');
      return id;
    }

    return switch (kind) {
      EffectKind.abilityBonus => AbilityScoreBonusEffect(
          ability: ability,
          amount: amount,
        ),
      EffectKind.setAbilityScore => SetAbilityScoreEffect(
          ability: ability,
          score: amount,
        ),
      EffectKind.hpPerLevel => BonusMaxHpPerLevelEffect(amount),
      EffectKind.hpFlat => BonusMaxHpFlatEffect(amount),
      EffectKind.acBonus => ArmorClassBonusEffect(amount),
      EffectKind.initiativeBonus => InitiativeBonusEffect(
          amount: amount,
          addProficiency: values['addProficiency'] == true,
        ),
      EffectKind.speedBonus => SpeedBonusEffect(amount),
      EffectKind.setSpeed => SetSpeedEffect(amount),
      EffectKind.darkvision => DarkvisionEffect(amount),
      EffectKind.skillProf => SkillProficiencyEffect(
          choice('skill', Skill.values.first.id),
        ),
      EffectKind.saveProf => SavingThrowProficiencyEffect(ability),
      EffectKind.saveBonus => SavingThrowBonusEffect(amount),
      EffectKind.weaponProf => WeaponProficiencyEffect(
          choice('weapon', weaponProficiencyIds.first),
        ),
      EffectKind.armorProf => ArmorProficiencyEffect(
          choice('armor', armorTrainingIds.first),
        ),
      EffectKind.toolProf => ToolProficiencyEffect(
          choice('tool', toolProficiencyIds.first),
        ),
      EffectKind.language => LanguageEffect(
          choice('language', Language.values.first.id),
        ),
      EffectKind.resistance => ResistanceEffect(
          choice('damageType', DamageType.values.first.id),
        ),
      EffectKind.immunity => ImmunityEffect(
          choice('damageType', DamageType.values.first.id),
        ),
      EffectKind.conditionImmunity => ConditionImmunityEffect(
          choice('condition', conditionIds.first),
        ),
      EffectKind.grantSpell => GrantSpellEffect(
          spellId: spell(),
          ability: _ability(values['castAbility']),
          use: InnateSpellUse.fromJson(_text(values['spellUse'])),
        ),
      EffectKind.alwaysPrepared => AlwaysPreparedSpellEffect(spellId: spell()),
      EffectKind.spellListAddition => SpellListAdditionEffect(spellId: spell()),
      // Sin dote elegida es «una dote a elección del jugador», que es un
      // efecto legítimo y no un formulario a medio llenar (la dote de origen
      // 2024).
      EffectKind.grantFeat => GrantFeatEffect(
          featId: switch (_text(values['feat'])) {
            '' || anyFeatChoice => null,
            final id => id,
          },
        ),
      EffectKind.extraAttack => ExtraAttackEffect(amount),
      EffectKind.masterySlots => WeaponMasterySlotsEffect(amount),
      EffectKind.passive => _text(values['traitName']).isEmpty
          ? throw const EffectFieldError('traitName')
          : PassiveTraitEffect(
              name: _text(values['traitName']),
              description: _text(values['traitDescription']),
            ),
    };
  }
}

/// Un efecto en partes, con lo que nombra ya resuelto contra el catálogo, o
/// null si es maquinaria que un jugador no tiene por qué leer: recursos, listas
/// de conjuros, elecciones.
///
/// La frase la arma cada cliente con sus textos (los `effect*` de Flutter, que
/// siguen usando `describeEffect`); lo que se busca en el catálogo queda acá, en
/// un solo lugar. Un id que ya no existe cae al id crudo en vez de desaparecer:
/// borrar una dote no debería volver ilegible al rasgo que la concedía.
///
/// Los casos son los de `describeEffect` de la app, y los dos tienen que
/// moverse juntos. `type` es el del JSON del efecto.
Map<String, Object?>? effectParts(Effect e, ContentRepository repo) {
  final type = e.toJson()['type'];
  Map<String, Object?> parts(Map<String, Object?> rest) => {
        'type': type,
        ...rest,
      };
  return switch (e) {
    AbilityScoreBonusEffect(:final ability, :final amount) => parts({
        'ability': ability.abbr,
        'amount': amount,
      }),
    SetAbilityScoreEffect(:final ability, :final score) => parts({
        'ability': ability.abbr,
        'score': score,
      }),
    SkillProficiencyEffect(:final skill) => parts({
        'name': Skill.labelFor(skill),
      }),
    SavingThrowProficiencyEffect(:final ability) => parts({
        'ability': ability.abbr,
      }),
    SavingThrowBonusEffect(:final amount, :final fromAbility) => parts({
        'amount': amount,
        'fromAbility': fromAbility?.abbr,
      }),
    WeaponProficiencyEffect(:final category) => parts({
        'name': repo.weapon(category)?.name ?? weaponProficiencyLabel(category),
      }),
    ArmorProficiencyEffect(:final category) => parts({
        'name': armorTrainingLabel(category),
      }),
    ToolProficiencyEffect(:final tool) => parts({
        'name': toolProficiencyLabel(tool),
      }),
    LanguageEffect(:final language) => parts({
        'name': Language.labelFor(language),
      }),
    ResistanceEffect(:final damageType) => parts({
        'name': DamageType.labelFor(damageType),
      }),
    ImmunityEffect(:final damageType) => parts({
        'name': DamageType.labelFor(damageType),
      }),
    ConditionImmunityEffect(:final condition) => parts({
        'name': conditionLabel(condition),
      }),
    AbilityCheckBonusEffect(:final ability, :final fromAbility) => parts({
        'ability': ability.abbr,
        'fromAbility': fromAbility.abbr,
      }),
    DarkvisionEffect(:final range) => parts({'range': range}),
    SpeedBonusEffect(:final feet) => parts({'feet': feet}),
    SetSpeedEffect(:final feet) => parts({'feet': feet}),
    ArmorClassBonusEffect(:final amount) => parts({'amount': amount}),
    InitiativeBonusEffect(
      :final amount,
      :final addProficiency,
      :final fromAbility,
    ) =>
      parts({
        'amount': amount,
        'addProficiency': addProficiency,
        'fromAbility': fromAbility?.abbr,
      }),
    BonusMaxHpPerLevelEffect(:final perLevel) => parts({'amount': perLevel}),
    BonusMaxHpFlatEffect(:final amount) => parts({'amount': amount}),
    PassiveTraitEffect(:final name) => parts({'name': name}),
    WeaponMasterySlotsEffect(:final count) => parts({'count': count}),
    ExtraAttackEffect(:final extra) => parts({'extra': extra}),
    GrantFeatEffect(:final featId) => featId == null
        ? parts({'choice': true})
        : parts({'name': repo.feat(featId)?.name ?? featId}),
    GrantSpellEffect(:final spellId, :final use) => parts({
        'name': repo.spell(spellId)?.name ?? spellId,
        'use': use.toJson(),
      }),
    AlwaysPreparedSpellEffect(:final spellId) => parts({
        'name': repo.spell(spellId)?.name ?? spellId,
      }),
    SpellListAdditionEffect(:final spellId) => parts({
        'name': repo.spell(spellId)?.name ?? spellId,
      }),
    _ => null,
  };
}
