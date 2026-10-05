import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;

/// Carga el catálogo oficial en un idioma: `en`, o null para el español.
typedef ContentLoader = Future<ContentRepository> Function(String? translation);

const _base = 'packages/dnd_engine/assets/srd_2024';

const _packs = [
  'races',
  'classes',
  'subclasses',
  'lineages',
  'backgrounds',
  'feats',
  'weapons',
  'armor',
  'items',
  'magic_items',
  'efa_magic_items',
  'spells',
  'creatures',
];

/// Carga el pack SRD 2024 empaquetado como asset.
///
/// Los archivos se piden todos juntos y no de a uno: en producción cada
/// pedido cruza Cloudflare y el túnel hasta el servidor, y en serie eran
/// catorce viajes de ida y vuelta sumados antes de ver la biblioteca.
/// `Future.wait` y no un `await` suelto por archivo: si uno falla mientras se
/// espera a otro, su error quedaría sin nadie que lo atienda.
///
/// Con [translation] (`en`) suma encima la superposición `X.en.json` de cada
/// catálogo que la tenga empaquetada. Sin ella no se pide ninguna: quien usa
/// la app en español no descarga nada más. Cuáles existen lo dice el
/// manifiesto de assets y no una lista propia, que se desfasaría del
/// `pubspec.yaml` en cuanto se traduzca un catálogo más.
///
/// [read] existe para que los tests vean qué se pide; por defecto es el
/// bundle de la app, que además cachea: volver a cargar al cambiar de idioma
/// no repite la descarga del español.
Future<ContentRepository> loadOfficialContent({
  String? translation,
  AssetBundle? bundle,
}) async {
  final assets = bundle ?? rootBundle;
  final translated = translation == null
      ? const <String>{}
      : (await AssetManifest.loadFromAssetBundle(assets)).listAssets().toSet();
  String? overlayOf(String name) {
    final path = '$_base/$name.$translation.json';
    return translated.contains(path) ? path : null;
  }

  final raw = await Future.wait([
    for (final name in ['manifest', ..._packs])
      assets.loadString('$_base/$name.json'),
  ]);
  final overlays = await Future.wait([
    for (final name in _packs)
      if (overlayOf(name) case final path?)
        assets.loadString(path)
      else
        Future.value('{}'),
  ]);
  ContentPackManifest.fromJson(
    (jsonDecode(raw.first) as Map).cast<String, dynamic>(),
  );
  final pack = {
    for (final (i, name) in _packs.indexed)
      name: applyContentTranslation(
        (jsonDecode(raw[i + 1]) as List).cast<Map<String, dynamic>>(),
        (jsonDecode(overlays[i]) as Map).cast<String, dynamic>(),
      ),
  };
  return ContentRepository.fromJsonPacks(
    races: pack['races']!,
    classes: pack['classes']!,
    subclasses: pack['subclasses']!,
    lineages: pack['lineages']!,
    backgrounds: pack['backgrounds']!,
    feats: pack['feats']!,
    weapons: pack['weapons']!,
    armor: pack['armor']!,
    items: [
      ...pack['items']!,
      ...pack['magic_items']!,
      ...pack['efa_magic_items']!,
    ],
    spells: pack['spells']!,
    creatures: pack['creatures']!,
  );
}
