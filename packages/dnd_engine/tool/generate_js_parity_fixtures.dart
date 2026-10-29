/// Genera los casos de la prueba de paridad Dart ↔ JS del motor
/// (`packages/dnd_web/scripts/engine-parity.mjs`):
///
///     dart run tool/generate_js_parity_fixtures.dart <directorio de salida>
///
/// Escribe `catalog.json` y un `<caso>.json` por personaje, con la ficha de
/// entrada y la salida de Dart (`ComputedSheet.toJson()`). Las fichas se arman
/// acá con el constructor y no a mano en JSON: así siguen válidas cuando el
/// modelo cambia, y la salida esperada la produce el propio motor.
///
/// Para que la entrada sea la que ve JS, el esperado se calcula sobre la ficha
/// ya pasada por `toJson` → `fromJson`, que es el camino real (API → cliente).
library;

import 'dart:convert';
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
};

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
    final esperado = CharacterCompiler(repo).compile(ficha).toJson();
    File('${out.path}/$nombre.json').writeAsStringSync(
      jsonEncode({'character': entrada, 'expected': esperado}),
    );
  }
  print('${_casos.length} casos en ${out.path}');
}
