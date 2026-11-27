import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

import 'id_allocation.dart';

/// Un guion de la Biblioteca con la cantidad de campañas que lo usan: es lo
/// que muestra la lista y lo que dispara el aviso de guion compartido.
class StoredScript {
  final Script script;
  final int campaigns;

  const StoredScript({required this.script, this.campaigns = 0});
}

/// El guion que usa un capítulo y su progreso.
class ChapterScript {
  final Script script;
  final ScriptProgress progress;

  /// Las campañas del guion, para el mismo aviso que [StoredScript].
  final int campaigns;

  const ChapterScript({
    required this.script,
    required this.progress,
    this.campaigns = 0,
  });
}

/// Contrato de persistencia de la biblioteca de guiones y de su uso en los
/// capítulos.
///
/// **Todo es de un solo dueño** y ningún jugador lee de acá. Cada consulta
/// filtra por `dm_user_id = quien pide` dentro del `WHERE`, y un capítulo no
/// puede usar el guion de otra cuenta porque las dos claves foráneas de
/// `chapter_scripts` comparten `dm_user_id`. Lo ajeno y lo inexistente
/// devuelven lo mismo (`null`, `false`, lista vacía).
abstract class ScriptRepository {
  /// Por nombre, sin distinguir mayúsculas.
  Future<List<StoredScript>> listForDm(String dmUserId);

  Future<StoredScript?> find(String dmUserId, String id);

  /// Si el id ya existe en la cuenta se guarda con uno libre, nunca se
  /// sobrescribe, igual que `NoteRepository.create`.
  Future<Script> create(String dmUserId, Script script);

  /// Reemplaza el documento. `false` si no existe en la cuenta.
  Future<bool> save(String dmUserId, Script script);

  /// Los capítulos que lo usaban se quedan sin guion, por cascada.
  Future<void> delete(String dmUserId, String id);

  Future<ChapterScript?> forChapter(
    String dmUserId,
    String campaignId,
    String chapterId,
  );

  /// Pone [scriptId] en el capítulo con [progress] (vacío salvo al duplicar),
  /// reemplazando lo que hubiera. El guion tiene que ser de [dmUserId]: lo
  /// garantiza la foránea.
  Future<void> attach(
    String dmUserId,
    String campaignId,
    String chapterId,
    String scriptId, {
    ScriptProgress progress = const ScriptProgress(),
  });

  /// `false` si el capítulo no tiene guion o no es de [dmUserId].
  Future<bool> saveProgress(
    String dmUserId,
    String campaignId,
    String chapterId,
    ScriptProgress progress,
  );

  Future<void> detach(String dmUserId, String campaignId, String chapterId);
}

class PostgresScriptRepository implements ScriptRepository {
  final Session _session;

  const PostgresScriptRepository(this._session);

  /// Cuántas campañas usan el guion de la fila `s`.
  static const _campaigns = '''
    (SELECT COUNT(DISTINCT used.campaign_id)
       FROM chapter_scripts used
      WHERE used.dm_user_id = s.dm_user_id AND used.script_id = s.id
    ) AS campaigns
  ''';

