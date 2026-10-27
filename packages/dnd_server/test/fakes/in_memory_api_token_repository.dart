import 'package:dnd_server/src/auth/session_token.dart';
import 'package:dnd_server/src/repositories/api_token_repository.dart';

/// Reimplementa en Dart el `WHERE user_id = …` y el vencimiento del SQL.
class InMemoryApiTokenRepository implements ApiTokenRepository {
  final Map<String, ({String userId, String hash, ApiToken token})> _byId = {};
  int _counter = 0;

  /// Vence un token ya creado, para probar que deja de servir.
  void expire(String id) {
    final row = _byId[id]!;
    final t = row.token;
    _byId[id] = (
      userId: row.userId,
      hash: row.hash,
      token: ApiToken(
        id: t.id,
        name: t.name,
        createdAt: t.createdAt,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
  }

  @override
  Future<(ApiToken, String)> create(String userId, String name) async {
    final secret = generateApiToken();
    final now = DateTime.now();
    final token = ApiToken(
      id: 'token-${_counter++}',
      name: name,
      createdAt: now,
      expiresAt: now.add(apiTokenTtl),
    );
    _byId[token.id] = (
      userId: userId,
      hash: hashSessionToken(secret),
      token: token,
    );
    return (token, secret);
  }

  @override
  Future<List<ApiToken>> listFor(String userId) async => [
    for (final row in _byId.values)
      if (row.userId == userId && row.token.expiresAt.isAfter(DateTime.now()))
        row.token,
  ];

  @override
  Future<bool> revoke(String userId, String id) async {
    if (_byId[id]?.userId != userId) return false;
    _byId.remove(id);
    return true;
  }

  @override
  Future<String?> userIdForToken(String token) async {
    final hash = hashSessionToken(token);
    for (final row in _byId.values) {
      if (row.hash == hash && row.token.expiresAt.isAfter(DateTime.now())) {
        return row.userId;
      }
    }
    return null;
  }
}
