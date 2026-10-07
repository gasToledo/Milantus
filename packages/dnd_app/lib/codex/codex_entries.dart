part of 'codex_screen.dart';

/// Una entrada del Códice: lo que muestra la fila de la lista y cómo se dibuja
/// su detalle.
///
/// Todas las categorías pasan por esta misma forma para que la lista, la
/// búsqueda general y el detalle sean un solo código: lo único propio de cada
/// tipo de contenido es qué datos pone arriba y qué texto abajo.
class CodexEntry {
  final String id;
  final String name;

  /// La línea de debajo del nombre, en la lista y en el detalle.
  final String subtitle;
  final ContentSource source;

  /// El valor por el que se filtra la categoría (nivel de conjuro, rareza,
  /// categoría de dote), o null si esa categoría no tiene filtro.
  final String? facet;

  /// El orden de [facet] entre los chips: un «Nivel 10» no puede ir antes que
  /// un «Nivel 2», ni «Raro» antes que «Común».
  final int facetRank;

  /// Lo que va debajo del encabezado del detalle. Es una función para no
  /// construir los ~1500 detalles al abrir la pantalla.
  final List<Widget> Function(BuildContext context) body;

  const CodexEntry({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.source,
    required this.body,
    this.facet,
    this.facetRank = 0,
  });
}

/// Las entradas de [category], ordenadas como las lista el Códice.
List<CodexEntry> codexEntries(
  CodexCategory category,
  ContentRepository repo,
  AppLocalizations l10n,
) => switch (category) {
  CodexCategory.races => [for (final r in repo.racesSorted) _race(r, repo)],
  CodexCategory.lineages => [
    for (final l in sortedByName(repo.lineages.values, (e) => e.name))
      _lineage(l, repo, l10n),
  ],
  CodexCategory.classes => [
    for (final c in repo.classesSorted) _class(c, repo),
  ],
  CodexCategory.subclasses => [
    for (final s in sortedByName(repo.subclasses.values, (e) => e.name))
      _subclass(s, repo, l10n),
  ],
  CodexCategory.backgrounds => [
    for (final b in repo.backgroundsSorted) _background(b, repo),
  ],
  CodexCategory.feats => [
    for (final f in repo.featsSorted) _feat(f, repo, l10n),
  ],
  // Por nivel y después por nombre, como en la ficha.
  CodexCategory.spells => [
    for (final s in repo.spellsSorted) _spell(s, repo, l10n),
  ],
  CodexCategory.magicItems => [
    for (final i in repo.itemsSorted)
      if (i.isMagic) _magicItem(i, l10n),
  ],
  CodexCategory.weapons => [for (final w in repo.weaponsSorted) _weapon(w)],
  CodexCategory.armor => [for (final a in repo.armorSorted) _armor(a, l10n)],
  CodexCategory.gear => [
    for (final i in repo.itemsSorted)
      if (!i.isMagic) _gear(i),
  ],
};

// ------------------------------------------------------------ Por tipo

CodexEntry _race(Race r, ContentRepository repo) {
  final lineages = repo.lineagesForRace(r.id);
  return CodexEntry(
    id: r.id,
    name: r.name,
    subtitle:
        r.tagline ??
        vocabularyLabel(VocabularyField.creatureType, r.creatureType),
    source: r.source,
    body: (context) => [
      _facts(context, [
        (
          context.l10n.identityCreatureTypeShort,
          vocabularyLabel(VocabularyField.creatureType, r.creatureType),
        ),
        (
          context.l10n.identitySize,
          r.sizeOptions.isEmpty
              ? vocabularyLabel(VocabularyField.size, r.size)
              : r.sizeOptions
                    .map((o) => vocabularyLabel(VocabularyField.size, o))
                    .join(' ${context.l10n.wordOr} '),
        ),
        (context.l10n.creatureSpeed, context.l10n.feetValue(r.speed)),
        for (final dv in r.effects.whereType<DarkvisionEffect>())
          (context.l10n.darkvision, context.l10n.feetValue(dv.range)),
      ]),
      if (r.description.isNotEmpty) _prose(context, r.description),
      _traits(
        context,
        context.l10n.creatureTraits,
        readableTraits(context.l10n, r.effects, repo),
      ),
      if (lineages.isNotEmpty)
        _section(context, context.l10n.catLineages, [
          _prose(context, lineages.map((l) => l.name).join(' · ')),
        ]),
    ],
  );
}

