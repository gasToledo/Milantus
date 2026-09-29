part of '../creation_wizard.dart';

class _EquipmentStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _EquipmentStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    draft.pruneEquipment();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StartingEquipmentSection(draft: draft, onChanged: onChanged),
        // Antes de «Equipo puesto»: lo que se compra (una armadura, un escudo)
        // tiene que aparecer abajo para ponérselo.
        const SizedBox(height: 26),
        _PurchasesSection(draft: draft, onChanged: onChanged),
        const SizedBox(height: 26),
        _SectionHeader(title: context.l10n.equipReceivedTitle),
        const SizedBox(height: 12),
        _ReceivedEquipmentSection(draft: draft, onChanged: onChanged),
        _WeaponGripSection(draft: draft, onChanged: onChanged),
        const SizedBox(height: 26),
        _SectionHeader(title: context.l10n.spellsTitle),
        const SizedBox(height: 12),
        // Va antes de la magia de clase: lo elegido acá queda siempre preparado
        // y sale del pozo de abajo, así que preguntarlo después haría que el
        // jugador preparase un conjuro que está por recibir gratis.
        //
        // Fuera de `draft.isCaster` a propósito: un rasgo puede conceder
        // conjuros a un personaje que no lanza por clase.
        _SpellChoicesSection(draft: draft, onChanged: onChanged),
        if (draft.isCaster)
          _SpellsSection(draft: draft, onChanged: onChanged)
        else
          const _NoSpellsNotice(),
      ],
    );
  }
}

class _StartingEquipmentSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _StartingEquipmentSection({
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(title: context.l10n.equipStartingTitle),
      const SizedBox(height: 12),
      _optionPicker(
        context,
        true,
        draft.klass?.startingEquipment ?? const [],
        draft.classEquipmentOptionId,
        (id) {
          draft.classEquipmentOptionId = id;
          draft.pruneEquipment();
          onChanged();
        },
      ),
      const SizedBox(height: 12),
      _optionPicker(
        context,
        false,
        draft.background?.startingEquipment ?? const [],
        draft.backgroundEquipmentOptionId,
        (id) {
          draft.backgroundEquipmentOptionId = id;
          draft.pruneEquipment();
          onChanged();
        },
      ),
      for (final (:key, :grant) in draft.selectedEquipmentGrants)
        if (grant.isChoice) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('equipment-choice-$key'),
            initialValue:
                grant.chooseFromItemIds.contains(draft.equipmentChoices[key])
                ? draft.equipmentChoices[key]
                : null,
            // Dos desplegables iguales no decían cuál era de la clase y cuál
            // del trasfondo.
            decoration: InputDecoration(
              labelText: key.startsWith('class:')
                  ? context.l10n.equipPickClassItem
                  : context.l10n.equipPickBackgroundItem,
            ),
            items: [
              for (final id in grant.chooseFromItemIds)
                DropdownMenuItem(
                  value: id,
                  child: Text(draft.repo.catalogEntry(id)?.name ?? id),
                ),
            ],
            onChanged: (id) {
              if (id != null) draft.equipmentChoices[key] = id;
              draft.pruneEquipment();
              onChanged();
            },
          ),
        ],
      // Lo que traen las opciones, sin las compras: eso va en su sección, y
      // mezclado acá el oro aparecía ya descontado sin decir por qué.
      if (draft.grantedItems.isNotEmpty || draft.grantedCoins.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          [
            ...draft.grantedItems.map((e) {
              final name = draft.repo.catalogEntry(e.itemId)?.name ?? e.itemId;
              return e.quantity == 1 ? name : '$name ×${e.quantity}';
            }),
            ...draft.grantedCoins.entries.map(
              (e) => '${e.value} ${coinAbbr(context.l10n, e.key)}',
            ),
          ].join(' · '),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ],
  );

  Widget _optionPicker(
    BuildContext context,
    bool forClass,
    List<StartingEquipmentOption> options,
    String? selected,
    ValueChanged<String?> changed,
  ) => options.isEmpty
      // Un desplegable sin opciones se veía deshabilitado y no decía por qué.
      ? Text(
          forClass
              ? context.l10n.equipNoStartingClass
              : context.l10n.equipNoStartingBackground,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        )
      : DropdownButtonFormField<String>(
          key: ValueKey(
            'starting-equipment-${forClass ? 'clase' : 'trasfondo'}',
          ),
          initialValue: options.any((e) => e.id == selected) ? selected : null,
          decoration: InputDecoration(
            labelText: forClass
                ? context.l10n.equipOptionClass
                : context.l10n.equipOptionBackground,
          ),
          // Cada opción dice qué trae: «Opción A» y «Opción B» a secas obligaban a
          // elegir a ciegas y enterarse después. Cerrado muestra solo el rótulo,
          // porque la lista completa ya aparece debajo una vez elegido.
          isExpanded: true,
          itemHeight: null,
          selectedItemBuilder: (_) => [
            for (final option in options) Text(option.label),
          ],
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.id,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.label),
                      Text(
                        _optionContents(context, option),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          onChanged: changed,
        );

  String _optionContents(
    BuildContext context,
    StartingEquipmentOption option,
  ) => [
    for (final grant in option.grants) ...[
      if (grant.itemId case final id?)
        grant.quantity == 1
            ? _itemName(id)
            : '${_itemName(id)} ×${grant.quantity}',
      if (grant.isChoice)
        grant.chooseFromItemIds.length <= 3
            ? grant.chooseFromItemIds
                  .map(_itemName)
                  .join(' ${context.l10n.wordOr} ')
            // «1 a elegir» no decía entre qué: se nombran las dos primeras.
            : '${grant.chooseFromItemIds.take(2).map(_itemName).join(', ')} ${context.l10n.equipOrOther}',
      for (final coin in grant.coins.entries)
        '${coin.value} ${coinAbbr(context.l10n, coin.key)}',
    ],
  ].join(' · ');

  String _itemName(String id) => draft.repo.catalogEntry(id)?.name ?? id;
}

