import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Chapter', () {
    test('conserva sus campos en el round-trip', () {
      const c = Chapter(
        id: 'la-cripta',
        name: 'La Cripta',
        summary: 'Bajan al osario y algo los sigue.',
        state: ChapterState.active,
        grantsLevel: true,
      );

      final r = Chapter.fromJson(c.toJson());

      expect(r.id, 'la-cripta');
      expect(r.name, 'La Cripta');
      expect(r.summary, 'Bajan al osario y algo los sigue.');
      expect(r.state, ChapterState.active);
      expect(r.grantsLevel, isTrue);
    });

    test('un capítulo nuevo nace planificado, sin descripción ni nivel', () {
      const c = Chapter(id: 'x', name: 'Sin escribir todavía');

      expect(c.summary, '');
      expect(c.state, ChapterState.planned);
      expect(c.grantsLevel, isFalse);
    });

    // El documento lo manda el cliente: que le falte un campo opcional no
    // puede impedir que el capítulo cargue.
    test('un documento incompleto usa los valores por defecto', () {
      final r = Chapter.fromJson({'id': 'x'});

      expect(r.id, 'x');
      expect(r.name, '');
      expect(r.summary, '');
      expect(r.state, ChapterState.planned);
      expect(r.grantsLevel, isFalse);
    });

    test('un estado desconocido cae en planificado en vez de romper', () {
      final r = Chapter.fromJson({'id': 'x', 'state': 'abandonado'});

      expect(r.state, ChapterState.planned);
    });

    test('copyWith cambia lo pasado y conserva el resto', () {
      const c = Chapter(
        id: 'x',
        name: 'La Cripta',
        summary: 'Algo pasa',
        grantsLevel: true,
      );

      final r = c.copyWith(state: ChapterState.completed);

      expect(r.id, 'x');
      expect(r.name, 'La Cripta');
      expect(r.summary, 'Algo pasa');
      expect(r.state, ChapterState.completed);
      expect(r.grantsLevel, isTrue);
    });

    // --- Recompensas ---
    //
    // El capítulo las anuncia; ninguna la aplica la app. Estos casos fijan lo
    // que se guarda, no lo que se reparte: repartirlo sería escribir la ficha
    // de otra cuenta.

    test('el botín sobrevive el round-trip', () {
      const c = Chapter(
        id: 'x',
        name: 'La Cripta',
        grantsGold: 250,
        grantsItems: ['Espada larga +1', 'Poción de curación'],
      );

      final r = Chapter.fromJson(c.toJson());

      expect(r.grantsGold, 250);
      expect(r.grantsItems, ['Espada larga +1', 'Poción de curación']);
    });

    test('un capítulo nuevo no reparte nada', () {
      const c = Chapter(id: 'x', name: 'y');

      expect(c.grantsGold, 0);
      expect(c.grantsItems, isEmpty);
      expect(c.grantsRewards, isFalse);
      expect(c.rewardsLabel, '');
    });

    test('un capítulo viejo, sin los campos, no reparte nada', () {
      final r = Chapter.fromJson({'id': 'x', 'name': 'y'});

      expect(r.grantsGold, 0);
      expect(r.grantsItems, isEmpty);
    });

    // Sube de nivel es lo único que reparte: no hay botín que mostrar.
    test('el nivel no cuenta como botín', () {
      const c = Chapter(id: 'x', name: 'y', grantsLevel: true);

      expect(c.grantsRewards, isFalse);
    });

    // Oro negativo no se puede mostrar ni gastar, igual que en la bolsa de un
    // personaje. Se descarta en vez de rechazar el capítulo entero.
    test('el oro negativo o de otro tipo se lee como cero', () {
      expect(Chapter.fromJson({'id': 'x', 'grantsGold': -50}).grantsGold, 0);
      expect(Chapter.fromJson({'id': 'x', 'grantsGold': '250'}).grantsGold, 0);
      expect(Chapter.fromJson({'id': 'x', 'grantsGold': null}).grantsGold, 0);
    });

    test('los ítems en blanco y los que no son texto se descartan', () {
      final r = Chapter.fromJson({
        'id': 'x',
        'grantsItems': ['  Espada larga +1  ', '', '   ', 7, null],
      });

      expect(r.grantsItems, ['Espada larga +1']);
    });

    test('copyWith conserva el botín que no se pasó', () {
      const c = Chapter(
        id: 'x',
        name: 'y',
        grantsGold: 250,
        grantsItems: ['Espada larga +1'],
      );

      final r = c.copyWith(state: ChapterState.completed);

      expect(r.grantsGold, 250);
      expect(r.grantsItems, ['Espada larga +1']);
    });

    test('en inglés, con la coma antes de «and» y las monedas del SRD', () {
      addTearDown(() => ContentLanguage.current = ContentLanguage.es);
      ContentLanguage.current = ContentLanguage.en;
      expect(describeRewards(0, const [], level: true), 'a level');
      expect(describeRewards(250, const ['Sword']), '250 gp and Sword');
      expect(
        describeRewards(250, const ['Sword'], level: true),
        'a level, 250 gp, and Sword',
      );
    });

    test('el botín se nombra en una línea que se pueda leer en voz alta', () {
      expect(describeRewards(0, const []), '');
      expect(describeRewards(0, const [], level: true), 'un nivel');
      expect(
        describeRewards(250, const ['Espada larga +1'], level: true),
        'un nivel, 250 po y Espada larga +1',
      );
      expect(describeRewards(250, const []), '250 po');
      expect(describeRewards(0, const ['Espada larga +1']), 'Espada larga +1');
      expect(
        describeRewards(0, const ['Espada larga +1', 'Poción de curación']),
        'Espada larga +1 y Poción de curación',
      );
      expect(
        describeRewards(250, const ['Espada larga +1', 'Poción de curación']),
        '250 po, Espada larga +1 y Poción de curación',
      );
    });

    // La etiqueta es para la pantalla; lo que viaja es el nombre inglés, que
    // es lo que el servidor compara.
    test('el estado serializa su nombre y no su etiqueta', () {
      expect(ChapterState.active.toJson(), 'active');
      expect(
        const Chapter(
          id: 'x',
          name: 'y',
          state: ChapterState.completed,
        ).toJson()['state'],
        'completed',
      );
    });

    test('el documento estampa la versión de esquema actual', () {
      const c = Chapter(id: 'x', name: 'y');

      expect(c.toJson()['schemaVersion'], Chapter.currentSchemaVersion);
    });

    test('un documento sin versión se trata como la 1', () {
      expect(Chapter.schemaVersionOf({'id': 'x'}), 1);
    });

    test('una versión que no es entero positivo es un error de formato', () {
      expect(
        () => Chapter.schemaVersionOf({'schemaVersion': 0}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Chapter.schemaVersionOf({'schemaVersion': 'dos'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza una versión futura con un error comprensible', () {
      expect(
        () => Chapter.migrateJson({
          'schemaVersion': Chapter.currentSchemaVersion + 1,
          'id': 'x',
        }),
        throwsA(
          isA<UnsupportedDataVersionException>()
              .having((e) => e.dataType, 'tipo', 'capítulo')
              .having(
                (e) => e.found,
                'versión encontrada',
                Chapter.currentSchemaVersion + 1,
              )
              .having(
                (e) => e.supported,
                'versión soportada',
                Chapter.currentSchemaVersion,
              ),
        ),
      );
    });

    test('migrar no modifica el mapa de entrada', () {
      final source = <String, dynamic>{'id': 'x', 'name': 'y'};

      Chapter.migrateJson(source);

      expect(source, {'id': 'x', 'name': 'y'});
    });

    test('un capítulo de la versión 1 migra a la actual y se lee igual', () {
      final migrated = Chapter.migrateJson({
        'schemaVersion': 1,
        'id': 'x',
        'name': 'y',
        'grantsItems': ['Mapa'],
      });

      expect(migrated['schemaVersion'], Chapter.currentSchemaVersion);
      final r = Chapter.fromJson({'schemaVersion': 1, 'id': 'x'});
      expect(r.grantsCatalog, isEmpty);
    });
  });

  group('Chapter, objetos del catálogo', () {
    const potion = ChapterItem(
      category: 'items',
      itemId: 'potion-of-healing',
      name: 'Poción de curación',
      quantity: 2,
    );
    const blade = ChapterItem(
      category: 'weapons',
      itemId: 'regalo-1',
      name: 'Hoja del Cuervo',
      baseItemId: 'longsword',
      homebrew: true,
    );

    test('sobreviven el round-trip', () {
      const c = Chapter(id: 'x', name: 'y', grantsCatalog: [potion, blade]);

      final r = Chapter.fromJson(c.toJson());

      expect(r.grantsCatalog.map((i) => i.toJson()), [
        potion.toJson(),
        blade.toJson(),
      ]);
      expect(r.grantsCatalog.last.homebrew, isTrue);
      expect(r.grantsCatalog.last.baseItemId, 'longsword');
    });

    test('lo que no se puede leer se descarta sin rechazar el capítulo', () {
      final r = Chapter.fromJson({
        'id': 'x',
        'grantsCatalog': [
          {
            'category': 'items',
            'itemId': 'rope',
            'name': 'Cuerda',
            'quantity': 0
          },
          {'category': 'spells', 'itemId': 'fireball', 'name': 'Bola de fuego'},
          {'category': 'items', 'itemId': '  ', 'name': 'Vacío'},
          {'category': 'items', 'itemId': 'rope'},
          'texto suelto',
          null,
        ],
      });

      expect(r.grantsCatalog, hasLength(1));
      // La cantidad mínima es 1.
      expect(r.grantsCatalog.single.quantity, 1);
    });

    test('se nombran en el botín, con ×n si son más de uno', () {
      const c = Chapter(
        id: 'x',
        name: 'y',
        grantsGold: 120,
        grantsItems: ['Mapa del contrabandista'],
        grantsCatalog: [potion, blade],
      );

      expect(c.grantsRewards, isTrue);
      expect(
        c.rewardsLabel,
        '120 po, Mapa del contrabandista, Poción de curación ×2 y Hoja del Cuervo',
      );
      expect(c.grantsLabel, startsWith('120 po'));
      expect(
        const Chapter(id: 'x', name: 'y', grantsCatalog: [blade]).grantsRewards,
        isTrue,
      );
    });

    test('copyWith conserva los objetos que no se pasaron', () {
      const c = Chapter(id: 'x', name: 'y', grantsCatalog: [potion]);

      expect(c.copyWith(state: ChapterState.active).grantsCatalog, [potion]);
    });
  });

  group('Chapter.entryOrder', () {
    // Cerrar o empezar un capítulo pasa por copyWith: perder el orden ahí
    // desacomodaría el Cuaderno sin que el DM tocara nada.
    test('sobrevive el round-trip y el copyWith', () {
      const c = Chapter(
        id: 'x',
        name: 'y',
        entryOrder: ['fight:1', 'note:a'],
      );

      expect(Chapter.fromJson(c.toJson()).entryOrder, ['fight:1', 'note:a']);
      expect(
        c.copyWith(state: ChapterState.completed).entryOrder,
        ['fight:1', 'note:a'],
      );
    });

    test('una clave repetida o que no es texto se descarta', () {
      final r = Chapter.fromJson({
        'schemaVersion': Chapter.currentSchemaVersion,
        'id': 'x',
        'entryOrder': ['note:a', 3, '', 'note:a', 'fight:1'],
      });

      expect(r.entryOrder, ['note:a', 'fight:1']);
    });

    test('un capítulo de la versión 2 se lee sin orden propio', () {
      final r = Chapter.fromJson({'schemaVersion': 2, 'id': 'x'});

      expect(r.entryOrder, isEmpty);
    });
  });
}
