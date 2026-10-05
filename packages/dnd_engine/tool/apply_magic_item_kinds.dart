// Escribe `magicItemType`, `cursed` y `variableRarity` en los dos catálogos
// mágicos de `lib/assets/srd_2024/`, leyendo la descripción en español.
//
//     dart tool/apply_magic_item_kinds.dart
//
// Parchea, no genera: va después de `extract_magic_item_text.dart`, que es el
// que escribe la descripción, y antes de `apply_voseo.dart` (no la lee
// después, pero así el orden queda uno solo para todos los parches). Es
// idempotente.
//
// Existe porque los planos del Artífice dependen de esos tres datos y antes
// se deducían de la descripción al compilar. La descripción se traduce por
// superposición, así que deducirlos del inglés habría cambiado qué puede
// replicar el Artífice según el idioma. Lo verifica
// `content_integrity_test`, que además falla si alguien regenera el catálogo
// y se olvida de este paso.

import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';

void main() {
  for (final archivo in ['magic_items.json', 'efa_magic_items.json']) {
    final file = File(
      '${_repoRoot()}/packages/dnd_engine/lib/assets/srd_2024/$archivo',
    );
    final data = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    for (final item in data) {
      final traits = Item.magicTraitsFrom(item['description'] as String? ?? '');
      // Los tres siempre, aunque sean nulos o falsos: un objeto que declara
      // alguno no se lee más de la descripción (ver `Item.fromJson`).
      item['magicItemType'] = traits.type;
      item['cursed'] = traits.cursed;
      item['variableRarity'] = traits.variableRarity;
    }
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
  }
}

String _repoRoot() =>
    Directory.fromUri(Platform.script.resolve('../../..')).path;
