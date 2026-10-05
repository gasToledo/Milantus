import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

List<Map<String, dynamic>> _catalogo(String nombre) =>
    (jsonDecode(File('lib/assets/srd_2024/$nombre.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  tearDown(() => ContentLanguage.current = ContentLanguage.es);

  test('todo valor de vocabulario del catálogo tiene su inglés', () {
    final faltan = <String>[];
    for (final MapEntry(key: catalogo, value: campos)
        in vocabularyFieldsByCatalog.entries) {
      for (final entrada in _catalogo(catalogo)) {
        for (final campo in campos) {
          final valor = entrada[campo];
          if (valor is! String) continue;
          final field = VocabularyField.values.byName(campo);
          if (vocabularyEnglish(field, valor) == null) {
            faltan.add('$catalogo.$campo: $valor');
          }
        }
      }
    }
    expect(faltan.toSet(), isEmpty);
  });

  test('los patrones con número', () {
    expect(vocabularyEnglish(VocabularyField.range, '120 pies'), '120 feet');
    expect(vocabularyEnglish(VocabularyField.range, '1 milla'), '1 mile');
    expect(
      vocabularyEnglish(VocabularyField.range, 'Personal (cono 30 pies)'),
      'Self (30-foot cone)',
    );
    expect(
      vocabularyEnglish(VocabularyField.range, 'Personal (aura de 15 pies)'),
      'Self (15-foot aura)',
    );
    expect(
      vocabularyEnglish(VocabularyField.range, 'Cono de 15 pies'),
      '15-foot cone',
    );
    expect(
      vocabularyEnglish(
        VocabularyField.duration,
        'Concentración, hasta 10 minutos',
      ),
      'Concentration, up to 10 minutes',
    );
    expect(
      vocabularyEnglish(VocabularyField.duration, 'Hasta 1 hora'),
      'Up to 1 hour',
    );
    expect(
      vocabularyEnglish(VocabularyField.castingTime, '1 minuto'),
      '1 minute',
    );
  });

  test('vocabularyLabel sigue al idioma y deja tal cual lo desconocido', () {
    expect(vocabularyLabel(VocabularyField.school, 'Evocación'), 'Evocación');
    ContentLanguage.current = ContentLanguage.en;
    expect(vocabularyLabel(VocabularyField.school, 'Evocación'), 'Evocation');
    expect(
      vocabularyLabel(VocabularyField.school, 'Cronomancia'),
      'Cronomancia',
    );
    expect(
      vocabularyLabel(VocabularyField.range, 'Personal (tirabuzón 5 pies)'),
      'Personal (tirabuzón 5 pies)',
    );
  });

  test('la superposición no puede traducir vocabulario cerrado', () {
    final conjuro = _catalogo('spells').first;
    final problemas = translationProblems('spells', [
      conjuro,
    ], {
      conjuro['id'] as String: {
        translationFingerprintKey: contentFingerprint(conjuro, [
          'name',
          'school',
        ]),
        'name': 'X',
        'school': 'Y',
      },
    });
    expect(problemas, [contains('«school» es vocabulario cerrado')]);
  });
}
