part of '../creation_wizard.dart';

class _RaceStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _RaceStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final race = draft.race;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.stepSpecies),
        const SizedBox(height: 10),
        _SplitSelect(
          emptyHint: context.l10n.pickSpeciesHint,
          selection: draft.raceId,
          options: [
            for (final r in draft.repo.racesSorted)
              _ChoiceCard(
                icon: raceIcon(r),
                title: r.name,
                subtitle: r.tagline,
                source: r.source,
                accent: pal.gold,
                selected: draft.raceId == r.id,
                onTap: () {
                  if (draft.raceId != r.id) {
                    draft.raceId = r.id;
                    draft.lineageId = null;
                    draft.speciesSpellcastingAbility = null;
                    draft.chosenSize = null;
                    draft.raceSkills.clear();
                    draft.raceFeatId = null;
                  }
                  onChanged();
                },
              ),
          ],
          detail: race == null
              ? null
              : _DetailPanel(
                  title: race.name,
                  facts: [
                    (
                      context.l10n.identityCreatureTypeShort,
                      vocabularyLabel(
                        VocabularyField.creatureType,
                        race.creatureType,
                      ),
                    ),
                    (
                      context.l10n.identitySize,
                      race.sizeOptions.isEmpty
                          ? vocabularyLabel(VocabularyField.size, race.size)
                          : draft.chosenSize == null
                          ? context.l10n.factToChoose
                          : vocabularyLabel(
                              VocabularyField.size,
                              draft.chosenSize!,
                            ),
                    ),
                    (
                      context.l10n.creatureSpeed,
                      context.l10n.feetValue(race.speed),
                    ),
                    // Es un número, no prosa: ningún rasgo pasivo la cuenta,
                    // y la lista de rasgos solo lee los pasivos.
                    for (final dv in race.effects.whereType<DarkvisionEffect>())
                      (
                        context.l10n.darkvision,
                        context.l10n.feetValue(dv.range),
                      ),
                    if (race.skillChoiceCount > 0)
                      (
                        context.l10n.creatureSkills,
                        context.l10n.factChoose(race.skillChoiceCount),
                      ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (race.description.isNotEmpty) ...[
                        Text(race.description),
                        const SizedBox(height: 18),
                      ],
                      Eyebrow(context.l10n.creatureTraits),
                      const SizedBox(height: 8),
                      _TraitList(
                        readableTraits(context.l10n, race.effects, draft.repo),
                      ),
                      if (race.sizeOptions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Eyebrow(context.l10n.identitySize),
                        Text(
                          context.l10n.pickSizeHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        _SingleSelect(
                          options: {
                            for (final size in race.sizeOptions) size: size,
                          },
                          selected: draft.chosenSize,
                          onSelect: (size) {
                            draft.chosenSize = size;
                            onChanged();
                          },
                        ),
                      ],
                      if (draft.lineageOptions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Eyebrow(context.l10n.raceLineageTitle),
                        Text(
                          context.l10n.raceLineageRequired,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        _SingleSelect(
                          options: {
                            for (final lineage in draft.lineageOptions)
                              lineage.id: lineage.name,
                          },
                          sources: {
                            for (final lineage in draft.lineageOptions)
                              lineage.id: lineage.source,
                          },
                          selected: draft.lineageId,
                          onSelect: (id) {
                            draft.lineageId = id;
                            draft.speciesSpellcastingAbility = null;
                            onChanged();
                          },
                        ),
                        if (draft.lineage case final lineage?) ...[
                          const SizedBox(height: 12),
                          Text(lineage.description),
                          if (lineage.featuresUpTo(1).isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              context.l10n.raceLineageLevel1,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            _TraitList([
                              for (final f in lineage.featuresUpTo(1))
                                (name: f.name, description: f.description),
                            ]),
                          ],
                        ],
                        if (draft.lineageUsesSpellcastingAbility) ...[
                          const SizedBox(height: 14),
                          _AbilityDropdown(
                            label: context.l10n.speciesSpellAbility,
                            value: draft.speciesSpellcastingAbility,
                            options: const [
                              Ability.intelligence,
                              Ability.wisdom,
                              Ability.charisma,
                            ],
                            onChanged: (ability) {
                              draft.speciesSpellcastingAbility = ability;
                              onChanged();
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.pickLineageSpellAbilityHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Paso 2 · Clase. Lista de clases y, al lado, el panel de detalle con lo que
/// esa clase exige a nivel 1 (estilo de combate, maestrías de arma).
class _ClassStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ClassStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final klass = draft.klass;
    final slots = draft.weaponMasterySlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.stepClass),
        const SizedBox(height: 10),
        _SplitSelect(
          emptyHint: context.l10n.pickClassHint,
          selection: draft.classId,
          options: [
            for (final c in repo.classesSorted)
              _ChoiceCard(
                icon: classIcon(c),
                title: c.name,
                subtitle:
                    'd${c.hitDie} · '
                    '${c.savingThrows.map((a) => a.abbr).join(" / ")}',
                source: c.source,
                accent: classAccent(c, context.palette.gold),
                selected: draft.classId == c.id,
                onTap: () {
                  draft.classId = c.id;
                  draft.classSkills.clear();
                  draft.weaponMasteries.clear();
                  draft.featureChoices.clear();
                  draft.cantrips.clear();
                  draft.spells.clear();
                  onChanged();
                },
              ),
          ],
          detail: klass == null
              ? null
              : _DetailPanel(
                  title: klass.name,
                  facts: [
                    (context.l10n.factHitDie, 'd${klass.hitDie}'),
                    (
                      context.l10n.savesTitle,
                      klass.savingThrows.map((a) => a.abbr).join(' · '),
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Genérico: lo que hay que elegir lo declara el contenido
                      // (Estilo de Combate del Guerrero, Invocaciones del
                      // Brujo). Sumar una clase con otra elección no toca esto.
                      for (final slot in draft.featureChoiceSlots) ...[
                        Eyebrow(
                          slot.count == 1
                              ? slot.name
                              : context.l10n.classChooseCount(
                                  slot.name,
                                  slot.count,
                                ),
                        ),
                        const SizedBox(height: 8),
                        _FeatureChoiceSelect(
                          slot: slot,
                          draft: draft,
                          onChanged: onChanged,
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (slots > 0) ...[
                        const SizedBox(height: 18),
                        Eyebrow(context.l10n.classWeaponMasteryTitle(slots)),
                        // Faltaba la mitad de adelante: la lista dice de qué
                        // armas se puede elegir, pero no qué se gana al
                        // elegirlas. El nombre de cada maestría lo trae el
                        // subtítulo del arma.
                        Text(
                          context.l10n.classWeaponMasteryBody(klass.name),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        _WeaponChecklist(
                          weapons: draft.proficientWeapons,
                          selected: draft.weaponMasteries,
                          max: slots,
                          onChanged: onChanged,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Paso 3 · Trasfondo. Incluye el aumento de característica 2024, que en estas
/// reglas viene del trasfondo (no de la especie).
class _BackgroundStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _BackgroundStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final repo = draft.repo;
    final bg = draft.background;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.stepBackground),
        const SizedBox(height: 10),
        _SplitSelect(
          emptyHint: context.l10n.pickBackgroundHint,
          selection: draft.backgroundId,
          options: [
            for (final b in repo.backgroundsSorted)
              _ChoiceCard(
                icon: backgroundIcon(b),
                title: b.name,
                // Lo que decide la elección —la dote de origen y a qué
                // características suma— y no la línea de sabor, que vive en el
                // detalle. Sin esto había que abrir uno por uno para comparar.
                subtitle: _backgroundGist(b, repo),
                source: b.source,
                accent: context.palette.gold,
                selected: draft.backgroundId == b.id,
                onTap: () {
                  if (draft.backgroundId != b.id) {
                    // Otra dote puede no ofrecerla, o no las mismas opciones.
                    draft.originFeatSpellcastingAbility = null;
                  }
                  draft.backgroundId = b.id;
                  draft.spreadPlusTwo = null;
                  draft.spreadPlusOne = null;
                  // El trasfondo nuevo puede conceder justo la dote de origen
                  // que ya estaba elegida para la especie. El paso de aptitudes
                  // deja de ofrecerla, pero volver atrás a cambiar el trasfondo
                  // dejaría la elección vieja en pie y duplicada.
                  final granted = b.originFeatId;
                  final chosen = draft.raceFeatId;
                  if (chosen != null &&
                      chosen == granted &&
                      !(draft.repo.feat(chosen)?.repeatable ?? false)) {
                    draft.raceFeatId = null;
                  }
                  onChanged();
                },
              ),
          ],
          detail: bg == null
              ? null
              : _DetailPanel(
                  title: bg.name,
                  facts: [
                    (
                      context.l10n.creatureSkills,
                      bg.skillProficiencies.map(Skill.labelFor).join(', '),
                    ),
                    // Las herramientas también son del trasfondo y no se
                    // eligen en ningún paso: si no se dicen acá, el jugador
                    // se entera recién en la ficha.
                    if (bg.toolProficiencies.isNotEmpty)
                      (
                        context.l10n.groupTools,
                        bg.toolProficiencies
                            .map(toolProficiencyLabel)
                            .join(', '),
                      ),
                    if (bg.originFeatId != null)
                      (
                        context.l10n.factOriginFeat,
                        repo.feat(bg.originFeatId!)?.name ?? bg.originFeatId!,
                      ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bg.tagline case final tagline?
                          when tagline.trim().isNotEmpty) ...[
                        Text(
                          tagline,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                      ],
                      // El renglón de datos de arriba nombra la dote; acá se
                      // dice qué hace. Elegir trasfondo es elegirla, y hasta
                      // ahora el nombre era todo lo que se sabía de ella.
                      // Sin nada que leer, el rótulo quedaba solo: es lo que
                      // pasaba con Duro antes de describir sus efectos.
                      if (repo.feat(bg.originFeatId ?? '') case final feat?
                          when readableTraits(
                            context.l10n,
                            feat.effects,
                            repo,
                          ).isNotEmpty) ...[
                        Eyebrow(context.l10n.bgOriginFeatGives),
                        const SizedBox(height: 8),
                        _TraitList([
                          for (final t in readableTraits(
                            context.l10n,
                            feat.effects,
                            repo,
                          ))
                            // Casi toda dote de origen trae un rasgo único con
                            // su mismo nombre, y el renglón de datos de arriba
                            // ya lo dijo. Repetirlo no agrega nada.
                            (
                              name: t.name == feat.name ? '' : t.name,
                              description: t.description,
                            ),
                        ]),
                        const SizedBox(height: 18),
                      ],
                      // Mismo selector que el del linaje en el paso Especie.
                      // Sin él, el Acólito nacía con Iniciado en la Magia a
                      // medio resolver y la advertencia en la ficha nueva.
                      if (draft.originFeatWithAbilityChoice
                          case final feat?) ...[
                        _AbilityDropdown(
                          label: context.l10n.pickFeatSpellAbilityTitle(
                            feat.name,
                          ),
                          value: draft.originFeatSpellcastingAbility,
                          options: feat.spellcastingAbilityOptions,
                          onChanged: (ability) {
                            draft.originFeatSpellcastingAbility = ability;
                            onChanged();
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.bgFeatAbilityHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 18),
                      ],
                      Eyebrow(context.l10n.bgAbilityIncrease),
                      const SizedBox(height: 8),
                      SegmentedButton<AbilitySpreadMode>(
                        segments: const [
                          ButtonSegment(
                            value: AbilitySpreadMode.twoOne,
                            label: Text('+2 / +1'),
                          ),
                          ButtonSegment(
                            value: AbilitySpreadMode.oneOneOne,
                            label: Text('+1 / +1 / +1'),
                          ),
                        ],
                        selected: {draft.spreadMode},
                        onSelectionChanged: (s) {
                          draft.spreadMode = s.first;
                          onChanged();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (draft.spreadMode == AbilitySpreadMode.twoOne)
                        _TwoOnePicker(draft: draft, onChanged: onChanged)
                      else
                        Text(
                          context.l10n.bgEachPlusOne(
                            bg.abilityOptions.map((a) => a.abbr).join(", "),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _TwoOnePicker extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _TwoOnePicker({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = draft.background?.abilityOptions ?? const [];
    return Row(
      children: [
        Expanded(
          child: _AbilityDropdown(
            label: '+2',
            value: draft.spreadPlusTwo,
            options: opts,
            onChanged: (a) {
              draft.spreadPlusTwo = a;
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AbilityDropdown(
            label: '+1',
            value: draft.spreadPlusOne,
            options: opts.where((a) => a != draft.spreadPlusTwo).toList(),
            onChanged: (a) {
              draft.spreadPlusOne = a;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _AbilityDropdown extends StatelessWidget {
  final String label;
  final Ability? value;
  final List<Ability> options;
  final ValueChanged<Ability?> onChanged;
  const _AbilityDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Ability>(
          isExpanded: true,
          value: options.contains(value) ? value : null,
          items: options
              .map((a) => DropdownMenuItem(value: a, child: Text(a.abbr)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Paso 4 · Puntuaciones: método, valores pendientes y una tarjeta por
/// característica con el total, el aumento del trasfondo y el modificador.

/// La dote de origen y las características a las que suma un trasfondo, en
/// una línea para su tarjeta. Null si no trae ninguna de las dos (homebrew).
String? _backgroundGist(Background b, ContentRepository repo) {
  final parts = [
    if (b.originFeatId case final id?) repo.feat(id)?.name ?? id,
    if (b.abilityOptions.isNotEmpty)
      b.abilityOptions.map((a) => a.abbr).join(' '),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
