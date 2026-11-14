import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/auth/oidc_service.dart';
import 'package:dnd_server/src/web/web_v2.dart';
import 'package:image/image.dart' as img;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/ai/portrait_provider.dart';
import 'package:dnd_server/src/import/backup_bundle.dart';
import 'package:dnd_server/src/import/homebrew_content.dart';
import 'package:dnd_server/src/import/import_service.dart';

import 'fakes/fake_auth_dependencies.dart';
import 'fakes/fake_portrait_provider.dart';
import 'fakes/in_memory_campaign_repository.dart';
import 'fakes/in_memory_chapter_repository.dart';
import 'fakes/in_memory_note_repository.dart';
import 'fakes/in_memory_npc_repository.dart';
import 'fakes/in_memory_character_repository.dart';
import 'fakes/in_memory_encounter_repository.dart';
import 'fakes/in_memory_event_repository.dart';
import 'fakes/in_memory_homebrew_repository.dart';
import 'fakes/in_memory_item_grant_repository.dart';
import 'fakes/in_memory_level_up_repository.dart';
import 'fakes/in_memory_portrait_blob_store.dart';
import 'fakes/in_memory_repository_transaction_runner.dart';
import 'fakes/in_memory_settings_repository.dart';

Map<String, dynamic> _homebrewWeapon(
  String id, [
  String name = 'Espada casera',
]) => {
  'id': id,
  'name': name,
  'source': 'homebrew',
  'category': 'martial',
  'damageDice': '1d8',
  'damageType': 'cortante',
};

Map<String, dynamic> _homebrewItem(String id, String name) => {
  'id': id,
  'name': name,
  'source': 'homebrew',
  'category': 'gear',
};

Map<String, dynamic> _homebrewCreature(String id) => {
  'id': id,
  'name': 'Bestia casera',
  'source': 'homebrew',
  'ac': '12',
  'hp': '9',
};

