import 'package:postgres/postgres.dart';

/// Una subida de nivel registrada en el Cuaderno de campaña.
///
/// No es un documento de usuario sino una fila de columnas sueltas: no lleva
/// `schemaVersion` ni `fromJson`, porque nadie la manda — la escribe el
/// servidor cuando el jugador guarda su ficha, y el cliente solo la lee.
class LevelUpLog {
  final String id;
  final String? chapterId;
  final String characterName;

  /// El nivel total alcanzado con esta subida.
  final int level;

  /// La clase que ganó este nivel, y en qué nivel de esa clase quedó.
  final String classId;
  final int classLevel;
  final DateTime at;

  const LevelUpLog({
    required this.id,
    required this.chapterId,
    required this.characterName,
    required this.level,
    required this.classId,
    required this.classLevel,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    if (chapterId != null) 'chapterId': chapterId,
    'characterName': characterName,
    'level': level,
    'classId': classId,
    'classLevel': classLevel,
    'at': at.toUtc().toIso8601String(),
  };
}

/// Las subidas de nivel de los personajes vinculados a una campaña, vistas
/// por su DM.
///
/// Se escribe desde el guardado de la ficha **del jugador**, o sea en la
/// campaña de otra cuenta: quien llama a [append] pasa un `dmUserId` que no es
/// el suyo, y es correcto solo porque salió de una fila de `campaign_members`
/// que ya autorizó una consulta anterior. Leer, en cambio, filtra por el DM
/// dentro del `WHERE`, como cualquier tabla de un solo dueño.
abstract class LevelUpRepository {
  Future<void> append(
    String dmUserId,
    String campaignId, {
    required String? chapterId,
    required String characterName,
    required int level,
    required String classId,
    required int classLevel,
  });

  /// De la más nueva a la más vieja. Vacío si la campaña no es de [dmUserId],
  /// sin distinguirlo de una campaña donde nadie subió de nivel.
  Future<List<LevelUpLog>> listFor(String dmUserId, String campaignId);
}

class PostgresLevelUpRepository implements LevelUpRepository {
  final Session _session;

  const PostgresLevelUpRepository(this._session);

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
    await _session.execute(
      Sql.named('''
        INSERT INTO level_up_logs (dm_user_id, campaign_id, chapter_id,
                                   character_name, level, class_id,
                                   class_level)
        VALUES (@dmUserId, @campaignId, @chapterId, @characterName, @level,
                @classId, @classLevel)
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
        'chapterId': TypedValue(Type.text, chapterId),
        'characterName': TypedValue(Type.text, characterName),
        'level': TypedValue(Type.integer, level),
        'classId': TypedValue(Type.text, classId),
        'classLevel': TypedValue(Type.integer, classLevel),
      },
    );
  }

  /// El desempate por `id` no es decorativo: subir dos niveles en un mismo
  /// guardado inserta dos filas en la misma transacción, y `now()` les da la
  /// misma hora a las dos.
  @override
  Future<List<LevelUpLog>> listFor(String dmUserId, String campaignId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT id, chapter_id, character_name, level, class_id, class_level,
               created_at
        FROM level_up_logs
        WHERE dm_user_id = @dmUserId AND campaign_id = @campaignId
        ORDER BY created_at DESC, id DESC
      '''),
      parameters: {
        'dmUserId': TypedValue(Type.uuid, dmUserId),
        'campaignId': TypedValue(Type.text, campaignId),
      },
    );
    return [
      for (final columns in result.map((row) => row.toColumnMap()))
        LevelUpLog(
          id: '${columns['id']}',
          chapterId: columns['chapter_id'] as String?,
          characterName: columns['character_name'] as String,
          level: columns['level'] as int,
          classId: columns['class_id'] as String,
          classLevel: columns['class_level'] as int,
          at: columns['created_at'] as DateTime,
        ),
    ];
  }
}
