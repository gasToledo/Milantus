import 'package:dnd_server/src/repositories/level_up_repository.dart';

import 'in_memory_campaign_repository.dart';

/// Doble de [LevelUpRepository] en memoria para las pruebas HTTP.
class InMemoryLevelUpRepository implements LevelUpRepository {
  InMemoryLevelUpRepository(InMemoryCampaignRepository campaigns) {
    // Reproduce la clave foránea en cascada de la campaña. Borrar un capítulo
    // no toca nada, igual que en la base: no hay foránea hacia `chapters`.
    campaigns.onCampaignDeleted.add((dmUserId, campaignId) {
      _rows.removeWhere(
        (r) => r.dmUserId == dmUserId && r.campaignId == campaignId,
      );
    });
  }

  final List<({String dmUserId, String campaignId, LevelUpLog log})> _rows = [];

  /// Como la secuencia real: un rollback no devuelve los ids que gastó.
  int _nextId = 0;

  Object snapshot() => List.of(_rows);

  void restore(Object raw) => _rows
    ..clear()
    ..addAll(
      raw as List<({String dmUserId, String campaignId, LevelUpLog log})>,
    );

  @override
  Future<void> append(
    String dmUserId,
    String campaignId, {
    required String? chapterId,
    required String characterName,
    required int level,
    required String classId,
    required int classLevel,
  }) async {
    _rows.add((
      dmUserId: dmUserId,
      campaignId: campaignId,
      log: LevelUpLog(
        id: '${++_nextId}',
        chapterId: chapterId,
        characterName: characterName,
        level: level,
        classId: classId,
        classLevel: classLevel,
        at: DateTime.now().toUtc(),
      ),
    ));
  }

  /// Del más nuevo al más viejo: el orden de alta invertido reproduce el
  /// `ORDER BY created_at DESC, id DESC` real sin depender del reloj.
  @override
  Future<List<LevelUpLog>> listFor(String dmUserId, String campaignId) async =>
      [
        for (final r in _rows.reversed)
          if (r.dmUserId == dmUserId && r.campaignId == campaignId) r.log,
      ];
}
