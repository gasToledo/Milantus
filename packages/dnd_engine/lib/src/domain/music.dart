/// Música del Modo DM: escenas que el DM enlaza desde YouTube o Spotify.
///
/// Milantus no guarda audio: solo el enlace que pegó el DM. Así no aloja
/// música ajena y el reproductor es el del propio sitio, embebido.
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

enum MusicSite { youtube, spotify }

/// Qué es lo enlazado. `playlist` vale para los dos sitios.
enum MusicKind { video, playlist, track, album, episode }

/// Un enlace de música reconocido: de qué sitio es, qué es y su id.
class MusicSource {
  final MusicSite site;
  final MusicKind kind;
  final String id;

  const MusicSource(this.site, this.kind, this.id);

  /// Reconoce un enlace de YouTube o Spotify, o devuelve `null`.
  ///
  /// Solo los sitios cuyo reproductor se puede embeber sin cuenta ni clave:
  /// cualquier otro enlace se rechaza al guardar, en vez de fallar en la mesa.
  static MusicSource? parse(String raw) {
    final text = raw.trim();
    // `spotify:track:<id>`, lo que copia la aplicación de escritorio.
    final uri = RegExp(r'^spotify:(track|album|playlist|episode):(\w+)$')
        .firstMatch(text);
    if (uri != null) {
      return MusicSource(MusicSite.spotify, _spotifyKinds[uri[1]]!, uri[2]!);
    }

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
        return MusicSource(MusicSite.youtube, MusicKind.playlist, list);
      }
      return null;
    }

    if (host == 'open.spotify.com') {
      // `intl-es/` y `embed/` son prefijos de la misma página.
      final rest =
          path.skipWhile((s) => s.startsWith('intl-') || s == 'embed').toList();
      if (rest.length < 2) return null;
      final kind = _spotifyKinds[rest[0]];
      if (kind == null || !_spotifyId.hasMatch(rest[1])) return null;
      return MusicSource(MusicSite.spotify, kind, rest[1]);
    }
    return null;
  }

  /// La dirección del reproductor embebido.
  ///
  /// YouTube va por `youtube-nocookie.com`, que no deja cookies hasta que se
  /// reproduce, y con `enablejsapi=1` para pausarlo y enterarse de sus errores
  /// por `postMessage`.
  String get embedUrl => switch ((site, kind)) {
        (MusicSite.youtube, MusicKind.playlist) =>
          'https://www.youtube-nocookie.com/embed/videoseries?list=$id&enablejsapi=1',
        (MusicSite.youtube, _) =>
          'https://www.youtube-nocookie.com/embed/$id?enablejsapi=1',
        // Los nombres de [MusicKind] de Spotify son los segmentos de su URL.
        (MusicSite.spotify, _) =>
          'https://open.spotify.com/embed/${kind.name}/$id',
      };

  /// La página del sitio, para «Abrir en YouTube/Spotify». Se arma con el id
  /// y no se abre el texto que pegó el DM: así lo que se abre es siempre una
  /// página del sitio, aunque haya pegado `spotify:…` o un enlace sin esquema.
  String get pageUrl => switch ((site, kind)) {
        (MusicSite.youtube, MusicKind.playlist) =>
          'https://www.youtube.com/playlist?list=$id',
        (MusicSite.youtube, _) => 'https://www.youtube.com/watch?v=$id',
        (MusicSite.spotify, _) => 'https://open.spotify.com/${kind.name}/$id',
      };

  static MusicSource? _video(String id) => _youtubeId.hasMatch(id)
      ? MusicSource(MusicSite.youtube, MusicKind.video, id)
      : null;

  static final _youtubeId = RegExp(r'^[\w-]{11}$');
  static final _youtubeList = RegExp(r'^[\w-]+$');
  static final _spotifyId = RegExp(r'^[A-Za-z0-9]+$');

  static const _spotifyKinds = {
    'track': MusicKind.track,
    'album': MusicKind.album,
    'playlist': MusicKind.playlist,
    'episode': MusicKind.episode,
  };
}
