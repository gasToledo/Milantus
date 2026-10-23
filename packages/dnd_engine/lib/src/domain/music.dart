/// Música del Modo DM: escenas que el DM enlaza desde YouTube o YouTube Music.
///
/// Milantus no guarda audio: solo el enlace que pegó el DM. Así no aloja
/// música ajena y el reproductor es el de YouTube, embebido.
///
/// Spotify estuvo y se sacó: su reproductor embebido pasa solo vistas previas
/// aunque el DM tenga la sesión iniciada, y sonar completo pide su API, con
/// Premium y un tope de cinco cuentas cargadas a mano.
library;

/// Una escena de música de una campaña: «Taberna», «Combate — el dragón».
///
/// No lleva `schemaVersion` propio: vive dentro del documento de la
/// [Campaign] y migra con él.
class MusicScene {
  final String id;
  final String name;

  /// El enlace tal cual lo pegó el DM, y no el id que se extrae de él: es lo
  /// que se abre en su sitio, y el id se recalcula con [MusicSource.parse].
  final String url;

  /// Si se ofrece al iniciar un combate. Puede haber varias.
  final bool offerOnCombat;

  const MusicScene({
    required this.id,
    required this.name,
    required this.url,
    this.offerOnCombat = false,
  });

  MusicScene copyWith({String? name, String? url, bool? offerOnCombat}) =>
      MusicScene(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        offerOnCombat: offerOnCombat ?? this.offerOnCombat,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'offerOnCombat': offerOnCombat,
      };

  factory MusicScene.fromJson(Map<String, dynamic> j) => MusicScene(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        offerOnCombat: j['offerOnCombat'] as bool? ?? false,
      );
}

/// Qué es lo enlazado.
enum MusicKind { video, playlist }

/// Un enlace de YouTube reconocido: qué es y su id.
class MusicSource {
  final MusicKind kind;
  final String id;

  const MusicSource(this.kind, this.id);

  /// Reconoce un enlace de YouTube o YouTube Music, o devuelve `null`.
  ///
  /// Cualquier otro enlace se rechaza al guardar, en vez de fallar en la
  /// mesa. Una escena de Spotify guardada antes de sacarlo queda sin
  /// reproducir, para editarla o borrarla.
  static MusicSource? parse(String raw) {
    final text = raw.trim();
    final url = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (url == null || url.host.isEmpty) return null;
    final host = url.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
    final path = url.pathSegments.where((s) => s.isNotEmpty).toList();

    if (host == 'youtu.be' && path.isNotEmpty) {
      return _video(path.first);
    }
    if (host == 'youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtube-nocookie.com') {
      // Un video dentro de una lista se toma como el video: es lo que estaba
      // mirando el DM al copiar el enlace.
      final v = url.queryParameters['v'];
      if (v != null) return _video(v);
      if (path.length >= 2 &&
          const {'embed', 'shorts', 'live'}.contains(path[0])) {
        return _video(path[1]);
      }
      final list = url.queryParameters['list'];
      if (list != null && _youtubeList.hasMatch(list)) {
        return MusicSource(MusicKind.playlist, list);
      }
    }
    return null;
  }

  /// La dirección del reproductor embebido.
  ///
  /// Va por `youtube-nocookie.com`, que no deja cookies hasta que se
  /// reproduce, y con `enablejsapi=1` para pausarlo y enterarse de sus errores
  /// por `postMessage`.
  String get embedUrl => switch (kind) {
        MusicKind.playlist =>
          'https://www.youtube-nocookie.com/embed/videoseries?list=$id&enablejsapi=1',
        MusicKind.video =>
          'https://www.youtube-nocookie.com/embed/$id?enablejsapi=1',
      };

  /// La página de YouTube, para «Abrir en YouTube». Se arma con el id y no se
  /// abre el texto que pegó el DM: así lo que se abre es siempre una página
  /// de YouTube, aunque haya pegado un enlace sin esquema.
  String get pageUrl => switch (kind) {
        MusicKind.playlist => 'https://www.youtube.com/playlist?list=$id',
        MusicKind.video => 'https://www.youtube.com/watch?v=$id',
      };

  static MusicSource? _video(String id) =>
      _youtubeId.hasMatch(id) ? MusicSource(MusicKind.video, id) : null;

  static final _youtubeId = RegExp(r'^[\w-]{11}$');
  static final _youtubeList = RegExp(r'^[\w-]+$');
}
