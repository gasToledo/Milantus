import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

Creature _criatura(Map<String, dynamic> campos) => Creature.fromJson({
      'id': 'criatura-prueba',
      'name': 'Criatura de prueba',
      'ac': '13',
      'hp': '11',
      ...campos,
    });

void main() {
  tearDown(() => ContentLanguage.current = ContentLanguage.es);

  group('Creature.displayKind', () {
    test('un homebrew con tipo y tamaño se lee en el idioma activo', () {
      final c = _criatura({
        'source': 'homebrew',
        'kind': 'Aberración Mediana',
        'type': 'aberration',
        'size': 'medium',
      });

      expect(c.displayKind, 'Aberración Mediana');

      ContentLanguage.current = ContentLanguage.en;
      expect(c.displayKind, 'Medium Aberration');
    });

    test('el femenino concuerda con el tamaño en español', () {
      final bestia = _criatura({
        'source': 'homebrew',
        'kind': 'Bestia Mediana',
        'type': 'beast',
        'size': 'medium',
      });
      final muerto = _criatura({
        'source': 'homebrew',
        'kind': 'Muerto viviente Mediano',
        'type': 'undead',
        'size': 'medium',
      });

      expect(bestia.displayKind, 'Bestia Mediana');
      expect(muerto.displayKind, 'Muerto viviente Mediano');

      ContentLanguage.current = ContentLanguage.en;
      expect(bestia.displayKind, 'Medium Beast');
      expect(muerto.displayKind, 'Medium Undead');
    });

    test('un homebrew viejo sin tipo ni tamaño muestra su línea guardada', () {
      final c = _criatura({
        'source': 'homebrew',
        'kind': 'Bestia Pequeña',
      });

      expect(c.displayKind, 'Bestia Pequeña');
      ContentLanguage.current = ContentLanguage.en;
      expect(c.displayKind, 'Bestia Pequeña');
    });

    test(
        'una criatura del catálogo muestra su línea tal cual, con alineamiento',
        () {
      final c = _criatura({
        'source': 'srd_2024',
        'kind': 'Aberración Grande, legal malvada',
        'type': 'aberration',
        'size': 'large',
      });

      expect(c.displayKind, 'Aberración Grande, legal malvada');
      ContentLanguage.current = ContentLanguage.en;
      expect(c.displayKind, 'Aberración Grande, legal malvada');
    });
  });
}
