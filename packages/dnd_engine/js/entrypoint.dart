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

/// El Bestiario: cada criatura del catálogo (con el homebrew encima), en el
/// orden de `creaturesSorted` —alfabético, sin las invocaciones por fórmula,
/// cuya CA y PG dependen de quien las invoca—, con lo que el motor deriva y la
/// pantalla no debe repetir: la línea de tipo (`displayKind`, que en un
/// homebrew sigue al idioma), el tipo con su rótulo, el desafío como se
/// imprime, el modificador de iniciativa (que el perfil puede traer
/// competente), la percepción pasiva y, por cada acción, si su alcance es
/// cuerpo a cuerpo. El resto del perfil (CA, PG,
/// características, acciones) viaja tal cual está en el catálogo.
String bestiary(String catalogJson) => jsonEncode([
      for (final c in _repoPara(catalogJson).creaturesSorted)
        {
          'id': c.id,
          'kind': c.displayKind,
          'type': c.creatureType?.id,
          'typeLabel': c.creatureType?.label,
          'cr': c.cr,
          'crText': c.challengeRatingText,
          'initiative': c.initiativeModifier,
          'passivePerception': c.passivePerceptionValue,
          'meleeReach': [for (final a in c.actions) a.isMeleeReach],
        },
    ]);

/// Los PNJ del DM listos para mostrar, sin que el cliente repita una regla.
/// Entra la lista que devuelven `GET /api/npcs` o `GET /api/campaigns/<id>/npcs`
/// —`{npc, character?, status?, currentHp?}` por entrada— y sale, en el mismo
/// orden, el PNJ **migrado** (`Npc.fromJson`, que rechaza una versión futura)
/// con lo que deriva el motor: sus números de combate (`NpcStats`), si viene
/// herido en esa campaña, el nombre de la criatura de base en el idioma
/// activo (el guardado queda de respaldo), la especie y las clases de su
/// ficha, y lo que la ficha muestra del bloque o de la ficha compilada.
String npcs(String entriesJson, String catalogJson) {
  final repo = _repoPara(catalogJson);
  return jsonEncode([
    for (final raw
        in (jsonDecode(entriesJson) as List).cast<Map<String, dynamic>>())
      _npcView(raw, repo),
  ]);
}

Map<String, dynamic> _npcView(
    Map<String, dynamic> raw, ContentRepository repo) {
  final npc = Npc.fromJson((raw['npc'] as Map).cast<String, dynamic>());
  final characterJson = raw['character'];
  final character = characterJson is Map
      ? Character.fromJson(characterJson.cast<String, dynamic>())
      : null;
  final status = NpcStatus.fromJson(raw['status'] as String?);
  final stats = NpcStats.of(npc, character, repo);
  final hurt = stats.hurt(status, raw['currentHp'] as int?);
  final baseId = npc.baseCreatureId;
  final block = npc.sheetKind == NpcSheetKind.block ? npc.block : null;
  final sheet = stats.sheet;
  return {
    'npc': npc.toJson(),
    'status': status.toJson(),
    'maxHp': stats.maxHp,
    'armorClass': stats.armorClass,
    'hurt': hurt == null ? null : {'current': hurt.current, 'max': hurt.max},
    'baseName': (baseId == null ? null : repo.creature(baseId)?.name) ??
        npc.baseCreatureName,
    'species': character == null
        ? null
        : repo.race(character.raceId)?.name ?? character.raceId,
    'classes': character == null
        ? const []
        : [
            for (final id in character.classHistory.toSet())
              {
                'name': repo.characterClass(id)?.name ?? id,
                'level': character.classLevel(id),
              },
          ],
    'block': block == null
        ? null
        : {
            'ac': block.ac,
            'hp': block.hp,
            'crText': block.challengeRatingText,
            'actions': [
              for (final a in block.actions)
                {
                  'name': a.name,
                  'attackBonus': a.attackBonus,
                  'damage': a.damage,
                },
            ],
          },
    'sheet': sheet == null
        ? null
        : {
            'armorClass': sheet.armorClass,
            'maxHp': sheet.maxHp,
            'initiative': sheet.initiative,
            'passivePerception': sheet.passivePerception,
          },
  };
}

/// El combate abierto de una campaña, para leerlo sin repetir una regla.
/// Entra el documento de `GET /api/campaigns/<id>/encounter` y los PG de los
/// jugadores de la mesa (`{memberId: {current, max}}`: los actuales de su
/// ficha real y el máximo que la compila, porque el encuentro no los lleva).
/// Sale el encuentro **migrado** (`Encounter.fromJson`, que rechaza una
/// versión futura), de quién es el turno —que salta a los caídos y no existe
/// mientras se arma—, cuántos quedan en pie por bando y, por fila, si está
/// caído, si está maltrecho y sus PG de la fuente que corresponde.
String encounter(String encounterJson, String playersHpJson) {
  final e = Encounter.fromJson(
      (jsonDecode(encounterJson) as Map).cast<String, dynamic>());
  final players = {
    for (final MapEntry(:key, :value)
        in (jsonDecode(playersHpJson) as Map).cast<String, Map>().entries)
      key: (current: value['current'] as int, max: value['max'] as int),
  };
  final current = e.current;
  final standing =
      e.standing({for (final p in players.entries) p.key: p.value.current});
  ({int current, int max})? hpOf(Combatant c) => c.kind == CombatantKind.player
      ? players[c.memberId]
      : c.maxHp > 0
          ? (current: c.currentHp, max: c.maxHp)
          : null;
  return jsonEncode({
    'encounter': e.toJson(),
    'preparing': e.isPreparing,
    'currentId': current?.id,
    'currentIndex': current == null
        ? -1
        : e.combatants.indexWhere((c) => c.id == current.id),
    'standing': {
      'allies': standing.allies,
      'alliesUp': standing.alliesUp,
      'enemies': standing.enemies,
      'enemiesUp': standing.enemiesUp,
      'neutrals': standing.neutrals,
    },
    'rows': [
      for (final c in e.combatants)
        if (hpOf(c) case final hp)
          {
            'id': c.id,
            'down': c.isDown,
            'bloodied':
                hp != null && hp.current > 0 && isBloodied(hp.current, hp.max),
            'hp': hp == null ? null : {'current': hp.current, 'max': hp.max},
          },
    ],
  });
}

/// El enlace de una escena de música → qué es, su id, el reproductor embebido
/// y la página de YouTube (`MusicSource.parse`), o `null` si no es un enlace
/// de YouTube que el motor reconozca. Así el cliente nunca arma una dirección
/// de iframe con lo que pegó el DM.
String musicSource(String url) {
  final source = MusicSource.parse(url);
  return jsonEncode(
    source == null
        ? null
        : {
            'kind': source.kind.name,
            'id': source.id,
            'embedUrl': source.embedUrl,
            'pageUrl': source.pageUrl,
          },
  );
}

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
  motor['bestiary'] = bestiary.toJS;
  motor['npcs'] = npcs.toJS;
  motor['encounter'] = encounter.toJS;
  motor['musicSource'] = musicSource.toJS;
  globalContext['dndEngine'] = motor;
}
