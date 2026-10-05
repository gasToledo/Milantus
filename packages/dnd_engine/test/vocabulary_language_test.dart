import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Lo que el SRD escribe igual en los dos idiomas. Cualquier otro rótulo igual
/// en español y en inglés es una traducción que falta.
const _iguales = {
  'CON', 'INT', // abreviaturas de Constitución e Inteligencia
  'Goblin', 'Celestial', 'Infernal', 'Primordial', // idiomas
  'Neutral', // alineamiento
};

/// Todos los rótulos de las tablas del motor en el idioma activo, con una
/// clave para saber de dónde salió cada uno.
Map<String, String> _rotulos() => {
      for (final s in Skill.values) 'skill/${s.id}': s.label,
      for (final a in Ability.values) ...{
        'ability/${a.name}': a.label,
        'abbr/${a.name}': a.abbr,
        'abilityDescription/${a.name}': a.description,
      },
      for (final d in DamageType.values) ...{
        'damage/${d.id}': d.label,
        'damageDescription/${d.id}': d.description,
      },
      for (final c in [
        'blinded',
        'charmed',
        'deafened',
        'frightened',
        'grappled',
        'incapacitated',
        'paralyzed',
        'petrified',
        'poisoned',
        'prone',
        'restrained',
        'stunned',
        'unconscious',
      ])
        'condition/$c': DamageType.labelFor(c),
      for (final l in Language.values) 'language/${l.id}': l.label,
      for (final a in CharacterAlignment.values) 'alignment/${a.name}': a.label,
      for (final id in armorTrainingIds) 'armor/$id': armorTrainingLabel(id),
      for (final id in weaponProficiencyIds)
        'weapon/$id': weaponProficiencyLabel(id),
      for (final id in [
        ...toolProficiencyIds,
        'artisans-tools',
        'gaming-set',
        'musical-instrument',
      ])
        'tool/$id': toolProficiencyLabel(id),
      for (final p in weaponProperties.values) ...{
        'property/${p.id}': p.name,
        'propertyDescription/${p.id}': p.description,
      },
      for (final m in weaponMasteries.values) ...{
        'mastery/${m.id}': m.name,
        'masteryDescription/${m.id}': m.description,
      },
      'damageTypeRule': damageTypeRule,
      'weaponRangeRule': weaponRangeRule,
      'weaponMasteryRule': weaponMasteryRule,
      for (final e in weaponCategoryRules.entries) 'category/${e.key}': e.value,
      for (final e in itemRarityLabels.entries) 'rarity/${e.key}': e.value,
      for (final e in featCategoryLabels.entries)
        if (e.key != 'general') 'featCategory/${e.key}': e.value,
      for (final e in itemCategoryLabels.entries)
        'itemCategory/${e.key}': e.value,
      // El glosario de los formularios homebrew.
      for (final (nombre, mapa) in [
        ('armorCategory', armorCategoryRules),
        ('spellSchool', spellSchoolRules),
        ('spellCastingTime', spellCastingTimeRules),
        ('spellComponent', spellComponentRules),
        ('featCategory', featCategoryRules),
        ('raceSize', raceSizeRules),
        ('itemCategory', itemCategoryRules),
        ('creatureSize', creatureSizeRules),
        ('creatureActionKind', creatureActionKindRules),
      ])
        for (final e in mapa.entries) '$nombre/${e.key}': e.value,
      for (final (i, regla) in [
        armorTrainingRule,
        armorBaseAcRule,
        shieldBaseAcRule,
        armorAddDexRule,
        armorMaxDexRule,
        armorStrengthRule,
        armorStealthRule,
        spellCantripRule,
        spellLevelRule(3),
        spellSchoolNote,
        spellLongCastingRule,
        spellConcentrationRule,
        spellRitualRule,
        spellClassesRule,
        featRepeatableRule,
        raceCreatureTypeRule,
        sizeRule,
        raceSpeedRule,
        raceSkillCountRule,
        raceSkillFromRule,
        raceSizeOptionsRule,
        skillProficiencyRule,
        toolProficiencyRule,
        backgroundAbilitiesRule,
        backgroundOriginFeatRule,
        itemCategoryNote,
        itemMundaneRule,
        itemRarityRule,
        itemAttunementRule,
        itemAcBonusRule,
        itemResistanceRule,
        itemBaseRule,
        itemMagicBonusRule,
        creatureTypeRule,
        creatureBeastNote,
        creatureCrRule,
        creatureAttackBonusRule,
      ].indexed)
        'rule/$i': regla,
    };

Map<String, String> _en() {
  ContentLanguage.current = ContentLanguage.en;
  return _rotulos();
}

void main() {
  tearDown(() => ContentLanguage.current = ContentLanguage.es);

  test('por defecto el vocabulario está en español', () {
    expect(ContentLanguage.current, ContentLanguage.es);
    expect(Skill.labelFor('sleight-of-hand'), 'Juego de Manos');
    expect(Ability.wisdom.abbr, 'SAB');
  });

  test('en inglés cada rótulo tiene su traducción', () {
    final es = _rotulos();
    final en = _en();
    expect(en.keys, es.keys);
    final faltan = [
      for (final k in es.keys)
        if (es[k] == en[k] && !_iguales.contains(en[k])) '$k: ${en[k]}',
    ];
    // También atrapa una clave que falta en la tabla inglesa: los dos idiomas
    // caerían al mismo id capitalizado.
    expect(faltan, isEmpty);
  });

  test('los términos en inglés son los del SRD', () {
    final en = _en();
    expect(en['skill/sleight-of-hand'], 'Sleight of Hand');
    expect(en['abbr/wisdom'], 'WIS');
    expect(en['damage/bludgeoning'], 'Bludgeoning');
    expect(en['condition/prone'], 'Prone');
    expect(en['language/thieves-cant'], "Thieves' Cant");
    expect(en['tool/thieves-tools'], "Thieves' Tools");
    expect(en['mastery/topple'], 'Topple');
    expect(weaponMasteryName('vex'), 'Vex');
  });

  test('el código de característica y el nombre del catálogo no cambian', () {
    ContentLanguage.current = ContentLanguage.en;
    expect(Ability.wisdom.code, 'WIS');
    // Lo usa el generador de objetos: es el nombre del catálogo en español.
    expect(knownToolLabel('thieves-tools'), 'Herramientas de ladrón');
    expect(Skill.fromId('stealth'), Skill.stealth);
  });

  test('un id desconocido cae al id capitalizado en los dos idiomas', () {
    expect(Skill.labelFor('mi-habilidad'), 'Mi Habilidad');
    ContentLanguage.current = ContentLanguage.en;
    expect(Skill.labelFor('mi-habilidad'), 'Mi Habilidad');
    expect(toolProficiencyLabel('mi-herramienta'), 'Mi Herramienta');
  });
}
