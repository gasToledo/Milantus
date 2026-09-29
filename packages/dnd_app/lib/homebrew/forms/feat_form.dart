part of '../homebrew_screen.dart';

/// Formulario de dote. Para guardarla alcanzan nombre y categoría; lo que la
/// hace útil —qué concede— va en su sección, junto a la descripción.
///
/// El panel muestra la dote como la ve el jugador al elegirla, que es lo único
/// que va a saber de ella: sin descripción ni efectos, queda un nombre solo.
class FeatForm extends StatefulWidget {
  final Feat? initial;

  /// Para que el editor de efectos pueda ofrecer y nombrar contenido del
  /// catálogo (los conjuros y las dotes que la dote conceda).
  final ContentRepository repo;
  const FeatForm({super.key, required this.repo, this.initial});
  @override
  State<FeatForm> createState() => _FeatFormState();
}

class _FeatFormState extends State<FeatForm> with _GuidedForm {
  late final _name = watch(widget.initial?.name ?? '');
  late String _category = widget.initial?.category ?? 'general';
  late final _description = watch(widget.initial?.description ?? '');
  late final List<Effect> _effects = [...?widget.initial?.effects];
  late bool _repeatable = widget.initial?.repeatable ?? false;

  Feat _feat() => Feat(
    id: widget.initial?.id ?? homebrewId(_name.text),
    name: _name.text.trim(),
    source: ContentSource.homebrew,
    category: _category,
    description: _description.text.trim(),
    effects: _effects,
    repeatable: _repeatable,
    // Lo que el formulario no edita se conserva: una dote del catálogo
    // duplicada sin su prerrequisito sería otra dote.
    exclusiveGroup: widget.initial?.exclusiveGroup,
    prerequisite: widget.initial?.prerequisite,
    spellcastingAbilityOptions:
        widget.initial?.spellcastingAbilityOptions ?? const [],
  );

  void _save() => Navigator.of(context).pop(_feat());

  @override
  _Explained? explain(String key) => switch (key) {
    'category' => switch (featCategoryRules[_category]) {
      final rule? => _explained(
        context.l10n.codexCategory,
        _featCategories(context.l10n)[_category] ?? _category,
        rule,
      ),
      null => null,
    },
    'repeatable' => _explained(
      context.l10n.hbRepetition,
      _repeatable ? context.l10n.codexRepeatable : context.l10n.hbOnce,
      featRepeatableRule,
    ),
    _ => null,
  };

  @override
  Iterable<String> get chosenKeys => [
    'category',
    if (_repeatable) 'repeatable',
  ];

  @override
  Widget build(BuildContext context) {
    final feat = _feat();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _FormScaffold(
      title: context.l10n.luFeat,
      onSave: _save,
      onInvalid: openAllSections,
      panel: guidePanel(
        previewTitle: context.l10n.hbFeatPreview,
        preview: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DenseRows(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewName(context, feat.name, size: 18),
                      const SizedBox(height: 6),
                      if (feat.description.isNotEmpty) ...[
                        Text(feat.description),
                        const SizedBox(height: 10),
                      ],
                      ..._traitsPreview(context, feat.effects, widget.repo),
                    ],
                  ),
                ),
              ],
            ),
            if (feat.description.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.hbFeatNoDescription,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
              ),
            ],
          ],
        ),
        hint: context.l10n.hbFeatHint,
      ),
      children: [
        _text(
          _name,
          context.l10n.detailsName,
          validator: (v) => _requiredText(v, context.l10n.hbReqFeatName),
        ),
        _categoryDropdown(
          _featCategories(context.l10n),
          _category,
          (v) => setState(() {
            _category = v;
            focus = 'category';
          }),
          onTap: () => focusOn('category'),
        ),
        explainHere((f) => f == 'category'),
        ..._optionalRule,
        section(
          icon: Icons.menu_book_outlined,
          title: context.l10n.hbDescription,
          summary: _description.text.trim().isEmpty
              ? context.l10n.hbNotSet
              : context.l10n.hbLoaded,
          children: [
            _text(_description, context.l10n.hbFeatDistinct, maxLines: 5),
          ],
        ),
        section(
          icon: Icons.auto_awesome,
          title: context.l10n.hbGrants,
          summary: _effectsSummary(context.l10n, _effects),
          children: [
            EffectEditor(
              effects: _effects,
              repo: widget.repo,
              onChanged: redraw,
            ),
          ],
        ),
        section(
          icon: Icons.repeat,
          title: context.l10n.hbPrereqRepeat,
          summary: [
            feat.prerequisite == null
                ? context.l10n.hbNoPrereq
                : context.l10n.hbWithPrereq,
            _repeatable
                ? context.l10n.hbRepeatableLower
                : context.l10n.hbOnceLower,
          ].join(' · '),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.hbRepeatSwitch),
              value: _repeatable,
              onChanged: (v) => setState(() {
                _repeatable = v;
                focus = 'repeatable';
              }),
            ),
            // ponytail: el prerrequisito no se edita, solo se conserva; se
            // suma cuando alguien arme una dote general propia con requisito.
            if (feat.prerequisite != null)
              Text(
                context.l10n.hbKeepPrereq,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            explainHere((f) => f == 'repeatable'),
          ],
        ),
      ],
    );
  }
}

/// El resumen de una lista de efectos en la cabecera de su sección.
String _effectsSummary(AppLocalizations l10n, List<Effect> effects) =>
    l10n.hbEffectsCount(effects.length);
