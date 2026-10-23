// Lado web de `music_embed.dart`. Va por `dart:js_interop`, como la pantalla
// encendida de `browser_web.dart`: no hace falta `package:web` para crear un
// iframe y hablarle por `postMessage`.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/widgets.dart';

import 'music_embed.dart';

/// `pointer-events` del elemento: el único modo de que el iframe deje pasar
/// los clics a lo que Flutter dibuja encima.
void Function(bool) _pointerEventsOf(JSObject element) =>
    (interactive) => (element['style'] as JSObject)['pointerEvents'] =
        (interactive ? 'auto' : 'none').toJS;

Widget musicEmbedView(MusicSource source, MusicEmbedController controller) =>
    HtmlElementView.fromTagName(
      // Una vista por enlace: otra escena es otro iframe, no el mismo con
      // otro `src`, así el anterior se lleva su escucha de mensajes.
      key: ValueKey(source.embedUrl),
      tagName: source.site == MusicSite.youtube ? 'iframe' : 'div',
      onElementCreated: (element) => source.site == MusicSite.youtube
          ? _youtube(element as JSObject, source, controller)
          : _spotify(element as JSObject, source, controller),
    );

JSObject get _window => globalContext;
JSObject get _document => globalContext['document'] as JSObject;

void _fill(JSObject element) {
  (element['style'] as JSObject)['cssText'] =
      'width:100%;height:100%;border:0;border-radius:9px;display:block'.toJS;
}

// ------------------------------------------------------------------ YouTube
//
// Sin el script `iframe_api`: el iframe con `enablejsapi=1` ya acepta órdenes
// y cuenta su estado por `postMessage`. Es un script de un tercero menos, y
// nada que cargar hasta que suena una escena.

void _youtube(JSObject frame, MusicSource source, MusicEmbedController c) {
  _fill(frame);
  // La reproducción la pidió el DM con un clic: el navegador deja arrancar
  // con sonido si el iframe declara `autoplay`.
  frame['allow'] = 'autoplay; encrypted-media'.toJS;
  frame['src'] = '${source.embedUrl}&autoplay=1'.toJS;

  void post(Map<String, Object> message) =>
      (frame['contentWindow'] as JSObject?)?.callMethod<JSAny?>(
        'postMessage'.toJS,
        jsonEncode(message).toJS,
        '*'.toJS,
      );

  // Sin «listening», el iframe no manda sus eventos al padre.
  frame['onload'] = ((JSAny? _) {
    post({'event': 'listening', 'id': 1, 'channel': 'widget'});
  }).toJS;

  final listener = ((JSObject event) {
    final from = event['source'];
    if (from == null || !from.strictEquals(frame['contentWindow']).toDart) {
      return;
    }
    final data = event['data'];
    if (!data.isA<JSString>()) return;
    final Object? decoded;
    try {
      decoded = jsonDecode((data as JSString).toDart);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final info = decoded['info'];
    switch (decoded['event']) {
      // 101 y 150: el dueño del video no deja reproducirlo fuera de YouTube.
      // 100: el video no existe o es privado; para el DM es lo mismo.
      case 'onError' when info is num:
        if (const {100, 101, 150}.contains(info.toInt())) {
          c.report(unembeddable: true, playing: false);
        }
      case 'onStateChange' when info is num:
        c.report(playing: info.toInt() == 1);
      case 'infoDelivery' when info is Map && info['playerState'] is num:
        c.report(playing: (info['playerState'] as num).toInt() == 1);
    }
  }).toJS;
  _window.callMethod<JSAny?>('addEventListener'.toJS, 'message'.toJS, listener);

  c.attach(
    play: () => post({'event': 'command', 'func': 'playVideo', 'args': []}),
    pause: () => post({'event': 'command', 'func': 'pauseVideo', 'args': []}),
    detach: () => _window.callMethod<JSAny?>(
      'removeEventListener'.toJS,
      'message'.toJS,
      listener,
    ),
    setInteractive: _pointerEventsOf(frame),
  );
}

// ------------------------------------------------------------------ Spotify
//
// El iframe de Spotify no acepta órdenes sueltas: pausarlo desde la barra
// minimizada necesita su Embed iFrame API, que se carga recién la primera vez
// que suena una escena de Spotify.

Future<JSObject>? _spotifyApi;

Future<JSObject> _loadSpotifyApi() => _spotifyApi ??= () {
  final ready = Completer<JSObject>();
  _window['onSpotifyIframeApiReady'] = ((JSObject api) {
    if (!ready.isCompleted) ready.complete(api);
  }).toJS;
  final script = _document.callMethod<JSObject>(
    'createElement'.toJS,
    'script'.toJS,
  );
  script['src'] = 'https://open.spotify.com/embed/iframe-api/v1'.toJS;
  script['async'] = true.toJS;
  script['onerror'] = ((JSAny? _) {
    if (!ready.isCompleted) ready.completeError(StateError('spotify'));
  }).toJS;
  (_document['head'] as JSObject).callMethod<JSAny?>(
    'appendChild'.toJS,
    script,
  );
  return ready.future.timeout(const Duration(seconds: 10));
}();

Future<void> _spotify(
  JSObject host,
  MusicSource source,
  MusicEmbedController c,
) async {
  (host['style'] as JSObject)['cssText'] = 'width:100%;height:100%'.toJS;
  // La API reemplaza el elemento que recibe por su iframe: se le da un hijo,
  // que siempre tiene padre, y no el elemento de la vista.
  final slot = _document.callMethod<JSObject>('createElement'.toJS, 'div'.toJS);
  host.callMethod<JSAny?>('appendChild'.toJS, slot);

  final JSObject api;
  try {
    api = await _loadSpotifyApi();
  } catch (_) {
    // ponytail: sin la API, el iframe solo, con sus propios controles. La
    // barra minimizada no puede pausarlo (no hay `attach`); techo: un botón
    // menos. Salida: reintentar la carga (borrar `_spotifyApi`) al desplegar.
    _spotifyApi = null;
    final frame = _document.callMethod<JSObject>(
      'createElement'.toJS,
      'iframe'.toJS,
    );
    _fill(frame);
    frame['allow'] = 'autoplay; encrypted-media'.toJS;
    frame['src'] = source.embedUrl.toJS;
    slot.callMethod<JSAny?>('replaceWith'.toJS, frame);
    return;
  }

  final options = {
    'uri': 'spotify:${source.kind.name}:${source.id}',
    'width': '100%',
    'height': '80',
  }.jsify();
  api.callMethod<JSAny?>(
    'createController'.toJS,
    slot,
    options,
    ((JSObject controller) {
      void call(String method) => controller.callMethod<JSAny?>(method.toJS);
      controller.callMethod<JSAny?>(
        'addListener'.toJS,
        'playback_update'.toJS,
        ((JSObject event) {
          final data = event['data'] as JSObject?;
          final paused = data?['isPaused'];
          if (paused != null && paused.isA<JSBoolean>()) {
            c.report(playing: !(paused as JSBoolean).toDart);
          }
        }).toJS,
      );
      // Arranca solo, como YouTube: el DM ya eligió la escena. Si el
      // navegador lo bloquea, queda el play del propio reproductor.
      controller.callMethod<JSAny?>(
        'addListener'.toJS,
        'ready'.toJS,
        ((JSAny? _) => call('play')).toJS,
      );
      c.attach(
        play: () => call('resume'),
        pause: () => call('pause'),
        detach: () => call('destroy'),
        setInteractive: _pointerEventsOf(host),
      );
    }).toJS,
  );
}