CodexEntry _lineage(Lineage l, ContentRepository repo, AppLocalizations l10n) {
  final race = repo.race(l.raceId)?.name ?? l.raceId;
  return CodexEntry(
    id: l.id,
    name: l.name,
    subtitle: l10n.codexLineageOf(race),
    source: l.source,
    body: (context) => [
      if (l.description.isNotEmpty) _prose(context, l.description),
      _features(context, l.features),
    ],
  );
}

CodexEntry _class(CharacterClass c, ContentRepository repo) {
  final saves = c.savingThrows.map((a) => a.abbr).join(' · ');
  final subclasses = repo.subclassesForClass(c.id);
  return CodexEntry(
    id: c.id,
    name: c.name,
    subtitle: 'd${c.hitDie} · $saves',
    source: c.source,
    body: (context) => [
      _facts(context, [
        (context.l10n.factHitDie, 'd${c.hitDie}'),
        (context.l10n.savesTitle, saves),
        (
          context.l10n.luStepSubclass,
          context.l10n.codexLevelN(c.subclassLevel),
        ),
      ]),
      _facts(context, [
        if (c.armorProficiencies.isNotEmpty)
          (
            context.l10n.groupArmor,
            c.armorProficiencies.map(armorTrainingLabel).join(', '),
          ),
        if (c.weaponProficiencies.isNotEmpty)
          (
            context.l10n.groupWeapons,
            c.weaponProficiencies.map(weaponProficiencyLabel).join(', '),
          ),
        if (c.skillChoiceCount > 0)
          (
            context.l10n.creatureSkills,
            c.skillChoiceFrom.isEmpty
                ? context.l10n.codexPickAny(c.skillChoiceCount)
                : context.l10n.codexPickFrom(
                    c.skillChoiceCount,
                    c.skillChoiceFrom.map(Skill.labelFor).join(', '),
                  ),
          ),
      ]),
      _features(context, c.features),
      if (subclasses.isNotEmpty)
        _section(context, context.l10n.catSubclasses, [
          _prose(context, subclasses.map((s) => s.name).join(' · ')),
        ]),
    ],
  );
}

CodexEntry _subclass(
  Subclass s,
  ContentRepository repo,
  AppLocalizations l10n,
) {
  final klass = repo.characterClass(s.classId)?.name ?? s.classId;
  return CodexEntry(
    id: s.id,
    name: s.name,
    subtitle: l10n.codexSubclassOf(klass),
    source: s.source,
    facet: klass,
    body: (context) => [
      if (s.description.isNotEmpty) _prose(context, s.description),
      _features(context, s.features),
    ],
  );
}

CodexEntry _background(Background b, ContentRepository repo) {
  final feat = b.originFeatId == null ? null : repo.feat(b.originFeatId!);
  return CodexEntry(
    id: b.id,
    name: b.name,
    subtitle: b.tagline ?? b.abilityOptions.map((a) => a.abbr).join(' · '),
    source: b.source,
    body: (context) => [
      _facts(context, [
        if (b.abilityOptions.isNotEmpty)
          (
            context.l10n.abilitiesTitle,
            b.abilityOptions.map((a) => a.abbr).join(' · '),
          ),
        if (b.skillProficiencies.isNotEmpty)
          (
            context.l10n.creatureSkills,
            b.skillProficiencies.map(Skill.labelFor).join(', '),
          ),
        if (b.toolProficiencies.isNotEmpty)
          (
            context.l10n.groupTools,
            b.toolProficiencies.map(toolProficiencyLabel).join(', '),
          ),
        if (feat != null) (context.l10n.factOriginFeat, feat.name),
      ]),
      if (b.description.isNotEmpty) _prose(context, b.description),
    ],
  );
}

