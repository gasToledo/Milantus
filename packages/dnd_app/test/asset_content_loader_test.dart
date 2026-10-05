import 'dart:convert';

import 'package:dnd_app/data/asset_content_loader.dart';
import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// El bundle real, que anota qué se pide y puede sumar archivos que no están
/// empaquetados (una superposición de prueba), también al manifiesto.
class _BundleQueAnota extends CachingAssetBundle {
  final Map<String, String> extra;
  final pedidos = <String>[];
  _BundleQueAnota([this.extra = const {}]);

  @override
  Future<ByteData> load(String key) async {
    pedidos.add(key);
    if (key == 'AssetManifest.bin' && extra.isNotEmpty) {
      final manifiesto =
          const StandardMessageCodec().decodeMessage(await rootBundle.load(key))
              as Map<Object?, Object?>;
      return const StandardMessageCodec().encodeMessage({
        ...manifiesto,
        for (final path in extra.keys) path: <Object?>[],
      })!;
    }
    final texto = extra[key];
    if (texto != null) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(texto)));
    }
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Lo que carga el navegador y lo que cargan las pruebas salen de caminos
  // distintos. Los archivos se piden en paralelo y se reparten por nombre, así
  // que un pack asignado al campo equivocado recién se vería en producción.
  test('el contenido empaquetado es el mismo que el del directorio', () async {
    final bundled = await loadOfficialContent();
    final disk = await ContentRepository.loadFromDirectory(
      '../dnd_engine/lib/assets/srd_2024',
    );

    Map<String, Set<String>> ids(ContentRepository r) => {
      'races': r.races.keys.toSet(),
      'classes': r.classes.keys.toSet(),
      'subclasses': r.subclasses.keys.toSet(),
      'lineages': r.lineages.keys.toSet(),
      'backgrounds': r.backgrounds.keys.toSet(),
      'feats': r.feats.keys.toSet(),
      'weapons': r.weapons.keys.toSet(),
      'armor': r.armor.keys.toSet(),
      'items': r.items.keys.toSet(),
      'spells': r.spells.keys.toSet(),
      'creatures': r.creatures.keys.toSet(),
    };
    expect(ids(bundled), ids(disk));
  });

  test('en español no se pide ninguna traducción', () async {
    final bundle = _BundleQueAnota();
    await loadOfficialContent(bundle: bundle);
    expect(bundle.pedidos.where((p) => p.contains('.en.json')), isEmpty);
    expect(bundle.pedidos, isNot(contains('AssetManifest.bin')));
  });

  test('en inglés aplica la superposición empaquetada', () async {
    final espanol = await loadOfficialContent();
    final conjuro = espanol.spells.values.first;
    final crudo = conjuro.toJson();
    final bundle = _BundleQueAnota({
      'packages/dnd_engine/assets/srd_2024/spells.en.json': jsonEncode({
        conjuro.id: {
          translationFingerprintKey: contentFingerprint(crudo, ['name']),
          'name': 'Translated',
        },
      }),
    });
    final ingles = await loadOfficialContent(translation: 'en', bundle: bundle);
    expect(ingles.spell(conjuro.id)!.name, 'Translated');
    // Solo se pide lo que el manifiesto dice que existe.
    expect(bundle.pedidos.where((p) => p.endsWith('.en.json')), [
      'packages/dnd_engine/assets/srd_2024/spells.en.json',
    ]);
  });
}