void main() {
  late FakeAuthDependencies fakeAuth;
  late InMemoryPortraitBlobStore portraits;
  late PortraitGenerationService generation;
  late ImportBackupFn importBackup;
  late ImportHomebrewFn importHomebrew;
  late InMemoryCharacterRepository characters;
  late InMemoryCampaignRepository campaigns;
  late InMemoryChapterRepository chapters;
  late InMemoryNoteRepository notes;
  late InMemoryEncounterRepository encounters;
  late InMemoryEventRepository events;
  late InMemoryNpcRepository npcs;
  late InMemoryRepositoryTransactionRunner transactions;
  late InMemoryHomebrewRepository homebrewRepo;
  late InMemoryLevelUpRepository levelUps;
  late InMemoryItemGrantRepository itemGrants;
  late InMemorySettingsRepository settingsRepo;
  late Handler handler;

  setUp(() {
    fakeAuth = FakeAuthDependencies();
    portraits = InMemoryPortraitBlobStore();
    generation = PortraitGenerationService([
      FakePortraitProvider(id: 'pollinations', name: 'Pollinations'),
    ]);
    importBackup = ({required userId, required bundle}) async =>
        const ImportResult(charactersImported: 0, portraitsImported: 0);
    characters = InMemoryCharacterRepository();
    campaigns = InMemoryCampaignRepository(characters);
    chapters = InMemoryChapterRepository(campaigns);
    notes = InMemoryNoteRepository(campaigns, chapters);
    encounters = InMemoryEncounterRepository(campaigns);
    campaigns
      ..playerChaptersFor = chapters.listFor
      ..playerNotesFor = notes.listFor
      ..playerBattlesFor = encounters.logsFor;
    events = InMemoryEventRepository();
    npcs = InMemoryNpcRepository(campaigns, characters);
    homebrewRepo = InMemoryHomebrewRepository();
    levelUps = InMemoryLevelUpRepository(campaigns);
    itemGrants = InMemoryItemGrantRepository(characters);
    transactions = InMemoryRepositoryTransactionRunner(
      characters: characters,
      campaigns: campaigns,
      chapters: chapters,
      events: events,
      npcs: npcs,
      encounters: encounters,
      homebrew: homebrewRepo,
      levelUps: levelUps,
      itemGrants: itemGrants,
    );
    importHomebrew = ({required userId, required content}) async {
      var count = 0;
      for (final category in content.entries) {
        for (final document in category.value) {
          await homebrewRepo.upsert(
            userId,
            category.key,
            document['id'] as String,
            document,
          );
          count++;
        }
      }
      return count;
    };
    settingsRepo = InMemorySettingsRepository();
    handler = buildHandler(
      auth: fakeAuth.dependencies,
      portraits: portraits,
      generation: generation,
      importBackup: importBackup,
      importHomebrew: importHomebrew,
      characters: characters,
      campaigns: campaigns,
      chapters: chapters,
      notes: notes,
      encounters: encounters,
      events: events,
      npcs: npcs,
      transactions: transactions,
      homebrew: homebrewRepo,
      levelUps: levelUps,
      itemGrants: itemGrants,
      settings: settingsRepo,
    );
  });

  group('/health', () {});

  test('una ruta desconocida responde 404', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/no-existe')),
    );

    expect(response.statusCode, 404);
  });

  test(
    'un error no manejado se convierte en 500 sin filtrar detalles',
    () async {
      final failing = const Pipeline()
          .addMiddleware(errorHandlingMiddleware)
          .addHandler((request) => throw StateError('boom'));
      final response = await failing(
        Request('GET', Uri.parse('http://localhost/x')),
      );

      expect(response.statusCode, 500);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], isNot(contains('boom')));
      expect(body['code'], 'internal_error');
    },
  );

  test('un FormatException se convierte en 400 con su mensaje', () async {
    final failing = const Pipeline()
        .addMiddleware(errorHandlingMiddleware)
        .addHandler((request) => throw const FormatException('dato inválido'));
    final response = await failing(
      Request('GET', Uri.parse('http://localhost/x')),
    );

    expect(response.statusCode, 400);
    final body = jsonDecode(await response.readAsString());
    expect(body['error'], 'dato inválido');
    // El código es el que el cliente traduce; el mensaje queda de detalle.
    expect(body['code'], 'invalid_data');
  });

  test('un choque de homebrew se convierte en 409 con su código', () async {
    final failing = const Pipeline()
        .addMiddleware(errorHandlingMiddleware)
        .addHandler(
          (request) => throw const HomebrewConflictException('Choca.'),
        );
    final response = await failing(
      Request('GET', Uri.parse('http://localhost/x')),
    );

    expect(response.statusCode, 409);
    final body = jsonDecode(await response.readAsString());
    expect(body['error'], 'Choca.');
    expect(body['code'], 'homebrew_conflict');
  });

  group('autenticación', () {
    test('/auth/login redirige a la URI del proveedor OIDC', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/auth/login')),
      );

      expect(response.statusCode, 302);
      expect(response.headers['location'], contains('idp.example'));
    });

    test('/api/me sin cookie de sesión responde 401', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/me')),
      );

      expect(response.statusCode, 401);
    });

    test('/api/me con una cookie inválida también responde 401', () async {
      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=no-existe'},
        ),
      );

      expect(response.statusCode, 401);
    });

    test('un callback exitoso abre sesión y /api/me la reconoce', () async {
      fakeAuth.nextVerifiedSubject = 'oidc-subject-a';

      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
        ),
      );

      expect(callback.statusCode, 302);
      final setCookie = callback.headers['set-cookie']!;
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie, contains('Secure'));
      expect(setCookie, contains('SameSite=Lax'));
      final token = RegExp(
        r'dnd_session=([^;]+)',
      ).firstMatch(setCookie)!.group(1)!;

      final me = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );
      expect(me.statusCode, 200);
      final body = jsonDecode(await me.readAsString());
      expect(body['userId'], isNotEmpty);
    });

    // Sin esto la pantalla no puede decir con qué cuenta entraste: hasta
    // ahora `/api/me` devolvía solo el id interno, que no le dice nada a nadie.
    test('/api/me devuelve el perfil que afirmó el proveedor', () async {
      fakeAuth.nextVerifiedIdentity = const OidcIdentity(
        subject: 'oidc-subject-perfil',
        name: 'Ada Lovelace',
        email: 'ada@example.org',
        pictureUrl: 'https://idp.example/ada.png',
      );
      final token = await _login(handler);

      final me = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      final body = jsonDecode(await me.readAsString());
      expect(body['name'], 'Ada Lovelace');
      expect(body['email'], 'ada@example.org');
      expect(body['pictureUrl'], 'https://idp.example/ada.png');
    });

    test('/api/me dice webV2 solo a las cuentas de DND_V2_USERS', () async {
      Handler conLista(Set<String> v2Users) => buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        importHomebrew: importHomebrew,
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
        npcs: npcs,
        transactions: transactions,
        homebrew: homebrewRepo,
        levelUps: levelUps,
        itemGrants: itemGrants,
        settings: settingsRepo,
        v2Users: v2Users,
      );
      Future<Map<String, dynamic>> me(Handler h, String token) async {
        final response = await h(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        );
        return jsonDecode(await response.readAsString());
      }

      // El primer login de cada prueba crea `account-1` (ver el fake).
      final token = await _login(handler);
      final userId = (await me(handler, token))['userId'] as String;

      expect((await me(handler, token))['webV2'], isFalse);
      expect((await me(conLista({'otra-cuenta'}), token))['webV2'], isFalse);
      final habilitada = await me(conLista({userId, 'otra-cuenta'}), token);
      expect(habilitada['webV2'], isTrue);
      // La lista no se filtra: solo el booleano de quien pregunta.
      expect(habilitada.values, isNot(contains('otra-cuenta')));
    });

    // Una cuenta del proveedor sin nombre ni correo cargados no puede romper
    // el arranque de la aplicación.
    test('/api/me tolera una sesión sin perfil', () async {
      fakeAuth.nextVerifiedIdentity = const OidcIdentity(
        subject: 'oidc-subject-sin-perfil',
      );
      final token = await _login(handler);

      final me = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(me.statusCode, 200);
      final body = jsonDecode(await me.readAsString());
      expect(body['userId'], isNotEmpty);
      expect(body['name'], isNull);
      expect(body['email'], isNull);
    });

    test('la respuesta del callback no expone tokens en el cuerpo: solo '
        'redirección y cookie', () async {
      fakeAuth.nextVerifiedSubject = 'oidc-subject-c';

      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
        ),
      );

      final body = await callback.readAsString();
      expect(body, isEmpty);
      expect(callback.headers.containsKey('set-cookie'), isTrue);
    });

    test('una aserción con emisor o firma inválidos no abre sesión', () async {
      fakeAuth.failCompleteLoginWith = StateError('firma inválida');

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
        ),
      );

      expect(response.statusCode, 401);
      expect(response.headers.containsKey('set-cookie'), isFalse);
    });

    test(
      'cerrar sesión invalida el token y una petición posterior es 401',
      () async {
        fakeAuth.nextVerifiedSubject = 'oidc-subject-b';
        final callback = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
          ),
        );
        final setCookie = callback.headers['set-cookie']!;
        final token = RegExp(
          r'dnd_session=([^;]+)',
        ).firstMatch(setCookie)!.group(1)!;

        final logout = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/logout'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        );
        expect(logout.headers['set-cookie'], contains('Max-Age=0'));

        final me = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        );
        expect(me.statusCode, 401);
      },
    );

    // Cerrar solo la sesión local deja viva la cookie de SSO del proveedor: el
    // siguiente login vuelve a entrar sin pedir credenciales y el botón parece
    // no haber hecho nada. El cliente necesita esta URL para cerrar las dos.
    test('cerrar sesión devuelve la URL de cierre del proveedor', () async {
      fakeAuth.nextVerifiedIdentity = const OidcIdentity(
        subject: 'oidc-subject-logout',
        logoutUrl: 'https://idp.example/end_session?id_token_hint=abc',
      );
      final token = await _login(handler);

      final logout = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/auth/logout'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      final body = jsonDecode(await logout.readAsString());
      expect(
        body['logoutUrl'],
        'https://idp.example/end_session?id_token_hint=abc',
      );
    });

    // Cerrar dos veces, o sin sesión, sigue sin ser un error: la sesión local
    // ya está cerrada, simplemente no hay a dónde redirigir.
    test('cerrar sesión sin sesión responde 200 con logoutUrl null', () async {
      final logout = await handler(
        Request('POST', Uri.parse('http://localhost/auth/logout')),
      );

      expect(logout.statusCode, 200);
      expect(logout.headers['set-cookie'], contains('Max-Age=0'));
      expect(jsonDecode(await logout.readAsString())['logoutUrl'], isNull);
    });

    test('dos cuentas distintas reciben sesiones que no se mezclan', () async {
      fakeAuth.nextVerifiedSubject = 'subject-a';
      final tokenA = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      fakeAuth.nextVerifiedSubject = 'subject-b';
      final tokenB = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=2&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      final meA = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$tokenA'},
          ),
        )).readAsString(),
      );
      final meB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );

      expect(meA['userId'], isNot(meB['userId']));
    });
  });

  group('/api/portraits', () {
    const pngBytes = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      1, 2, 3, 4,
    ];

    Future<String> _loginAs(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin cookie de sesión no se entrega la imagen', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/portraits/sagan/1.png')),
      );

      expect(response.statusCode, 401);
    });

    test('la propia cuenta recibe el retrato que guardó', () async {
      final token = await _loginAs('subject-owner');
      final me = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      final key = await portraits.save(
        userId: me['userId'] as String,
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/$key'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'image/png');
      expect(await response.read().expand((e) => e).toList(), pngBytes);
    });

    test(
      'un retrato de otra cuenta responde como inexistente, no 403',
      () async {
        final ownerToken = await _loginAs('subject-owner-2');
        final ownerMe = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/me'),
              headers: {'cookie': 'dnd_session=$ownerToken'},
            ),
          )).readAsString(),
        );
        final key = await portraits.save(
          userId: ownerMe['userId'] as String,
          characterId: 'sagan',
          bytes: Uint8List.fromList(pngBytes),
        );

        final intruderToken = await _loginAs('subject-intruder');
        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/portraits/$key'),
            headers: {'cookie': 'dnd_session=$intruderToken'},
          ),
        );

        expect(response.statusCode, 404);
      },
    );

    test('con ?w= devuelve la miniatura de ese ancho', () async {
      // El medallón del roster mide menos de cien píxeles y el original 1024:
      // el cliente pide el ancho en que va a dibujar porque en el navegador no
      // hay forma de decodificar a medida (ver `PortraitImage.provider`).
      final token = await _loginAs('subject-thumb');
      final me = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      final key = await portraits.save(
        userId: me['userId'] as String,
        characterId: 'sagan',
        bytes: Uint8List.fromList(
          img.encodePng(img.Image(width: 1024, height: 1024)),
        ),
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/$key?w=128'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 200);
      final bytes = Uint8List.fromList(
        await response.read().expand((e) => e).toList(),
      );
      expect(img.decodePng(bytes)!.width, 128);
      // Una clave de retrato nunca se reescribe, así que el navegador no tiene
      // por qué volver a pedirla.
      expect(response.headers['cache-control'], contains('immutable'));
    });

    test('un ?w= inservible sirve el original en vez de fallar', () async {
      // Un medallón vacío por un parámetro mal formado sería peor que bajar de
      // más: el retrato tiene que aparecer igual.
      final token = await _loginAs('subject-thumb-bad');
      final me = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      final key = await portraits.save(
        userId: me['userId'] as String,
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      for (final w in ['0', '-8', 'grande', '9999']) {
        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/portraits/$key?w=$w'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        );

        expect(response.statusCode, 200, reason: 'con w=$w');
        expect(
          await response.read().expand((e) => e).toList(),
          pngBytes,
          reason: 'con w=$w',
        );
      }
    });

    test('DELETE borra el retrato propio', () async {
      final token = await _loginAs('subject-borra');
      final me = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      final userId = me['userId'] as String;
      final key = await portraits.save(
        userId: userId,
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      final response = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/portraits/$key'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 200);
      expect(await portraits.read(userId: userId, portraitKey: key), isNull);
    });

    // Lo ajeno responde igual que lo inexistente: distinguirlos haría de la
    // ruta una forma de averiguar qué retratos tiene otra cuenta.
    test('DELETE de un retrato ajeno responde 404 y no lo toca', () async {
      final ownerToken = await _loginAs('subject-duenio-borrado');
      final ownerMe = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$ownerToken'},
          ),
        )).readAsString(),
      );
      final ownerId = ownerMe['userId'] as String;
      final key = await portraits.save(
        userId: ownerId,
        characterId: 'sagan',
        bytes: Uint8List.fromList(pngBytes),
      );

      final intruderToken = await _loginAs('subject-intruso-borrado');
      final response = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/portraits/$key'),
          headers: {'cookie': 'dnd_session=$intruderToken'},
        ),
      );

      expect(response.statusCode, 404);
      // El mismo código que un retrato que no existe: el cliente no puede
      // distinguir lo ajeno de lo inexistente ni siquiera por el código.
      expect(
        jsonDecode(await response.readAsString())['code'],
        'portrait_not_found',
      );
      expect(
        await portraits.read(userId: ownerId, portraitKey: key),
        isNotNull,
      );
    });

    test('un retrato inexistente también responde 404', () async {
      final token = await _loginAs('subject-empty');

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/sagan/no-existe.png'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 404);
      expect(
        jsonDecode(await response.readAsString())['code'],
        'portrait_not_found',
      );
    });
  });

  group('/api/portraits/providers', () {
    test('sin sesión no se entrega', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/portraits/providers')),
      );

      expect(response.statusCode, 401);
    });

    test('lista solo los proveedores configurados', () async {
      fakeAuth.nextVerifiedSubject = 'subject-providers';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/portraits/providers'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['providers'], [
        {
          'id': 'pollinations',
          'name': 'Pollinations',
          'supportsReference': false,
        },
      ]);
    });
  });

  group('/api/portraits/generate', () {
    Future<String> _login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión no se genera nada', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/portraits/generate'),
          body: jsonEncode({'providerId': 'pollinations', 'prompt': 'x'}),
        ),
      );

      expect(response.statusCode, 401);
    });

    test('un proveedor desconocido responde 400', () async {
      final token = await _login('subject-gen-1');

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/portraits/generate'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'providerId': 'no-existe', 'prompt': 'x'}),
        ),
      );

      expect(response.statusCode, 400);
    });

    test('genera y devuelve las imágenes en base64, nunca una key', () async {
      final token = await _login('subject-gen-2');

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/portraits/generate'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'providerId': 'pollinations',
            'prompt': 'un caballero',
          }),
        ),
      );

      expect(response.statusCode, 200);
      final body = await response.readAsString();
      expect(body, isNot(contains('apiKey')));
      final decoded = jsonDecode(body);
      expect(decoded['images'], hasLength(1));
    });

    test(
      'un fallo del proveedor responde 502 con un mensaje, no un 500',
      () async {
        generation = PortraitGenerationService([
          FakePortraitProvider(
            id: 'pollinations',
            onGenerate: ({required prompt, reference, count}) async =>
                throw ProviderException('el proveedor rechazó el pedido'),
          ),
        ]);
        handler = buildHandler(
          auth: fakeAuth.dependencies,
          portraits: portraits,
          generation: generation,
          importBackup: importBackup,
          importHomebrew: importHomebrew,
          characters: characters,
          campaigns: campaigns,
          chapters: chapters,
          notes: notes,
          encounters: encounters,
          events: events,
          npcs: npcs,
          transactions: transactions,
          homebrew: homebrewRepo,
          levelUps: levelUps,
          itemGrants: itemGrants,
          settings: settingsRepo,
        );
        final token = await _login('subject-gen-3');

        final response = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/portraits/generate'),
            headers: {'cookie': 'dnd_session=$token'},
            body: jsonEncode({'providerId': 'pollinations', 'prompt': 'x'}),
          ),
        );

        expect(response.statusCode, 502);
        final body = jsonDecode(await response.readAsString());
        expect(body['error'], 'el proveedor rechazó el pedido');
        expect(body['code'], 'portrait_failed');
      },
    );

    // Cada candidato es una llamada al proveedor y la cantidad la pide el
    // cliente: sin techo, un solo pedido podía gastar el crédito entero.
    test(
      'una cantidad fuera de rango se rechaza sin llamar al proveedor',
      () async {
        var calls = 0;
        generation = PortraitGenerationService([
          FakePortraitProvider(
            id: 'pollinations',
            onGenerate: ({required prompt, reference, count}) async {
              calls++;
              return [
                Uint8List.fromList(const [1, 2, 3]),
              ];
            },
          ),
        ]);
        handler = buildHandler(
          auth: fakeAuth.dependencies,
          portraits: portraits,
          generation: generation,
          importBackup: importBackup,
          importHomebrew: importHomebrew,
          characters: characters,
          campaigns: campaigns,
          chapters: chapters,
          notes: notes,
          encounters: encounters,
          events: events,
          npcs: npcs,
          transactions: transactions,
          homebrew: homebrewRepo,
          levelUps: levelUps,
          itemGrants: itemGrants,
          settings: settingsRepo,
        );
        final token = await _login('subject-gen-count');

        for (final count in [0, PortraitGenerationService.maxCount + 1]) {
          final response = await handler(
            Request(
              'POST',
              Uri.parse('http://localhost/api/portraits/generate'),
              headers: {'cookie': 'dnd_session=$token'},
              body: jsonEncode({
                'providerId': 'pollinations',
                'prompt': 'x',
                'count': count,
              }),
            ),
          );
          expect(response.statusCode, 400, reason: 'count: $count');
        }
        expect(calls, 0);
      },
    );
  });

  group('POST /api/characters/<id>/portraits', () {
    test('sin sesión no se guarda nada', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters/sagan/portraits'),
          body: jsonEncode({'bytes': 'ab'}),
        ),
      );

      expect(response.statusCode, 401);
    });

    test('guarda los bytes elegidos y devuelve la clave', () async {
      fakeAuth.nextVerifiedSubject = 'subject-upload';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );
      const pngBase64 =
          'iVBORw0KGgo='; // cabecera PNG suficiente para sniffPortraitImageType

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters/sagan/portraits'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'bytes': pngBase64}),
        ),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['key'], startsWith('sagan/'));
    });

    test('la subida de un retrato propio funciona aunque no haya proveedores '
        'de IA configurados', () async {
      generation = PortraitGenerationService(const []);
      handler = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        importHomebrew: importHomebrew,
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
        npcs: npcs,
        transactions: transactions,
        homebrew: homebrewRepo,
        levelUps: levelUps,
        itemGrants: itemGrants,
        settings: settingsRepo,
      );
      fakeAuth.nextVerifiedSubject = 'subject-upload-no-providers';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters/sagan/portraits'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'bytes': 'iVBORw0KGgo='}),
        ),
      );

      expect(response.statusCode, 200);
    });
  });

  group('GET /api/export', () {
    test(
      'exporta solo datos de la cuenta y los ZIP pasan el lector de importación',
      () async {
        fakeAuth.sessionsByToken['export-token'] = 'export-owner';
        final image = img.encodePng(img.Image(width: 1, height: 1));
        final portraitKey = await portraits.save(
          userId: 'export-owner',
          characterId: 'sagan',
          bytes: image,
        );
        final diaryKey = await portraits.save(
          userId: 'export-owner',
          characterId: 'sagan',
          bytes: image,
        );
        await characters.create(
          'export-owner',
          Character.fromJson(
            demoSagan().toJson()..['raceId'] = 'hb-especie',
          ).copyWith(
            portraitPaths: [portraitKey],
            diary: [DiaryEntry(entryId: 'mapa', imageKey: diaryKey)],
          ),
        );
        await characters.create(
          'other-owner',
          Character.fromJson(demoSagan().toJson()..['id'] = 'ajeno'),
        );
        await characters.createNpcSheet(
          'export-owner',
          Character.fromJson(demoSagan().toJson()..['id'] = 'solo-pnj'),
        );
        await homebrewRepo.upsert('export-owner', 'races', 'hb-especie', {
          'id': 'hb-especie',
          'name': 'Especie propia',
          'source': 'homebrew',
        });
        await homebrewRepo.upsert(
          'export-owner',
          'weapons',
          'hb-espada',
          _homebrewWeapon('hb-espada'),
        );
        await settingsRepo.save('export-owner', {
          'themeMode': 'light',
          'azureApiKey': 'privada',
        });

        Future<Response> export([
          String query = '',
          bool authenticated = true,
        ]) async => handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/export$query'),
            headers: {if (authenticated) 'cookie': 'dnd_session=export-token'},
          ),
        );
        expect((await export('', false)).statusCode, 401);
        expect((await export('?characterId=ajeno')).statusCode, 404);
        expect((await export('?characterId=solo-pnj')).statusCode, 404);

        final single = await export('?characterId=sagan');
        expect(single.statusCode, 200);
        expect(single.headers['content-type'], 'application/zip');
        expect(single.headers['cache-control'], contains('no-store'));
        final bundle = BackupBundleCodec.decode(
          await single.read().expand((chunk) => chunk).toList(),
        );
        expect(bundle.scope, BackupScope.character);
        expect(bundle.preferences, isNull);
        expect(bundle.homebrew!['races']!.single['id'], 'hb-especie');
        expect(bundle.homebrew!['weapons'], isEmpty);
        final sheet = bundle.characters.single;
        expect(sheet.character.id, 'sagan');
        expect(sheet.portraits.single.bytes, image);
        expect(sheet.diaryImages.single.entryId, 'mapa');
        expect(sheet.diaryImages.single.bytes, image);

        final complete = await export();
        expect(complete.statusCode, 200);
        final backup = BackupBundleCodec.decode(
          await complete.read().expand((chunk) => chunk).toList(),
        );
        expect(backup.scope, BackupScope.full);
        expect(backup.characters.single.character.id, 'sagan');
        expect(backup.homebrew!['races']!.single['id'], 'hb-especie');
        expect(backup.homebrew!['weapons']!.single['id'], 'hb-espada');
        expect(backup.preferences, {'themeMode': 'light'});
      },
    );
  });

  group('POST /api/import', () {
    test('sin sesión no se importa nada', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/import'),
          body: jsonEncode({'bytes': 'ab'}),
        ),
      );

      expect(response.statusCode, 401);
    });

    test('un ZIP inválido responde 400 sin invocar la importación', () async {
      fakeAuth.nextVerifiedSubject = 'subject-import-1';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );
      var called = false;
      handler = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: ({required userId, required bundle}) async {
          called = true;
          return const ImportResult(
            charactersImported: 0,
            portraitsImported: 0,
          );
        },
        importHomebrew: importHomebrew,
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
        npcs: npcs,
        transactions: transactions,
        homebrew: homebrewRepo,
        levelUps: levelUps,
        itemGrants: itemGrants,
        settings: settingsRepo,
      );

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/import'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'bytes': base64Encode(utf8.encode('no es un zip')),
          }),
        ),
      );

      expect(response.statusCode, 400);
      expect(called, isFalse);
    });

    test('un cuerpo JSON que no es objeto responde 400', () async {
      fakeAuth.nextVerifiedSubject = 'subject-import-shape';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/import'),
          headers: {'cookie': 'dnd_session=$token'},
          body: '[]',
        ),
      );
      expect(response.statusCode, 400);
    });

    test('un respaldo válido se importa y devuelve el resumen', () async {
      fakeAuth.nextVerifiedSubject = 'subject-import-2';
      final token = _extractToken(
        (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/auth/callback?code=1&state=xyz'),
          ),
        )).headers['set-cookie']!,
      );
      handler = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: ({required userId, required bundle}) async {
          expect(bundle.characters.single.character.id, 'sagan');
          return const ImportResult(
            charactersImported: 1,
            portraitsImported: 0,
          );
        },
        importHomebrew: importHomebrew,
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
        npcs: npcs,
        transactions: transactions,
        homebrew: homebrewRepo,
        levelUps: levelUps,
        itemGrants: itemGrants,
        settings: settingsRepo,
      );

      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/import'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'bytes': base64Encode(_validZipBytes())}),
        ),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['charactersImported'], 1);
      expect(body['portraitsImported'], 0);
    });
  });

  group('/api/characters', () {
    Map<String, dynamic> characterJson(String id, {String name = 'Sagan'}) => {
      'id': id,
      'name': name,
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': <String, dynamic>{},
    };

    Future<String> login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/characters')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/characters/sagan'),
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
        Request('DELETE', Uri.parse('http://localhost/api/characters/sagan')),
      ]) {
        expect((await handler(request)).statusCode, 401);
      }
    });

    test('crea un personaje y lo devuelve en el listado', () async {
      final token = await login('subject-chars-1');

      final created = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
      );
      expect(created.statusCode, 200);
      final createdBody = jsonDecode(await created.readAsString());
      expect(createdBody['character']['id'], 'sagan');

      final listed = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );
      final listedBody = jsonDecode(await listed.readAsString());
      expect(listedBody['characters'], hasLength(1));
      expect(listedBody['characters'][0]['character']['id'], 'sagan');
    });

    // Borrar el personaje se lleva sus retratos: ninguna ficha los vuelve a
    // nombrar, así que quedarían ocupando el volumen para siempre.
    test('borrar un personaje borra sus retratos', () async {
      final token = await login('subject-chars-portraits');
      final me = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/me'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      final userId = me['userId'] as String;
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
      );
      final key = await portraits.save(
        userId: userId,
        characterId: 'sagan',
        bytes: Uint8List.fromList(const [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
          1, 2, 3,
        ]),
      );

      final deleted = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/characters/sagan'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      expect(deleted.statusCode, 200);
      expect(await portraits.read(userId: userId, portraitKey: key), isNull);
    });

    test('crear con un id ya usado en la cuenta asigna uno libre en vez de '
        'sobrescribir', () async {
      final token = await login('subject-chars-2');
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': characterJson('sagan', name: 'Original'),
          }),
        ),
      );

      final second = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': characterJson('sagan', name: 'Duplicado'),
          }),
        ),
      );
      final secondBody = jsonDecode(await second.readAsString());
      expect(secondBody['character']['id'], isNot('sagan'));

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['characters'], hasLength(2));
    });

    test('el listado de una cuenta no incluye personajes de otra', () async {
      final tokenA = await login('subject-chars-a');
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$tokenA'},
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
      );

      final tokenB = await login('subject-chars-b');
      final listedB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );
      expect(listedB['characters'], isEmpty);
    });

    test('actualiza un personaje existente sin reasignar id', () async {
      final token = await login('subject-chars-3');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/characters/sagan'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': characterJson('sagan', name: 'Actualizado'),
          }),
        ),
      );

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['characters'], hasLength(1));
      expect(listed['characters'][0]['character']['name'], 'Actualizado');
    });

    group('versión de la ficha', () {
      Future<Response> put(String token, String name, {int? expected}) async =>
          await handler(
            Request(
              'PUT',
              Uri.parse('http://localhost/api/characters/sagan'),
              headers: {'cookie': 'dnd_session=$token'},
              body: jsonEncode({
                'character': characterJson('sagan', name: name),
                'expectedVersion': ?expected,
              }),
            ),
          );

      Future<Map<String, dynamic>> firstListed(String token) async =>
          (jsonDecode(
                await (await handler(
                  Request(
                    'GET',
                    Uri.parse('http://localhost/api/characters'),
                    headers: {'cookie': 'dnd_session=$token'},
                  ),
                )).readAsString(),
              )['characters']
              as List)[0];

      test('una expectedVersion vieja responde 409 y no escribe', () async {
        final token = await login('subject-chars-v1');
        await put(token, 'Primera');
        final stale = (await firstListed(token))['version'] as int;
        await put(token, 'Segunda', expected: stale);

        final response = await put(token, 'Pisada', expected: stale);
        expect(response.statusCode, 409);
        expect(
          jsonDecode(await response.readAsString())['code'],
          'character_stale',
        );
        expect((await firstListed(token))['character']['name'], 'Segunda');
      });

      test('la version del listado guarda y devuelve otra', () async {
        final token = await login('subject-chars-v2');
        await put(token, 'Primera');
        final version = (await firstListed(token))['version'] as int;

        final response = await put(token, 'Segunda', expected: version);
        expect(response.statusCode, 200);
        final next = jsonDecode(await response.readAsString())['version'];
        expect(next, isA<int>());
        expect(next, isNot(version));
      });

      test(
        'sin expectedVersion guarda aunque la ficha haya cambiado',
        () async {
          final token = await login('subject-chars-v3');
          await put(token, 'Primera');
          await put(token, 'Segunda');

          final response = await put(token, 'Tercera');
          expect(response.statusCode, 200);
          expect((await firstListed(token))['character']['name'], 'Tercera');
        },
      );
    });

    test(
      'un id de ruta que no coincide con el del cuerpo responde 400',
      () async {
        final token = await login('subject-chars-4');
        final response = await handler(
          Request(
            'PUT',
            Uri.parse('http://localhost/api/characters/otro-id'),
            headers: {'cookie': 'dnd_session=$token'},
            body: jsonEncode({'character': characterJson('sagan')}),
          ),
        );
        expect(response.statusCode, 400);
      },
    );

    test('un documento sin los campos requeridos responde 400', () async {
      final token = await login('subject-chars-5');
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': {'id': 'sagan'},
          }),
        ),
      );
      expect(response.statusCode, 400);
    });

    test('una versión de esquema futura responde 400', () async {
      final token = await login('subject-chars-6');
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'character': {...characterJson('sagan'), 'schemaVersion': 999},
          }),
        ),
      );
      expect(response.statusCode, 400);
    });

    test('borra un personaje de la cuenta', () async {
      final token = await login('subject-chars-7');
      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/characters'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'character': characterJson('sagan')}),
        ),
      );

      final deleted = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/characters/sagan'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );
      expect(deleted.statusCode, 200);

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['characters'], isEmpty);
    });

    test(
      'borrar con el id de un personaje de otra cuenta no lo afecta',
      () async {
        final tokenB = await login('subject-chars-8b');
        await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$tokenB'},
            body: jsonEncode({
              'character': characterJson('sagan', name: 'De B'),
            }),
          ),
        );

        final tokenA = await login('subject-chars-8a');
        final deleted = await handler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/characters/sagan'),
            headers: {'cookie': 'dnd_session=$tokenA'},
          ),
        );
        // No hay "sagan" en la cuenta de quien pide el borrado: responde 200
        // igual (borrar algo que ya no está no es un error, ver
        // `_deleteCharacterHandler`), sin tocar el de la cuenta B.
        expect(deleted.statusCode, 200);

        final listedB = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/characters'),
              headers: {'cookie': 'dnd_session=$tokenB'},
            ),
          )).readAsString(),
        );
        expect(listedB['characters'], hasLength(1));
        expect(listedB['characters'][0]['character']['name'], 'De B');
      },
    );

    test(
      'actualizar con el id de un personaje de otra cuenta no lo sobrescribe: '
      'crea el propio',
      () async {
        final tokenB = await login('subject-chars-9b');
        await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/characters'),
            headers: {'cookie': 'dnd_session=$tokenB'},
            body: jsonEncode({
              'character': characterJson('sagan', name: 'De B'),
            }),
          ),
        );

        final tokenA = await login('subject-chars-9a');
        final updated = await handler(
          Request(
            'PUT',
            Uri.parse('http://localhost/api/characters/sagan'),
            headers: {'cookie': 'dnd_session=$tokenA'},
            body: jsonEncode({
              'character': characterJson('sagan', name: 'Intento de A'),
            }),
          ),
        );
        // La clave primaria es (userId, id): un PUT con el id de otra cuenta
        // no la alcanza, crea (o actualiza) el propio documento de A con ese
        // mismo id, sin escribir nunca la fila de B.
        expect(updated.statusCode, 200);

        final listedB = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/characters'),
              headers: {'cookie': 'dnd_session=$tokenB'},
            ),
          )).readAsString(),
        );
        expect(listedB['characters'], hasLength(1));
        expect(listedB['characters'][0]['character']['name'], 'De B');

        final listedA = jsonDecode(
          await (await handler(
            Request(
              'GET',
              Uri.parse('http://localhost/api/characters'),
              headers: {'cookie': 'dnd_session=$tokenA'},
            ),
          )).readAsString(),
        );
        expect(listedA['characters'], hasLength(1));
        expect(listedA['characters'][0]['character']['name'], 'Intento de A');
      },
    );
  });

  group('/api/homebrew', () {
    Future<String> login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/homebrew')),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          body: jsonEncode({'id': 'w1'}),
        ),
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
        ),
      ]) {
        expect((await handler(request)).statusCode, 401);
      }
    });

    test('guarda una entidad y aparece agrupada por categoría', () async {
      final token = await login('subject-hb-1');
      final saved = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode(_homebrewWeapon('w1')),
        ),
      );
      expect(saved.statusCode, 200);

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['content']['weapons'], [_homebrewWeapon('w1')]);
    });

    test('los objetos son una categoría válida y se pueden borrar', () async {
      final token = await login('subject-hb-items');
      final cookie = {'cookie': 'dnd_session=$token'};

      final saved = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/items/hb-capa'),
          headers: cookie,
          body: jsonEncode(_homebrewItem('hb-capa', 'Capa de protección')),
        ),
      );
      expect(saved.statusCode, 200);

      Future<dynamic> listItems() async => jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: cookie,
          ),
        )).readAsString(),
      )['content']['items'];

      expect(await listItems(), [
        _homebrewItem('hb-capa', 'Capa de protección'),
      ]);

      final deleted = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/homebrew/items/hb-capa'),
          headers: cookie,
        ),
      );
      expect(deleted.statusCode, 200);
      expect(await listItems(), isEmpty);
    });

    test('una categoría desconocida responde 400', () async {
      final token = await login('subject-hb-2');
      final response = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/no-existe/w1'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode(_homebrewWeapon('w1')),
        ),
      );
      expect(response.statusCode, 400);
    });

    test(
      'un id de ruta que no coincide con el del cuerpo responde 400',
      () async {
        final token = await login('subject-hb-3');
        final response = await handler(
          Request(
            'PUT',
            Uri.parse('http://localhost/api/homebrew/weapons/w1'),
            headers: {'cookie': 'dnd_session=$token'},
            body: jsonEncode({'id': 'otro'}),
          ),
        );
        expect(response.statusCode, 400);
      },
    );

    test('borra una entidad de la cuenta', () async {
      final token = await login('subject-hb-4');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode(_homebrewWeapon('w1')),
        ),
      );
      await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$token'},
        ),
      );

      final listed = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(listed['content']['weapons'], isEmpty);
    });

    test('el homebrew de una cuenta no aparece en el de otra', () async {
      final tokenA = await login('subject-hb-a');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$tokenA'},
          body: jsonEncode(_homebrewWeapon('w1')),
        ),
      );

      final tokenB = await login('subject-hb-b');
      final listedB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/homebrew'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );
      expect(listedB['content'], isEmpty);
    });

    test('importa un pack completo incluyendo criaturas', () async {
      final token = await login('subject-hb-batch');
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/homebrew/import'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'content': {
              'weapons': [_homebrewWeapon('batch-weapon')],
              'creatures': [_homebrewCreature('batch-creature')],
            },
          }),
        ),
      );

      expect(response.statusCode, 200);
      expect(jsonDecode(await response.readAsString())['importedCount'], 2);
      final stored = await homebrewRepo.listForUser(
        fakeAuth.accountsBySubject['subject-hb-batch']!,
      );
      expect(stored['creatures']?.single['id'], 'batch-creature');
    });

    test('rechaza todo el pack si una entrada es inválida', () async {
      final token = await login('subject-hb-invalid');
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/homebrew/import'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({
            'content': {
              'weapons': [
                _homebrewWeapon('valid-before-error'),
                {'id': 'broken', 'source': 'homebrew'},
              ],
            },
          }),
        ),
      );

      expect(response.statusCode, 400);
      expect(
        await homebrewRepo.listForUser(
          fakeAuth.accountsBySubject['subject-hb-invalid']!,
        ),
        isEmpty,
      );
    });

    test('rechaza un origen que no sea homebrew', () async {
      final token = await login('subject-hb-source');
      final response = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/homebrew/weapons/w1'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode(_homebrewWeapon('w1')..['source'] = 'srd_2024'),
        ),
      );
      expect(response.statusCode, 400);
    });
  });

  group('/api/settings', () {
    Future<String> login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/settings')),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/settings'),
          body: jsonEncode({'imageProvider': 'pollinations'}),
        ),
      ]) {
        expect((await handler(request)).statusCode, 401);
      }
    });

    test('sin ajustes guardados devuelve null', () async {
      final token = await login('subject-settings-1');
      final response = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(response['settings'], isNull);
    });

    test('rechaza un cuerpo ordinario mayor a 1 MiB', () async {
      final token = await login('subject-settings-large');
      final response = await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/settings'),
          headers: {'cookie': 'dnd_session=$token'},
          body: ''.padRight(1024 * 1024 + 1, 'x'),
        ),
      );
      expect(response.statusCode, 413);
    });

    test('guarda y relee los ajustes de la cuenta', () async {
      final token = await login('subject-settings-2');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/settings'),
          headers: {'cookie': 'dnd_session=$token'},
          body: jsonEncode({'imageProvider': 'azure'}),
        ),
      );

      final response = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(response['settings'], {'imageProvider': 'azure'});
    });

    test('un PUT sin sheetLayout conserva el que ya estaba guardado', () async {
      final token = await login('subject-settings-merge');
      Future<void> put(Map<String, dynamic> body) async {
        await handler(
          Request(
            'PUT',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$token'},
            body: jsonEncode(body),
          ),
        );
      }

      final layout = {
        'combate': [
          ['hit-points'],
          ['attacks'],
          ['saves'],
        ],
        'personaje': null,
      };
      await put({'sheetLayout': layout});
      // Lo que manda Flutter: su lista cerrada de campos, sin `sheetLayout`.
      await put({'sortMode': 'manual'});

      final response = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$token'},
          ),
        )).readAsString(),
      );
      expect(response['settings'], {
        'sheetLayout': layout,
        'sortMode': 'manual',
      });
    });

    test('los ajustes de dos cuentas no se mezclan', () async {
      final tokenA = await login('subject-settings-a');
      await handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/settings'),
          headers: {'cookie': 'dnd_session=$tokenA'},
          body: jsonEncode({'imageProvider': 'azure'}),
        ),
      );

      final tokenB = await login('subject-settings-b');
      final responseB = jsonDecode(
        await (await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/settings'),
            headers: {'cookie': 'dnd_session=$tokenB'},
          ),
        )).readAsString(),
      );
      expect(responseB['settings'], isNull);
    });
  });

  group('webStaticHandler', () {
    test('una ruta que el enrutado no reconoce cae al build web', () async {
      final withStatic = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        importHomebrew: importHomebrew,
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
        npcs: npcs,
        transactions: transactions,
        homebrew: homebrewRepo,
        levelUps: levelUps,
        itemGrants: itemGrants,
        settings: settingsRepo,
        webStaticHandler: (request) =>
            Response.ok('build web', headers: {'x-fuente': 'estatico'}),
      );

      final response = await withStatic(
        Request('GET', Uri.parse('http://localhost/')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['x-fuente'], 'estatico');
    });

    test('una ruta de la API nunca cae al build web', () async {
      final withStatic = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        importHomebrew: importHomebrew,
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
        npcs: npcs,
        transactions: transactions,
        homebrew: homebrewRepo,
        levelUps: levelUps,
        itemGrants: itemGrants,
        settings: settingsRepo,
        webStaticHandler: (request) =>
            Response.ok('build web', headers: {'x-fuente': 'estatico'}),
      );

      final response = await withStatic(
        Request('GET', Uri.parse('http://localhost/api/characters')),
      );

      expect(response.headers['x-fuente'], isNull);
    });

    // La Cascade pasa al siguiente handler ante cualquier 404, también los de
    // la API a propósito («Código inválido o vencido.»): el build web
    // contestaba «Not Found» en texto plano y el mensaje se perdía.
    test('un 404 de la API no cae al build web', () async {
      final withStatic = buildHandler(
        auth: fakeAuth.dependencies,
        portraits: portraits,
        generation: generation,
        importBackup: importBackup,
        importHomebrew: importHomebrew,
        characters: characters,
        campaigns: campaigns,
        chapters: chapters,
        notes: notes,
        encounters: encounters,
        events: events,
        npcs: npcs,
        transactions: transactions,
        homebrew: homebrewRepo,
        levelUps: levelUps,
        itemGrants: itemGrants,
        settings: settingsRepo,
        webStaticHandler: (request) =>
            Response.ok('build web', headers: {'x-fuente': 'estatico'}),
      );

      for (final path in ['/api/no-existe', '/auth/no-existe']) {
        final response = await withStatic(
          Request('GET', Uri.parse('http://localhost$path')),
        );
        expect(response.statusCode, 404, reason: path);
        expect(response.headers['x-fuente'], isNull, reason: path);
      }
    });
  });

  group('/v2 (cliente React)', () {
    late Directory dist;

    setUp(() {
      dist = Directory.systemTemp.createTempSync('dnd_web_v2_');
      File('${dist.path}/index.html').writeAsStringSync('<html>spa</html>');
      Directory('${dist.path}/assets').createSync();
      File('${dist.path}/assets/index-abc123.js').writeAsStringSync('js');
    });

    tearDown(() => dist.deleteSync(recursive: true));

    Handler build({Handler? v2, Handler? flutter}) => buildHandler(
      auth: fakeAuth.dependencies,
      portraits: portraits,
      generation: generation,
      importBackup: importBackup,
      importHomebrew: importHomebrew,
      characters: characters,
      campaigns: campaigns,
      chapters: chapters,
      notes: notes,
      encounters: encounters,
      events: events,
      npcs: npcs,
      transactions: transactions,
      homebrew: homebrewRepo,
      levelUps: levelUps,
      itemGrants: itemGrants,
      settings: settingsRepo,
      webStaticHandler: flutter,
      webV2Handler: v2,
    );

    Future<Response> get(Handler h, String path) =>
        Future.value(h(Request('GET', Uri.parse('http://localhost$path'))));

    test(
      'sin DND_WEB_V2_ROOT responde 404, haya o no build de Flutter',
      () async {
        final flutter = (Request r) => Response.ok('flutter');
        for (final h in [build(), build(flutter: flutter)]) {
          expect((await get(h, '/v2/')).statusCode, 404);
          expect((await get(h, '/v2')).statusCode, 404);
          expect((await get(h, '/v2/personajes')).statusCode, 404);
        }
        // Lo que no empieza con el segmento `v2` sigue siendo de Flutter.
        expect(
          await (await get(build(flutter: flutter), '/v22')).readAsString(),
          'flutter',
        );
      },
    );

    test('una ruta de cliente cae a index.html y no se cachea', () async {
      final h = build(v2: buildWebV2Handler(dist.path));
      for (final path in ['/v2/', '/v2/index.html', '/v2/personajes/3']) {
        final response = await get(h, path);
        expect(response.statusCode, 200, reason: path);
        expect(await response.readAsString(), '<html>spa</html>', reason: path);
        expect(response.headers['cache-control'], 'private, no-cache');
      }
    });

    test(
      'los archivos con hash de assets/ son immutable; uno que falta es 404',
      () async {
        final h = build(v2: buildWebV2Handler(dist.path));
        final hit = await get(h, '/v2/assets/index-abc123.js');
        expect(hit.statusCode, 200);
        expect(
          hit.headers['cache-control'],
          'public, max-age=31536000, immutable',
        );
        final miss = await get(h, '/v2/assets/viejo-zzz.js');
        expect(miss.statusCode, 404);
        expect(miss.headers['cache-control'], isNot(contains('immutable')));
      },
    );

    test('/api no se toca aunque /v2 esté montado', () async {
      final h = build(v2: buildWebV2Handler(dist.path));
      final response = await get(h, '/api/me');
      expect(response.headers['cache-control'], isNull);
      expect(await response.readAsString(), isNot(contains('spa')));
    });
  });

  // Es la única parte del servidor donde una cuenta alcanza datos de otra, así
  // que lo que más importa acá es lo que NO se puede hacer.
  group('/api/campaigns y compartir personajes', () {
    Map<String, dynamic> characterJson(String id, {String name = 'Sagan'}) => {
      'id': id,
      'name': name,
      'raceId': 'human',
      'classId': 'fighter',
      'backgroundId': 'soldier',
      'assignedScores': <String, dynamic>{},
    };

    Map<String, dynamic> campaignJson(String id, {String name = 'La Tumba'}) =>
        {'id': id, 'name': name};

    Future<String> login(String subject) async {
      fakeAuth.nextVerifiedSubject = subject;
      final callback = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/auth/callback?code=c&state=xyz'),
        ),
      );
      return _extractToken(callback.headers['set-cookie']!);
    }

    Future<Map<String, dynamic>> send(
      String method,
      String path, {
      String? token,
      Object? body,
    }) async {
      final response = await handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {if (token != null) 'cookie': 'dnd_session=$token'},
          body: body == null ? null : jsonEncode(body),
        ),
      );
      final text = await response.readAsString();
      return {
        'status': response.statusCode,
        'body': text.isEmpty ? null : jsonDecode(text),
      };
    }

    /// Deja un personaje creado y devuelve un código para compartirlo.
    Future<String> shareCharacter(
      String token,
      String characterId, {
      String name = 'Sagan',
    }) async {
      await send(
        'POST',
        '/api/characters',
        token: token,
        body: {'character': characterJson(characterId, name: name)},
      );
      final shared = await send(
        'POST',
        '/api/characters/$characterId/share',
        token: token,
      );
      return shared['body']['code'] as String;
    }

    Future<void> createCampaign(
      String token,
      String id, {
      String name = 'La Tumba',
    }) => send(
      'POST',
      '/api/campaigns',
      token: token,
      body: {'campaign': campaignJson(id, name: name)},
    );

    Future<({String owner, String dm, String memberId})> linkCharacter(
      String suffix,
    ) async {
      final owner = await login('transaction-owner-$suffix');
      final code = await shareCharacter(owner, 'sagan');
      final dm = await login('transaction-dm-$suffix');
      await createCampaign(dm, 'tumba');
      final redeemed = await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: dm,
        body: {'code': code},
      );
      return (
        owner: owner,
        dm: dm,
        memberId: redeemed['body']['member']['memberId'] as String,
      );
    }

    test(
      'revertir evento conserva el código para reintentar el canje',
      () async {
        final owner = await login('transaction-owner-redeem');
        final code = await shareCharacter(owner, 'sagan');
        final dm = await login('transaction-dm-redeem');
        await createCampaign(dm, 'tumba');
        final before = transactions.runCount;
        events.failAppendWith = StateError('events unavailable');

        final failed = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: dm,
          body: {'code': code},
        );
        expect(failed['status'], 500);
        expect(transactions.runCount, before + 1);

        events.failAppendWith = null;
        final retried = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: dm,
          body: {'code': code},
        );
        expect(retried['status'], 200);
      },
    );

    test('revertir evento conserva el personaje al borrarlo', () async {
      final linked = await linkCharacter('delete-character');
      final before = transactions.runCount;
      events.failAppendWith = StateError('events unavailable');

      final failed = await send(
        'DELETE',
        '/api/characters/sagan',
        token: linked.owner,
      );
      expect(failed['status'], 500);
      expect(transactions.runCount, before + 1);

      final listed = await send('GET', '/api/characters', token: linked.owner);
      expect(listed['body']['characters'], hasLength(1));
    });

    test('revertir evento conserva el vínculo al borrarlo', () async {
      final linked = await linkCharacter('delete-link');
      final before = transactions.runCount;
      events.failAppendWith = StateError('events unavailable');

      final failed = await send(
        'DELETE',
        '/api/campaign-links/${linked.memberId}',
        token: linked.dm,
      );
      expect(failed['status'], 500);
      expect(transactions.runCount, before + 1);

      events.failAppendWith = null;
      final retried = await send(
        'DELETE',
        '/api/campaign-links/${linked.memberId}',
        token: linked.dm,
      );
      expect(retried['status'], 200);
    });

    test('revertir evento deja el capítulo abierto para reintentar', () async {
      final linked = await linkCharacter('close-chapter');
      await send(
        'POST',
        '/api/campaigns/tumba/chapters',
        token: linked.dm,
        body: {
          'chapter': {
            'schemaVersion': 1,
            'id': 'cripta',
            'name': 'La Cripta',
            'summary': '',
            'state': 'planned',
            'grantsLevel': false,
          },
        },
      );
      final before = transactions.runCount;
      events.failAppendWith = StateError('events unavailable');

      final failed = await send(
        'POST',
        '/api/campaigns/tumba/chapters/cripta/close',
        token: linked.dm,
      );
      expect(failed['status'], 500);
      expect(transactions.runCount, before + 1);

      events.failAppendWith = null;
      final retried = await send(
        'POST',
        '/api/campaigns/tumba/chapters/cripta/close',
        token: linked.dm,
      );
      expect(retried['status'], 200);
    });

    test('sin sesión ninguna operación responde', () async {
      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/campaigns')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/campaigns'),
          body: jsonEncode({'campaign': campaignJson('c1')}),
        ),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/campaigns/c1'),
          body: jsonEncode({'campaign': campaignJson('c1')}),
        ),
        Request('DELETE', Uri.parse('http://localhost/api/campaigns/c1')),
        Request('GET', Uri.parse('http://localhost/api/campaigns/c1/members')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/campaigns/c1/members'),
          body: jsonEncode({'code': 'ABCD-EFGH'}),
        ),
        Request('POST', Uri.parse('http://localhost/api/characters/x/share')),
        Request('GET', Uri.parse('http://localhost/api/characters/x/shares')),
        Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/campaign-links/'
            '00000000-0000-4000-8000-000000000000',
          ),
        ),
        Request('GET', Uri.parse('http://localhost/api/events')),
        Request(
          'POST',
          Uri.parse('http://localhost/api/events/seen'),
          body: jsonEncode({'ids': <String>[]}),
        ),
      ]) {
        expect(
          (await handler(request)).statusCode,
          401,
          reason: '${request.url}',
        );
      }
    });

    test(
      'el listado de campañas de una cuenta no incluye las de otra',
      () async {
        final tokenA = await login('camp-a');
        await createCampaign(tokenA, 'tumba');

        final tokenB = await login('camp-b');
        final listed = await send('GET', '/api/campaigns', token: tokenB);

        expect(listed['body']['campaigns'], isEmpty);
      },
    );

    test('no se puede editar ni borrar la campaña de otra cuenta', () async {
      final tokenA = await login('camp-edit-a');
      await createCampaign(tokenA, 'tumba');

      final tokenB = await login('camp-edit-b');
      final edited = await send(
        'PUT',
        '/api/campaigns/tumba',
        token: tokenB,
        body: {'campaign': campaignJson('tumba', name: 'Secuestrada')},
      );
      expect(edited['status'], 404);

      await send('DELETE', '/api/campaigns/tumba', token: tokenB);

      final stillThere = await send('GET', '/api/campaigns', token: tokenA);
      expect(stillThere['body']['campaigns'], hasLength(1));
      expect(stillThere['body']['campaigns'][0]['name'], 'La Tumba');
    });

    test(
      'el DM ve la ficha después de canjear el código del jugador',
      () async {
        final tokenA = await login('link-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('link-b');
        await createCampaign(tokenB, 'tumba');
        final redeemed = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        expect(redeemed['status'], 200);

        final members = await send(
          'GET',
          '/api/campaigns/tumba/members',
          token: tokenB,
        );
        expect(members['body']['members'], hasLength(1));
        expect(members['body']['members'][0]['character']['id'], 'sagan');
      },
    );

    // El vínculo es una referencia, no una copia: el DM tiene que ver lo que
    // el jugador tiene ahora, no lo que tenía al compartir.
    test(
      'el DM ve los cambios que el jugador hace después de vincular',
      () async {
        final tokenA = await login('live-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('live-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        await send(
          'PUT',
          '/api/characters/sagan',
          token: tokenA,
          body: {'character': characterJson('sagan', name: 'Sagan el Rojo')},
        );

        final members = await send(
          'GET',
          '/api/campaigns/tumba/members',
          token: tokenB,
        );
        expect(
          members['body']['members'][0]['character']['name'],
          'Sagan el Rojo',
        );
      },
    );

    test('un código no se puede canjear dos veces', () async {
      final tokenA = await login('once-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('once-b');
      await createCampaign(tokenB, 'tumba');
      await createCampaign(tokenB, 'otra');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      final second = await send(
        'POST',
        '/api/campaigns/otra/members',
        token: tokenB,
        body: {'code': code},
      );
      expect(second['status'], 404);
    });

    test('un código inventado no sirve y no dice por qué', () async {
      final tokenB = await login('fake-code-b');
      await createCampaign(tokenB, 'tumba');

      final response = await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': 'ZZZZ-ZZZZ'},
      );

      expect(response['status'], 404);
      expect(response['body']['error'], 'Código inválido o vencido.');
    });

    // Intentar contra una campaña ajena no puede costarle el código al jugador:
    // la sentencia se revierte entera y el código sigue sirviendo.
    test(
      'canjear contra una campaña ajena falla y no quema el código',
      () async {
        final tokenA = await login('steal-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenC = await login('steal-c');
        await createCampaign(tokenC, 'ajena');

        final tokenB = await login('steal-b');
        final stolen = await send(
          'POST',
          '/api/campaigns/ajena/members',
          token: tokenB,
          body: {'code': code},
        );
        expect(stolen['status'], 404);

        await createCampaign(tokenB, 'propia');
        final legit = await send(
          'POST',
          '/api/campaigns/propia/members',
          token: tokenB,
          body: {'code': code},
        );
        expect(legit['status'], 200);
      },
    );

    test('sin vínculo, la campaña no muestra ninguna ficha', () async {
      final tokenA = await login('nolink-a');
      await send(
        'POST',
        '/api/characters',
        token: tokenA,
        body: {'character': characterJson('sagan')},
      );

      final tokenB = await login('nolink-b');
      await createCampaign(tokenB, 'tumba');
      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );

      expect(members['body']['members'], isEmpty);
    });

    test(
      'compartir un personaje ajeno responde como si no existiera',
      () async {
        final tokenA = await login('share-a');
        await send(
          'POST',
          '/api/characters',
          token: tokenA,
          body: {'character': characterJson('sagan')},
        );

        final tokenB = await login('share-b');
        final response = await send(
          'POST',
          '/api/characters/sagan/share',
          token: tokenB,
        );

        expect(response['status'], 404);
      },
    );

    test('el jugador ve en qué campañas está su personaje', () async {
      final tokenA = await login('shares-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('shares-b');
      await createCampaign(tokenB, 'tumba');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      final shares = await send(
        'GET',
        '/api/characters/sagan/shares',
        token: tokenA,
      );
      expect(shares['body']['shares'], hasLength(1));
      expect(shares['body']['shares'][0]['campaignName'], 'La Tumba');
      // El id del DM es de uso interno: sirve para avisarle, no para mostrarlo.
      expect(shares['body']['shares'][0].containsKey('dmUserId'), isFalse);
    });

    test('el jugador corta el vínculo y el DM deja de ver la ficha', () async {
      final tokenA = await login('unlink-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('unlink-b');
      await createCampaign(tokenB, 'tumba');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      final shares = await send(
        'GET',
        '/api/characters/sagan/shares',
        token: tokenA,
      );
      final memberId = shares['body']['shares'][0]['memberId'];
      final cut = await send(
        'DELETE',
        '/api/campaign-links/$memberId',
        token: tokenA,
      );
      expect(cut['status'], 200);

      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );
      expect(members['body']['members'], isEmpty);
    });

    test('un tercero no puede cortar un vínculo del que no es parte', () async {
      final tokenA = await login('third-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('third-b');
      await createCampaign(tokenB, 'tumba');
      final redeemed = await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );
      final memberId = redeemed['body']['member']['memberId'];

      final tokenC = await login('third-c');
      final attempt = await send(
        'DELETE',
        '/api/campaign-links/$memberId',
        token: tokenC,
      );
      expect(attempt['status'], 404);

      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );
      expect(members['body']['members'], hasLength(1));
    });

    test('borrar el personaje se lleva el vínculo', () async {
      final tokenA = await login('cascade-a');
      final code = await shareCharacter(tokenA, 'sagan');

      final tokenB = await login('cascade-b');
      await createCampaign(tokenB, 'tumba');
      await send(
        'POST',
        '/api/campaigns/tumba/members',
        token: tokenB,
        body: {'code': code},
      );

      await send('DELETE', '/api/characters/sagan', token: tokenA);

      final members = await send(
        'GET',
        '/api/campaigns/tumba/members',
        token: tokenB,
      );
      expect(members['body']['members'], isEmpty);
    });

    group('avisos', () {
      Future<List<dynamic>> pending(String token) async {
        final response = await send('GET', '/api/events', token: token);
        return response['body']['events'] as List<dynamic>;
      }

      test('vincular avisa al jugador y no al DM que lo hizo', () async {
        final tokenA = await login('ev-link-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-link-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        final forPlayer = await pending(tokenA);
        expect(forPlayer, hasLength(1));
        expect(forPlayer[0]['kind'], 'character_linked');
        expect(forPlayer[0]['payload']['characterName'], 'Sagan');
        expect(forPlayer[0]['payload']['campaignName'], 'La Tumba');

        expect(await pending(tokenB), isEmpty);
      });

      test('echar avisa al jugador; irse avisa al DM', () async {
        final tokenA = await login('ev-kick-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-kick-b');
        await createCampaign(tokenB, 'tumba');
        final redeemed = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await send(
          'POST',
          '/api/events/seen',
          token: tokenA,
          body: {
            'ids': [for (final e in await pending(tokenA)) e['id']],
          },
        );

        // El DM echa al personaje: se entera el jugador.
        await send(
          'DELETE',
          '/api/campaign-links/${redeemed['body']['member']['memberId']}',
          token: tokenB,
        );
        final afterKick = await pending(tokenA);
        expect(afterKick, hasLength(1));
        expect(afterKick[0]['kind'], 'character_unlinked_by_dm');
        expect(await pending(tokenB), isEmpty);

        // El jugador se va por su cuenta: se entera el DM.
        final code2 = await send(
          'POST',
          '/api/characters/sagan/share',
          token: tokenA,
        );
        final again = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code2['body']['code']},
        );
        await send(
          'DELETE',
          '/api/campaign-links/${again['body']['member']['memberId']}',
          token: tokenA,
        );
        final forDm = await pending(tokenB);
        expect(forDm.last['kind'], 'character_unlinked_by_owner');
      });

      // Sin esto el personaje desaparece del panel del DM sin explicación.
      test('borrar el personaje avisa al DM que lo tenía', () async {
        final tokenA = await login('ev-del-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-del-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        await send('DELETE', '/api/characters/sagan', token: tokenA);

        final forDm = await pending(tokenB);
        expect(forDm, hasLength(1));
        expect(forDm[0]['kind'], 'character_deleted_by_owner');
        expect(forDm[0]['payload']['characterName'], 'Sagan');
      });

      // Sigue en la mesa pero con otra ficha: el DM tiene que enterarse antes
      // de la próxima sesión. Un guardado cualquiera, en cambio, no avisa.
      test('rehacer el personaje avisa al DM que lo tenía', () async {
        final tokenA = await login('ev-rebuild-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-rebuild-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        await send(
          'PUT',
          '/api/characters/sagan',
          token: tokenA,
          body: {'character': characterJson('sagan', name: 'Sagan')},
        );
        expect(await pending(tokenB), isEmpty);

        await send(
          'PUT',
          '/api/characters/sagan',
          token: tokenA,
          body: {
            'character': characterJson('sagan', name: 'Sagan'),
            'rebuilt': true,
          },
        );

        final forDm = await pending(tokenB);
        expect(forDm, hasLength(1));
        expect(forDm[0]['kind'], 'character_rebuilt');
        expect(forDm[0]['payload']['characterName'], 'Sagan');
        expect(forDm[0]['payload']['campaignName'], 'La Tumba');
      });

      test('un aviso se entrega una sola vez', () async {
        final tokenA = await login('ev-once-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-once-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        final first = await pending(tokenA);
        expect(first, hasLength(1));

        await send(
          'POST',
          '/api/events/seen',
          token: tokenA,
          body: {
            'ids': [first[0]['id']],
          },
        );

        expect(await pending(tokenA), isEmpty);
      });

      test('una cuenta no puede marcar vistos los avisos de otra', () async {
        final tokenA = await login('ev-steal-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ev-steal-b');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );

        final forPlayer = await pending(tokenA);
        final response = await send(
          'POST',
          '/api/events/seen',
          token: tokenB,
          body: {
            'ids': [forPlayer[0]['id']],
          },
        );

        // No falla, pero tampoco hace nada: quien manda un id ajeno no debe
        // poder distinguirlo de uno que no existe.
        expect(response['status'], 200);
        expect(await pending(tokenA), hasLength(1));
      });

      test('un id de aviso mal formado no rompe nada', () async {
        final token = await login('ev-junk');

        final response = await send(
          'POST',
          '/api/events/seen',
          token: token,
          body: {
            'ids': ['no-soy-un-uuid'],
          },
        );

        expect(response['status'], 200);
      });
    });

    group('capítulos', () {
      Map<String, dynamic> chapterJson(
        String id, {
        String name = 'La Cripta',
        String state = 'planned',
        bool grantsLevel = false,
        Object? grantsGold,
        Object? grantsItems,
      }) => {
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'summary': '',
        'state': state,
        'grantsLevel': grantsLevel,
        // Se mandan tal cual llegan, sin tipar: varios casos de acá prueban
        // justamente qué hace el servidor con un botín escrito mal.
        if (grantsGold != null) 'grantsGold': grantsGold,
        if (grantsItems != null) 'grantsItems': grantsItems,
      };

      Future<Map<String, dynamic>> createChapter(
        String token,
        String campaignId,
        String id, {
        String name = 'La Cripta',
        bool grantsLevel = false,
        Object? grantsGold,
        Object? grantsItems,
      }) => send(
        'POST',
        '/api/campaigns/$campaignId/chapters',
        token: token,
        body: {
          'chapter': chapterJson(
            id,
            name: name,
            grantsLevel: grantsLevel,
            grantsGold: grantsGold,
            grantsItems: grantsItems,
          ),
        },
      );

      Future<List<dynamic>> listChapters(
        String token,
        String campaignId,
      ) async {
        final response = await send(
          'GET',
          '/api/campaigns/$campaignId/chapters',
          token: token,
        );
        return response['body']['chapters'] as List<dynamic>;
      }

      test('sin sesión ninguna operación responde 401', () async {
        for (final request in [
          Request(
            'GET',
            Uri.parse('http://localhost/api/campaigns/c1/chapters'),
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/api/campaigns/c1/chapters'),
            body: jsonEncode({'chapter': chapterJson('ch1')}),
          ),
          Request(
            'PUT',
            Uri.parse('http://localhost/api/campaigns/c1/chapters/ch1'),
            body: jsonEncode({'chapter': chapterJson('ch1')}),
          ),
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/campaigns/c1/chapters/ch1'),
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/api/campaigns/c1/chapters/ch1/close'),
          ),
        ]) {
          expect(
            (await handler(request)).statusCode,
            401,
            reason: '${request.url}',
          );
        }
      });

      test('crear, listar y editar un capítulo', () async {
        final token = await login('ch-crud');
        await createCampaign(token, 'tumba');

        final created = await createChapter(token, 'tumba', 'cripta');
        expect(created['status'], 200);
        expect(created['body']['chapter']['name'], 'La Cripta');

        expect(await listChapters(token, 'tumba'), hasLength(1));

        final edited = await send(
          'PUT',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
          body: {'chapter': chapterJson('cripta', name: 'La Cripta Profunda')},
        );
        expect(edited['status'], 200);
        expect(
          (await listChapters(token, 'tumba'))[0]['name'],
          'La Cripta Profunda',
        );
      });

      test('borrar un capítulo lo saca de la lista', () async {
        final token = await login('ch-delete');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');

        await send(
          'DELETE',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
        );

        expect(await listChapters(token, 'tumba'), isEmpty);
      });

      test(
        'los capítulos de una campaña ajena no se ven ni se tocan',
        () async {
          final tokenA = await login('ch-owner');
          await createCampaign(tokenA, 'tumba');
          await createChapter(tokenA, 'tumba', 'cripta');

          final tokenB = await login('ch-intruder');
          expect(
            (await send(
              'GET',
              '/api/campaigns/tumba/chapters',
              token: tokenB,
            ))['status'],
            404,
          );
          expect(
            (await send(
              'POST',
              '/api/campaigns/tumba/chapters',
              token: tokenB,
              body: {'chapter': chapterJson('robado')},
            ))['status'],
            404,
          );
          expect(
            (await send(
              'PUT',
              '/api/campaigns/tumba/chapters/cripta',
              token: tokenB,
              body: {'chapter': chapterJson('cripta', name: 'Secuestrado')},
            ))['status'],
            404,
          );
          expect(
            (await send(
              'DELETE',
              '/api/campaigns/tumba/chapters/cripta',
              token: tokenB,
            ))['status'],
            404,
          );
          expect(
            (await send(
              'POST',
              '/api/campaigns/tumba/chapters/cripta/close',
              token: tokenB,
            ))['status'],
            404,
          );

          // Y lo del dueño quedó intacto.
          expect((await listChapters(tokenA, 'tumba'))[0]['name'], 'La Cripta');
        },
      );

      // Cerrar avisa a otras cuentas: si viajara por el PUT, un reguardado
      // idempotente repetiría los avisos.
      test('un PUT no puede cerrar un capítulo', () async {
        final token = await login('ch-put-close');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');

        final response = await send(
          'PUT',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
          body: {'chapter': chapterJson('cripta', state: 'completed')},
        );

        expect(response['status'], 400);
        expect(response['body']['error'], contains('su propia acción'));
        expect((await listChapters(token, 'tumba'))[0]['state'], 'planned');
      });

      test('no se pueden poner dos capítulos en marcha', () async {
        final token = await login('ch-two-active');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');
        await createChapter(token, 'tumba', 'regreso', name: 'El Regreso');

        await send(
          'PUT',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
          body: {'chapter': chapterJson('cripta', state: 'active')},
        );

        final second = await send(
          'PUT',
          '/api/campaigns/tumba/chapters/regreso',
          token: token,
          body: {
            'chapter': chapterJson(
              'regreso',
              name: 'El Regreso',
              state: 'active',
            ),
          },
        );

        expect(second['status'], 400);
        expect(second['body']['error'], contains('La Cripta'));
      });

      // Reguardar el que ya está en marcha (para corregirle el nombre) no
      // puede chocar contra sí mismo.
      test(
        'editar el capítulo en marcha sin sacarlo de marcha funciona',
        () async {
          final token = await login('ch-edit-active');
          await createCampaign(token, 'tumba');
          await createChapter(token, 'tumba', 'cripta');
          await send(
            'PUT',
            '/api/campaigns/tumba/chapters/cripta',
            token: token,
            body: {'chapter': chapterJson('cripta', state: 'active')},
          );

          final again = await send(
            'PUT',
            '/api/campaigns/tumba/chapters/cripta',
            token: token,
            body: {
              'chapter': chapterJson(
                'cripta',
                name: 'La Cripta Profunda',
                state: 'active',
              ),
            },
          );

          expect(again['status'], 200);
        },
      );

      test('cerrar un capítulo lo completa y avisa a cada jugador', () async {
        final tokenA = await login('ch-close-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(tokenB, 'tumba', 'cripta', grantsLevel: true);
        // El aviso de haberse vinculado ya llegó; se limpia para mirar solo el
        // del capítulo.
        await send(
          'POST',
          '/api/events/seen',
          token: tokenA,
          body: {
            'ids': [
              for (final e
                  in (await send(
                        'GET',
                        '/api/events',
                        token: tokenA,
                      ))['body']['events']
                      as List)
                e['id'],
            ],
          },
        );

        final closed = await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );
        expect(closed['status'], 200);
        expect((await listChapters(tokenB, 'tumba'))[0]['state'], 'completed');

        final forPlayer =
            (await send('GET', '/api/events', token: tokenA))['body']['events']
                as List;
        expect(forPlayer, hasLength(1));
        expect(forPlayer[0]['kind'], 'chapter_completed');
        expect(forPlayer[0]['payload']['characterName'], 'Sagan');
        expect(forPlayer[0]['payload']['campaignName'], 'La Tumba');
        expect(forPlayer[0]['payload']['chapterName'], 'La Cripta');
        expect(forPlayer[0]['payload']['grantsLevel'], isTrue);

        // Al DM que lo cerró no le llega nada: ya vio la respuesta.
        final forDm =
            (await send('GET', '/api/events', token: tokenB))['body']['events']
                as List;
        expect(forDm, isEmpty);
      });

      group('Conceder Inspiración Heroica', () {
        /// Vincula un personaje a una campaña y devuelve los dos tokens más el
        /// `memberId`, que es lo que identifica el vínculo.
        Future<(String, String, String)> mesa(String slug) async {
          final tokenA = await login('$slug-player');
          final code = await shareCharacter(tokenA, 'sagan');
          final tokenB = await login('$slug-dm');
          await createCampaign(tokenB, 'tumba');
          final redeemed = await send(
            'POST',
            '/api/campaigns/tumba/members',
            token: tokenB,
            body: {'code': code},
          );
          return (
            tokenA,
            tokenB,
            redeemed['body']['member']['memberId'] as String,
          );
        }

        test('le llega el aviso al dueño del personaje', () async {
          final (tokenA, tokenB, memberId) = await mesa('hi-ok');

          final res = await send(
            'POST',
            '/api/campaigns/tumba/members/$memberId/heroic-inspiration',
            token: tokenB,
          );
          expect(res['status'], 200);

          final forPlayer =
              (await send(
                    'GET',
                    '/api/events',
                    token: tokenA,
                  ))['body']['events']
                  as List;
          final aviso = forPlayer.firstWhere(
            (e) => e['kind'] == 'heroic_inspiration_granted',
          );
          expect(aviso['payload']['characterName'], 'Sagan');
          expect(aviso['payload']['campaignName'], 'La Tumba');

          // Al DM que la concedió no le llega nada: ya vio la respuesta.
          final forDm =
              (await send(
                    'GET',
                    '/api/events',
                    token: tokenB,
                  ))['body']['events']
                  as List;
          expect(
            forDm.where((e) => e['kind'] == 'heroic_inspiration_granted'),
            isEmpty,
          );
        });

        test('no le toca la ficha al jugador', () async {
          // La prueba que fija la frontera del Modo DM. Compara el **documento
          // guardado** y no la ficha compilada: una compilada podría coincidir
          // aunque el documento hubiera cambiado.
          final (tokenA, tokenB, memberId) = await mesa('hi-frontera');

          final antes = await send('GET', '/api/characters', token: tokenA);
          await send(
            'POST',
            '/api/campaigns/tumba/members/$memberId/heroic-inspiration',
            token: tokenB,
          );
          final despues = await send('GET', '/api/characters', token: tokenA);

          expect(despues['body'], antes['body']);
        });

        test('un DM ajeno a la campaña recibe 404', () async {
          final (_, _, memberId) = await mesa('hi-ajeno');
          final intruso = await login('hi-intruso');

          final res = await send(
            'POST',
            '/api/campaigns/tumba/members/$memberId/heroic-inspiration',
            token: intruso,
          );
          // Lo ajeno y lo inexistente responden igual: distinguirlos convertiría
          // la API en una forma de averiguar qué hay en otras cuentas.
          expect(res['status'], 404);
        });

        test('un vínculo que no existe recibe 404', () async {
          final (_, tokenB, _) = await mesa('hi-inexistente');

          final res = await send(
            'POST',
            '/api/campaigns/tumba/members/no-existe/heroic-inspiration',
            token: tokenB,
          );
          expect(res['status'], 404);
        });
      });
      test('un capítulo sin nivel avisa sin la marca de nivel', () async {
        final tokenA = await login('ch-close-nolevel-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-nolevel-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(tokenB, 'tumba', 'cripta');

        await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );

        final forPlayer =
            (await send('GET', '/api/events', token: tokenA))['body']['events']
                as List;
        final chapterEvent = forPlayer.firstWhere(
          (e) => e['kind'] == 'chapter_completed',
        );
        expect(chapterEvent['payload']['grantsLevel'], isFalse);
      });

      group('reparto de objetos', () {
        const potion = {
          'category': 'items',
          'itemId': 'potion-of-healing',
          'name': 'Poción de curación',
          'quantity': 2,
        };

        // Una mesa con dos personajes de dos cuentas y un capítulo con oro.
        Future<
          ({String dm, String a, String b, String memberA, String memberB})
        >
        table(String prefix) async {
          final dm = await login('$prefix-dm');
          await createCampaign(dm, 'tumba');
          final a = await login('$prefix-a');
          final b = await login('$prefix-b');
          final ids = <String>[];
          for (final (token, character) in [(a, 'sagan'), (b, 'elsbeth')]) {
            final redeemed = await send(
              'POST',
              '/api/campaigns/tumba/members',
              token: dm,
              body: {'code': await shareCharacter(token, character)},
            );
            ids.add(redeemed['body']['member']['memberId'] as String);
          }
          await createChapter(dm, 'tumba', 'cripta', grantsGold: 50);
          return (dm: dm, a: a, b: b, memberA: ids[0], memberB: ids[1]);
        }

        Future<Map<String, dynamic>> close(String dm, Object? allocations) =>
            send(
              'POST',
              '/api/campaigns/tumba/chapters/cripta/close',
              token: dm,
              body: {'allocations': allocations},
            );

        Future<List<dynamic>> grantsOf(String token, String character) async =>
            (await send(
                  'GET',
                  '/api/characters/$character/item-grants',
                  token: token,
                ))['body']['grants']
                as List;

        Future<Map<String, dynamic>> completedEvent(String token) async =>
            ((await send('GET', '/api/events', token: token))['body']['events']
                        as List)
                    .firstWhere(
                      (e) => e['kind'] == 'chapter_completed',
                    )['payload']
                as Map<String, dynamic>;

        test(
          'cada dueño recibe solo lo suyo, y el aviso lleva lo suyo',
          () async {
            final t = await table('rep-own');

            final closed = await close(t.dm, [
              {
                'memberId': t.memberA,
                'items': [potion],
                'freeItems': ['Mapa del contrabandista'],
              },
            ]);
            expect(closed['status'], 200);

            final grants = await grantsOf(t.a, 'sagan');
            expect(grants, hasLength(1));
            expect(grants.single['name'], 'Poción de curación');
            expect(grants.single['quantity'], 2);
            expect(grants.single['campaignName'], 'La Tumba');
            expect(grants.single['chapterName'], 'La Cripta');
            expect(grants.single['homebrew'], isFalse);
            // El documento nunca viaja al cliente.
            expect(grants.single.containsKey('homebrewDocument'), isFalse);
            expect(await grantsOf(t.b, 'elsbeth'), isEmpty);

            final mine = await completedEvent(t.a);
            expect(mine['grantsItems'], [
              'Mapa del contrabandista',
              'Poción de curación ×2',
            ]);
            expect(mine['hasGrants'], isTrue);
            // Sin objetos, el aviso llega igual con su oro, y sin la marca.
            final theirs = await completedEvent(t.b);
            expect(theirs['grantsGold'], 50);
            expect(theirs['grantsItems'], isEmpty);
            expect(theirs.containsKey('hasGrants'), isFalse);

            // El capítulo guarda lo repartido, no a quién le tocó.
            final chapter = (await listChapters(t.dm, 'tumba')).single;
            expect(chapter['state'], 'completed');
            expect(chapter['grantsCatalog'], hasLength(1));
            expect(chapter['grantsItems'], ['Mapa del contrabandista']);
            expect(jsonEncode(chapter), isNot(contains(t.memberA)));
          },
        );

        // La frontera del Modo DM: el reparto deja una bandeja, no escribe la ficha.
        test('cerrar con reparto no cambia el documento de la ficha', () async {
          final t = await table('rep-sheet');
          Future<dynamic> sheet() async =>
              (await send('GET', '/api/characters', token: t.a))['body'];
          final before = jsonEncode(await sheet());

          await close(t.dm, [
            {
              'memberId': t.memberA,
              'items': [potion],
            },
          ]);

          expect(jsonEncode(await sheet()), before);
        });

        test(
          'un memberId de otra mesa es un 400 y no deja nada hecho',
          () async {
            final t = await table('rep-foreign');
            final other = await login('rep-foreign-other');
            await createCampaign(other, 'otra');
            final alien = await send(
              'POST',
              '/api/campaigns/otra/members',
              token: other,
              body: {'code': await shareCharacter(t.a, 'sagan-2')},
            );
            final alienId = alien['body']['member']['memberId'] as String;

            final closed = await close(t.dm, [
              {
                'memberId': alienId,
                'items': [potion],
              },
            ]);

            expect(closed['status'], 400);
            expect(
              (await listChapters(t.dm, 'tumba')).single['state'],
              'planned',
            );
            expect(await grantsOf(t.a, 'sagan'), isEmpty);
            expect(await grantsOf(t.a, 'sagan-2'), isEmpty);
          },
        );

        test('un homebrew que no es del DM es un 400', () async {
          final t = await table('rep-hb-foreign');
          // El objeto existe, pero en la cuenta del jugador y no en la del DM.
          await send(
            'PUT',
            '/api/homebrew/items/hoja',
            token: t.a,
            body: _homebrewItem('hoja', 'Hoja del Cuervo'),
          );

          final closed = await close(t.dm, [
            {
              'memberId': t.memberA,
              'items': [
                {
                  'category': 'items',
                  'itemId': 'hoja',
                  'name': 'Hoja del Cuervo',
                  'homebrew': true,
                },
              ],
            },
          ]);

          expect(closed['status'], 400);
          expect(
            (await listChapters(t.dm, 'tumba')).single['state'],
            'planned',
          );
        });

        test(
          'cerrar con nivel y oro los deja en el aviso y en el capítulo',
          () async {
            final dm = await login('rep-lvlgold-dm');
            await createCampaign(dm, 'tumba');
            final a = await login('rep-lvlgold-a');
            await send(
              'POST',
              '/api/campaigns/tumba/members',
              token: dm,
              body: {'code': await shareCharacter(a, 'sagan')},
            );
            // Un capítulo que no tenía nada cargado.
            await createChapter(dm, 'tumba', 'cripta');

            final closed = await send(
              'POST',
              '/api/campaigns/tumba/chapters/cripta/close',
              token: dm,
              body: {'grantsLevel': true, 'grantsGold': 25},
            );
            expect(closed['status'], 200);

            final event = await completedEvent(a);
            expect(event['grantsLevel'], isTrue);
            expect(event['grantsGold'], 25);
            final chapter = (await listChapters(dm, 'tumba')).single;
            expect(chapter['grantsLevel'], isTrue);
            expect(chapter['grantsGold'], 25);
          },
        );

        test(
          'cerrar sin cuerpo sigue igual: los nombres, sin regalos',
          () async {
            final t = await table('rep-nobody');

            final closed = await send(
              'POST',
              '/api/campaigns/tumba/chapters/cripta/close',
              token: t.dm,
            );

            expect(closed['status'], 200);
            expect(await grantsOf(t.a, 'sagan'), isEmpty);
            final event = await completedEvent(t.a);
            expect(event['grantsGold'], 50);
            expect(event.containsKey('hasGrants'), isFalse);
          },
        );

        test('cerrar dos veces no repite regalos ni avisos', () async {
          final t = await table('rep-twice');
          final allocations = [
            {
              'memberId': t.memberA,
              'items': [potion],
            },
          ];

          await close(t.dm, allocations);
          final again = await close(t.dm, allocations);

          expect(again['status'], 200);
          expect(await grantsOf(t.a, 'sagan'), hasLength(1));
          final events =
              (await send('GET', '/api/events', token: t.a))['body']['events']
                  as List;
          expect(
            events.where((e) => e['kind'] == 'chapter_completed'),
            hasLength(1),
          );
        });

        test(
          'la campaña vista por el jugador no dice a quién le tocó qué',
          () async {
            final t = await table('rep-playerview');
            await close(t.dm, [
              {
                'memberId': t.memberA,
                'items': [potion],
                'freeItems': ['Mapa del contrabandista'],
              },
            ]);

            final view = await send(
              'GET',
              '/api/characters/elsbeth/campaigns',
              token: t.b,
            );
            final text = jsonEncode(view['body']);

            // Lo repartido (la unión) es público para la mesa, como siempre lo fue el
            // botín; lo que no viaja es nada por persona.
            expect(text, contains('Poción de curación'));
            expect(text, isNot(contains(t.memberA)));
            expect(text, isNot(contains('allocations')));
            expect(text, isNot(contains('hasGrants')));
            expect(text, isNot(contains('homebrewDocument')));
          },
        );

        test('borrar el personaje se lleva sus regalos', () async {
          final t = await table('rep-cascade');
          await close(t.dm, [
            {
              'memberId': t.memberA,
              'items': [potion],
            },
          ]);
          expect(itemGrants.count, 1);

          await send('DELETE', '/api/characters/sagan', token: t.a);

          expect(itemGrants.count, 0);
        });

        group('dar un objeto desde la Mesa', () {
          Future<Map<String, dynamic>> give(
            String dm,
            String memberId,
            Object? items,
          ) => send(
            'POST',
            '/api/campaigns/tumba/members/$memberId/item-grants',
            token: dm,
            body: {'items': items},
          );

          test(
            'crea el regalo y el aviso solo al dueño, y la ficha no cambia',
            () async {
              final t = await table('dar-ok');
              Future<String> sheet() async => jsonEncode(
                (await send('GET', '/api/characters', token: t.a))['body'],
              );
              final before = await sheet();

              final given = await give(t.dm, t.memberA, [potion]);

              expect(given['status'], 200);
              final grants = await grantsOf(t.a, 'sagan');
              expect(grants, hasLength(1));
              expect(grants.single['chapterName'], '');
              expect(grants.single['quantity'], 2);
              final event =
                  ((await send(
                                'GET',
                                '/api/events',
                                token: t.a,
                              ))['body']['events']
                              as List)
                          .firstWhere(
                            (e) => e['kind'] == 'item_granted',
                          )['payload']
                      as Map;
              expect(event['grantsItems'], ['Poción de curación ×2']);
              expect(event['hasGrants'], isTrue);
              // Solo al dueño: ni a otro miembro de la mesa ni al DM.
              expect(await grantsOf(t.b, 'elsbeth'), isEmpty);
              for (final other in [t.b, t.dm]) {
                final kinds =
                    ((await send(
                              'GET',
                              '/api/events',
                              token: other,
                            ))['body']['events']
                            as List)
                        .map((e) => e['kind']);
                expect(kinds, isNot(contains('item_granted')));
              }
              expect(await sheet(), before);
            },
          );

          test(
            'un vínculo o una campaña ajenos responden igual que los inexistentes',
            () async {
              final t = await table('dar-404');
              final stranger = await login('dar-404-stranger');
              const missing = '00000000-0000-4000-8000-0000000000ff';

              final foreign = await give(stranger, t.memberA, [potion]);
              final unknown = await give(t.dm, missing, [potion]);
              final noCampaign = await send(
                'POST',
                '/api/campaigns/otra/members/${t.memberA}/item-grants',
                token: t.dm,
                body: {
                  'items': [potion],
                },
              );

              expect(foreign['status'], 404);
              expect(unknown['status'], 404);
              expect(noCampaign['status'], 404);
              expect(await grantsOf(t.a, 'sagan'), isEmpty);
            },
          );

          test(
            'una lista vacía, una categoría inválida o texto libre son un 400',
            () async {
              final t = await table('dar-400');

              expect((await give(t.dm, t.memberA, []))['status'], 400);
              expect(
                (await give(t.dm, t.memberA, [
                  {'category': 'spells', 'itemId': 'x', 'name': 'X'},
                ]))['status'],
                400,
              );
              expect(
                (await give(t.dm, t.memberA, [
                  'Mapa del contrabandista',
                ]))['status'],
                400,
              );
              expect(await grantsOf(t.a, 'sagan'), isEmpty);
            },
          );

          test('un homebrew que no es del DM es un 400', () async {
            final t = await table('dar-hb');
            await send(
              'PUT',
              '/api/homebrew/items/hoja',
              token: t.a,
              body: _homebrewItem('hoja', 'Hoja del Cuervo'),
            );

            final given = await give(t.dm, t.memberA, [
              {
                'category': 'items',
                'itemId': 'hoja',
                'name': 'Hoja del Cuervo',
                'homebrew': true,
              },
            ]);

            expect(given['status'], 400);
            expect(await grantsOf(t.a, 'sagan'), isEmpty);
          });
        });

        group('la bandeja del jugador', () {
          Future<(String, String, Map<String, dynamic>)> withGift(
            String prefix, {
            bool homebrewItem = false,
          }) async {
            final t = await table(prefix);
            var item = potion as Map<String, Object?>;
            if (homebrewItem) {
              await send(
                'PUT',
                '/api/homebrew/items/hoja',
                token: t.dm,
                body: _homebrewItem('hoja', 'Hoja del Cuervo'),
              );
              item = {
                'category': 'items',
                'itemId': 'hoja',
                'name': 'Hoja del Cuervo',
                'homebrew': true,
              };
            }
            await close(t.dm, [
              {
                'memberId': t.memberA,
                'items': [item],
              },
            ]);
            final id = (await grantsOf(t.a, 'sagan')).single['id'] as String;
            return (t.a, id, {'dm': t.dm, 'b': t.b});
          }

          test('lo ajeno responde igual que lo inexistente', () async {
            final (_, id, others) = await withGift('rep-404');
            final stranger = await login('rep-404-stranger');
            const missing = '00000000-0000-4000-a000-999999999999';

            for (final token in [stranger, others['b'] as String]) {
              final listed = await send(
                'GET',
                '/api/characters/sagan/item-grants',
                token: token,
              );
              expect(listed['status'], 404);
              final claim = await send(
                'POST',
                '/api/item-grants/$id/claim',
                token: token,
              );
              final claimMissing = await send(
                'POST',
                '/api/item-grants/$missing/claim',
                token: token,
              );
              expect(claim['status'], 404);
              expect(claim['body'], claimMissing['body']);
              final resolve = await send(
                'DELETE',
                '/api/item-grants/$id',
                token: token,
              );
              expect(resolve['status'], 404);
              expect(
                resolve['body'],
                (await send(
                  'DELETE',
                  '/api/item-grants/$missing',
                  token: token,
                ))['body'],
              );
            }
            // Ni siquiera el DM que lo repartió lo toca.
            expect(
              (await send(
                'DELETE',
                '/api/item-grants/$id',
                token: others['dm'] as String,
              ))['status'],
              404,
            );
          });

          test(
            'reclamar devuelve el objeto, no borra la fila y resolver la saca',
            () async {
              final (player, id, _) = await withGift('rep-claim');

              final claimed = await send(
                'POST',
                '/api/item-grants/$id/claim',
                token: player,
              );
              expect(claimed['status'], 200);
              expect(claimed['body']['itemId'], 'potion-of-healing');
              expect(claimed['body']['quantity'], 2);
              expect(await grantsOf(player, 'sagan'), hasLength(1));

              expect(
                (await send(
                  'DELETE',
                  '/api/item-grants/$id',
                  token: player,
                ))['status'],
                200,
              );
              expect(await grantsOf(player, 'sagan'), isEmpty);
            },
          );

          test(
            'reclamar un homebrew crea la copia en la cuenta del jugador',
            () async {
              final (player, id, _) = await withGift(
                'rep-hb',
                homebrewItem: true,
              );
              // El jugador ya tiene un objeto propio con el mismo id de origen.
              await send(
                'PUT',
                '/api/homebrew/items/hoja',
                token: player,
                body: _homebrewItem('hoja', 'Mi hoja'),
              );

              final first = await send(
                'POST',
                '/api/item-grants/$id/claim',
                token: player,
              );
              final second = await send(
                'POST',
                '/api/item-grants/$id/claim',
                token: player,
              );

              expect(first['body']['itemId'], isNot('hoja'));
              expect(second['body']['itemId'], first['body']['itemId']);
              final own =
                  (await send(
                        'GET',
                        '/api/homebrew',
                        token: player,
                      ))['body']['content']['items']
                      as List;
              // Lo propio no se pisa, y la copia entra una sola vez con su id.
              expect(
                own.map((d) => d['name']),
                unorderedEquals(['Mi hoja', 'Hoja del Cuervo']),
              );
              expect(
                own.singleWhere((d) => d['name'] == 'Hoja del Cuervo')['id'],
                first['body']['itemId'],
              );
            },
          );
        });
      });

      test('el botín del capítulo viaja en el aviso', () async {
        final tokenA = await login('ch-close-loot-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-loot-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(
          tokenB,
          'tumba',
          'cripta',
          grantsGold: 250,
          grantsItems: ['Espada larga +1', 'Poción de curación'],
        );

        await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );

        final chapterEvent =
            ((await send('GET', '/api/events', token: tokenA))['body']['events']
                    as List)
                .firstWhere((e) => e['kind'] == 'chapter_completed');
        expect(chapterEvent['payload']['grantsGold'], 250);
        expect(chapterEvent['payload']['grantsItems'], [
          'Espada larga +1',
          'Poción de curación',
        ]);
      });

      // LA prueba de esta feature, y por eso es negativa: el DM anuncia el
      // botín y el aviso llega, pero **la ficha del jugador no se mueve**. El
      // oro y los ítems los anota él. Si algún día alguien hace que el cierre
      // escriba la ficha ajena, se entera acá.
      test(
        'cerrar un capítulo con botín no toca la ficha del jugador',
        () async {
          final tokenA = await login('ch-close-untouched-player');
          final code = await shareCharacter(tokenA, 'sagan');

          Future<Object?> sagan() async =>
              ((await send(
                        'GET',
                        '/api/characters',
                        token: tokenA,
                      ))['body']['characters']
                      as List)
                  .firstWhere((c) => c['character']['id'] == 'sagan');

          final before = await sagan();

          final tokenB = await login('ch-close-untouched-dm');
          await createCampaign(tokenB, 'tumba');
          await send(
            'POST',
            '/api/campaigns/tumba/members',
            token: tokenB,
            body: {'code': code},
          );
          await createChapter(
            tokenB,
            'tumba',
            'cripta',
            grantsLevel: true,
            grantsGold: 250,
            grantsItems: ['Espada larga +1'],
          );

          await send(
            'POST',
            '/api/campaigns/tumba/chapters/cripta/close',
            token: tokenB,
          );

          expect(await sagan(), before);
        },
      );

      test('un botín escrito mal se guarda limpio en vez de romper', () async {
        final token = await login('ch-loot-dirty');
        await createCampaign(token, 'tumba');
        final created = await createChapter(
          token,
          'tumba',
          'cripta',
          grantsGold: -50,
          grantsItems: ['  Espada larga +1  ', '', 7],
        );

        expect(created['status'], 200);
        expect(created['body']['chapter']['grantsGold'], 0);
        expect(created['body']['chapter']['grantsItems'], ['Espada larga +1']);
      });

      // Cerrar dos veces no es un error, pero tampoco vuelve a avisar.
      test('cerrar un capítulo ya cerrado no repite el aviso', () async {
        final tokenA = await login('ch-close-twice-player');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('ch-close-twice-dm');
        await createCampaign(tokenB, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        await createChapter(tokenB, 'tumba', 'cripta');

        await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );
        final afterFirst =
            ((await send('GET', '/api/events', token: tokenA))['body']['events']
                    as List)
                .where((e) => e['kind'] == 'chapter_completed')
                .length;

        final second = await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: tokenB,
        );
        expect(second['status'], 200);

        final afterSecond =
            ((await send('GET', '/api/events', token: tokenA))['body']['events']
                    as List)
                .where((e) => e['kind'] == 'chapter_completed')
                .length;
        expect(afterSecond, afterFirst);
      });

      test('cerrar un capítulo inexistente responde 404', () async {
        final token = await login('ch-close-missing');
        await createCampaign(token, 'tumba');

        final response = await send(
          'POST',
          '/api/campaigns/tumba/chapters/fantasma/close',
          token: token,
        );

        expect(response['status'], 404);
      });

      test('borrar la campaña se lleva sus capítulos', () async {
        final token = await login('ch-cascade');
        await createCampaign(token, 'tumba');
        await createChapter(token, 'tumba', 'cripta');

        await send('DELETE', '/api/campaigns/tumba', token: token);
        await createCampaign(token, 'tumba');

        expect(await listChapters(token, 'tumba'), isEmpty);
      });
    });

    group('cuaderno', () {
      Map<String, dynamic> noteJson(
        String id, {
        String chapterId = 'cripta',
        String title = 'Los tres sellos',
        String body = 'El tercero está detrás del tapiz.',
      }) => {
        'schemaVersion': 1,
        'id': id,
        'chapterId': chapterId,
        'title': title,
        'body': body,
      };

      Future<Map<String, dynamic>> createNote(
        String token,
        String campaignId,
        String id, {
        String chapterId = 'cripta',
        String title = 'Los tres sellos',
      }) => send(
        'POST',
        '/api/campaigns/$campaignId/notes',
        token: token,
        body: {'note': noteJson(id, chapterId: chapterId, title: title)},
      );

      Future<Map<String, dynamic>> notebook(
        String token,
        String campaignId,
      ) async {
        final response = await send(
          'GET',
          '/api/campaigns/$campaignId/notebook',
          token: token,
        );
        return response['body'] as Map<String, dynamic>;
      }

      /// Una campaña con un capítulo donde colgar notas.
      Future<String> tableWithChapter(String user) async {
        final token = await login(user);
        await createCampaign(token, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/chapters',
          token: token,
          body: {
            'chapter': {
              'schemaVersion': 1,
              'id': 'cripta',
              'name': 'La Cripta',
              'summary': '',
              'state': 'planned',
              'grantsLevel': false,
            },
          },
        );
        return token;
      }

      test('sin sesión ninguna operación responde 401', () async {
        for (final request in [
          Request(
            'GET',
            Uri.parse('http://localhost/api/campaigns/c1/notebook'),
          ),
          Request(
            'POST',
            Uri.parse('http://localhost/api/campaigns/c1/notes'),
            body: jsonEncode({'note': noteJson('n1')}),
          ),
          Request(
            'PUT',
            Uri.parse('http://localhost/api/campaigns/c1/notes/n1'),
            body: jsonEncode({'note': noteJson('n1')}),
          ),
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/campaigns/c1/notes/n1'),
          ),
        ]) {
          expect(
            (await handler(request)).statusCode,
            401,
            reason: '${request.url}',
          );
        }
      });

      test('crear, listar, editar y borrar una nota', () async {
        final token = await tableWithChapter('nota-crud');

        final created = await createNote(token, 'tumba', 'sellos');
        expect(created['status'], 200);
        expect(created['body']['note']['title'], 'Los tres sellos');

        expect((await notebook(token, 'tumba'))['notes'], hasLength(1));

        final edited = await send(
          'PUT',
          '/api/campaigns/tumba/notes/sellos',
          token: token,
          body: {
            'note': noteJson('sellos', title: 'Los tres sellos (corregido)'),
          },
        );
        expect(edited['status'], 200);
        expect(
          ((await notebook(token, 'tumba'))['notes'] as List).single['title'],
          'Los tres sellos (corregido)',
        );

        await send('DELETE', '/api/campaigns/tumba/notes/sellos', token: token);
        expect((await notebook(token, 'tumba'))['notes'], isEmpty);
      });

      test('una nota necesita un capítulo que exista', () async {
        final token = await tableWithChapter('nota-sin-cap');
        final response = await createNote(
          token,
          'tumba',
          'suelta',
          chapterId: 'no-existe',
        );
        expect(response['status'], 400);
      });

      test('una nota sin título se rechaza', () async {
        final token = await tableWithChapter('nota-sin-titulo');
        final response = await send(
          'POST',
          '/api/campaigns/tumba/notes',
          token: token,
          body: {'note': noteJson('vacia', title: '   ')},
        );
        expect(response['status'], 400);
      });

      // Lo ajeno y lo inexistente responden igual, como en todo el resto del
      // espacio de campañas.
      test('el cuaderno de una campaña ajena no se ve ni se toca', () async {
        final owner = await tableWithChapter('nota-duena');
        await createNote(owner, 'tumba', 'sellos');
        final other = await login('nota-ajena');

        expect((await notebook(other, 'tumba'))['status'], isNull);
        for (final call in [
          send('GET', '/api/campaigns/tumba/notebook', token: other),
          send(
            'POST',
            '/api/campaigns/tumba/notes',
            token: other,
            body: {'note': noteJson('intrusa')},
          ),
          send(
            'PUT',
            '/api/campaigns/tumba/notes/sellos',
            token: other,
            body: {'note': noteJson('sellos', title: 'Pisada')},
          ),
          send('DELETE', '/api/campaigns/tumba/notes/sellos', token: other),
        ]) {
          expect((await call)['status'], 404);
        }

        // Y la nota de la dueña quedó intacta.
        final mine = (await notebook(owner, 'tumba'))['notes'] as List;
        expect(mine.single['title'], 'Los tres sellos');
      });

      test('borrar el capítulo se lleva sus notas', () async {
        final token = await tableWithChapter('nota-cascada');
        await createNote(token, 'tumba', 'sellos');
        expect((await notebook(token, 'tumba'))['notes'], hasLength(1));

        await send(
          'DELETE',
          '/api/campaigns/tumba/chapters/cripta',
          token: token,
        );

        expect((await notebook(token, 'tumba'))['notes'], isEmpty);
      });

      test('borrar la campaña se lleva el cuaderno', () async {
        final token = await tableWithChapter('nota-campana');
        await createNote(token, 'tumba', 'sellos');

        await send('DELETE', '/api/campaigns/tumba', token: token);
        await createCampaign(token, 'tumba');

        expect((await notebook(token, 'tumba'))['notes'], isEmpty);
      });

      // El cuaderno es el primer lector de `encounter_logs`: hasta ahora se
      // grababan y no los leía nadie.
      test('el combate cerrado aparece en el cuaderno', () async {
        final token = await tableWithChapter('nota-combate');

        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': {
              'schemaVersion': 1,
              'id': 'e1',
              'round': 4,
              'turnIndex': 0,
              'combatants': [
                {
                  'id': 'm1',
                  'kind': 'monster',
                  'name': 'Esqueleto 1',
                  'initiative': 12,
                  'creatureId': 'skeleton',
                  'currentHp': 0,
                  'maxHp': 13,
                },
                {
                  'id': 'm2',
                  'kind': 'monster',
                  'name': 'Esqueleto 2',
                  'initiative': 11,
                  'creatureId': 'skeleton',
                  'currentHp': 5,
                  'maxHp': 13,
                },
              ],
            },
          },
        );
        await send('DELETE', '/api/campaigns/tumba/encounter', token: token);

        final logs = (await notebook(token, 'tumba'))['encounterLogs'] as List;
        expect(logs, hasLength(1));
        expect(logs.single['rounds'], 4);
        // Las copias se agrupan y el número de la mesa se saca del nombre.
        final monsters = logs.single['monsters'] as List;
        expect(monsters.single['name'], 'Esqueleto');
        expect(monsters.single['count'], 2);
        expect(monsters.single['defeated'], 1);
      });

      // Sin capítulo en marcha el combate se archiva suelto; el DM lo cuelga
      // después. Lo que ya tiene capítulo no se mueve, y lo ajeno no se toca.
      test(
        'un combate suelto se cuelga de un capítulo, una sola vez',
        () async {
          final token = await tableWithChapter('nota-suelto');
          await send(
            'POST',
            '/api/campaigns/tumba/chapters',
            token: token,
            body: {
              'chapter': {
                'schemaVersion': 1,
                'id': 'feria',
                'name': 'La feria',
              },
            },
          );
          await send(
            'PUT',
            '/api/campaigns/tumba/encounter',
            token: token,
            body: {
              'encounter': {
                'schemaVersion': 1,
                'id': 'e1',
                'round': 1,
                'turnIndex': 0,
                'combatants': [
                  {
                    'id': 'm1',
                    'kind': 'monster',
                    'name': 'Esqueleto',
                    'initiative': 12,
                    'creatureId': 'skeleton',
                    'currentHp': 0,
                    'maxHp': 13,
                  },
                ],
              },
            },
          );
          await send('DELETE', '/api/campaigns/tumba/encounter', token: token);
          final log =
              ((await notebook(token, 'tumba'))['encounterLogs'] as List).single
                  as Map<String, dynamic>;
          expect(log['chapterId'], isNull);
          final path =
              '/api/campaigns/tumba/encounter-logs/${log['id']}/chapter';

          final other = await login('nota-suelto-otro');
          await createCampaign(other, 'tumba');
          final ajeno = await send(
            'PUT',
            path,
            token: other,
            body: {'chapterId': 'cripta'},
          );
          expect(ajeno['status'], 404);

          final inventado = await send(
            'PUT',
            path,
            token: token,
            body: {'chapterId': 'no-existe'},
          );
          expect(inventado['status'], 404);

          final ok = await send(
            'PUT',
            path,
            token: token,
            body: {'chapterId': 'cripta'},
          );
          expect(ok['status'], 200);
          final logs =
              (await notebook(token, 'tumba'))['encounterLogs'] as List;
          expect(logs.single['chapterId'], 'cripta');

          final otraVez = await send(
            'PUT',
            path,
            token: token,
            body: {'chapterId': 'feria'},
          );
          expect(otraVez['status'], 404);
          final despues =
              (await notebook(token, 'tumba'))['encounterLogs'] as List;
          expect(despues.single['chapterId'], 'cripta');
        },
      );

      // El orden se guarda aparte del capítulo: tiene que poder ordenarse uno
      // ya cerrado (el PUT del capítulo lo rechaza) sin tocar nada más de él.
      test(
        'el orden del cuaderno se guarda, también en un capítulo cerrado',
        () async {
          final token = await tableWithChapter('nota-orden');
          await send(
            'POST',
            '/api/campaigns/tumba/chapters/cripta/close',
            token: token,
          );
          const path = '/api/campaigns/tumba/chapters/cripta/entry-order';

          final other = await login('nota-orden-otro');
          await createCampaign(other, 'tumba');
          final ajeno = await send(
            'PUT',
            path,
            token: other,
            body: {
              'entryOrder': ['note:x'],
            },
          );
          expect(ajeno['status'], 404);

          final ok = await send(
            'PUT',
            path,
            token: token,
            body: {
              'entryOrder': ['fight:1', 'note:a', 'fight:1'],
            },
          );
          expect(ok['status'], 200);
          final chapter =
              ((await send(
                        'GET',
                        '/api/campaigns/tumba/chapters',
                        token: token,
                      ))['body']['chapters']
                      as List)
                  .single;
          expect(chapter['entryOrder'], ['fight:1', 'note:a']);
          expect(chapter['state'], 'completed');
          expect(chapter['name'], 'La Cripta');
        },
      );

      test('un combate descartado no deja entrada', () async {
        final token = await tableWithChapter('nota-descarte');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': {
              'schemaVersion': 1,
              'id': 'e1',
              'round': 1,
              'turnIndex': 0,
              'combatants': <dynamic>[],
            },
          },
        );
        await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=true',
          token: token,
        );

        expect((await notebook(token, 'tumba'))['encounterLogs'], isEmpty);
      });

      // La subida se registra cuando el jugador la anota en su ficha, no
      // cuando el DM la otorga: es lo único que dice que efectivamente pasó.
      group('subidas de nivel', () {
        /// Sagan (guerrero 1) vinculado a «tumba». Con [chapterState], la
        /// campaña tiene además el capítulo «cripta» en ese estado.
        Future<({String owner, String dm})> linkedTable(
          String suffix, {
          String? chapterState,
        }) async {
          final owner = await login('nivel-jugador-$suffix');
          final code = await shareCharacter(owner, 'sagan');
          final dm = await login('nivel-dm-$suffix');
          await createCampaign(dm, 'tumba');
          await send(
            'POST',
            '/api/campaigns/tumba/members',
            token: dm,
            body: {'code': code},
          );
          if (chapterState != null) {
            await send(
              'POST',
              '/api/campaigns/tumba/chapters',
              token: dm,
              body: {
                'chapter': {
                  'schemaVersion': 1,
                  'id': 'cripta',
                  'name': 'La Cripta',
                  'summary': '',
                  'state': chapterState,
                  'grantsLevel': false,
                },
              },
            );
          }
          return (owner: owner, dm: dm);
        }

        Future<Map<String, dynamic>> saveSheet(
          String owner,
          List<String> classHistory,
        ) => send(
          'PUT',
          '/api/characters/sagan',
          token: owner,
          body: {
            'character': {
              ...characterJson('sagan'),
              'classHistory': classHistory,
            },
          },
        );

        Future<List<dynamic>> levelUpsOf(String dm) async =>
            (await notebook(dm, 'tumba'))['levelUps'] as List;

        test('subir un nivel lo anota en el capítulo en marcha', () async {
          final t = await linkedTable('uno', chapterState: 'active');

          expect(
            (await saveSheet(t.owner, ['fighter', 'fighter']))['status'],
            200,
          );

          final entry = (await levelUpsOf(t.dm)).single as Map;
          expect(entry['id'], isA<String>());
          expect(entry['chapterId'], 'cripta');
          expect(entry['characterName'], 'Sagan');
          expect(entry['level'], 2);
          expect(entry['classId'], 'fighter');
          expect(entry['classLevel'], 2);
          expect(DateTime.parse(entry['at'] as String).isUtc, isTrue);

          // Borrar el capítulo no deshace la subida: ya pasó.
          await send(
            'DELETE',
            '/api/campaigns/tumba/chapters/cripta',
            token: t.dm,
          );
          expect(await levelUpsOf(t.dm), hasLength(1));
        });

        test(
          'subir dos niveles en un guardado deja una entrada por nivel',
          () async {
            final t = await linkedTable('dos', chapterState: 'active');

            await saveSheet(t.owner, ['fighter', 'fighter', 'rogue']);

            // De la más nueva a la más vieja, y cada una con la clase que
            // ganó ese nivel: la multiclase no se aplana en la clase inicial.
            final entries = await levelUpsOf(t.dm);
            expect([for (final e in entries) e['level']], [3, 2]);
            expect(
              [for (final e in entries) e['classId']],
              ['rogue', 'fighter'],
            );
            expect([for (final e in entries) e['classLevel']], [1, 2]);
          },
        );

        test('guardar sin subir de nivel no anota nada', () async {
          final t = await linkedTable('igual', chapterState: 'active');

          await saveSheet(t.owner, ['fighter']);
          expect(await levelUpsOf(t.dm), isEmpty);

          await saveSheet(t.owner, ['fighter', 'fighter']);
          await saveSheet(t.owner, ['fighter', 'fighter']);
          // Bajar tampoco anota, ni borra lo que ya estaba.
          await saveSheet(t.owner, ['fighter']);
          expect(await levelUpsOf(t.dm), hasLength(1));
        });

        test('sin capítulo en marcha la entrada no lleva capítulo', () async {
          final t = await linkedTable('sin-cap', chapterState: 'planned');

          await saveSheet(t.owner, ['fighter', 'fighter']);

          final entry = (await levelUpsOf(t.dm)).single as Map;
          expect(entry.containsKey('chapterId'), isFalse);
          expect(entry['level'], 2);
        });

        test('un personaje sin vincular no anota en ninguna campaña', () async {
          final owner = await login('nivel-suelto-jugador');
          await shareCharacter(owner, 'sagan');
          final dm = await login('nivel-suelto-dm');
          await createCampaign(dm, 'tumba');

          await saveSheet(owner, ['fighter', 'fighter']);

          expect(await levelUpsOf(dm), isEmpty);
        });

        // Lo ajeno y lo inexistente responden igual; y el «tumba» de otra
        // cuenta es otra campaña, con su propio cuaderno vacío.
        test('otro DM no ve las subidas de esta campaña', () async {
          final t = await linkedTable('ajeno', chapterState: 'active');
          await saveSheet(t.owner, ['fighter', 'fighter']);
          final other = await login('nivel-otro-dm');

          expect(
            (await send(
              'GET',
              '/api/campaigns/tumba/notebook',
              token: other,
            ))['status'],
            404,
          );
          await createCampaign(other, 'tumba');
          expect(await levelUpsOf(other), isEmpty);
          expect(await levelUpsOf(t.dm), hasLength(1));
        });
      });
    });

    // La vuelta del vínculo: hasta acá el jugador compartía su ficha y no veía
    // nada a cambio. Es la única ruta del servidor por la que un jugador lee
    // una campaña, así que —como en todo este grupo— lo que más importa es lo
    // que NO devuelve.
    group('campaña vista por el jugador', () {
      const summary = 'Detrás del tercer sello duerme la madre de los gules.';

      Future<void> createChapter(
        String token,
        String id,
        String name, {
        String campaignId = 'tumba',
        String state = 'planned',
        int grantsGold = 0,
      }) => send(
        'POST',
        '/api/campaigns/$campaignId/chapters',
        token: token,
        body: {
          'chapter': {
            'schemaVersion': 1,
            'id': id,
            'name': name,
            'summary': summary,
            'state': state,
            'grantsLevel': false,
            'grantsGold': grantsGold,
          },
        },
      );

      /// Una mesa armada: el jugador comparte a Sagan, el DM lo suma y deja un
      /// capítulo cerrado. Devuelve los dos tokens.
      Future<(String player, String dm)> table(String prefix) async {
        final player = await login('$prefix-player');
        final code = await shareCharacter(player, 'sagan');

        final dm = await login('$prefix-dm');
        await createCampaign(dm, 'tumba');
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: dm,
          body: {'code': code},
        );
        await createChapter(dm, 'cripta', 'La cripta sellada', grantsGold: 250);
        await send(
          'POST',
          '/api/campaigns/tumba/chapters/cripta/close',
          token: dm,
        );
        return (player, dm);
      }

      Future<List<dynamic>> campaignsOf(String token, [String id = 'sagan']) =>
          send(
            'GET',
            '/api/characters/$id/campaigns',
            token: token,
          ).then((r) => r['body']['campaigns'] as List);

      test('sin sesión responde 401', () async {
        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/characters/sagan/campaigns'),
          ),
        );
        expect(response.statusCode, 401);
      });

      test('el jugador ve su campaña y el capítulo que se cerró', () async {
        final (player, _) = await table('vista');

        final campaigns = await campaignsOf(player);
        expect(campaigns, hasLength(1));
        final block = campaigns.single as Map<String, dynamic>;
        expect(block['campaign']['name'], 'La Tumba');

        final chapters = block['chapters'] as List;
        expect(chapters, hasLength(1));
        expect(chapters.single['name'], 'La cripta sellada');
        expect(chapters.single['grantsGold'], 250);
      });

      // LA prueba de esta ruta. `Chapter.summary` es lo que el DM escribe
      // adentro del capítulo, y su documentación dice que no la ve ningún
      // jugador ni siquiera con el capítulo cerrado. Se comprueba contra el
      // cuerpo entero y no contra un campo: si mañana alguien la mete anidada
      // en otro lado, esto también lo agarra.
      test('la descripción del capítulo no viaja nunca', () async {
        final (player, dm) = await table('sin-summary');

        // Primero, que el texto exista de verdad: sin esto la prueba de abajo
        // pasaría igual con un capítulo sin descripción, que no prueba nada.
        final delDm = await send(
          'GET',
          '/api/campaigns/tumba/chapters',
          token: dm,
        );
        expect(jsonEncode(delDm['body']), contains('gules'));

        final raw = await send(
          'GET',
          '/api/characters/sagan/campaigns',
          token: player,
        );
        expect(jsonEncode(raw['body']), isNot(contains('gules')));
        expect(
          ((raw['body']['campaigns'] as List).single['chapters'] as List)
              .single['summary'],
          anyOf(isNull, ''),
        );
      });

      // El orden del Cuaderno nombra por id notas privadas y combates: no
      // sale ni en el capítulo en curso ni en los cerrados.
      test('el orden del cuaderno no viaja al jugador', () async {
        final (player, dm) = await table('sin-orden');
        Future<void> ordered(String id, String state) => send(
          'POST',
          '/api/campaigns/tumba/chapters',
          token: dm,
          body: {
            'chapter': {
              'schemaVersion': Chapter.currentSchemaVersion,
              'id': id,
              'name': id,
              'state': state,
              'entryOrder': ['note:orden-secreto-$id'],
            },
          },
        );
        await ordered('camino', 'planned');
        await send(
          'POST',
          '/api/campaigns/tumba/chapters/camino/close',
          token: dm,
        );
        await ordered('feria', 'active');

        final delDm = await send(
          'GET',
          '/api/campaigns/tumba/chapters',
          token: dm,
        );
        expect(jsonEncode(delDm['body']), contains('orden-secreto-feria'));

        final raw = await send(
          'GET',
          '/api/characters/sagan/campaigns',
          token: player,
        );
        expect(jsonEncode(raw['body']), isNot(contains('orden-secreto')));
      });

      test(
        'los capítulos que todavía no se cerraron no van entre los cerrados',
        () async {
          final (player, dm) = await table('solo-cerrados');
          await createChapter(dm, 'camino', 'El camino');
          await createChapter(dm, 'feria', 'La feria', state: 'active');

          final chapters =
              (await campaignsOf(player)).single['chapters'] as List;
          expect(chapters, hasLength(1));
          expect(chapters.single['name'], 'La cripta sellada');
        },
      );

      Future<void> createNote(
        String token,
        String id,
        String chapterId,
        String title,
        String body, {
        bool shared = false,
      }) => send(
        'POST',
        '/api/campaigns/tumba/notes',
        token: token,
        body: {
          'note': {
            'schemaVersion': 2,
            'id': id,
            'chapterId': chapterId,
            'title': title,
            'body': body,
            'shared': shared,
          },
        },
      );

      // La frontera de las notas: lo privado no sale nunca, y lo compartido
      // solo de un capítulo en marcha o cerrado. Se mira el cuerpo entero.
      test('una nota privada no llega al jugador', () async {
        final (player, dm) = await table('nota-privada');
        await createNote(
          dm,
          'n1',
          'cripta',
          'Los tres sellos',
          'Tras el tapiz.',
        );

        final raw = await send(
          'GET',
          '/api/characters/sagan/campaigns',
          token: player,
        );
        expect(jsonEncode(raw['body']), isNot(contains('tapiz')));
        expect(jsonEncode(raw['body']), isNot(contains('sellos')));
        expect(
          (raw['body']['campaigns'] as List).single['sharedNotes'],
          isEmpty,
        );
      });

      test('una nota compartida de un capítulo pendiente no llega', () async {
        final (player, dm) = await table('nota-pendiente');
        await createChapter(dm, 'camino', 'El camino');
        await createNote(
          dm,
          'n1',
          'camino',
          'Emboscada',
          'Cuatro bandidos al vado.',
          shared: true,
        );

        final raw = await send(
          'GET',
          '/api/characters/sagan/campaigns',
          token: player,
        );
        expect(jsonEncode(raw['body']), isNot(contains('bandidos')));
        expect(
          (raw['body']['campaigns'] as List).single['sharedNotes'],
          isEmpty,
        );
      });

      test('el jugador recibe las notas compartidas del capítulo en curso y '
          'de los cerrados, y solo esas', () async {
        final (player, dm) = await table('nota-compartida');
        await createChapter(dm, 'feria', 'La feria', state: 'active');
        await createNote(
          dm,
          'n1',
          'cripta',
          'Lo hallado',
          'Un cáliz.',
          shared: true,
        );
        await createNote(
          dm,
          'n2',
          'feria',
          'Los puestos',
          'Hay siete.',
          shared: true,
        );
        await createNote(dm, 'n3', 'feria', 'El soplón', 'Es el herrero.');

        final block =
            (await campaignsOf(player)).single as Map<String, dynamic>;
        final notes = block['sharedNotes'] as List;
        expect([for (final n in notes) n['id']], unorderedEquals(['n1', 'n2']));
        expect(notes.firstWhere((n) => n['id'] == 'n2')['body'], 'Hay siete.');
        // Lo privado del mismo capítulo en curso sigue sin salir.
        expect(jsonEncode(block), isNot(contains('herrero')));
        // Y la nota no arrastra más que lo que el jugador lee.
        expect(notes.first.keys, isNot(contains('shared')));
      });

      // El objetivo del capítulo en curso llega a propósito; el de un cerrado
      // sigue sin llegar (ver 'la descripción del capítulo no viaja nunca').
      test('el objetivo llega solo del capítulo en curso', () async {
        final (player, dm) = await table('objetivo-en-curso');
        await createChapter(dm, 'feria', 'La feria', state: 'active');
        await createChapter(dm, 'camino', 'El camino');

        final block =
            (await campaignsOf(player)).single as Map<String, dynamic>;
        expect(block['currentChapter']['name'], 'La feria');
        expect(block['currentChapter']['summary'], summary);
        // El cerrado, en cambio, va sin objetivo; el pendiente no va.
        expect(
          (block['chapters'] as List).single['summary'],
          anyOf(isNull, ''),
        );
        expect(jsonEncode(block['chapters']), isNot(contains('gules')));
        expect(jsonEncode(block), isNot(contains('El camino')));
      });

      test('sin capítulo en marcha no hay capítulo en curso', () async {
        final (player, _) = await table('sin-en-curso');

        final block =
            (await campaignsOf(player)).single as Map<String, dynamic>;
        expect(block['currentChapter'], isNull);
      });

      test('las escenas de música y el orden de la Mesa no viajan', () async {
        final (player, dm) = await table('sin-musica');
        await send(
          'PUT',
          '/api/campaigns/tumba',
          token: dm,
          body: {
            'campaign': {
              ...campaignJson('tumba'),
              'schemaVersion': 3,
              'memberOrder': ['orden-secreto-del-dm'],
              'musicScenes': [
                {
                  'id': 's1',
                  'name': 'Lamento del dragón',
                  'url': 'https://youtu.be/dQw4w9WgXcQ',
                  'offerOnCombat': true,
                },
              ],
            },
          },
        );
        // Que las escenas se hayan guardado de verdad, o la prueba de abajo
        // pasaría igual sin probar nada.
        final delDm = await send('GET', '/api/campaigns', token: dm);
        expect(jsonEncode(delDm['body']), contains('Lamento'));
        expect(jsonEncode(delDm['body']), contains('orden-secreto-del-dm'));

        final raw = await send(
          'GET',
          '/api/characters/sagan/campaigns',
          token: player,
        );
        expect(jsonEncode(raw['body']), isNot(contains('Lamento')));
        expect(jsonEncode(raw['body']), isNot(contains('youtu')));
        expect(jsonEncode(raw['body']), isNot(contains('musicScenes')));
        expect(jsonEncode(raw['body']), isNot(contains('memberOrder')));
        expect(
          jsonEncode(raw['body']),
          isNot(contains('orden-secreto-del-dm')),
        );
      });

      test('las batallas cerradas viajan con la mesa', () async {
        final (player, dm) = await table('batallas');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: dm,
          body: {
            'encounter': {
              'schemaVersion': 1,
              'id': 'e1',
              'round': 4,
              'turnIndex': 0,
              'combatants': [
                {
                  'id': 'm1',
                  'kind': 'monster',
                  'name': 'Esqueleto 1',
                  'initiative': 12,
                  'creatureId': 'skeleton',
                  'currentHp': 0,
                  'maxHp': 13,
                },
              ],
            },
          },
        );
        await send('DELETE', '/api/campaigns/tumba/encounter', token: dm);

        final battles = (await campaignsOf(player)).single['battles'] as List;
        expect(battles, hasLength(1));
        expect(battles.single['rounds'], 4);
        expect(
          (battles.single['monsters'] as List).single['name'],
          'Esqueleto',
        );
      });

      test('la mesa lista a los demás y no al propio personaje', () async {
        final (player, dm) = await table('mesa');

        final otro = await login('mesa-otro');
        await send(
          'POST',
          '/api/characters',
          token: otro,
          body: {'character': characterJson('mirna', name: 'Mirna')},
        );
        final code = await send(
          'POST',
          '/api/characters/mirna/share',
          token: otro,
        );
        await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: dm,
          body: {'code': code['body']['code']},
        );

        expect((await campaignsOf(player)).single['party'], ['Mirna']);
      });

      test(
        'agrupa varias campañas, conserva el orden y oculta datos ajenos',
        () async {
          final player = await login('varias-player');
          final code = await shareCharacter(player, 'sagan');
          final dm = await login('varias-dm');

          await createCampaign(dm, 'zorro', name: 'El Zorro');
          await send(
            'POST',
            '/api/campaigns/zorro/members',
            token: dm,
            body: {'code': code},
          );
          await createChapter(
            dm,
            'cripta',
            'La cripta',
            campaignId: 'zorro',
            grantsGold: 100,
          );
          await send(
            'POST',
            '/api/campaigns/zorro/chapters/cripta/close',
            token: dm,
          );

          final otro = await login('varias-otro');
          final otroCode = await shareCharacter(otro, 'mirna', name: 'Mirna');
          await send(
            'POST',
            '/api/campaigns/zorro/members',
            token: dm,
            body: {'code': otroCode},
          );

          final secondCode = await shareCharacter(player, 'sagan');
          await createCampaign(dm, 'alfa', name: 'El Alfa');
          await send(
            'POST',
            '/api/campaigns/alfa/members',
            token: dm,
            body: {'code': secondCode},
          );

          final campaignBlocks = await campaignsOf(player);
          expect(campaignBlocks, hasLength(2));
          expect(
            campaignBlocks.map((campaign) => campaign['campaign']['name']),
            ['El Alfa', 'El Zorro'],
          );
          final alfa = campaignBlocks.first as Map<String, dynamic>;
          final zorro = campaignBlocks.last as Map<String, dynamic>;
          expect(alfa['party'], isEmpty);
          expect(zorro['party'], ['Mirna'], reason: jsonEncode(campaignBlocks));
          expect(zorro['chapters'], hasLength(1));
          expect(zorro.containsKey('dmUserId'), isFalse);
          expect(zorro['campaign'].containsKey('id'), isFalse);
          expect(campaigns.playerProjectionCalls, 1);
        },
      );

      test(
        'si la campaña desaparece, el vínculo no rompe la respuesta',
        () async {
          final (player, dm) = await table('campana-borrada');

          await send('DELETE', '/api/campaigns/tumba', token: dm);

          expect(await campaignsOf(player), isEmpty);
        },
      );

      // El id de la campaña y el del DM no viajan: el jugador no tiene ninguna
      // ruta que los tome, y mandarlos solo serviría para tantear qué existe
      // del otro lado.
      test('no viaja el id de la campaña ni el del DM', () async {
        final (player, _) = await table('sin-ids');

        final block =
            (await campaignsOf(player)).single as Map<String, dynamic>;
        expect(block['campaign'].containsKey('id'), isFalse);
        expect(block.containsKey('dmUserId'), isFalse);
        expect(block['memberId'], isNotEmpty);
      });

      test('un personaje sin vínculos devuelve la lista vacía', () async {
        final token = await login('sin-campanas');
        await send(
          'POST',
          '/api/characters',
          token: token,
          body: {'character': characterJson('sagan')},
        );

        expect(await campaignsOf(token), isEmpty);
      });

      // Preguntar por un personaje ajeno tiene que ser indistinguible de
      // preguntar por uno que no existe.
      test('preguntar por un personaje ajeno responde 404', () async {
        final (_, dm) = await table('ajeno');

        final response = await send(
          'GET',
          '/api/characters/sagan/campaigns',
          token: dm,
        );
        expect(response['status'], 404);
      });
    });

    group('combate', () {
      Map<String, dynamic> playerCombatant(
        String id, {
        required String memberId,
        int initiative = 10,
      }) => {
        'id': id,
        'kind': 'player',
        'name': 'PJ',
        'initiative': initiative,
        'memberId': memberId,
      };

      Map<String, dynamic> monsterCombatant(
        String id, {
        int initiative = 5,
        int currentHp = 7,
        int maxHp = 7,
        String name = 'Goblin',
      }) => {
        'id': id,
        'kind': 'monster',
        'name': name,
        'initiative': initiative,
        'creatureId': 'goblin',
        'currentHp': currentHp,
        'maxHp': maxHp,
      };

      Map<String, dynamic> encounterJson({
        String id = 'e1',
        int round = 1,
        int turnIndex = 0,
        required List<Map<String, dynamic>> combatants,
      }) => {
        'schemaVersion': 1,
        'id': id,
        'round': round,
        'turnIndex': turnIndex,
        'combatants': combatants,
      };

      test('sin sesión ninguna operación responde 401', () async {
        for (final request in [
          Request(
            'GET',
            Uri.parse('http://localhost/api/campaigns/c1/encounter'),
          ),
          Request(
            'PUT',
            Uri.parse('http://localhost/api/campaigns/c1/encounter'),
            body: jsonEncode({'encounter': encounterJson(combatants: [])}),
          ),
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/campaigns/c1/encounter'),
          ),
          Request('GET', Uri.parse('http://localhost/api/characters/x/turn')),
        ]) {
          expect(
            (await handler(request)).statusCode,
            401,
            reason: '${request.url}',
          );
        }
      });

      test('guardar y releer un encuentro', () async {
        final token = await login('enc-roundtrip');
        await createCampaign(token, 'tumba');

        final saved = await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': encounterJson(combatants: [monsterCombatant('m1')]),
          },
        );
        expect(saved['status'], 200);

        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(read['status'], 200);
        expect(read['body']['encounter']['combatants'], hasLength(1));
      });

      test('sin combate abierto, la lectura responde 404', () async {
        final token = await login('enc-none');
        await createCampaign(token, 'tumba');

        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(read['status'], 404);
        expect(read['body']['error'], 'No hay ningún combate en curso.');
      });

      test('un DM ajeno recibe 404 al leer y al guardar', () async {
        final tokenA = await login('enc-owner');
        await createCampaign(tokenA, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenA,
          body: {'encounter': encounterJson(combatants: [])},
        );

        final tokenB = await login('enc-intruder');
        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: tokenB,
        );
        expect(read['status'], 404);

        final write = await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenB,
          body: {'encounter': encounterJson(combatants: [])},
        );
        expect(write['status'], 404);
      });

      test(
        'cerrar el combate borra el encuentro y deja el log grabado',
        () async {
          final token = await login('enc-close');
          await createCampaign(token, 'tumba');
          await send(
            'PUT',
            '/api/campaigns/tumba/encounter',
            token: token,
            body: {
              'encounter': encounterJson(
                round: 3,
                combatants: [
                  playerCombatant(
                    'p1',
                    memberId: '00000000-0000-4000-8000-000000000000',
                  ),
                  monsterCombatant('m1', currentHp: 0),
                ],
              ),
            },
          );

          final closed = await send(
            'DELETE',
            '/api/campaigns/tumba/encounter',
            token: token,
          );
          expect(closed['status'], 200);

          final afterClose = await send(
            'GET',
            '/api/campaigns/tumba/encounter',
            token: token,
          );
          expect(afterClose['status'], 404);

          expect(encounters.logs, hasLength(1));
          expect(encounters.logs.single.document['rounds'], 3);
          expect(encounters.logs.single.document['monsters'], hasLength(1));
          expect(encounters.logs.single.document['monsters'][0]['defeated'], 1);
        },
      );

      // Un combate abierto por error no tiene por qué quedar en el registro
      // de la campaña como si se hubiera jugado.
      test('descartar el combate no deja log', () async {
        final token = await login('enc-discard');
        await createCampaign(token, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': encounterJson(combatants: [monsterCombatant('m1')]),
          },
        );

        final discarded = await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=true',
          token: token,
        );
        expect(discarded['status'], 200);

        final afterDiscard = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(afterDiscard['status'], 404);
        expect(encounters.logs, isEmpty);
      });

      // Perder lo jugado tiene que ser una decisión explícita: un parámetro
      // mal escrito archiva, no descarta.
      test('un "discard" que no es exactamente true archiva igual', () async {
        final token = await login('enc-discard-typo');
        await createCampaign(token, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {
            'encounter': encounterJson(combatants: [monsterCombatant('m1')]),
          },
        );

        await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=si',
          token: token,
        );

        expect(encounters.logs, hasLength(1));
      });

      test('un DM ajeno no puede descartar el combate de otro', () async {
        final tokenA = await login('enc-discard-owner');
        await createCampaign(tokenA, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenA,
          body: {'encounter': encounterJson(combatants: [])},
        );

        final tokenB = await login('enc-discard-intruder');
        final response = await send(
          'DELETE',
          '/api/campaigns/tumba/encounter?discard=true',
          token: tokenB,
        );
        expect(response['status'], 404);

        // Y el combate del dueño sigue en pie.
        final stillThere = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: tokenA,
        );
        expect(stillThere['status'], 200);
      });

      test('cerrar sin combate abierto no hace nada', () async {
        final token = await login('enc-close-empty');
        await createCampaign(token, 'tumba');

        final closed = await send(
          'DELETE',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(closed['status'], 200);
        expect(encounters.logs, isEmpty);
      });

      group('aviso de fin de combate', () {
        // Una mesa con dos personajes; en el combate solo pelea el primero.
        Future<({String dm, String fighter, String bystander})> table(
          String prefix,
        ) async {
          final dm = await login('$prefix-dm');
          await createCampaign(dm, 'tumba');
          final fighter = await login('$prefix-a');
          final bystander = await login('$prefix-b');
          final ids = <String>[];
          for (final (token, character) in [
            (fighter, 'sagan'),
            (bystander, 'elsbeth'),
          ]) {
            final redeemed = await send(
              'POST',
              '/api/campaigns/tumba/members',
              token: dm,
              body: {'code': await shareCharacter(token, character)},
            );
            ids.add(redeemed['body']['member']['memberId'] as String);
          }
          await send(
            'PUT',
            '/api/campaigns/tumba/encounter',
            token: dm,
            body: {
              'encounter': encounterJson(
                combatants: [
                  playerCombatant('p1', memberId: ids.first),
                  monsterCombatant('m1'),
                ],
              ),
            },
          );
          return (dm: dm, fighter: fighter, bystander: bystander);
        }

        Future<List<dynamic>> finished(String token) async {
          final response = await send('GET', '/api/events', token: token);
          return [
            for (final e in response['body']['events'] as List<dynamic>)
              if (e['kind'] == 'encounter_finished') e,
          ];
        }

        test(
          'avisa solo a quienes pelearon, y el aviso no trae el combate',
          () async {
            final mesa = await table('enc-ev');
            await send(
              'DELETE',
              '/api/campaigns/tumba/encounter',
              token: mesa.dm,
            );

            final events = await finished(mesa.fighter);
            expect(events, hasLength(1));
            // Solo quién y dónde: lo que pasó en el combate es del DM.
            expect(events.single['payload'], {
              'characterName': 'Sagan',
              'campaignName': 'La Tumba',
            });
            expect(await finished(mesa.bystander), isEmpty);
            expect(await finished(mesa.dm), isEmpty);
          },
        );

        test('descartar el combate no avisa a nadie', () async {
          final mesa = await table('enc-ev-discard');
          await send(
            'DELETE',
            '/api/campaigns/tumba/encounter?discard=true',
            token: mesa.dm,
          );

          expect(await finished(mesa.fighter), isEmpty);
        });
      });

      test('borrar la campaña deja el combate inaccesible', () async {
        final token = await login('enc-cascade');
        await createCampaign(token, 'tumba');
        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: token,
          body: {'encounter': encounterJson(combatants: [])},
        );

        await send('DELETE', '/api/campaigns/tumba', token: token);

        final read = await send(
          'GET',
          '/api/campaigns/tumba/encounter',
          token: token,
        );
        expect(read['status'], 404);
      });

      test('el jugador vinculado obtiene su turno correcto', () async {
        final tokenA = await login('turn-a');
        final code = await shareCharacter(tokenA, 'sagan');

        final tokenB = await login('turn-b');
        await createCampaign(tokenB, 'tumba');
        final redeemed = await send(
          'POST',
          '/api/campaigns/tumba/members',
          token: tokenB,
          body: {'code': code},
        );
        final memberId = redeemed['body']['member']['memberId'] as String;

        await send(
          'PUT',
          '/api/campaigns/tumba/encounter',
          token: tokenB,
          body: {
            'encounter': encounterJson(
              combatants: [
                playerCombatant('p1', memberId: memberId, initiative: 20),
                monsterCombatant('m1', initiative: 10),
              ],
            ),
          },
        );

        final turn = await send(
          'GET',
          '/api/characters/sagan/turn',
          token: tokenA,
        );
        expect(turn['body']['turn'], 'active');
      });

      test('un jugador sin vínculo obtiene "none", no un error', () async {
        final token = await login('turn-none');
        await send(
          'POST',
          '/api/characters',
          token: token,
          body: {'character': characterJson('sagan')},
        );

        final turn = await send(
          'GET',
          '/api/characters/sagan/turn',
          token: token,
        );
        expect(turn['status'], 200);
        expect(turn['body']['turn'], 'none');
      });

      test(
        'un jugador no puede preguntar por el turno de un personaje ajeno',
        () async {
          final tokenA = await login('turn-owner');
          await send(
            'POST',
            '/api/characters',
            token: tokenA,
            body: {'character': characterJson('sagan')},
          );

          final tokenB = await login('turn-intruder');
          final turn = await send(
            'GET',
            '/api/characters/sagan/turn',
            token: tokenB,
          );
          expect(turn['status'], 404);
        },
      );
    });
  });
}

