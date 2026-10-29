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
/// la sesión falsa muestra. Si cambian, cambian en `e2e/helpers.ts`.
const smokeSessionToken = 'sesion-de-humo=';
const smokeAccountName = 'Ada de Humo';

/// Cuenta de la sesión falsa, y el personaje que tiene sembrado (lo abre
/// `e2e/ficha.spec.ts`). Los PG actuales no son los máximos a propósito: así
/// la prueba distingue «PG actuales» de «PG máximos».
const smokeUserId = 'cuenta-de-humo';
const smokeCharacterId = 'guerrero-de-humo';

/// La favorita de los ajustes sembrados, y el orden que esos ajustes piden.
const smokeFavoriteId = 'zelda-de-humo';

/// El clérigo sembrado, con trucos y conjuros preparados.
const smokeClericId = 'elsbeth-de-humo';

/// La cuenta del DM de la mesa sembrada, y su campaña. Está en `v2Users`: el
/// Modo DM de /v2 (`e2e/dm.spec.ts`) es de las cuentas con `webV2`.
const _smokeDmId = 'dm-de-humo';
const smokeDmToken = 'sesion-del-dm=';
const _smokeCampaignId = 'marca-del-cuervo';

/// La cuenta del segundo jugador de esa mesa. No tiene sesión: solo es dueña
/// de una ficha vinculada.
const _smokeSecondPlayerId = 'segundo-jugador-de-humo';

/// Un arma homebrew de la cuenta, que Aldric lleva equipada: la ficha de /v2
/// tiene que fusionar `/api/homebrew` con el catálogo oficial para que su
/// ataque aparezca (`e2e/ficha.spec.ts`).
const smokeHomebrewWeaponId = 'hacha-de-humo';

/// Una criatura homebrew de la cuenta, para el Bestiario
/// (`e2e/bestiario.spec.ts`). Trae iniciativa propia (+6, con DES 16 sería
/// +3) para distinguir lo que deriva el motor de una cuenta hecha en el cliente.
const smokeHomebrewCreatureId = 'sombra-de-humo';

