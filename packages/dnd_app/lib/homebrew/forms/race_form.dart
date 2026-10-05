part of '../homebrew_screen.dart';

/// Formulario de especie: arriba lo que se lee en la tarjeta al crear un
/// personaje —tipo, tamaño y velocidad— y lo demás plegado.
///
/// Suma lo que antes solo se conservaba: el lema, entre qué habilidades se
/// elige y los tamaños a elegir. Una especie propia sin eso ofrecía las 18
/// habilidades y un solo tamaño aunque su historia dijera otra cosa.
class RaceForm extends StatefulWidget {
  final Race? initial;

  /// Ver [FeatForm.repo].
  final ContentRepository repo;
  const RaceForm({super.key, required this.repo, this.initial});
  @override
  State<RaceForm> createState() => _RaceFormState();
}

class _RaceFormState extends State<RaceForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  // l10n-ignore: el tamaño por defecto es el valor guardado (`Race.size`), no texto.
  late String _size = widget.initial?.size ?? 'Mediano';
  // l10n-ignore: tipo de criatura por defecto, el valor guardado en español (se muestra con `vocabularyLabel`).
  late final _creatureType = watch(widget.initial?.creatureType ?? 'Humanoide');
  late final _tagline = watch(widget.initial?.tagline ?? '');
  late final _description = watch(widget.initial?.description ?? '');
  late final _speed = watch('${widget.initial?.speed ?? 30}');
  late final _skillCount = watch('${widget.initial?.skillChoiceCount ?? 0}');
  late final Set<String> _skillFrom = {...?widget.initial?.skillChoiceFrom};
  late final Set<String> _sizeOptions = {...?widget.initial?.sizeOptions};
  late final List<Effect> _effects = [...?widget.initial?.effects];

  int get _skillCountValue => int.tryParse(_skillCount.text.trim()) ?? 0;

  Race _race() => Race(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    creatureType: _creatureType.text.trim(),
    description: _description.text.trim(),
    tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
    size: _size,
    // Con un solo tamaño marcado no hay nada que elegir, y la creación
    // mostraría una elección de una opción: vale el tamaño de arriba.
    sizeOptions: _sizeOptions.length < 2
        ? const []
        : [
            for (final s in _raceSizes(context.l10n).keys)
              if (_sizeOptions.contains(s)) s,
          ],
    skillChoiceFrom: _skillFrom.toList(),
    // El emblema no se edita acá: se conserva el del original.
    iconId: widget.initial?.iconId,
    speed: int.tryParse(_speed.text.trim()) ?? 0,
    skillChoiceCount: _skillCountValue,
    effects: _effects,
  );

  void _save() => Navigator.of(context).pop(_race());

  @override
  _Explained? explain(String key) => switch (key) {
    'type' => _explained(
      context.l10n.identityCreatureType,
      _creatureType.text.trim().isEmpty
          ? context.l10n.hbNoType
          : _creatureType.text.trim(),
      raceCreatureTypeRule,
    ),
    'size' => switch (raceSizeRules[_size]) {
      final rule? => _explained(
        context.l10n.identitySize,
        _raceSizes(context.l10n)[_size] ?? _size,
        rule,
        sizeRule,
      ),
      null => null,
    },
    'speed' => _explained(
      context.l10n.creatureSpeed,
      context.l10n.feetValue(_speed.text.trim()),
      raceSpeedRule,
    ),
    'skillCount' => _explained(
      context.l10n.creatureSkills,
      context.l10n.factChoose(_skillCountValue),
      raceSkillCountRule,
      skillProficiencyRule,
    ),
    'skillFrom' => _explained(
      context.l10n.creatureSkills,
      context.l10n.hbAmongWhichChooses,
      raceSkillFromRule,
    ),
    'sizeOptions' => _explained(
      context.l10n.identitySize,
      context.l10n.hbSizeToChoose,
      raceSizeOptionsRule,
    ),
    _ => null,
  };

  @override
  Iterable<String> get chosenKeys => [
    'type',
    'size',
    'speed',
    if (_skillCountValue > 0) 'skillCount',
    if (_skillFrom.isNotEmpty) 'skillFrom',
    if (_sizeOptions.length > 1) 'sizeOptions',
  ];

  String get _skillsSummary {
    final count = _skillCountValue;
    if (count <= 0) return context.l10n.hbNone;
    return _skillFrom.isEmpty
        ? context.l10n.hbAmongAll(count)
        : context.l10n.hbAmongN(count, _skillFrom.length);
  }

  @override
  Widget build(BuildContext context) {
    final race = _race();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _FormScaffold(
      title: context.l10n.stepSpecies,
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: context.l10n.hbRacePreview,
        preview: DenseRows(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _previewName(context, race.name, size: 18),
                  if (race.tagline case final tagline?)
                    Text(tagline, style: TextStyle(color: muted)),
                  const SizedBox(height: 10),
                  _statBand(context, [
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
                          : context.l10n.factToChoose,
                    ),
                    (
                      context.l10n.creatureSpeed,
                      context.l10n.feetValue(race.speed),
                    ),
                    if (race.skillChoiceCount > 0)
                      (
                        context.l10n.creatureSkills,
                        context.l10n.factChoose(race.skillChoiceCount),
                      ),
                  ], wide: false),
                  if (race.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(race.description),
                  ],
                  const SizedBox(height: 12),
                  Eyebrow(context.l10n.creatureTraits),
                  ..._traitsPreview(context, race.effects, widget.repo),
                ],
              ),
            ),
          ],
        ),
        hint: context.l10n.hbRaceHint,
      ),
      children: [
        _text(
          _name,
          context.l10n.detailsName,
          validator: (v) => _requiredText(v, context.l10n.hbReqRaceName),
        ),
        _fieldRow(
          flex: const [3, 2, 2],
          [
            _text(
              _creatureType,
              context.l10n.identityCreatureType,
              onTap: () => focusOn('type'),
            ),
            // Tamaño es un valor cerrado: escribirlo a mano dejaba pasar un
            // "mediano" en minúscula que el resto del motor no reconoce.
            _idDropdown(
              label: context.l10n.identitySize,
              value: _size,
              options: _raceSizes(context.l10n),
              onChanged: (v) => setState(() {
                _size = v;
                focus = 'size';
              }),
              onTap: () => focusOn('size'),
            ),
            _text(
              _speed,
              context.l10n.hbSpeedFeet,
              number: true,
              validator: (v) =>
                  _intInRange(context.l10n, v, 0, 120, optional: false),
              onTap: () => focusOn('speed'),
            ),
          ],
        ),
        explainHere((f) => f == 'type' || f == 'size' || f == 'speed'),
        ..._optionalRule,
        section(
          icon: Icons.menu_book_outlined,
          title: context.l10n.hbPresentation,
          summary: _orNone([
            if (_tagline.text.trim().isNotEmpty) context.l10n.hbTaglineLower,
            if (_description.text.trim().isNotEmpty)
              context.l10n.hbDescriptionLower,
          ], context.l10n.hbNotSet),
          children: [
            _text(_tagline, context.l10n.hbTaglineLabel),
            _text(_description, context.l10n.hbDescription, maxLines: 5),
          ],
        ),
        section(
          icon: Icons.school_outlined,
          title: context.l10n.creatureSkills,
          summary: _skillsSummary,
          children: [
            _text(
              _skillCount,
              context.l10n.hbHowMany,
              number: true,
              validator: (v) =>
                  _intInRange(context.l10n, v, 0, 18, optional: false),
              onTap: () => focusOn('skillCount'),
            ),
            if (_skillCountValue > 0 || _skillFrom.isNotEmpty) ...[
              const SizedBox(height: 6),
              Eyebrow(context.l10n.hbAmongWhich),
              _idChips(
                _skillOptions,
                _skillFrom,
                redraw,
                onTap: (_) => focus = 'skillFrom',
              ),
            ],
            explainHere((f) => f == 'skillCount' || f == 'skillFrom'),
          ],
        ),
        section(
          icon: Icons.height,
          title: context.l10n.hbSizeToChoose,
          summary: _sizeOptions.length < 2
              ? context.l10n.hbOnlySize(
                  _raceSizes(context.l10n)[_size] ?? _size,
                )
              : [
                  for (final s in _raceSizes(context.l10n).keys)
                    if (_sizeOptions.contains(s)) _raceSizes(context.l10n)[s]!,
                ].join(' ${context.l10n.wordOr} '),
          children: [
            _idChips(
              _raceSizes(context.l10n),
              _sizeOptions,
              redraw,
              onTap: (_) => focus = 'sizeOptions',
            ),
            explainHere((f) => f == 'sizeOptions'),
          ],
        ),
        section(
          icon: Icons.auto_awesome,
          title: context.l10n.creatureTraits,
          summary: _effectsSummary(context.l10n, _effects),
          children: [
            EffectEditor(
              effects: _effects,
              repo: widget.repo,
              onChanged: redraw,
            ),
          ],
        ),
      ],
    );
  }
}
