part of 'app.dart';

void _mountScenarioRoutes(
  Router router,
  Handler Function(Handler) authenticated,
  ScenarioRepository scenarios,
  int maxImageBytes,
) {
  router
    ..get(
      '/api/scenarios',
      authenticated((request) async {
        final all = await scenarios.listForDm(request.userId);
        return _jsonOk({
          'scenarios': [for (final scenario in all) scenario.toJson()],
        });
      }),
    )
    ..get(
      '/api/scenarios/characters',
      authenticated((request) async {
        final characters = await scenarios.listCharacters(request.userId);
        return _jsonOk({
          'characters': [
            for (final character in characters)
              {
                'key': character.key,
                'name': character.name,
                'campaignId': character.campaignId,
                'campaignName': character.campaignName,
              },
          ],
        });
      }),
    )
    ..post(
      '/api/scenarios',
      authenticated((request) async {
        final draft = await _readScenarioDraft(
          request,
          scenarios,
          maxImageBytes,
        );
        final scenario = await scenarios.create(request.userId, draft);
        return _jsonOk(scenario.toJson());
      }),
    )
    ..get(
      '/api/scenarios/<id>',
      authenticated((request) async {
        final scenario = await scenarios.find(
          request.userId,
          _scenarioId(request),
        );
        return scenario == null
            ? _notFound('scenario_not_found')
            : _jsonOk(scenario.toJson());
      }),
    )
    ..put(
      '/api/scenarios/<id>',
      authenticated((request) async {
        final id = _scenarioId(request);
        if (await scenarios.find(request.userId, id) == null) {
          return _notFound('scenario_not_found');
        }
        final draft = await _readScenarioDraft(
          request,
          scenarios,
          maxImageBytes,
        );
        final scenario = await scenarios.save(request.userId, id, draft);
        return scenario == null
            ? _notFound('scenario_not_found')
            : _jsonOk(scenario.toJson());
      }),
    )
    ..delete(
      '/api/scenarios/<id>',
      authenticated((request) async {
        final deleted = await scenarios.delete(
          request.userId,
          _scenarioId(request),
        );
        return deleted ? Response(204) : _notFound('scenario_not_found');
      }),
    )
    ..get(
      '/api/scenarios/<id>/image',
      authenticated((request) async {
        final bytes = await scenarios.readImage(
          request.userId,
          _scenarioId(request),
        );
        final type = bytes == null ? null : sniffPortraitImageType(bytes);
        return bytes == null || type == null
            ? _notFound('scenario_image_not_found')
            : Response.ok(
                bytes,
                headers: {
                  'content-type': type.contentType,
                  // El cliente pide siempre con `?v=<updatedAt>` y todo
                  // guardado mueve esa fecha: una portada nueva es otra URL,
                  // así que la vieja se puede guardar para siempre. Sin esto
                  // la lista volvía a bajar cada BYTEA de Postgres al entrar.
                  'cache-control': 'private, max-age=31536000, immutable',
                  'x-content-type-options': 'nosniff',
                },
              );
      }),
    );
}

String _scenarioId(Request request) {
  final id = request.params['id']!;
  if (!isUuid(id)) {
    throw const FormatException('El ID del escenario no es válido.');
  }
  return id;
}

Future<ScenarioDraft> _readScenarioDraft(
  Request request,
  ScenarioRepository scenarios,
  int maxImageBytes,
) async {
  final body = await _readJsonBody(
    request,
    maxBytes: _base64JsonLimit(maxImageBytes) + _defaultJsonBodyBytes,
  );
  final name = body['name'];
  final description = body['description'] ?? '';
  final characterKeys = body['characterKeys'];
  final rawImage = body['image'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException('El escenario necesita un nombre.');
  }
  if (description is! String) {
    throw const FormatException('La descripción tiene que ser texto.');
  }
  if (characterKeys != null &&
      (characterKeys is! List || characterKeys.any((key) => key is! String))) {
    throw const FormatException('Los personajes vinculados no son válidos.');
  }
  final keys = (characterKeys as List?)?.cast<String>().toSet();
  if (keys != null && keys.isNotEmpty) {
    final available = await scenarios.listCharacters(request.userId);
    if (!available
        .map((character) => character.key)
        .toSet()
        .containsAll(keys)) {
      throw const FormatException(
        'Algún personaje vinculado ya no está disponible.',
      );
    }
  }
  Uint8List? bytes;
  if (rawImage != null) {
    if (rawImage is! String) {
      throw const FormatException('La imagen tiene que estar en Base64.');
    }
    bytes = base64Decode(rawImage);
    if (bytes.length > maxImageBytes) {
      throw const PayloadTooLargeException('La imagen es demasiado grande.');
    }
    if (sniffPortraitImageType(bytes) == null) {
      throw const FormatException(
        'La imagen tiene que ser PNG, JPEG, WebP o GIF.',
      );
    }
  }
  return ScenarioDraft(
    name: name.trim(),
    description: description.trim(),
    characterKeys: keys?.toList(),
    imageChanged: body.containsKey('image'),
    image: bytes,
  );
}
