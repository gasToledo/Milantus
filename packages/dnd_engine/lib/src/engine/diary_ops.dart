import '../domain/character.dart' show DiaryEntry, DiaryEntryKind;

/// Las reglas de una lista de entradas: el Diario de un personaje y las notas de
/// un PNJ. Viven acá para que un segundo dueño no repita cómo se recorta el
/// título o qué fecha cambia al editar.
class DiaryOps {
  const DiaryOps._();

  /// `entry` (el id), `kind`, `title`, `body`, `imageKey` y `at`. Título y cuerpo se
  /// recortan. Un id existente se reemplaza en su lugar, conserva `createdAt` y pone
  /// `updatedAt`; uno nuevo va al final y sin `updatedAt`. Una imagen lleva el cuerpo
  /// vacío y los otros tipos no llevan `imageKey`. `null` si no tiene título, o si es
  /// una imagen sin `imageKey`.
  static List<DiaryEntry>? save(
    List<DiaryEntry> entries,
    Map<String, dynamic> action,
  ) {
    final kind = DiaryEntryKind.fromJson(action['kind']);
    final title = (action['title'] as String? ?? '').trim();
    final imageKey = action['imageKey'] as String?;
    if (title.isEmpty || (kind == DiaryEntryKind.image && imageKey == null)) {
      return null;
    }
    final id = action['entry'] as String;
    final at = DateTime.parse(action['at'] as String);
    final isImage = kind == DiaryEntryKind.image;
    final body = isImage ? '' : (action['body'] as String? ?? '').trim();
    final index = entries.indexWhere((e) => e.entryId == id);
    final DiaryEntry entry;
    if (index < 0) {
      // `updatedAt` queda vacío: en una entrada recién escrita las dos fechas
      // serían la misma y la tarjeta diría «editada» de algo nuevo.
      entry = DiaryEntry(
        entryId: id,
        kind: kind,
        title: title,
        body: body,
        imageKey: isImage ? imageKey : null,
        createdAt: at,
      );
    } else {
      entry = entries[index].copyWith(
        kind: kind,
        title: title,
        body: body,
        imageKey: isImage ? imageKey : null,
        updatedAt: at,
      );
    }
    final list = [...entries];
    if (index < 0) {
      list.add(entry);
    } else {
      list[index] = entry;
    }
    return list;
  }

  static List<DiaryEntry> remove(List<DiaryEntry> entries, String id) => [
        for (final e in entries)
          if (e.entryId != id) e,
      ];

  /// Saca [id] y lo reinserta en el lugar que ocupa [to], como el reorden de
  /// Flutter. Ids que no existen, o iguales, dejan la lista como estaba.
  static List<DiaryEntry> move(List<DiaryEntry> entries, String id, String to) {
    if (id == to) return entries;
    final list = [...entries];
    final from = list.indexWhere((e) => e.entryId == id);
    final target = list.indexWhere((e) => e.entryId == to);
    if (from < 0 || target < 0) return entries;
    list.insert(target, list.removeAt(from));
    return list;
  }
}
