// l10n-ignore-file: errores de programación (UnsupportedError) que no le llegan a la persona.
import 'dart:typed_data';

/// Sustituto sin `dart:html` que ocupa este punto de entrada cuando el
/// código se compila para una plataforma sin navegador (la VM que corre
/// `flutter test`, por ejemplo). Nunca se llama fuera de una interacción real
/// del usuario en el build web (ver `browser_web.dart`), así que no hace
/// falta un no-op silencioso: un `UnsupportedError` señala claramente un uso
/// fuera de lugar, igual que `content_pack_loader_stub.dart` en `dnd_engine`.
void redirectTo(String path) {
  throw UnsupportedError('redirectTo solo está disponible en el build web.');
}

void downloadBytes(
  Uint8List bytes, {
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError('downloadBytes solo está disponible en el build web.');
}

void openInNewTab(String url) {
  throw UnsupportedError('openInNewTab solo está disponible en el build web.');
}

// Lo que sigue **no** lanza: se llama al arrancar y desde los tests de
// widget, que no tienen navegador pero tampoco están haciendo nada mal. Sin
// almacenamiento ni idioma de navegador, la app cae al idioma por defecto.
String? readStoredLocale() => null;

void writeStoredLocale(String code) {}

String? browserLanguage() => null;

void setDocumentLanguage(String code) {}