/// Arma un respaldo mínimo válido (un personaje, sin retratos) para probar el
/// enrutado de `/api/import` sin depender de `BackupBundleCodec`, que no se
/// expone fuera de `dnd_server` (la prueba vive del lado de la API, no del
/// codec, que ya tiene su propia batería en `import/backup_bundle_test.dart`).
Uint8List _validZipBytes() {
  final archive = Archive();
  archive.add(
    ArchiveFile.string(
      'characters/sagan.json',
      jsonEncode({
        'id': 'sagan',
        'name': 'Sagan',
        'raceId': 'human',
        'classId': 'fighter',
        'backgroundId': 'soldier',
        'assignedScores': <String, dynamic>{},
      }),
    ),
  );
  archive.add(
    ArchiveFile.string(
      'manifest.json',
      jsonEncode({
        'type': 'dnd_bundle',
        'formatVersion': 2,
        'scope': 'character',
        'characters': [
          {'id': 'sagan', 'file': 'characters/sagan.json', 'portraits': []},
        ],
      }),
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}

String _extractToken(String setCookieHeader) =>
    RegExp(r'dnd_session=([^;]+)').firstMatch(setCookieHeader)!.group(1)!;

/// Recorre el callback con la identidad que el doble tenga configurada y
/// devuelve el token de la cookie resultante.
Future<String> _login(Handler handler) async {
  final callback = await handler(
    Request(
      'GET',
      Uri.parse('http://localhost/auth/callback?code=abc&state=xyz'),
    ),
  );
  return _extractToken(callback.headers['set-cookie']!);
}