CodexEntry _feat(Feat f, ContentRepository repo, AppLocalizations l10n) {
  final category = featCategoryLabels[f.category] ?? f.category;
  final prerequisite = _prerequisite(f.prerequisite, repo, l10n);
  return CodexEntry(
    id: f.id,
    name: f.name,
    subtitle: category,
    source: f.source,
    facet: category,
    facetRank: featCategoryLabels.keys.toList().indexOf(f.category),
    body: (context) => [
      _facts(context, [
        (context.l10n.codexCategory, category),
        if (prerequisite != null)
          (context.l10n.codexRequirements, prerequisite),
        if (f.repeatable)
          (context.l10n.codexRepeatable, context.l10n.commonYes),
      ]),
      _effectPills(context, f.effects, repo),
      _prose(context, featSummary(context.l10n, f, repo)),
    ],
  );
}

/// Lo que la dote hace en la ficha, una pill dorada por efecto («+1 CAR»,
/// «Conjuro: Detectar pensamientos…»).
///
/// La prosa cuenta el rasgo pero no el aumento: en las dotes partidas por
/// característica, «Líder Inspirador (Carisma)» no decía en ningún lado que
/// suma +1 a Carisma. Los rasgos pasivos quedan afuera porque ya son la prosa.
Widget _effectPills(
  BuildContext context,
  List<Effect> effects,
  ContentRepository repo,
) {
  final lines = [
    for (final e in effects)
      if (e is! PassiveTraitEffect) ?describeEffect(context.l10n, e, repo),
  ];
  if (lines.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final line in lines) GoldPill(line)],
    ),
  );
}

CodexEntry _spell(Spell s, ContentRepository repo, AppLocalizations l10n) {
  final level = s.level == 0 ? l10n.spellCantrip : l10n.spellLevel(s.level);
  return CodexEntry(
    id: s.id,
    name: s.name,
    subtitle: '$level · ${vocabularyLabel(VocabularyField.school, s.school)}',
    source: s.source,
    facet: level,
    facetRank: s.level,
    body: (context) => [
      _facts(context, [
        (
          context.l10n.spellCastingTime,
          s.ritual
              ? context.l10n.codexRitual(
                  vocabularyLabel(VocabularyField.castingTime, s.castingTime),
                )
              : vocabularyLabel(VocabularyField.castingTime, s.castingTime),
        ),
        (
          context.l10n.commonRange,
          vocabularyLabel(VocabularyField.range, s.range),
        ),
        (context.l10n.spellComponents, s.components),
        (
          context.l10n.spellDuration,
          s.concentration
              ? context.l10n.codexConcentration(
                  vocabularyLabel(VocabularyField.duration, s.duration),
                )
              : vocabularyLabel(VocabularyField.duration, s.duration),
        ),
      ]),
      if (s.classes.isNotEmpty)
        _facts(context, [
          (
            context.l10n.codexCanPrepare,
            s.classes
                .map((id) => repo.characterClass(id)?.name ?? id)
                .join(', '),
          ),
        ]),
      _prose(context, s.description),
    ],
  );
}

