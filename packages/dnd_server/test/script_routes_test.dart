import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fakes/fake_auth_dependencies.dart';
import 'fakes/fake_portrait_provider.dart';
import 'fakes/in_memory_campaign_repository.dart';
import 'fakes/in_memory_chapter_repository.dart';
import 'fakes/in_memory_character_repository.dart';
import 'fakes/in_memory_encounter_repository.dart';
import 'fakes/in_memory_event_repository.dart';
import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_item_grant_repository.dart';
import 'fakes/in_memory_level_up_repository.dart';
import 'fakes/in_memory_note_repository.dart';
import 'fakes/in_memory_npc_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_repository_transaction_runner.dart';
import 'fakes/in_memory_scenario_repository.dart';
import 'fakes/in_memory_script_repository.dart';
import 'fakes/in_memory_settings_repository.dart';

/// Rutas de guiones del Modo DM: la Biblioteca, el progreso de cada capítulo,
/// el hito que estampa el Registro y que nada de eso le llegue a un jugador.
void main() {
  late FakeAuthDependencies fakeAuth;
  late Handler handler;

  setUp(() {
    fakeAuth = FakeAuthDependencies();
    final characters = InMemoryCharacterRepository();
    final campaigns = InMemoryCampaignRepository(characters);
    final chapters = InMemoryChapterRepository(campaigns);
    final notes = InMemoryNoteRepository(campaigns, chapters);
    final encounters = InMemoryEncounterRepository(campaigns);
    campaigns
      ..playerChaptersFor = chapters.listFor
      ..playerNotesFor = notes.listFor
      ..playerBattlesFor = encounters.logsFor;
    final events = InMemoryEventRepository();
    final npcs = InMemoryNpcRepository(campaigns, characters);
    final homebrew = InMemoryHomebrewRepository();
    final levelUps = InMemoryLevelUpRepository(campaigns);
    final itemGrants = InMemoryItemGrantRepository(characters);
    handler = buildHandler(
      auth: fakeAuth.dependencies,
      portraits: InMemoryPortraitBlobStore(),
      generation: PortraitGenerationService([
        FakePortraitProvider(id: 'pollinations', name: 'Pollinations'),
      ]),
      importBackup: ({required userId, required bundle}) async =>
          const ImportResult(charactersImported: 0, portraitsImported: 0),
      importHomebrew: ({required userId, required content}) async => 0,
      characters: characters,
      campaigns: campaigns,
      chapters: chapters,
      notes: notes,
      encounters: encounters,
      events: events,
      npcs: npcs,
      transactions: InMemoryRepositoryTransactionRunner(
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        events: events,
        npcs: npcs,
        encounters: encounters,
        homebrew: homebrew,
        levelUps: levelUps,
        itemGrants: itemGrants,
      ),
      homebrew: homebrew,
      levelUps: levelUps,
      itemGrants: itemGrants,
      settings: InMemorySettingsRepository(),
      scenarios: InMemoryScenarioRepository(campaigns, npcs),
      scripts: InMemoryScriptRepository(),
    );
  });

  Future<String> login(String subject) async {
    fakeAuth.nextVerifiedSubject = subject;
    final callback = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/auth/callback?code=c&state=x'),
      ),
    );
    return RegExp(
      r'dnd_session=([^;]+)',
    ).firstMatch(callback.headers['set-cookie']!)!.group(1)!;
  }

  Future<({int status, Map<String, dynamic> body})> send(
    String method,
    String path, {
    required String token,
    Object? body,
  }) async {
    final response = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'cookie': 'dnd_session=$token'},
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return (
      status: response.statusCode,
      body: (jsonDecode(await response.readAsString()) as Map)
          .cast<String, dynamic>(),
    );
  }

  /// La petición que tiene que salir bien: devuelve el cuerpo.
  Future<Map<String, dynamic>> ok(
    String method,
    String path, {
    required String token,
    Object? body,
  }) async {
    final response = await send(method, path, token: token, body: body);
    expect(response.status, 200, reason: '$method $path: ${response.body}');
    return response.body;
  }

  final script = Script(
    id: 'guion',
    name: 'La cripta',
    steps: [
      MilestoneStep(const Milestone(id: 'entrada', title: 'La entrada')),
      MilestoneStep(const Milestone(id: 'altar', title: 'El altar')),
    ],
  );
  final [first, second] = [for (final m in script.milestones) m.id];

  const chapterPath = '/api/campaigns/mesa/chapters/cripta/script';

  Future<void> createCampaign(String token, String id) => ok(
    'POST',
    '/api/campaigns',
    token: token,
    body: {
      'campaign': {'id': id, 'name': 'Campaña $id'},
    },
  );

  Future<void> createChapter(
    String token,
    String id, {
    String campaign = 'mesa',
    ChapterState state = ChapterState.active,
  }) => ok(
    'POST',
    '/api/campaigns/$campaign/chapters',
    token: token,
    body: {'chapter': Chapter(id: id, name: id, state: state).toJson()},
  );

  Future<void> createScript(String token) => ok(
    'POST',
    '/api/scripts',
    token: token,
    body: {'script': script.toJson()},
  );

  /// Un DM con la campaña «mesa», su capítulo en marcha y el guion puesto.
  Future<String> dmWithScript() async {
    final dm = await login('dm');
    await createCampaign(dm, 'mesa');
    await createChapter(dm, 'cripta');
    await createScript(dm);
    await ok('PUT', chapterPath, token: dm, body: {'scriptId': script.id});
    return dm;
  }

  Future<Map<String, dynamic>> reach(String token, String milestone) => ok(
    'POST',
    '$chapterPath/progress',
    token: token,
    body: {
      'action': {'type': 'reach', 'milestone': milestone},
    },
  );

  Future<List<dynamic>> entries(String token, String kind) async =>
      (await ok('GET', '/api/campaigns/mesa/notebook', token: token))[kind]
          as List;

  Future<void> writeNote(
    String token,
    String id, {
    String? milestoneId,
    bool shared = false,
  }) => ok(
    'POST',
    '/api/campaigns/mesa/notes',
    token: token,
    body: {
      'note': Note(
        id: id,
        chapterId: 'cripta',
        title: id,
        shared: shared,
        milestoneId: milestoneId,
      ).toJson(),
    },
  );

  Future<Object?> milestoneOfNote(String token, String id) async =>
      (await entries(
        token,
        'notes',
      )).singleWhere((n) => n['id'] == id)['milestoneId'];

  /// Vincula el guerrero de [player] a la campaña «mesa» de [dm].
  Future<void> joinTable(String player, String dm) async {
    await ok(
      'POST',
      '/api/characters',
      token: player,
      body: {
        'character': {
          'id': 'sagan',
          'name': 'Sagan',
          'raceId': 'human',
          'classId': 'fighter',
          'backgroundId': 'soldier',
          'assignedScores': <String, dynamic>{},
        },
      },
    );
    final shared = await ok(
      'POST',
      '/api/characters/sagan/share',
      token: player,
    );
    await ok(
      'POST',
      '/api/campaigns/mesa/members',
      token: dm,
      body: {'code': shared['code']},
    );
  }

  Future<void> fight(String dm) async {
    await ok(
      'PUT',
      '/api/campaigns/mesa/encounter',
      token: dm,
      body: {'encounter': const Encounter(id: 'combate').toJson()},
    );
    await ok('DELETE', '/api/campaigns/mesa/encounter', token: dm);
  }

  test('la Biblioteca crea, lista, edita y borra', () async {
    final dm = await dmWithScript();
    final path = '/api/scripts/${script.id}';

    final listed = (await ok('GET', '/api/scripts', token: dm))['scripts'];
    expect(listed.single['script']['id'], script.id);
    expect(listed.single['campaigns'], 1);

    final renamed = script.copyWith(name: 'La cripta hundida').toJson();
    await ok('PUT', path, token: dm, body: {'script': renamed});
    expect(
      (await ok('GET', path, token: dm))['script']['name'],
      renamed['name'],
    );

    for (final invalid in [
      script.copyWith(id: 'otro').toJson(),
      script.copyWith(name: '  ').toJson(),
    ]) {
      final response = await send(
        'PUT',
        path,
        token: dm,
        body: {'script': invalid},
      );
      expect(response.status, 400);
    }

    await ok('DELETE', path, token: dm);
    expect((await ok('GET', '/api/scripts', token: dm))['scripts'], isEmpty);
  });

  test('lo ajeno y lo inexistente responden igual', () async {
    await dmWithScript();
    final other = await login('otro-dm');
    final path = '/api/scripts/${script.id}';

    for (final (method, url, body) in [
      ('GET', path, null),
      ('PUT', path, {'script': script.toJson()}),
      ('DELETE', path, null),
      ('POST', '$path/duplicate', {'id': 'copia', 'name': 'Copia'}),
    ]) {
      final response = await send(method, url, token: other, body: body);
      expect(response.status, 404, reason: '$method $url');
      expect(response.body['code'], 'script_not_found');
    }
    for (final (method, url, body) in [
      ('GET', chapterPath, null),
      ('PUT', chapterPath, {'scriptId': script.id}),
      ('DELETE', chapterPath, null),
      (
        'POST',
        '$chapterPath/progress',
        {
          'action': {'type': 'reach', 'milestone': first},
        },
      ),
    ]) {
      final response = await send(method, url, token: other, body: body);
      expect(response.status, 404, reason: '$method $url');
      expect(response.body['code'], 'campaign_not_found');
    }
    expect((await ok('GET', '/api/scripts', token: other))['scripts'], isEmpty);
  });

  test('avanzar guarda el progreso y una acción inválida no', () async {
    final dm = await dmWithScript();

    await reach(dm, first);
    final after = await ok('GET', chapterPath, token: dm);
    expect(after['progress']['reached'], [first]);
    expect(after['view']['currentId'], second);

    final invalid = await send(
      'POST',
      '$chapterPath/progress',
      token: dm,
      body: {
        'action': {'type': 'reach', 'milestone': first},
      },
    );
    expect(invalid.status, 400);
    expect(await ok('GET', chapterPath, token: dm), after);
  });

  test('una nota nueva lleva el hito en marcha y no el del cliente', () async {
    final dm = await dmWithScript();

    await writeNote(dm, 'antes', milestoneId: second);
    await reach(dm, first);
    await writeNote(dm, 'despues');

    expect(await milestoneOfNote(dm, 'antes'), first);
    expect(await milestoneOfNote(dm, 'despues'), second);
  });

  test('mover la nota de capítulo le borra el hito', () async {
    final dm = await dmWithScript();
    await createChapter(dm, 'bosque', state: ChapterState.planned);
    await writeNote(dm, 'nota');

    Future<void> edit(String chapterId) => ok(
      'PUT',
      '/api/campaigns/mesa/notes/nota',
      token: dm,
      body: {
        'note': Note(
          id: 'nota',
          chapterId: chapterId,
          title: 'editada',
          milestoneId: second,
        ).toJson(),
      },
    );

    await edit('cripta');
    expect(await milestoneOfNote(dm, 'nota'), first);
    await edit('bosque');
    expect(await milestoneOfNote(dm, 'nota'), isNull);
  });

  test('el combate cerrado y la subida de nivel llevan el hito', () async {
    final dm = await dmWithScript();
    final player = await login('jugador');
    await joinTable(player, dm);
    await reach(dm, first);

    await fight(dm);
    final sheet = (await ok(
      'GET',
      '/api/characters',
      token: player,
    ))['characters'].single;
    await ok(
      'PUT',
      '/api/characters/sagan',
      token: player,
      body: {
        'character': {
          ...sheet['character'],
          'classHistory': ['fighter', 'fighter'],
        },
        'expectedVersion': sheet['version'],
      },
    );

    expect((await entries(dm, 'encounterLogs')).single['milestoneId'], second);
    expect((await entries(dm, 'levelUps')).single['milestoneId'], second);
  });

  test('duplicar pasa el capítulo a la copia con su progreso', () async {
    final dm = await dmWithScript();
    await createCampaign(dm, 'otra');
    await createChapter(dm, 'cripta', campaign: 'otra');
    const otherPath = '/api/campaigns/otra/chapters/cripta/script';
    await ok('PUT', otherPath, token: dm, body: {'scriptId': script.id});
    final before = await reach(dm, first);

    final copy = (await ok(
      'POST',
      '/api/scripts/${script.id}/duplicate',
      token: dm,
      body: {
        'id': 'copia',
        'name': 'Copia',
        'campaignId': 'mesa',
        'chapterId': 'cripta',
      },
    ))['script'];

    final mine = await ok('GET', chapterPath, token: dm);
    expect(mine['script']['id'], copy['id']);
    expect(mine['progress'], before['progress']);
    expect((await ok('GET', otherPath, token: dm))['script']['id'], script.id);
  });

  test('borrar el guion deja al capítulo sin guion', () async {
    final dm = await dmWithScript();

    await ok('DELETE', '/api/scripts/${script.id}', token: dm);

    expect(await ok('GET', chapterPath, token: dm), {'script': null});
  });

  test('el jugador no ve el guion ni los hitos', () async {
    final dm = await dmWithScript();
    final player = await login('jugador');
    await joinTable(player, dm);
    await writeNote(dm, 'nota', shared: true);
    await fight(dm);
    // El DM sí los tiene: si no, la negativa de abajo pasaría de vacía.
    expect(await milestoneOfNote(dm, 'nota'), first);
    expect((await entries(dm, 'encounterLogs')).single['milestoneId'], first);

    final table = (await ok(
      'GET',
      '/api/characters/sagan/campaigns',
      token: player,
    ))['campaigns'].single;

    expect(table['sharedNotes'], hasLength(1));
    expect(table['battles'], hasLength(1));
    expect(jsonEncode(table), isNot(contains('milestoneId')));
    expect((await send('GET', chapterPath, token: player)).status, 404);
  });
}
