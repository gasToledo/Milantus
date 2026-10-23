import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('MusicSource.parse', () {
    void reconoce(String url, MusicSite site, MusicKind kind, String id) {
      final s = MusicSource.parse(url);
      expect(s, isNotNull, reason: url);
      expect((s!.site, s.kind, s.id), (site, kind, id), reason: url);
    }

    test('videos de YouTube en todas sus formas', () {
      for (final url in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ?t=42',
        'youtube.com/watch?v=dQw4w9WgXcQ&list=PL123',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/live/dQw4w9WgXcQ',
        'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
      ]) {
        reconoce(url, MusicSite.youtube, MusicKind.video, 'dQw4w9WgXcQ');
      }
    });

    test('una lista de YouTube', () {
      reconoce(
        'https://www.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG',
        MusicSite.youtube,
        MusicKind.playlist,
        'PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG',
      );
    });

    test('canciones, álbumes, listas y episodios de Spotify', () {
      const id = '37i9dQZF1DX8Uebhn9wzrS';
      reconoce('https://open.spotify.com/track/$id?si=abc', MusicSite.spotify,
          MusicKind.track, id);
      reconoce('https://open.spotify.com/intl-es/album/$id', MusicSite.spotify,
          MusicKind.album, id);
      reconoce('https://open.spotify.com/playlist/$id', MusicSite.spotify,
          MusicKind.playlist, id);
      reconoce('spotify:episode:$id', MusicSite.spotify, MusicKind.episode, id);
    });

    test('lo que no es un enlace soportado devuelve null', () {
      for (final url in [
        '',
        'no es un enlace',
        'https://soundcloud.com/artista/tema',
        'https://www.youtube.com/',
        'https://www.youtube.com/watch?v=corto',
        'https://open.spotify.com/artist/37i9dQZF1DX8Uebhn9wzrS',
      ]) {
        expect(MusicSource.parse(url), isNull, reason: url);
      }
    });

    test('el reproductor embebido apunta a cada sitio', () {
      expect(
        MusicSource.parse('https://youtu.be/dQw4w9WgXcQ')!.embedUrl,
        'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?enablejsapi=1',
      );
      expect(
        MusicSource.parse('https://open.spotify.com/album/abc123')!.embedUrl,
        'https://open.spotify.com/embed/album/abc123',
      );
    });
  });
}
