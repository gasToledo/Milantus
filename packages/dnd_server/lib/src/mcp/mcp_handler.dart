import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../auth/mcp_token.dart';
import '../feedback/feedback_mail.dart';
import '../repositories/mcp_audit_repository.dart';

/// Versiones del protocolo MCP que se hablan, de la más nueva a la más
/// vieja. Si el cliente pide una que no está, se contesta la primera y
/// decide él; es lo que pide la especificación.
const List<String> mcpProtocolVersions = ['2025-11-25', '2025-06-18'];

/// Una herramienta del MCP. El esquema de entrada se declara estricto
/// (`additionalProperties: false`) y el handler lo hace cumplir: un argumento
/// de más es un error que Claude tiene que leer, no algo que se ignora.
class McpTool {
  final String name;
  final String title;

  /// Pensada para el modelo: cuándo usarla y qué devuelve.
  final String description;
  final Map<String, Map<String, dynamic>> properties;
  final List<String> required;

  /// Lo que hace falta para llamarla. Toda herramienta que escribe pide
  /// escritura.
  final McpScope scope;
  final bool destructive;
  final bool idempotent;
  final Future<McpResult> Function(McpPrincipal who, McpArgs args) run;

  const McpTool({
    required this.name,
    required this.title,
    required this.description,
    required this.properties,
    this.required = const [],
    required this.scope,
    this.destructive = false,
    this.idempotent = true,
    required this.run,
  });

  bool get readOnly => scope == McpScope.lectura;

  Map<String, dynamic> toJson() => {
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': {
      'type': 'object',
      'properties': properties,
      'required': required,
      'additionalProperties': false,
    },
    'annotations': {
      'title': title,
      'readOnlyHint': readOnly,
      if (!readOnly) 'destructiveHint': destructive,
      if (!readOnly) 'idempotentHint': idempotent,
      // Solo toca la cuenta en Milantus: nada fuera de este servidor.
      'openWorldHint': false,
    },
  };
}

/// Lo que devuelve una herramienta: el dato estructurado y una línea para
/// leer. Los listados van envueltos en un objeto, que es lo que admite
/// `structuredContent`.
class McpResult {
  final Map<String, dynamic> data;
  final String summary;
  const McpResult(this.data, this.summary);
}

/// Un error que Claude tiene que leer y corregir: viaja como resultado con
/// `isError`, no como error del protocolo.
class McpToolError implements Exception {
  final String message;
  const McpToolError(this.message);
  @override
  String toString() => message;
}

/// Lectura de los argumentos contra el esquema declarado.
class McpArgs {
  final Map<String, dynamic> raw;
  const McpArgs(this.raw);

  String str(String key) {
    final v = raw[key];
    if (v is! String || v.trim().isEmpty) throw McpToolError('Falta «$key».');
    return v.trim();
  }

  String? optStr(String key) {
    final v = raw[key];
    if (v == null) return null;
    if (v is! String) throw McpToolError('«$key» tiene que ser texto.');
    return v;
  }

  int integer(String key, {int min = 0}) {
    final v = raw[key];
    if (v is! int || v < min) {
      throw McpToolError(
        '«$key» tiene que ser un entero mayor o igual a $min.',
      );
    }
    return v;
  }

  bool boolean(String key) {
    final v = raw[key];
    if (v is! bool) {
      throw McpToolError('«$key» tiene que ser verdadero o falso.');
    }
    return v;
  }

  List<String>? optStrList(String key) {
    final v = raw[key];
    if (v == null) return null;
    if (v is! List || v.any((e) => e is! String)) {
      throw McpToolError('«$key» tiene que ser una lista de textos.');
    }
    return v.cast<String>();
  }

  Map<String, dynamic> obj(String key) {
    final v = raw[key];
    if (v is! Map<String, dynamic>) {
      throw McpToolError('«$key» tiene que ser un objeto.');
    }
    return v;
  }

  String oneOf(String key, Iterable<String> values) {
    final v = str(key);
    if (!values.contains(v)) {
      throw McpToolError('«$key» tiene que ser uno de: ${values.join(', ')}.');
    }
    return v;
  }

  bool has(String key) => raw.containsKey(key);
}

/// Pagina un listado con un cursor opaco (la posición, en texto). Los
/// listados son chicos: no hace falta un cursor que sobreviva a cambios.
Map<String, dynamic> mcpPage(
  List<Object?> items,
  McpArgs args, {
  int size = 50,
}) {
  final cursor = args.optStr('cursor');
  final start = cursor == null ? 0 : int.tryParse(cursor);
  if (start == null || start < 0) throw const McpToolError('Cursor inválido.');
  final from = start.clamp(0, items.length);
  final end = (from + size).clamp(0, items.length);
  return {
    'items': items.sublist(from, end),
    'total': items.length,
    if (end < items.length) 'nextCursor': '$end',
  };
}

const Map<String, dynamic> mcpCursorProperty = {
  'type': 'string',
  'description': 'El nextCursor de la página anterior, para seguir.',
};

