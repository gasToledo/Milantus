import '../domain/character.dart';
import '../domain/npc.dart';

/// Una entrada de PNJ tal como la sirve el servidor: `{npc, character?,
/// status?, currentHp?}`.
///
/// Hay dos filas con la misma forma y distinto origen, y el combate las trata
/// distinto: la de la campaña (`GET /api/campaigns/:id/npcs`) siempre trae
/// `status`; la de la biblioteca (`GET /api/npcs`) nunca. Por eso
/// [fromLibrary] es «no tiene estado» y no un campo aparte que alguien tenga
/// que acordarse de mandar.
class EncounterNpc {
  final Npc npc;
  final Character? sheet;
  final String? status;
  final int? currentHp;

  const EncounterNpc({
    required this.npc,
    this.sheet,
    this.status,
    this.currentHp,
  });

  factory EncounterNpc.fromEntry(Map<String, dynamic> raw) {
    final character = raw['character'];
    return EncounterNpc(
      npc: Npc.fromJson((raw['npc'] as Map).cast<String, dynamic>()),
      sheet: character is Map
          ? Character.fromJson(character.cast<String, dynamic>())
          : null,
      status: raw['status'] as String?,
      currentHp: raw['currentHp'] as int?,
    );
  }

  /// Viene de la biblioteca: todavía no está vinculado a la campaña.
  bool get fromLibrary => status == null;
}
