part of 'app.dart';

/// La Biblioteca de guiones y el guion de cada capítulo. Son del DM: ninguna
/// ruta de acá cruza cuentas ni la usa un jugador.
void _mountScriptRoutes(
  Router router,
  Handler Function(Handler) authenticated,
  ScriptRepository scripts,
  CampaignRepository campaigns,
  ChapterRepository chapters,
) {
  /// El guion es del capítulo de una campaña del DM: se validan las dos antes
  /// de tocar nada.
  Handler onChapter(
    Future<Response> Function(
      Request request,
      String campaignId,
      String chapterId,
    )
    handle,
  ) => authenticated((request) async {
    final campaignId = requireSafePathSegment(
      request.params['id']!,
      label: 'id de campaña',
    );
    final chapterId = requireSafePathSegment(
      request.params['chapterId']!,
      label: 'id de capítulo',
    );
    if (await campaigns.find(request.userId, campaignId) == null) {
      return _notFound('campaign_not_found');
    }
    if (await chapters.find(request.userId, campaignId, chapterId) == null) {
      return _notFound('chapter_not_found');
    }
    return handle(request, campaignId, chapterId);
  });

  /// La respuesta de las rutas de un capítulo: la vista va calculada para que
  /// la web no tenga que pedirla aparte.
  Future<Response> chapterScript(
    String userId,
    String campaignId,
    String chapterId,
  ) async {
    final current = await scripts.forChapter(userId, campaignId, chapterId);
    if (current == null) return _jsonOk({'script': null});
    return _jsonOk({
      'script': current.script.toJson(),
      'progress': current.progress.toJson(),
      'view': ScriptView.of(current.script, current.progress).toJson(),
      'campaigns': current.campaigns,
    });
  }

  const chapterPath = '/api/campaigns/<id>/chapters/<chapterId>/script';

  router
    ..get(
      '/api/scripts',
      authenticated((request) async {
        final all = await scripts.listForDm(request.userId);
        return _jsonOk({
          'scripts': [for (final stored in all) _storedScriptJson(stored)],
        });
      }),
    )
    ..post(
      '/api/scripts',
      authenticated((request) async {
        final script = _scriptFromBody(await _readJsonBody(request));
        requireSafePathSegment(script.id, label: 'id de guion');
        final stored = await scripts.create(request.userId, script);
        return _jsonOk({'script': stored.toJson()});
      }),
    )
    ..get(
      '/api/scripts/<id>',
      authenticated((request) async {
        final stored = await scripts.find(request.userId, _scriptId(request));
        return stored == null
            ? _notFound('script_not_found')
            : _jsonOk(_storedScriptJson(stored));
      }),
    )
    ..put(
      '/api/scripts/<id>',
      authenticated((request) async {
        final id = _scriptId(request);
        final script = _scriptFromBody(await _readJsonBody(request));
        if (script.id != id) {
          throw const FormatException(
            'El id del guion no coincide con la ruta.',
          );
        }
        return await scripts.save(request.userId, script)
            ? _jsonOk({'script': script.toJson()})
            : _notFound('script_not_found');
      }),
    )
    ..delete(
      '/api/scripts/<id>',
      authenticated((request) async {
        final id = _scriptId(request);
        if (await scripts.find(request.userId, id) == null) {
          return _notFound('script_not_found');
        }
        await scripts.delete(request.userId, id);
        return _jsonOk({'status': 'ok'});
      }),
    )
    ..post(
      '/api/scripts/<id>/duplicate',
      authenticated((request) async {
        final sourceId = _scriptId(request);
        final source = await scripts.find(request.userId, sourceId);
        if (source == null) return _notFound('script_not_found');
        final body = await _readJsonBody(request);
        final id = body['id'];
        final name = body['name'];
        if (id is! String || name is! String || name.trim().isEmpty) {
          throw const FormatException('La copia necesita un id y un nombre.');
        }
        requireSafePathSegment(id, label: 'id de guion');
        final copy = await scripts.create(
          request.userId,
          source.script.copyWith(id: id, name: name.trim()),
        );
        final campaignId = body['campaignId'];
        final chapterId = body['chapterId'];
        if (campaignId is String && chapterId is String) {
          // `forChapter` filtra por el DM: un capítulo ajeno no aparece.
          final current = await scripts.forChapter(
            request.userId,
            campaignId,
            chapterId,
          );
          if (current?.script.id == sourceId) {
            await scripts.attach(
              request.userId,
              campaignId,
              chapterId,
              copy.id,
              progress: current!.progress,
            );
          }
        }
        return _jsonOk({'script': copy.toJson()});
      }),
    )
    ..get(
      chapterPath,
      onChapter(
        (request, campaignId, chapterId) =>
            chapterScript(request.userId, campaignId, chapterId),
      ),
    )
    ..put(
      chapterPath,
      onChapter((request, campaignId, chapterId) async {
        final scriptId = (await _readJsonBody(request))['scriptId'];
        if (scriptId is! String || scriptId.isEmpty) {
          throw const FormatException('Falta "scriptId".');
        }
        if (await scripts.find(request.userId, scriptId) == null) {
          return _notFound('script_not_found');
        }
        // Siempre con el progreso vacío, también si es el mismo guion: es
        // «empezar de nuevo».
        await scripts.attach(request.userId, campaignId, chapterId, scriptId);
        return chapterScript(request.userId, campaignId, chapterId);
      }),
    )
    ..delete(
      chapterPath,
      onChapter((request, campaignId, chapterId) async {
        await scripts.detach(request.userId, campaignId, chapterId);
        return _jsonOk({'status': 'ok'});
      }),
    )
    ..post(
      '$chapterPath/progress',
      onChapter((request, campaignId, chapterId) async {
        // El cliente manda la acción, nunca el progreso: lo calcula el motor.
        final action = (await _readJsonBody(request))['action'];
        if (action is! Map<String, dynamic>) {
          throw const FormatException('Falta "action".');
        }
        final current = await scripts.forChapter(
          request.userId,
          campaignId,
          chapterId,
        );
        if (current == null) return _notFound('script_not_found');
        await scripts.saveProgress(
          request.userId,
          campaignId,
          chapterId,
          ScriptProgressOps.apply(current.script, current.progress, action),
        );
        return chapterScript(request.userId, campaignId, chapterId);
      }),
    );
}

String _scriptId(Request request) =>
    requireSafePathSegment(request.params['id']!, label: 'id de guion');

Map<String, dynamic> _storedScriptJson(StoredScript stored) => {
  'script': stored.script.toJson(),
  'campaigns': stored.campaigns,
};

/// Mismo criterio que `_characterFromRequestJson`: cualquier fallo de forma es
/// un 400, y la versión futura conserva su mensaje.
Script _scriptFromBody(Map<String, dynamic> body) {
  final requested = body['script'];
  if (requested is! Map<String, dynamic>) {
    throw const FormatException('Falta "script".');
  }
  final Script script;
  try {
    script = Script.fromJson(requested);
  } on UnsupportedDataVersionException {
    rethrow;
  } catch (error) {
    throw FormatException('Guion inválido: $error');
  }
  final name = script.name.trim();
  if (name.isEmpty) {
    throw const FormatException('El guion necesita un nombre.');
  }
  return script.copyWith(name: name);
}
