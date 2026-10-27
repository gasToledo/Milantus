import 'dart:convert';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fakes/fake_auth_dependencies.dart';
import 'fakes/fake_portrait_provider.dart';
import 'fakes/in_memory_api_token_repository.dart';
import 'fakes/in_memory_campaign_repository.dart';
import 'fakes/in_memory_chapter_repository.dart';
import 'fakes/in_memory_character_repository.dart';
import 'fakes/in_memory_encounter_repository.dart';
import 'fakes/in_memory_event_repository.dart';
import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_level_up_repository.dart';
import 'fakes/in_memory_note_repository.dart';
import 'fakes/in_memory_npc_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_repository_transaction_runner.dart';
import 'fakes/in_memory_settings_repository.dart';

/// Tokens personales y el MCP: que el token solo abra `/mcp`, que deje de
/// servir al revocarlo o vencer, y que por el MCP lo ajeno siga siendo
/// inexistente.
void main() {
  late FakeAuthDependencies fakeAuth;
  late InMemoryApiTokenRepository apiTokens;
  late Handler handler;

  setUp(() {
    fakeAuth = FakeAuthDependencies();
    apiTokens = InMemoryApiTokenRepository();
    final characters = InMemoryCharacterRepository();
    final campaigns = InMemoryCampaignRepository(characters);
    final chapters = InMemoryChapterRepository(campaigns);
    final notes = InMemoryNoteRepository(campaigns, chapters);
    final encounters = InMemoryEncounterRepository(campaigns);
    campaigns
      ..playerChaptersFor = chapters.listFor
      ..playerBattlesFor = encounters.logsFor;
    final events = InMemoryEventRepository();
    final npcs = InMemoryNpcRepository(campaigns, characters);
    final homebrew = InMemoryHomebrewRepository();
    final levelUps = InMemoryLevelUpRepository(campaigns);
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
      ),
      homebrew: homebrew,
      levelUps: levelUps,
      settings: InMemorySettingsRepository(),
      apiTokens: apiTokens,
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

  Future<({int status, dynamic json})> api(
    String method,
    String path, {
    String? cookie,
    String? bearer,
    Object? body,
  }) async {
    final response = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          if (cookie != null) 'cookie': 'dnd_session=$cookie',
          if (bearer != null) 'authorization': 'Bearer $bearer',
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final text = await response.readAsString();
    return (
      status: response.statusCode,
      json: text.isEmpty ? null : jsonDecode(text),
    );
  }

  Future<String> newToken(String cookie) async {
    final out = await api(
      'POST',
      '/api/tokens',
      cookie: cookie,
      body: {'name': 'Claude Code'},
    );
    expect(out.status, 200);
    return out.json['secret'] as String;
  }

  var rpcId = 0;
  Future<({int status, dynamic json})> rpc(
    String token,
    String method, [
    Map<String, dynamic>? params,
  ]) => api(
    'POST',
    '/mcp',
    bearer: token,
    body: {
      'jsonrpc': '2.0',
      'id': rpcId++,
      'method': method,
      'params': ?params,
    },
  );

  /// Llama a una herramienta y devuelve su texto y si fue error.
  Future<({String text, bool isError})> tool(
    String token,
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    final out = await rpc(token, 'tools/call', {
      'name': name,
      'arguments': arguments,
    });
    final result = out.json['result'] as Map<String, dynamic>;
    return (
      text: (result['content'] as List).first['text'] as String,
      isError: result['isError'] as bool,
    );
  }

  test(
    'sin token, con uno vencido o con uno revocado, /mcp responde 401',
    () async {
      final cookie = await login('dm');
      final token = await newToken(cookie);
      expect((await rpc('mlt_inventado', 'ping')).status, 401);
      expect((await api('POST', '/mcp', body: {})).status, 401);

      expect((await rpc(token, 'ping')).status, 200);
      final id =
          (await api(
                'GET',
                '/api/tokens',
                cookie: cookie,
              )).json['tokens'][0]['id']
              as String;
      apiTokens.expire(id);
      expect((await rpc(token, 'ping')).status, 401);

      final otro = await newToken(cookie);
      final otroId =
          (await api(
                'GET',
                '/api/tokens',
                cookie: cookie,
              )).json['tokens'][0]['id']
              as String;
      expect(
        (await api('DELETE', '/api/tokens/$otroId', cookie: cookie)).status,
        200,
      );
      expect((await rpc(otro, 'ping')).status, 401);
    },
  );

  test('el token abre solo /mcp: /api sigue pidiendo la cookie', () async {
    final token = await newToken(await login('dm'));
    expect((await api('GET', '/api/campaigns', bearer: token)).status, 401);
  });

  test('un token ajeno no se lista ni se revoca', () async {
    final dm = await login('dm');
    await newToken(dm);
    final id =
        (await api('GET', '/api/tokens', cookie: dm)).json['tokens'][0]['id']
            as String;
    final intruso = await login('intruso');

    expect(
      (await api('GET', '/api/tokens', cookie: intruso)).json['tokens'],
      isEmpty,
    );
    expect(
      (await api('DELETE', '/api/tokens/$id', cookie: intruso)).status,
      404,
    );
    expect(
      (await api('GET', '/api/tokens', cookie: dm)).json['tokens'],
      hasLength(1),
    );
  });

  test('por el MCP se arma una campaña con capítulo, nota y PNJ', () async {
    final token = await newToken(await login('dm'));
    final init = await rpc(token, 'initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'test', 'version': '0'},
    });
    expect(init.json['result']['capabilities'], contains('tools'));

    final campaign = jsonDecode(
      (await tool(token, 'create_campaign', {'name': 'La Costa'})).text,
    )['id'];
    final chapter = jsonDecode(
      (await tool(token, 'create_chapter', {
        'campaignId': campaign,
        'name': 'El naufragio',
      })).text,
    )['id'];
    final note = await tool(token, 'create_note', {
      'campaignId': campaign,
      'chapterId': chapter,
      'title': 'Ganchos',
      'body': 'El faro está apagado.',
    });
    expect(note.isError, isFalse);
    await tool(token, 'create_npc', {'name': 'Marla', 'campaignId': campaign});
    await tool(token, 'update_campaign', {
      'campaignId': campaign,
      'premise': 'Contrabandistas.',
    });

    final view = jsonDecode(
      (await tool(token, 'get_campaign', {'campaignId': campaign})).text,
    );
    expect(view['premise'], 'Contrabandistas.');
    expect(view['name'], 'La Costa');
    expect([for (final c in view['chapters']) c['name']], ['El naufragio']);
    expect(
      [for (final n in view['notes']) n['body']],
      ['El faro está apagado.'],
    );
    expect([for (final n in view['npcs']) n['name']], ['Marla']);
  });

  test('por el MCP, la campaña de otra cuenta no existe', () async {
    final dm = await newToken(await login('dm'));
    final campaign = jsonDecode(
      (await tool(dm, 'create_campaign', {'name': 'Propia'})).text,
    )['id'];
    final intruso = await newToken(await login('intruso'));

    for (final (name, args) in [
      ('get_campaign', {'campaignId': campaign}),
      ('update_campaign', {'campaignId': campaign, 'name': 'Robada'}),
      ('create_chapter', {'campaignId': campaign, 'name': 'Infiltrado'}),
    ]) {
      final out = await tool(intruso, name, args);
      expect(out.isError, isTrue, reason: name);
    }
    expect(
      jsonDecode(
        (await tool(dm, 'get_campaign', {'campaignId': campaign})).text,
      )['name'],
      'Propia',
    );
  });
}
