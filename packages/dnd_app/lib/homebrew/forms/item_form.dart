part of '../homebrew_screen.dart';

/// Formulario de objeto homebrew: arriba nombre, categoría, peso y precio, que
/// es todo lo que necesita un objeto mundano, y lo mágico plegado.
///
/// No valida colisión de id contra armas y armaduras: `homebrewId` arma
/// `hb-<slug>-<timestamp>`, así que un id de acá no puede pisar uno del
/// catálogo oficial ni otro homebrew.
///
/// ponytail: las cargas no se editan, solo se conservan del original. Van en
/// su propia sección cuando alguien arme una varita propia.
class ItemForm extends StatefulWidget {
  final Item? initial;

  /// Para ofrecer las bases permitidas por su nombre. Es la única cosa del
  /// formulario que sale del catálogo y no de lo que se escribe.
  final ContentRepository repo;

  const ItemForm({super.key, required this.repo, this.initial});

  @override
  State<ItemForm> createState() => _ItemFormState();
}

Map<String, String> _baseItemKinds(AppLocalizations l10n) => {
  'none': l10n.hbNoneCap,
  'weapon': l10n.kindWeapon,
  'armor': l10n.kindArmor,
  'shield': l10n.kindShield,
};

class _ItemFormState extends State<ItemForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late final _weight = watch(
    widget.initial == null ? '0' : '${widget.initial!.weight}',
  );
  late final _costCp = watch('${widget.initial?.costCp ?? 0}');
  late final _description = watch(widget.initial?.description ?? '');
  late final _acBonus = watch('${_initialAcBonus(widget.initial)}');
  late final _magicBonus = watch('${widget.initial?.magicBonus ?? 0}');
  late final Set<String> _eligibleBases = {
    ...?widget.initial?.eligibleBaseItemIds,
  };
  late String _category = widget.initial?.category ?? 'gear';
  late String? _rarity = widget.initial?.rarity;
  late bool _attunement = widget.initial?.requiresAttunement ?? false;
  late String _baseItemKind = widget.initial?.baseItemKind ?? 'none';
  late final Set<String> _resistances = {
    for (final e in widget.initial?.effects ?? const <Effect>[])
      if (e is ResistanceEffect) e.damageType,
  };

  /// Los efectos que no son CA ni resistencia: se editan con el editor de las
  /// dotes. Antes solo se conservaban, y no había forma de armar una Capa de
  /// protección (salvaciones) ni unos Guanteletes de fuerza de ogro (fijar la
  /// Fuerza) sin escribir el JSON.
  late final List<Effect> _otherEffects = [
    ...?widget.initial?.effects.where(
      (e) => e is! ArmorClassBonusEffect && e is! ResistanceEffect,
    ),
  ];

  static int _initialAcBonus(Item? item) {
    for (final e in item?.effects ?? const <Effect>[]) {
      if (e is ArmorClassBonusEffect) return e.amount;
    }
    return 0;
  }

  int get _acBonusValue => int.tryParse(_acBonus.text.trim()) ?? 0;
  int get _magicBonusValue => int.tryParse(_magicBonus.text.trim()) ?? 0;

  Item _item() => Item(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    category: _category,
    weight: double.tryParse(_weight.text.trim()) ?? 0,
    costCp: int.tryParse(_costCp.text.trim()) ?? 0,
    bundleSize: widget.initial?.bundleSize ?? 1,
    description: _description.text.trim(),
    rarity: _rarity,
    requiresAttunement: _attunement,
    magicBonus: _magicBonusValue,
    baseItemKind: _baseItemKind == 'none' ? null : _baseItemKind,
    eligibleBaseItemIds: _eligibleBases.toList(),
    // Las cargas no se editan acá, pero un objeto del catálogo que las
    // tiene deja de ser el mismo objeto sin ellas.
    maxCharges: widget.initial?.maxCharges,
    rechargeAmount: widget.initial?.rechargeAmount,
    effects: [
      if (_acBonusValue != 0) ArmorClassBonusEffect(_acBonusValue),
      for (final type in _resistances) ResistanceEffect(type),
      ..._otherEffects,
    ],
  );

  void _save() => Navigator.of(context).pop(_item());

  /// Claves: `category`, `rarity`, `attunement`, `acBonus`, `res:<tipo>`,
  /// `base` y `magicBonus`.
  @override
  _Explained? explain(String key) {
    switch (key) {
      case 'category':
        final rule = itemCategoryRules[_category];
        if (rule == null) return null;
        return _explained(
          context.l10n.codexCategory,
          _itemCategories(context.l10n)[_category] ?? _category,
          rule,
          itemCategoryNote,
        );
      case 'rarity':
        final rarity = _rarity;
        return rarity == null
            ? _explained(
                context.l10n.codexRarity,
                context.l10n.hbMundane,
                itemMundaneRule,
              )
            : _explained(
                context.l10n.codexRarity,
                _itemRarities(context.l10n)[rarity] ?? rarity,
                itemRarityRule,
              );
      case 'attunement':
        return _explained(
          context.l10n.hbMagic,
          _attunement
              ? context.l10n.codexAttunement
              : context.l10n.hbNoAttunement,
          itemAttunementRule,
        );
      case 'acBonus':
        return _explained(
          context.l10n.hbEffect,
          context.l10n.acValue(_signed(_acBonusValue)),
          itemAcBonusRule,
        );
      case 'base':
        return _explained(
          context.l10n.hbBaseItem,
          _baseItemKinds(context.l10n)[_baseItemKind] ?? _baseItemKind,
          itemBaseRule,
        );
      case 'magicBonus':
        return _explained(
          context.l10n.hbBaseItem,
          context.l10n.hbBonusValue(_signed(_magicBonusValue)),
          itemMagicBonusRule,
        );
    }
    final type = key.substring('res:'.length);
    return _explained(
      context.l10n.hbEffect,
      context.l10n.effectResistance(DamageType.labelFor(type)),
      itemResistanceRule,
      DamageType.fromId(type)?.description,
    );
  }

  @override
  Iterable<String> get chosenKeys => [
    'category',
    if (_rarity != null) 'rarity',
    if (_attunement) 'attunement',
    if (_acBonusValue != 0) 'acBonus',
    for (final id in _damageTypeOptions.keys)
      if (_resistances.contains(id)) 'res:$id',
    if (_baseItemKind != 'none') 'base',
    if (_magicBonusValue != 0) 'magicBonus',
  ];

  String get _effectsSummary => _orNone([
    if (_acBonusValue != 0) context.l10n.acValue(_signed(_acBonusValue)),
    for (final MapEntry(key: id, value: label) in _damageTypeOptions.entries)
      if (_resistances.contains(id)) context.l10n.effectResistance(label),
    if (_otherEffects.isNotEmpty)
      context.l10n.hbMoreEffects(_otherEffects.length),
  ], context.l10n.hbNoneM);

  @override
  Widget build(BuildContext context) {
    final item = _item();
    return _FormScaffold(
      title: context.l10n.hbItem,
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: context.l10n.hbPreviewTitle,
        preview: _rowPreview(
          item.name,
          pills: _itemPills(context.l10n, item),
          stats: _itemStats(context.l10n, item),
        ),
        hint: context.l10n.hbItemHint,
      ),
      children: [
        _text(
          _name,
          context.l10n.detailsName,
          validator: (v) => _requiredText(v, context.l10n.hbReqItemName),
        ),
        _fieldRow(
          flex: const [3, 2, 2],
          [
            _categoryDropdown(
              _itemCategories(context.l10n),
              _category,
              (v) => setState(() {
                _category = v;
                focus = 'category';
              }),
              onTap: () => focusOn('category'),
            ),
            _text(
              _weight,
              context.l10n.hbWeightShort,
              number: true,
              validator: (v) => _weightValue(context.l10n, v),
            ),
            _text(
              _costCp,
              context.l10n.hbPriceCp,
              number: true,
              validator: (v) =>
                  _intInRange(context.l10n, v, 0, 100000000, optional: false),
            ),
          ],
        ),
        explainHere((f) => f == 'category'),
        ..._optionalRule,
        section(
          icon: Icons.auto_awesome,
          title: context.l10n.hbMagic,
          summary: _orNone([
            if (_rarity != null)
              _itemRarities(context.l10n)[_rarity] ?? _rarity!,
            if (_attunement) context.l10n.catalogAttunement,
          ], context.l10n.hbMundaneLower),
          children: [
            _idDropdown(
              label: context.l10n.codexRarity,
              value: _rarity ?? _mundane,
              options: _itemRarities(context.l10n),
              onChanged: (v) => setState(() {
                _rarity = v == _mundane ? null : v;
                focus = 'rarity';
                // Sin rareza no hay objeto mágico, y un objeto mundano no se
                // sintoniza: dejar el interruptor prendido guardaría una
                // combinación que el motor considera inválida.
                if (_rarity == null) _attunement = false;
              }),
              onTap: () => focusOn('rarity'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.hbRequiresAttunement),
              subtitle: _rarity == null
                  ? Text(context.l10n.hbOnlyMagicAttune)
                  : null,
              value: _attunement,
              onChanged: _rarity == null
                  ? null
                  : (v) => setState(() {
                      _attunement = v;
                      focus = 'attunement';
                    }),
            ),
            explainHere((f) => f == 'rarity' || f == 'attunement'),
          ],
        ),
        section(
          icon: Icons.shield_outlined,
          title: context.l10n.hbEffectsEquipped,
          summary: _effectsSummary,
          children: [
            _text(
              _acBonus,
              context.l10n.hbAcBonusLabel,
              number: true,
              validator: (v) =>
                  _intInRange(context.l10n, v, -5, 10, optional: false),
              onTap: () => focusOn('acBonus'),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.hbResistances),
            const SizedBox(height: 6),
            _idChips(
              _damageTypeOptions,
              _resistances,
              redraw,
              onTap: (id) => focus = 'res:$id',
            ),
            explainHere((f) => f == 'acBonus' || f.startsWith('res:')),
            const SizedBox(height: 12),
            Text(context.l10n.hbOtherEffects),
            const SizedBox(height: 6),
            EffectEditor(
              effects: _otherEffects,
              repo: widget.repo,
              onChanged: redraw,
              hiddenKinds: const {'acBonus', 'resistance'},
            ),
          ],
        ),
        section(
          icon: Icons.layers_outlined,
          title: context.l10n.hbBaseItem,
          summary: _baseItemKind == 'none'
              ? context.l10n.hbNoneM
              : _orNone([
                  _baseItemKinds(context.l10n)[_baseItemKind] ?? _baseItemKind,
                  if (_magicBonusValue != 0) _signed(_magicBonusValue),
                ], ''),
          children: [
            _fieldRow(
              flex: const [3, 2],
              [
                _idDropdown(
                  label: context.l10n.hbBaseItem,
                  value: _baseItemKind,
                  options: _baseItemKinds(context.l10n),
                  // Las bases elegidas son de la familia anterior y no valen
                  // para la nueva: el motor las rechazaría igual
                  // (`_validBase`), pero quedarían guardadas y sin nada que
                  // las muestre.
                  onChanged: (v) => setState(() {
                    _baseItemKind = v;
                    _eligibleBases.clear();
                    focus = 'base';
                  }),
                  onTap: () => focusOn('base'),
                ),
                _text(
                  _magicBonus,
                  context.l10n.hbMagicBonusShort,
                  number: true,
                  validator: (v) =>
                      _intInRange(context.l10n, v, -5, 10, optional: false),
                  onTap: () => focusOn('magicBonus'),
                ),
              ],
            ),
            // Solo con una familia elegida: sin objeto base no hay nada que
            // restringir, y el campo pedía escribir los ids del catálogo a
            // mano.
            if (_baseItemKind != 'none') ...[
              const SizedBox(height: 8),
              Eyebrow(context.l10n.hbAllowedBases),
              const SizedBox(height: 4),
              Text(
                _eligibleBases.isEmpty
                    ? context.l10n.hbAnyBase
                    : context.l10n.hbOnlyMarked,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _idChips(_baseOptions(), _eligibleBases, redraw),
            ],
            explainHere((f) => f == 'base' || f == 'magicBonus'),
          ],
        ),
        section(
          icon: Icons.menu_book_outlined,
          title: context.l10n.hbDescription,
          summary: _description.text.trim().isEmpty
              ? context.l10n.hbNotSet
              : context.l10n.hbLoaded,
          children: [
            _text(_description, context.l10n.hbDescription, maxLines: 5),
          ],
        ),
      ],
    );
  }

  /// Las bases del catálogo que puede tomar la familia elegida, por su nombre.
  /// Escudo y armadura salen del mismo catálogo y los separa `isShield`, igual
  /// que en `InventoryOps._validBase`.
  Map<String, String> _baseOptions() => switch (_baseItemKind) {
    'weapon' => {for (final w in widget.repo.weaponsSorted) w.id: w.name},
    'armor' => {
      for (final a in widget.repo.armorSorted)
        if (!a.isShield) a.id: a.name,
    },
    'shield' => {
      for (final a in widget.repo.armorSorted)
        if (a.isShield) a.id: a.name,
    },
    _ => const {},
  };
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// Las pills de un objeto en la lista y en la vista previa del formulario.
List<String> _itemPills(AppLocalizations l10n, Item i) => [
  _itemCategories(l10n)[i.category] ?? i.category,
  if (i.rarity != null) _itemRarities(l10n)[i.rarity] ?? i.rarity!,
  if (i.requiresAttunement) l10n.codexAttunement,
];

/// Las cifras de un objeto, con el mismo motivo que [_itemPills].
List<(String, String)> _itemStats(AppLocalizations l10n, Item i) => [
  if (i.weight > 0) (l10n.codexWeight, '${formatPounds(i.weight)} lb'),
  if (i.costCp > 0) (l10n.codexPrice, l10n.cost(i.costCp)),
  if (i.maxCharges != null) (l10n.codexCharges, '${i.maxCharges}'),
  if (i.bundleSize > 1) (l10n.kindPack, '${i.bundleSize}'),
];
