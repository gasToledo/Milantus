import 'dart:convert';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fakes/fake_auth_dependencies.dart';
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
import 'fakes/in_memory_settings_repository.dart';

Handler _handler(
  FakeAuthDependencies auth, {
  Set<String> v2Users = const {},
  List<String>? lines,
}) {
  final characters = InMemoryCharacterRepository();
  final campaigns = InMemoryCampaignRepository(characters);
  final chapters = InMemoryChapterRepository(campaigns);
  final encounters = InMemoryEncounterRepository(campaigns);
  final events = InMemoryEventRepository();
  final npcs = InMemoryNpcRepository(campaigns, characters);
  final homebrew = InMemoryHomebrewRepository();
  final levelUps = InMemoryLevelUpRepository(campaigns);
  final itemGrants = InMemoryItemGrantRepository(characters);
  return buildHandler(
    auth: auth.dependencies,
    portraits: InMemoryPortraitBlobStore(),
    generation: PortraitGenerationService(const []),
    importBackup: ({required userId, required bundle}) async =>
        const ImportResult(charactersImported: 0, portraitsImported: 0),
    importHomebrew: ({required userId, required content}) async => 0,
    characters: characters,
    campaigns: campaigns,
    chapters: chapters,
    notes: InMemoryNoteRepository(campaigns, chapters),
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
    v2Users: v2Users,
    clientErrorLog: lines?.add,
    webStaticHandler: (_) => Response.ok('flutter'),
  );
}

Future<String> _login(Handler handler) async {
  final callback = await handler(
    Request('GET', Uri.parse('http://localhost/auth/callback?code=c&state=x')),
  );
  return RegExp(
    r'dnd_session=([^;]+)',
  ).firstMatch(callback.headers['set-cookie']!)!.group(1)!;
}

Future<Response> _post(Handler h, String? token, Object body) async => h(
  Request(
    'POST',
    Uri.parse('http://localhost/api/client-errors'),
    headers: {'cookie': ?(token == null ? null : 'dnd_session=$token')},
    body: jsonEncode(body),
  ),
);

void main() {
  late FakeAuthDependencies auth;
  late List<String> lines;

  setUp(() {
    auth = FakeAuthDependencies();
    lines = [];
  });

  group('POST /api/client-errors', () {
    test('sin sesión es 401 y no escribe nada', () async {
      final h = _handler(auth, lines: lines);
      expect((await _post(h, null, {'message': 'x'})).statusCode, 401);
      expect(lines, isEmpty);
    });

    test(
      'escribe una línea con el usuario y solo los campos conocidos',
      () async {
        final h = _handler(auth, lines: lines);
        final token = await _login(h);
        final r = await _post(h, token, {
          'message': 'boom',
          'stack': 'Error: boom\n  at a',
          'character': {'name': 'Ficha'},
          'route': 5,
        });
        expect(r.statusCode, 204);
        expect(lines, hasLength(1));
        final logged = jsonDecode(
          lines.single.substring('client-error '.length),
        );
        expect(logged['userId'], isNotEmpty);
        expect(logged['message'], 'boom');
        expect(logged.containsKey('character'), isFalse);
        expect(logged.containsKey('route'), isFalse);
      },
    );

    test('la misma firma no vuelve a escribir', () async {
      final h = _handler(auth, lines: lines);
      final token = await _login(h);
      final body = {'message': 'bucle', 'stack': 'E\n  at x'};
      for (var i = 0; i < 5; i++) {
        expect((await _post(h, token, body)).statusCode, 204);
      }
      expect(lines, hasLength(1));
    });

    test('el límite por cuenta corta', () async {
      final h = _handler(auth, lines: lines);
      final token = await _login(h);
      for (var i = 0; i < 30; i++) {
        expect((await _post(h, token, {'message': 'e$i'})).statusCode, 204);
      }
      expect(lines, hasLength(20));
    });
  });

  group('GET / con /v2', () {
    Future<Response> root(Handler h, {String? token, String? extra}) async => h(
      Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {
          'cookie': [
            if (token != null) 'dnd_session=$token',
            ?extra,
          ].join('; '),
        },
      ),
    );

    test('redirige a /v2/ a la cuenta habilitada, también con *', () async {
      for (final lista in [
        {'account-1'},
        {'*'},
      ]) {
        final h = _handler(FakeAuthDependencies(), v2Users: lista);
        final token = await _login(h);
        final r = await root(h, token: token);
        expect(r.statusCode, 302);
        expect(r.headers['location'], '/v2/');
        expect(r.headers['cache-control'], 'no-store');
      }
    });

    test('sirve Flutter sin sesión, sin flag o con milantus_v1=1', () async {
      final h = _handler(auth, v2Users: {'account-1'});
      final token = await _login(h);
      final otra = _handler(FakeAuthDependencies(), v2Users: {'nadie'});
      final tokenOtra = await _login(otra);
      for (final r in [
        await root(h),
        await root(otra, token: tokenOtra),
        await root(h, token: token, extra: 'milantus_v1=1'),
      ]) {
        expect(r.statusCode, 200);
        expect(await r.readAsString(), 'flutter');
      }
    });
  });
}
