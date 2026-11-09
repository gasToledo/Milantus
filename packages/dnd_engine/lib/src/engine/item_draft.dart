import '../data/content_repository.dart';
import '../domain/content.dart';
import '../domain/content_source.dart';
import '../domain/effects.dart';
import 'draft_numbers.dart';

/// El borrador de un objeto que edita un formulario (mismo patrón que
/// `WeaponDraft` y `ArmorDraft`). Es el `_item()`, la separación de efectos, los
/// validadores y los `onChanged` de rareza y de familia de `ItemForm` de
/// Flutter, llevados al motor.
class ItemDraft {
  const ItemDraft._();

  /// La plantilla de «Nuevo objeto»: mundano, de la familia «Equipo» y sin
  /// efectos. El id es provisorio: el definitivo sale del nombre al guardar.
  static Item empty() => const Item(
        id: 'objeto-propio',
        name: '',
        source: ContentSource.homebrew,
        category: 'gear',
      );

  /// Lo que el formulario edita, como texto.
  ///
  /// Los efectos viajan **en tres partes**, porque el formulario tiene un campo
  /// para el bonificador a la CA, otro para las resistencias y un editor para el
  /// resto: [build] los vuelve a juntar. `acBonus` es el del **primer**
  /// `ArmorClassBonusEffect`; si el objeto trae más de uno, los demás quedan en
  /// `otherEffects` en vez de perderse sin aviso.
  static Map<String, dynamic> formOf(Item i) {
    ArmorClassBonusEffect? firstAc;
    for (final e in i.effects) {
      if (e is ArmorClassBonusEffect) {
        firstAc = e;
        break;
      }
    }
    return {
      'name': i.name,
      'category': i.category,
      'weight': weightText(i.weight),
      'costCp': '${i.costCp}',
      'description': i.description,
      'rarity': i.rarity ?? '',
      'requiresAttunement': i.requiresAttunement,
      'acBonus': '${firstAc?.amount ?? 0}',
      'resistances': [
        for (final e in i.effects)
          if (e is ResistanceEffect) e.damageType,
      ],
      'otherEffects': [
        for (final e in i.effects)
          if (e is! ResistanceEffect && !identical(e, firstAc)) e.toJson(),
      ],
      'baseItemKind': i.baseItemKind ?? 'none',
      'magicBonus': '${i.magicBonus}',
      'eligibleBaseItemIds': [...i.eligibleBaseItemIds],
      // Las cargas no se editan, pero el formulario avisa que se conservan.
      'hasCharges': i.maxCharges != null,
    };
  }

  /// Arma el objeto sobre [original]. No lanza por datos inválidos: también
  /// alimenta la vista previa mientras se escribe.
  ///
  /// Lo que el formulario no muestra se conserva del original —`id`, el tamaño
  /// del paquete, la propiedad de base y las cargas con su recarga—, porque un
  /// objeto del catálogo que las tiene deja de ser el mismo objeto sin ellas.
  ///
  /// Un objeto mundano nunca queda sintonizado, diga lo que diga el formulario:
  /// es la defensa de la regla («solo los objetos mágicos se sintonizan»), por
  /// si el formulario llega con una combinación que [withRarity] no armó.
  static Item build(Item original, Map<String, dynamic> form) {
    final rarity = draftText(form['rarity']);
    final kind = draftText(form['baseItemKind']);
    final acBonus = int.tryParse(draftText(form['acBonus'])) ?? 0;
    return Item(
      id: original.id,
      name: draftText(form['name']),
      source: ContentSource.homebrew,
      category: draftText(form['category']),
      weight: double.tryParse(draftText(form['weight'])) ?? 0,
      costCp: int.tryParse(draftText(form['costCp'])) ?? 0,
      bundleSize: original.bundleSize,
      description: draftText(form['description']),
      rarity: rarity.isEmpty ? null : rarity,
      requiresAttunement:
          rarity.isNotEmpty && form['requiresAttunement'] == true,
      magicBonus: int.tryParse(draftText(form['magicBonus'])) ?? 0,
      baseItemKind: kind.isEmpty || kind == 'none' ? null : kind,
      eligibleBaseItemIds: [
        for (final id in (form['eligibleBaseItemIds'] as List? ?? const []))
          id.toString(),
      ],
      eligibleBaseProperty: original.eligibleBaseProperty,
      maxCharges: original.maxCharges,
      rechargeAmount: original.rechargeAmount,
      // El orden de Flutter: la CA, una resistencia por tipo y el resto.
      effects: [
        if (acBonus != 0) ArmorClassBonusEffect(acBonus),
        for (final type in (form['resistances'] as List? ?? const []))
          ResistanceEffect(type.toString()),
        ...Effect.listFromJson(form['otherEffects']),
      ],
    );
  }

  /// Campo → código de error; vacío si se puede guardar (los de
  /// `WeaponDraft.errors`).
  static Map<String, String> errors(Map<String, dynamic> form) {
    final out = <String, String>{};
    if (draftText(form['name']).isEmpty) out['name'] = 'required';
    checkEconomy(out, form);
    checkInt(out, form, 'acBonus', -5, 10, optional: false);
    checkInt(out, form, 'magicBonus', -5, 10, optional: false);
    return out;
  }

  /// Elegir la rareza. Sin rareza no hay objeto mágico, y un objeto mundano no
  /// se sintoniza: dejar el interruptor prendido guardaría una combinación que
  /// el motor considera inválida.
  static Map<String, dynamic> withRarity(
    Map<String, dynamic> form,
    String rarity,
  ) =>
      {
        ...form,
        'rarity': rarity,
        if (rarity.isEmpty) 'requiresAttunement': false,
      };

  /// Elegir la familia del objeto base. Las bases marcadas son de la familia
  /// anterior y no valen para la nueva: el motor las rechazaría igual
  /// (`InventoryOps._validBase`), pero quedarían guardadas y sin nada que las
  /// muestre.
  static Map<String, dynamic> withBaseKind(
    Map<String, dynamic> form,
    String kind,
  ) =>
      {...form, 'baseItemKind': kind, 'eligibleBaseItemIds': <String>[]};

  /// Las bases del catálogo que puede tomar la familia [kind], por su nombre.
  /// Escudo y armadura salen del mismo catálogo y los separa `isShield`.
  static List<({String id, String name})> baseOptions(
    String kind,
    ContentRepository repo,
  ) =>
      switch (kind) {
        'weapon' => [
            for (final w in repo.weaponsSorted) (id: w.id, name: w.name),
          ],
        'armor' => [
            for (final a in repo.armorSorted)
              if (!a.isShield) (id: a.id, name: a.name),
          ],
        'shield' => [
            for (final a in repo.armorSorted)
              if (a.isShield) (id: a.id, name: a.name),
          ],
        _ => const [],
      };
}
