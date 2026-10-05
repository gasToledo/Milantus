part of '../sheet_screen.dart';

extension _SheetGeneralSection on _SheetScreenState {
  // ------------------------------------------------------------- Personaje

  Widget _buildPersonaje() {
    final s = sheet;
    final warnings = CharacterValidator(repo).validate(_c);
    // Lo pendiente ya sale como advertencia con su propio botón; acá queda
    // sólo lo que el motor no reporta, que es poder cambiar lo ya elegido.
    final canReplace = <(String, IconData, VoidCallback)>[
      if (s.proficiencyChoiceSlots.any(
        (slot) => slot.replaceable && slot.pending == 0,
      ))
        (
          context.l10n.replaceProficiency,
          Icons.handyman,
          _resolveProficiencyChoices,
        ),
      // `FeatureChoiceSlot` no lleva `chosen`: es declarativo y lo elegido vive
      // en el personaje, así que lo completo se cuenta desde ahí.
      if (s.featureChoiceSlots.any(
        (slot) =>
            slot.replaceable &&
            (_c.featureChoices[slot.groupId]?.length ?? 0) >= slot.count,
      ))
        (context.l10n.replaceChoice, Icons.style, _resolveFeatureChoices),
      if (s.spellChoiceSlots.any(
        (slot) => slot.replaceable && slot.pending == 0,
      ))
        (context.l10n.replaceSpells, Icons.auto_fix_high, _resolveSpellChoices),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, icon, onPressed) in canReplace) ...[
          _replaceableNotice(title: title, icon: icon, onPressed: onPressed),
          const SizedBox(height: 16),
        ],
        if (warnings.isNotEmpty) ...[
          sheetCard(
            icon: Icons.warning_amber,
            title: context.l10n.sheetWarnings,
            child: DenseRows(
              children: [
                for (final w in warnings)
                  ListTile(
                    dense: true,
                    // Lo pendiente (info) no es una ficha rota: distinguirlo
                    // evita que una elección por hacer parezca un error.
                    leading: Icon(
                      w.severity == WarningSeverity.info
                          ? Icons.info_outline
                          : Icons.warning_amber,
                      color: w.severity == WarningSeverity.info
                          ? context.palette.gold
                          : context.palette.crimson,
                    ),
                    title: Text(w.message),
                    trailing: switch (_resolverFor(w.code)) {
                      final resolver? => TextButton(
                        onPressed: resolver,
                        child: Text(context.l10n.sheetResolve),
                      ),
                      _ => null,
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        responsiveColumns([
          [
            _identityCard(),
            _abilitiesCard(s),
            if (s.unarmoredDefenseOptions.length > 1) _unarmoredDefenseCard(s),
            _proficienciesCard(s),
            _sensesCard(s),
            _languagesCard(s),
          ],
          [_skillsCard(s)],
          [_passivesCard(s)],
        ]),
      ],
    );
  }

  /// Aviso de que una elección ya hecha se puede cambiar: una franja de una
  /// línea con filete dorado, no una tarjeta.
  ///
  /// Los tres avisos pueden salir a la vez, y apilados como tarjetas con botón
  /// relleno le ganaban en peso a Subir nivel, que es el CTA primario de la
  /// ficha. El filete dorado ya dice «hay algo que elegir»; el botón queda
  /// secundario porque la acción es opcional: nada está mal si no se toca.
  Widget _replaceableNotice({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final pal = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      // El filete acompaña el alto real de la franja: en un teléfono el título
      // y la explicación ocupan más de una línea cada uno.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: pal.gold),
            const SizedBox(width: 16),
            Align(child: Icon(icon, size: 19, color: pal.gold)),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.replaceableNoticeBody,
                      style: TextStyle(fontSize: 13, color: pal.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Align(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: OutlinedButton(
                  onPressed: onPressed,
                  child: Text(context.l10n.sheetChange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El editor que resuelve una advertencia, o `null` si no hay ninguno.
  ///
  /// El mapeo vive acá y no en el motor: `code` ya es el identificador estable
  /// —lo fijan los tests del motor— y agregarle un campo sería un segundo
  /// identificador paralelo, con el motor opinando sobre pantallas que no
  /// conoce. Un código nuevo simplemente no trae botón hasta que se le escriba
  /// uno.
  ///
  /// Cada editor resuelve **todas** las instancias de su tipo, así que no hace
  /// falta saber cuál advertencia disparó el botón.
  VoidCallback? _resolverFor(String code) => switch (code) {
    'size_pending' || 'size_invalid' => _resolveSize,
    // Un linaje ausente, inexistente o de otra especie se arregla igual:
    // eligiendo uno válido. Si la especie no ofrece ninguno no hay qué elegir.
    'lineage_pending' || 'lineage_missing' || 'lineage_wrong_race'
        when repo.lineagesForRace(_c.raceId).isNotEmpty =>
      _resolveLineage,
    'species_spellcasting_ability_pending' => _resolveSpeciesAbility,
    'feat_spellcasting_ability_pending' => _resolveFeatAbilities,
    'feature_choice_pending' => _resolveFeatureChoices,
    'spell_choice_pending' => _resolveSpellChoices,
    // Todos los avisos de idiomas los arregla el mismo editor: los del origen
    // y los que deja elegir un rasgo se muestran juntos, que es como el
    // jugador los piensa.
    'language_choice_pending' ||
    'language_choice_pending_feature' ||
    'too_many_languages' ||
    'language_duplicate' ||
    'language_universal_chosen' ||
    'language_not_standard' => _resolveLanguages,
    // El mismo código también sale cuando sobran competencias sin rasgo que
    // las conceda: ahí no hay nada que elegir y el diálogo saldría vacío.
    // El mismo aviso cubre la Pericia, que viaja en su propia lista.
    'proficiency_choice_count'
        when sheet.proficiencyChoiceSlots.isNotEmpty ||
            sheet.expertiseChoiceSlots.isNotEmpty =>
      _resolveProficiencyChoices,
    // La mochila no se arregla con un diálogo: hay que decidir qué se suelta o
    // qué se dessintoniza, y eso se hace mirando la lista entera.
    'encumbered' ||
    'attunement_over_limit' => () => _selectTab(_SheetTab.inventario),
    _ => null,
  };

  Future<void> _resolveProficiencyChoices() async {
    final initial = [
      ...sheet.proficiencyChoiceSlots,
      ...sheet.expertiseChoiceSlots,
    ];
    final choices = <String, List<String>>{
      for (final slot in initial) slot.groupId: List.of(slot.chosen),
    };

    final result = await showDialog<Map<String, List<String>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final previewCharacter = _c.copyWith(
            chosenProficiencies: const [],
            proficiencyChoices: choices,
          );
          final preview = CharacterCompiler(repo).compile(previewCharacter);
          final slots = [
            ...preview.proficiencyChoiceSlots,
            ...preview.expertiseChoiceSlots,
          ];
          final fixed = <String>{
            ...preview.skillProficiencies,
            ...preview.toolProficiencies,
          };
          for (final selected in choices.values) {
            fixed.removeAll(selected);
          }

          bool complete() => slots.every((slot) {
            final selected = choices[slot.groupId] ?? const <String>[];
            return selected.length == slot.count &&
                selected.every(slot.options.contains);
          });

          return AppDialog(
            title: slots.isNotEmpty && slots.every((s) => s.expertise)
                ? context.l10n.pickExpertiseTitle
                : context.l10n.pickProficienciesTitle,
            // Más ancho que el molde: son varios cupos de chips en columna y a
            // 480 cada grupo se parte en demasiadas filas para compararlos.
            width: 720,
            scrollable: false,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.pickProficienciesHint),
                  const SizedBox(height: 16),
                  for (final slot in slots) ...[
                    Text(
                      slot.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${choices[slot.groupId]?.length ?? 0}/${slot.count}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in slot.options)
                          Builder(
                            builder: (context) {
                              final selected =
                                  choices[slot.groupId]?.contains(id) ?? false;
                              final selectedElsewhere = choices.entries
                                  .where((entry) => entry.key != slot.groupId)
                                  .expand((entry) => entry.value)
                                  .contains(id);
                              // En un cupo de Pericia, tener la competencia
                              // es el requisito para elegirla: `fixed` no
                              // debe bloquear. Lo elegido en otro cupo sí,
                              // en los dos casos.
                              final locked =
                                  !selected &&
                                  ((!slot.expertise && fixed.contains(id)) ||
                                      selectedElsewhere);
                              return FilterChip(
                                label: Text(
                                  slot.skills.contains(id)
                                      ? Skill.labelFor(id)
                                      : toolProficiencyLabel(id),
                                ),
                                selected: selected,
                                onSelected: locked
                                    ? null
                                    : (value) => setDialogState(() {
                                        final current =
                                            choices[slot.groupId] ??= [];
                                        if (!value) {
                                          current.remove(id);
                                        } else if (current.length <
                                            slot.count) {
                                          current.add(id);
                                        }
                                      }),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
            actions: [
              DialogAction(
                context.l10n.commonCancel,
                keyHint: 'Esc',
                onPressed: () => Navigator.pop(dialogContext),
              ),
              DialogAction(
                context.l10n.commonSave,
                primary: true,
                onPressed: complete()
                    ? () => Navigator.pop(dialogContext, choices)
                    : null,
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    _replace(
      _c.copyWith(chosenProficiencies: const [], proficiencyChoices: result),
    );
  }

  /// Diálogo de una sola elección sobre una lista corta. Tocar una opción
  /// confirma: con una sola decisión, un botón "Guardar" sobra.
  Future<T?> _pickOne<T>({
    required String title,
    required String hint,
    required List<T> options,
    required String Function(T) label,
    required T? current,
  }) => showDialog<T>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hint),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(label(option)),
                  selected: option == current,
                  onSelected: (_) => Navigator.pop(dialogContext, option),
                ),
            ],
          ),
        ],
      ),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ],
    ),
  );

  Future<void> _resolveSize() async {
    final options = repo.race(_c.raceId)?.sizeOptions ?? const <String>[];
    if (options.isEmpty) return;
    final picked = await _pickOne<String>(
      title: context.l10n.pickSizeTitle,
      hint: context.l10n.pickSizeHint,
      options: options,
      label: (size) => size,
      current: _c.chosenSize,
    );
    if (picked == null || !mounted) return;
    _replace(_c.copyWith(chosenSize: picked));
  }

  Future<void> _resolveLineage() async {
    final options = repo.lineagesForRace(_c.raceId);
    if (options.isEmpty) return;
    final current = options.where((l) => l.id == _c.lineageId).firstOrNull;
    final picked = await _pickOne<Lineage>(
      title: context.l10n.pickLineageTitle,
      hint: context.l10n.pickLineageHint,
      options: options,
      label: (lineage) => lineage.name,
      current: current,
    );
    if (picked == null || !mounted) return;
    // La aptitud mágica no se limpia: los tres linajes que lanzan conjuros
    // ofrecen las mismas opciones, así que borrarla sólo obligaría a elegir de
    // nuevo lo mismo. Si el linaje nuevo la necesita y falta, la advertencia
    // correspondiente aparece con su propio botón.
    _replace(_c.copyWith(lineageId: picked.id));
  }

  Future<void> _resolveSpeciesAbility() async {
    final picked = await _pickOne<Ability>(
      title: context.l10n.pickSpellAbilityTitle,
      hint: context.l10n.pickLineageSpellAbilityHint,
      options: const [Ability.intelligence, Ability.wisdom, Ability.charisma],
      label: (ability) => ability.label,
      current: _c.speciesSpellcastingAbility,
    );
    if (picked == null || !mounted) return;
    _replace(_c.copyWith(speciesSpellcastingAbility: picked));
  }

  /// Aptitud mágica de las dotes que la dejan elegir (Iniciado en la Magia,
  /// Marcas Dracónicas). Se resuelven de a una, en el orden en que la ficha
  /// las lista, igual que el resto de los editores de esta pantalla.
  Future<void> _resolveFeatAbilities() async {
    final validator = CharacterValidator(repo);
    for (final id in validator.heldFeatIds(_c)) {
      final feat = repo.feat(id);
      if (feat == null || feat.spellcastingAbilityOptions.isEmpty) continue;
      if (_c.featSpellcastingAbilities.containsKey(id)) continue;
      final picked = await _pickOne<Ability>(
        title: context.l10n.pickFeatSpellAbilityTitle(feat.name),
        hint: context.l10n.pickFeatSpellAbilityHint,
        options: feat.spellcastingAbilityOptions,
        label: (ability) => ability.label,
        current: null,
      );
      if (picked == null || !mounted) return;
      _replace(
        _c.copyWith(
          featSpellcastingAbilities: {
            ..._c.featSpellcastingAbilities,
            id: picked,
          },
        ),
      );
    }
  }

  /// Resuelve las elecciones abiertas pendientes (Estilo de Combate,
  /// Invocaciones Sobrenaturales…) sin recrear el personaje.
  ///
  /// Las opciones son dotes de la categoría que nombra cada slot y los
  /// prerrequisitos los evalúa el validador del motor, igual que en la creación
  /// y en la subida de nivel.
  Future<void> _resolveFeatureChoices() async {
    final validator = CharacterValidator(repo);
    final choices = <String, List<String>>{
      for (final slot in sheet.featureChoiceSlots)
        slot.groupId: List.of(_c.featureChoices[slot.groupId] ?? const []),
    };

    // Los grupos que no se editan acá se conservan: el motor no limpia solo las
    // elecciones huérfanas y borrarlas sería perder datos del jugador.
    Character withChoices(Map<String, List<String>> edited) =>
        _c.copyWith(featureChoices: {..._c.featureChoices, ...edited});

    final result = await showDialog<Map<String, List<String>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = withChoices(choices);
          final previewSheet = CharacterCompiler(repo).compile(preview);
          final slots = previewSheet.featureChoiceSlots;

          bool complete() => slots.every(
            (slot) => (choices[slot.groupId] ?? const []).length >= slot.count,
          );

          return AppDialog(
            title: context.l10n.pickFeaturesTitle,
            width: 720,
            scrollable: false,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final slot in slots) ...[
                    Text(
                      slot.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Builder(
                      builder: (context) {
                        final chosen = choices[slot.groupId] ??= [];
                        final options = repo
                            .featureChoiceOptions(slot)
                            .where(
                              (f) =>
                                  chosen.contains(f.id) ||
                                  validator.unmetFeatPrerequisite(
                                        f,
                                        preview,
                                        previewSheet,
                                      ) ==
                                      null,
                            )
                            .toList();
                        if (options.isEmpty) {
                          return Text(
                            context.l10n.pickNoOptions,
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        }
                        // ponytail: el `Set` no representa una opción
                        // repetible tomada dos veces. Acá sólo se completan
                        // huecos; para repetir está la subida de nivel, que
                        // sí lleva contador.
                        final selected = chosen.toSet();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${chosen.length}/${slot.count}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            CappedChipSelect(
                              options: {for (final f in options) f.id: f.name},
                              selected: selected,
                              max: slot.count,
                              onChanged: () => setDialogState(
                                () => choices[slot.groupId] = selected.toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
            actions: [
              DialogAction(
                context.l10n.commonCancel,
                keyHint: 'Esc',
                onPressed: () => Navigator.pop(dialogContext),
              ),
              DialogAction(
                context.l10n.commonSave,
                primary: true,
                onPressed: complete()
                    ? () => Navigator.pop(dialogContext, choices)
                    : null,
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    _replace(withChoices(result));
  }

  /// Editor de los conjuros que un rasgo deja elegir y quedan siempre
  /// preparados (Conjuros Característicos, Descubrimientos Mágicos).
  ///
  /// El pozo lo entrega la ficha compilada ya filtrado, así que acá no se
  /// vuelve a interpretar ningún criterio. La ficha se recompila en cada toque
  /// porque un conjuro tomado en un cupo sale del pozo del siguiente.
  Future<void> _resolveSpellChoices() async {
    final choices = <String, List<String>>{
      for (final slot in sheet.spellChoiceSlots)
        slot.groupId: List.of(slot.chosen),
    };

    // Los grupos que no se editan acá se conservan, igual que en
    // `_resolveFeatureChoices`.
    Character withChoices(Map<String, List<String>> edited) =>
        _c.copyWith(spellChoices: {..._c.spellChoices, ...edited});

    final result = await showDialog<Map<String, List<String>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final previewSheet = CharacterCompiler(
            repo,
          ).compile(withChoices(choices));
          final slots = previewSheet.spellChoiceSlots;

          bool complete() => slots.every(
            (slot) => (choices[slot.groupId] ?? const []).length >= slot.count,
          );

          return AppDialog(
            title: context.l10n.pickSpellsTitle,
            width: 720,
            scrollable: false,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final slot in slots) ...[
                    Text(
                      slot.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    // Mismo aviso que en la subida: este cupo no suma un
                    // conjuro, apunta a uno que ya se conoce.
                    if (!slot.grantsSpells)
                      Text(
                        context.l10n.pickKnownSpellHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Builder(
                      builder: (context) {
                        final chosen = choices[slot.groupId] ??= [];
                        if (slot.options.isEmpty) {
                          return Text(
                            context.l10n.pickNoSpells,
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        }
                        final selected = chosen.toSet();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${chosen.length}/${slot.count}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            CappedChipSelect(
                              options: {
                                for (final id in slot.options)
                                  if (repo.spell(id) case final s?)
                                    id: s.isCantrip
                                        ? '${s.name} (truco)'
                                        : '${s.name} (Nv ${s.level})',
                              },
                              selected: selected,
                              max: slot.count,
                              onChanged: () => setDialogState(
                                () => choices[slot.groupId] = selected.toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
            actions: [
              DialogAction(
                context.l10n.commonCancel,
                keyHint: 'Esc',
                onPressed: () => Navigator.pop(dialogContext),
              ),
              DialogAction(
                context.l10n.commonSave,
                primary: true,
                onPressed: complete()
                    ? () => Navigator.pop(dialogContext, choices)
                    : null,
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    _replace(withChoices(result));
  }

  /// Editor de idiomas: los dos del origen y los que deja elegir un rasgo.
  ///
  /// Van en un solo diálogo porque para el jugador son lo mismo —qué habla su
  /// personaje— aunque el motor los guarde por separado según de dónde salgan.
  Future<void> _resolveLanguages() async {
    final origen = {..._c.languages};
    final porRasgo = <String, List<String>>{
      for (final slot in sheet.languageChoiceSlots)
        slot.groupId: List.of(slot.chosen),
    };

    Character conIdiomas() => _c.copyWith(
      languages: origen.toList(),
      languageChoices: {..._c.languageChoices, ...porRasgo},
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Se recompila en cada toque: un idioma tomado en el origen sale del
          // pozo del cupo de rasgo, y al revés.
          final preview = CharacterCompiler(repo).compile(conIdiomas());
          final cupo = Language.originChoiceCount;
          final completo =
              origen.length == cupo &&
              preview.languageChoiceSlots.every((s) => s.pending == 0);

          return AppDialog(
            title: context.l10n.pickLanguagesTitle,
            width: 720,
            scrollable: false,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.pickLanguagesIntro(
                      Language.labelFor(Language.universal.id),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.pickLanguagesOrigin(origen.length, cupo),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  CappedChipSelect(
                    options: {
                      for (final l in Language.originChoices) l.id: l.label,
                    },
                    selected: origen,
                    max: cupo,
                    onChanged: () => setDialogState(() {}),
                  ),
                  for (final slot in preview.languageChoiceSlots) ...[
                    const SizedBox(height: 18),
                    Text(
                      '${slot.name} '
                      '(${(porRasgo[slot.groupId] ?? const []).length}/${slot.count})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final sel = {...?porRasgo[slot.groupId]};
                        return CappedChipSelect(
                          options: {
                            for (final id in slot.options)
                              id: Language.labelFor(id),
                          },
                          selected: sel,
                          max: slot.count,
                          onChanged: () => setDialogState(
                            () => porRasgo[slot.groupId] = sel.toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              DialogAction(
                context.l10n.commonCancel,
                keyHint: 'Esc',
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              DialogAction(
                context.l10n.commonSave,
                primary: true,
                onPressed: completo
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    _replace(conIdiomas());
  }

  Widget _identityCard() {
    final pal = context.palette;
    final bg = repo.background(_c.backgroundId)?.name ?? '—';
    final raceType = repo.race(_c.raceId)?.creatureType;
    final creatureType = raceType == null
        ? '—'
        : vocabularyLabel(VocabularyField.creatureType, raceType);
    final rows = <(String, String)>[
      (context.l10n.identityAlignment, _c.alignment?.label ?? '—'),
      (context.l10n.identityCreatureType, creatureType),
      // El tamaño resuelto lo da la ficha compilada, no la especie: las que
      // dejan elegir traen ahí sólo el valor por defecto.
      (
        context.l10n.identitySize,
        vocabularyLabel(VocabularyField.size, sheet.size),
      ),
      (context.l10n.identityBackground, bg),
      if (_c.personalityTrait.isNotEmpty)
        (context.l10n.identityTrait, _c.personalityTrait),
    ];
    return sheetCard(
      icon: Icons.badge,
      title: context.l10n.identityTitle,
      child: DenseRows(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(color: pal.textMuted)),
                  ),
                  Flexible(
                    flex: 2,
                    child: Text(value, textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _abilitiesCard(ComputedSheet s) {
    final pal = context.palette;
    return sheetCard(
      icon: Icons.fitness_center,
      title: context.l10n.abilitiesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.all(14), child: _abilityRow(s)),
          // La plaqueta cambió de qué número pone grande: decirlo una vez acá
          // sale más barato que dejar a cada quien descubrirlo comparando.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: pal.textMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: context.l10n.abilitiesHintLead,
                      children: [
                        TextSpan(
                          text: context.l10n.saveShort,
                          style: TextStyle(color: pal.gold),
                        ),
                        TextSpan(text: context.l10n.abilitiesHintTail),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: pal.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unarmoredDefenseCard(ComputedSheet s) {
    final options = s.unarmoredDefenseOptions;
    final selected = s.selectedUnarmoredDefenseClassId;
    return sheetCard(
      icon: Icons.shield_outlined,
      title: context.l10n.unarmoredTitle,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: InputDecoration(
            labelText: context.l10n.unarmoredFormula,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.classId,
                child: Text(() {
                  final klass =
                      repo.characterClass(option.classId ?? '')?.name ??
                      option.classId;
                  final shield = option.allowShield
                      ? ' · ${context.l10n.combatShield}'
                      : '';
                  return '$klass · ${option.ability.label}$shield';
                }()),
              ),
          ],
          onChanged: (classId) {
            if (classId != null) {
              _replace(_c.copyWith(unarmoredDefenseClassId: classId));
            }
          },
        ),
      ),
    );
  }

  Widget _proficienciesCard(ComputedSheet s) {
    // Los ids viajan en inglés porque son la clave estable del contenido; la
    // traducción la tiene el motor. Un id de arma concreta (el estoque del
    // Bardo) no está en esa tabla: lo resuelve el catálogo.
    final labels = <String>[
      for (final id in s.armorProficiencies) armorTrainingLabel(id),
      for (final id in s.weaponProficiencies)
        repo.weapon(id)?.name ?? weaponProficiencyLabel(id),
      for (final id in s.toolProficiencies) toolProficiencyLabel(id),
    ]..sort(compareContentNames);
    return sheetCard(
      icon: Icons.verified_user,
      title: context.l10n.proficienciesTitle,
      child: Padding(padding: const EdgeInsets.all(14), child: _chips(labels)),
    );
  }

  /// La CA dentro de un escudo. Ya no la usa la banda táctica —ahí la CA es una
  /// cifra más, comparable con las otras cuatro— pero sigue siendo la forma en
  /// que la muestran las tarjetas donde la CA es el tema: Defensa, en Combate,
  /// e Inventario, donde lo que se equipa la cambia.
  Widget _acPlaque(int ac) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: pal.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.armorUpper,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: pal.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          ShieldBadge('$ac'),
        ],
      ),
    );
  }

  /// Percepción pasiva y visión en la oscuridad, que salieron de la banda
  /// táctica. Las dos responden la misma pregunta —qué nota el personaje sin
  /// buscarlo— y juntas se leen como un par; sueltas entre la CA y la velocidad
  /// parecían cifras de combate.
  Widget _sensesCard(ComputedSheet s) {
    final pal = context.palette;
    final rows = <(String, String, String?)>[
      (context.l10n.passivePerception, '${s.passivePerception}', null),
      if (s.darkvision != null)
        (
          context.l10n.darkvision,
          '${s.darkvision}',
          context.l10n.unitFeetSuffix,
        ),
    ];
    return sheetCard(
      icon: Icons.visibility,
      title: context.l10n.creatureSenses,
      child: DenseRows(
        children: [
          for (final (label, value, suffix) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: value,
                      children: [
                        if (suffix != null)
                          TextSpan(
                            text: suffix,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: pal.textMuted,
                            ),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _languagesCard(ComputedSheet s) {
    // Común primero, que lo sabe todo personaje; el resto por nombre. Se
    // ordena por etiqueta y no por id para que salga alfabético en español.
    final labels = [
      for (final id in s.languages)
        if (id != Language.universal.id) Language.labelFor(id),
    ]..sort(compareContentNames);
    return sheetCard(
      icon: Icons.translate,
      title: context.l10n.creatureLanguages,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _chips([Language.labelFor(Language.universal.id), ...labels]),
      ),
    );
  }

  Widget _skillsCard(ComputedSheet s) {
    final pal = context.palette;
    Widget legend(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        // Flexible y no a secas: en un teléfono los dos rótulos ya no entran
        // uno al lado del otro y el largo tiene que poder cortarse.
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, color: pal.textMuted),
          ),
        ),
      ],
    );
    return sheetCard(
      icon: Icons.psychology,
      title: context.l10n.creatureSkills,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final skill in Skill.values) _skillRow(s, skill),
          // La leyenda nombra las dos marcas. Sin ella el anillo del punto es
          // una diferencia que hay que adivinar, y quien no distingue el oro
          // del gris no tiene de dónde deducirla.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: pal.hairline)),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                legend(
                  _skillDot(proficient: true),
                  context.l10n.skillsLegendProficient,
                ),
                legend(
                  _skillDot(proficient: true, expertise: true),
                  context.l10n.skillsLegendExpertise,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Marca de competencia de una habilidad: punto lleno, o anillo si hay
  /// Pericia. Compartido por las filas y por la leyenda para que no puedan
  /// dibujarse distinto.
  Widget _skillDot({required bool proficient, bool expertise = false}) {
    final pal = context.palette;
    final size = expertise ? 12.0 : 8.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: expertise ? null : (proficient ? pal.gold : pal.hairline),
        shape: BoxShape.circle,
        border: expertise ? Border.all(color: pal.gold, width: 3) : null,
      ),
    );
  }

  Widget _skillRow(ComputedSheet s, Skill skill) {
    final pal = context.palette;
    final proficient = s.skillProficiencies.contains(skill.id);
    final expertise = s.expertiseSkills.contains(skill.id);
    // La cuenta vive en la ficha, no acá: es el mismo método que usa la
    // Percepción pasiva, así que la Pericia no puede llegar a una y no a otra.
    final mod = s.skillModifier(skill.id);
    final color = proficient ? pal.gold : null;
    return Container(
      // Las competentes llevan además un fondo tonal: son las filas que se
      // buscan, y encontrarlas no puede depender solo de que el número esté
      // dorado.
      color: proficient ? pal.gold.withAlpha(12) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          _skillDot(proficient: proficient, expertise: expertise),
          SizedBox(width: expertise ? 8 : 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    skill.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: proficient ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                // La etiqueta nombra la Pericia en vez de insinuarla: el anillo
                // solo la distingue si ya sabés que existe.
                if (expertise) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: pal.gold.withAlpha(128)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      context.l10n.skillExpertiseBadge,
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.6,
                        color: pal.gold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            skill.ability.abbr,
            style: TextStyle(fontSize: 10.5, color: pal.textMuted),
          ),
          SizedBox(
            width: 42,
            child: Text(
              _signed(mod),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passivesCard(ComputedSheet s) {
    if (s.passives.isEmpty) return const SizedBox.shrink();
    return sheetCard(
      icon: Icons.auto_awesome,
      title: context.l10n.traitsAndFeatsTitle,
      trailing: GoldPill('${s.passives.length}'),
      child: Column(
        children: [
          for (var i = 0; i < s.passives.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.palette.hairline),
            // Sin descripción no hay nada que desplegar: una dote como Duro,
            // que es solo un efecto, abría un panel vacío.
            if (s.passives[i].description.trim().isEmpty)
              ListTile(title: Text(s.passives[i].name))
            else
              ExpansionTile(
                title: Text(s.passives[i].name),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedAlignment: Alignment.centerLeft,
                children: [
                  // Un rasgo largo es un párrafo, no una celda: se acota a unos
                  // 60 caracteres por línea y se interlinea, que es lo que hace
                  // que se lea de corrido. En la columna ancha del escritorio,
                  // sin tope, la línea llegaba a los 120 y el ojo perdía el
                  // renglón al volver.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 60 * 7.2),
                    child: Text(
                      s.passives[i].description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  /// Banda táctica: las cinco cifras que se consultan a mitad de turno, en el
  /// orden en que se preguntan en la mesa (CA, PG, iniciativa, velocidad,
  /// competencia).
  ///
  /// Son cinco y no ocho. **Tamaño** ya vive en Identidad, y **Percepción
  /// pasiva** y **Visión en la oscuridad** pasaron a la tarjeta Sentidos: son
  /// sentidos, no cifras de combate, y ocupando lugar acá empujaban a un
  /// segundo renglón las que sí lo son.
  Widget _tacticalBand(ComputedSheet s) {
    final pal = context.palette;
    final c = _c.combat;
    final ratio = s.maxHp == 0 ? 0.0 : c.currentHp / s.maxHp;
    // 152 es el ancho al que «COMPETENCIA» entra en un renglón; menos que eso
    // partía el rótulo en dos. PG pide más porque lleva el par actual/máximo.
    Widget box(Widget child, {double width = 152}) =>
        SizedBox(width: width, child: child);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        box(
          StatTile(
            icon: Icons.shield,
            label: context.l10n.statArmor,
            value: '${s.armorClass}',
          ),
        ),
        box(
          StatTile(
            label: context.l10n.hitPoints,
            labelTrailing: '${(ratio * 100).round()}%',
            value: '${c.currentHp}',
            suffix: ' / ${s.maxHp}',
            valueColor: pal.crimson,
            footer: ThinBar(
              ratio: ratio,
              color: pal.crimson,
              track: Theme.of(context).colorScheme.surface,
            ),
          ),
          width: 208,
        ),
        // Se toca, como las plaquetas de característica: con Alerta el número
        // ya no es la Destreza y hay que poder explicarlo en la mesa.
        box(
          InkWell(
            onTap: () => _showInitiativeBreakdown(s),
            borderRadius: BorderRadius.circular(12),
            child: StatTile(
              icon: Icons.bolt,
              label: context.l10n.initiative,
              value: _signed(s.initiative),
            ),
          ),
        ),
        box(
          StatTile(
            icon: Icons.keyboard_double_arrow_right,
            label: context.l10n.creatureSpeed,
            // Al pie y no en `labelTrailing`, que es para un dato corto tipo
            // «85%»: con este texto la placa desborda en un teléfono.
            footer: _c.combat.exhaustion > 0
                ? Text(
                    context.l10n.exhaustionSpeed(5 * _c.combat.exhaustion),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.crimson,
                    ),
                  )
                : null,
            value: '${s.speed}',
            suffix: context.l10n.unitFeetSuffix,
          ),
        ),
        box(
          StatTile(
            icon: Icons.military_tech,
            label: context.l10n.statProficiency,
            value: '+${s.proficiencyBonus}',
          ),
        ),
      ],
    );
  }

  /// Las seis plaquetas de característica, en una fila o en dos de tres.
  ///
  /// Seis columnas en un teléfono dejan cada plaqueta en unos 30 px, y ahí no
  /// entra ni «Punt. 20» ni la marca de salvación: la plaqueta pasó a decir
  /// tres cosas, no una. Con dos filas de tres cada una queda al doble de
  /// ancho y se lee entera, que es preferible a mostrarla recortada.
  ///
  /// El corte está en 420: la marca «SALV» pide unos 52 px de contenido, que
  /// con el relleno de la plaqueta y los seis huecos da ese total.
  Widget _abilityRow(ComputedSheet s) {
    final a = Ability.values;

    // Toque en vez de tooltip: el tooltip en el celular casi no se descubre, y
    // este es justo el número que hay que poder explicar en la mesa cuando el
    // DM pregunta de dónde sale.
    Widget plaque(Ability ability) => InkWell(
      onTap: () => _showAbilityBreakdown(s, ability),
      borderRadius: BorderRadius.circular(12),
      child: AbilityPlaque(
        ability: ability,
        score: s.abilityScores[ability]!,
        // La prueba de característica y no el modificador crudo: bajo
        // Cansancio no son lo mismo, y lo que se toca en la mesa cuando el DM
        // dice "tirá Fuerza" es esto. El daño sale de Ataques y la CD de
        // Conjuros, que siguen leyendo el modificador.
        modifier: s.abilityCheck(ability),
        saveProficient: s.savingThrowProficiencies.contains(ability),
      ),
    );

    Widget row(List<Ability> abilities) => Row(
      children: [
        for (var i = 0; i < abilities.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: plaque(abilities[i])),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 420
          ? row(a)
          : Column(
              children: [
                row(a.sublist(0, 3)),
                const SizedBox(height: 8),
                row(a.sublist(3)),
              ],
            ),
    );
  }

  /// Explica de dónde sale una característica y qué tiradas dependen de ella.
  ///
  /// Existe por un caso concreto de mesa: el DM preguntó por qué Inteligencia
  /// daba +7 y la ficha mostraba el resultado pero no el camino. Cada línea es
  /// una suma verificable, no un número suelto.
  /// Un renglón de desglose: rótulo a la izquierda, número a la derecha. El
  /// total va `strong`, en oro.
  Widget _breakdownLine(String label, String value, {bool strong = false}) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: strong ? null : muted,
                fontWeight: strong ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              color: strong ? context.palette.gold : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Explica de dónde sale la iniciativa. Con Alerta o Emboscador Temible el
  /// número deja de ser la Destreza, y la placa mostraba el total sin decir
  /// por qué. Cada renglón sale de la ficha compilada: acá no se suma nada
  /// que el engine no haya dicho.
  void _showInitiativeBreakdown(ComputedSheet s) {
    final line = _breakdownLine;
    _infoDialog(
      context.l10n.initiative,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Eyebrow(context.l10n.breakdownWhereFrom),
          line(
            context.l10n.breakdownDexModifier,
            _signed(s.abilityModifiers[Ability.dexterity]!),
          ),
          for (final b in s.initiativeBonuses)
            line(
              b.source.isEmpty ? context.l10n.breakdownOtherTrait : b.source,
              _signed(b.amount),
            ),
          if (s.d20Modifier != 0)
            line(
              context.l10n.exhaustionLevel(_c.combat.exhaustion),
              _signed(s.d20Modifier),
            ),
          const Divider(height: 16),
          line(context.l10n.initiative, _signed(s.initiative), strong: true),
        ],
      ),
    );
  }

  void _showAbilityBreakdown(ComputedSheet s, Ability ability) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final score = s.abilityScores[ability]!;
    final mod = s.abilityModifiers[ability]!;
    final bonuses = s.bonusesFor(ability);
    final sc = s.spellcasting;
    final line = _breakdownLine;

    // Solo las habilidades en las que sos competente. Las demás tiran con el
    // modificador pelado, que ya está arriba: listarlas todas eran seis líneas
    // repitiendo el mismo número en una pantalla de celular.
    // Un aporte de Orden Divina o Primordial también hace que la habilidad
    // deje de tirar con el modificador pelado, aunque no haya competencia.
    final skills = [
      for (final sk in Skill.values)
        if (sk.ability == ability &&
            (s.skillProficiencies.contains(sk.id) ||
                s.expertiseSkills.contains(sk.id) ||
                s.skillBonuses.containsKey(sk.id)))
          sk,
    ];

    _infoDialog(
      ability.label,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ability.description,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          Eyebrow(context.l10n.breakdownWhereFrom),
          line(
            context.l10n.breakdownAssigned,
            '${s.baseAbilityScore(ability)}',
          ),
          for (final b in bonuses)
            line(
              b.source.isEmpty ? context.l10n.breakdownOtherTrait : b.source,
              '${b.amount >= 0 ? '+' : ''}${b.amount}',
            ),
          const Divider(height: 16),
          line(context.l10n.breakdownScore, '$score', strong: true),
          line(context.l10n.breakdownModifier, _signed(mod), strong: true),

          const SizedBox(height: 16),
          Eyebrow(context.l10n.breakdownWhatToRoll),
          line(
            s.savingThrowProficiencies.contains(ability)
                ? context.l10n.breakdownSaveProficient
                : context.l10n.breakdownSave,
            _signed(s.savingThrow(ability)),
          ),
          for (final sk in skills) ...[
            line(
              s.expertiseSkills.contains(sk.id)
                  ? context.l10n.breakdownSkillExpertise(sk.label)
                  : sk.label,
              _signed(s.skillModifier(sk.id)),
            ),
            for (final b in s.skillBonuses[sk.id] ?? const <SkillBonus>[])
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: line(
                  context.l10n.breakdownIncludes(_signed(b.amount), b.source),
                  '',
                ),
              ),
          ],
          // Se muestra siempre y no solo cuando la característica no tiene
          // habilidades: bajo Cansancio la prueba deja de coincidir con el
          // modificador, y el número que hay que tirar es este.
          line(
            context.l10n.breakdownAbilityChecks,
            _signed(s.abilityCheck(ability)),
          ),
          if (_c.combat.exhaustion > 0)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: line(
                context.l10n.breakdownExhaustion(
                  2 * _c.combat.exhaustion,
                  _c.combat.exhaustion,
                ),
                '',
              ),
            ),
          if (sc != null && sc.ability == ability) ...[
            line(context.l10n.breakdownSpellAttack, _signed(sc.attackBonus)),
            line(context.l10n.breakdownSaveDc, '${sc.saveDc}'),
          ],
          const SizedBox(height: 10),
          Text(
            context.l10n.breakdownFooter(
              s.proficiencyBonus,
              s.level,
              _signed(s.abilityCheck(ability)),
            ),
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _chips(List<String> labels) => labels.isEmpty
      ? Text('—', style: TextStyle(color: context.palette.textMuted))
      : Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels.map((l) => Chip(label: Text(l))).toList(),
        );
}
