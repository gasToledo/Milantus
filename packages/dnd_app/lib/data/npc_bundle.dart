// l10n-ignore-file: errores sin contexto de interfaz, en los dos idiomas con `localized` (siguen a `ContentLanguage`, que `main.dart` fija con el idioma de la interfaz).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_engine/npc_bundle_export.dart';

import 'backup_bundle.dart';
export 'package:dnd_engine/homebrew_references.dart' show homebrewUsedBy;
// El escritor y los tipos del archivo viven en el motor, donde los comparte el
// servidor; acá se reexportan para que el resto de la app no cambie de import.
export 'package:dnd_engine/npc_bundle_export.dart'
    show NpcBundlePortrait, NpcExportOptions, npcExportImageKeys, npcForExport;

/// Lo que se ve de un archivo de PNJ antes de importarlo.
class NpcBundlePreview {
  final Npc npc;
  final Character? sheet;
  final Map<String, List<Map<String, dynamic>>> homebrew;
  final int portraitCount;

  const NpcBundlePreview({
    required this.npc,
    this.sheet,
    this.homebrew = const {},
    this.portraitCount = 0,
  });

  /// Los nombres del homebrew que trae, para la vista previa.
  List<String> get homebrewNames => [
    for (final docs in homebrew.values)
      for (final doc in docs) '${doc['name'] ?? doc['id']}',
  ];
}

/// El archivo con que un DM le pasa un PNJ a otro (tipo `dnd_npc`).
///
/// El servidor tiene su propio lector (`NpcBundleCodec` en `dnd_server`) y es
/// quien decide si el archivo vale: este lado solo lo arma, y lo lee para la
/// vista previa. Es un formato aparte del respaldo a propósito: el respaldo es
/// de personajes jugadores, y un PNJ que entrara por ahí terminaría en «Mis
/// personajes».
class NpcBundleCodec {
  static const type = NpcBundleWriter.type;
  static const formatVersion = NpcBundleWriter.formatVersion;
  static const manifestName = NpcBundleWriter.manifestName;

  static Uint8List encode({
    required Npc npc,
    Character? sheet,
    Map<String, List<Map<String, dynamic>>> homebrew = const {},
    List<NpcBundlePortrait> portraits = const [],
  }) => NpcBundleWriter.encode(
    npc: npc,
    sheet: sheet,
    homebrew: homebrew,
    portraits: portraits,
  );

  /// Lee lo necesario para mostrar qué trae el archivo. Lanza
  /// [FormatException] si no es un PNJ exportado y
  /// [UnsupportedDataVersionException] si viene de una versión futura.
  static NpcBundlePreview preview(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw FormatException(
        localized(
          'El archivo no es un ZIP válido.',
          'The file isn’t a valid ZIP.',
        ),
      );
    }
    final manifestFile = archive.findFile(manifestName);
    final content = manifestFile?.readBytes();
    if (content == null) {
      throw FormatException(
        localized(
          'El archivo no es un PNJ exportado.',
          'The file isn’t an exported NPC.',
        ),
      );
    }
    final manifest = jsonDecode(utf8.decode(content));
    if (manifest is! Map || manifest['type'] != type) {
      throw FormatException(
        localized(
          'El archivo no es un PNJ exportado.',
          'The file isn’t an exported NPC.',
        ),
      );
    }
    final version = manifest['formatVersion'];
    if (version is int && version > formatVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'archivo de PNJ',
        found: version,
        supported: formatVersion,
      );
    }
    final rawSheet = manifest['character'];
    final rawHomebrew = manifest['homebrew'];
    return NpcBundlePreview(
      npc: Npc.fromJson((manifest['npc'] as Map).cast<String, dynamic>()),
      sheet: rawSheet is Map
          ? Character.fromJson(rawSheet.cast<String, dynamic>())
          : null,
      homebrew: rawHomebrew is Map
          ? {
              for (final e in rawHomebrew.entries)
                '${e.key}': [
                  for (final doc in (e.value as List? ?? const []))
                    if (doc is Map) doc.cast<String, dynamic>(),
                ],
            }
          : const {},
      portraitCount: (manifest['portraits'] as List? ?? const []).length,
    );
  }

  /// Rearma el archivo de un personaje exportado desde «Mis personajes»
  /// (`dnd_bundle`) como el de un PNJ con ficha: el personaje retirado de un
  /// jugador vuelve a la mesa en manos del DM. Cualquier otro archivo vuelve
  /// tal cual, y [preview] decide si es un PNJ.
  ///
  /// Se convierte acá y no en el servidor porque el servidor ya sabe importar
  /// un PNJ con ficha, retratos y homebrew: una segunda ruta de importación
  /// sería una segunda puerta que validar. Al revés no hay camino: un PNJ
  /// nunca se traspasa a un jugador.
  ///
  /// El trasfondo y las entradas del Diario pasan al PNJ, porque la ficha de
  /// un PNJ no muestra el Diario. Las imágenes del Diario no viajan por esta
  /// vía (el respaldo las guarda aparte de los retratos); sí viajan las de las
  /// notas de un PNJ exportado como PNJ (ver `exportNpcFlow`).
  static Uint8List adoptCharacterExport(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return bytes;
    }
    Object? json(String name) {
      final content = archive.findFile(name)?.readBytes();
      return content == null ? null : jsonDecode(utf8.decode(content));
    }

    final manifest = json('manifest.json');
    if (manifest is! Map || manifest['type'] != BackupBundleCodec.type) {
      return bytes;
    }
    final version = manifest['formatVersion'];
    if (version is int && version > BackupBundleCodec.formatVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'respaldo',
        found: version,
        supported: BackupBundleCodec.formatVersion,
      );
    }
    final entries = manifest['characters'] as List? ?? const [];
    if (entries.length != 1) {
      throw FormatException(
        entries.isEmpty
            ? localized(
                'El archivo no trae ningún personaje.',
                'The file has no character.',
              )
            : localized(
                'El respaldo trae ${entries.length} personajes: exportá desde '
                    '«Mis personajes» solo el que quieras sumar como PNJ.',
                'The backup has ${entries.length} characters: from “My '
                    'characters”, export only the one you want to add as an NPC.',
              ),
      );
    }
    final entry = entries.single as Map;
    final original = Character.fromJson(
      (json(entry['file'] as String) as Map).cast<String, dynamic>(),
    );

    // El respaldo nombra cada retrato por su posición en `portraitPaths`
    // (`portraits/<id>/<i>.png`); uno que no se pudo leer al exportar falta,
    // y por eso se busca por número y no por orden.
    final portraits = <NpcBundlePortrait>[];
    for (final file in (entry['portraits'] as List? ?? const [])) {
      final index = RegExp(r'/(\d+)\.png$').firstMatch('$file')?.group(1);
      final content = archive.findFile('$file')?.readBytes();
      final i = index == null ? null : int.parse(index);
      if (content == null || i == null || i >= original.portraitPaths.length) {
        continue;
      }
      portraits.add((
        owner: 'character',
        key: original.portraitPaths[i],
        bytes: content,
      ));
    }

    final homebrewFile = manifest['homebrewFile'];
    final allHomebrew = homebrewFile is String ? json(homebrewFile) : null;
    final adopted = adoptCharacterAsNpc(original, {
      if (allHomebrew is Map)
        for (final e in allHomebrew.entries)
          '${e.key}': [
            for (final doc in (e.value as List? ?? const []))
              if (doc is Map) doc.cast<String, dynamic>(),
          ],
    });
    return encode(
      npc: adopted.npc,
      sheet: adopted.sheet,
      homebrew: adopted.homebrew,
      portraits: portraits,
    );
  }
}
