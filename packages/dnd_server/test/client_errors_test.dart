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
import 'fakes/in_memory_scenario_repository.dart';
import 'fakes/in_memory_settings_repository.dart';

Handler _handler(FakeAuthDependencies auth, {List<String>? lines}) {
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
    scenarios: InMemoryScenarioRepository(campaigns, npcs),
    clientErrorLog: lines?.add,
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
}
