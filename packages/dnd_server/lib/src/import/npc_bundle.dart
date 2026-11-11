import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_engine/npc_bundle_export.dart' show adoptCharacterAsNpc;

import 'backup_bundle.dart';
import 'homebrew_content.dart';

/// Un retrato que viaja en el paquete, con a quién pertenece.
class NpcBundlePortrait {
  /// `npc` para los retratos propios del PNJ, `character` para los de su
  /// ficha de personaje.
  final String owner;

  /// La clave que tenía en la cuenta de origen. No sobrevive la importación
  /// —el retrato se guarda con una clave nueva—, pero hace falta para
  /// encontrar su prompt y su lugar en la lista.
  final String originalKey;
  final Uint8List bytes;

  const NpcBundlePortrait({
    required this.owner,
    required this.originalKey,
    required this.bytes,
  });
}

class NpcBundle {
  final Npc npc;
  final Character? sheet;
  final Map<String, List<Map<String, dynamic>>> homebrew;
  final List<NpcBundlePortrait> portraits;

  const NpcBundle({
    required this.npc,
    this.sheet,
    this.homebrew = const {},
    this.portraits = const [],
  });
}

/// Lector del archivo con que un DM le pasa un PNJ a otro.
///
/// Es un formato propio y no el del respaldo (`dnd_bundle`) a propósito: el
/// respaldo es de personajes jugadores, y un PNJ importado por esa vía
/// terminaría en «Mis personajes». Acá la ruta de entrada es otra y el tipo del
/// archivo lo dice.
///
/// Todo lo que llega es de otra cuenta, quizás de otra instalación: se valida
/// **antes** de escribir nada, con los mismos límites que el respaldo.
class NpcBundleCodec {
  static const type = 'dnd_npc';
  static const formatVersion = 1;
  static const manifestName = 'npc-bundle.json';
  static const maxArchiveBytes = 64 * 1024 * 1024;
  static const maxEntryBytes = 32 * 1024 * 1024;
  static const maxJsonBytes = 8 * 1024 * 1024;

  static final _portraitName = RegExp(r'^portraits/\d+\.(png|jpe?g|webp|gif)$');

