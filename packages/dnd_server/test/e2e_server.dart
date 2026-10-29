/// Servidor para la prueba de humo del cliente React (Playwright, en
/// `packages/dnd_web/e2e/`): el `buildHandler` real, con los repositorios en
/// memoria de `test/fakes/` y una sesión ya abierta.
///
///     DND_WEB_V2_ROOT=../dnd_web/dist DND_SERVER_PORT=8787 \
///       dart run test/e2e_server.dart
///
/// Vive en `test/` y no en `bin/` porque enchufa dobles de prueba, y no se
/// llama `*_test.dart` para que `dart test` no lo arranque. Así CI lo formatea
/// y lo analiza igual que el resto, y el Dockerfile no lo ve (`.dockerignore`).
///
/// La sesión falsa evita el login OIDC, que necesita Zitadel; lo que se prueba
/// es el camino cookie → `/api/me` → `/v2`, no el proveedor de identidad.
library;

import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/ai/portrait_generation_service.dart';
import 'package:dnd_server/src/app.dart';
import 'package:dnd_server/src/auth/session_store.dart';
import 'package:dnd_server/src/import/import_service.dart';
import 'package:dnd_server/src/web/web_v2.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

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

/// Cookie que el test de Playwright instala en el navegador, y el nombre que
/// la sesión falsa muestra. Si cambian, cambian en `e2e/ficha.spec.ts`.
const smokeSessionToken = 'sesion-de-humo=';
const smokeAccountName = 'Ada de Humo';

/// Cuenta de la sesión falsa, y el personaje que tiene sembrado (lo abre
/// `e2e/ficha.spec.ts`). Los PG actuales no son los máximos a propósito: así
/// la prueba distingue «PG actuales» de «PG máximos».
const smokeUserId = 'cuenta-de-humo';
const smokeCharacterId = 'guerrero-de-humo';

Future<void> main() async {
  final root = Platform.environment['DND_WEB_V2_ROOT'] ?? '';
  final port = int.parse(Platform.environment['DND_SERVER_PORT'] ?? '8787');
  final v2 = root.isEmpty ? null : buildWebV2Handler(root);
  if (v2 == null) {
    stderr.writeln(
      'DND_WEB_V2_ROOT="$root" no existe: hace falta `npm run build`.',
    );
    exit(1);
  }

  final auth = FakeAuthDependencies();
  auth.sessionsByToken[smokeSessionToken] = smokeUserId;
  auth.profilesByToken[smokeSessionToken] = const SessionProfile(
    name: smokeAccountName,
    email: 'humo@example.org',
  );

  final characters = InMemoryCharacterRepository();
  await characters.create(
    smokeUserId,
    Character(
      id: smokeCharacterId,
      name: 'Brunilda de Humo',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      level: 5,
      assignedScores: const {
        Ability.strength: 15,
        Ability.dexterity: 13,
        Ability.constitution: 14,
        Ability.intelligence: 12,
        Ability.wisdom: 16,
        Ability.charisma: 10,
      },
      backgroundAbilityBonuses: const {
        Ability.strength: 2,
        Ability.constitution: 1,
      },
      chosenSkills: const ['perception', 'survival', 'insight'],
      featureChoices: const {
        'fighting-style': ['fs-defense'],
      },
      weaponMasteryChoices: const ['longsword', 'greatsword', 'dagger'],
      hpPerLevel: const [10, 6, 6, 6, 6],
      equippedArmorId: 'chain-mail',
      shieldEquipped: true,
      equippedWeaponIds: const ['longsword'],
      combat: CombatState(currentHp: 31),
    ),
  );
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

  final handler = buildHandler(
    auth: auth.dependencies,
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
    webV2Handler: v2,
    v2Users: {smokeUserId},
  );

  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    port,
  );
  // Playwright espera esta línea en la salida para saber que ya se puede abrir.
  print('e2e_server escuchando en ${server.address.host}:${server.port}');
}
