part of '../homebrew_screen.dart';

/// Formulario de arma: arriba lo que hace falta para guardar un arma usable
/// —nombre, categoría, dado y tipo de daño— y el resto en secciones plegadas.
///
/// Al costado van la fila tal como va a quedar en la lista y la explicación de
/// lo que se está tocando. Quien arma su primera arma no sabe qué hace «Sutil»
/// ni «Derribar», y ese es el momento de decírselo. En una pantalla angosta no
/// hay panel: la explicación aparece debajo del campo.
///
/// El alcance va en Propiedades y aparece con «A distancia» o «Arrojadiza»
/// marcadas: sin una de las dos, el arma no ataca desde lejos y los dos
/// números no significan nada.
class WeaponForm extends StatefulWidget {
  final Weapon? initial;
  const WeaponForm({super.key, this.initial});
  @override
  State<WeaponForm> createState() => _WeaponFormState();
}

class _WeaponFormState extends State<WeaponForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late final _dice = watch(widget.initial?.damageDice ?? '1d6');
  late String _type = widget.initial?.damageType ?? DamageType.slashing.id;
  late final _versatile = watch(widget.initial?.versatileDice ?? '');
  late String _mastery = widget.initial?.mastery ?? '';
  late final _weight = watch(
    widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = watch('${widget.initial?.costCp ?? 0}');
  late final _magicBonus = watch('${widget.initial?.magicBonus ?? 0}');
  late String _category = widget.initial?.category ?? 'simple';
  late final Set<String> _props = {...?widget.initial?.properties};
  late final _description = watch(widget.initial?.description ?? '');
  late final _rangeNormal = watch(_rangeText(widget.initial?.rangeNormal));
  late final _rangeLong = watch(_rangeText(widget.initial?.rangeLong));

  /// 0 es «sin alcance» en el modelo, y en el campo se lee mejor vacío.
  static String _rangeText(int? feet) =>
      feet == null || feet <= 0 ? '' : '$feet';

  /// Con alguna de las dos propiedades el arma ataca desde lejos, y entonces
  /// el alcance es obligatorio: un arco sin alcance no tiene a quién pegarle.
  bool get _needsRange =>
      _props.contains('ranged') || _props.contains('thrown');

  String? _rangeLongValue(String? value) {
    final error = _intInRange(
      context.l10n,
      value,
      5,
      1000,
      optional: !_needsRange,
    );
    if (error != null) return error;
    final normal = int.tryParse(_rangeNormal.text.trim());
    final long = int.tryParse((value ?? '').trim());
    return normal != null && long != null && long < normal
        ? context.l10n.hbRangeLongMin
        : null;
  }

  /// El arma tal como está escrita.
  ///
  /// La vista previa la pide en cada tecla, así que un número a medio tipear
  /// cae en 0 en vez de romper. Al guardar ese caso no llega: [_FormScaffold]
  /// valida antes de llamar a [_save].
  Weapon _weapon() => Weapon(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    category: _category,
    damageDice: _dice.text.trim(),
    damageType: _type,
    properties: _props.toList(),
    // Lo que el formulario no muestra se conserva del original, para que
    // editar —o duplicar— un arma del catálogo no le cambie la regla.
    twoHandedUnlessMounted: widget.initial?.twoHandedUnlessMounted ?? false,
    rangeNormal: int.tryParse(_rangeNormal.text.trim()) ?? 0,
    rangeLong: int.tryParse(_rangeLong.text.trim()) ?? 0,
    versatileDice: _versatile.text.trim().isEmpty
        ? null
        : _versatile.text.trim(),
    mastery: _mastery.isEmpty ? null : _mastery,
    weight: double.tryParse(_weight.text.trim()) ?? 0,
    costCp: int.tryParse(_costCp.text.trim()) ?? 0,
    magicBonus: int.tryParse(_magicBonus.text.trim()) ?? 0,
    description: _description.text.trim(),
  );

  void _save() => Navigator.of(context).pop(_weapon());

  /// Claves: `category`, `type`, `mastery` o `prop:<id>`.
  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'category':
        final rule = weaponCategoryRules[_category];
        if (rule == null) return null;
        return _explained(
          context.l10n.codexCategory,
          _weaponCategories(context.l10n)[_category] ?? _category,
          rule,
        );
      case 'type':
        final type = DamageType.fromId(_type);
        if (type == null) return null;
        return _explained(
          context.l10n.hbDamageType,
          type.label,
          type.description,
          damageTypeRule,
        );
      case 'mastery':
        if (_mastery.isEmpty) {
          return _explained(
            context.l10n.codexMastery,
            context.l10n.hbNoMastery,
            context.l10n.hbNoMasteryRule,
          );
        }
        final mastery = weaponMasteries[_mastery];
        if (mastery == null) return null;
        return _explained(
          context.l10n.codexMastery,
          mastery.name,
          mastery.description,
          weaponMasteryRule,
        );
      case 'range':
        final normal = _rangeNormal.text.trim();
        final long = _rangeLong.text.trim();
        return _explained(
          context.l10n.commonRange,
          normal.isEmpty
              ? context.l10n.hbNoRange
              : context.l10n.hbRangeFeet(normal, long),
          weaponRangeRule,
        );
    }
    final property = weaponProperties[key.substring('prop:'.length)];
    if (property == null) return null;
    return _explained(
      context.l10n.hbProperty,
      property.name,
      property.description,
    );
  }

  @override
  Iterable<String> get chosenKeys => [
    'category',
    'type',
    if (_mastery.isNotEmpty) 'mastery',
    for (final p in weaponProperties.keys)
      if (_props.contains(p)) 'prop:$p',
  ];

  String get _propertiesSummary {
    final names = [
      for (final p in weaponProperties.values)
        if (_props.contains(p.id)) p.name,
    ];
    return names.isEmpty ? context.l10n.hbNone : names.join(', ');
  }

  String get _masterySummary {
    final bonus = int.tryParse(_magicBonus.text.trim()) ?? 0;
    return [
      _mastery.isEmpty
          ? context.l10n.hbNoMasteryLower
          : weaponMasteryName(_mastery),
      if (bonus != 0) '+$bonus',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final weapon = _weapon();
    return _FormScaffold(
      title: context.l10n.kindWeapon,
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: context.l10n.hbPreviewTitle,
        preview: _rowPreview(
          weapon.name,
          pills: _weaponPills(context.l10n, weapon),
          stats: _weaponStats(context.l10n, weapon),
        ),
        hint: context.l10n.hbWeaponHint,
      ),
      children: [
        _text(
          _name,
          context.l10n.detailsName,
          validator: (v) => _requiredText(v, context.l10n.hbReqWeaponName),
        ),
        _fieldRow(
          flex: const [3, 2, 3],
          [
            _categoryDropdown(
              _weaponCategories(context.l10n),
              _category,
              (v) => setState(() {
                _category = v;
                focus = 'category';
              }),
              onTap: () => focusOn('category'),
            ),
            _text(
              _dice,
              context.l10n.hbDamageDie,
              validator: (v) => _diceValue(context.l10n, v, optional: false),
            ),
            _damageTypeDropdown(
              _type,
              (v) => setState(() {
                _type = v;
                focus = 'type';
              }),
              onTap: () => focusOn('type'),
            ),
          ],
        ),
        explainHere((f) => f == 'category' || f == 'type'),
        ..._optionalRule,
        section(
          icon: Icons.tune,
          title: context.l10n.codexProperties,
          summary: _propertiesSummary,
          children: [
            _idChips(
              _weaponPropOptions,
              _props,
              redraw,
              onTap: (id) => focus = 'prop:$id',
            ),
            // A dos manos, el dado versátil reemplaza al normal: sin la
            // propiedad no significa nada. Si el arma ya trae uno se muestra
            // igual, para que nunca quede un valor guardado sin verse.
            if (_props.contains('versatile') ||
                _versatile.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _text(
                _versatile,
                context.l10n.hbVersatile,
                validator: (v) => _diceValue(context.l10n, v, optional: true),
              ),
            ],
            // Mismo criterio que el dado versátil: un alcance ya cargado se
            // sigue viendo aunque se desmarque la propiedad.
            if (_needsRange ||
                _rangeNormal.text.trim().isNotEmpty ||
                _rangeLong.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _fieldRow([
                _text(
                  _rangeNormal,
                  context.l10n.hbRangeNormal,
                  number: true,
                  validator: (v) => _intInRange(
                    context.l10n,
                    v,
                    5,
                    1000,
                    optional: !_needsRange,
                  ),
                  onTap: () => focusOn('range'),
                ),
                _text(
                  _rangeLong,
                  context.l10n.hbRangeLong,
                  number: true,
                  validator: _rangeLongValue,
                  onTap: () => focusOn('range'),
                ),
              ]),
            ],
            explainHere((f) => f.startsWith('prop:') || f == 'range'),
          ],
        ),
        section(
          icon: Icons.auto_awesome,
          title: context.l10n.hbMasteryMagic,
          summary: _masterySummary,
          children: [
            _fieldRow(
              flex: const [3, 2],
              [
                _idDropdown(
                  label: context.l10n.codexMastery,
                  value: _mastery,
                  options: _masteryOptions(context.l10n),
                  onChanged: (v) => setState(() {
                    _mastery = v;
                    focus = 'mastery';
                  }),
                  onTap: () => focusOn('mastery'),
                ),
                _text(
                  _magicBonus,
                  context.l10n.hbMagicBonus,
                  number: true,
                  validator: (v) =>
                      _intInRange(context.l10n, v, 0, 3, optional: false),
                ),
              ],
            ),
            explainHere((f) => f == 'mastery'),
          ],
        ),
        _economySection(this, _weight, _costCp),
        _legendSection(this, _description, context.l10n.hbLegendWeapon),
      ],
    );
  }
}

