import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'session_cookie.dart';

/// Clave de contexto de shelf donde [requireSession] deja el id de cuenta
/// autenticada, para que los handlers protegidos lo lean sin volver a tocar
/// la cookie.
const String userIdContextKey = 'dnd_user_id';

extension AuthenticatedRequest on Request {
  /// Id de la cuenta autenticada. Solo válido dentro de un handler protegido
  /// por [requireSession]: fuera de ahí, tirar aquí es un error de
  /// enrutado, no una condición a manejar con gracia.
  String get userId => context[userIdContextKey] as String;
}

/// Exige una sesión válida para llegar al handler protegido. La autorización
/// viaja siempre en la cookie, nunca en un encabezado que el cliente
/// gestione: así una petición autenticada como una cuenta no puede, ni por
/// accidente, hacerse pasar por otra.
///
/// [resolveUserId] recibe el token de la cookie y devuelve el id de cuenta
/// dueña de esa sesión, o `null` si el token no existe o expiró. Se recibe
/// como función, y no como el `PostgresSessionStore` concreto, para que este
/// middleware se pueda probar sin una base de datos real.
Middleware requireSession(
  Future<String?> Function(String token) resolveUserId,
) {
  return (Handler innerHandler) {
    return (Request request) async {
      // El MCP ya autenticó con su token y llama a las mismas rutas por
      // adentro. El contexto de shelf solo lo escribe el servidor: una
      // petición HTTP no tiene forma de traerlo puesto.
      if (request.context[userIdContextKey] is String) {
        return innerHandler(request);
      }
      final token = readSessionToken(request.headers['cookie']);
      final userId = token == null ? null : await resolveUserId(token);
      if (userId == null) {
        return Response(
          401,
          body: jsonEncode({
            'error': 'No autenticado.',
            'code': 'unauthenticated',
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      return innerHandler(request.change(context: {userIdContextKey: userId}));
    };
  };
}
