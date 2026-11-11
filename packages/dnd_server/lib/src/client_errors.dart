import 'dart:convert';

import 'feedback/feedback_mail.dart';

/// Campos que el cliente puede mandar y su tope de largo. Es una lista
/// cerrada a propósito: cualquier otra clave (una ficha que se coló en el
/// cuerpo, por ejemplo) se descarta sin mirarla.
const _clientErrorFields = {
  'message': 500,
  'stack': 4000,
  'componentStack': 2000,
  'route': 200,
  'version': 200,
  'userAgent': 300,
};

/// Recibe los errores que el cliente React manda solo y decide si merecen una
/// línea de log. No toca la base ni guarda nada: el log del contenedor es todo
/// el destino.
class ClientErrorSink {
  final void Function(String line) log;
  final FeedbackRateLimiter _limiter;
  final Duration dedupWindow;
  final DateTime Function() _now;
  final _seen = <String, DateTime>{};

  ClientErrorSink({
    required this.log,
    int maxPerHour = 20,
    this.dedupWindow = const Duration(minutes: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _limiter = FeedbackRateLimiter(
         maxPerWindow: maxPerHour,
         now: now ?? DateTime.now,
       );

  /// Escribe la línea si corresponde. Devuelve `true` si escribió; el handler
  /// responde 204 igual en los dos casos, para que el cliente no distinga.
  bool accept(String userId, Map<String, dynamic> body) {
    final fields = <String, String>{
      for (final entry in _clientErrorFields.entries)
        if (body[entry.key] case final String value)
          entry.key: value.length > entry.value
              ? value.substring(0, entry.value)
              : value,
    };
    final message = fields['message'];
    if (message == null || message.isEmpty) return false;

    // Firma: mensaje + primera línea de traza propia. Un error en bucle repite
    // las dos, así que deja una línea y no mil.
    final firstLine = (fields['stack'] ?? '')
        .split('\n')
        .skip(1)
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final signature = '$userId|$message|${firstLine.trim()}';
    final now = _now();
    _seen.removeWhere((_, at) => now.difference(at) > dedupWindow);
    if (_seen.containsKey(signature)) return false;
    if (!_limiter.allows(userId)) return false;

    _seen[signature] = now;
    _limiter.record(userId);
    // jsonEncode: una sola línea aunque la traza traiga saltos, y nadie puede
    // fabricar líneas de log falsas metiendo un «\n» en el mensaje.
    log('client-error ${jsonEncode({'userId': userId, ...fields})}');
    return true;
  }
}