  @override
  Future<List<StoredScript>> listForDm(String dmUserId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT s.document, s.updated_at, $_campaigns
        FROM scripts s
        WHERE s.dm_user_id = @dmUserId
        ORDER BY lower(s.name), s.id
      '''),
      parameters: {'dmUserId': TypedValue(Type.uuid, dmUserId)},
    );
    return [for (final row in result) _storedOf(row.toColumnMap())];
  }

  @override
  Future<StoredScript?> find(String dmUserId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT s.document, s.updated_at, $_campaigns
        FROM scripts s
        WHERE s.dm_user_id = @dmUserId AND s.id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, id),
      },
    );
    if (result.isEmpty) return null;
    return _storedOf(result.first.toColumnMap());
  }

  @override
  Future<Script> create(String dmUserId, Script script) async {
    var candidate = script;
    while (true) {
      try {
        await _session.execute(
          Sql.named('''
            INSERT INTO scripts (dm_user_id, id, document)
            VALUES (@dmUserId, @id, @document)
          '''),
          parameters: {
            'dmUserId': TypedValue(Type.uuid, dmUserId),
            'id': TypedValue(Type.text, candidate.id),
            'document': TypedValue(Type.jsonb, candidate.toJson()),
          },
        );
        return candidate;
      } on UniqueViolationException {
        candidate = candidate.copyWith(
          id: resolveStorageId(
            requestedId: candidate.id,
            existingIds: {candidate.id},
            fallbackId: () => DateTime.now().microsecondsSinceEpoch.toString(),
          ),
        );
      }
    }
  }

  @override
  Future<bool> save(String dmUserId, Script script) async {
    final result = await _session.execute(
      Sql.named('''
        UPDATE scripts SET document = @document, updated_at = now()
        WHERE dm_user_id = @dmUserId AND id = @id
        RETURNING id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, script.id),
        'document': TypedValue(Type.jsonb, script.toJson()),
      },
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> delete(String dmUserId, String id) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM scripts WHERE dm_user_id = @dmUserId AND id = @id
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'id': TypedValue(Type.text, id),
      },
    );
  }

  @override
  Future<ChapterScript?> forChapter(
    String dmUserId,
    String campaignId,
    String chapterId,
  ) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT s.document, s.updated_at, cs.reached, cs.chosen, cs.shared,
               $_campaigns
        FROM chapter_scripts cs
        JOIN scripts s ON s.dm_user_id = cs.dm_user_id AND s.id = cs.script_id
        WHERE cs.dm_user_id = @dmUserId
          AND cs.campaign_id = @campaignId
          AND cs.chapter_id = @chapterId
      '''),
      parameters: _chapterKey(dmUserId, campaignId, chapterId),
    );
    if (result.isEmpty) return null;
    final columns = result.first.toColumnMap();
    final stored = _storedOf(columns);
    return ChapterScript(
      script: stored.script,
      campaigns: stored.campaigns,
      progress: ScriptProgress.fromJson(columns),
    );
  }

  @override
  Future<void> attach(
    String dmUserId,
    String campaignId,
    String chapterId,
    String scriptId, {
    ScriptProgress progress = const ScriptProgress(),
  }) async {
    await _session.execute(
      Sql.named('''
        INSERT INTO chapter_scripts (dm_user_id, campaign_id, chapter_id,
                                     script_id, reached, chosen, shared)
        VALUES (@dmUserId, @campaignId, @chapterId, @scriptId, @reached,
                @chosen, @shared)
        ON CONFLICT (dm_user_id, campaign_id, chapter_id)
        DO UPDATE SET script_id = excluded.script_id,
                      reached = excluded.reached,
                      chosen = excluded.chosen,
                      shared = excluded.shared,
                      updated_at = now()
      '''),
      parameters: {
        ..._chapterKey(dmUserId, campaignId, chapterId),
        'scriptId': TypedValue(Type.text, scriptId),
        ..._progressColumns(progress),
      },
    );
  }

  @override
  Future<bool> saveProgress(
    String dmUserId,
    String campaignId,
    String chapterId,
    ScriptProgress progress,
  ) async {
    final result = await _session.execute(
      Sql.named('''
        UPDATE chapter_scripts
        SET reached = @reached, chosen = @chosen, shared = @shared,
            updated_at = now()
        WHERE dm_user_id = @dmUserId
          AND campaign_id = @campaignId
          AND chapter_id = @chapterId
        RETURNING chapter_id
      '''),
      parameters: {
        ..._chapterKey(dmUserId, campaignId, chapterId),
        ..._progressColumns(progress),
      },
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> detach(
    String dmUserId,
    String campaignId,
    String chapterId,
  ) async {
    await _session.execute(
      Sql.named('''
        DELETE FROM chapter_scripts
        WHERE dm_user_id = @dmUserId
          AND campaign_id = @campaignId
          AND chapter_id = @chapterId
      '''),
      parameters: _chapterKey(dmUserId, campaignId, chapterId),
    );
  }

  Map<String, Object> _chapterKey(
    String dmUserId,
    String campaignId,
    String chapterId,
  ) => {
    'dmUserId': TypedValue(Type.uuid, dmUserId),
    'campaignId': TypedValue(Type.text, campaignId),
    'chapterId': TypedValue(Type.text, chapterId),
  };

  Map<String, Object> _progressColumns(ScriptProgress progress) => {
    'reached': TypedValue(Type.textArray, [...progress.reached]),
    'chosen': TypedValue(Type.jsonb, progress.chosen),
    'shared': TypedValue(Type.textArray, [...progress.shared]),
  };

  /// La columna `updated_at` pisa lo que traiga el documento, como en las
  /// notas.
  StoredScript _storedOf(Map<String, dynamic> columns) {
    final updatedAt = columns['updated_at'] as DateTime?;
    return StoredScript(
      script: Script.fromJson({
        ...(columns['document'] as Map).cast<String, dynamic>(),
        if (updatedAt != null) 'updatedAt': updatedAt.toIso8601String(),
      }),
      campaigns: columns['campaigns'] as int,
    );
  }
}
