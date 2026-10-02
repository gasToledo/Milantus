import 'dart:convert';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/config.dart';
import 'package:dnd_server/src/feedback/feedback_mail.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fakes/fake_auth_dependencies.dart';
import 'fakes/in_memory_campaign_repository.dart';
import 'fakes/in_memory_chapter_repository.dart';
import 'fakes/in_memory_character_repository.dart';
import 'fakes/in_memory_encounter_repository.dart';
import 'fakes/in_memory_event_repository.dart';
import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_note_repository.dart';
import 'fakes/in_memory_npc_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_repository_transaction_runner.dart';
import 'fakes/in_memory_settings_repository.dart';

Handler _handler(FakeAuthDependencies auth, SendFeedbackFn? sendFeedback) {
  final characters = InMemoryCharacterRepository();
  final campaigns = InMemoryCampaignRepository(characters);
  final chapters = InMemoryChapterRepository(campaigns);
  final encounters = InMemoryEncounterRepository(campaigns);
  final events = InMemoryEventRepository();
  final npcs = InMemoryNpcRepository(campaigns, characters);
  final homebrew = InMemoryHomebrewRepository();
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
    ),
    homebrew: homebrew,
    settings: InMemorySettingsRepository(),
    sendFeedback: sendFeedback,
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

Future<Response> _post(
  Handler handler,
  String? token,
  Object body, {
  String? userAgent,
}) async => handler(
  Request(
    'POST',
    Uri.parse('http://localhost/api/feedback'),
    headers: {
      'cookie': ?(token == null ? null : 'dnd_session=$token'),
      'user-agent': ?userAgent,
    },
    body: jsonEncode(body),
  ),
);

