import '../data/content_repository.dart';
import '../domain/character.dart';
import '../domain/effects.dart';
import 'character_compiler.dart';
import 'coin_ops.dart';
import 'combat_ops.dart';
import 'dice.dart';
import 'inventory_ops.dart';

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
  /// - Mochila, todas con `entry` (el `entryId`): `equip` y `attune` con
  ///   `value`; `setQuantity` y `setCharges` con `value`; `note` con `text`;
  ///   `offHand` y `twoHanded` alternan la marca del arma; `removeItem` saca
  ///   la línea entera.
  /// - `setCoins` con `coins` (denominación → cantidad).
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
        outcome['dismissed'] = [
          for (final i in combat.companions)
            if (i.concentration)
              repo.creature(i.creatureId)?.name ?? i.creatureId,
        ];
        if (action['type'] == 'concentrate') {
          CombatOps.startConcentration(combat, spell!);
        } else {
          CombatOps.endConcentration(combat);
        }
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
      default:
        throw FormatException('Acción de ficha desconocida: ${action['type']}');
    }
    return SheetActionResult(c, outcome);
  }
}
