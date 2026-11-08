// l10n-ignore-file: errores sin contexto de interfaz, en los dos idiomas con `localized` (siguen a `ContentLanguage`, que `main.dart` fija con el idioma de la interfaz).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_engine/homebrew_transfer.dart' as engine_transfer;
import 'package:dnd_engine/homebrew_transfer.dart' show homebrewExportEnvelope;

import '../api/api_client.dart';
import 'backup_bundle.dart';

/// Construye los archivos de exportación en memoria, para que la UI los
/// entregue como descarga del navegador (ver capacidad `web-client`). A
/// diferencia de la versión de escritorio, no escribe a disco ni sabe nada
/// de una carpeta de exportaciones: cada método devuelve bytes y un nombre
/// de archivo sugerido.
class TransferService {
  final ApiClient api;

  const TransferService(this.api);

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static String _timestamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  /// Exporta un personaje. Los retratos se piden al servidor por su clave
  /// (autenticado por la sesión de la cuenta), no se leen de disco. [homebrew]
  /// es el que usa la ficha (ver `homebrewUsedBy`): sin él, la copia llega a
  /// otra cuenta con objetos y especies que no existen allá.
  Future<Uint8List> exportCharacter(
    Character c, {
    Map<String, List<Map<String, dynamic>>>? homebrew,
  }) => BackupBundleCodec.encode(
    scope: BackupScope.character,
    characters: [c],
    homebrew: homebrew,
    readPortrait: api.fetchPortraitBytes,
  );

  String characterExportFileName(Character c) =>
      '${_safe(c.name)}-${_safe(c.id)}.zip';

  /// Exporta un respaldo completo.
  Future<Uint8List> exportBackup(
    List<Character> all, {
    Map<String, List<Map<String, dynamic>>>? homebrew,
    Map<String, dynamic>? preferences,
  }) => BackupBundleCodec.encode(
    scope: BackupScope.full,
    characters: all,
    homebrew: homebrew,
    preferences: preferences,
    readPortrait: api.fetchPortraitBytes,
  );

  String backupFileName() => 'backup-${_timestamp()}.zip';

  /// Todo el contenido homebrew (listas JSON por tipo) envuelto en el
  /// formato `dnd_homebrew`, como bytes UTF-8 listos para descargar. El
  /// formato vive en el motor, que también lo arma en el cliente web.
  Uint8List exportHomebrew(Map<String, List<Map<String, dynamic>>> content) =>
      Uint8List.fromList(
        utf8.encode(
          jsonEncode(homebrewExportEnvelope(content, DateTime.now())),
        ),
      );

  String homebrewExportFileName() =>
      engine_transfer.homebrewExportFileName(DateTime.now());

  /// Parsea un export de homebrew (`dnd_homebrew`) a listas JSON por tipo.
  static Map<String, List<Map<String, dynamic>>> parseHomebrewImport(
    String jsonText,
  ) => engine_transfer.parseHomebrewImport(jsonText);
}
