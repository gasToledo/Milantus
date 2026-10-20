import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Spell spell(String id) => repo.spells[id]!;

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