CodexEntry _magicItem(Item i, AppLocalizations l10n) {
  final rarity = itemRarityLabels[i.rarity] ?? i.rarity!;
  return CodexEntry(
    id: i.id,
    name: i.name,
    subtitle: i.requiresAttunement ? l10n.codexRarityAttune(rarity) : rarity,
    source: i.source,
    facet: rarity,
    facetRank: itemRarityLabels.keys.toList().indexOf(i.rarity!),
    body: (context) => [
      _facts(context, [
        (context.l10n.codexRarity, rarity),
        (
          context.l10n.codexAttunement,
          i.requiresAttunement
              ? context.l10n.codexRequires
              : context.l10n.codexNotRequired,
        ),
        if (i.maxCharges case final charges?)
          (context.l10n.codexCharges, '$charges'),
        if (i.weight > 0)
          (context.l10n.codexWeight, '${formatPounds(i.weight)} lb'),
        if (i.costCp > 0)
          (context.l10n.codexPrice, context.l10n.cost(i.costCp)),
      ]),
      // La primera línea del texto es la de tipo y rareza, que ya está arriba.
      _prose(context, _withoutTypeLine(i.description)),
    ],
  );
}

CodexEntry _weapon(Weapon w) {
  final damage =
      '${w.damageDice} ${DamageType.labelFor(w.damageType).toLowerCase()}';
  final category = weaponProficiencyLabel(w.category);
  return CodexEntry(
    id: w.id,
    name: w.name,
    subtitle: '$category · $damage',
    source: w.source,
    facet: category,
    facetRank: w.category == 'simple' ? 0 : 1,
    body: (context) => [
      _facts(context, [
        (context.l10n.creatureDamage, damage),
        if (w.versatileDice case final v?) (context.l10n.invTwoHanded, v),
        if (w.rangeLabel case final range?) (context.l10n.commonRange, range),
        if (w.mastery case final m?)
          (context.l10n.codexMastery, weaponMasteryName(m)),
        if (w.weight > 0)
          (context.l10n.codexWeight, '${formatPounds(w.weight)} lb'),
        if (w.costCp > 0)
          (context.l10n.codexPrice, context.l10n.cost(w.costCp)),
      ]),
      if (w.properties.isNotEmpty)
        _traits(context, context.l10n.codexProperties, [
          for (final id in w.properties)
            (
              name: weaponProperties[id]?.name ?? id,
              description: weaponProperties[id]?.description ?? '',
            ),
        ]),
      if (w.description.isNotEmpty) _prose(context, w.description),
    ],
  );
}

CodexEntry _armor(Armor a, AppLocalizations l10n) {
  final category = armorTrainingLabel(a.category);
  final ac = a.category == 'shield'
      ? '+${a.baseAc}'
      : !a.addDexMod
      ? '${a.baseAc}'
      : a.maxDexBonus == null
      ? l10n.codexAcDex(a.baseAc)
      : l10n.codexAcDexMax(a.baseAc, a.maxDexBonus!);
  return CodexEntry(
    id: a.id,
    name: a.name,
    subtitle: l10n.codexArmorSubtitle(category, ac),
    source: a.source,
    facet: category,
    facetRank: const ['light', 'medium', 'heavy', 'shield'].indexOf(a.category),
    body: (context) => [
      _facts(context, [
        (context.l10n.creatureAcShort, ac),
        if (a.strengthRequirement case final str?)
          (context.l10n.codexStrength, '$str'),
        if (a.stealthDisadvantage)
          (context.l10n.codexStealth, context.l10n.codexDisadvantage),
        if (a.weight > 0)
          (context.l10n.codexWeight, '${formatPounds(a.weight)} lb'),
        if (a.costCp > 0)
          (context.l10n.codexPrice, context.l10n.cost(a.costCp)),
      ]),
      if (a.description.isNotEmpty) _prose(context, a.description),
    ],
  );
}

CodexEntry _gear(Item i) {
  final category = itemCategoryLabels[i.category] ?? i.category;
  return CodexEntry(
    id: i.id,
    name: i.name,
    subtitle: category,
    source: i.source,
    facet: category,
    facetRank: itemCategoryLabels.keys.toList().indexOf(i.category),
    body: (context) => [
      _facts(context, [
        (context.l10n.codexCategory, category),
        if (i.bundleSize > 1) (context.l10n.codexPackOf, '${i.bundleSize}'),
        if (i.weight > 0)
          (context.l10n.codexWeight, '${formatPounds(i.weight)} lb'),
        if (i.costCp > 0)
          (context.l10n.codexPrice, context.l10n.cost(i.costCp)),
      ]),
      if (i.description.isNotEmpty) _prose(context, i.description),
    ],
  );
}