/// Peso y precio, que arma, armadura y objeto piden igual.
Widget _economySection(
  _GuidedForm form,
  TextEditingController weight,
  TextEditingController costCp,
) {
  final w = double.tryParse(weight.text.trim()) ?? 0;
  final cost = int.tryParse(costCp.text.trim()) ?? 0;
  return form.section(
    icon: Icons.paid_outlined,
    title: form.context.l10n.hbEconomy,
    summary: w <= 0 && cost <= 0
        ? form.context.l10n.hbNotSet
        : [
            if (w > 0) '${formatPounds(w)} lb',
            if (cost > 0) form.context.l10n.cost(cost),
          ].join(' · '),
    children: [
      _fieldRow([
        _text(
          weight,
          form.context.l10n.hbWeightLabel,
          number: true,
          validator: (v) => _weightValue(form.context.l10n, v),
        ),
        _text(
          costCp,
          form.context.l10n.hbPriceLabel,
          number: true,
          validator: (v) =>
              _intInRange(form.context.l10n, v, 0, 100000000, optional: false),
        ),
      ]),
    ],
  );
}

/// El texto libre al final de arma y armadura.
Widget _legendSection(
  _GuidedForm form,
  TextEditingController description,
  String what,
) => form.section(
  icon: Icons.menu_book_outlined,
  title: form.context.l10n.hbLegend,
  summary: description.text.trim().isEmpty
      ? form.context.l10n.hbNotSet
      : form.context.l10n.hbLoaded,
  children: [_text(description, what, maxLines: 5)],
);

/// Las pills de un arma en la lista. Las comparten la lista y la vista previa
/// del formulario: si se separaran, la vista previa mostraría otra fila.
List<String> _weaponPills(AppLocalizations l10n, Weapon w) => [
  _weaponCategories(l10n)[w.category] ?? w.category,
  DamageType.labelFor(w.damageType),
  if (w.magicBonus != 0) '+${w.magicBonus}',
  for (final property in w.properties) _weaponPropOptions[property] ?? property,
];

/// Las cifras de un arma en la lista, con el mismo motivo que [_weaponPills].
List<(String, String)> _weaponStats(AppLocalizations l10n, Weapon w) => [
  (
    l10n.creatureDamage,
    w.versatileDice == null
        ? w.damageDice
        : '${w.damageDice} / ${w.versatileDice}',
  ),
  if (w.rangeNormal > 0)
    (
      l10n.commonRange,
      w.rangeLong > w.rangeNormal
          ? '${w.rangeNormal}/${w.rangeLong}'
          : '${w.rangeNormal}',
    ),
  if (w.weight > 0) (l10n.codexWeight, '${formatPounds(w.weight)} lb'),
  if (w.costCp > 0) (l10n.codexPrice, l10n.cost(w.costCp)),
];
