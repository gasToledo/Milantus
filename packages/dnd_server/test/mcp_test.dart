import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/auth/mcp_token.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:dnd_server/src/repositories/mcp_audit_repository.dart';
import 'package:jose/jose.dart';
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
import 'fakes/in_memory_level_up_repository.dart';
import 'fakes/in_memory_note_repository.dart';
import 'fakes/in_memory_npc_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_repository_transaction_runner.dart';
import 'fakes/in_memory_settings_repository.dart';

class _Audit implements McpAuditRepository {
  final rows = <(String, String, String)>[];
  @override
  Future<void> record(String userId, String tool, String outcome) async =>
      rows.add((userId, tool, outcome));
}

/// El MCP con OAuth: que solo entre un access token de Zitadel válido para
/// Milantus, que el scope de lectura no escriba, y que por el MCP lo ajeno
/// siga sin existir.
void main() {
  final issuer = Uri.parse('https://auth.example');
  final base = Uri.parse('https://app.example');
  const projectId = 'proyecto-milantus';
  final key = JsonWebKey.generate('RS256');
  late ContentRepository content;

  late InMemoryCharacterRepository characters;
  late InMemoryCampaignRepository campaigns;
  late InMemoryChapterRepository chapters;
  late _Audit audit;
  late Handler handler;

  setUpAll(() async {
    content = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );
  });

  setUp(() {
    characters = InMemoryCharacterRepository();
    campaigns = InMemoryCampaignRepository(characters);
    chapters = InMemoryChapterRepository(campaigns);
    final notes = InMemoryNoteRepository(campaigns, chapters);
    final encounters = InMemoryEncounterRepository(campaigns);
    campaigns
      ..playerChaptersFor = chapters.listFor
      ..playerBattlesFor = encounters.logsFor;
    final events = InMemoryEventRepository();
    final npcs = InMemoryNpcRepository(campaigns, characters);
    final homebrew = InMemoryHomebrewRepository();
    final levelUps = InMemoryLevelUpRepository(campaigns);
    audit = _Audit();
    handler = buildHandler(
      auth: FakeAuthDependencies().dependencies,
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
      mcp: McpDependencies(
        verifier: McpTokenVerifier(
          issuer: issuer,
          audience: projectId,
          loadKeys: () async => JsonWebKeySet.fromKeys([key]),
        ),
        // El `sub` es la cuenta, para que las pruebas las nombren directo.
        resolveAccount: (subject) async => subject,
        audit: audit,
        content: content,
        publicBaseUrl: base,
        issuer: issuer,
        projectId: projectId,
      ),
    );
  });

  /// Un access token como los que emite Zitadel, firmado con la clave de la
  /// prueba. Los permisos van como roles del proyecto.
  String token(
    String subject, {
    List<McpScope> scopes = McpScope.values,
    String audience = projectId,
    Duration ttl = const Duration(minutes: 5),
  }) {
    final now = DateTime.now();
    return (JsonWebSignatureBuilder()
          ..jsonContent = {
            'iss': '$issuer',
            'sub': subject,
            'aud': [audience, 'client-claude'],
            'iat': now.millisecondsSinceEpoch ~/ 1000,
            'exp': now.add(ttl).millisecondsSinceEpoch ~/ 1000,
            'urn:zitadel:iam:org:project:roles': {
              for (final s in scopes) s.role: {'org': 'milantus'},
            },
          }
          ..addRecipient(key, algorithm: 'RS256'))
        .build()
        .toCompactSerialization();
  }

  var rpcId = 0;
  Future<Response> post(
    Object? body, {
    String? bearer,
    Map<String, String> headers = const {},
  }) async => handler(
    Request(
      'POST',
      base.resolve('/mcp'),
      headers: {
        if (bearer != null) 'authorization': 'Bearer $bearer',
        ...headers,
      },
      body: jsonEncode(body),
    ),
  );

  Map<String, dynamic> call(String name, [Map<String, dynamic>? args]) => {
    'jsonrpc': '2.0',
    'id': rpcId++,
    'method': 'tools/call',
    'params': {'name': name, 'arguments': args ?? <String, dynamic>{}},
  };

  /// El resultado de una herramienta: su dato estructurado o su error.
  Future<({Map<String, dynamic>? data, String? error})> tool(
    String bearer,
    String name, [
    Map<String, dynamic>? args,
  ]) async {
    final response = await post(call(name, args), bearer: bearer);
    expect(response.statusCode, 200, reason: name);
    final result =
        jsonDecode(await response.readAsString())['result']
            as Map<String, dynamic>;
    return result['isError'] == true
        ? (data: null, error: result['content'][0]['text'] as String)
        : (
            data: result['structuredContent'] as Map<String, dynamic>,
            error: null,
          );
  }

  Future<Character> addCharacter(String account, String id) =>
      characters.create(
        account,
        Character.fromJson({
          'id': id,
          'name': 'Sagan',
          'raceId': 'human',
          'classId': 'fighter',
          'backgroundId': 'soldier',
          'assignedScores': <String, dynamic>{},
        }),
      );

  group('autorización', () {
    test('sin token, vencido o con otra audiencia responde 401 con la '
        'metadata', () async {
      for (final bearer in [
        null,
        'no-es-un-jwt',
        token('ana', ttl: const Duration(minutes: -1)),
        token('ana', audience: 'otro-proyecto'),
      ]) {
        final response = await post(call('listar_personajes'), bearer: bearer);
        expect(response.statusCode, 401);
        expect(
          response.headers['www-authenticate'],
          contains(
            'resource_metadata="$base/.well-known/oauth-protected-resource/mcp"',
          ),
        );
      }
    });

    test(
      'la metadata apunta a Zitadel y pide la audiencia del proyecto',
      () async {
        final response = await handler(
          Request(
            'GET',
            base.resolve('/.well-known/oauth-protected-resource/mcp'),
          ),
        );
        final metadata = jsonDecode(await response.readAsString());
        expect(metadata['resource'], '$base/mcp');
        expect(metadata['authorization_servers'], ['$issuer']);
        expect(
          metadata['scopes_supported'],
          contains('urn:zitadel:iam:org:project:id:$projectId:aud'),
        );
      },
    );

    test(
      'con solo lectura, escribir responde 403 insufficient_scope',
      () async {
        await addCharacter('ana', 'sagan');
        final lectura = token('ana', scopes: [McpScope.lectura]);

        expect((await tool(lectura, 'listar_personajes')).error, isNull);
        final response = await post(
          call('descanso', {'personajeId': 'sagan', 'tipo': 'largo'}),
          bearer: lectura,
        );
        expect(response.statusCode, 403);
        expect(
          response.headers['www-authenticate'],
          contains('error="insufficient_scope"'),
        );
        expect(audit.rows.last, ('ana', 'descanso', 'sin_permiso'));
      },
    );

    test('un Origin ajeno responde 403', () async {
      final response = await post(
        call('listar_personajes'),
        bearer: token('ana'),
        headers: {'origin': 'https://otro.example'},
      );
      expect(response.statusCode, 403);
    });

    test('la cookie no abre /mcp ni el token abre /api', () async {
      final api = await handler(
        Request(
          'GET',
          base.resolve('/api/characters'),
          headers: {'authorization': 'Bearer ${token('ana')}'},
        ),
      );
      expect(api.statusCode, 401);
    });
  });

  group('lo ajeno no existe', () {
    test(
      'ni la ficha ni la campaña de otra cuenta se ven ni se tocan',
      () async {
        await addCharacter('ana', 'sagan');
        await campaigns.create(
          'ana',
          const Campaign(id: 'costa', name: 'Costa'),
        );
        await chapters.create(
          'ana',
          'costa',
          const Chapter(id: 'uno', name: 'Uno'),
        );
        final before = (await characters.find('ana', 'sagan'))!.toJson();
        final intruso = token('beto');

        for (final (name, args) in [
          ('ver_personaje', {'personajeId': 'sagan'}),
          (
            'aplicar_dano_o_curacion',
            {'personajeId': 'sagan', 'tipo': 'dano', 'cantidad': 5},
          ),
          ('descanso', {'personajeId': 'sagan', 'tipo': 'corto'}),
          ('ver_campana', {'campanaId': 'costa'}),
          (
            'crear_nota',
            {'campanaId': 'costa', 'capituloId': 'uno', 'titulo': 'Robada'},
          ),
        ]) {
          final out = await tool(intruso, name, args);
          expect(out.error, contains('no encontrad'), reason: name);
        }
        expect((await characters.find('ana', 'sagan'))!.toJson(), before);
      },
    );
  });

  group('herramientas', () {
    test('el daño sale de CombatOps y se guarda en la ficha propia', () async {
      final sagan = await addCharacter('ana', 'sagan');
      final sheet = CharacterCompiler(content).compile(sagan);
      final ana = token('ana');

      final ficha = await tool(ana, 'ver_personaje', {'personajeId': 'sagan'});
      expect(ficha.data!['ca'], sheet.armorClass);
      expect(ficha.data!['pgMaximos'], sheet.maxHp);

      final golpe = await tool(ana, 'aplicar_dano_o_curacion', {
        'personajeId': 'sagan',
        'tipo': 'dano',
        'cantidad': 3,
      });
      final expected = Character.fromJson(sagan.toJson());
      CombatOps.applyDamage(expected.combat, 3, sheet: sheet);
      expect(golpe.data!['pgActuales'], expected.combat.currentHp);
      expect(
        (await characters.find('ana', 'sagan'))!.combat.currentHp,
        expected.combat.currentHp,
      );
    });

    test('un argumento que el esquema no declara es un error', () async {
      final out = await tool(token('ana'), 'listar_personajes', {'otro': 1});
      expect(out.error, contains('otro'));
    });
  });
}