/// Compras con el oro de partida.
///
/// El PHB 2024 deja elegir el oro en vez del paquete (el Paladín puede nacer
/// con 150 po), y hasta acá ese oro quedaba en la bolsa sin forma de
/// gastarlo: había que terminar el personaje y comprar desde la ficha. Acá
/// se compra al precio del manual y sin diálogo de pago, porque todo el paso
/// se puede rehacer hasta terminar.
class _PurchasesSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _PurchasesSection({required this.draft, required this.onChanged});

  void _set(String itemId, int quantity) {
    draft.setPurchase(itemId, quantity);
    draft.pruneEquipment();
    onChanged();
  }

  Future<void> _openShop(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => ItemCatalogDialog(
      repo: draft.repo,
      title: context.l10n.equipShopTitle,
      purseLabel: context.l10n.equipLeftShort,
      purseCp: () => draft.goldLeftCp,
      countOf: (id) => draft.purchases[id] ?? 0,
      hint: context.l10n.equipShopHint,
      // No cierra: se arma el equipo entero sin volver a abrir el catálogo.
      onBuy: (row) async {
        draft.buy(row.id);
        draft.pruneEquipment();
        onChanged();
        return false;
      },
      includeMagic: false,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final granted = CoinOps.totalCp(draft.grantedCoins);
    final left = draft.goldLeftCp;

    // Sin opciones elegidas todavía no se sabe cuánto oro hay: «Quedan 0 po»
    // y «no traen oro» decían algo falso de un paquete que nadie eligió.
    final unchosen =
        (draft.classEquipmentOption == null &&
            (draft.klass?.startingEquipment ?? const []).isNotEmpty) ||
        (draft.backgroundEquipmentOption == null &&
            (draft.background?.startingEquipment ?? const []).isNotEmpty);
    if (granted == 0 && unchosen && draft.purchases.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: context.l10n.equipPurchases),
          const SizedBox(height: 12),
          Text(
            context.l10n.equipPickFirst,
            style: TextStyle(fontSize: 13, height: 1.5, color: muted),
          ),
        ],
      );
    }

    Widget plaque(String label, String value, {bool highlight = false}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: pal.plaque,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: highlight ? pal.gold : pal.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: pal.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: highlight ? pal.gold : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: context.l10n.equipPurchases,
          counterIcon: Icons.savings_outlined,
          counter: left < 0
              ? context.l10n.catalogShortBy(CoinOps.formatAmount(-left))
              : context.l10n.equipLeft(CoinOps.formatAmount(left)),
        ),
        const SizedBox(height: 12),
        Text(
          granted == 0
              ? context.l10n.equipNoGold
              : context.l10n.equipGoldExplainer,
          style: TextStyle(fontSize: 13, height: 1.5, color: muted),
        ),
        if (draft.purchases.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.hairline),
            ),
            child: Column(
              children: [
                for (final (index, e) in draft.purchases.entries.indexed) ...[
                  if (index > 0) Divider(height: 1, color: pal.hairline),
                  _row(context, e.key, e.value),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            plaque(
              context.l10n.equipStartingGold,
              CoinOps.formatAmount(granted),
            ),
            const SizedBox(width: 10),
            plaque(
              context.l10n.equipInPurchases,
              CoinOps.formatAmount(draft.purchasesCp),
            ),
            const SizedBox(width: 10),
            plaque(
              left < 0
                  ? context.l10n.equipShortLabel
                  : context.l10n.equipYouHaveLeft,
              CoinOps.formatAmount(left.abs()),
              highlight: true,
            ),
          ],
        ),
        if (left < 0) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.equipOverspent,
            style: TextStyle(fontSize: 13, color: pal.crimson),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('open-shop'),
            onPressed: granted == 0 && draft.purchases.isEmpty
                ? null
                : () => _openShop(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.equipBuyItems),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String itemId, int quantity) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final name = draft.repo.catalogEntry(itemId)?.name ?? itemId;
    final unit = InventoryOps.catalogPriceCp(itemId, draft.repo);
    final bundle = draft.repo.item(itemId)?.bundleSize ?? 1;
    return Padding(
      key: ValueKey('purchase-$itemId'),
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  bundle > 1
                      ? '${formatCost(unit)} el paquete de $bundle'
                      : '${formatCost(unit)} c/u',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.equipOneLess(name),
            onPressed: quantity > 1 ? () => _set(itemId, quantity - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.equipOneMore(name),
            onPressed: () => _set(itemId, quantity + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
          SizedBox(
            width: 72,
            child: Text(
              CoinOps.formatAmount(unit * quantity),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: pal.gold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.equipRemovePurchase(name),
            onPressed: () => _set(itemId, 0),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ReceivedEquipmentSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ReceivedEquipmentSection({
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final armor = [
      for (final id in draft.receivedItemIds) ?draft.repo.armorPiece(id),
    ];
    final weapons = [
      for (final id in draft.receivedItemIds) ?draft.repo.weapon(id),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Las pastillas siempre fueron interruptores, pero se leían como una
        // lista de lo recibido.
        if (armor.isNotEmpty || weapons.isNotEmpty) ...[
          Text(
            context.l10n.equipTapPiece,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in armor)
              FilterChip(
                label: Text(item.name),
                selected: item.isShield
                    ? draft.shieldEquipped
                    : draft.equippedArmorId == item.id,
                onSelected: (on) {
                  draft.equipmentTouched = true;
                  if (item.isShield) {
                    draft.shieldEquipped = on;
                    // Con escudo no hay mano libre: una versátil marcada a dos
                    // manos seguiría calculándose con el dado mayor.
                    if (on) draft.weaponTwoHanded.clear();
                  } else {
                    draft.equippedArmorId = on ? item.id : null;
                  }
                  onChanged();
                },
              ),
            for (final item in weapons)
              FilterChip(
                label: Text(item.name),
                selected: draft.weaponIds.contains(item.id),
                onSelected: (on) {
                  draft.equipmentTouched = true;
                  draft.weaponIds.remove(item.id);
                  if (on) draft.weaponIds.add(item.id);
                  onChanged();
                },
              ),
          ],
        ),
        // Solo con algo recibido: antes de elegir un paquete no hay «paquete
        // elegido», y el aviso aparecía igual.
        if (armor.isEmpty &&
            weapons.isEmpty &&
            draft.receivedItemIds.isNotEmpty)
          Text(
            context.l10n.equipNothingToWear,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// Cómo se empuña cada arma elegida.
///
/// Solo aparecen los interruptores que el arma admite: Secundaria exige la
/// propiedad Ligera y A dos manos exige daño versátil. Antes acá había un
/// cartel avisando que la regla de dos armas no se aplicaba sola; ahora el
/// motor la aplica, así que lo que falta es decidir la mano.
class _WeaponGripSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _WeaponGripSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Secundaria solo con dos armas en las manos, y A dos manos solo sin
    // escudo: con una espada y un escudo se ofrecían las dos cosas, y el texto
    // hablaba de un ataque con la otra mano que no había.
    final dual = draft.weaponIds.length >= 2;
    final shield = draft.shieldEquipped;
    final grips = [
      for (final id in draft.weaponIds)
        if (draft.repo.weapon(id) case final w?)
          if ((dual && w.isLight) || (!shield && w.versatileDice != null)) w,
    ];
    if (grips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          context.l10n.equipGrip,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (dual)
          Text(
            context.l10n.equipOffHandNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 6),
        for (final w in grips)
          Row(
            children: [
              Expanded(child: Text(w.name)),
              if (dual && w.isLight)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    key: ValueKey('off-hand-${w.id}'),
                    label: Text(context.l10n.equipOffHandShort),
                    selected: draft.weaponOffHand[w.id] ?? false,
                    onSelected: (v) {
                      // Solo se empuña un arma en la secundaria.
                      draft.weaponOffHand
                        ..clear()
                        ..addAll(v ? {w.id: true} : const {});
                      onChanged();
                    },
                  ),
                ),
              if (!shield && w.versatileDice != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    key: ValueKey('two-handed-${w.id}'),
                    label: Text(context.l10n.invTwoHanded),
                    selected: draft.weaponTwoHanded[w.id] ?? false,
                    onSelected: (v) {
                      draft.weaponTwoHanded[w.id] = v;
                      onChanged();
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Cartel para clases que no lanzan conjuros.
class _NoSpellsNotice extends StatelessWidget {
  const _NoSpellsNotice();

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 30, color: pal.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.equipNoSpellsTitle,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.equipNoSpellsBody,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Conjuros que un rasgo deja elegir y quedan siempre preparados.
///
/// Ninguna clase oficial declara uno a nivel 1 —el primero es Descubrimientos
/// Mágicos, a nivel 6—, así que en la práctica esto solo aparece con homebrew.
/// Va igual: si no estuviera, la creación sería el único lugar donde una
/// elección que el motor declara no se puede resolver.
class _SpellChoicesSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpellChoicesSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Igual que en el paso de aptitudes: cambiar de clase o de trasfondo puede
    // vaciar un cupo, y una elección que dejó de calificar tiene que soltarse
    // acá y no quedar guardada sin chip que la saque.
    draft.pruneSpellChoices();
    final slots = draft.spellChoiceSlots;
    if (slots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slot in slots) ...[
          _SpellGroupHeader(
            title: slot.name,
            count: (draft.spellChoices[slot.groupId] ?? const []).length,
            cap: slot.count,
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.equipNoPreparedSlot,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final selected = {...?draft.spellChoices[slot.groupId]};
              final spells = [
                for (final id in slot.options) ?draft.repo.spell(id),
              ];
              // La etiqueta de nivel solo distingue algo si el cupo mezcla
              // trucos con conjuros; en uno de puros trucos, «(truco)» en cada
              // chip repetía el título.
              final mixed =
                  spells.any((s) => s.isCantrip) &&
                  spells.any((s) => !s.isCantrip);
              return CappedChipSelect(
                options: {
                  for (final s in spells)
                    s.id: s.isCantrip
                        ? (mixed
                              ? context.l10n.equipCantripSuffix(s.name)
                              : s.name)
                        : context.l10n.equipLevelShort(s.name, s.level),
                },
                selected: selected,
                max: slot.count,
                onChanged: () {
                  draft.spellChoices[slot.groupId] = selected.toList();
                  onChanged();
                },
                onInfo: (id) {
                  if (draft.repo.spell(id) case final s?) {
                    showSpellDetailsDialog(context, s);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _SpellsSection extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _SpellsSection({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sc = draft.spellcasting;
    if (sc == null) return const SizedBox.shrink();
    final all = draft.repo.spellsForList(
      sc.spellList,
      extraSpellIds: draft.spellListAdditionIds,
    );
    final maxLevel = sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);
    final grantedSpellIds = draft.grantedSpellIds;
    final cantrips = all
        .where((s) => s.isCantrip && !grantedSpellIds.contains(s.id))
        .toList();
    final grantedCantripNames = [
      for (final s in all)
        if (s.isCantrip && grantedSpellIds.contains(s.id)) s.name,
    ];
    final leveled = all
        .where(
          (s) =>
              !s.isCantrip &&
              s.level <= maxLevel &&
              !grantedSpellIds.contains(s.id),
        )
        .toList();
    final grantedLeveledNames = [
      for (final s in all)
        if (!s.isCantrip && grantedSpellIds.contains(s.id)) s.name,
    ];
    final prepared = sc.preparation == SpellPreparation.prepared;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipCasterLine(
            sc.saveDc,
            '${sc.attackBonus >= 0 ? '+' : ''}${sc.attackBonus}',
            sc.ability.abbr,
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        // Tres palabras que la pantalla usa como si se explicaran solas.
        // Se arma según la clase: sin trucos no se los nombra, y preparar y
        // conocer no son lo mismo aunque la grilla de abajo se vea igual.
        AppHelpCallout(
          icon: Icons.auto_stories,
          title: context.l10n.equipMagicTitle,
          message: [
            if (sc.cantripsKnown > 0) context.l10n.equipMagicCantrips,
            prepared
                ? context.l10n.equipMagicPrepared
                : context.l10n.equipMagicKnown,
            context.l10n.equipMagicSlots,
          ].join(' '),
        ),
        if (sc.cantripsKnown > 0) ...[
          const SizedBox(height: 18),
          _SpellGroupHeader(
            title: context.l10n.spellsCantripsTitle,
            count: draft.cantrips.length,
            cap: sc.cantripsKnown,
          ),
          if (grantedCantripNames.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              // Sin nombrar el origen: los concedidos vienen mezclados de la
              // especie, la dote del trasfondo u otros rasgos, y decir
              // «tu especie» atribuía a la especie los de la dote.
              grantedCantripNames.length == 1
                  ? context.l10n.equipGrantedCantripOne(
                      grantedCantripNames.single,
                    )
                  : context.l10n.equipGrantedCantripMany(
                      grantedCantripNames.join(', '),
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          _SpellChips(
            spells: cantrips,
            selected: draft.cantrips,
            max: sc.cantripsKnown,
            icon: Icons.auto_fix_high,
            onChanged: onChanged,
          ),
        ],
        const SizedBox(height: 20),
        _SpellGroupHeader(
          title: prepared
              ? context.l10n.spellsPreparedTitle
              : context.l10n.spellsKnownTitle,
          count: draft.spells.length,
          cap: prepared ? sc.preparedCount : null,
        ),
        if (grantedLeveledNames.isNotEmpty)
          Text(
            context.l10n.equipGrantedLeveled(grantedLeveledNames.join(', ')),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Text(
          context.l10n.equipMaxLevel(maxLevel),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _SpellChips(
          spells: leveled,
          selected: draft.spells,
          max: prepared ? sc.preparedCount : 999,
          icon: Icons.auto_stories,
          showLevel: true,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Título de un grupo de conjuros con su contador.
class _SpellGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final int? cap;
  const _SpellGroupHeader({
    required this.title,
    required this.count,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          cap == null ? '$count' : '$count / $cap',
          style: TextStyle(fontSize: 12, color: context.palette.textMuted),
        ),
      ],
    );
  }
}

/// Conjuros como chips seleccionables, con tope.
class _SpellChips extends StatelessWidget {
  final List<Spell> spells;
  final Set<String> selected;
  final int max;
  final IconData icon;
  final bool showLevel;
  final VoidCallback onChanged;
  const _SpellChips({
    required this.spells,
    required this.selected,
    required this.max,
    required this.icon,
    required this.onChanged,
    this.showLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final full = selected.length >= max;
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final s in spells)
          Builder(
            builder: (context) {
              final on = selected.contains(s.id);
              final enabled = on || !full;
              return Material(
                color: on ? pal.goldSoft : scheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: enabled
                      ? () {
                          if (!selected.remove(s.id)) selected.add(s.id);
                          onChanged();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? pal.gold : pal.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: on
                              ? pal.gold
                              : enabled
                              ? scheme.onSurfaceVariant
                              : pal.textMuted,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            showLevel
                                ? context.l10n.equipLevelShort(s.name, s.level)
                                : s.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: on
                                  ? pal.gold
                                  : enabled
                                  ? scheme.onSurface
                                  : pal.textMuted,
                            ),
                          ),
                        ),
                        // Su propio `InkWell` adentro del chip: el toque del
                        // chip ya elige, y con el cupo lleno es justo cuando
                        // más falta poder leer lo que todavía no elegiste.
                        //
                        // Acá sí anida, a diferencia de `CappedChipSelect`:
                        // este chip es un `InkWell` propio y no un `FilterChip`,
                        // que se queda con todos los toques de su superficie.
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => showSpellDetailsDialog(context, s),
                          customBorder: const CircleBorder(),
                          child: Tooltip(
                            message: context.l10n.helpWhatItDoes(s.name),
                            child: Icon(
                              Icons.info_outline,
                              size: 15,
                              color: pal.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
