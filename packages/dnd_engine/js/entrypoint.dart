/// Puente del motor hacia JavaScript: `dart compile js -O2 js/entrypoint.dart`.
///
/// Expone `globalThis.dndEngine` con funciones **de cadena a cadena**. Pasar JSON como texto y no como objetos JS es a propósito: el
/// motor trabaja con mapas de Dart y la conversión de objetos cruza la
/// frontera con reglas propias (enteros contra dobles, `undefined` contra
/// `null`) que no hacen falta para nada; con texto el contrato es el mismo
/// JSON que ya viaja por la API.
///
/// Vive en `js/` y no en `tool/` porque la imagen de Docker lo compila
/// (`packages/dnd_server/Dockerfile`) y `.dockerignore` deja afuera `tool/`;
/// además un cambio acá sí tiene que desplegar (ver el `gate` de `cd.yml`).
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dnd_engine/dnd_engine.dart';

String? _catalogJsonVisto;
ContentRepository? _repo;

/// Armar el repositorio cuesta (parsea ~3 MB de catálogo), y la ficha se
/// recalcula con cada cambio. Se guarda el último: el cliente le pasa siempre
/// el mismo texto del catálogo, así que la comparación es la de la misma
/// referencia, no un recorrido de megabytes.
ContentRepository _repoPara(String catalogJson) {
  final cacheado = _repo;
  if (cacheado != null && catalogJson == _catalogJsonVisto) return cacheado;
  final catalog = jsonDecode(catalogJson) as Map<String, dynamic>;
  List<Map<String, dynamic>> lista(String clave) =>
      ((catalog[clave] as List?) ?? const []).cast<Map<String, dynamic>>();
  // Las claves son los parámetros de `fromJsonPacks`: el catálogo viaja como
  // el cargador de directorio lo arma (`items` ya con los objetos mágicos).
  final repo = ContentRepository.fromJsonPacks(
    races: lista('races'),
    classes: lista('classes'),
    subclasses: lista('subclasses'),
    lineages: lista('lineages'),
    backgrounds: lista('backgrounds'),
    feats: lista('feats'),
    weapons: lista('weapons'),
    armor: lista('armor'),
    items: lista('items'),
    spells: lista('spells'),
    creatures: lista('creatures'),
  );
  _catalogJsonVisto = catalogJson;
  return _repo = repo;
}

/// Ficha (JSON de `Character`) + catálogo → `ComputedSheet.toJson()` completo.
/// `Character.fromJson` ya migra: una ficha vieja entra igual que en el
/// servidor.
String compute(String characterJson, String catalogJson) {
  final character = Character.fromJson(
    jsonDecode(characterJson) as Map<String, dynamic>,
  );
  final sheet = CharacterCompiler(_repoPara(catalogJson)).compile(character);
  return jsonEncode(sheet.toJson());
}

/// Lleva una ficha de cualquier versión al esquema actual. Rechaza una versión
/// futura (`UnsupportedDataVersionException`) en vez de devolverla: el cliente
/// no debe guardar de vuelta una ficha que no entiende.
String migrateCharacter(String characterJson) => jsonEncode(
      Character.migrateJson(jsonDecode(characterJson) as Map<String, dynamic>),
    );

/// Fija el idioma de los rótulos que el motor arma al calcular («Mediano»,
/// el nombre de una condición…). Es el estado global `ContentLanguage.current`
/// que `main.dart` de Flutter también fija con el idioma de la interfaz; hay
/// que llamarlo **antes** de `compute`. Cualquier código que no sea `en` deja
/// el español, que es la fuente.
void setLanguage(String code) {
  ContentLanguage.current =
      code == 'en' ? ContentLanguage.en : ContentLanguage.es;
}

/// Superpone la traducción (`X.en.json`) a un catálogo (`X.json`), ambos como
/// texto JSON. Es el `applyContentTranslation` de Flutter y del servidor, no
/// una copia en TypeScript: la regla de qué ruta se pisa vive en un solo lado.
String applyTranslation(String packJson, String overlayJson) => jsonEncode(
      applyContentTranslation(
        (jsonDecode(packJson) as List).cast<Map<String, dynamic>>(),
        (jsonDecode(overlayJson) as Map).cast<String, dynamic>(),
      ),
    );

/// [value] de un campo de vocabulario cerrado (`school`, `castingTime`,
/// `duration`, `range`, `size`, `creatureType`) en el idioma fijado con
/// [setLanguage]. Es el `vocabularyLabel` que usa Flutter al mostrarlos: esos
/// campos viajan en español también en el catálogo inglés, y la traducción
/// tiene patrones («Concentración, hasta 1 minuto», «Personal (cono de 15
/// pies)») que no tienen por qué copiarse en TypeScript. Un campo que no
/// existe devuelve el valor tal cual, como un valor desconocido.
String vocabularyLabelFor(String field, String value) {
  for (final f in VocabularyField.values) {
    if (f.name == field) return vocabularyLabel(f, value);
  }
  return value;
}

void main() {
  final motor = JSObject();
  motor['compute'] = compute.toJS;
  motor['migrateCharacter'] = migrateCharacter.toJS;
  motor['setLanguage'] = setLanguage.toJS;
  motor['applyTranslation'] = applyTranslation.toJS;
  motor['vocabularyLabel'] = vocabularyLabelFor.toJS;
  globalContext['dndEngine'] = motor;
}
