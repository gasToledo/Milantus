import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'dnd_engine.dart';
import 'homebrew_references.dart';

/// Un retrato que viaja en el archivo: de quién es (`npc` o `character`), la
/// clave que tiene en esta cuenta y sus bytes.
typedef NpcBundlePortrait = ({String owner, String key, Uint8List bytes});

/// Qué eligió el DM llevar en el archivo, además de lo que va siempre.
typedef NpcExportOptions = ({bool background, bool tags, bool notes});

/// El PNJ tal como viaja con [options]: lo desmarcado se vacía. Las campañas y
/// el estado en cada una **nunca** viajan: no están en el documento del PNJ,
/// así que no hay nada que sacar.
Npc npcForExport(Npc npc, NpcExportOptions options) => npc.copyWith(
      background: options.background ? npc.background : '',
      tags: options.tags ? npc.tags : const [],
      notes: options.notes ? npc.notes : const [],
    );

/// Las imágenes que viajan con un PNJ: de quién es cada una y su clave.
///
/// Las usan Flutter (que las baja del servidor) y el servidor (que las lee del
/// almacén): un solo criterio de qué viaja.
List<({String owner, String key})> npcExportImageKeys(
  Npc npc,
  Character? sheet,
  NpcExportOptions options,
) =>
    [
      for (final key in npc.portraitPaths) (owner: 'npc', key: key),
      if (sheet != null)
        for (final key in sheet.portraitPaths) (owner: 'character', key: key),
      // Las imágenes de las notas viajan como los retratos, y solo si viajan
      // las notas. Un PNJ con ficha las guarda en la carpeta de la ficha (ver
      // `_uploadNoteImage`), y el servidor las reubica según el dueño.
      if (options.notes)
        for (final note in npc.notes)
          if (note.imageKey case final key?)
            (
              owner: sheet != null && key.startsWith('${sheet.id}/')
                  ? 'character'
                  : 'npc',
              key: key,
            ),
    ];

/// El PNJ con ficha que sale de un personaje exportado: el trasfondo y las
/// entradas del Diario (sin las de imagen) pasan al PNJ y se vacían en la
/// ficha; el homebrew se reduce al que la ficha usa.
///
/// Es el personaje retirado de un jugador que vuelve a la mesa en manos del DM.
/// Al revés no hay camino: un PNJ nunca se traspasa a un jugador.
({Npc npc, Character sheet, Map<String, List<Map<String, dynamic>>> homebrew})
    adoptCharacterAsNpc(
  Character original,
  Map<String, List<Map<String, dynamic>>> allHomebrew,
) {
  final homebrew = homebrewUsedBy(original, allHomebrew);

  final npc = Npc(
    id: 'importado',
    name: original.name,
    sheetKind: NpcSheetKind.character,
    background: original.background,
    // Las entradas del Diario son del mismo tipo que las notas del PNJ, así
    // que pasan tal cual (texto y enlaces). Las de imagen no: su archivo vive
    // en el respaldo aparte de los retratos y acá no hay a dónde mandarlo.
    notes: [
      for (final e in original.diary)
        if (e.kind != DiaryEntryKind.image &&
            [e.title, e.body].any((t) => t.trim().isNotEmpty))
          e,
    ],
  );
  // Vaciados en la ficha para que no quede una copia que nadie ve.
  final sheet = Character.fromJson(
    original.toJson()
      ..['background'] = ''
      ..['diary'] = const [],
  );
  return (npc: npc, sheet: sheet, homebrew: homebrew);
}

/// El archivo con que un DM le pasa un PNJ a otro (tipo `dnd_npc`).
///
/// Lo arma el servidor (`GET /api/npcs/<id>/export`) y también Flutter, que
/// sigue armándolo en el cliente. El lector con sus límites es el
/// `NpcBundleCodec` de `dnd_server`: este lado solo escribe. Es un formato
/// aparte del respaldo a propósito: el respaldo es de personajes jugadores, y un
/// PNJ que entrara por ahí terminaría en «Mis personajes».
class NpcBundleWriter {
  static const type = 'dnd_npc';
  static const formatVersion = 1;
  static const manifestName = 'npc-bundle.json';

  static Uint8List encode({
    required Npc npc,
    Character? sheet,
    Map<String, List<Map<String, dynamic>>> homebrew = const {},
    List<NpcBundlePortrait> portraits = const [],
  }) {
    final archive = Archive();
    final entries = <Map<String, dynamic>>[];
    for (final (i, portrait) in portraits.indexed) {
      final file = 'portraits/$i.${_extensionOf(portrait.bytes)}';
      archive.addFile(ArchiveFile.bytes(file, portrait.bytes));
      entries.add({'file': file, 'owner': portrait.owner, 'key': portrait.key});
    }
    final manifest = {
      'type': type,
      'formatVersion': formatVersion,
      'npc': npc.toJson(),
      if (sheet != null) 'character': sheet.toJson(),
      if (homebrew.values.any((docs) => docs.isNotEmpty)) 'homebrew': homebrew,
      'portraits': entries,
    };
    archive.addFile(
      ArchiveFile.bytes(manifestName, utf8.encode(jsonEncode(manifest))),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _extensionOf(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length > 11 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length > 5 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'gif';
    }
    return 'png';
  }
}
