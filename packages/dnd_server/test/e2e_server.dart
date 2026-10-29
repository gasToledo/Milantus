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
import 'package:image/image.dart' as img;
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

/// Una dote homebrew de la cuenta (`e2e/homebrew.spec.ts`).
const smokeHomebrewFeatId = 'paso-de-humo';

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

  // Un retrato de Elsbeth, para los medallones de /v2: su ficha lo pide con
  // la clave, y el DM de su mesa por el vínculo (`e2e/dm.spec.ts`).
  final portraits = InMemoryPortraitBlobStore();
  final elsbethPortrait = await portraits.save(
    userId: smokeUserId,
    characterId: smokeClericId,
    bytes: img.encodePng(img.Image(width: 8, height: 8)),
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
      portraitPaths: [elsbethPortrait],
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
  final elsbethLink = await campaigns.redeemShareCode(
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
  final saganLink = await campaigns.redeemShareCode(
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
  // Un combate que no cuelga de ningún capítulo, con un PNJ aliado de nombre
  // propio: el Cuaderno del DM lo nombra, la vista del jugador no
  // (`e2e/dm.spec.ts`).
  encounters.logs.add((
    dmUserId: _smokeDmId,
    campaignId: _smokeCampaignId,
    document: const EncounterLog(
      id: 'emboscada',
      rounds: 2,
      players: ['Elsbeth de Humo'],
      monsters: [
        EncounterLogMonsters(name: 'Bandido', count: 2, defeated: 1),
        EncounterLogMonsters(
          name: 'Garrick el Tabernero',
          side: CombatantSide.ally,
          npc: true,
          publicName: 'Bandido',
          creatureId: 'bandit',
        ),
      ],
    ).toJson(),
  ));
  // El combate abierto de la mesa (`e2e/combate.spec.ts`), en la ronda 3 y
  // con el turno en el primer lobo: un jugador ya actuó, Garrick (PNJ aliado)
  // volvió herido y el segundo lobo está caído, así que el turno lo salta. Su
  // efecto es un texto que el jugador no debe recibir: el documento del
  // combate nunca le llega, solo su estado de turno.
  await encounters.save(
    _smokeDmId,
    _smokeCampaignId,
    Encounter(
      id: 'emboscada-del-valle',
      round: 3,
      turnIndex: 1,
      stage: EncounterStage.running,
      combatants: [
        Combatant(
          id: 'c-elsbeth',
          kind: CombatantKind.player,
          name: 'Elsbeth de Humo',
          initiative: 19,
          memberId: elsbethLink!.memberId,
        ),
        const Combatant(
          id: 'c-lobo-1',
          kind: CombatantKind.monster,
          name: 'Lobo 1',
          initiative: 16,
          creatureId: 'wolf',
          currentHp: 5,
          maxHp: 11,
          tags: ['Marca reservada del DM'],
        ),
        const Combatant(
          id: 'c-garrick',
          kind: CombatantKind.npc,
          name: 'Garrick el Tabernero',
          initiative: 14,
          npcId: 'garrick',
          currentHp: 7,
          maxHp: 11,
          side: CombatantSide.ally,
        ),
        Combatant(
          id: 'c-sagan',
          kind: CombatantKind.player,
          name: 'Sagan de Humo',
          initiative: 12,
          memberId: saganLink!.memberId,
        ),
        const Combatant(
          id: 'c-lobo-2',
          kind: CombatantKind.monster,
          name: 'Lobo 2',
          initiative: 9,
          creatureId: 'wolf',
          maxHp: 11,
        ),
      ],
    ),
  );
  final events = InMemoryEventRepository();
  final npcs = InMemoryNpcRepository(campaigns, characters);
  await _seedNpcs(npcs, characters);
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
  // Una dote propia, para que el Homebrew del Modo DM (`e2e/homebrew.spec.ts`)
  // tenga lo propio en más de una categoría del Códice.
  await homebrew.upsert(
    smokeUserId,
    'feats',
    smokeHomebrewFeatId,
    const Feat(
      id: smokeHomebrewFeatId,
      name: 'Paso de Humo',
      source: ContentSource.homebrew,
      description: 'Te movés entre la niebla sin que nadie te oiga.',
    ).toJson(),
  );
  final levelUps = InMemoryLevelUpRepository(campaigns);
  // Lo que el servidor anota cuando el jugador sube de nivel con el capítulo
  // en marcha.
  await levelUps.append(
    _smokeDmId,
    _smokeCampaignId,
    chapterId: 'capitulo-en-marcha',
    characterName: 'Elsbeth de Humo',
    level: 3,
    classId: 'cleric',
    classLevel: 3,
  );

  final handler = buildHandler(
    auth: auth.dependencies,
    portraits: portraits,
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

/// La biblioteca de PNJ del DM (`e2e/pnj.spec.ts`): uno de cada tipo. Garrick
/// tiene bloque (copiado del bandido del SRD, así su línea dice la criatura de
/// base por el catálogo), está en la mesa sembrada y volvió herido de un
/// combate; Vesna tiene ficha de personaje, y en la mesa no se sabe si sigue
/// viva; Odile no tiene estadísticas ni campaña. Su voz, su trasfondo y sus
/// notas son textos que ninguna otra cuenta debe recibir.
Future<void> _seedNpcs(
  InMemoryNpcRepository npcs,
  InMemoryCharacterRepository characters,
) async {
  await npcs.insert(
    _smokeDmId,
    Npc(
      id: 'garrick',
      name: 'Garrick el Tabernero',
      sheetKind: NpcSheetKind.block,
      block: const Creature(
        id: 'bandit',
        name: 'Bandido',
        source: ContentSource.homebrew,
        ac: '12',
        hp: '11',
        cr: 0.125,
        actions: [
          CreatureAction(name: 'Cimitarra', attackBonus: '3', damage: '1d6+1'),
        ],
      ),
      baseCreatureId: 'bandit',
      baseCreatureName: 'Bandido',
      speech: 'Voz reservada del DM: nunca termina una frase.',
      background: 'Trasfondo reservado del DM: **sirvió en la guardia**.',
      tags: const ['Waterdeep', 'Aliados'],
      notes: const [
        DiaryEntry(
          entryId: 'deuda',
          title: 'Le debe al gremio',
          body: 'Nota reservada del PNJ: doscientas piezas de oro.',
        ),
      ],
    ),
  );
  final sheet = await characters.createNpcSheet(
    _smokeDmId,
    Character(
      id: 'vesna-ficha',
      name: 'Vesna la Cuervo',
      raceId: 'elf',
      classId: 'wizard',
      backgroundId: 'sage',
      level: 3,
      assignedScores: const {
        Ability.strength: 8,
        Ability.dexterity: 14,
        Ability.constitution: 13,
        Ability.intelligence: 15,
        Ability.wisdom: 12,
        Ability.charisma: 10,
      },
      hpPerLevel: const [6, 4, 4],
    ),
  );
  await npcs.insert(
    _smokeDmId,
    Npc(
      id: 'vesna',
      name: 'Vesna la Cuervo',
      sheetKind: NpcSheetKind.character,
      characterId: sheet.id,
      tags: const ['Enemigos'],
    ),
  );
  await npcs.insert(
    _smokeDmId,
    Npc(
      id: 'odile',
      name: 'La hermana Odile',
      sheetKind: NpcSheetKind.none,
      tags: const ['Gremio'],
    ),
  );
  await npcs.link(_smokeDmId, _smokeCampaignId, 'garrick');
  await npcs.saveHp(_smokeDmId, _smokeCampaignId, {'garrick': 7});
  await npcs.link(
    _smokeDmId,
    _smokeCampaignId,
    'vesna',
    status: NpcStatus.unknown,
  );
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
