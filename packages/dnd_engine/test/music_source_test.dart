import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('MusicSource.parse', () {
    void reconoce(String url, MusicKind kind, String id) {
      final s = MusicSource.parse(url);
      expect(s, isNotNull, reason: url);
      expect((s!.kind, s.id), (kind, id), reason: url);
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
        reconoce(url, MusicKind.video, 'dQw4w9WgXcQ');
      }
    });

    test('una lista de YouTube o de YouTube Music', () {
      const id = 'PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG';
      for (final url in [
        'https://www.youtube.com/playlist?list=$id',
        'https://music.youtube.com/playlist?list=$id',
      ]) {
        reconoce(url, MusicKind.playlist, id);
      }
    });

    test('lo que no es un enlace soportado devuelve null', () {
      for (final url in [
        '',
        'no es un enlace',
        'https://soundcloud.com/artista/tema',
        'https://www.youtube.com/',
        'https://www.youtube.com/watch?v=corto',
        // Spotify se sacó: sin su API solo pasa vistas previas.
        'https://open.spotify.com/playlist/37i9dQZF1DX8Uebhn9wzrS',
        'spotify:track:37i9dQZF1DX8Uebhn9wzrS',
      ]) {
        expect(MusicSource.parse(url), isNull, reason: url);
      }
    });

    test('el reproductor embebido va por youtube-nocookie', () {
      expect(
        MusicSource.parse('https://youtu.be/dQw4w9WgXcQ')!.embedUrl,
        'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?enablejsapi=1',
      );
    });
  });
}
