import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Note', () {
    // Una nota v1 la escribió un DM cuando nada de lo suyo llegaba a la mesa:
    // leerla como compartida la expondría sin que nadie lo haya decidido.
    test('una nota v1 se lee como privada', () {
      final nota = Note.fromJson({
        'schemaVersion': 1,
        'id': 'n1',
        'chapterId': 'c1',
        'title': 'Secreto',
      });

      expect(nota.shared, isFalse);
      expect(nota.toJson()['shared'], isFalse);
    });

    test('la visibilidad sobrevive a la ida y vuelta', () {
      final nota = const Note(id: 'n1', chapterId: 'c1', shared: true);

      expect(Note.fromJson(nota.toJson()).shared, isTrue);
    });

    test('una nota nueva sin versión conserva lo que el DM eligió', () {
      final nota = Note.fromJson({
        'id': 'n1',
        'chapterId': 'c1',
        'title': 'Para la mesa',
        'shared': true,
      });

      expect(nota.shared, isTrue);
    });

    test('rechaza una versión futura en vez de perder campos', () {
      expect(
        () => Note.migrateJson({'schemaVersion': 99, 'id': 'n1'}),
        throwsA(isA<UnsupportedDataVersionException>()),
      );
    });

    test('migrar no modifica la entrada', () {
      final source = {'schemaVersion': 1, 'id': 'n1', 'chapterId': 'c1'};

      Note.migrateJson(source);

      expect(source.containsKey('shared'), isFalse);
      expect(source['schemaVersion'], 1);
    });
  });
}
