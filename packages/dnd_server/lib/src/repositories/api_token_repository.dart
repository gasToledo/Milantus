import 'package:postgres/postgres.dart';

import '../auth/session_token.dart';

/// Lo que se muestra de un token personal: nunca el token mismo, que solo se
/// ve una vez, al crearlo.
class ApiToken {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime expiresAt;

  const ApiToken({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

/// Prefijo del token en claro: deja reconocerlo si aparece pegado en un
/// repositorio o un chat, que es como suelen filtrarse.
const String apiTokenPrefix = 'mlt_';

/// Cuánto vale un token. Lo que se conecta con él es un agente que escribe en
/// la cuenta: si se olvida en una máquina vieja, que deje de servir solo.
const Duration apiTokenTtl = Duration(days: 90);

String generateApiToken() => '$apiTokenPrefix${generateSessionToken()}';

/// Tokens personales de API, para el MCP. Toda consulta que no sea la de
/// [userIdForToken] lleva la cuenta en el `WHERE`, como el resto del servidor.
abstract class ApiTokenRepository {
  /// Crea un token y devuelve sus datos junto al token en claro.
  Future<(ApiToken, String)> create(String userId, String name);

  /// Los tokens vigentes de la cuenta, el más nuevo primero.
  Future<List<ApiToken>> listFor(String userId);

  /// `false` si no existe o es de otra cuenta: las dos cosas responden igual.
  Future<bool> revoke(String userId, String id);

  /// Cuenta dueña del token, o `null` si no existe o venció. Anota el uso.
  Future<String?> userIdForToken(String token);
}

class PostgresApiTokenRepository implements ApiTokenRepository {
  final Session _session;

  const PostgresApiTokenRepository(this._session);

  @override
  Future<(ApiToken, String)> create(String userId, String name) async {
    final token = generateApiToken();
    final result = await _session.execute(
      Sql.named('''
        INSERT INTO api_tokens (id, user_id, name, token_hash, expires_at)
        VALUES (@id, @userId, @name, @tokenHash, @expiresAt)
        RETURNING id, name, created_at, last_used_at, expires_at
      '''),
      parameters: {
        // El id es solo para revocar: no hace falta que sea secreto, pero
        // tampoco que diga cuántos tokens hay.
        'id': TypedValue(Type.text, generateSessionToken().substring(0, 16)),
        'userId': TypedValue(Type.uuid, userId),
        'name': TypedValue(Type.text, name),
        'tokenHash': TypedValue(Type.text, hashSessionToken(token)),
        'expiresAt': TypedValue(
          Type.timestampWithTimezone,
          DateTime.now().toUtc().add(apiTokenTtl),
        ),
      },
    );
    return (_fromRow(result.first.toColumnMap()), token);
  }

  @override
  Future<List<ApiToken>> listFor(String userId) async {
    final result = await _session.execute(
      Sql.named('''
        SELECT id, name, created_at, last_used_at, expires_at FROM api_tokens
        WHERE user_id = @userId AND expires_at > now()
        ORDER BY created_at DESC
      '''),
      parameters: {'userId': TypedValue(Type.uuid, userId)},
    );
    return [for (final row in result) _fromRow(row.toColumnMap())];
  }

  @override
  Future<bool> revoke(String userId, String id) async {
    final result = await _session.execute(
      Sql.named('DELETE FROM api_tokens WHERE id = @id AND user_id = @userId'),
      parameters: {
        'id': TypedValue(Type.text, id),
        'userId': TypedValue(Type.uuid, userId),
      },
    );
    return result.affectedRows > 0;
  }

  @override
  Future<String?> userIdForToken(String token) async {
    // Una sola sentencia busca y anota el uso: el token vencido no matchea y
    // entonces tampoco se toca.
    final result = await _session.execute(
      Sql.named('''
        UPDATE api_tokens SET last_used_at = now()
        WHERE token_hash = @tokenHash AND expires_at > now()
        RETURNING user_id
      '''),
      parameters: {'tokenHash': TypedValue(Type.text, hashSessionToken(token))},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['user_id'] as String;
  }

  ApiToken _fromRow(Map<String, dynamic> row) => ApiToken(
    id: row['id'] as String,
    name: row['name'] as String,
    createdAt: row['created_at'] as DateTime,
    lastUsedAt: row['last_used_at'] as DateTime?,
    expiresAt: row['expires_at'] as DateTime,
  );
}
