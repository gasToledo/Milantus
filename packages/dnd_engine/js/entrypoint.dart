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

/// La mochila de una ficha, cada entrada **resuelta por el motor**: el nombre
/// (`Espada larga +1 (Espada larga)`), el peso por unidad, si cuenta como
/// equipada, si es mágica y sus cargas. Son `InventoryOps.resolve` e
/// `InventoryOps.isEquipped`, las mismas que usan el compilador y Flutter: un
/// cliente que las repitiera podría tildar como equipado algo que no le suma
/// la CA.
///
/// Devuelve una lista JSON en el orden del inventario. `kind` es `weapon`,
/// `armor`, `item`, o `null` si el id no está en el catálogo (homebrew que no
/// se cargó): la fila se muestra igual, como en Flutter. `family` es la
/// categoría del objeto, o `magic` si tiene rareza (`itemFamily` de la app).
String inventory(String characterJson, String catalogJson) {
  final character = Character.fromJson(
    jsonDecode(characterJson) as Map<String, dynamic>,
  );
  final repo = _repoPara(catalogJson);
  return jsonEncode([
    for (final e in character.inventory) _inventoryLine(character, e, repo),
  ]);
}

Map<String, dynamic> _inventoryLine(
  Character c,
  InventoryEntry e,
  ContentRepository repo,
) {
  final entry = repo.catalogEntry(e.itemId);
  final resolved = InventoryOps.resolve(e, repo);
  final item = resolved.item;
  final replica =
      e.origin?.startsWith('artificer:replicate-magic-item:') == true;
  final source =
      item?.source ?? resolved.weapon?.source ?? resolved.armor?.source;
  return {
    'entryId': e.entryId,
    'itemId': e.itemId,
    'name': entry == null ? e.itemId : resolved.name,
    'kind': entry == null
        ? null
        : resolved.weapon != null
            ? 'weapon'
            : resolved.armor != null
                ? 'armor'
                : entry.kind,
    'family': item == null ? null : (item.isMagic ? 'magic' : item.category),
    'weight': resolved.weight,
    'quantity': e.quantity,
    'equipped': InventoryOps.isEquipped(c, e, repo),
    'attuned': e.attuned,
    'requiresAttunement': item?.requiresAttunement ?? false,
    'magic': (item?.isMagic ?? false) || replica,
    'charges': e.charges,
    'maxCharges': item?.maxCharges,
    'note': e.note,
    'homebrew': source == ContentSource.homebrew,
  };
}

/// Lo que reparte un capítulo cerrado, en una línea y en el idioma activo
/// («25 po y una poción de curación»), o vacío. Es `Chapter.grantsLabel`:
/// cómo se nombran el oro, los objetos y la subida de nivel vive en el motor.
String chapterGrants(String chapterJson) => Chapter.fromJson(
      jsonDecode(chapterJson) as Map<String, dynamic>,
    ).grantsLabel;

/// El nombre visible de un id de vocabulario del catálogo, en el idioma
/// activo: rareza, categoría de dote o de objeto, competencias, propiedades y
/// maestrías de arma, tipos de daño, habilidades, características (su
/// abreviatura) e idiomas. Son las tablas y `labelFor` del motor, las mismas
/// que lee Flutter; un tipo o id desconocido vuelve tal cual. Con
/// `weaponPropertyRule` devuelve la explicación de la propiedad.
String catalogLabel(String kind, String id) => switch (kind) {
      'rarity' => itemRarityLabels[id] ?? id,
      'featCategory' => featCategoryLabels[id] ?? id,
      'itemCategory' => itemCategoryLabels[id] ?? id,
      'armorTraining' => armorTrainingLabel(id),
      'weaponProficiency' => weaponProficiencyLabel(id),
      'tool' => toolProficiencyLabel(id),
      'weaponProperty' => weaponProperties[id]?.name ?? id,
      'weaponPropertyRule' => weaponProperties[id]?.description ?? '',
      'mastery' => weaponMasteryName(id),
      'damageType' => DamageType.labelFor(id),
      'skill' => Skill.labelFor(id),
      'ability' =>
        Ability.values.where((a) => a.name == id).firstOrNull?.abbr ?? id,
      'language' => Language.labelFor(id),
      _ => id,
    };

/// El orden de las claves de una tabla de rótulos (`rarity`, `featCategory`,
/// `itemCategory`), como lista JSON: de la rareza más común a la más rara, por
/// ejemplo. Es el que usan los filtros del Códice en Flutter.
String catalogLabelOrder(String kind) => jsonEncode(switch (kind) {
      'rarity' => itemRarityLabels.keys.toList(),
      'featCategory' => featCategoryLabels.keys.toList(),
      'itemCategory' => itemCategoryLabels.keys.toList(),
      _ => const <String>[],
    });

/// Un precio de tabla guardado en cobre (`formatCost`): la cuenta de qué
/// denominación lo expresa sin fracción es del motor; las abreviaturas las pone
/// el cliente ([labelsJson]: `{"cp": "pc", …}`), porque en inglés «pp» es
/// platino y no plata.
String formatCostFor(int cp, String labelsJson) => formatCost(
      cp,
      labels: (jsonDecode(labelsJson) as Map).cast<String, String>(),
    );

/// El modificador de una puntuación de característica (`abilityModifier`):
/// la tabla del glosario lo muestra y la cuenta es del motor, no del cliente.
int abilityModifierOf(int score) => abilityModifier(score);

void main() {
  final motor = JSObject();
  motor['compute'] = compute.toJS;
  motor['migrateCharacter'] = migrateCharacter.toJS;
  motor['setLanguage'] = setLanguage.toJS;
  motor['applyTranslation'] = applyTranslation.toJS;
  motor['vocabularyLabel'] = vocabularyLabelFor.toJS;
  motor['inventory'] = inventory.toJS;
  motor['chapterGrants'] = chapterGrants.toJS;
  motor['catalogLabel'] = catalogLabel.toJS;
  motor['catalogLabelOrder'] = catalogLabelOrder.toJS;
  motor['formatCost'] = formatCostFor.toJS;
  motor['abilityModifier'] = abilityModifierOf.toJS;
  globalContext['dndEngine'] = motor;
}
