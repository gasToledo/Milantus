import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:shelf/shelf.dart';

/// Lo que habilita un access token del MCP. Escritura incluye lectura: nadie
/// pide poder escribir lo que no puede ver.
enum McpScope {
  lectura('milantus:lectura', 'milantus_lectura'),
  escritura('milantus:escritura', 'milantus_escritura');

  /// Cómo viaja como scope OAuth propio, si Zitadel lo copia al token.
  final String scope;

  /// Cómo viaja como rol del proyecto en Zitadel, si no.
  final String role;

  const McpScope(this.scope, this.role);
}

/// La cuenta y los permisos que un token válido le da a la petición.
class McpPrincipal {
  final String userId;
  final Set<McpScope> scopes;
  const McpPrincipal(this.userId, this.scopes);

  bool allows(McpScope needed) =>
      scopes.contains(needed) ||
      (needed == McpScope.lectura && scopes.contains(McpScope.escritura));
}

/// Clave de contexto de shelf donde [requireMcpToken] deja el
/// [McpPrincipal]. Aparte de la de `requireSession`: una sesión del navegador
/// y un token del MCP no se confunden en ningún handler.
const String mcpPrincipalContextKey = 'dnd_mcp_principal';

extension McpRequest on Request {
  McpPrincipal get mcpPrincipal =>
      context[mcpPrincipalContextKey] as McpPrincipal;
}

/// Verifica los access tokens que Zitadel le emite a Claude.
///
/// JWT con la firma verificada contra las claves públicas del emisor, y no
/// introspección: no hay una llamada de red por petición, y la introspección
/// pide credenciales de cliente que esta API no tiene ni necesita. El costo
/// es que la app de Zitadel tiene que emitir *Token Type: JWT*; con tokens
/// opacos esto responde 401 y lo dice `despliegue.md`.
class McpTokenVerifier {
  final Uri issuer;

  /// Id del proyecto de Milantus: la audiencia obligatoria.
  final String audience;

  /// Trae el JWKS del emisor. Se recibe como función para que las pruebas
  /// firmen con una clave propia sin red.
  final Future<JsonWebKeySet> Function() loadKeys;

  final DateTime Function() now;

  JsonWebKeySet? _keys;
  DateTime? _loadedAt;

