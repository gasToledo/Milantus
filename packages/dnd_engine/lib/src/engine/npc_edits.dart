import '../domain/creature.dart';
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
/// - `setBlock` con `block` (una criatura en JSON): reemplaza el bloque de un PNJ
///   de bloque. En cualquier otro tipo lanza: no tendría dónde vivir.
/// - `saveNote`, `removeNote` y `moveNote`: los campos de [DiaryOps]. Una nota
///   inválida deja el PNJ como estaba.
/// - `addPortrait` con `key` y, si hay, `prompt`: antepone el retrato (queda como
///   el actual) y no duplica una clave que ya está. `restorePortrait` con `key`
///   lo pasa al frente. `removePortrait` con `key` lo quita y se lleva su prompt.
///   Misma lógica que las de la ficha (`SheetActions`), porque un PNJ sin ficha
///   guarda sus retratos en su propio documento.
/// - `setAppearance` con `text`, recortado. Vacío la borra.
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
      case 'setBlock':
        if (npc.sheetKind != NpcSheetKind.block) {
          throw const FormatException('Solo un PNJ de bloque tiene bloque.');
        }
        return npc.copyWith(
          block: Creature.fromJson(
            (action['block'] as Map).cast<String, dynamic>(),
          ),
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
      case 'addPortrait':
        final key = action['key'] as String? ?? '';
        if (key.isEmpty || npc.portraitPaths.contains(key)) return npc;
        final prompt = action['prompt'] as String?;
        return npc.copyWith(
          portraitPaths: [key, ...npc.portraitPaths],
          portraitPrompts:
              prompt == null ? null : {...npc.portraitPrompts, key: prompt},
        );
      case 'restorePortrait':
        final key = action['key'] as String;
        if (npc.portraitPaths.indexOf(key) <= 0) return npc;
        return npc.copyWith(
          portraitPaths: [key, ...npc.portraitPaths.where((k) => k != key)],
        );
      case 'removePortrait':
        final key = action['key'] as String;
        if (!npc.portraitPaths.contains(key)) return npc;
        return npc.copyWith(
          portraitPaths: [...npc.portraitPaths.where((k) => k != key)],
          portraitPrompts: {...npc.portraitPrompts}..remove(key),
        );
      case 'setAppearance':
        return npc.copyWith(
          appearance: (action['text'] as String? ?? '').trim(),
        );
      default:
        throw FormatException('Acción de PNJ desconocida: ${action['type']}');
    }
  }
}
