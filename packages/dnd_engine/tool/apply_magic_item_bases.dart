// Escribe `baseItemKind` en los objetos genéricos «Arma +N» y «Armadura +N»
// de `lib/assets/srd_2024/magic_items.json`.
//
//     dart tool/apply_magic_item_bases.dart
//
// Parchea, no genera: va después de `generate_magic_items.py` y de
// `apply_magic_item_kinds.dart`, y antes de `apply_voseo.dart`. Es
// idempotente.
//
// Existe porque la descripción de esos seis dice «Arma (cualquiera sencilla o
// marcial)» o «Armadura (ligera, media o pesada)» pero el generador no la
// traduce a `baseItemKind`: sin él una réplica de «Arma +1» no tiene datos de
// arma. Lo verifica `magic_items_2024_test`, que falla si alguien regenera el
// catálogo y se olvida de este paso.

import 'dart:convert';
import 'dart:io';

/// Prefijo del id → tipo de base. Solo los genéricos con número: el resto de
/// los objetos con base ya la declara el generador.
const _bases = {'arma-': 'weapon', 'armadura-': 'armor'};

void main() {
  final file = File(
    '${_repoRoot()}/packages/dnd_engine/lib/assets/srd_2024/magic_items.json',
  );
  final data = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  for (var i = 0; i < data.length; i++) {
    final id = data[i]['id'] as String;
    final kind = _bases.entries
        .where((e) => RegExp('^${e.key}[123]\$').hasMatch(id))
        .map((e) => e.value)
        .firstOrNull;
    if (kind == null) continue;
    // `baseItemKind` va entre `requiresAttunement` y `sourcePage`, como en
    // los demás objetos: se reconstruye el mapa para respetar el orden.
    final nuevo = <String, dynamic>{};
    for (final e in data[i].entries) {
      if (e.key == 'baseItemKind') continue;
      if (e.key == 'sourcePage') nuevo['baseItemKind'] = kind;
      nuevo[e.key] = e.value;
    }
    data[i] = nuevo;
  }
  file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n');
}

String _repoRoot() =>
    Directory.fromUri(Platform.script.resolve('../../..')).path;
