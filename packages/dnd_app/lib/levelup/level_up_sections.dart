part of 'level_up_screen.dart';

extension _LevelUpSections on _LevelUpScreenState {
  Widget _buildStep(_LevelUpStepKind kind) => switch (kind) {
    _LevelUpStepKind.overview => _buildOverviewStep(),
    _LevelUpStepKind.hitPoints => _buildHitPointsStep(),
    _LevelUpStepKind.subclass => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luChooseEyebrow,
          title: context.l10n.luSubclassIntroTitle,
          body: context.l10n.luSubclassIntroBody,
        ),
        const SizedBox(height: 22),
        _buildSubclassSection(),
      ],
    ),
    _LevelUpStepKind.abilityScore => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luChooseEyebrow,
          title: context.l10n.luAsiIntroTitle,
          body: context.l10n.luAsiIntroBody,
        ),
        const SizedBox(height: 22),
        _buildAsi(),
      ],
    ),
    _LevelUpStepKind.featureChoices => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luChooseEyebrow,
          title: context.l10n.luChoicesIntroTitle,
          body: context.l10n.luChoicesIntroBody,
        ),
        const SizedBox(height: 22),
        _buildFeatureChoicesSection(),
      ],
    ),
    _LevelUpStepKind.proficiencies => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luChooseEyebrow,
          title: _pendingAreAllExpertise
              ? context.l10n.aptExpertise
              : context.l10n.stepProficiencies,
          body: _pendingAreAllExpertise
              ? context.l10n.luProfBodyExpertise
              : context.l10n.luProfBody,
        ),
        const SizedBox(height: 22),
        _buildProficiencySection(),
      ],
    ),
    _LevelUpStepKind.features => _buildFeaturesStep(),
    _LevelUpStepKind.spellChoices => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luChooseEyebrow,
          title: context.l10n.luAlwaysPreparedTitle,
          body: context.l10n.luAlwaysPreparedBody,
        ),
        const SizedBox(height: 22),
        _buildSpellChoicesSection(),
      ],
    ),
    _LevelUpStepKind.spells => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luMagicEyebrow,
          title: context.l10n.luYourSpellsAt(_newLevel),
          body: context.l10n.luMagicBody,
        ),
        const SizedBox(height: 18),
        _buildSpellSection(),
      ],
    ),
    _LevelUpStepKind.review => _buildReviewStep(),
  };

  Widget _buildClassChoicePicker() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final before = _sheetBefore;
    final selected = widget.repo.characterClass(_levelUpClassId);
    final invalid =
        selected != null &&
        selected.id != widget.character.classId &&
        selected.multiclass != null &&
        !selected.multiclass!.meetsAbilityRequirements(before.abilityScores);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.luClassOfLevel),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(_levelUpClassId),
          initialValue: _levelUpClassId,
          decoration: InputDecoration(
            labelText: context.l10n.luWhichClass,
            helperText: context.l10n.luClassHelper,
          ),
          items: [
            for (final klass in _classOptions)
              DropdownMenuItem(value: klass.id, child: Text(klass.name)),
          ],
          onChanged: (id) {
            if (id != null) _selectLevelUpClass(id);
          },
        ),
        if (selected != null) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.luClassLevelLine(
              _newClassLevel,
              selected.name,
              selected.hitDie,
            ),
            style: TextStyle(color: muted, fontSize: 12.5),
          ),
        ],
        if (invalid)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              context.l10n.luMulticlassReq(
                selected.multiclass!.requirementLabel,
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12.5,
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverviewStep() {
    final features = _gainedFeatures();
    final choices = <Widget>[
      // Promedio o tirada es una decisión, y el Estilo de Combate también:
      // listados entre los cambios automáticos, el jugador no esperaba que se
      // le preguntara nada.
      _LevelUpCard(
        icon: Icons.favorite,
        title: context.l10n.hitPoints,
        body: context.l10n.luOverviewHp(_hitDie),
        tag: context.l10n.luTagYouChoose,
      ),
      if (_openChoiceSlots case final open when open.isNotEmpty)
        _LevelUpCard(
          icon: Icons.style,
          title: open.length == 1
              ? open.single.name
              : context.l10n.luFeatureChoicesTitle,
          body: open.length == 1
              ? context.l10n.luFeatureChoicesBody
              : open.map((s) => s.name).join(' · '),
          // Igual que la tarjeta de conjuros: si todo está elegido y solo
          // queda revisar, no es una decisión obligatoria.
          tag: _pendingChoices > 0
              ? context.l10n.luTagYouChoose
              : context.l10n.luTagOptional,
        ),
      if (_needsSubclass)
        _LevelUpCard(
          icon: Icons.shield,
          title: context.l10n.luChooseSubclass,
          body: context.l10n.luChooseSubclassBody,
          tag: context.l10n.luTagYouChoose,
        ),
      if (_isAsi)
        _LevelUpCard(
          icon: Icons.trending_up,
          title: context.l10n.luStepAsi,
          body: context.l10n.luAsiCardBody,
          tag: context.l10n.luTagYouChoose,
        ),
      if (_hasSpellcasting)
        _LevelUpCard(
          icon: Icons.auto_stories,
          title: context.l10n.luReviewSpells,
          body: context.l10n.luReviewSpellsBody,
          // Decía «OPCIONAL» aunque el nivel trajera un truco o un conjuro
          // nuevo, y el paso que sigue ahora no deja confirmar sin elegirlos.
          tag: _classSpellsComplete
              ? context.l10n.luTagOptional
              : context.l10n.luTagYouChoose,
        ),
    ];
    final automatic = <Widget>[
      if (features.isNotEmpty)
        _LevelUpCard(
          icon: Icons.workspace_premium,
          title: features.length == 1
              ? features.single.name
              : '${features.length} rasgos de clase',
          // Con un solo rasgo, el cuerpo repetía el título («Canalizar
          // Divinidad / Canalizar Divinidad»): va su primera oración.
          body: features.length == 1
              ? features.single.description.split('. ').first
              : features.map((feature) => feature.name).join(' · '),
          tag: context.l10n.luTagAuto,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 142,
                height: 142,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.palette.plaque,
                  border: Border.all(color: context.palette.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: context.palette.gold.withAlpha(45),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.luLevelUpper,
                      style: TextStyle(
                        color: context.palette.gold,
                        fontSize: 10,
                        letterSpacing: 2.5,
                      ),
                    ),
                    Text(
                      '$_newLevel',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 62,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                // Sin «listo»: el personaje no tiene por qué ser varón.
                context.l10n.luCharacterLevels(
                  widget.character.name,
                  _newLevel,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 28),
              ),
              const SizedBox(height: 7),
              Text(
                context.l10n.luOverviewIntro,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // Los dos encabezados de abajo ya separan lo automático de lo que se
        // elige. Lo que no dice ninguna pantalla es por qué la lista de pasos
        // cambia de personaje a personaje, ni que hasta el final no se tocó
        // nada: sin eso, salir del wizard da miedo. La única escritura es
        // `onDone`, y la hace `_confirm`.
        AppHelpCallout(message: context.l10n.luOverviewHelp),
        const SizedBox(height: 28),
        _buildClassChoicePicker(),
        if (automatic.isNotEmpty) ...[
          Eyebrow(context.l10n.luAutoChanges),
          _responsiveCards(automatic),
          const SizedBox(height: 24),
        ],
        Eyebrow(context.l10n.luDecisions),
        _responsiveCards(choices),
      ],
    );
  }

  Widget _responsiveCards(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  Widget _buildHitPointsStep() {
    final before = _sheetBefore;
    final after = _updatedSheet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          // Promedio o tirada es una decisión: «automático» decía lo contrario.
          eyebrow: context.l10n.luChooseEyebrow,
          title: context.l10n.luMoreHpTitle,
          body: context.l10n.luMoreHpBody(_hitDie),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final picker = _LevelUpCard(
              icon: Icons.casino,
              title: context.l10n.luHitDie(_hitDie),
              body: _hpMethod == _HpMethod.roll && _rolledHp == null
                  ? context.l10n.luNoResult
                  : context.l10n.luBaseGain(_hpGain),
              trailing: Text(
                _hpMethod == _HpMethod.roll && _rolledHp == null
                    ? '—'
                    : '$_hpGain',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 30,
                  color: context.palette.gold,
                ),
              ),
            );
            // La tarjeta mostraba el resultado y escondía los sumandos: decía
            // «ganancia base +4» de un lado y «40 → 46» del otro, sin nada que
            // explicara los otros dos. Quien hizo el personaje no podía
            // reconstruirlo, y quien recién empieza concluye que la cuenta está
            // mal.
            //
            // El resto no se desglosa más ni se nombra el rasgo que lo da: eso
            // sale de agregar efectos y lo hace el motor, no un widget. Sumado
            // así, los tres renglones siempre cierran contra la cifra de al
            // lado, aunque mañana aparezca otra fuente de PG.
            final conMod = after.abilityModifiers[Ability.constitution] ?? 0;
            final delta = after.maxHp - before.maxHp;
            final resto = delta - _hpGain - conMod;
            final sinTirar = _hpMethod == _HpMethod.roll && _rolledHp == null;
            String firmado(int n) => n >= 0 ? '+$n' : '$n';
            final preview = _LevelUpCard(
              icon: Icons.favorite,
              title: context.l10n.luHpMaxTitle,
              // El aviso de la revisión final sale solo cuando este nivel trae
              // mejora de característica: sin un lugar donde subir Constitución
              // era un renglón que no le hablaba a nadie, y de paso empujaba
              // los botones de método fuera de una ventana baja.
              body: sinTirar
                  ? context.l10n.luRollToSee
                  : '${context.l10n.luHpTotal([context.l10n.luHpDie(_hpGain), context.l10n.luHpCon(firmado(conMod)), if (resto != 0) context.l10n.luHpFeatures(firmado(resto))].join(' · '), firmado(delta))}'
                        '${_isAsi ? ' ${context.l10n.luHpRecalc}' : ''}',
              trailing: Text(
                // Sin tirar, la cifra de la derecha era solo la Constitución y
                // se leía como el resultado.
                sinTirar
                    ? '${before.maxHp} → ?'
                    : '${before.maxHp} → ${after.maxHp}',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  color: context.palette.crimson,
                ),
              ),
            );
            return Column(
              children: [
                if (compact) ...[
                  picker,
                  const SizedBox(height: 12),
                  preview,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: picker),
                      const SizedBox(width: 14),
                      Expanded(child: preview),
                    ],
                  ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<_HpMethod>(
                    segments: [
                      ButtonSegment(
                        value: _HpMethod.average,
                        icon: const Icon(Icons.balance),
                        label: Text(
                          context.l10n.luAverage(averageHitDie(_hitDie)),
                        ),
                      ),
                      ButtonSegment(
                        value: _HpMethod.roll,
                        icon: Icon(Icons.casino),
                        label: Text(context.l10n.luRoll),
                      ),
                    ],
                    selected: {_hpMethod},
                    onSelectionChanged: (selection) => _updateState(() {
                      _hpMethod = selection.first;
                      _rolledHp = null;
                    }),
                  ),
                ),
                if (_hpMethod == _HpMethod.roll) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => _updateState(
                        () => _rolledHp = Dice().rollHitDie(_hitDie),
                      ),
                      icon: const Icon(Icons.casino),
                      label: Text(
                        _rolledHp == null
                            ? context.l10n.luRollDie
                            : context.l10n.luRollAgain,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Resuelve las elecciones abiertas del nivel nuevo.
  ///
  /// Las opciones salen de la categoría que declara cada espacio, y los
  /// prerrequisitos los evalúa el validador del motor: el mismo camino que el
  /// selector de dotes. Un grupo lleno y revisable deja cambiar la elección,
  /// que es lo que pide la regla de las invocaciones.
  Widget _buildFeatureChoicesSection() {
    final target = _buildUpdated();
    final sheet = _updatedSheet;
    final validator = CharacterValidator(widget.repo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slot in _choiceSlots) ...[
          Eyebrow(
            '${slot.name} (${_choicesFor(slot.groupId).length}/${slot.count})',
          ),
          const SizedBox(height: 6),
          _FeatureChoiceGroup(
            slot: slot,
            chosen: _choicesFor(slot.groupId),
            repo: widget.repo,
            options: widget.repo
                .featureChoiceOptions(slot)
                .where(
                  (f) =>
                      _choicesFor(slot.groupId).contains(f.id) ||
                      validator.unmetFeatPrerequisite(f, target, sheet) == null,
                )
                .toList(),
            onChanged: (ids) => _setChoices(slot.groupId, ids),
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  Widget _buildProficiencySection() {
    final data = _proficiencyData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slot in data.slots) ...[
          Eyebrow(
            '${slot.name} '
            '(${_proficiencyFor(slot.groupId).length}/${slot.count})',
          ),
          const SizedBox(height: 6),
          _ProficiencyChoiceGroup(
            slot: slot,
            chosen: _proficiencyFor(slot.groupId),
            // Lo elegido en otro cupo también bloquea: dos cupos abiertos a la
            // vez no pueden repartirse la misma competencia.
            locked: {
              ...data.fixed,
              for (final e in _effectiveProficiencyChoices.entries)
                if (e.key != slot.groupId) ...e.value,
            },
            onChanged: (ids) => _setProficiency(slot.groupId, ids),
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  Widget _buildSpellChoicesSection() {
    // Primero lo que esta subida trae sin llenar. En el orden del compilador,
    // el truco de Descarga Agónica tomada a nivel 2 quedaba debajo del Libro
    // de las Sombras y de Iniciado en la Magia, ya completos y con decenas de
    // opciones. La partición se mide contra el personaje de antes de la
    // subida y no contra lo elegido en vivo: así un cupo no salta de lugar
    // en el momento en que se lo termina de llenar.
    final slots = _spellChoiceSlots;
    bool isNew(SpellChoiceSlot s) =>
        _originalSpellChoiceFor(s.groupId).length < s.count;
    final fresh = slots.where(isNew).toList();
    final revisable = slots.where((s) => !isNew(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slot in fresh) ..._spellChoiceSlotWidgets(slot),
        if (fresh.isNotEmpty && revisable.isNotEmpty) ...[
          Text(
            context.l10n.luChosenEarlier,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.luChangeOrKeep,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
        ],
        for (final slot in revisable) ..._spellChoiceSlotWidgets(slot),
      ],
    );
  }

  List<Widget> _spellChoiceSlotWidgets(SpellChoiceSlot slot) => [
    Eyebrow(
      '${slot.name} '
      '(${_spellChoiceFor(slot.groupId).length}/${slot.count})',
    ),
    // El título del paso promete conjuros siempre preparados; un cupo
    // que solo señala uno ya conocido (Descarga Agónica) tiene que
    // decir que no suma nada nuevo.
    if (!slot.grantsSpells) ...[
      const SizedBox(height: 4),
      Text(
        context.l10n.pickKnownSpellHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
    const SizedBox(height: 6),
    _SpellChoiceGroup(
      repo: widget.repo,
      slot: slot,
      chosen: _spellChoiceFor(slot.groupId),
      onChanged: (ids) => _setSpellChoice(slot.groupId, ids),
    ),
    const SizedBox(height: 22),
  ];

  Widget _buildFeaturesStep() {
    final features = _gainedFeatures();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luAutoEyebrow,
          title: context.l10n.luFeaturesAt(_newLevel),
          body: context.l10n.luFeaturesBody,
        ),
        const SizedBox(height: 20),
        DenseRows(
          children: [
            for (final feature in features)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 20,
                      color: context.palette.gold,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.name,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (feature.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              feature.description,
                              style: TextStyle(
                                height: 1.5,
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final before = _sheetBefore;
    final updated = _buildUpdated();
    final after = _updatedSheet;
    final diff = diffSheets(before, after);
    final beforeResources = {
      for (final resource in before.resources) resource.key: resource,
    };
    final resourceRows = <Widget>[];
    for (final resource in after.resources) {
      final previous = beforeResources[resource.key];
      if (previous?.max == resource.max) continue;
      resourceRows.add(
        _ReviewRow(
          icon: Icons.bolt,
          label: resource.name,
          // Sin clase es de la especie o de una dote: el Ataque de Aliento
          // figuraba como «Recurso de clase».
          note: resource.classId == null
              ? context.l10n.luResource
              : context.l10n.luClassResource,
          before: '${previous?.max ?? 0}',
          after: '${resource.max}',
        ),
      );
    }
    final beforeSpells = before.spellcasting;
    final afterSpells = after.spellcasting;
    final beforeSlots = _slotSummary(beforeSpells?.slotsByLevel ?? const {});
    final afterSlots = _slotSummary(afterSpells?.slotsByLevel ?? const {});
    final rows = <Widget>[
      _ReviewRow(
        icon: Icons.military_tech,
        label: context.l10n.sortLevel,
        note: _klass?.name ?? widget.character.classId,
        before: '${widget.character.level}',
        after: '$_newLevel',
      ),
      _ReviewRow(
        icon: Icons.favorite,
        label: context.l10n.luReviewMaxHp,
        note: context.l10n.luReviewHpNote(diff.hpGained),
        before: '${before.maxHp}',
        after: '${after.maxHp}',
      ),
      if (diff.proficiencyBonusChanged)
        _ReviewRow(
          icon: Icons.verified,
          label: context.l10n.luReviewProfBonus,
          note: context.l10n.luReviewProfBonusNote,
          before: '+${diff.proficiencyBonusFrom}',
          after: '+${diff.proficiencyBonusTo}',
        ),
      ...resourceRows,
      if (beforeSlots != afterSlots)
        _ReviewRow(
          icon: Icons.diamond_outlined,
          label: context.l10n.spellsSlots,
          note: context.l10n.luReviewSlotsNote,
          before: beforeSlots,
          after: afterSlots,
        ),
      if (beforeSpells?.preparedCount != afterSpells?.preparedCount)
        _ReviewRow(
          icon: Icons.menu_book,
          label: context.l10n.spellsPreparedTitle,
          note: context.l10n.luReviewPreparedNote,
          before: '${beforeSpells?.preparedCount ?? 0}',
          after: '${afterSpells?.preparedCount ?? 0}',
        ),
      if (beforeSpells?.cantripsKnown != afterSpells?.cantripsKnown)
        _ReviewRow(
          icon: Icons.flare,
          label: context.l10n.spellsCantripsTitle,
          note: context.l10n.luReviewCantripsNote,
          before: '${beforeSpells?.cantripsKnown ?? 0}',
          after: '${afterSpells?.cantripsKnown ?? 0}',
        ),
      if (diff.extraAttacksGained > 0)
        _ReviewRow(
          icon: Icons.sports_martial_arts,
          label: context.l10n.luReviewAttacks,
          note: context.l10n.luReviewExtraAttack,
          before: '${before.attacksPerAction}',
          after: '${after.attacksPerAction}',
        ),
      if (diff.weaponMasterySlotsGained > 0)
        _ReviewRow(
          icon: Icons.gavel,
          label: context.l10n.luReviewMasteries,
          note: context.l10n.luReviewMasteriesNote,
          before: '${before.weaponMasterySlots}',
          after: '${after.weaponMasterySlots}',
        ),
      if (_needsSubclass && _subclassId != null)
        _ReviewRow(
          icon: Icons.shield,
          label: context.l10n.luStepSubclass,
          note: context.l10n.luReviewSubclassNote,
          before: '—',
          after: widget.repo.subclass(_subclassId!)?.name ?? _subclassId!,
        ),
      if (_isAsi)
        _ReviewRow(
          icon: _asiKind == _AsiKind.feat
              ? Icons.workspace_premium
              : Icons.trending_up,
          label: _asiKind == _AsiKind.feat
              ? context.l10n.luFeat
              : context.l10n.abilitiesTitle,
          note: _asiKind == _AsiKind.feat
              ? context.l10n.luReviewFeatNote
              : context.l10n.luReviewImproveNote,
          before: '—',
          after: _asiReviewLabel(),
        ),
      // Por clase y no las listas planas: editar los conjuros en la subida los
      // pasa al mapa por clase y vacía las planas, y la fila decía «4 → 0».
      if (_newCantrips != null || _newSpells != null)
        _ReviewRow(
          icon: Icons.auto_stories,
          label: context.l10n.luReviewChosenSpells,
          note: context.l10n.luReviewChosenNote,
          before:
              '${widget.character.cantripIdsFor(_levelUpClassId).length + widget.character.spellIdsFor(_levelUpClassId).length}',
          after:
              '${updated.cantripIdsFor(_levelUpClassId).length + updated.spellIdsFor(_levelUpClassId).length}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelUpIntro(
          eyebrow: context.l10n.luFinalEyebrow,
          title: context.l10n.luFinalTitle(widget.character.name),
          body: context.l10n.luFinalBody,
        ),
        const SizedBox(height: 20),
        DenseRows(children: rows),
        if (_gainedFeatures().isNotEmpty) ...[
          const SizedBox(height: 22),
          Eyebrow(context.l10n.luIncorporated),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final feature in _gainedFeatures()) GoldPill(feature.name),
            ],
          ),
        ],
      ],
    );
  }

  String _asiReviewLabel() {
    if (_asiKind == _AsiKind.feat) {
      return widget.repo.feat(_featId!)?.name ?? _featId!;
    }
    return _abilityIncreases.entries
        .map((entry) => '${entry.key.abbr} +${entry.value}')
        .join(' · ');
  }

  String _slotSummary(Map<int, int> slots) {
    if (slots.isEmpty) return '—';
    final entries = slots.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((entry) => context.l10n.luSlotLine(entry.key, entry.value))
        .join(' · ');
  }

  Widget _buildSubclassSection() {
    if (!_needsSubclass) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.luSubclassAt(_newLevel)),
        const SizedBox(height: 8),
        for (final s in _subclassOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _updateState(() => _subclassId = s.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _subclassId == s.id
                      ? context.palette.goldSoft
                      : context.palette.plaque,
                  border: Border.all(
                    color: _subclassId == s.id
                        ? context.palette.gold
                        : context.palette.hairline,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _subclassId == s.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _subclassId == s.id ? context.palette.gold : muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SourceBadge(s.source),
                            ],
                          ),
                          if (s.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              s.description,
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ],
                          // Solo en la elegida: con todas abiertas, la lista de
                          // ocho subclases se vuelve un manual. Cambiar de
                          // opción es gratis, así que tocar es mirar.
                          if (_subclassId == s.id)
                            for (final f in s.featuresUpTo(_newClassLevel)) ...[
                              const SizedBox(height: 8),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${f.name}. ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: f.description),
                                  ],
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Sección de conjuros del nivel nuevo (solo para lanzadores): muestra los
  /// espacios y cupos al nuevo nivel, marca los niveles de espacio recién
  /// abiertos y permite preparar/aprender conjuros sin salir de la subida.
  Widget _buildSpellSection() {
    final targetBlock = _updatedSheet.spellcastingBlocks
        .where((block) => block.classId == _levelUpClassId)
        .firstOrNull;
    final after = targetBlock?.spellcasting ?? _updatedSheet.spellcasting;
    if (after == null) return const SizedBox.shrink();
    final before = _sheetBefore.spellcasting;
    final beforeLevels = before?.slotsByLevel.keys.toSet() ?? const <int>{};

    final slots = after.slotsByLevel.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final prepared = _newCantrips != null || _newSpells != null;

    // Lo que ya está preparado, a la vista: al volver del editor no se veía
    // qué había quedado, y un cupo libre pasaba sin que nadie lo notara. Los
    // concedidos por rasgos no ocupan cupo y no se cuentan.
    final updated = _buildUpdated();
    final granted = {
      ..._updatedSheet.alwaysPreparedSpellIds,
      for (final s in _updatedSheet.innateSpells) s.spellId,
    };
    final chosen = [
      for (final id in updated.spellIdsFor(
        targetBlock?.classId ?? updated.classId,
      ))
        if (!granted.contains(id)) ?widget.repo.spell(id),
    ];
    final chosenCantrips = [
      for (final id in updated.cantripIdsFor(
        targetBlock?.classId ?? updated.classId,
      ))
        if (!granted.contains(id)) ?widget.repo.spell(id),
    ];
    // Lo que falta sale de la misma regla que bloquea Continuar: con una
    // cuenta propia la pantalla decía «5 de 5 · Conjuros actualizados» y el
    // pie, en rojo, que faltaba un truco que acá no aparecía por ningún lado.
    final pending = _pendingClassSpells;
    final done = prepared && _classSpellsComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Eyebrow(context.l10n.luSpellsEyebrow(_newLevel)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final e in slots)
              _SlotBadge(
                level: e.key,
                count: e.value,
                isNew: !beforeLevels.contains(e.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            context.l10n.luPrepare(after.preparedCount),
            if (after.cantripsKnown > 0)
              context.l10n.luCantrips(after.cantripsKnown),
          ].join(' · '),
          style: TextStyle(color: muted, fontSize: 13),
        ),
        if (after.cantripsKnown > 0) ...[
          const SizedBox(height: 10),
          Text(
            context.l10n.luCantripsOf(
              chosenCantrips.length,
              after.cantripsKnown,
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (chosenCantrips.isNotEmpty)
            Text(
              chosenCantrips.map((s) => s.name).join(' · '),
              style: TextStyle(color: muted, fontSize: 13),
            ),
          if (pending.cantrips > 0)
            Text(
              context.l10n.luMissingCantrips(pending.cantrips),
              style: TextStyle(color: context.palette.gold, fontSize: 13),
            ),
        ],
        if (after.preparedCount > 0) ...[
          const SizedBox(height: 10),
          Text(
            context.l10n.luPreparedOf(chosen.length, after.preparedCount),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (chosen.isNotEmpty)
            Text(
              chosen.map((s) => s.name).join(' · '),
              style: TextStyle(color: muted, fontSize: 13),
            ),
          if (pending.prepared > 0)
            Text(
              context.l10n.luMissingPrepare(pending.prepared),
              style: TextStyle(color: context.palette.gold, fontSize: 13),
            ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openSpellPrep(after, classId: targetBlock?.classId),
          // La tilde solo cuando no falta nada: con «Conjuros actualizados» y
          // un truco pendiente, nadie volvía a abrir el editor.
          icon: Icon(done ? Icons.check : Icons.auto_stories, size: 18),
          label: Text(
            done ? context.l10n.luSpellsUpdated : context.l10n.luPrepareSpells,
          ),
        ),
      ],
    );
  }

  void _openSpellPrep(Spellcasting sc, {String? classId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpellEditScreen(
          character: _buildUpdated(),
          repo: widget.repo,
          spellcasting: sc,
          classId: classId,
          // La misma regla que la ficha (ver `Character.withClassSpells`),
          // sobre la ficha tal como va quedando en esta subida.
          onSave: (cantrips, spells) => _updateState(() {
            final updated = _buildUpdated().withClassSpells(
              classId ?? widget.character.classId,
              cantrips: cantrips,
              spells: spells,
            );
            _newCantrips = updated.cantripIds;
            _newSpells = updated.spellIds;
            _newClassCantrips = updated.classCantripIds;
            _newClassSpells = updated.classSpellIds;
          }),
        ),
      ),
    );
  }

  Widget _buildAsi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.luAsiAt(_newLevel)),
        SegmentedButton<_AsiKind>(
          segments: [
            ButtonSegment(
              value: _AsiKind.improve,
              label: Text(context.l10n.luImproveAbilities),
            ),
            ButtonSegment(
              value: _AsiKind.feat,
              label: Text(context.l10n.luTakeFeat),
            ),
          ],
          selected: {_asiKind},
          onSelectionChanged: (s) => _updateState(() => _asiKind = s.first),
        ),
        const SizedBox(height: 12),
        if (_asiKind == _AsiKind.improve)
          _buildImprove()
        else ...[
          _buildFeatPicker(),
          // Hay dotes que además de sus rasgos conceden "+1 a una
          // característica a tu elección": los dones épicos y las marcas
          // mayores. Aparece recién con la dote elegida, porque hasta entonces
          // no hay ningún +1 del que hablar.
          if (_featAbilityChoice case final aumento?) ...[
            const SizedBox(height: 22),
            Eyebrow(context.l10n.luFeatRaises(aumento.amount)),
            const SizedBox(height: 10),
            _buildAbilityGrid(_sheetBefore, _updatedSheet),
            // El techo solo se aclara cuando no es el de siempre: decir "hasta
            // 20" en una marca mayor sería ruido, porque es el techo normal.
            if (aumento.max != 20) ...[
              const SizedBox(height: 10),
              Text(
                context.l10n.luFeatCap(aumento.max),
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildImprove() {
    final before = _sheetBefore;
    final after = _updatedSheet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_ImproveMode>(
          segments: [
            ButtonSegment(
              value: _ImproveMode.plusTwo,
              label: Text(context.l10n.luPlusTwo),
            ),
            ButtonSegment(
              value: _ImproveMode.plusOneTwo,
              label: Text(context.l10n.luPlusOneTwo),
            ),
          ],
          selected: {_impMode},
          onSelectionChanged: (s) => _updateState(() {
            _impMode = s.first;
            _abilityB = null;
          }),
        ),
        const SizedBox(height: 14),
        _buildAbilityGrid(before, after),
        const SizedBox(height: 14),
        Text(
          _impMode == _ImproveMode.plusTwo
              ? context.l10n.luPickOneAbility
              : context.l10n.luPickTwoAbilities,
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// La grilla de las seis características, con el antes → después de cada una.
  /// La comparten la mejora normal y el +1 de una dote: es la misma decisión
  /// —a cuál va el aumento— y mostrarla distinta según de dónde viene el punto
  /// sería una diferencia sin motivo.
  Widget _buildAbilityGrid(ComputedSheet before, ComputedSheet after) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Un don puede acotar a qué característica va su +1.
            for (final ability in _featAbilityChoice?.allowed ?? Ability.values)
              SizedBox(
                width: width,
                child: _LevelUpCard(
                  icon: Icons.add_circle_outline,
                  title: ability.label,
                  body:
                      '${before.abilityScores[ability] ?? 0} → '
                      '${after.abilityScores[ability] ?? before.abilityScores[ability] ?? 0}',
                  tag: _abilityIncreases[ability] == null
                      ? 'SIN CAMBIOS'
                      : '+${_abilityIncreases[ability]}',
                  selected: _abilityIncreases.containsKey(ability),
                  onTap: () => _selectAbility(ability),
                ),
              ),
          ],
        );
      },
    );
  }

  void _selectAbility(Ability ability) {
    _updateState(() {
      // La dote concede un solo punto, así que siempre es selección
      // simple, sin importar en qué modo quedó el segmentado de la mejora.
      if (_featAbilityChoice != null || _impMode == _ImproveMode.plusTwo) {
        _abilityA = ability;
        _abilityB = null;
        return;
      }
      if (_abilityA == ability) {
        _abilityA = _abilityB;
        _abilityB = null;
      } else if (_abilityB == ability) {
        _abilityB = null;
      } else if (_abilityA == null) {
        _abilityA = ability;
      } else {
        _abilityB = ability;
      }
    });
  }

  Widget _buildFeatPicker() {
    // Los prerrequisitos se evalúan sobre el personaje tal como quedará al
    // nuevo nivel: las marcas mayores exigen nivel 4, y a nivel 3 el personaje
    // todavía no lo tiene aunque esté subiendo justo a ese nivel.
    final target = _buildUpdated(withFeat: false);
    final sheet = CharacterCompiler(widget.repo).compile(target);
    final validator = CharacterValidator(widget.repo);
    final held = validator.heldFeatIds(target);

    // No se puede repetir una dote ya tomada salvo que sea repetible (2024).
    // Se mide contra `held`, que incluye la dote de origen del trasfondo y el
    // estilo de combate, no solo `featIds`: con el catálogo oficial no hay
    // solapamiento porque acá solo se ofrecen dotes generales, pero un
    // trasfondo homebrew puede conceder cualquiera.
    final allFeats = widget.repo.featsSorted
        // Generales y dones épicos, que es lo que dice el rasgo de nivel 19:
        // "obtenés una dote de don épico u otra dote para la que cumplas las
        // condiciones". No hace falta gatear el nivel acá porque los trece
        // dones declaran `minLevel: 19` y el filtro de prerrequisitos de más
        // abajo los esconde solo.
        .where((f) => f.category == 'general' || f.category == 'epic-boon')
        // "Mejora de Característica" ya es la opción hermana de este
        // selector y necesita registrar sus puntuaciones, no un featId.
        .where((f) => f.id != 'ability-score-improvement')
        .where((f) => f.repeatable || !held.contains(f.id))
        .where((f) {
          final group = f.effectiveExclusiveGroup;
          return group == null ||
              !held.any(
                (id) =>
                    id != f.id &&
                    widget.repo.feat(id)?.effectiveExclusiveGroup == group,
              );
        })
        // Las reglas viven en el motor: la UI solo esconde lo inelegible.
        .where(
          (f) =>
              validator.unmetFeatPrerequisite(f, target, sheet, held: held) ==
              null,
        )
        // Ya viene alfabético de `featsSorted`: reordenar acá con
        // `compareTo` crudo desharía el plegado de tildes.
        .toList();
    if (allFeats.isEmpty) {
      return Text(
        context.l10n.luNoFeats,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final query = _featQuery.trim().toLowerCase();
    final feats = query.isEmpty
        ? allFeats
        : allFeats
              .where(
                (feat) =>
                    feat.name.toLowerCase().contains(query) ||
                    featSummary(
                      context.l10n,
                      feat,
                      widget.repo,
                    ).toLowerCase().contains(query),
              )
              .toList();
    final selected = _featId == null
        ? null
        : allFeats.where((f) => f.id == _featId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: context.l10n.luSearchFeat,
            hintText: context.l10n.luNameOrEffect,
            border: const OutlineInputBorder(),
            suffixText: context.l10n.luAvailable(feats.length),
          ),
          onChanged: (value) => _updateState(() => _featQuery = value),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final list = SizedBox(
              height: 410,
              child: feats.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.luNoFeatMatch(_featQuery),
                        style: TextStyle(color: context.palette.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: feats.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final feat = feats[index];
                        return _LevelUpCard(
                          icon: Icons.workspace_premium,
                          title: feat.name,
                          body: featSummary(context.l10n, feat, widget.repo),
                          selected: _featId == feat.id,
                          trailing: SourceBadge(feat.source),
                          onTap: () => _updateState(() {
                            _featId = feat.id;
                            // El +1 elegido para otro don puede no valer en
                            // este (Ataque Imparable solo sube FUE o DES).
                            final allowed = _featAbilityChoice?.allowed;
                            if (allowed != null &&
                                !allowed.contains(_abilityA)) {
                              _abilityA = null;
                            }
                          }),
                        );
                      },
                    ),
            );
            final detail = selected != null
                ? _FeatDetail(selected, widget.repo)
                : _LevelUpCard(
                    icon: Icons.touch_app,
                    title: context.l10n.luPickFeatTitle,
                    body: context.l10n.luPickFeatBody,
                  );
            if (!wide) {
              return Column(
                children: [list, const SizedBox(height: 14), detail],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: list),
                const SizedBox(width: 16),
                SizedBox(width: 320, child: detail),
              ],
            );
          },
        ),
      ],
    );
  }
}
