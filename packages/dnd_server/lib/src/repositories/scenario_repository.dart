import 'dart:typed_data';

import 'package:postgres/postgres.dart';

class StoredScenario {
  final String id;
  final String name;
  final String description;
  final List<String> characterKeys;
  final bool hasImage;
  final DateTime updatedAt;

  const StoredScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.characterKeys,
    required this.hasImage,
    required this.updatedAt,
  });

  factory StoredScenario._fromRow(Map<String, dynamic> row) => StoredScenario(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String,
    characterKeys: (row['character_keys'] as List).cast<String>(),
    hasImage: row['has_image'] as bool,
    updatedAt: row['updated_at'] as DateTime,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'characterKeys': characterKeys,
    'hasImage': hasImage,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

typedef ScenarioCharacter = ({
  String key,
  String name,
  String? campaignId,
  String? campaignName,
});

class ScenarioDraft {
  final String name;
  final String description;
  final List<String>? characterKeys;

  // Una edición de texto puede viajar junto a un reemplazo o borrado de la
  // portada. Si se omite la imagen, se conserva la que haya al guardar.
  final bool imageChanged;
  final Uint8List? image;

  const ScenarioDraft({
    required this.name,
    required this.description,
    this.characterKeys,
    this.imageChanged = false,
    this.image,
  });
}

abstract class ScenarioRepository {
  Future<List<StoredScenario>> listForDm(String dmUserId);
  Future<StoredScenario?> find(String dmUserId, String id);
  Future<StoredScenario> create(String dmUserId, ScenarioDraft draft);
  Future<StoredScenario?> save(String dmUserId, String id, ScenarioDraft draft);
  Future<bool> delete(String dmUserId, String id);
  Future<Uint8List?> readImage(String dmUserId, String id);
  Future<List<ScenarioCharacter>> listCharacters(String dmUserId);
}

class PostgresScenarioRepository implements ScenarioRepository {
  final Session _session;

  const PostgresScenarioRepository(this._session);

  static const _columns =
      'id, name, description, character_keys, image IS NOT NULL AS has_image, updated_at';

  @override
  Future<List<StoredScenario>> listForDm(String dmUserId) async {
    final rows = await _session.execute(
      Sql.named('''
        SELECT $_columns FROM scenarios
        WHERE dm_user_id = @dmUserId
        ORDER BY lower(name), id
      '''),
      parameters: _owner(dmUserId),
    );
    return [for (final row in rows) StoredScenario._fromRow(row.toColumnMap())];
  }

  @override
  Future<StoredScenario?> find(String dmUserId, String id) async {
    final rows = await _session.execute(
      Sql.named('''
        SELECT $_columns FROM scenarios WHERE dm_user_id = @dmUserId AND id = @id
      '''),
      parameters: _owner(dmUserId, id),
    );
    return rows.isEmpty
        ? null
        : StoredScenario._fromRow(rows.single.toColumnMap());
  }

  @override
  Future<StoredScenario> create(String dmUserId, ScenarioDraft draft) async {
    final rows = await _session.execute(
      Sql.named('''
        INSERT INTO scenarios (dm_user_id, name, description, character_keys, image)
        VALUES (@dmUserId, @name, @description, COALESCE(@keys, '{}'), @image)
        RETURNING $_columns
      '''),
      parameters: {..._owner(dmUserId), ..._draft(draft)},
    );
    return StoredScenario._fromRow(rows.single.toColumnMap());
  }

  @override
  Future<StoredScenario?> save(
    String dmUserId,
    String id,
    ScenarioDraft draft,
  ) async {
    final rows = await _session.execute(
      Sql.named('''
        UPDATE scenarios
        SET name = @name, description = @description,
            character_keys = COALESCE(@keys, character_keys),
            image = CASE WHEN @imageChanged THEN @image ELSE image END,
            updated_at = clock_timestamp()
        WHERE dm_user_id = @dmUserId AND id = @id
        RETURNING $_columns
      '''),
      parameters: {
        ..._owner(dmUserId, id),
        ..._draft(draft),
        'imageChanged': TypedValue(Type.boolean, draft.imageChanged),
      },
    );
    return rows.isEmpty
        ? null
        : StoredScenario._fromRow(rows.single.toColumnMap());
  }

  @override
  Future<bool> delete(String dmUserId, String id) async {
    final rows = await _session.execute(
      Sql.named(
        'DELETE FROM scenarios WHERE dm_user_id = @dmUserId AND id = @id',
      ),
      parameters: _owner(dmUserId, id),
    );
    return rows.affectedRows > 0;
  }

  @override
  Future<Uint8List?> readImage(String dmUserId, String id) async {
    final rows = await _session.execute(
      Sql.named(
        'SELECT image FROM scenarios WHERE dm_user_id = @dmUserId AND id = @id',
      ),
      parameters: _owner(dmUserId, id),
    );
    final bytes = rows.isEmpty ? null : rows.single.single as List<int>?;
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<List<ScenarioCharacter>> listCharacters(String dmUserId) async {
    final rows = await _session.execute(
      Sql.named('''
        SELECT 'npc:' || n.id AS key, n.name,
               NULL::text AS campaign_id, NULL::text AS campaign_name
        FROM npcs n
        WHERE n.dm_user_id = @dmUserId
        UNION ALL
        SELECT 'member:' || m.id::text, ch.name, c.id, c.name
        FROM campaign_members m
        JOIN characters ch ON ch.user_id = m.owner_user_id AND ch.id = m.character_id
        JOIN campaigns c ON c.dm_user_id = m.dm_user_id AND c.id = m.campaign_id
        WHERE m.dm_user_id = @dmUserId
        ORDER BY name, key
      '''),
      parameters: _owner(dmUserId),
    );
    return [
      for (final row in rows.map((row) => row.toColumnMap()))
        (
          key: row['key'] as String,
          name: row['name'] as String,
          campaignId: row['campaign_id'] as String?,
          campaignName: row['campaign_name'] as String?,
        ),
    ];
  }

  Map<String, TypedValue> _owner(String dmUserId, [String? id]) => {
    'dmUserId': TypedValue(Type.uuid, dmUserId),
    if (id != null) 'id': TypedValue(Type.uuid, id),
  };

  Map<String, TypedValue> _draft(ScenarioDraft draft) => {
    'name': TypedValue(Type.text, draft.name),
    'description': TypedValue(Type.text, draft.description),
    'keys': TypedValue(Type.textArray, draft.characterKeys),
    'image': TypedValue(Type.byteArray, draft.image),
  };
}
