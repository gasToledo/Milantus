part of '../homebrew_screen.dart';

/// Formulario de armadura, con el mismo armazón que el de arma: arriba lo que
/// hace falta para guardarla —nombre, categoría y CA— y lo demás plegado.
///
/// Además de la fila de la lista, el panel muestra la CA que va a quedar en la
/// ficha con dos Destrezas de ejemplo: «tope +2» no dice nada hasta que se ve
/// que un personaje ágil se queda en 16.
class ArmorForm extends StatefulWidget {
  final Armor? initial;
  const ArmorForm({super.key, this.initial});
  @override
  State<ArmorForm> createState() => _ArmorFormState();
}

class _ArmorFormState extends State<ArmorForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late final _baseAc = watch('${widget.initial?.baseAc ?? 11}');
  late final _maxDex = watch(widget.initial?.maxDexBonus?.toString() ?? '');
  late final _strReq = watch(
    widget.initial?.strengthRequirement?.toString() ?? '',
  );
  late final _weight = watch(
    widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = watch('${widget.initial?.costCp ?? 0}');
  late String _category = widget.initial?.category ?? 'light';
  late bool _addDex = widget.initial?.addDexMod ?? true;
  late bool _stealth = widget.initial?.stealthDisadvantage ?? false;
  late final _description = watch(widget.initial?.description ?? '');

  /// Las Destrezas con las que el panel muestra la CA: una que pasa el tope
  /// del manual y una que no.
  static const _exampleDex = [3, 1];

  /// La armadura tal como está escrita. Mismo criterio que `_weapon`: un
  /// número a medio tipear cae en un defecto para la vista previa, y al
  /// guardar no llega porque el formulario valida antes.
  Armor _armor() => Armor(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    category: _category,
    baseAc: int.tryParse(_baseAc.text.trim()) ?? 0,
    addDexMod: _addDex,
    maxDexBonus: int.tryParse(_maxDex.text.trim()),
    strengthRequirement: int.tryParse(_strReq.text.trim()),
    stealthDisadvantage: _stealth,
    weight: double.tryParse(_weight.text.trim()) ?? 0,
    costCp: int.tryParse(_costCp.text.trim()) ?? 0,
    description: _description.text.trim(),
  );

  void _save() => Navigator.of(context).pop(_armor());

  /// Elegir la categoría trae la Destreza del manual: media hasta +2, pesada
  /// sin Destreza. Antes la categoría solo cambiaba la pill, y una armadura
  /// «Media» se guardaba con la Destreza entera de la ligera que venía por
  /// defecto: la ficha le daba 17 a un personaje con DES +3 donde el manual
  /// dice 16. Es un punto de partida y no un candado, porque el homebrew está
  /// para salirse del manual: después se ajusta en la sección de abajo. El
  /// escudo no toca nada, porque no suma Destreza.
  void _applyCategoryDex(String category) {
    switch (category) {
      case 'light':
        _addDex = true;
        _maxDex.text = '';
      case 'medium':
        _addDex = true;
        _maxDex.text = '2';
      case 'heavy':
        _addDex = false;
        _maxDex.text = '';
    }
  }

  bool get _shield => _category == 'shield';

  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'category':
        final rule = armorCategoryRules[_category];
        if (rule == null) return null;
        return _explained(
          context.l10n.codexCategory,
          _armorCategories(context.l10n)[_category] ?? _category,
          rule,
          armorTrainingRule,
        );
      case 'baseAc':
        return _explained(
          context.l10n.hbArmorBaseAc,
          _baseAc.text.trim().isEmpty
              ? context.l10n.hbNotFilled
              : _baseAc.text.trim(),
          _shield ? shieldBaseAcRule : armorBaseAcRule,
        );
      case 'addDex':
        return _explained(
          context.l10n.hbDexterity,
          _addDex ? context.l10n.hbAddsDex : context.l10n.hbNoDex,
          armorAddDexRule,
        );
      case 'maxDex':
        final cap = _maxDex.text.trim();
        return _explained(
          context.l10n.hbDexCap,
          cap.isEmpty ? context.l10n.hbNoCap : context.l10n.hbUpTo(cap),
          armorMaxDexRule,
        );
      case 'strength':
        final str = _strReq.text.trim();
        return _explained(
          context.l10n.hbDemand,
          str.isEmpty ? context.l10n.hbNoStrReq : context.l10n.hbStrength(str),
          armorStrengthRule,
        );
      case 'stealth':
        return _explained(
          context.l10n.hbDemand,
          _stealth
              ? context.l10n.hbStealthDisadv
              : context.l10n.hbNoStealthDisadv,
          armorStealthRule,
        );
    }
    return null;
  }

  @override
  Iterable<String> get chosenKeys => [
    'category',
    if (!_shield && _addDex && _maxDex.text.trim().isNotEmpty) 'maxDex',
    if (_strReq.text.trim().isNotEmpty) 'strength',
    if (_stealth) 'stealth',
  ];

  String get _dexSummary {
    if (!_addDex) return context.l10n.hbNoDexLower;
    final cap = _maxDex.text.trim();
    return cap.isEmpty ? context.l10n.hbFullDex : context.l10n.hbUpToLower(cap);
  }

  String get _demandsSummary {
    final str = _strReq.text.trim();
    final parts = [
      if (str.isNotEmpty) context.l10n.hbStrength(str),
      if (_stealth) context.l10n.hbStealthDisadv,
    ];
    return parts.isEmpty ? context.l10n.hbNone : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final armor = _armor();
    return _FormScaffold(
      title: context.l10n.kindArmor,
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: context.l10n.hbPreviewTitle,
        preview: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _rowPreview(
              armor.name,
              pills: _armorPills(context.l10n, armor),
              stats: _armorStats(context.l10n, armor),
            ),
            // Un escudo no tiene una CA propia que mostrar: suma a la otra.
            if (!armor.isShield) ...[
              const SizedBox(height: 14),
              Eyebrow(context.l10n.hbOnSheet),
              _statBand(context, [
                for (final dex in _exampleDex)
                  (
                    context.l10n.hbAcWithDex(dex),
                    '${armor.armorClassFor(dex)}',
                  ),
              ], wide: false),
            ],
          ],
        ),
        hint: context.l10n.hbArmorHint,
      ),
      children: [
        _text(
          _name,
          context.l10n.detailsName,
          validator: (v) => _requiredText(v, context.l10n.hbReqArmorName),
        ),
        _fieldRow(
          flex: const [3, 2],
          [
            _categoryDropdown(
              _armorCategories(context.l10n),
              _category,
              (v) => setState(() {
                _category = v;
                _applyCategoryDex(v);
                focus = 'category';
              }),
              onTap: () => focusOn('category'),
            ),
            _text(
              _baseAc,
              _shield ? context.l10n.hbShieldAc : context.l10n.hbArmorBaseAc,
              number: true,
              validator: (v) =>
                  _intInRange(context.l10n, v, 1, 30, optional: false),
              onTap: () => focusOn('baseAc'),
            ),
          ],
        ),
        explainHere((f) => f == 'category' || f == 'baseAc'),
        ..._optionalRule,
        // Un escudo no suma Destreza: la sección solo confundiría. Lo que
        // traiga guardado igual se conserva, porque el estado no se toca.
        if (!_shield)
          section(
            icon: Icons.directions_run,
            title: context.l10n.hbHowDex,
            summary: _dexSummary,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.hbAddsDexMod),
                value: _addDex,
                onChanged: (v) => setState(() {
                  _addDex = v;
                  focus = 'addDex';
                }),
              ),
              if (_addDex)
                _text(
                  _maxDex,
                  context.l10n.hbDexCapLabel,
                  number: true,
                  validator: (v) =>
                      _intInRange(context.l10n, v, 0, 10, optional: true),
                  onTap: () => focusOn('maxDex'),
                ),
              explainHere((f) => f == 'addDex' || f == 'maxDex'),
            ],
          ),
        section(
          icon: Icons.fitness_center,
          title: context.l10n.hbDemands,
          summary: _demandsSummary,
          children: [
            _text(
              _strReq,
              context.l10n.hbStrReqLabel,
              number: true,
              validator: (v) =>
                  _intInRange(context.l10n, v, 1, 30, optional: true),
              onTap: () => focusOn('strength'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.hbStealthLabel),
              value: _stealth,
              onChanged: (v) => setState(() {
                _stealth = v;
                focus = 'stealth';
              }),
            ),
            explainHere((f) => f == 'strength' || f == 'stealth'),
          ],
        ),
        _economySection(this, _weight, _costCp),
        _legendSection(this, _description, context.l10n.hbLegendArmor),
      ],
    );
  }
}

/// Las pills de una armadura en la lista y en la vista previa del formulario.
List<String> _armorPills(AppLocalizations l10n, Armor a) => [
  _armorCategories(l10n)[a.category] ?? a.category,
  if (a.stealthDisadvantage) l10n.hbStealthDisadv,
];

/// Las cifras de una armadura, con el mismo motivo que [_armorPills].
List<(String, String)> _armorStats(AppLocalizations l10n, Armor a) => [
  (l10n.creatureAcShort, a.isShield ? '+${a.baseAc}' : '${a.baseAc}'),
  if (a.weight > 0) (l10n.codexWeight, '${formatPounds(a.weight)} lb'),
  if (a.costCp > 0) (l10n.codexPrice, formatCost(a.costCp)),
];
