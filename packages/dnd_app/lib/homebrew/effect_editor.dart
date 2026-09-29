part of 'homebrew_screen.dart';

/// Editor de una lista de [Effect]. Permite agregar tipos comunes y quitarlos.
///
/// ponytail: no edita un efecto ya agregado —se quita y se vuelve a poner— ni
/// ofrece los efectos de **elección** (`ProficiencyChoiceEffect` y familia), que
/// piden un subformulario con su propia lista de opciones, ni la maquinaria de
/// clase (`SpellcastingEffect`, `ResourceEffect`, `CompanionEffect`), que no
/// aparece en una dote ni en una especie. Todo eso se sigue cargando por JSON e
/// importando el pack, y el editor lo conserva tal cual: lo que no sabe
/// describir lo muestra por su tipo, pero nunca lo borra.
class EffectEditor extends StatefulWidget {
  final List<Effect> effects;

  /// Para nombrar y ofrecer el contenido que un efecto puede conceder.
  final ContentRepository repo;
  final VoidCallback onChanged;

  /// Tipos que no se ofrecen, por el nombre de su `_EffectKind`. El objeto
  /// esconde la CA y las resistencias porque ya tiene campos propios para
  /// eso: ofrecerlos dos veces permitía sumar la misma CA dos veces.
  final Set<String> hiddenKinds;

  const EffectEditor({
    super.key,
    required this.effects,
    required this.repo,
    required this.onChanged,
    this.hiddenKinds = const {},
  });

  @override
  State<EffectEditor> createState() => _EffectEditorState();
}