/// Una segunda sesión, de una cuenta que **no** está en `v2Users`: /v2 le
/// responde «No disponible» sin pedir nada más a la API.
const smokeNoV2Token = 'sesion-sin-v2=';
const smokeNoV2UserId = 'cuenta-sin-v2';

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
  // El DM de la mesa sembrada: la prueba de aislamiento lo usa para pedir la
  // ficha de otra cuenta y comprobar que responde 404.
  auth.sessionsByToken[smokeDmToken] = _smokeDmId;
  auth.profilesByToken[smokeDmToken] = const SessionProfile(
    name: 'DM de Humo',
    email: 'dm@example.org',
  );
  auth.sessionsByToken[smokeNoV2Token] = smokeNoV2UserId;
  auth.profilesByToken[smokeNoV2Token] = const SessionProfile(
    name: 'Sin Humo',
    email: 'sin-v2@example.org',
  );

  final characters = InMemoryCharacterRepository();
  await characters.create(
    smokeUserId,
    _smokeFighter(
      id: smokeCharacterId,
      name: 'Brunilda de Humo',
      hpPerLevel: const [10, 6, 6, 6, 6],
      currentHp: 31,
    ),
  );
  // Para el dashboard (`e2e/dashboard.spec.ts`): el mismo guerrero a otros
  // niveles. Por nombre irían Aldric, Brunilda, Zelda; por nivel, Brunilda,
  // Zelda, Aldric: con el orden «nivel» y a Zelda de favorita, la prueba
  // distingue el orden de los ajustes del alfabético y el favorito del resto.
  await characters.create(
    smokeUserId,
    _smokeFighter(
      id: smokeFavoriteId,
      name: 'Zelda de Humo',
      hpPerLevel: const [10, 6, 6, 6],
      currentHp: 9,
    ),
  );
  await characters.create(
    smokeUserId,
    _smokeFighter(
      id: 'aldric-de-humo',
      name: 'Aldric de Humo',
      hpPerLevel: const [10, 6],
      currentHp: 16,
      weapons: const ['longsword', smokeHomebrewWeaponId],
    ),
  );
  // Un lanzador, para que la ficha muestre la tarjeta de Conjuros
  // (`e2e/ficha.spec.ts`). Nivel 3: en el dashboard queda entre Brunilda (5)
  // y Aldric (2) con el orden «nivel».
  await characters.create(
    smokeUserId,
    Character(
      id: smokeClericId,
      name: 'Elsbeth de Humo',
      raceId: 'human',
      classId: 'cleric',
      subclassId: 'life-domain',
      backgroundId: 'sage',
      level: 3,
      assignedScores: const {
        Ability.strength: 14,
        Ability.dexterity: 8,
        Ability.constitution: 13,
        Ability.intelligence: 11,
        Ability.wisdom: 15,
        Ability.charisma: 12,
      },
      backgroundAbilityBonuses: const {
        Ability.wisdom: 2,
        Ability.intelligence: 1,
      },
      chosenSkills: const ['medicine', 'religion'],
      hpPerLevel: const [8, 5, 5],
      cantripIds: const ['guidance', 'sacred-flame', 'light'],
      spellIds: const ['bless', 'cure-wounds', 'shield-of-faith'],
      combat: CombatState(currentHp: 18),
      // Para las pestañas Inventario y Diario (`e2e/ficha.spec.ts`): un arma
      // equipada, una armadura que no, un objeto mágico sintonizado con
      // cargas, munición y equipo, para que haya varias familias.
      coins: const {'gp': 37, 'sp': 12, 'cp': 40},
      inventory: const [
        InventoryEntry(entryId: 'e-maza', itemId: 'mace', equipped: true),
        InventoryEntry(entryId: 'e-ballesta', itemId: 'light-crossbow'),
        InventoryEntry(entryId: 'e-virotes', itemId: 'bolts', quantity: 20),
        InventoryEntry(
          entryId: 'e-cota',
          itemId: 'scale-mail',
          note: 'Se la quita para nadar.',
        ),
        InventoryEntry(entryId: 'e-kit', itemId: 'healers-kit'),
        InventoryEntry(entryId: 'e-raciones', itemId: 'rations', quantity: 5),
        InventoryEntry(
          entryId: 'e-anillo',
          itemId: 'anillo-de-evasion',
          equipped: true,
          attuned: true,
          charges: 2,
        ),
      ],
      background:
          'Elsbeth creció copiando manuscritos en la biblioteca del templo.\n\n'
          'Cree que la biblioteca **no se quemó por accidente**.',
      diary: const [
        DiaryEntry(
          entryId: 'd-oraculo',
          title: 'Lo que dijo el oráculo',
          body: 'El cuervo no guarda caminos: los borra.',
        ),
        DiaryEntry(
          entryId: 'd-mapa',
          kind: DiaryEntryKind.link,
          title: 'Mapa de la Marca',
          body: 'https://example.org/marca',
        ),
      ],
    ),
  );
  final settings = InMemorySettingsRepository();
  await settings.save(smokeUserId, {
    'sortMode': 'level',
    'favoriteCharacterId': smokeFavoriteId,
    'characterOrder': <String>[],
  });
  final campaigns = InMemoryCampaignRepository(characters);
  final chapters = InMemoryChapterRepository(campaigns);
  final notes = InMemoryNoteRepository(campaigns, chapters);
  final encounters = InMemoryEncounterRepository(campaigns);
  campaigns
    ..playerChaptersFor = chapters.listFor
    ..playerBattlesFor = encounters.logsFor;

  // Una mesa para la pestaña Campaña: el jugador comparte a Elsbeth, otra
  // cuenta (el DM) la suma, cierra un capítulo que reparte oro y un objeto, y
  // deja una batalla registrada en ese capítulo. Por los mismos repositorios
  // que usan las rutas, así el vínculo existe como en producción.
  final code = await campaigns.createShareCode(
    ownerUserId: smokeUserId,
    characterId: smokeClericId,
  );
  await campaigns.create(
    _smokeDmId,
    const Campaign(
      id: _smokeCampaignId,
      name: 'La Marca del Cuervo',
      premise:
          'Un cuervo de piedra aparece en cada pueblo que el invierno vacía.',
      // Cosas del DM que el jugador no ve (`e2e/campanas.spec.ts` busca estos
      // textos en la API y en la pantalla): escenas de música, un capítulo en
      // marcha con su resumen y una nota.
      musicScenes: [
        MusicScene(
          id: 'escena-secreta',
          name: 'Tema secreto del DM',
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
      ],
    ),
  );
  await campaigns.redeemShareCode(
    dmUserId: _smokeDmId,
    campaignId: _smokeCampaignId,
    code: code!,
  );
  // Un segundo jugador, de **otra cuenta**, con estados que salen en su
  // tarjeta como pills: la Mesa del DM (`e2e/dm.spec.ts`) lista a los dos. Es
  // otra cuenta a propósito: así la lista de campañas de la cuenta de humo
  // (`e2e/campanas.spec.ts`) sigue teniendo una sola mesa.
  await characters.create(
    _smokeSecondPlayerId,
    _smokeFighter(
      id: 'sagan-de-humo',
      name: 'Sagan de Humo',
      hpPerLevel: const [10, 6, 6],
      currentHp: 12,
      conditions: const {'poisoned'},
      exhaustion: 2,
    ),
  );
  final fighterCode = await campaigns.createShareCode(
    ownerUserId: _smokeSecondPlayerId,
    characterId: 'sagan-de-humo',
  );
  await campaigns.redeemShareCode(
    dmUserId: _smokeDmId,
    campaignId: _smokeCampaignId,
    code: fighterCode!,
  );
  await chapters.create(
    _smokeDmId,
    _smokeCampaignId,
    const Chapter(
      id: 'paso-de-varn',
      name: 'El paso de Varn',
      state: ChapterState.completed,
      grantsGold: 25,
      grantsItems: ['una poción de curación'],
    ),
  );
  await chapters.create(
    _smokeDmId,
    _smokeCampaignId,
    const Chapter(
      id: 'capitulo-en-marcha',
      name: 'El Valle Hueco',
      summary: 'Resumen reservado del DM: el cuervo es el rey.',
      state: ChapterState.active,
    ),
  );
  // Uno que todavía no empezó, sin objetivo: la lista del DM lo muestra
  // pendiente y el jugador no lo recibe (`e2e/dm.spec.ts`).
  await chapters.create(
    _smokeDmId,
    _smokeCampaignId,
    const Chapter(id: 'concilio-de-brasas', name: 'El Concilio de Brasas'),
  );
  await notes.create(
    _smokeDmId,
    _smokeCampaignId,
    const Note(
      id: 'nota-del-dm',
      chapterId: 'capitulo-en-marcha',
      title: 'Nota privada',
      body: 'Nota reservada del DM: el herrero traiciona al grupo.',
    ),
  );
  encounters.logs.add((
    dmUserId: _smokeDmId,
    campaignId: _smokeCampaignId,
    document: {
      ...const EncounterLog(
        id: 'lobos',
        rounds: 4,
        players: ['Elsbeth de Humo', 'Thalion'],
        monsters: [EncounterLogMonsters(name: 'Lobo', count: 3, defeated: 3)],
      ).toJson(),
      'chapterId': 'paso-de-varn',
    },
  ));
  final events = InMemoryEventRepository();
  final npcs = InMemoryNpcRepository(campaigns, characters);
  final homebrew = InMemoryHomebrewRepository();
  await homebrew.upsert(
    smokeUserId,
    'weapons',
    smokeHomebrewWeaponId,
    const Weapon(
      id: smokeHomebrewWeaponId,
      name: 'Hacha de Humo',
      source: ContentSource.homebrew,
      category: 'martial',
      damageDice: '1d10',
      damageType: 'slashing',
      properties: ['heavy'],
    ).toJson(),
  );
  await homebrew.upsert(
    smokeUserId,
    'creatures',
    smokeHomebrewCreatureId,
    const Creature(
      id: smokeHomebrewCreatureId,
      name: 'Sombra de Humo',
      source: ContentSource.homebrew,
      kind: 'Muerto viviente Mediano',
      type: CreatureType.undead,
      size: CreatureSize.medium,
      ac: '13',
      hp: '22',
      hitDice: '5d8',
      speed: '40 pies',
      abilityScores: {
        Ability.strength: 6,
        Ability.dexterity: 16,
        Ability.constitution: 10,
        Ability.intelligence: 8,
        Ability.wisdom: 12,
        Ability.charisma: 14,
      },
      initiativeBonus: 6,
      cr: 1,
      traits: [
        CreatureTrait(name: 'Paso sin huella', description: 'No deja rastro.'),
      ],
      actions: [
        CreatureAction(
          name: 'Roce helado',
          attackBonus: '5',
          damage: '2d6+3',
          damageType: 'cold',
          reach: '5 pies',
        ),
      ],
    ).toJson(),
  );
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
    settings: settings,
    webV2Handler: v2,
    // El DM también: el Modo DM de /v2 es de las cuentas con `webV2`.
    v2Users: {smokeUserId, _smokeDmId},
  );

  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    port,
  );
  // Playwright espera esta línea en la salida para saber que ya se puede abrir.
  print('e2e_server escuchando en ${server.address.host}:${server.port}');
}

/// Un guerrero completo: el nivel sale de cuántos PG por nivel se le dan.
/// Los PG actuales no son los máximos a propósito, así la prueba distingue
/// «PG actuales» de «PG máximos».
Character _smokeFighter({
  required String id,
  required String name,
  required List<int> hpPerLevel,
  required int currentHp,
  List<String> weapons = const ['longsword'],
  Set<String> conditions = const {},
  int exhaustion = 0,
}) => Character(
  id: id,
  name: name,
  raceId: 'human',
  classId: 'fighter',
  backgroundId: 'soldier',
  level: hpPerLevel.length,
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
  hpPerLevel: hpPerLevel,
  equippedArmorId: 'chain-mail',
  shieldEquipped: true,
  equippedWeaponIds: weapons,
  combat: CombatState(
    currentHp: currentHp,
    conditions: {...conditions},
    exhaustion: exhaustion,
  ),
);
