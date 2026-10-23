import 'package:flutter/foundation.dart';

// El reproductor embebido de YouTube o Spotify de una escena. La vista real
// (`music_embed_web.dart`) solo existe al compilar para web; en la VM de
// `flutter test` se usa el stub, que no dibuja nada (mismo patrón que
// `browser.dart`).
export 'music_embed_stub.dart' if (dart.library.html) 'music_embed_web.dart';

/// Lo que el reproductor sabe y puede hacer con el embebido de una escena.
///
/// La vista se engancha al crearse ([attach]) y avisa lo que el sitio le
/// cuenta ([report]); el reproductor solo lee [playing] y [unembeddable] y
/// llama a [play] y [pause]. Uno por escena puesta: cambiar de escena lo
/// descarta, y con él la escucha de mensajes del sitio.
class MusicEmbedController extends ChangeNotifier {
  bool _playing = false;
  bool _unembeddable = false;
  VoidCallback? _play;
  VoidCallback? _pause;
  VoidCallback? _detach;
  void Function(bool)? _setInteractive;
  bool _interactive = true;

  /// Lo último que avisó el sitio. Arranca en falso: hasta que el embebido
  /// cargue no hay nada sonando.
  bool get playing => _playing;

  /// El sitio se negó a reproducir el enlace dentro de otra página.
  bool get unembeddable => _unembeddable;

  /// Si el embebido recibe los clics. Con un menú o un diálogo encima, el
  /// iframe se los robaba aunque Flutter lo dibujara tapado: la opción del
  /// menú que caía sobre el video no se podía tocar.
  void setInteractive(bool value) {
    if (value == _interactive) return;
    _interactive = value;
    _setInteractive?.call(value);
  }

  void play() => _play?.call();
  void pause() => _pause?.call();

  void attach({
    required VoidCallback play,
    required VoidCallback pause,
    VoidCallback? detach,
    void Function(bool interactive)? setInteractive,
  }) {
    _play = play;
    _pause = pause;
    _detach = detach;
    _setInteractive = setInteractive;
    // Si ya había un menú abierto cuando terminó de cargar.
    if (!_interactive) setInteractive?.call(false);
  }

  void report({bool? playing, bool? unembeddable}) {
    if (playing != null) _playing = playing;
    if (unembeddable != null) _unembeddable = unembeddable;
    notifyListeners();
  }

  @override
  void dispose() {
    _detach?.call();
    super.dispose();
  }
}
