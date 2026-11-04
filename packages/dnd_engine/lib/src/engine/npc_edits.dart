import '../domain/npc.dart';
import 'diary_ops.dart';

/// Lo que se le puede escribir a un PNJ, como `SheetActions` a una ficha. No muta
/// la entrada. Una acción desconocida lanza: un cliente desfasado no tiene que
/// guardar un documento que el motor no tocó creyendo que sí.
///
/// - `setName` con `name`, recortado. Vacío deja el PNJ como estaba.
/// - `setSpeech` con `text`, recortado. Vacío la borra.
/// - `setBackground` con `text`, tal cual: recortar mientras se escribe se comería
///   el espacio del final.
/// - `addTag` con `tag` (el constructor normaliza). `removeTag` con `tag`, sin
///   distinguir mayúsculas.
/// - `saveNote`, `removeNote` y `moveNote`: los campos de [DiaryOps]. Una nota
///   inválida deja el PNJ como estaba.
class NpcEdits {
  const NpcEdits._();

  static Npc apply(Npc npc, Map<String, dynamic> action) {
    switch (action['type']) {
      case 'setName':
        final name = (action['name'] as String? ?? '').trim();
        return name.isEmpty ? npc : npc.copyWith(name: name);
      case 'setSpeech':
        return npc.copyWith(speech: (action['text'] as String? ?? '').trim());
      case 'setBackground':
        return npc.copyWith(background: action['text'] as String? ?? '');
      case 'addTag':
        return npc
            .copyWith(tags: [...npc.tags, action['tag'] as String? ?? '']);
      case 'removeTag':
        final tag = (action['tag'] as String? ?? '').trim().toLowerCase();
        return npc.copyWith(
          tags: [
            for (final t in npc.tags)
              if (t.toLowerCase() != tag) t,
          ],
        );
      case 'saveNote':
        final notes = DiaryOps.save(npc.notes, action);
        return notes == null ? npc : npc.copyWith(notes: notes);
      case 'removeNote':
        return npc.copyWith(
          notes: DiaryOps.remove(npc.notes, action['entry'] as String),
        );
      case 'moveNote':
        return npc.copyWith(
          notes: DiaryOps.move(
            npc.notes,
            action['entry'] as String,
            action['to'] as String,
          ),
        );
      default:
        throw FormatException('Acción de PNJ desconocida: ${action['type']}');
    }
  }
}
