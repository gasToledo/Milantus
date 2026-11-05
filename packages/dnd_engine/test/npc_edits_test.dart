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

  test(
      'los retratos se anteponen sin duplicar, se restauran y borrar se lleva el prompt',
      () {
    var n = NpcEdits.apply(
        npc, {'type': 'addPortrait', 'key': 'a', 'prompt': 'pa'});
    n = NpcEdits.apply(n, {'type': 'addPortrait', 'key': 'b', 'prompt': 'pb'});
    n = NpcEdits.apply(
        n, {'type': 'addPortrait', 'key': 'a', 'prompt': 'otro'});
    expect(n.portraitPaths, ['b', 'a']);
    expect(n.portraitPrompts, {'a': 'pa', 'b': 'pb'});
    n = NpcEdits.apply(n, {'type': 'restorePortrait', 'key': 'a'});
    expect(n.portraitPaths, ['a', 'b']);
    n = NpcEdits.apply(n, {'type': 'removePortrait', 'key': 'a'});
    expect(n.portraitPaths, ['b']);
    expect(n.portraitPrompts, {'b': 'pb'});
  });

  test('setAppearance recorta, y vacío la borra', () {
    final con =
        NpcEdits.apply(npc, {'type': 'setAppearance', 'text': '  alta '});
    expect(con.appearance, 'alta');
    expect(
        NpcEdits.apply(con, {'type': 'setAppearance', 'text': ' '}).appearance,
        isEmpty);
  });

  test('setBlock reemplaza el bloque, y en un PNJ sin bloque lanza', () {
    final withBlock = Npc(
      id: 'npc-2',
      name: 'Rurik',
      sheetKind: NpcSheetKind.block,
      block: Npc.emptyBlock('Rurik'),
    );
    final block = Npc.emptyBlock('Otro');
    final result = NpcEdits.apply(withBlock, {
      'type': 'setBlock',
      'block': block.toJson(),
    });
    expect(result.block!.name, 'Otro');
    expect(
      () => NpcEdits.apply(npc, {'type': 'setBlock', 'block': block.toJson()}),
      throwsFormatException,
    );
  });
}