// ------------------------------------------------------------ Piezas

/// Los requisitos de una dote en una línea, o null si no tiene.
String? _prerequisite(
  FeatPrerequisite? p,
  ContentRepository repo,
  AppLocalizations l10n,
) {
  if (p == null || p.isEmpty) return null;
  String scores(Map<Ability, int> m, String join) =>
      m.entries.map((e) => '${e.key.abbr} ${e.value}').join(join);
  return [
    if (p.minLevel case final level?) l10n.codexLevelN(level),
    if (p.minAbilityScores.isNotEmpty)
      scores(p.minAbilityScores, ' ${l10n.wordAnd} '),
    if (p.anyAbilityScores.isNotEmpty)
      scores(p.anyAbilityScores, ' ${l10n.wordOr} '),
    if (p.requiredClassId case final id?) repo.characterClass(id)?.name ?? id,
    ?p.requiredClassFeature,
    if (p.requiredFeatIds.isNotEmpty)
      p.requiredFeatIds
          .map((id) => repo.feat(id)?.name ?? id)
          .join(' ${l10n.wordOr} '),
    if (p.requiredFeatCategory case final category?)
      l10n.codexPrereqFeat(featCategoryLabels[category] ?? category),
    if (p.requiredProficiency case final prof?)
      prof == 'spellcasting'
          ? l10n.codexPrereqCast
          : l10n.codexPrereqProf(prof),
  ].join(' · ');
}

/// El texto de un objeto mágico sin su primera línea («Anillo, raro»), que el
/// detalle ya muestra como datos.
String _withoutTypeLine(String description) {
  final cut = description.indexOf('\n');
  return cut < 0 ? description : description.substring(cut + 1);
}

/// Datos cortos en placas, como los de la ficha: rótulo arriba, valor abajo.
Widget _facts(BuildContext context, List<(String, String)> facts) {
  if (facts.isEmpty) return const SizedBox.shrink();
  final pal = context.palette;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in facts)
          Container(
            constraints: const BoxConstraints(minWidth: 110, maxWidth: 520),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: pal.plaque,
              border: Border.all(color: pal.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: pal.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _prose(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: SelectableText(
    text,
    style: const TextStyle(fontSize: 14, height: 1.55),
  ),
);

Widget _section(BuildContext context, String title, List<Widget> children) =>
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Eyebrow(title), const SizedBox(height: 6), ...children],
      ),
    );

/// Rasgos con nombre en negrita y su texto, uno por párrafo.
Widget _traits(
  BuildContext context,
  String title,
  List<({String name, String description})> traits,
) {
  if (traits.isEmpty) return const SizedBox.shrink();
  return _section(context, title, [
    for (final t in traits)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: t.description.isEmpty ? t.name : '${t.name}. ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: t.description),
            ],
          ),
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ),
  ]);
}

/// Rasgos de clase, subclase o linaje, agrupados por el nivel en que se
/// ganan: es como se leen en el manual y lo que se pregunta al subir.
Widget _features(BuildContext context, List<ClassFeature> features) {
  if (features.isEmpty) return const SizedBox.shrink();
  final byLevel = <int, List<ClassFeature>>{};
  for (final f in features) {
    (byLevel[f.level] ??= []).add(f);
  }
  final levels = byLevel.keys.toList()..sort();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final level in levels)
        _traits(context, context.l10n.commonLevel(level), [
          for (final f in byLevel[level]!)
            (name: f.name, description: f.description),
        ]),
    ],
  );
}