  McpTokenVerifier({
    required this.issuer,
    required this.audience,
    required this.loadKeys,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// Lee las claves de `/oauth/v2/keys` del emisor.
  static Future<JsonWebKeySet> Function() jwksFrom(Uri issuer) => () async {
    final response = await http.get(
      issuer.replace(path: '${_trimSlash(issuer.path)}/oauth/v2/keys'),
    );
    if (response.statusCode != 200) {
      throw StateError('JWKS respondió ${response.statusCode}.');
    }
    return JsonWebKeySet.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  };

  /// Las claves de Zitadel rotan sin aviso: un `kid` desconocido recarga el
  /// juego, pero a lo sumo una vez por minuto, para que un token inventado
  /// no convierta cada petición en una llamada al emisor.
  Future<JsonWebKeySet> _keysFor(String? kid) async {
    final cached = _keys;
    final known = cached != null && cached.keys.any((k) => k.keyId == kid);
    final stale =
        _loadedAt == null ||
        now().difference(_loadedAt!) > const Duration(minutes: 1);
    if (cached == null || (!known && stale)) {
      _keys = await loadKeys();
      _loadedAt = now();
    }
    return _keys!;
  }

  /// El `sub` y los permisos del token, o `null` si no vale: firma, emisor,
  /// audiencia o vigencia. Los motivos no se distinguen hacia afuera.
  Future<({String subject, Set<McpScope> scopes})?> verify(String token) async {
    final JsonWebToken jwt;
    try {
      final kid = JoseObject.fromCompactSerialization(
        token,
      ).commonProtectedHeader.keyId;
      final store = JsonWebKeyStore()..addKeySet(await _keysFor(kid));
      jwt = await JsonWebToken.decodeAndVerify(
        token,
        store,
        allowedArguments: const ['RS256', 'RS384', 'RS512', 'ES256'],
      );
    } catch (_) {
      return null;
    }
    final claims = jwt.claims;
    final at = now();
    if (claims.expiry == null || !claims.expiry!.isAfter(at)) return null;
    if (claims.notBefore != null && claims.notBefore!.isAfter(at)) return null;
    if (_trimSlash('${claims.issuer}') != _trimSlash('$issuer')) return null;
    if (!(claims.audience ?? const []).contains(audience)) return null;
    final subject = claims.subject;
    if (subject == null || subject.isEmpty) return null;
    return (subject: subject, scopes: _scopesOf(claims.toJson()));
  }

  /// Los permisos salen del claim `scope` o de los roles del proyecto, lo que
  /// traiga el token: Zitadel no documenta si copia scopes propios, y los
  /// roles por scope (`urn:zitadel:iam:org:project:role:…`) son su mecanismo
  /// documentado. Aceptar los dos deja elegir en Zitadel sin tocar código.
  Set<McpScope> _scopesOf(Map<String, dynamic> claims) {
    final scope = claims['scope'];
    final granted = <String>{
      if (scope is String) ...scope.split(' '),
      if (scope is List) ...scope.whereType<String>(),
    };
    final roles = <String>{
      for (final key in [
        'urn:zitadel:iam:org:project:roles',
        'urn:zitadel:iam:org:project:$audience:roles',
      ])
        if (claims[key] is Map) ...(claims[key] as Map).keys.cast<String>(),
    };
    return {
      for (final s in McpScope.values)
        if (granted.contains(s.scope) || roles.contains(s.role)) s,
    };
  }
}

String _trimSlash(String s) =>
    s.endsWith('/') ? s.substring(0, s.length - 1) : s;

/// URL de la metadata del recurso protegido (RFC 9728) para `/mcp`.
Uri mcpResourceMetadataUrl(Uri publicBaseUrl) => publicBaseUrl.replace(
  path:
      '${_trimSlash(publicBaseUrl.path)}/.well-known/oauth-protected-resource/mcp',
);

/// La metadata que le dice a Claude dónde autorizarse y qué pedir.
Map<String, dynamic> mcpResourceMetadata({
  required Uri publicBaseUrl,
  required Uri issuer,
  required String projectId,
}) => {
  // Tiene que ser exactamente la URL del MCP, con su ruta: Claude la compara.
  'resource': '${_trimSlash('$publicBaseUrl')}/mcp',
  'authorization_servers': [_trimSlash('$issuer')],
  'scopes_supported': mcpRequestedScopes(projectId),
  'bearer_methods_supported': ['header'],
  'resource_name': 'Milantus',
};

/// Lo que Claude pide al autorizarse. La audiencia del proyecto va como scope
/// porque Zitadel no soporta el parámetro `resource` (RFC 8707): sin ella el
/// token sale para otra audiencia y no entra.
///
/// ponytail: se piden los roles del proyecto. Si la prueba contra Zitadel
/// muestra que copia `milantus:lectura`/`milantus:escritura` al token, se
/// cambia esta lista por esos scopes; el verificador ya acepta los dos.
List<String> mcpRequestedScopes(String projectId) => [
  'openid',
  'urn:zitadel:iam:org:project:id:$projectId:aud',
  for (final s in McpScope.values) 'urn:zitadel:iam:org:project:role:${s.role}',
];

/// Exige un access token válido de Zitadel para llegar al MCP. No toca la
/// cookie ni `requireSession`: el login web sigue igual, y este es el único
/// lugar del servidor que acepta un Bearer.
///
/// [resolveAccount] lleva el `sub` a la misma cuenta que usa el login web,
/// creándola si es la primera vez que esa persona entra a Milantus.
Middleware requireMcpToken({
  required McpTokenVerifier verifier,
  required Future<String> Function(String subject) resolveAccount,
  required Uri resourceMetadataUrl,
}) {
  return (Handler inner) => (Request request) async {
    final auth = request.headers['authorization'] ?? '';
    final token = auth.startsWith('Bearer ') ? auth.substring(7).trim() : '';
    final verified = token.isEmpty ? null : await verifier.verify(token);
    if (verified == null) {
      return Response(
        401,
        body: jsonEncode({'error': 'Falta un token válido.'}),
        headers: {
          'content-type': 'application/json',
          // Claude lee `resource_metadata` de acá para saber dónde
          // autorizarse; sin el 401 no lo busca.
          'www-authenticate': [
            'Bearer resource_metadata="$resourceMetadataUrl"',
            if (token.isNotEmpty) 'error="invalid_token"',
          ].join(', '),
        },
      );
    }
    final userId = await resolveAccount(verified.subject);
    return inner(
      request.change(
        context: {
          mcpPrincipalContextKey: McpPrincipal(userId, verified.scopes),
        },
      ),
    );
  };
}
