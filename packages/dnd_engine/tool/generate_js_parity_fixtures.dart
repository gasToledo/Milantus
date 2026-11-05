/// Genera los casos de la prueba de paridad Dart ↔ JS del motor
/// (`packages/dnd_web/scripts/engine-parity.mjs`):
///
///     dart run tool/generate_js_parity_fixtures.dart <directorio de salida>
///
/// Escribe `catalog.json`, un `<caso>.json` por personaje, con la ficha de
/// entrada y la salida de Dart (`ComputedSheet.toJson()`), y un
/// `accion-<caso>.json` por acción de partida, con la acción, la semilla y lo
/// que devuelve `SheetActions.apply`. Las fichas se arman
/// acá con el constructor y no a mano en JSON: así siguen válidas cuando el
/// modelo cambia, y la salida esperada la produce el propio motor.
///
/// Para que la entrada sea la que ve JS, el esperado se calcula sobre la ficha
/// ya pasada por `toJson` → `fromJson`, que es el camino real (API → cliente).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';

const _scores = {
  Ability.strength: 15,
  Ability.dexterity: 13,
  Ability.constitution: 14,
  Ability.intelligence: 12,
  Ability.wisdom: 16,
  Ability.charisma: 10,
};

/// Cada caso apunta a un tramo distinto del motor; ver el comentario de cada
/// uno. Más casos no aportan paridad, solo tiempo de CI.
final _casos = <String, Character>{
  // Lanzador de lista preparada, con arma y oro.
  'clerigo': Character(
    id: 'p-cleric',
    name: 'Clérigo',
    raceId: 'human',
    classId: 'cleric',
    backgroundId: 'hermit',
    level: 3,
    assignedScores: _scores,
    hpPerLevel: const [8, 5, 5],
    featureChoices: const {
      'divine-order': ['divine-order-thaumaturge'],
    },
    cantripIds: const ['guidance', 'sacred-flame'],
    spellIds: const ['bless', 'cure-wounds'],
    inventory: const [
      InventoryEntry(entryId: 'maza', itemId: 'mace', equipped: true),
    ],
    coins: const {'gp': 250},
  ),
  // Marcial con armadura, maestría de arma y estilo de combate.
  'guerrero': Character(
    id: 'p-fighter',
    name: 'Guerrero',
    raceId: 'human',
    classId: 'fighter',
    backgroundId: 'soldier',
    level: 5,
    assignedScores: _scores,
    // Dos entradas para que el reorden del Diario tenga algo que mover.
    diary: [
      DiaryEntry(
        entryId: 'diario-a',
        title: 'Primera',
        body: 'texto',
        createdAt: DateTime.utc(2026, 3, 12),
      ),
      DiaryEntry(
        entryId: 'diario-b',
        kind: DiaryEntryKind.link,
        title: 'Segunda',
        body: 'https://example.org',
        createdAt: DateTime.utc(2026, 3, 20),
      ),
    ],
    // Dos retratos, el segundo con su prompt, para el alta y la baja.
    portraitPaths: const ['retrato-a', 'retrato-b'],
    portraitPrompts: const {'retrato-b': 'prompt de b'},
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
    // Cansado: `compute` aplica el Cansancio sobre la ficha calculada.
    combat: CombatState(currentHp: 40, exhaustion: 2),
  ),
  // Multiclase: bloques de lanzamiento propios y espacios combinados.
  'multiclase': Character(
    id: 'p-multi',
    name: 'Multiclase',
    raceId: 'human',
    classId: 'fighter',
    backgroundId: 'soldier',
    classHistory: const ['fighter', 'fighter', 'fighter', 'wizard', 'wizard'],
    assignedScores: _scores,
    hpPerLevel: const [10, 6, 6, 5, 5],
    cantripIds: const ['fire-bolt'],
    spellIds: const ['magic-missile', 'shield'],
  ),
  // Forma Salvaje: el pozo de formas viene del catálogo de criaturas.
  'druida': Character(
    id: 'p-druid',
    name: 'Druida',
    raceId: 'human',
    classId: 'druid',
    backgroundId: 'sage',
    level: 8,
    assignedScores: _scores,
    hpPerLevel: List.filled(8, 5),
    wildShapeForms: const ['wolf'],
  ),
  // Transformado en lobo: `compute` aplica la forma antes del Cansancio.
  'druida-transformado': Character(
    id: 'p-druid-wolf',
    name: 'Druida transformado',
    raceId: 'human',
    classId: 'druid',
    backgroundId: 'sage',
    level: 8,
    assignedScores: _scores,
    hpPerLevel: List.filled(8, 5),
    wildShapeForms: const ['wolf'],
    combat: CombatState(currentHp: 20, wildShapeCreatureId: 'wolf'),
  ),
  // Arma de pacto: dos ejemplares que creó el rasgo y uno vinculado, para que
  // vincular el otro, crear y soltar tengan algo que desplazar.
  'brujo-filo': Character(
    id: 'p-blade',
    name: 'Brujo del Filo',
    raceId: 'human',
    classId: 'warlock',
    backgroundId: 'sage',
    level: 1,
    assignedScores: _scores,
    featureChoices: const {
      'warlock-invocation': ['pact-of-the-blade'],
    },
    hpPerLevel: const [8],
    inventory: const [
      InventoryEntry(
        entryId: 'estoque',
        itemId: 'rapier',
        origin: 'effect-target:pact-weapon',
        equipped: true,
      ),
      InventoryEntry(
        entryId: 'daga',
        itemId: 'dagger',
        origin: 'effect-target:pact-weapon',
      ),
    ],
    effectTargets: const {
      'pact-weapon': ['estoque'],
    },
  ),
  // Artífice de nivel 14: tres planos elegidos y una réplica de uno, para que
  // marcar, quitar, replicar y transmutar tengan algo que cambiar.
  'artifice': Character(
    id: 'p-artificer',
    name: 'Artífice',
    raceId: 'human',
    classId: 'artificer',
    backgroundId: 'sage',
    level: 14,
    assignedScores: _scores,
    hpPerLevel: List.filled(14, 6),
    magicItemChoices: const [
      'bolsa-de-contencion',
      'manifold-tool',
      'escudo-1'
    ],
    inventory: const [
      InventoryEntry(
        entryId: 'replica-bolsa',
        itemId: 'bolsa-de-contencion',
        origin: 'artificer:replicate-magic-item:bolsa-de-contencion',
      ),
    ],
  ),
  // Estado activable (Furia) con arma a dos manos y desventaja de lanzar.
  'barbaro': Character(
    id: 'p-barbarian',
    name: 'Bárbaro',
    raceId: 'orc',
    classId: 'barbarian',
    subclassId: 'berserker',
    backgroundId: 'soldier',
    level: 5,
    assignedScores: _scores,
    hpPerLevel: List.filled(5, 7),
    inventory: const [
      InventoryEntry(entryId: 'hacha', itemId: 'greataxe', equipped: true),
    ],
  ),
  // Furia activa de la Senda del Fanático: un daño extra de dos tipos
  // (`necrotic|radiant`) cuyo «o» resuelve `Attack.damageText`, y las ventajas
  // ya filtradas por tirada.
  'barbaro-fanatico': Character(
    id: 'p-zealot',
    name: 'Bárbaro Fanático',
    raceId: 'orc',
    classId: 'barbarian',
    subclassId: 'zealot',
    backgroundId: 'soldier',
    level: 5,
    assignedScores: _scores,
    hpPerLevel: List.filled(5, 7),
    inventory: const [
      InventoryEntry(entryId: 'hacha', itemId: 'greataxe', equipped: true),
    ],
    combat: CombatState(currentHp: 30, activeModes: {'rage': null}),
  ),
  // Pacto, invocaciones y un linaje con lanzamiento de especie.
  'brujo': Character(
    id: 'p-warlock',
    name: 'Brujo',
    raceId: 'gnome',
    lineageId: 'gnome-forest',
    speciesSpellcastingAbility: Ability.charisma,
    classId: 'warlock',
    subclassId: 'fiend-patron',
    backgroundId: 'sage',
    level: 5,
    assignedScores: const {
      Ability.strength: 8,
      Ability.dexterity: 14,
      Ability.constitution: 13,
      Ability.intelligence: 12,
      Ability.wisdom: 10,
      Ability.charisma: 16,
    },
    hpPerLevel: const [8, 5, 5, 5, 5],
    cantripIds: const ['eldritch-blast', 'mage-hand'],
    spellIds: const ['hex', 'sleep'],
  ),
  // Artífice con espacios y un Sirviente Homúnculo en juego: invocar paga un
  // espacio, despedir lo saca de la lista y `companionsView` lo lee.
  'invocador': Character(
    id: 'p-summoner',
    name: 'Invocador',
    raceId: 'human',
    classId: 'artificer',
    backgroundId: 'sage',
    level: 11,
    assignedScores: _scores,
    hpPerLevel: List.filled(11, 6),
    spellIds: const ['homunculus-servant'],
  ),
  // Truco innato reemplazable (`setInnateCantrip`, `innateCantripOptions`).
  'altoelfo': Character(
    id: 'p-high-elf',
    name: 'Alto Elfo',
    raceId: 'elf',
    lineageId: 'elf-high',
    speciesSpellcastingAbility: Ability.intelligence,
    classId: 'wizard',
    backgroundId: 'sage',
    level: 3,
    assignedScores: _scores,
    hpPerLevel: const [6, 4, 4],
  ),
};

