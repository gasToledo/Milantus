import '../data/content_repository.dart';
import '../domain/character.dart';
import '../domain/computed_sheet.dart';
import '../domain/creature.dart';
import '../domain/npc.dart';
import 'character_compiler.dart';

/// Los números de combate de un PNJ: con cuántos PG entra a pelear, qué CA
/// muestra la mesa y, en una campaña, si viene herido de un combate anterior.
///
/// Vive en el motor y no en el cliente porque cada respuesta es una regla —
/// resolver la fórmula de PG de un bloque, compilar la ficha de un PNJ
/// jugable—, y los dos clientes (Flutter y React) tienen que dar el mismo
/// número. Es la cuenta de `npcMaxHp`/`npcArmorClass`/`npcStoredHp` de
/// `dnd_app/lib/ui/dm/npcs/npc_shared.dart`, que todavía la repite.
class NpcStats {
  /// PG máximos con los que entra a un combate, o 0 si no tiene con qué
  /// pelear. Un bloque recién creado y todavía vacío cuenta como sin PG.
  final int maxHp;

  /// La CA tal como la imprime el bloque («12 (armadura de cuero)») o la de
  /// la ficha compilada, o null si no tiene.
  final String? armorClass;

  /// La ficha compilada, solo para [NpcSheetKind.character] con ficha.
  final ComputedSheet? sheet;

  const NpcStats._({required this.maxHp, this.armorClass, this.sheet});

  factory NpcStats.of(Npc npc, Character? character, ContentRepository repo) {
    switch (npc.sheetKind) {
      case NpcSheetKind.none:
        return const NpcStats._(maxHp: 0);
      case NpcSheetKind.block:
        final block = npc.block;
        if (block == null) return const NpcStats._(maxHp: 0);
        return NpcStats._(maxHp: _blockMaxHp(block), armorClass: block.ac);
      case NpcSheetKind.character:
        if (character == null) return const NpcStats._(maxHp: 0);
        final sheet = CharacterCompiler(repo).compile(character);
        return NpcStats._(
          maxHp: sheet.maxHp,
          armorClass: '${sheet.armorClass}',
          sheet: sheet,
        );
    }
  }

  /// Una fórmula que no se puede evaluar (un homebrew a medio cargar) cuenta
  /// como sin PG: entra neutral hasta que el DM la complete. Se atrapan las
  /// dos excepciones porque `CreatureFormulaException` no es una
  /// `FormatException`: Flutter solo atrapa la segunda.
  static int _blockMaxHp(Creature block) {
    try {
      return block.resolve(const CreatureVars({})).maxHp;
    } on CreatureFormulaException {
      return 0;
    } on FormatException {
      return 0;
    }
  }

  /// Los PG guardados en una campaña, solo si está vivo y herido: uno muerto
  /// no pelea, y uno entero no tiene nada que avisar. [currentHp] es el del
  /// vínculo (`campaign_npcs.current_hp`), donde null es entero; un valor por
  /// encima del máximo (el bloque se editó después) se lee como el máximo.
  ({int current, int max})? hurt(NpcStatus status, int? currentHp) {
    if (status == NpcStatus.dead || currentHp == null) return null;
    final current = currentHp < maxHp ? currentHp : maxHp;
    return current < maxHp ? (current: current, max: maxHp) : null;
  }
}
