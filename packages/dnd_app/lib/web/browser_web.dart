// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// `dart:html` sigue siendo la única forma de navegar la pestaña y descargar
// un blob sin agregar `package:web` solo para dos llamadas. El lint que evita
// librerías web fuera de plugins asume que este archivo se compila también
// para las demás plataformas: no es el caso, es el lado `_web.dart` de una
// importación condicional (ver `browser.dart`/`browser_stub.dart`), así que
// nunca entra al build de Windows.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Único punto de contacto con el navegador para lo que no tiene equivalente
/// en Flutter puro: navegar la pestaña entera (login/logout) y disparar una
/// descarga de bytes en memoria. El resto de la aplicación no importa
/// `dart:html` directamente.

/// Navega la pestaña completa a [path] (ruta relativa al origen actual). Se
/// usa para `/auth/login`: una petición `fetch` seguiría el 302 del lado del
/// cliente y nunca mostraría la pantalla de inicio de sesión del proveedor
/// OIDC, así que esto tiene que ser una navegación real, no una llamada de
/// `ApiClient`.
void redirectTo(String path) {
  html.window.location.assign(path);
}

/// Descarga [bytes] como un archivo, sin exponer ninguna ruta del servidor
/// (ver capacidad `web-client`, exportación de un personaje): crea un enlace
/// efímero a un blob en memoria y lo "clickea" mediante programación.
void downloadBytes(
  Uint8List bytes, {
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Abre [url] en una pestaña nueva, para los enlaces que el jugador guarda en
/// el Diario.
///
/// `noopener,noreferrer` corta el acceso de la página abierta a
/// `window.opener`: sin eso, un sitio enlazado desde una entrada podría
/// redirigir la pestaña de la aplicación a donde quisiera.
///
/// **Quien llama valida el esquema** (`_openableLink`, en el Diario): un
/// `javascript:` llegando hasta acá se ejecutaría en el origen de la propia
/// aplicación. Esta función es el mecanismo, no la política, y hoy tiene un
/// solo llamador.
void openInNewTab(String url) {
  html.window.open(url, '_blank', 'noopener,noreferrer');
}

/// Abre el diálogo de impresión con [document], un HTML completo, sin sacar
/// a la persona de la app.
///
/// Va en un iframe invisible y no en una pestaña nueva: `window.open` fuera
/// del mismo gesto lo bloquea Safari, y una pestaña en blanco que queda
/// abierta después de imprimir es un estorbo. El iframe anterior se borra
/// recién al imprimir otra vez, porque algunos navegadores siguen leyéndolo
/// mientras el diálogo está abierto.
///
/// Por `dart:js_interop` y no `dart:html`: `IFrameElement.contentWindow` es
/// un `WindowBase`, que no expone `print`.
void printHtml(String document) {
  const id = 'milantus-print';
  final doc = globalContext['document'] as JSObject;
  doc
      .callMethod<JSObject?>('getElementById'.toJS, id.toJS)
      ?.callMethod<JSAny?>('remove'.toJS);
  final frame = doc.callMethod<JSObject>('createElement'.toJS, 'iframe'.toJS);
  frame['id'] = id.toJS;
  (frame['style'] as JSObject)['cssText'] =
      'position:fixed;right:0;bottom:0;width:0;height:0;border:0'.toJS;
  frame['onload'] = ((JSAny? _) {
    (frame['contentWindow'] as JSObject).callMethod<JSAny?>('print'.toJS);
  }).toJS;
  frame['srcdoc'] = document.toJS;
  (doc['body'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, frame);
}

/// Clave bajo la que se recuerda el idioma elegido. Una sola, y sin datos de
/// la persona: solo `es` o `en`.
const _localeKey = 'milantus.locale';

/// Idioma guardado, o `null` si no hay. **Puede lanzar** si el navegador
/// bloquea el almacenamiento (modo privado estricto, cookies desactivadas):
/// quien llama (`AppLocaleController`) lo trata como «no hay».
String? readStoredLocale() => html.window.localStorage[_localeKey];

void writeStoredLocale(String code) {
  html.window.localStorage[_localeKey] = code;
}

/// Idioma del navegador (`en-US`, `es-AR`…), o `null` si no lo informa.
String? browserLanguage() => html.window.navigator.language;

/// Mantiene `<html lang>` al día: lo usan los lectores de pantalla para elegir
/// la voz y los navegadores para ofrecer traducir la página.
void setDocumentLanguage(String code) {
  html.document.documentElement?.setAttribute('lang', code);
}

// ------------------------------------------------------- Pantalla encendida
//
// `dart:html` no trae la Wake Lock API, así que va por `dart:js_interop`, que
// ya viene con el SDK: no hace falta `package:web` para dos llamadas.

@JS('navigator.wakeLock')
external _WakeLock? get _wakeLock;

extension type _WakeLock._(JSObject _) implements JSObject {
  external JSPromise<_WakeLockSentinel> request(String type);
}

extension type _WakeLockSentinel._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> release();
}

_WakeLockSentinel? _sentinel;
bool _wantScreenAwake = false;
StreamSubscription<html.Event>? _visibilitySub;

/// Si el navegador sabe mantener la pantalla encendida. Safari lo trae
/// recién desde iOS 16.4: donde no está, la ficha no ofrece el interruptor en
/// vez de mostrar uno que no hace nada.
bool get screenWakeLockSupported => _wakeLock != null;

/// Pide (o suelta) que la pantalla no se apague mientras la ficha está
/// abierta. **Lanza** si el navegador lo rechaza (ahorro de batería, por
/// ejemplo); quien llama vuelve el interruptor a apagado.
Future<void> keepScreenAwake(bool on) async {
  _wantScreenAwake = on;
  if (!on) {
    await _visibilitySub?.cancel();
    _visibilitySub = null;
    final s = _sentinel;
    _sentinel = null;
    await s?.release().toDart;
    return;
  }
  // El navegador suelta el bloqueo solo cada vez que la pestaña se esconde
  // (cambiar de app, bloquear el teléfono). Sin volver a pedirlo al regresar,
  // el interruptor quedaría prendido sin hacer nada desde el primer mensaje
  // de WhatsApp.
  _visibilitySub ??= html.document.onVisibilityChange.listen((_) {
    if (_wantScreenAwake && html.document.visibilityState == 'visible') {
      _acquire().catchError((_) {});
    }
  });
  try {
    await _acquire();
  } catch (_) {
    await keepScreenAwake(false);
    rethrow;
  }
}

Future<void> _acquire() async {
  final s = await _wakeLock!.request('screen').toDart;
  // Si lo apagaron mientras la promesa estaba en vuelo, el bloqueo recién
  // llegado no tiene dueño: se suelta ya o la pantalla quedaría prendida.
  if (!_wantScreenAwake) {
    await s.release().toDart;
    return;
  }
  _sentinel = s;
}

/// Preferencia de pantalla encendida. Va en el navegador y no en la cuenta
/// por el mismo motivo que el idioma: es de este dispositivo. Prenderla en el
/// teléfono no tiene por qué prenderla en la PC. **Puede lanzar** si el
/// navegador bloquea el almacenamiento.
const _screenAwakeKey = 'milantus.screenAwake';

bool? readStoredScreenAwake() =>
    switch (html.window.localStorage[_screenAwakeKey]) {
      'true' => true,
      'false' => false,
      _ => null,
    };

void writeStoredScreenAwake(bool on) {
  html.window.localStorage[_screenAwakeKey] = '$on';
}

/// Tutoriales ya vistos (ver `Tutorials`). En el navegador por lo mismo que el
/// idioma. **Puede lanzar** si el navegador bloquea el almacenamiento.
const _tutorialsKey = 'milantus.tutorials';

String? readStoredTutorials() => html.window.localStorage[_tutorialsKey];

void writeStoredTutorials(String value) {
  html.window.localStorage[_tutorialsKey] = value;
}