class _EffectEditorState extends State<EffectEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.effects.isEmpty)
          Text(
            context.l10n.effNone,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          DenseRows(
            children: [
              for (final entry in widget.effects.asMap().entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        // Al jugador lo que no se puede describir no se le
                        // muestra; acá mira quien arma el contenido, y
                        // ocultarlo escondería un efecto que igual se guarda.
                        child: Text(
                          describeEffect(
                                context.l10n,
                                entry.value,
                                widget.repo,
                              ) ??
                              entry.value.toJson()['type'].toString(),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.effRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() => widget.effects.removeAt(entry.key));
                          widget.onChanged();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(context.l10n.effAdd),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final effect = await showDialog<Effect>(
      context: context,
      builder: (_) => _AddEffectDialog(
        repo: widget.repo,
        kinds: [
          for (final k in _EffectKind.values)
            if (!widget.hiddenKinds.contains(k.name)) k,
        ],
      ),
    );
    if (effect != null) {
      setState(() => widget.effects.add(effect));
      widget.onChanged();
    }
  }
}

/// Los tipos que el diálogo sabe construir, en el orden en que se ofrecen:
/// primero lo que toca los números de la ficha, después lo que concede
/// competencias, después la magia y por último lo narrativo.
enum _EffectKind {
  abilityBonus,
  setAbilityScore,
  hpPerLevel,
  hpFlat,
  acBonus,
  initiativeBonus,
  speedBonus,
  setSpeed,
  darkvision,
  skillProf,
  saveProf,
  saveBonus,
  weaponProf,
  armorProf,
  toolProf,
  language,
  resistance,
  immunity,
  grantSpell,
  alwaysPrepared,
  spellListAddition,
  grantFeat,
  extraAttack,
  masterySlots,
  passive;

  /// El nombre del tipo en el idioma activo.
  String label(AppLocalizations l10n) => switch (this) {
    abilityBonus => l10n.effKindAbilityBonus,
    setAbilityScore => l10n.effKindSetAbility,
    hpPerLevel => l10n.effKindHpPerLevel,
    hpFlat => l10n.effKindHpFlat,
    acBonus => l10n.effKindAcBonus,
    initiativeBonus => l10n.effKindInitiative,
    speedBonus => l10n.effKindSpeedBonus,
    setSpeed => l10n.effKindSetSpeed,
    darkvision => l10n.darkvision,
    skillProf => l10n.effKindSkillProf,
    saveProf => l10n.effKindSaveProf,
    saveBonus => l10n.effKindSaveBonus,
    weaponProf => l10n.effKindWeaponProf,
    armorProf => l10n.effKindArmorProf,
    toolProf => l10n.effKindToolProf,
    language => l10n.effLanguage,
    resistance => l10n.effKindResistance,
    immunity => l10n.effKindImmunity,
    grantSpell => l10n.effKindGrantSpell,
    alwaysPrepared => l10n.effKindAlwaysPrepared,
    spellListAddition => l10n.effKindSpellList,
    grantFeat => l10n.effKindGrantFeat,
    extraAttack => l10n.luReviewExtraAttack,
    masterySlots => l10n.luReviewMasteries,
    passive => l10n.effKindPassive,
  };

  /// Qué es el número, cuando no se entiende solo. Una visión en la oscuridad
  /// de «1» se guardaba sin que nada avisara que eran pies.
  String unit(AppLocalizations l10n) => switch (this) {
    speedBonus || setSpeed => l10n.effUnitFeet,
    darkvision => l10n.effUnitRangeFeet,
    _ => l10n.effUnitValue,
  };

  /// El valor con el que arranca el campo: el más común en el manual. Con
  /// un 1 para todo, la visión en la oscuridad nacía de un pie.
  int get start => switch (this) {
    speedBonus => 10,
    setSpeed => 30,
    darkvision => 60,
    _ => 1,
  };
}

class _AddEffectDialog extends StatefulWidget {
  final ContentRepository repo;
  final List<_EffectKind> kinds;
  const _AddEffectDialog({required this.repo, required this.kinds});
  @override
  State<_AddEffectDialog> createState() => _AddEffectDialogState();
}

class _AddEffectDialogState extends State<_AddEffectDialog> {
  late _EffectKind _kind = widget.kinds.first;
  Ability _ability = Ability.strength;
  late String _skill = _skillOptions.keys.first;
  late String _damageType = _damageTypeOptions.keys.first;
  late String _weaponCategory = weaponProficiencyIds.first;
  late String _armorCategory = armorTrainingIds.first;
  late String _tool = toolProficiencyIds.first;
  late String _language = Language.values.first.id;

  /// Arrancan en la primera entrada del catálogo y no en null para que el botón
  /// Agregar nunca quede sin efecto que construir: el conjuro y la dote son
  /// listas largas, pero siempre hay uno elegido.
  late String _spellId = widget.repo.spellsSorted.first.id;
  late String? _featId = widget.repo.featsSorted.firstOrNull?.id;
  InnateSpellUse _spellUse = InnateSpellUse.atWill;

  /// Suma el bonificador por competencia a la iniciativa, como Alerta.
  bool _initiativeProficiency = false;

  late final _amountCtrl = TextEditingController(text: '${_kind.start}');
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  Effect? _build() => switch (_kind) {
    _EffectKind.abilityBonus => AbilityScoreBonusEffect(
      ability: _ability,
      amount: _amount,
    ),
    _EffectKind.setAbilityScore => SetAbilityScoreEffect(
      ability: _ability,
      score: _amount,
    ),
    _EffectKind.hpPerLevel => BonusMaxHpPerLevelEffect(_amount),
    _EffectKind.hpFlat => BonusMaxHpFlatEffect(_amount),
    _EffectKind.acBonus => ArmorClassBonusEffect(_amount),
    _EffectKind.initiativeBonus => InitiativeBonusEffect(
      amount: _amount,
      addProficiency: _initiativeProficiency,
    ),
    _EffectKind.speedBonus => SpeedBonusEffect(_amount),
    _EffectKind.setSpeed => SetSpeedEffect(_amount),
    _EffectKind.darkvision => DarkvisionEffect(_amount),
    _EffectKind.skillProf => SkillProficiencyEffect(_skill),
    _EffectKind.saveProf => SavingThrowProficiencyEffect(_ability),
    _EffectKind.saveBonus => SavingThrowBonusEffect(_amount),
    _EffectKind.weaponProf => WeaponProficiencyEffect(_weaponCategory),
    _EffectKind.armorProf => ArmorProficiencyEffect(_armorCategory),
    _EffectKind.toolProf => ToolProficiencyEffect(_tool),
    _EffectKind.language => LanguageEffect(_language),
    _EffectKind.resistance => ResistanceEffect(_damageType),
    _EffectKind.immunity => ImmunityEffect(_damageType),
    _EffectKind.grantSpell => GrantSpellEffect(
      spellId: _spellId,
      ability: _ability,
      use: _spellUse,
    ),
    _EffectKind.alwaysPrepared => AlwaysPreparedSpellEffect(spellId: _spellId),
    _EffectKind.spellListAddition => SpellListAdditionEffect(spellId: _spellId),
    // Sin dote elegida es "una dote a elección del jugador", que es un efecto
    // legítimo y no un formulario a medio llenar (la dote de origen 2024).
    _EffectKind.grantFeat => GrantFeatEffect(featId: _featId),
    _EffectKind.extraAttack => ExtraAttackEffect(_amount),
    _EffectKind.masterySlots => WeaponMasterySlotsEffect(_amount),
    _EffectKind.passive =>
      _nameCtrl.text.trim().isEmpty
          ? null
          : PassiveTraitEffect(
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim(),
            ),
  };

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: context.l10n.effAdd,
      width: 460,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _idDropdown(
            label: context.l10n.identityCreatureTypeShort,
            value: _kind.name,
            options: {
              for (final k in widget.kinds) k.name: k.label(context.l10n),
            },
            // Cambiar de tipo cambia qué significa el número: «1» de CA no
            // es «1» pie de visión. Se vuelve al valor de partida del tipo.
            onChanged: (v) => setState(() {
              _kind = _EffectKind.values.byName(v);
              _amountCtrl.text = '${_kind.start}';
            }),
          ),
          ..._fields(),
        ],
      ),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          context.l10n.commonAdd,
          primary: true,
          onPressed: () {
            final e = _build();
            // Antes el botón no hacía nada y el diálogo se quedaba abierto sin
            // decir por qué: un control que no responde se lee como roto.
            if (e == null) {
              showAppMessage(
                context,
                context.l10n.hbReqTraitName,
                tone: AppMessageTone.error,
              );
              return;
            }
            Navigator.of(context).pop(e);
          },
        ),
      ],
    );
  }

  List<Widget> _fields() => switch (_kind) {
    _EffectKind.abilityBonus ||
    _EffectKind.setAbilityScore => [_abilityDropdown(), _amountField()],
    _EffectKind.hpPerLevel ||
    _EffectKind.hpFlat ||
    _EffectKind.acBonus ||
    _EffectKind.speedBonus ||
    _EffectKind.setSpeed ||
    _EffectKind.darkvision ||
    _EffectKind.saveBonus ||
    _EffectKind.extraAttack ||
    _EffectKind.masterySlots => [_amountField()],
    // El bonificador por competencia va como interruptor y no como número:
    // sube con el nivel, y un número fijo quedaría viejo al subir.
    _EffectKind.initiativeBonus => [
      _amountField(),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.l10n.effAddsProfBonus),
        value: _initiativeProficiency,
        onChanged: (v) => setState(() => _initiativeProficiency = v),
      ),
    ],
    _EffectKind.saveProf => [_abilityDropdown()],
    _EffectKind.skillProf => [
      _idDropdown(
        label: context.l10n.effSkill,
        value: _skill,
        options: _skillOptions,
        onChanged: (v) => setState(() => _skill = v),
      ),
    ],
    _EffectKind.weaponProf => [
      _idDropdown(
        label: context.l10n.groupWeapons,
        value: _weaponCategory,
        options: {
          for (final id in weaponProficiencyIds) id: weaponProficiencyLabel(id),
          // Un rasgo también puede conceder **un arma concreta** (el Bardo con
          // el estoque), y ahí el id es el del arma, no una categoría.
          for (final w in widget.repo.weaponsSorted) w.id: w.name,
        },
        onChanged: (v) => setState(() => _weaponCategory = v),
      ),
    ],
    _EffectKind.armorProf => [
      _idDropdown(
        label: context.l10n.kindArmor,
        value: _armorCategory,
        options: {
          for (final id in armorTrainingIds) id: armorTrainingLabel(id),
        },
        onChanged: (v) => setState(() => _armorCategory = v),
      ),
    ],
    _EffectKind.toolProf => [
      _idDropdown(
        label: context.l10n.kindTool,
        value: _tool,
        options: {
          for (final id in toolProficiencyIds) id: toolProficiencyLabel(id),
        },
        onChanged: (v) => setState(() => _tool = v),
      ),
    ],
    _EffectKind.language => [
      _idDropdown(
        label: context.l10n.effLanguage,
        value: _language,
        options: {for (final l in Language.values) l.id: l.label},
        onChanged: (v) => setState(() => _language = v),
      ),
    ],
    _EffectKind.resistance || _EffectKind.immunity => [
      // Desplegable y no texto libre: escrito a mano, "fuego" no coincide con
      // el id `fire` y el efecto quedaba guardado sin hacer nada.
      _damageTypeDropdown(_damageType, (v) => setState(() => _damageType = v)),
    ],
    _EffectKind.grantSpell => [
      _spellDropdown(),
      _idDropdown(
        label: context.l10n.effHowUsed,
        value: _spellUse.name,
        options: {
          for (final use in InnateSpellUse.values)
            use.name: innateSpellUseLabel(context.l10n, use),
        },
        onChanged: (v) =>
            setState(() => _spellUse = InnateSpellUse.values.byName(v)),
      ),
      _abilityDropdown(label: context.l10n.effCastAbility),
    ],
    _EffectKind.alwaysPrepared ||
    _EffectKind.spellListAddition => [_spellDropdown()],
    _EffectKind.grantFeat => [
      _idDropdown(
        label: context.l10n.luFeat,
        value: _featId ?? _anyFeat,
        options: {
          _anyFeat: context.l10n.effPlayerChoice,
          for (final f in widget.repo.featsSorted) f.id: f.name,
        },
        onChanged: (v) => setState(() => _featId = v == _anyFeat ? null : v),
      ),
    ],
    _EffectKind.passive => [
      _text(_nameCtrl, context.l10n.effTraitName),
      _text(_descCtrl, context.l10n.hbDescription, maxLines: 2),
    ],
  };

  Widget _spellDropdown() => _idDropdown(
    label: context.l10n.hbSpell,
    value: _spellId,
    options: {
      for (final s in widget.repo.spellsSorted)
        s.id: s.isCantrip
            ? context.l10n.equipCantripSuffix(s.name)
            : context.l10n.effSpellLevel(s.name, s.level),
    },
    onChanged: (v) => setState(() => _spellId = v),
  );

  Widget _abilityDropdown({String? label}) => _idDropdown(
    label: label ?? context.l10n.effAbility,
    value: _ability.name,
    // El nombre completo y no la abreviatura: acá se está eligiendo, y "STR"
    // obliga a saber inglés para tomar la decisión. El resumen del efecto ya
    // creado sí usa la abreviatura, que ahí es un rótulo compacto.
    options: {for (final a in Ability.values) a.name: a.label},
    onChanged: (v) => setState(() => _ability = Ability.values.byName(v)),
  );

  Widget _amountField() =>
      _text(_amountCtrl, _kind.unit(context.l10n), number: true);
}

/// Valor del desplegable de dote que significa "la elige el jugador". Va como
/// texto y no como null por lo mismo que [_mundane]: el desplegable no acepta
/// una opción nula.
const _anyFeat = 'any';
