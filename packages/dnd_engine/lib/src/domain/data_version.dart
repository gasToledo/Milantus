import 'content_language.dart';

class UnsupportedDataVersionException implements Exception {
  final String dataType;
  final int found;
  final int supported;

  const UnsupportedDataVersionException({
    required this.dataType,
    required this.found,
    required this.supported,
  });

  /// En inglés no nombra [dataType], que el que lanza escribe en castellano
  /// («log de combate»): la versión dice lo que importa.
  @override
  String toString() => localized(
        'La versión $found de $dataType es más nueva que la versión '
            '$supported compatible con esta aplicación.',
        'Version $found of this data is newer than version $supported, '
            'the one this app supports.',
      );
}