void main() {
  late FakeAuthDependencies auth;
  late List<FeedbackEmail> sent;
  late Handler handler;

  setUp(() {
    auth = FakeAuthDependencies();
    sent = [];
    handler = _handler(auth, (email) async => sent.add(email));
  });

  group('POST /api/feedback', () {
    test('sin sesión no se manda nada', () async {
      final response = await _post(handler, null, {
        'kind': 'bug',
        'message': 'x',
      });

      expect(response.statusCode, 401);
      expect(sent, isEmpty);
    });

    test('quién escribe sale de la sesión, no del cuerpo', () async {
      final token = await _login(handler);
      final identity = auth.nextVerifiedIdentity;

      final response = await _post(handler, token, {
        'kind': 'bug',
        'message': '  No guarda la ficha  ',
        'email': 'otra@persona.org',
        'context': {
          'version': '0.20.0',
          'language': 'es',
          'origin': 'Ficha',
          'inventado': 'no debería aparecer',
        },
      }, userAgent: 'NavegadorDePrueba/1.0');

      expect(response.statusCode, 200);
      final email = sent.single;
      expect(email.replyTo, identity.email);
      expect(email.subject, '[Milantus] Error · ${identity.name}');
      expect(email.text, startsWith('No guarda la ficha\n'));
      expect(email.text, contains('Versión: 0.20.0'));
      expect(email.text, contains('Abierto desde: Ficha'));
      expect(email.text, contains('Navegador: NavegadorDePrueba/1.0'));
      expect(email.text, isNot(contains('otra@persona.org')));
      expect(email.text, isNot(contains('no debería aparecer')));
    });

    test('rechaza un tipo desconocido o un mensaje vacío', () async {
      final token = await _login(handler);

      final badKind = await _post(handler, token, {
        'kind': 'queja',
        'message': 'x',
      });
      final blank = await _post(handler, token, {
        'kind': 'idea',
        'message': '   ',
      });

      expect(badKind.statusCode, 400);
      expect(blank.statusCode, 400);
      expect(sent, isEmpty);
    });

    test('corta después del cupo por cuenta', () async {
      final token = await _login(handler);
      final limit = FeedbackRateLimiter().maxPerWindow;

      for (var i = 0; i < limit; i++) {
        final ok = await _post(handler, token, {
          'kind': 'idea',
          'message': '$i',
        });
        expect(ok.statusCode, 200);
      }
      final blocked = await _post(handler, token, {
        'kind': 'idea',
        'message': 'una más',
      });

      expect(blocked.statusCode, 429);
      expect(sent, hasLength(limit));
    });

    test('un fallo del proveedor es 502 y no gasta el cupo', () async {
      var fail = true;
      handler = _handler(auth, (email) async {
        if (fail) throw StateError('proveedor caído');
        sent.add(email);
      });
      final token = await _login(handler);
      final limit = FeedbackRateLimiter().maxPerWindow;

      for (var i = 0; i < limit; i++) {
        final failed = await _post(handler, token, {
          'kind': 'bug',
          'message': 'x',
        });
        expect(failed.statusCode, 502);
      }
      fail = false;
      final retry = await _post(handler, token, {
        'kind': 'bug',
        'message': 'x',
      });

      expect(retry.statusCode, 200);
    });

    test('sin proveedor configurado responde 503', () async {
      handler = _handler(auth, null);
      final token = await _login(handler);

      final response = await _post(handler, token, {
        'kind': 'idea',
        'message': 'x',
      });

      expect(response.statusCode, 503);
    });
  });

  group('/api/me avisa si hay envío de feedback', () {
    Future<bool> feedbackEnabled(Handler handler) async {
      final token = await _login(handler);
      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );
      return jsonDecode(await response.readAsString())['feedbackEnabled']
          as bool;
    }

    test('con proveedor', () async {
      expect(await feedbackEnabled(handler), isTrue);
    });

    test('sin proveedor', () async {
      expect(await feedbackEnabled(_handler(auth, null)), isFalse);
    });
  });

  group('workerFeedbackSender', () {
    SendFeedbackFn sender(http.Response Function(http.Request) respond) =>
        workerFeedbackSender(
          url: Uri.parse('https://milantus-feedback.example.workers.dev'),
          secret: 'secreto',
          client: MockClient((request) async => respond(request)),
        );

    test('le pasa asunto, texto y responder-a al Worker', () async {
      late http.Request captured;
      final send = sender((request) {
        captured = request;
        return http.Response('{"ok":true}', 200);
      });

      await send(
        const FeedbackEmail(
          subject: 'Asunto',
          text: 'Cuerpo',
          replyTo: 'tester@example.org',
        ),
      );

      expect(
        captured.url.toString(),
        'https://milantus-feedback.example.workers.dev',
      );
      expect(captured.headers['authorization'], 'Bearer secreto');
      expect(jsonDecode(captured.body), {
        'subject': 'Asunto',
        'text': 'Cuerpo',
        'replyTo': 'tester@example.org',
      });
    });

    test('un código de error lanza', () async {
      final send = sender(
        (_) => http.Response('{"error":"No autorizado."}', 401),
      );

      expect(
        send(const FeedbackEmail(subject: 's', text: 't')),
        throwsA(isA<StateError>()),
      );
    });

    test('un 200 sin ok también lanza', () async {
      final send = sender((_) => http.Response('<html>proxy</html>', 200));

      expect(
        send(const FeedbackEmail(subject: 's', text: 't')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('FeedbackConfig', () {
    test('sin URL o sin secreto del Worker queda deshabilitado', () {
      const completa = {
        'DND_FEEDBACK_WORKER_URL':
            'https://milantus-feedback.example.workers.dev',
        'DND_FEEDBACK_WORKER_SECRET': 'secreto',
      };
      for (final falta in completa.keys) {
        final env = {...completa}..remove(falta);
        expect(
          FeedbackConfig.fromEnvironment(env).enabled,
          isFalse,
          reason: 'sin $falta',
        );
      }
      expect(FeedbackConfig.fromEnvironment(completa).enabled, isTrue);
    });
  });
}
