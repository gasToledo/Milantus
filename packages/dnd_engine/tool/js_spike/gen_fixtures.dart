// Genera los personajes de ejemplo y la salida de referencia de la VM de Dart:
//   dart run tool/js_spike/gen_fixtures.dart build/js_spike/fixtures
import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';

import 'sheet_summary.dart';

Map<Ability, int> _scores(List<int> v) => {
      for (var i = 0; i < 6; i++) Ability.values[i]: v[i],
    };

Future<void> main(List<String> args) async {
  final out = Directory(args.single)..createSync(recursive: true);
  const dir = 'lib/assets/srd_2024';
  final repo = await ContentRepository.loadFromDirectory(dir);
  final compiler = CharacterCompiler(repo);

  final fighter5 = Character(
    id: 'f5',
    name: 'Sagan',
    raceId: 'human',
    classId: 'fighter',
    backgroundId: 'soldier',
    level: 5,
    assignedScores: _scores([15, 13, 14, 10, 12, 8]),
    backgroundAbilityBonuses: {Ability.strength: 2, Ability.constitution: 1},
    chosenSkills: ['perception', 'survival', 'insight'],
    featureChoices: const {
      'fighting-style': ['fs-defense']
    },
    weaponMasteryChoices: ['longsword', 'greatsword', 'dagger'],
    featIds: ['skilled'],
    hpPerLevel: [10, 6, 6, 6, 6],
    equippedArmorId: 'leather',
    equippedWeaponIds: ['longsword'],
  );
  final wizard3 = Character(
    id: 'w3',
    name: 'Mirta',
    raceId: 'human',
    classId: 'wizard',
    backgroundId: 'soldier',
    level: 3,
    assignedScores: _scores([8, 14, 14, 15, 12, 10]),
    hpPerLevel: [6, 4, 4],
  );
  final multi7 = Character(
    id: 'm7',
    name: 'Multi',
    raceId: 'human',
    classId: 'fighter',
    backgroundId: 'soldier',
    level: 7,
    classHistory: const [
      'fighter',
      'fighter',
      'fighter',
      'fighter',
      'fighter',
      'wizard',
      'wizard',
    ],
    assignedScores: _scores([15, 13, 14, 12, 10, 8]),
    hpPerLevel: [10, 6, 6, 6, 6, 5, 5],
    equippedArmorId: 'leather',
  );

  for (final c in [fighter5, wizard3, multi7]) {
    final json = c.toJson();
    File('${out.path}/${c.id}.character.json')
        .writeAsStringSync(jsonEncode(json));
    File('${out.path}/${c.id}.expected.json').writeAsStringSync(
      jsonEncode(summarizeSheet(compiler.compile(Character.fromJson(json)))),
    );
  }
  // Fixture v1 versionado: referencia de migración.
  final v1 = File('test/fixtures/character_v1.json').readAsStringSync();
  File('${out.path}/v1.character.json').writeAsStringSync(v1);
  File('${out.path}/v1.migrated.json').writeAsStringSync(
    jsonEncode(Character.migrateJson(
      (jsonDecode(v1) as Map).cast<String, dynamic>(),
    )),
  );
}
