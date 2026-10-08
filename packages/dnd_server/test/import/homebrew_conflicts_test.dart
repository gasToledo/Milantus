import 'package:dnd_server/src/import/homebrew_content.dart';
import 'package:test/test.dart';

Map<String, dynamic> _weapon(String id, {String name = 'Lanza de prueba'}) => {
  'id': id,
  'name': name,
  'source': 'homebrew',
};

void main() {
  group('homebrewConflicts', () {
    test('un id que la cuenta no tiene no choca', () {
      expect(
        homebrewConflicts({}, {
          'weapons': [_weapon('hb-a')],
        }),
        isEmpty,
      );
    });

    test('un homebrew idéntico se reusa y no choca', () {
      final doc = _weapon('hb-a');

      expect(
        homebrewConflicts(
          {
            'weapons': [doc],
          },
          {
            'weapons': [doc],
          },
        ),
        isEmpty,
      );
    });

    test('el orden de los campos no vuelve distinto al mismo homebrew', () {
      final existing = {
        'id': 'hb-a',
        'name': 'Lanza',
        'source': 'homebrew',
        'damage': '1d6',
      };
      final incoming = {
        'damage': '1d6',
        'source': 'homebrew',
        'name': 'Lanza',
        'id': 'hb-a',
      };

      expect(
        homebrewConflicts(
          {
            'weapons': [existing],
          },
          {
            'weapons': [incoming],
          },
        ),
        isEmpty,
      );
    });

    test(
      'el mismo id con otro contenido choca y se nombra con su categoría',
      () {
        expect(
          homebrewConflicts(
            {
              'weapons': [_weapon('hb-a', name: 'Lanza vieja')],
            },
            {
              'weapons': [_weapon('hb-a', name: 'Lanza nueva')],
            },
          ),
          ['Lanza nueva (weapons)'],
        );
      },
    );

    test('un mismo id en otra categoría no choca', () {
      expect(
        homebrewConflicts(
          {
            'armor': [_weapon('hb-a')],
          },
          {
            'weapons': [_weapon('hb-a', name: 'Otra')],
          },
        ),
        isEmpty,
      );
    });
  });
}