/// Servidor MCP sobre HTTP «Streamable» en su forma mínima: cada POST trae
/// un mensaje JSON-RPC y se contesta con JSON, sin SSE ni sesión. Ninguna
/// herramienta avisa nada por su cuenta, así que el túnel no sostiene
/// conexiones abiertas.
///
/// Escrito a mano y no con un SDK: `dart_mcp`, el del equipo de Dart, no
/// trae Streamable HTTP, y `mcp_dart` suma una dependencia que cambia rápido
/// para lo que acá son cuatro métodos.
///
/// Va detrás de `requireMcpToken`: la petición ya trae la cuenta.
Handler mcpHandler({
  required List<McpTool> tools,
  required String allowedOrigin,
  required String resourceMetadataUrl,
  required McpAuditRepository audit,
  FeedbackRateLimiter? limiter,
}) {
  // Un agente que entra en un bucle no tiene que poder martillar la base. Se
  // reusa el limitador de sugerencias: es el mismo problema, a otra escala.
  final calls =
      limiter ??
      FeedbackRateLimiter(maxPerWindow: 60, window: const Duration(minutes: 1));
  final byName = {for (final t in tools) t.name: t};

  return (Request request) async {
    // Un navegador manda `Origin`; Claude, desde su servidor, no. Si viene,
    // tiene que ser la propia app: lo pide la especificación contra el
    // rebinding de DNS.
    final origin = request.headers['origin'];
    if (origin != null && origin != allowedOrigin) {
      return _rpc(
        null,
        status: 403,
        error: {'code': -32600, 'message': 'Origen no permitido.'},
      );
    }
    if (request.method != 'POST') {
      // Sin SSE no hay nada que abrir con GET; la especificación pide 405.
      return Response(405, headers: {'allow': 'POST'});
    }

    final Object? message;
    try {
      message = jsonDecode(await request.readAsString());
    } on FormatException {
      return _rpc(null, error: {'code': -32700, 'message': 'JSON inválido.'});
    }
    if (message is! Map<String, dynamic> || message['jsonrpc'] != '2.0') {
      return _rpc(
        null,
        error: {
          'code': -32600,
          'message': 'Se esperaba un mensaje JSON-RPC 2.0.',
        },
      );
    }
    final id = message['id'];
    // Una notificación (`notifications/initialized`) no lleva respuesta.
    if (id == null) return Response(202);

    final params = message['params'] is Map<String, dynamic>
        ? message['params'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final who = request.mcpPrincipal;
    switch (message['method']) {
      case 'initialize':
        final asked = params['protocolVersion'];
        return _rpc(
          id,
          result: {
            'protocolVersion': mcpProtocolVersions.contains(asked)
                ? asked
                : mcpProtocolVersions.first,
            'capabilities': {'tools': <String, dynamic>{}},
            'serverInfo': {'name': 'milantus', 'version': '1.0.0'},
            'instructions': _instructions,
          },
        );
      case 'ping':
        return _rpc(id, result: <String, dynamic>{});
      case 'tools/list':
        return _rpc(
          id,
          result: {
            'tools': [for (final t in tools) t.toJson()],
          },
        );
      case 'tools/call':
        final tool = byName[params['name']];
        if (tool == null) {
          return _rpc(
            id,
            error: {'code': -32602, 'message': 'Herramienta desconocida.'},
          );
        }
        if (!who.allows(tool.scope)) {
          await audit.record(who.userId, tool.name, 'sin_permiso');
          // 403 con `insufficient_scope`: Claude vuelve a autorizarse
          // pidiendo lo que falta.
          return Response(
            403,
            body: jsonEncode({
              'error': 'El token no permite ${tool.scope.scope}.',
            }),
            headers: {
              'content-type': 'application/json',
              'www-authenticate':
                  'Bearer error="insufficient_scope", '
                  'scope="${tool.scope.scope}", '
                  'resource_metadata="$resourceMetadataUrl"',
            },
          );
        }
        if (!calls.allows(who.userId)) {
          await audit.record(who.userId, tool.name, 'limite');
          return Response(
            429,
            body: jsonEncode({
              'error': 'Demasiadas llamadas. Esperá un minuto.',
            }),
            headers: {'content-type': 'application/json', 'retry-after': '60'},
          );
        }
        calls.record(who.userId);
        final args = params['arguments'] ?? <String, dynamic>{};
        try {
          if (args is! Map<String, dynamic>) {
            throw const McpToolError(
              'Los argumentos tienen que ser un objeto.',
            );
          }
          final unknown = args.keys.where(
            (k) => !tool.properties.containsKey(k),
          );
          if (unknown.isNotEmpty) {
            throw McpToolError('Argumento desconocido: «${unknown.first}».');
          }
          final out = await tool.run(who, McpArgs(args));
          await audit.record(who.userId, tool.name, 'ok');
          return _rpc(
            id,
            result: {
              'content': [
                {'type': 'text', 'text': out.summary},
              ],
              'structuredContent': out.data,
              'isError': false,
            },
          );
        } on McpToolError catch (e) {
          await audit.record(who.userId, tool.name, 'error');
          return _toolError(id, e.message);
        } on FormatException catch (e) {
          await audit.record(who.userId, tool.name, 'error');
          return _toolError(id, e.message);
        }
      default:
        return _rpc(
          id,
          error: {'code': -32601, 'message': 'Método desconocido.'},
        );
    }
  };
}

const String _instructions =
    'Milantus es una app de D&D 5e (reglas 2024) con fichas de personaje y '
    'un Modo DM. Estas herramientas leen y operan la cuenta de quien se '
    'conectó: sus personajes, las campañas que dirige o en las que juega, su '
    'homebrew y el catálogo SRD. Los números de una ficha los calcula '
    'Milantus: no los recalcules. Las fichas de otros jugadores no se '
    'escriben nunca, ni siquiera como DM. Borrar se hace desde la app.';

Response _toolError(Object? id, String message) => _rpc(
  id,
  result: {
    'content': [
      {'type': 'text', 'text': message},
    ],
    'isError': true,
  },
);

Response _rpc(
  Object? id, {
  Object? result,
  Map<String, dynamic>? error,
  int status = 200,
}) => Response(
  status,
  body: jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    if (error != null) 'error': error else 'result': result,
  }),
  headers: {'content-type': 'application/json'},
);
