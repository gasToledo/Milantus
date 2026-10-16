import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  group('Npc — round-trip', () {
    test('un PNJ sin estadísticas conserva sus datos narrativos', () {
      final npc = Npc(
        id: 'npc-1',
        name: 'Toblen',
        sheetKind: NpcSheetKind.none,
        speech: 'Habla con la boca llena.',
        appearance: 'Delantal manchado',
        background: 'Dueño de la posada.',
        tags: const ['Phandalin'],
        notes: [
          DiaryEntry(
            entryId: 'n1',
            title: 'Deudas',
            body: 'Debe oro',
            createdAt: DateTime.utc(2026, 9, 14),
          ),
        ],
        portraitPaths: const ['npc-1/a.png'],
        portraitPrompts: const {'npc-1/a.png': 'retrato'},
      );

      final r = Npc.fromJson(npc.toJson());

      expect(r.name, 'Toblen');
      expect(r.sheetKind, NpcSheetKind.none);
      expect(r.hasStats, isFalse);
      expect(r.speech, npc.speech);
      expect(r.appearance, npc.appearance);
      expect(r.background, npc.background);
      expect(r.tags, ['Phandalin']);
      expect(r.notes.single.title, 'Deudas');
      expect(r.notes.single.body, 'Debe oro');
      expect(r.notes.single.createdAt, DateTime.utc(2026, 9, 14));
      expect(r.portraitPaths, ['npc-1/a.png']);
      expect(r.portraitPrompts, {'npc-1/a.png': 'retrato'});
    });

    test('un PNJ con bloque guarda una copia completa de la criatura', () {
      final knight = repo.creature('knight')!;
      final npc = Npc(
        id: 'npc-2',
        name: 'Capitana Ilse Varn',
        sheetKind: NpcSheetKind.block,
        block: knight,
        baseCreatureId: knight.id,
        baseCreatureName: knight.name,
      );

      final r = Npc.fromJson(npc.toJson());

      expect(r.hasStats, isTrue);
      expect(r.baseCreatureName, knight.name);
      expect(r.block!.hp, knight.hp);
      expect(r.block!.ac, knight.ac);
      expect(r.block!.actions.length, knight.actions.length);
    });

    test('un PNJ con ficha de personaje guarda el id de su ficha', () {
      final npc = Npc(
        id: 'npc-3',
        name: 'Maerith',
        sheetKind: NpcSheetKind.character,
        characterId: 'npc-3-ficha',
      );

      final r = Npc.fromJson(npc.toJson());

      expect(r.sheetKind, NpcSheetKind.character);
      expect(r.characterId, 'npc-3-ficha');
      expect(r.block, isNull);
    });

    test('editar el bloque no toca la criatura de origen', () {
      final knight = repo.creature('knight')!;
      final npc = Npc(
        id: 'npc-2',
        name: 'Ilse',
        sheetKind: NpcSheetKind.block,
        block: knight,
      );
      final edited = npc.copyWith(
        block: Creature.fromJson({...knight.toJson(), 'hp': '60'}),
      );

      expect(edited.block!.hp, '60');
      expect(repo.creature('knight')!.hp, knight.hp);
      expect(edited.sheetKind, NpcSheetKind.block);
    });
  });

  group('Npc — tags', () {
    test('no quedan dos tags que solo difieran en mayúsculas', () {
      final npc = Npc(
        id: 'a',
        name: 'A',
        sheetKind: NpcSheetKind.none,
        tags: const ['Waterdeep', 'waterdeep', ' ', 'Enemigos '],
      );

      expect(npc.tags, ['Waterdeep', 'Enemigos']);
      expect(npc.hasTag('WATERDEEP'), isTrue);
    });
  });

  group('Npc — versionado', () {
    Map<String, dynamic> doc() =>
        Npc(id: 'a', name: 'A', sheetKind: NpcSheetKind.none).toJson();

    test('el documento estampa la versión actual', () {
      expect(doc()['schemaVersion'], Npc.currentSchemaVersion);
    });

    test('migrar no modifica el mapa de entrada', () {
      final source = doc();
      final copy = Map<String, dynamic>.from(source);
      Npc.migrateJson(source);
      expect(source, copy);
    });

    test('rechaza una versión futura', () {
      expect(
        () => Npc.fromJson({...doc(), 'schemaVersion': 99}),
        throwsA(isA<UnsupportedDataVersionException>()),
      );
    });

    // Una nota de la v1, tal como quedó guardada en la base.
    Map<String, dynamic> docV1() => {
          'schemaVersion': 1,
          'id': 'a',
          'name': 'A',
          'sheetKind': 'none',
          'notes': [
            {
              'id': 'n1',
              'date': '2026-09-14T10:00:00.000Z',
              'text': 'Debe oro'
            },
            {
              'id': 'n2',
              'date': '2026-09-15T10:00:00.000Z',
              'text': 'Línea 1\nLínea 2'
            },
          ],
        };

    test('una nota v1 migra a una entrada de texto con el texto entero', () {
      final r = Npc.fromJson(docV1());

      expect(r.notes.map((n) => n.entryId), ['n1', 'n2']);
      expect(r.notes.every((n) => n.kind == DiaryEntryKind.text), isTrue);
      expect(r.notes.every((n) => n.title.isEmpty), isTrue);
      expect(r.notes[0].body, 'Debe oro');
      expect(r.notes[1].body, 'Línea 1\nLínea 2');
      expect(r.notes[0].createdAt, DateTime.utc(2026, 9, 14, 10));
      expect(r.notes[0].updatedAt, isNull);
    });

    test('migrar la v1 no modifica la entrada y estampa la versión actual', () {
      final source = docV1();
      final antes =
          (source['notes'] as List).map((n) => Map.of(n as Map)).toList();

      final migrado = Npc.migrateJson(source);

      expect(migrado['schemaVersion'], Npc.currentSchemaVersion);
      expect(source['schemaVersion'], 1);
      expect(source['notes'], antes);
    });

    test('una nota v1 sin id no choca con otra: cada una conserva su lugar',
        () {
      final r = Npc.fromJson({
        ...docV1(),
        'notes': [
          {'text': 'a'},
          {'text': 'b'},
        ],
      });

      expect(r.notes.map((n) => n.entryId).toSet(), hasLength(2));
    });

    test('ida y vuelta de una nota con imagen y un enlace', () {
      final npc = Npc(
        id: 'a',
        name: 'A',
        sheetKind: NpcSheetKind.none,
        notes: [
          DiaryEntry(
            entryId: 'i',
            kind: DiaryEntryKind.image,
            title: 'Retrato de época',
            imageKey: 'a/1.png',
          ),
          DiaryEntry(
            entryId: 'l',
            kind: DiaryEntryKind.link,
            title: 'Su canción',
            body: 'https://example.com/cancion',
          ),
        ],
      );

      final json = npc.toJson();
      final r = Npc.fromJson(json);

      expect(json['schemaVersion'], 2);
      expect(r.notes[0].kind, DiaryEntryKind.image);
      expect(r.notes[0].imageKey, 'a/1.png');
      expect(r.notes[1].kind, DiaryEntryKind.link);
      expect(r.notes[1].body, 'https://example.com/cancion');
    });

    test('un tipo desconocido cae en sin estadísticas', () {
      final r = Npc.fromJson({...doc(), 'sheetKind': 'algo-nuevo'});
      expect(r.sheetKind, NpcSheetKind.none);
    });
  });

  group('NpcStatus', () {
    test('un estado desconocido cae en vivo', () {
      expect(NpcStatus.fromJson('zombi'), NpcStatus.alive);
      expect(NpcStatus.fromJson('dead'), NpcStatus.dead);
    });
  });
}