/// Acciones de partida (`SheetActions`, `act` en JS) sobre los mismos
/// personajes, con un estado de combate gastado para que cada una tenga algo
/// que cambiar. La semilla fija las tiradas: el dado de golpe y la recarga al
/// amanecer. Una por rama del motor que toca algo distinto del documento.
final _acciones = <String, (String, Map<String, dynamic>)>{
  'accion-dano': ('clerigo', {'type': 'damage', 'amount': 7}),
  'accion-espacio-pacto': (
    'brujo',
    {'type': 'spendSlot', 'level': 3, 'pact': true},
  ),
  'accion-recurso': ('barbaro', {'type': 'spendResource', 'resource': 'rage'}),
  'accion-dado-de-golpe': ('guerrero', {'type': 'spendHitDie'}),
  'accion-condicion': (
    'barbaro',
    {'type': 'setCondition', 'condition': 'stunned', 'value': true},
  ),
  'accion-cansancio': ('guerrero', {'type': 'setExhaustion', 'value': 6}),
  'accion-modo': ('barbaro', {'type': 'activateMode', 'mode': 'rage'}),
  'accion-modo-fin': ('barbaro', {'type': 'deactivateMode', 'mode': 'rage'}),
  'accion-descanso-corto': ('brujo', {'type': 'shortRest'}),
  'accion-descanso-largo': ('druida', {'type': 'longRest'}),
  'accion-entrar-forma': (
    'druida',
    {'type': 'enterWildShape', 'creature': 'wolf'}
  ),
  'accion-volver-forma': ('druida', {'type': 'leaveWildShape'}),
  'accion-anotar-forma': (
    'druida',
    {'type': 'setWildShapeForm', 'creature': 'panther', 'value': true},
  ),
  'accion-elegir-rasgo': (
    'brujo',
    {
      'type': 'setFeatureChoice',
      'group': 'warlock-invocation',
      'id': 'armor-of-shadows',
      'value': true,
    },
  ),
  'accion-diario-guardar': (
    'guerrero',
    {
      'type': 'saveDiaryEntry',
      'entry': 'diario-a',
      'kind': 'text',
      'title': ' Primera, editada ',
      'body': 'otro texto',
      'imageKey': null,
      'at': '2026-04-02T10:00:00.000Z',
    },
  ),
  'accion-diario-mover': (
    'guerrero',
    {'type': 'moveDiaryEntry', 'entry': 'diario-a', 'to': 'diario-b'},
  ),
  'accion-retrato-agregar': (
    'guerrero',
    {'type': 'addPortrait', 'key': 'retrato-c', 'prompt': 'prompt de c'},
  ),
  'accion-retrato-borrar': (
    'guerrero',
    {'type': 'removePortrait', 'key': 'retrato-b'},
  ),
  'accion-linaje': (
    'brujo',
    {'type': 'setLineage', 'lineage': 'gnome-rock'},
  ),
  'accion-conjuros': (
    'multiclase',
    {
      'type': 'setClassSpells',
      'classId': 'wizard',
      'cantrips': ['fire-bolt'],
      'spells': ['shield'],
    },
  ),
  'accion-pacto-vincular': (
    'brujo-filo',
    {'type': 'setEffectTarget', 'group': 'pact-weapon', 'entry': 'daga'},
  ),
  'accion-pacto-crear': (
    'brujo-filo',
    {'type': 'createEffectTarget', 'group': 'pact-weapon', 'weapon': 'mace'},
  ),
  'accion-pacto-soltar': (
    'brujo-filo',
    {'type': 'clearEffectTargets', 'group': 'pact-weapon'},
  ),
  'accion-plan-marcar': (
    'artifice',
    {'type': 'setMagicItemPlan', 'item': 'cuerda-de-escalada', 'value': true},
  ),
  'accion-plan-quitar': (
    'artifice',
    {'type': 'setMagicItemPlan', 'item': 'bolsa-de-contencion', 'value': false},
  ),
  'accion-replica': (
    'artifice',
    {'type': 'replicateItem', 'item': 'escudo-1', 'base': 'shield'},
  ),
  'accion-agregar-con-base': (
    'artifice',
    {'type': 'addItem', 'item': 'arma-de-advertencia', 'base': 'longsword'},
  ),
  'accion-transmutar': (
    'artifice',
    {
      'type': 'transmuteReplica',
      'entry': 'replica-bolsa',
      'item': 'manifold-tool',
    },
  ),
  'accion-invocar': (
    'invocador',
    {
      'type': 'summonCompanion',
      'option': 'homunculus-servant',
      'creature': 'homunculus-servant',
      'level': 3,
      'pact': false,
    },
  ),
  'accion-despedir': (
    'invocador',
    {'type': 'dismissCompanion', 'index': 0},
  ),
  'accion-truco-innato': (
    'altoelfo',
    {
      'type': 'setInnateCantrip',
      'granted': 'prestidigitation',
      'spell': 'fire-bolt'
    },
  ),
};

