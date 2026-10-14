import 'dart:async';

import 'browser.dart' as browser;

/// Mantiene la pantalla encendida mientras haya abierta una pantalla de
/// juego (la ficha o el Modo DM) **y** la preferencia de Ajustes esté
/// prendida.
///
/// Cuenta quién la pide en vez de prender y apagar sin más: el Modo DM abre la
/// ficha de un PNJ encima suyo, y si la ficha la apagara al cerrarse, el DM
/// se quedaría sin pantalla encendida en medio del combate.
class ScreenAwake {
  final void Function(bool on) write;
  final Future<void> Function(bool on) apply;

  /// Si el navegador sabe hacerlo. Sin esto Ajustes no ofrece el interruptor.
  final bool supported;

  bool _enabled;
  int _holders = 0;
  bool _applied = false;

  /// Los puntos de contacto con el navegador se inyectan para los tests; por
  /// defecto son los reales de `browser.dart`.
  ScreenAwake({
    bool? Function() read = browser.readStoredScreenAwake,
    this.write = browser.writeStoredScreenAwake,
    this.apply = browser.keepScreenAwake,
    bool? supported,
  }) : supported = supported ?? browser.screenWakeLockSupported,
       _enabled = _safeRead(read);

  static bool _safeRead(bool? Function() read) {
    try {
      return read() ?? false;
    } catch (_) {
      // Almacenamiento bloqueado: se arranca apagado, que es lo que pasaría
      // sin haberlo elegido nunca.
      return false;
    }
  }

  bool get enabled => _enabled;

  void setEnabled(bool on) {
    _enabled = on;
    try {
      write(on);
    } catch (_) {
      // Sin almacenamiento vale igual durante la sesión; solo no se recuerda.
    }
    _sync();
  }

  void hold() {
    _holders++;
    _sync();
  }

  void release() {
    if (_holders > 0) _holders--;
    _sync();
  }

  void _sync() {
    final want = supported && _enabled && _holders > 0;
    if (want == _applied) return;
    _applied = want;
    // ponytail: si el navegador lo rechaza (ahorro de batería) no se avisa;
    // el interruptor sigue prendido y se reintenta en la próxima pantalla.
    // Sumar un aviso si aparecen quejas de que «no anda».
    unawaited(
      apply(want).catchError((_) {
        _applied = false;
      }),
    );
  }
}

/// La única instancia de la app: la preferencia y el conteo son de la
/// pestaña entera, no de una pantalla.
final screenAwake = ScreenAwake();