  /// Lo que lee **toda** entrada de un PNJ (la vista previa y la importación):
  /// el archivo de un PNJ (`dnd_npc`) o el de **un** personaje exportado desde
  /// «Mis personajes» (`dnd_bundle`), que entra como PNJ con ficha.
  ///
  /// Sigue habiendo una sola puerta: el personaje se adopta acá, antes de que
  /// la ruta de importación escriba nada. Se lee con el decodificador validado
  /// del respaldo (límites de tamaño, rutas, entradas), no con el de Flutter,
  /// que abre el ZIP sin límites: en un servidor eso es un riesgo.
  static NpcBundle decodeForImport(List<int> bytes) {
    if (bytes.length > maxArchiveBytes) {
      throw const FormatException('El archivo del PNJ es demasiado grande.');
    }
    // Se abre solo para ver qué manifiesto trae; la validación de verdad la
    // hace el decodificador que corresponda.
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo no es un ZIP válido.');
    }
    if (archive.findFile(manifestName) != null) return decode(bytes);
    if (archive.findFile('manifest.json') != null) {
      return _adoptBackup(BackupBundleCodec.decode(bytes));
    }
    throw const FormatException('El ZIP no es un PNJ exportado.');
  }

  static NpcBundle _adoptBackup(BackupBundle backup) {
    if (backup.characters.length != 1) {
      throw const FormatException(
        'Para sumar un personaje como PNJ hay que exportar uno solo.',
      );
    }
    final entry = backup.characters.single;

    // El decodificador del respaldo suelta las claves de retrato del personaje
    // (no sirven en otra cuenta) y deja a cada retrato su nombre de archivo,
    // que empieza con su posición en `portraitPaths`. Acá se arman claves
    // propias en ese orden: lo único que importa es que cada retrato y su
    // prompt encuentren su lugar en la ficha. Uno sin número, o repetido, se
    // omite en vez de adivinar.
    final byIndex = <int, BundlePortrait>{};
    for (final portrait in entry.portraits) {
      final index = int.tryParse(
        RegExp(r'^\d+').stringMatch(portrait.fileName) ?? '',
      );
      if (index != null) byIndex.putIfAbsent(index, () => portrait);
    }
    final ordered = byIndex.keys.toList()..sort();
    final keys = {for (final i in ordered) i: 'retrato-$i'};
    final original = entry.character.copyWith(
      portraitPaths: [for (final i in ordered) keys[i]!],
      portraitPrompts: {
        for (final i in ordered)
          if (byIndex[i]!.prompt case final prompt?) keys[i]!: prompt,
      },
    );

    final adopted = adoptCharacterAsNpc(
      original,
      backup.homebrew ?? const {},
      imageEntryIds: {for (final i in entry.diaryImages) i.entryId},
    );
    if (adopted.npc.name.trim().isEmpty) {
      throw const FormatException('El PNJ no tiene nombre.');
    }
    return NpcBundle(
      npc: adopted.npc,
      sheet: adopted.sheet,
      homebrew: adopted.homebrew,
      portraits: [
        for (final i in ordered)
          NpcBundlePortrait(
            owner: 'character',
            originalKey: keys[i]!,
            bytes: byIndex[i]!.bytes,
          ),
      ],
    );
  }

  static NpcBundle decode(List<int> bytes) {
    try {
      return _decode(bytes);
    } on FormatException {
      rethrow;
    } on UnsupportedDataVersionException {
      rethrow;
    } catch (error) {
      throw FormatException('El archivo del PNJ no es válido: $error');
    }
  }

  static NpcBundle _decode(List<int> bytes) {
    if (bytes.length > maxArchiveBytes) {
      throw const FormatException('El archivo del PNJ es demasiado grande.');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final files = <String, ArchiveFile>{};
    var total = 0;
    for (final entry in archive) {
      final name = entry.name;
      final allowed = name == manifestName || _portraitName.hasMatch(name);
      if (!entry.isFile ||
          entry.isSymbolicLink ||
          !allowed ||
          files.containsKey(name)) {
        throw const FormatException(
          'El archivo del PNJ contiene entradas no permitidas.',
        );
      }
      if (entry.size > maxEntryBytes) {
        throw const FormatException(
          'El archivo del PNJ contiene un archivo demasiado grande.',
        );
      }
      total += entry.size;
      if (total > maxArchiveBytes) {
        throw const FormatException('El archivo del PNJ es demasiado grande.');
      }
      files[name] = entry;
    }

    final manifestEntry = files[manifestName];
    if (manifestEntry == null || manifestEntry.size > maxJsonBytes) {
      throw const FormatException('El ZIP no es un PNJ exportado.');
    }
    final manifest = jsonDecode(utf8.decode(_readBytes(manifestEntry)));
    if (manifest is! Map || manifest['type'] != type) {
      throw const FormatException('El ZIP no es un PNJ exportado.');
    }
    final version = manifest['formatVersion'];
    if (version is! int || version < 1) {
      throw const FormatException('Versión de archivo de PNJ inválida.');
    }
    if (version > formatVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'archivo de PNJ',
        found: version,
        supported: formatVersion,
      );
    }

    final rawNpc = manifest['npc'];
    if (rawNpc is! Map) throw const FormatException('Falta el PNJ.');
    final npc = Npc.fromJson(rawNpc.cast<String, dynamic>());
    if (npc.name.trim().isEmpty) {
      throw const FormatException('El PNJ no tiene nombre.');
    }

    final rawSheet = manifest['character'];
    final sheet = rawSheet is Map
        ? Character.fromJson(rawSheet.cast<String, dynamic>())
        : null;
    if ((npc.sheetKind == NpcSheetKind.character) != (sheet != null)) {
      throw const FormatException('La ficha del PNJ no coincide con su tipo.');
    }

    final rawHomebrew = manifest['homebrew'];
    final homebrew = rawHomebrew is Map
        ? parseHomebrewContent(rawHomebrew.cast<String, dynamic>())
        : const <String, List<Map<String, dynamic>>>{};

    final portraits = <NpcBundlePortrait>[];
    for (final raw in (manifest['portraits'] as List? ?? const [])) {
      if (raw is! Map) {
        throw const FormatException('Retrato inválido en el archivo.');
      }
      final file = raw['file'];
      final owner = raw['owner'];
      final key = raw['key'];
      final entry = file is String ? files[file] : null;
      if (entry == null ||
          (owner != 'npc' && owner != 'character') ||
          key is! String) {
        throw const FormatException('Retrato inválido en el archivo.');
      }
      portraits.add(
        NpcBundlePortrait(
          owner: owner as String,
          originalKey: key,
          bytes: _readBytes(entry),
        ),
      );
    }

    return NpcBundle(
      npc: npc,
      sheet: sheet,
      homebrew: homebrew,
      portraits: portraits,
    );
  }

  static Uint8List _readBytes(ArchiveFile entry) {
    final bytes = entry.readBytes();
    if (bytes == null) {
      throw FormatException('No se pudo leer ${entry.name}.');
    }
    return bytes;
  }
}
