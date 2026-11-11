import '../domain/character.dart' show DiaryEntry;

/// Las reglas de una lista de entradas: el Diario de un personaje y las notas de
/// un PNJ. Viven acá para que un segundo dueño no repita cómo se recorta el
/// título o qué fecha cambia al editar.
class DiaryOps {
  const DiaryOps._();

  /// `entry` (el id), `title`, `body`, `imageKey`, `url`, `linkLabel` y `at`.
  /// Título, cuerpo, enlace y nombre se recortan; un enlace o un nombre vacío se
  /// guardan como null y un cuerpo vacío como vacío. Un id existente se
  /// reemplaza en su lugar, conserva `createdAt` y pone `updatedAt`; uno nuevo
  /// va al final y sin `updatedAt`. Una entrada puede llevar texto, imagen y
  /// enlace a la vez: solo el título es obligatorio, y `null` si falta.
  static List<DiaryEntry>? save(
    List<DiaryEntry> entries,
    Map<String, dynamic> action,
  ) {
    final title = (action['title'] as String? ?? '').trim();
    if (title.isEmpty) return null;
    final imageKey = action['imageKey'] as String?;
    final url = _trimmedOrNull(action['url']);
    final linkLabel = _trimmedOrNull(action['linkLabel']);
    final id = action['entry'] as String;
    final at = DateTime.parse(action['at'] as String);
    final body = (action['body'] as String? ?? '').trim();
    final index = entries.indexWhere((e) => e.entryId == id);
    final DiaryEntry entry;
    if (index < 0) {
      // `updatedAt` queda vacío: en una entrada recién escrita las dos fechas
      // serían la misma y la tarjeta diría «editada» de algo nuevo.
      entry = DiaryEntry(
        entryId: id,
        title: title,
        body: body,
        imageKey: imageKey,
        url: url,
        linkLabel: linkLabel,
        createdAt: at,
      );
    } else {
      entry = entries[index].copyWith(
        title: title,
        body: body,
        imageKey: imageKey,
        url: url,
        linkLabel: linkLabel,
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

  static String? _trimmedOrNull(Object? value) {
    final text = (value as String? ?? '').trim();
    return text.isEmpty ? null : text;
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
