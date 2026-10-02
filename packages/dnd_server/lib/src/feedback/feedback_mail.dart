import 'dart:convert';

import 'package:http/http.dart' as http;

/// Un mensaje de un tester ya armado como correo. El remitente y el
/// destinatario no viajan acá: son configuración del servidor (ver
/// `FeedbackConfig`), nunca algo que pueda decidir quien escribe.
class FeedbackEmail {
  final String subject;
  final String text;

  /// El correo de la cuenta, para contestarle con «Responder». `null` solo si
  /// el proveedor OIDC no lo afirmó: el mensaje se manda igual.
  final String? replyTo;

  const FeedbackEmail({
    required this.subject,
    required this.text,
    this.replyTo,
  });
}

/// Entrega un [FeedbackEmail]. Lanza si no se pudo. Se recibe como función
/// por la misma razón que el resto de las dependencias de `buildHandler`: el
/// enrutado se prueba con un doble, sin mandar correos de verdad.
typedef SendFeedbackFn = Future<void> Function(FeedbackEmail email);

enum FeedbackKind { idea, bug }

/// Los datos técnicos que la app manda junto al mensaje, con el rótulo con
/// que aparecen en el correo. Es una lista cerrada a propósito: cualquier otra
/// clave se descarta, así el correo no se vuelve un canal para meter texto
/// arbitrario con apariencia de dato del sistema.
const feedbackContextLabels = {
  'version': 'Versión',
  'language': 'Idioma',
  'theme': 'Tema',
  'viewport': 'Ventana',
  'origin': 'Abierto desde',
  'errorDetail': 'Detalle del error',
};

/// Arma el correo. Lo que identifica a la cuenta (nombre, correo) y lo que
/// sale de la petición (navegador, hora) lo pone el servidor; de la app
/// llegan solo el mensaje y los datos de [feedbackContextLabels].
FeedbackEmail composeFeedbackEmail({
  required FeedbackKind kind,
  required String message,
  required Map<String, String> context,
  required DateTime receivedAt,
  String? name,
  String? email,
  String? userAgent,
}) {
  final who = _oneLine(name ?? email ?? 'Cuenta sin nombre');
  final kindLabel = switch (kind) {
    FeedbackKind.idea => 'Idea',
    FeedbackKind.bug => 'Error',
  };
  final technical = <String, String?>{
    'Cuenta': [name, email].whereType<String>().join(' · '),
    'Recibido': receivedAt.toUtc().toIso8601String(),
    'Navegador': userAgent,
    for (final entry in feedbackContextLabels.entries)
      entry.value: context[entry.key],
  };
  final lines = [
    for (final entry in technical.entries)
      if (entry.value case final value? when value.isNotEmpty)
        '${entry.key}: $value',
  ];
  return FeedbackEmail(
    subject: '[Milantus] $kindLabel · $who',
    text: '$message\n\n— Datos técnicos —\n${lines.join('\n')}\n',
    replyTo: email,
  );
}

/// Un nombre con saltos de línea no puede romper el asunto: algunos clientes
/// de correo cortan ahí y el resto se lee como si fuera otra cosa.
String _oneLine(String value) => value.replaceAll(RegExp(r'[\r\n]+'), ' ');

/// Le pasa el correo al Worker de `feedback-worker/`, que lo entrega a la
/// casilla del proyecto. Va por un Worker y no por la API de envío de
/// Cloudflare porque esa es paga, mientras que un Worker manda gratis a una
/// dirección verificada en Email Routing, y el destino es siempre esa casilla
/// (el tester solo figura en «Responder a»). Sin dependencias nuevas: alcanza
/// con el paquete `http`, que el servidor ya usa para los retratos.
SendFeedbackFn workerFeedbackSender({
  required Uri url,
  required String secret,
  http.Client? client,
}) {
  return (email) async {
    final c = client ?? http.Client();
    try {
      final response = await c
          .post(
            url,
            headers: {
              'authorization': 'Bearer $secret',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'subject': email.subject,
              'text': email.text,
              'replyTo': ?email.replyTo,
            }),
          )
          .timeout(const Duration(seconds: 15));
      // El Worker responde `{"ok": true}`; se exigen eso y el código. Si no,
      // el cuerpo dice qué falló (secreto distinto, destino sin verificar) y
      // va al log del servidor, no a quien escribió.
      final ok =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          _succeeded(response.body);
      if (!ok) {
        throw StateError(
          'El Worker respondió ${response.statusCode}: ${response.body}',
        );
      }
    } finally {
      if (client == null) c.close();
    }
  };
}

bool _succeeded(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map && decoded['ok'] == true;
  } on FormatException {
    return false;
  }
}

/// Cuántos mensajes puede mandar una cuenta por ventana de tiempo. Solo
/// escriben cuentas con sesión, pero un botón que dispara correos sin tope es
/// fácil de convertir en spam hacia la casilla del proyecto.
///
/// ponytail: en memoria y por proceso; se reinicia con el servidor. Alcanza
/// con una sola instancia detrás del túnel; con varias, pasar a una tabla.
class FeedbackRateLimiter {
  final int maxPerWindow;
  final Duration window;
  final DateTime Function() now;
  final _sent = <String, List<DateTime>>{};

  FeedbackRateLimiter({
    this.maxPerWindow = 10,
    this.window = const Duration(hours: 1),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  bool allows(String userId) {
    final cutoff = now().subtract(window);
    final recent = (_sent[userId] ?? const <DateTime>[])
        .where((at) => at.isAfter(cutoff))
        .toList();
    _sent[userId] = recent;
    return recent.length < maxPerWindow;
  }

  /// Se anota recién cuando el correo salió: si el proveedor está caído, los
  /// reintentos no le gastan el cupo a quien escribe.
  void record(String userId) => (_sent[userId] ??= []).add(now());
}
