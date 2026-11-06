part of 'app.dart';

Future<Response> _exportHandler(
  Request request,
  CharacterRepository characters,
  HomebrewRepository homebrew,
  SettingsRepository settings,
  PortraitBlobStore portraits,
) async {
  final userId = request.userId;
  final characterId = request.url.queryParameters['characterId'];
  final Character? character;
  final List<Character> sheets;
  if (characterId == null) {
    character = null;
    sheets = (await characters.listForUser(
      userId,
    )).map((entry) => entry.character).toList();
  } else {
    character = await characters.find(userId, characterId);
    if (character == null) return _notFound('character_not_found');
    sheets = [character];
  }

  final content = await homebrew.listForUser(userId);
  final bytes = await exporter.BackupBundleCodec.encode(
    scope: character == null ? BackupScope.full : BackupScope.character,
    characters: sheets,
    homebrew: character == null ? content : homebrewUsedBy(character, content),
    preferences: character == null ? await settings.find(userId) : null,
    readPortrait: (key) async {
      try {
        return (await portraits.read(userId: userId, portraitKey: key))?.bytes;
      } on FormatException {
        // Una referencia vieja que ya no es una clave del almacén se omite.
        return null;
      }
    },
  );
  final name = character == null
      ? 'backup-${DateTime.now().toUtc().toIso8601String().substring(0, 19).replaceAll(':', '-')}'
      : '${character.name}-${character.id}';
  final fileName = '${name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.zip';
  return Response.ok(
    bytes,
    headers: {
      'content-type': 'application/zip',
      'content-disposition': 'attachment; filename="$fileName"',
      'cache-control': 'private, no-store',
    },
  );
}
