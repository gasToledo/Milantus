import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

import '../tool/translate_content.dart';

/// Un recorte con la forma de los archivos de 5etools.
final _fiveEtools = [
  {
    'spell': [
      {'name': 'Magic Missile', 'source': 'PHB'},
      {'name': 'Magic Missile', 'source': 'XPHB'},
    ],
    'baseitem': [
      {'name': 'Padded Armor', 'source': 'XPHB'},
    ],
    'feat': [
      {'name': 'Athlete', 'source': 'XPHB'},
      {'name': 'Defense', 'source': 'XPHB'},
    ],
    'subclass': [
      {'name': 'College of Lore', 'shortName': 'Lore', 'source': 'XPHB'},
      {
        'name': 'Path of the Berserker',
        'shortName': 'Berserker',
        'source': 'XPHB',
      },
    ],
  },
];

void main() {
  final index = indexFiveEtools(_fiveEtools);

  group('englishName', () {
    test('cruza por id y por las formas que usa el catálogo', () {
      expect(englishName(index, ['spell'], 'magic-missile'), 'Magic Missile');
      expect(englishName(index, ['baseitem'], 'padded'), 'Padded Armor');
      expect(englishName(index, ['feat'], 'fs-defense'), 'Defense');
      expect(
        englishName(index, ['feat'], 'athlete-strength'),
        'Athlete (Strength)',
      );
      expect(
        englishName(index, ['subclass'], 'college-lore'),
        'College of Lore',
      );
      expect(
        englishName(index, ['subclass'], 'berserker'),
        'Path of the Berserker',
      );
      expect(englishName(index, ['spell'], 'bolsa-de-contencion'), isNull);
    });
  });

  group('fillOverlay', () {
    final pack = [
      {'id': 'magic-missile', 'name': 'Proyectil Mágico', 'range': '120 pies'},
      {'id': 'toque-raro', 'name': 'Toque Raro', 'range': 'Toque'},
    ];
    String? nameFor(String id) => englishName(index, ['spell'], id);

    test('completa nombres y alcances, y lista lo que falta', () {
      final r = fillOverlay('spells', pack, {}, nameFor);
      final misil = r.overlay['magic-missile'] as Map<String, dynamic>;
      expect(misil['name'], 'Magic Missile');
      expect(misil['range'], '120 feet');
      expect(translationProblems('spells', pack, r.overlay), isEmpty);
      expect(r.pending, [contains('spells/toque-raro')]);
    });

    test('correrla dos veces no cambia nada', () {
      final primera = fillOverlay('spells', pack, {}, nameFor).overlay;
      final segunda = fillOverlay('spells', pack, primera, nameFor).overlay;
      expect(segunda, primera);
    });

    test('nunca pisa lo traducido a mano', () {
      final aMano = {
        'magic-missile': {
          translationFingerprintKey: contentFingerprint(pack.first, ['name']),
          'name': 'Magic Dart',
        },
      };
      final r = fillOverlay('spells', pack, aMano, nameFor).overlay;
      final misil = r['magic-missile'] as Map<String, dynamic>;
      expect(misil['name'], 'Magic Dart');
      expect(misil['range'], '120 feet');
      expect(translationProblems('spells', pack, r), isEmpty);
    });

    test('no completa una entrada desfasada, la lista', () {
      final vieja = {
        'magic-missile': {translationFingerprintKey: '00000000', 'name': 'X'},
      };
      final r = fillOverlay('spells', pack, vieja, nameFor);
      expect(r.overlay['magic-missile'], vieja['magic-missile']);
      expect(r.pending.first, contains('desfasada'));
    });
  });

  test('refreshOverlay recalcula huellas y dice cuáles cambió', () {
    final pack = [
      {'id': 'magic-missile', 'name': 'Proyectil Mágico'},
    ];
    final r = refreshOverlay(pack, {
      'magic-missile': {translationFingerprintKey: '00000000', 'name': 'MM'},
    });
    expect(r.changed, ['magic-missile']);
    expect(translationProblems('spells', pack, r.overlay), isEmpty);
    expect(refreshOverlay(pack, r.overlay).changed, isEmpty);
  });
}
