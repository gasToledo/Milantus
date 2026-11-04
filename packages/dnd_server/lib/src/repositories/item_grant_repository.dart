import 'package:postgres/postgres.dart';

/// Un objeto que el DM le repartió a un personaje y que su jugador todavía no
/// aceptó ni descartó.
///
/// No es un documento de usuario (nadie lo manda): lo escribe el servidor al
/// cerrar un capítulo, así que no lleva `schemaVersion`.
class ItemGrant {
  final String id;
  final String characterId;
  final String campaignName;
  final String chapterName;

  /// `{ category, itemId, name, baseItemId?, quantity, homebrewDocument? }`.
  /// `homebrewDocument` es la copia del documento del DM, que el jugador recibe
  /// al aceptar; **nunca viaja al cliente** (`toPublicJson` lo deja afuera).
  final Map<String, dynamic> item;
  final DateTime createdAt;

  const ItemGrant({
    required this.id,
    required this.characterId,
    required this.campaignName,
    required this.chapterName,
    required this.item,
    required this.createdAt,
  });

  bool get isHomebrew => item['homebrewDocument'] is Map;

  Map<String, dynamic> toPublicJson() => {
    'id': id,
    'campaignName': campaignName,
    'chapterName': chapterName,
    'category': item['category'],
    'itemId': item['itemId'],
    'name': item['name'],
    'baseItemId': item['baseItemId'],
    'quantity': item['quantity'] ?? 1,
    'homebrew': isHomebrew,
  };
}

/// La bandeja de objetos repartidos por un DM.
///
/// **Todo método lleva el dueño en el `WHERE`**: no existe forma de leer ni
/// tocar el regalo de otra cuenta, y lo ajeno responde igual que lo
/// inexistente. La única excepción es [addAll], que escribe en la cuenta del
/// jugador: el `ownerUserId` que recibe salió de una fila de
/// `campaign_members` que una consulta anterior del DM ya autorizó, nunca del
/// pedido (`modo-dm.md`).
abstract class ItemGrantRepository {
  Future<void> addAll(
    String ownerUserId,
    String characterId,
    String campaignName,
    String chapterName,
    List<Map<String, dynamic>> items,
  );

  Future<List<ItemGrant>> listFor(String ownerUserId, String characterId);

  Future<ItemGrant?> find(String ownerUserId, String id);

  /// Si borró algo. Un id ajeno devuelve `false`, igual que uno inexistente.
  Future<bool> delete(String ownerUserId, String id);
}

class PostgresItemGrantRepository implements ItemGrantRepository {
  final Session _session;

  const PostgresItemGrantRepository(this._session);

  @override
  Future<void> addAll(
    String ownerUserId,
    String characterId,
    String campaignName,
    String chapterName,
    List<Map<String, dynamic>> items,
  ) async {
    for (final item in items) {
      await _session.execute(
        Sql.named('''
          INSERT INTO item_grants
            (owner_user_id, character_id, campaign_name, chapter_name, item)
          VALUES (@owner, @characterId, @campaignName, @chapterName, @item)
        '''),
        parameters: {
          'owner': TypedValue(Type.uuid, ownerUserId),
          'characterId': TypedValue(Type.text, characterId),
          'campaignName': TypedValue(Type.text, campaignName),
          'chapterName': TypedValue(Type.text, chapterName),
          'item': TypedValue(Type.jsonb, item),
        },
      );
    }
  }

  @override
  Future<List<ItemGrant>> listFor(
    String ownerUserId,
    String characterId,
  ) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT id, character_id, campaign_name, chapter_name, item, created_at
        FROM item_grants
        WHERE owner_user_id = @owner AND character_id = @characterId
        ORDER BY created_at, id
      '''),
      parameters: {
        'owner': TypedValue(Type.uuid, ownerUserId),
        'characterId': TypedValue(Type.text, characterId),
      },
    );
    return [for (final row in result) _fromRow(row.toColumnMap())];
  }

  @override
  Future<ItemGrant?> find(String ownerUserId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT id, character_id, campaign_name, chapter_name, item, created_at
        FROM item_grants
        WHERE owner_user_id = @owner AND id = @id
      '''),
      parameters: {
        'owner': TypedValue(Type.uuid, ownerUserId),
        'id': TypedValue(Type.uuid, id),
      },
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  @override
  Future<bool> delete(String ownerUserId, String id) async {
    final result = await _session.execute(
      Sql.named('''
        DELETE FROM item_grants
        WHERE owner_user_id = @owner AND id = @id
        RETURNING id
      '''),
      parameters: {
        'owner': TypedValue(Type.uuid, ownerUserId),
        'id': TypedValue(Type.uuid, id),
      },
    );
    return result.isNotEmpty;
  }

  ItemGrant _fromRow(Map<String, dynamic> c) => ItemGrant(
    id: c['id'] as String,
    characterId: c['character_id'] as String,
    campaignName: c['campaign_name'] as String,
    chapterName: c['chapter_name'] as String,
    item: (c['item'] as Map).cast<String, dynamic>(),
    createdAt: c['created_at'] as DateTime,
  );
}
