// Spike: el motor expuesto a JavaScript vía `dart:js_interop`.
//   dart compile js   -O2 tool/js_spike/entrypoint.dart -o build/js_spike/engine.js
//   dart compile wasm    tool/js_spike/entrypoint.dart -o build/js_spike/engine.wasm
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dnd_engine/dnd_engine.dart';

import 'sheet_summary.dart';

String? _catalogKey;
CharacterCompiler? _compiler;

/// El catálogo se parsea una sola vez: Node pasa siempre el mismo string, y
/// reconstruir el repositorio en cada `compute` mediría el parseo, no la regla.
CharacterCompiler _compilerFor(String catalogJson) {
  if (_compiler != null && identical(_catalogKey, catalogJson)) {
    return _compiler!;
  }
  final cat = (jsonDecode(catalogJson) as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> pack(String k) =>
      ((cat[k] ?? const []) as List).cast<Map<String, dynamic>>();
  final repo = ContentRepository.fromJsonPacks(
    races: pack('races'),
    classes: pack('classes'),
    subclasses: pack('subclasses'),
    lineages: pack('lineages'),
    backgrounds: pack('backgrounds'),
    feats: pack('feats'),
    weapons: pack('weapons'),
    armor: pack('armor'),
    items: pack('items'),
    spells: pack('spells'),
    creatures: pack('creatures'),
  );
  _catalogKey = catalogJson;
  return _compiler = CharacterCompiler(repo);
}

String compute(String characterJson, String catalogJson) {
  final character = Character.fromJson(
    (jsonDecode(characterJson) as Map).cast<String, dynamic>(),
  );
  final sheet = _compilerFor(catalogJson).compile(character);
  return jsonEncode(summarizeSheet(sheet));
}

String migrateCharacter(String json) => jsonEncode(
      Character.migrateJson((jsonDecode(json) as Map).cast<String, dynamic>()),
    );

void main() {
  globalContext.setProperty(
      'dndEngine'.toJS,
      <String, JSAny>{
        'compute': ((JSString c, JSString cat) =>
            compute(c.toDart, cat.toDart).toJS).toJS,
        'migrateCharacter':
            ((JSString j) => migrateCharacter(j.toDart).toJS).toJS,
      }.jsify());
}
