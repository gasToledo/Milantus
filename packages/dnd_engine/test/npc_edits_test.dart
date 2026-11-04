import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  final npc = Npc(
    id: 'npc-1',
    name: 'Bruna',
    sheetKind: NpcSheetKind.none,
    tags: const ['Waterdeep'],
  );

  test('un nombre vacío deja el PNJ como estaba', () {
    expect(
        NpcEdits.apply(npc, {'type': 'setName', 'name': '  '}).name, 'Bruna');
  });

  test('un tag que solo difiere en mayúsculas no se duplica, y se quita igual',
      () {
    final same = NpcEdits.apply(npc, {'type': 'addTag', 'tag': 'waterdeep'});
    expect(same.tags, ['Waterdeep']);
    expect(NpcEdits.apply(npc, {'type': 'removeTag', 'tag': 'WATERDEEP'}).tags,
        isEmpty);
  });

  test('una nota sin título no entra', () {
    final result = NpcEdits.apply(npc, {
      'type': 'saveNote',
      'entry': 'n1',
      'kind': 'text',
      'title': ' ',
      'at': '2026-11-04T12:00:00.000Z',
    });
    expect(result.notes, isEmpty);
  });

  test('una acción desconocida lanza en vez de guardar sin tocar nada', () {
    expect(() => NpcEdits.apply(npc, {'type': 'volar'}), throwsFormatException);
  });
}
