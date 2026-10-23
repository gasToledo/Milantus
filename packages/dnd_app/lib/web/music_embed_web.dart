// Lado web de `music_embed.dart`. Va por `dart:js_interop`, como la pantalla
// encendida de `browser_web.dart`: no hace falta `package:web` para crear un
// iframe y hablarle por `postMessage`.
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
      tagName: 'iframe',
      onElementCreated: (element) =>
          _youtube(element as JSObject, source, controller),
    );

JSObject get _window => globalContext;

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
