import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;
  late ContentRepository english;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    english = await ContentRepository.loadFromDirectory('lib/assets/srd_2024',
        translation: 'en');
  });

  Spell spell(String id) => repo.spells[id]!;

  test('el catálogo declara ritual y concentración sin duplicarla en duración',
      () {
    final entries =
        jsonDecode(File('lib/assets/srd_2024/spells.json').readAsStringSync())
            as List;
    for (final entry in entries) {
      expect(entry['concentration'], isA<bool>(), reason: entry['id']);
      expect(entry['ritual'], isA<bool>(), reason: entry['id']);
      expect((entry['duration'] as String).toLowerCase(),
          isNot(contains('concentración')),
          reason: entry['id']);
    }
  });

  test('cada componente material tiene detalle en español e inglés', () {
    final translations = jsonDecode(
        File('lib/assets/srd_2024/spells.en.json').readAsStringSync()) as Map;
    for (final spell in repo.spells.values) {
      if (!spell.components.contains('M')) continue;
      expect(spell.components, matches(r'^[VS, ]*M \(.+\)$'), reason: spell.id);
      expect(translations[spell.id]['components'], isA<String>(),
          reason: spell.id);
      final translated = english.spells[spell.id]!;
      expect(translated.components, matches(r'^[VS, ]*M \(.+\)$'),
          reason: spell.id);
      expect(
          Spell.fromJson(translated.toJson()).components, translated.components,
          reason: spell.id);
    }
  });

  test('los materiales distinguen valor mínimo, consumo y partes conservadas',
      () {
    final glyph = spell('glyph-of-warding').components;
    expect(glyph, contains('al menos 200 po'));
    expect(glyph, contains('se consume'));
    expect(english.spells['glyph-of-warding']!.components,
        contains('200+ GP, which the spell consumes'));
    final pearl = spell('identify').components;
    expect(pearl, contains('al menos 100 po'));
    expect(pearl, isNot(contains('consume')));
    final clone = spell('clone').components;
    expect(
        clone, matches(r'diamante.+1000 po.+se consume.+recipiente.+2000 po'));
    expect(spell('true-strike').components, contains('al menos 1 pc'));
    expect(spell('power-word-heal').components, 'V');
    // El PDF español agrega V por error; el PHB 2024 conserva S y M.
    expect(spell('hypnotic-pattern').components, startsWith('S, M ('));
  });

  test('los textos describen las reglas de 2024 en ambos idiomas', () {
    expect(spell('counterspell').description,
        contains('salvación de Constitución'));
    expect(
        spell('counterspell').description, contains('ese espacio no se gasta'));
    expect(english.spells['counterspell']!.description,
        contains('Constitution saving throw'));
    expect(english.spells['counterspell']!.description,
        contains('that slot is not expended'));
    expect(spell('power-word-kill').description, contains('más de 100 PG'));
    expect(spell('power-word-kill').description,
        contains('12d12 de daño psíquico'));
    expect(english.spells['power-word-kill']!.description,
        contains('12d12 Psychic damage'));
    expect(spell('guidance').description, contains('elegís una habilidad'));
    expect(spell('guidance').description, contains('todas las pruebas'));
    expect(english.spells['guidance']!.description, contains('choose a skill'));
    expect(english.spells['guidance']!.description,
        contains('every ability check'));
  });

  test('la procedencia se cruzó contra el SRD 5.2.1 conjuro por conjuro', () {
    // La etiqueta decide qué cubre la atribución CC BY 4.0. El cruce por
    // nombre, nivel y escuela contra SP_SRD_CC_v5.2.1 dejó 339 conjuros del
    // SRD y 52 exclusivos del manual.
    final porFuente = <ContentSource, int>{};
    for (final s in repo.spells.values) {
      porFuente[s.source] = (porFuente[s.source] ?? 0) + 1;
    }
    expect(porFuente[ContentSource.srd2024], 339);
    expect(porFuente[ContentSource.phb2024], 52);
    expect(porFuente[ContentSource.foa2025], 1);

    // Estos sí están en el SRD, con el nombre "desmarcado" en dos casos.
    for (final id in ['divine-smite', 'hex', 'chromatic-orb', 'bigbys-hand']) {
      expect(spell(id).source, ContentSource.srd2024, reason: id);
    }
    // Y estos no: quedarse corto es seguro, al revés sería un problema.
    for (final id in ['friends', 'toll-the-dead', 'summon-beast']) {
      expect(spell(id).source, ContentSource.phb2024, reason: id);
    }
  });

  test('la mejora existe donde el manual de 2024 la publica, y en ningún otro',
      () {
    // El fixture no baja 5etools: guarda solo si esa revisión trae
    // `entriesHigherLevel` o dados que escalan. Homúnculo sirviente no está
    // en el XPHB; EFA sí le publica la mejora, y el catálogo también.
    final bloque = (jsonDecode(
            File('test/fixtures/five_etools_names.json').readAsStringSync())
        as Map)['spellHigherLevel'] as Map<String, dynamic>;
    final esperados = {
      ...(bloque['xphb'] as List).cast<String>(),
      ...(bloque['efa'] as List).cast<String>(),
    };
    expect(bloque['efa'], ['homunculus-servant']);
    final conMejora = {
      for (final s in repo.spells.values)
        if (s.higherLevel.trim().isNotEmpty) s.id,
    };
    final faltan = esperados.difference(conMejora).toList()..sort();
    final deMas = conMejora.difference(esperados).toList()..sort();
    expect(faltan, isEmpty, reason: 'sin mejora: ${faltan.join(', ')}');
    expect(deMas, isEmpty, reason: 'mejora de más: ${deMas.join(', ')}');
  });

  test('la mejora en inglés trae los mismos dados y números que en español',
      () {
    // Un «1d6» o un «5» que se pierda al traducir cambia el daño o el nivel
    // del espacio. El dado se toma entero, para que «2d6» no cuente además
    // como 2 y como 6.
    final dado = RegExp(r'\d*d\d+');
    final numero = RegExp(r'\d+');
    List<String> tokens(String text) {
      final dados = [for (final m in dado.allMatches(text)) m[0]!];
      final resto = text.replaceAll(dado, ' ');
      final numeros = [for (final m in numero.allMatches(resto)) m[0]!];
      return [...dados, ...numeros]..sort();
    }

    final distintos = <String>[];
    for (final s in repo.spells.values) {
      if (s.higherLevel.isEmpty) continue;
      final otra = english.spells[s.id]!;
      final a = tokens(s.higherLevel).join(',');
      final b = tokens(otra.higherLevel).join(',');
      if (a != b) distintos.add('${s.id}: $a ≠ $b');
    }
    expect(distintos, isEmpty, reason: distintos.join('\n'));
  });

  test('ningún conjuro comparte nombre con otro', () {
    // Dos conjuros con el mismo nombre son indistinguibles en los selectores
    // de la app.
    final porNombre = <String, String>{};
    for (final s in repo.spells.values) {
      expect(porNombre.containsKey(s.name), isFalse,
          reason: '${s.name}: ${porNombre[s.name]} y ${s.id}');
      porNombre[s.name] = s.id;
    }
  });
}
