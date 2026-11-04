import 'package:dnd_server/src/repositories/item_grant_repository.dart';

import 'in_memory_character_repository.dart';

/// Doble de [ItemGrantRepository] en memoria para las pruebas HTTP.
///
/// Reimplementa en Dart lo que la base hace sola: el dueño en cada consulta y
/// la clave foránea en cascada contra el personaje. El SQL real no lo ejecuta
/// ninguna prueba.
class InMemoryItemGrantRepository implements ItemGrantRepository {
  InMemoryItemGrantRepository(InMemoryCharacterRepository characters) {
    characters.onCharacterDeleted.add((ownerUserId, characterId) {
      _rows.removeWhere(
        (r) =>
            r.ownerUserId == ownerUserId && r.grant.characterId == characterId,
      );
    });
  }

  final List<({String ownerUserId, ItemGrant grant})> _rows = [];
  int _counter = 0;

  Object snapshot() => List.of(_rows);

  void restore(Object raw) => _rows
    ..clear()
    ..addAll(raw as List<({String ownerUserId, ItemGrant grant})>);

  /// Cuántos regalos hay en total, para las pruebas de la cascada.
  int get count => _rows.length;

  /// Las filas de [ownerUserId], para las pruebas que miran la bandeja.
  List<ItemGrant> of(String ownerUserId) => [
    for (final r in _rows)
      if (r.ownerUserId == ownerUserId) r.grant,
  ];

  @override
  Future<void> addAll(
    String ownerUserId,
    String characterId,
    String campaignName,
    String chapterName,
    List<Map<String, dynamic>> items,
  ) async {
    for (final item in items) {
      _rows.add((
        ownerUserId: ownerUserId,
        grant: ItemGrant(
          id: '00000000-0000-4000-a000-${(_counter++).toString().padLeft(12, '0')}',
          characterId: characterId,
          campaignName: campaignName,
          chapterName: chapterName,
          item: item,
          createdAt: DateTime.fromMillisecondsSinceEpoch(_counter),
        ),
      ));
    }
  }

  @override
  Future<List<ItemGrant>> listFor(
    String ownerUserId,
    String characterId,
  ) async => [
    for (final r in _rows)
      if (r.ownerUserId == ownerUserId && r.grant.characterId == characterId)
        r.grant,
  ];

  @override
  Future<ItemGrant?> find(String ownerUserId, String id) async {
    for (final r in _rows) {
      if (r.ownerUserId == ownerUserId && r.grant.id == id) return r.grant;
    }
    return null;
  }

  @override
  Future<bool> delete(String ownerUserId, String id) async {
    final before = _rows.length;
    _rows.removeWhere((r) => r.ownerUserId == ownerUserId && r.grant.id == id);
    return _rows.length < before;
  }
}
