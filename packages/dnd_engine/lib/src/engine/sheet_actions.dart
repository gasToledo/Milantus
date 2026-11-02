import '../data/content_repository.dart';
import '../domain/character.dart';
import '../domain/effects.dart';
import 'character_compiler.dart';
import 'coin_ops.dart';
import 'combat_ops.dart';
import 'dice.dart';
import 'inventory_ops.dart';
import 'level_up.dart';

/// Lo que devuelve [SheetActions.apply]: la ficha nueva y lo que pasó, para
/// el aviso que muestra la pantalla («Te estabilizaste», «Recuperaste 7 PG»).
class SheetActionResult {
  final Character character;

  /// Depende de la acción (ver [SheetActions.apply]); vacío si no hay nada que
  /// contar.
  final Map<String, Object?> outcome;

  const SheetActionResult(this.character, [this.outcome = const {}]);

  Map<String, dynamic> toJson() => {
        'character': character.toJson(),
        'outcome': outcome,
      };
}

/// Las acciones de partida de la ficha propia —PG, salvaciones de muerte,
/// espacios, usos de recursos, dados de golpe y descansos— como **una sola
/// puerta serializable**: la acción es un mapa JSON y el resultado también.
///
/// Existe por el cliente React (`js/entrypoint.dart`), que no puede mutar el
/// `CombatState` como lo hace un widget de Flutter: le pide al motor la ficha
/// ya cambiada y la guarda tal cual. Así ninguna regla (el tope de un recurso,
/// qué recupera un descanso, la recarga al amanecer) se copia en TypeScript.
///
/// No muta la ficha de entrada: trabaja sobre una copia del estado de combate,
/// que `copyWith` pasaría por referencia.
class SheetActions {
  /// Aplica [action] a [character]. Las acciones (`type`) y lo que cuenta cada
  /// una en `outcome`:
  ///
  /// - `damage`, `heal`, `tempHp` con `amount`.
  /// - `deathSave` con `success`; `outcome.deathSave` es `stable`, `dead` o
  ///   `null`.
  /// - `spendSlot`, `recoverSlot` con `level` y `pact`.
  /// - `spendResource`, `recoverResource` con `resource` (la clave del
  ///   recurso) y `amount` (1 si falta).
  /// - `spendHitDie`; `outcome.healed` son los PG recuperados.
  /// - `shortRest`; `outcome.restored` son los nombres de lo que se recargó.
  /// - `longRest`; `outcome` lleva `exhaustion` (el que queda, solo si había),
  ///   `inspirationGained` e `itemsRecharged`.
  /// - `heroicInspiration` con `value`: marcarla o gastarla a mano.
  /// - `concentrate` con `spell` (el nombre, como lo guarda Flutter);
  ///   `outcome.dismissed` son los compañeros que dependían de la concentración
  ///   anterior y se fueron.
  /// - `endConcentration`; `outcome.dismissed` como en `concentrate`.
  /// - `setCondition` con `condition` (el id del estado) y `value`; uno que
  ///   incapacita termina la concentración y los modos, y `outcome.dismissed`
  ///   son los compañeros que se fueron con ella.
  /// - `setExhaustion` con `value` (0 a 6); `outcome.died` es true en el 6.
  /// - `activateMode` con `mode` y `variant` o `variants`; `outcome.activated`
  ///   es false si no se pudo (sin usos, armadura pesada) y la ficha vuelve
  ///   intacta. `deactivateMode` con `mode`.
  /// - Mochila, todas con `entry` (el `entryId`): `equip` y `attune` con
  ///   `value`; `setQuantity` y `setCharges` con `value`; `note` con `text`;
  ///   `offHand` y `twoHanded` alternan la marca del arma; `removeItem` saca
  ///   la línea entera.
  /// - `setCoins` con `coins` (denominación → cantidad).
  /// - `addItem` con `item`: suma sin pagar (botín, regalo).
  /// - `buy` con `item`, `quantity`, `unitPriceCp` y `at` (la fecha del
  ///   asiento en «Cuentas», `AAAA-MM-DD`, que la pone quien llama para que
  ///   el motor no dependa del reloj); `outcome.paid` es false si no alcanzó
  ///   y la ficha vuelve intacta.
  /// - `sell` con `entry`, `quantity`, `unitPriceCp` y `at`.
  /// - `levelUp` con `draft` (`LevelUpDraft.fromJson`): sube el nivel con
  ///   [LevelUp.confirm], PG actuales incluidos.
  /// - `setClassSpells` con `classId`, `cantrips` y `spells`: lo que queda
  ///   elegido para esa clase ([Character.withClassSpells]). No valida el tope:
  ///   una ficha pasada de cupo tiene que poder guardarse mientras se saca de
  ///   a uno. Un `classId` que no es un bloque de lanzamiento ni la clase
  ///   principal no toca la ficha.
  /// - `setInnateCantrip` con `granted` (el conjuro que declara el rasgo) y
  ///   `spell`: cambia un truco innato reemplazable. Un truco que no lo es, o
  ///   un `spell` fuera de [LevelUp.innateCantripOptions], no toca la ficha.
  ///   Ninguna de las dos toca el combate: los espacios y la concentración
  ///   siguen igual, y los usos del truco se indexan por el conjuro original.
  /// - `setMagicItemPlan` con `item` y `value`: marca o desmarca un plano del
  ///   Artífice ([InventoryOps.setMagicItemPlan]); `outcome.removedReplica` es
  ///   true si desmarcarlo se llevó su réplica. `replicateItem` con `item` y
  ///   `base` (opcional): crea la réplica; `outcome.created` es false si no se
  ///   pudo (sin cupo, plano no elegido, base inválida). `transmuteReplica`
  ///   con `entry`, `item` y `base` (opcional). Sin cupo de planos, las tres
  ///   dejan la ficha como estaba; quitar una réplica es `removeItem`.
  /// - `setEffectTarget` con `group` y `entry`: vincula un ejemplar de la
  ///   mochila al cupo (el arma de pacto). `createEffectTarget` con `group` y
  ///   `weapon`: crea el arma del catálogo y la vincula. `clearEffectTargets`
  ///   con `group`: suelta el vínculo y se lleva lo que creó el rasgo. Las tres
  ///   dejan la ficha como estaba si el cupo no existe, si la opción no es
  ///   elegible, si el cupo está lleno y no es reemplazable, o (la tercera)
  ///   si no hay nada que limpiar.
  ///
  /// Una acción desconocida lanza [FormatException]: un cliente desfasado no
  /// tiene que guardar una ficha que el motor no tocó creyendo que sí.
  static SheetActionResult apply(
    Character character,
    ContentRepository repo,
    Map<String, dynamic> action, {
    Dice? dice,
  }) {
    final combat = CombatState.fromJson(character.combat.toJson());
    var c = character.copyWith(combat: combat);
    final sheet = CharacterCompiler(repo).compile(c);
    final amount = (action['amount'] as num?)?.toInt() ?? 0;
    final outcome = <String, Object?>{};

    switch (action['type']) {
      case 'damage':
        CombatOps.applyDamage(combat, amount, sheet: sheet);
      case 'heal':
        CombatOps.applyHealing(combat, sheet.maxHp, amount);
      case 'tempHp':
        CombatOps.setTempHp(combat, amount);
      case 'deathSave':
        outcome['deathSave'] = CombatOps.recordDeathSave(
          combat,
          success: action['success'] == true,
        );
      case 'spendSlot' || 'recoverSlot':
        final level = (action['level'] as num).toInt();
        final pact = action['pact'] == true;
        if (action['type'] == 'spendSlot') {
          CombatOps.spendSlot(
            combat,
            pact ? sheet.pactSlotsByLevel : sheet.normalSpellSlotsByLevel,
            level,
            pact: pact,
          );
        } else {
          CombatOps.recoverSpellSlot(combat, level, pact: pact);
        }
      case 'spendResource' || 'recoverResource':
        final key = action['resource'] as String;
        final resource = sheet.resources.where((r) => r.key == key).firstOrNull;
        // Un recurso que la ficha ya no declara (cambió de clase en Flutter
        // mientras esta copia estaba abierta) no se toca.
        if (resource != null) {
          final n = (action['amount'] as num?)?.toInt() ?? 1;
          final used = combat.resourceUsage[key] ?? 0;
          CombatOps.setResourceUsed(
            combat,
            resource,
            action['type'] == 'spendResource' ? used + n : used - n,
          );
        }
      case 'spendHitDie':
        outcome['healed'] = CombatOps.spendHitDie(
          combat,
          sheet,
          c.level,
          dice: dice,
        );
      case 'shortRest':
        outcome['restored'] = [
          for (final r in sheet.resources)
            if (r.recharge == RechargeOn.shortRest) r.name,
        ];
        CombatOps.shortRest(
          combat,
          sheet.resources,
          spellcasting: sheet.spellcasting,
        );
      case 'longRest':
        final exhaustionBefore = combat.exhaustion;
        final hadInspiration = combat.heroicInspiration;
        CombatOps.longRest(
          combat,
          sheet.maxHp,
          sheet.resources,
          c.level,
          // Sin perfil no hay máximo que calcular: se lo deja como está en
          // vez de inventarle uno.
          companionMaxHp: (instance) =>
              CombatOps.companionMaxHp(sheet, instance) ?? instance.currentHp,
          grantsHeroicInspiration: sheet.heroicInspirationOnLongRest,
        );
        // Los objetos se recargan al amanecer y viven en la mochila, no en el
        // estado de combate (ver el `ponytail:` de `rechargeAtDawn`).
        final (recharged, items) = InventoryOps.rechargeAtDawn(
          c,
          repo,
          dice: dice,
        );
        c = recharged;
        outcome
          ..['exhaustion'] = exhaustionBefore > 0 ? combat.exhaustion : null
          ..['inspirationGained'] = !hadInspiration && combat.heroicInspiration
          ..['itemsRecharged'] = items;
      case 'heroicInspiration':
        combat.heroicInspiration = action['value'] == true;
      case 'concentrate' || 'endConcentration':
        final spell = action['spell'] as String?;
        // Volver a tocar el conjuro en que ya te concentrás no cambia nada en
        // la mesa, pero `startConcentration` despediría a lo que ese mismo
        // conjuro sostiene.
        if (action['type'] == 'concentrate' &&
            combat.concentratingOn == spell) {
          break;
        }
        outcome['dismissed'] = _concentrationCompanions(combat, repo);
        if (action['type'] == 'concentrate') {
          CombatOps.startConcentration(combat, spell!);
        } else {
          CombatOps.endConcentration(combat);
        }
      case 'setCondition':
        final condition = action['condition'] as String;
        final on = action['value'] == true;
        // Solo incapacitar rompe la concentración; los nombres se toman antes
        // de que `setCondition` se lleve a los compañeros que la sostenían.
        if (on && CombatOps.incapacitatingConditions.contains(condition)) {
          outcome['dismissed'] = _concentrationCompanions(combat, repo);
        }
        CombatOps.setCondition(combat, condition, on, sheet: sheet);
      case 'setExhaustion':
        outcome['died'] = CombatOps.setExhaustion(
          combat,
          (action['value'] as num).toInt(),
        );
      case 'activateMode':
        final ok = CombatOps.activateMode(
          combat,
          sheet,
          action['mode'] as String,
          variant: action['variant'] as String?,
          variants: [
            for (final v in (action['variants'] as List?) ?? const [])
              v as String,
          ],
        );
        outcome['activated'] = ok;
        // `activateMode` puede haber dado PG temporales o quitado estados
        // antes de descubrir que no hay usos: un rechazo deja la ficha como
        // estaba, no a medias.
        if (!ok) c = character;
      case 'deactivateMode':
        CombatOps.deactivateMode(
          combat,
          action['mode'] as String,
          sheet: sheet,
        );
      case 'equip':
        c = InventoryOps.setEquipped(
          c,
          action['entry'] as String,
          action['value'] == true,
          repo,
        );
      case 'attune':
        c = InventoryOps.updateEntry(
          c,
          action['entry'] as String,
          (e) => e.copyWith(attuned: action['value'] == true),
        );
      case 'setQuantity':
        // El − se apaga en 1: quitar la línea es otra acción.
        final value = (action['value'] as num).toInt();
        c = InventoryOps.updateEntry(
          c,
          action['entry'] as String,
          (e) => e.copyWith(quantity: value < 1 ? 1 : value),
        );
      case 'setCharges':
        c = InventoryOps.setCharges(
          c,
          action['entry'] as String,
          (action['value'] as num).toInt(),
          repo,
        );
      case 'note':
        c = InventoryOps.updateEntry(
          c,
          action['entry'] as String,
          (e) => e.copyWith(note: action['text'] as String? ?? ''),
        );
      case 'offHand':
        c = InventoryOps.toggleOffHand(c, action['entry'] as String, repo);
      case 'twoHanded':
        c = InventoryOps.toggleTwoHanded(c, action['entry'] as String, repo);
      case 'removeItem':
        final id = action['entry'] as String;
        final entry = c.inventory.where((e) => e.entryId == id).firstOrNull;
        if (entry != null) {
          c = InventoryOps.remove(c, id, repo, quantity: entry.quantity);
        }
      case 'setCoins':
        c = c.copyWith(
          coins: CoinOps.normalize({
            for (final e in (action['coins'] as Map).entries)
              e.key as String: (e.value as num).toInt(),
          }),
        );
      case 'addItem':
        c = InventoryOps.add(c, action['item'] as String);
      case 'buy':
        final bought = InventoryOps.buy(
          c,
          action['item'] as String,
          repo,
          quantity: (action['quantity'] as num).toInt(),
          unitPriceCp: (action['unitPriceCp'] as num).toInt(),
          at: DateTime.parse(action['at'] as String),
        );
        outcome['paid'] = bought != null;
        c = bought ?? c;
      case 'sell':
        c = InventoryOps.sell(
          c,
          action['entry'] as String,
          repo,
          quantity: (action['quantity'] as num).toInt(),
          unitPriceCp: (action['unitPriceCp'] as num).toInt(),
          at: DateTime.parse(action['at'] as String),
        );
      case 'levelUp':
        final up = LevelUp(
          c,
          repo,
          LevelUpDraft.fromJson(action['draft'] as Map<String, dynamic>),
        );
        // Un cliente desfasado no guarda una subida a medias.
        if (!up.complete) {
          throw const FormatException('Subida de nivel incompleta');
        }
        c = up.confirm();
      case 'setClassSpells':
        final classId = action['classId'] as String;
        if (sheet.spellcastingBlocks.any((b) => b.classId == classId) ||
            classId == c.classId) {
          c = c.withClassSpells(
            classId,
            cantrips: [
              for (final id in action['cantrips'] as List) id as String
            ],
            spells: [for (final id in action['spells'] as List) id as String],
          );
        }
      case 'setInnateCantrip':
        final granted = action['granted'] as String;
        final spell = action['spell'] as String;
        final innate = sheet.innateSpells
            .where((s) => s.grantedSpellId == granted && s.isReplaceable)
            .firstOrNull;
        if (innate != null &&
            LevelUp.innateCantripOptions(repo, innate)
                .any((o) => o.id == spell)) {
          c = c.withInnateCantrip(granted, spell);
        }
      case 'setMagicItemPlan':
        final slot = sheet.itemChoiceSlots.firstOrNull;
        if (slot == null) break;
        c = InventoryOps.setMagicItemPlan(
          c,
          slot,
          action['item'] as String,
          action['value'] == true,
        );
        outcome['removedReplica'] =
            c.inventory.length < character.inventory.length;
      case 'replicateItem':
        if (sheet.itemChoiceSlots.isEmpty) break;
        final replicated = InventoryOps.replicateMagicItem(
          c,
          action['item'] as String,
          repo,
          baseItemId: action['base'] as String?,
        );
        outcome['created'] = replicated.inventory.length > c.inventory.length;
        c = replicated;
      case 'transmuteReplica':
        if (sheet.itemChoiceSlots.isEmpty) break;
        c = InventoryOps.transmuteReplica(
          c,
          action['entry'] as String,
          action['item'] as String,
          repo,
          baseItemId: action['base'] as String?,
        );
      case 'setEffectTarget' || 'createEffectTarget' || 'clearEffectTargets':
        final group = action['group'] as String;
        final slot = sheet.targetChoiceSlots
            .where((s) => s.groupId == group)
            .firstOrNull;
        if (slot == null) break;
        final full = slot.chosenEntryIds.length >= slot.count;
        if (action['type'] == 'clearEffectTargets') {
          if (slot.replaceable && slot.chosenEntryIds.isNotEmpty) {
            c = InventoryOps.clearEffectTargets(c, group);
          }
          break;
        }
        // Un cupo lleno y fijo no admite otra elección: sin esto el motor
        // desplazaría la anterior aunque la regla diga que no se cambia.
        if (full && !slot.replaceable) break;
        if (action['type'] == 'setEffectTarget') {
          final entry = action['entry'] as String;
          if (slot.eligibleEntryIds.contains(entry)) {
            c = InventoryOps.setEffectTarget(c, group, entry,
                count: slot.count);
          }
        } else {
          final weapon = action['weapon'] as String;
          if (slot.creatableWeaponIds.contains(weapon)) {
            c = InventoryOps.createEffectTarget(
              c,
              group,
              weapon,
              repo,
              count: slot.count,
            );
          }
        }
      default:
        throw FormatException('Acción de ficha desconocida: ${action['type']}');
    }
    return SheetActionResult(c, outcome);
  }

  /// Los nombres de los compañeros que sostiene la concentración actual: los
  /// que se van si ella termina.
  static List<String> _concentrationCompanions(
    CombatState combat,
    ContentRepository repo,
  ) =>
      [
        for (final i in combat.companions)
          if (i.concentration)
            repo.creature(i.creatureId)?.name ?? i.creatureId,
      ];
}