/// El creador de personajes (`creation` en JS): un borrador a medio armar y
/// una acción. Uno por cosa que cambia la vista: la clase con sus cupos, la
/// tirada de 4d6 (con la semilla) y el trasfondo con la dote que pide aptitud.
const _borradorElfo = {
  'raceId': 'elf',
  'lineageId': 'elf-high',
  'speciesSpellcastingAbility': 'intelligence',
};
final _creaciones = <String, (Map<String, dynamic>, Map<String, dynamic>)>{
  'creacion-guerrero': (
    {..._borradorElfo, 'classId': 'fighter'},
    {'type': 'toggle', 'pick': 'weaponMastery', 'id': 'longsword'},
  ),
  'creacion-tirada': (
    {..._borradorElfo, 'classId': 'wizard'},
    {'type': 'applyScoreMethod', 'method': 'roll4d6'},
  ),
  'creacion-trasfondo': (
    {..._borradorElfo, 'classId': 'wizard'},
    {'type': 'selectBackground', 'id': 'sage'},
  ),
};

const _semilla = 7;

CombatState _gastado(String caso) => CombatState(
      currentHp: 3,
      tempHp: 2,
      hitDiceUsed: const {8: 1},
      exhaustion: 1,
      resourceUsage: const {'wild_shape': 1},
      spellSlotsUsed: const {1: 1},
      pactSlotsUsed: const {3: 1},
      companions: caso == 'invocador'
          ? [
              CompanionInstance(
                optionId: 'homunculus-servant',
                creatureId: 'homunculus-servant',
                spellLevel: 2,
                currentHp: 5,
              ),
            ]
          : null,
    );

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Uso: dart run tool/generate_js_parity_fixtures.dart <dir>');
    exit(64);
  }
  final out = Directory(args.single)..createSync(recursive: true);
  const srd = 'lib/assets/srd_2024';

  Future<List<dynamic>> leer(String archivo) async =>
      jsonDecode(await File('$srd/$archivo').readAsString()) as List;

  // Mismo armado que `loadContentRepositoryFromDirectory`: los objetos mágicos
  // entran dentro de `items`.
  final catalog = {
    for (final k in [
      'races',
      'classes',
      'subclasses',
      'lineages',
      'backgrounds',
      'feats',
      'weapons',
      'armor',
      'spells',
      'creatures',
    ])
      k: await leer('$k.json'),
    'items': [
      ...await leer('items.json'),
      ...await leer('magic_items.json'),
      ...await leer('efa_magic_items.json'),
    ],
  };
  File('${out.path}/catalog.json').writeAsStringSync(jsonEncode(catalog));

  final repo = await ContentRepository.loadFromDirectory(srd);
  for (final MapEntry(key: nombre, value: personaje) in _casos.entries) {
    final entrada = jsonDecode(jsonEncode(personaje.toJson()));
    final ficha = Character.fromJson(entrada as Map<String, dynamic>);
    final esperado = applyExhaustion(
      withWildShape(CharacterCompiler(repo).compile(ficha), ficha, repo),
      ficha.combat.exhaustion,
    ).toJson();
    File('${out.path}/$nombre.json').writeAsStringSync(
      jsonEncode({'character': entrada, 'expected': esperado}),
    );
  }
  for (final MapEntry(key: nombre, value: (caso, accion))
      in _acciones.entries) {
    final entrada = jsonDecode(
      jsonEncode(_casos[caso]!.copyWith(combat: _gastado(caso)).toJson()),
    );
    final ficha = Character.fromJson(entrada as Map<String, dynamic>);
    final esperado = SheetActions.apply(
      ficha,
      repo,
      accion,
      dice: Dice(Random(_semilla)),
    ).toJson();
    File('${out.path}/$nombre.json').writeAsStringSync(
      jsonEncode({
        'character': entrada,
        'action': accion,
        'seed': _semilla,
        'expected': esperado,
      }),
    );
  }
  // Las dos funciones de lectura del editor de conjuros de la ficha
  // (`spellEdit`, `innateCantripOptions`): el JSON que devuelve el puente.
  final multiclase = Character.fromJson(
    jsonDecode(jsonEncode(_casos['multiclase']!.toJson()))
        as Map<String, dynamic>,
  );
  final altoElfo = Character.fromJson(
    jsonDecode(jsonEncode(_casos['altoelfo']!.toJson()))
        as Map<String, dynamic>,
  );
  final hojaMulti = CharacterCompiler(repo).compile(multiclase);
  final bloque = hojaMulti.spellcastingBlocks.firstWhere(
    (b) => b.classId == 'wizard',
  );
  final o = LevelUp.classSpells(
    multiclase,
    hojaMulti,
    repo,
    bloque.spellcasting,
    classId: 'wizard',
  );
  final innato = CharacterCompiler(repo)
      .compile(altoElfo)
      .innateSpells
      .firstWhere((s) => s.isReplaceable);
  void puente(
    String nombre,
    Character ficha,
    String fn,
    String arg,
    Object? esperado,
  ) =>
      File('${out.path}/$nombre.json').writeAsStringSync(
        jsonEncode({
          'character': jsonDecode(jsonEncode(ficha.toJson())),
          'bridge': {
            'fn': fn,
            'args': [arg]
          },
          'expected': esperado,
        }),
      );
  puente(
    'puente-conjuros',
    multiclase,
    'spellEdit',
    'wizard',
    // La forma de `_classSpellsMap` del puente, escrita otra vez a propósito:
    // la paridad es justamente que el JS compilado dé lo mismo.
    {
      'cantripsKnown': bloque.spellcasting.cantripsKnown,
      'preparedCount': bloque.spellcasting.preparedCount,
      'prepared': bloque.spellcasting.preparation == SpellPreparation.prepared,
      'cantrips': [
        for (final sp in o.cantrips) {'id': sp.id, 'name': sp.name},
      ],
      'spells': [
        for (final sp in o.spells)
          {'id': sp.id, 'name': sp.name, 'level': sp.level},
      ],
      'chosenCantrips': o.chosenCantrips,
      'chosenSpells': o.chosenSpells,
      'grantedCantrips': o.grantedCantrips,
      'grantedSpells': o.grantedSpells,
    },
  );
  puente(
    'puente-truco-innato',
    altoElfo,
    'innateCantripOptions',
    innato.grantedSpellId,
    [
      for (final s in LevelUp.innateCantripOptions(repo, innato))
        {'id': s.id, 'name': s.name, 'school': s.school},
    ],
  );
  // Los planos del Artífice: la forma del puente escrita otra vez a propósito.
  final artifice = Character.fromJson(
    jsonDecode(jsonEncode(_casos['artifice']!.toJson()))
        as Map<String, dynamic>,
  );
  final cupoPlanos =
      CharacterCompiler(repo).compile(artifice).itemChoiceSlots.single;
  final opciones = [
    for (final id in cupoPlanos.optionItemIds) repo.item(id)!,
  ]..sort((a, b) => compareContentNames(a.name, b.name));
  void puenteSinFicha(String nombre, String fn, String arg, Object? esperado) =>
      File('${out.path}/$nombre.json').writeAsStringSync(
        jsonEncode({
          'bridge': {
            'fn': fn,
            'args': [arg],
            'withoutCharacter': true,
          },
          'expected': esperado,
        }),
      );
  puente(
    'puente-planos',
    artifice,
    'magicItemPlans',
    '',
    {
      'groupId': cupoPlanos.groupId,
      'name': cupoPlanos.name,
      'count': cupoPlanos.count,
      'maxActive': cupoPlanos.maxActive,
      'options': [
        for (final i in opciones)
          {
            'id': i.id,
            'name': i.name,
            'rarity': i.rarity,
            'requiresAttunement': i.requiresAttunement,
            'baseItemKind': i.baseItemKind,
          },
      ],
      'chosen': [
        for (final id in artifice.magicItemChoices)
          {'id': id, 'name': repo.item(id)!.name},
      ],
      'replicas': [
        {
          'itemId': 'bolsa-de-contencion',
          'entryId': 'replica-bolsa',
          'name': repo.item('bolsa-de-contencion')!.name,
          'baseName': null,
        },
      ],
    },
  );
  // Los compañeros: la salida del motor tal cual. Que la forma sea la que
  // escribe `companion_view.dart` ya lo prueba `companion_test.dart`; acá
  // solo importa que el JS compilado dé lo mismo.
  final invocador = Character.fromJson(
    jsonDecode(
      jsonEncode(_casos['invocador']!
          .copyWith(combat: _gastado('invocador'))
          .toJson()),
    ) as Map<String, dynamic>,
  );
  void puenteCon(
          String nombre, String fn, List<Object> args, Object? esperado) =>
      File('${out.path}/$nombre.json').writeAsStringSync(
        jsonEncode({
          'character': jsonDecode(jsonEncode(invocador.toJson())),
          'bridge': {'fn': fn, 'args': args},
          'expected': esperado,
        }),
      );
  puenteCon(
    'puente-companeros',
    'companionsView',
    const [],
    companionsView(invocador, repo),
  );
  // El prompt es texto, no JSON: `text` le dice al verificador que no lo parsee.
  File('${out.path}/puente-retrato-prompt.json').writeAsStringSync(
    jsonEncode({
      'character': jsonDecode(jsonEncode(invocador.toJson())),
      'bridge': {
        'fn': 'portraitPrompt',
        'args': ['Acuarela', 'pelo blanco', false],
        'text': true,
      },
      'expected': buildPortraitPrompt(
        character: invocador,
        repo: repo,
        style: 'Acuarela',
        extraText: 'pelo blanco',
        includeWeapon: false,
      ),
    }),
  );
  puenteCon(
    'puente-elecciones',
    'choicesView',
    const [],
    choicesView(invocador, repo),
  );
  puenteCon(
    'puente-companero-vista-previa',
    'companionPreview',
    const ['homunculus-servant', 'homunculus-servant', 3],
    companionPreview(
      invocador,
      repo,
      'homunculus-servant',
      'homunculus-servant',
      3,
    ),
  );
  puenteSinFicha(
    'puente-bases',
    'magicBaseOptions',
    'escudo-1',
    [
      for (final a in repo.armorSorted.where((e) => e.isShield))
        {'id': a.id, 'name': a.name},
    ],
  );
  final baseDeBloque = repo.creaturesSorted.first;
  File('${out.path}/puente-pnj-nuevo.json').writeAsStringSync(
    jsonEncode({
      'bridge': {
        'fn': 'newNpc',
        'args': ['Bruna', 'block', baseDeBloque.id],
        'withoutCharacter': true,
      },
      'expected': Npc.draft(
        name: 'Bruna',
        kind: NpcSheetKind.block,
        base: baseDeBloque,
      ).toJson(),
    }),
  );
  final notaAccion = {
    'type': 'saveNote',
    'entry': 'nota-1',
    'kind': 'text',
    'title': '  Le debe al gremio ',
    'body': ' Doscientas piezas. ',
    'imageKey': null,
    'at': '2026-11-04T12:00:00.000Z',
  };
  final pnjBase = Npc(id: 'pnj', name: 'Bruna', sheetKind: NpcSheetKind.none);
  File('${out.path}/puente-pnj-edicion.json').writeAsStringSync(
    jsonEncode({
      'bridge': {
        'fn': 'npcEdit',
        'args': [jsonEncode(pnjBase.toJson()), jsonEncode(notaAccion)],
        'pure': true,
      },
      'expected': NpcEdits.apply(pnjBase, notaAccion).toJson(),
    }),
  );
  final accionRetrato = {
    'type': 'addPortrait',
    'key': 'pnj/a.png',
    'prompt': 'una tabernera',
  };
  File('${out.path}/puente-pnj-retrato.json').writeAsStringSync(
    jsonEncode({
      'bridge': {
        'fn': 'npcEdit',
        'args': [jsonEncode(pnjBase.toJson()), jsonEncode(accionRetrato)],
        'pure': true,
      },
      'expected': NpcEdits.apply(pnjBase, accionRetrato).toJson(),
    }),
  );
  // El prompt de un PNJ sin ficha: texto, y el «character» del caso es el PNJ
  // (el verificador le pasa primero ese JSON y después el catálogo).
  final pnjConBloqueRetrato = Npc(
    id: 'pnj',
    name: 'Bruna',
    sheetKind: NpcSheetKind.block,
    block: repo.creaturesSorted.first,
    baseCreatureId: repo.creaturesSorted.first.id,
  );
  File('${out.path}/puente-pnj-retrato-prompt.json').writeAsStringSync(
    jsonEncode({
      'character': jsonDecode(jsonEncode(pnjConBloqueRetrato.toJson())),
      'bridge': {
        'fn': 'npcPortraitPrompt',
        'args': ['Acuarela', 'cicatriz en la ceja'],
        'text': true,
      },
      'expected': buildNpcPortraitPrompt(
        npc: pnjConBloqueRetrato,
        repo: repo,
        style: 'Acuarela',
        extraText: 'cicatriz en la ceja',
      ),
    }),
  );
  // El bloque de un PNJ y el borrador de una criatura: el reemplazo del bloque
  // y la cuenta del formulario (línea compuesta, errores) tienen que dar lo
  // mismo en la VM y en el JS compilado.
  final pnjConBloque = Npc(
    id: 'pnj',
    name: 'Bruna',
    sheetKind: NpcSheetKind.block,
    block: Npc.emptyBlock('Bruna'),
  );
  final bloqueNuevo = repo.creaturesSorted.first.toJson();
  final accionBloque = {'type': 'setBlock', 'block': bloqueNuevo};
  File('${out.path}/puente-pnj-bloque.json').writeAsStringSync(
    jsonEncode({
      'bridge': {
        'fn': 'npcEdit',
        'args': [jsonEncode(pnjConBloque.toJson()), jsonEncode(accionBloque)],
        'pure': true,
      },
      'expected': NpcEdits.apply(pnjConBloque, accionBloque).toJson(),
    }),
  );
  final criaturaBase = Npc.emptyBlock('Rurik');
  final formulario = CreatureDraft.formOf(criaturaBase)
    ..['ac'] = '14'
    ..['cr'] = '1/4'
    ..['hitDice'] = 'x';
  final armada = CreatureDraft.build(criaturaBase, formulario);
  File('${out.path}/puente-criatura-borrador.json').writeAsStringSync(
    jsonEncode({
      'bridge': {
        'fn': 'creatureDraft',
        'args': [jsonEncode(criaturaBase.toJson()), jsonEncode(formulario)],
        'pure': true,
      },
      'expected': {
        'creature': armada.toJson(),
        'row': {
          'id': armada.id,
          'kind': armada.displayKind,
          'type': armada.creatureType?.id,
          'typeLabel': armada.creatureType?.label,
          'cr': armada.cr,
          'crText': armada.challengeRatingText,
          'initiative': armada.initiativeModifier,
          'passivePerception': armada.passivePerceptionValue,
          'meleeReach': [for (final a in armada.actions) a.isMeleeReach],
        },
        'errors': CreatureDraft.errors(formulario),
      },
    }),
  );
  for (final MapEntry(key: nombre, value: (borrador, accion))
      in _creaciones.entries) {
    final draft = CreationDraft.fromJson(repo, borrador)
      ..apply(accion, dice: Dice(Random(_semilla)));
    File('${out.path}/$nombre.json').writeAsStringSync(
      jsonEncode({
        'creation': {'draft': borrador, 'action': accion},
        'seed': _semilla,
        'expected': draft.viewJson(),
      }),
    );
  }
  print(
    '${_casos.length + _acciones.length + _creaciones.length} casos en '
    '${out.path}',
  );
}
