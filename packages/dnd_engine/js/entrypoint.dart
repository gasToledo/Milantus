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
import 'dart:math';

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
    'equippable': InventoryOps.isEquippable(e, repo),
    'bundleSize': item?.bundleSize ?? 1,
    // La marca de mano secundaria (solo armas ligeras) y de a dos manos (solo
    // versátiles), por el arma de base; null donde no aplica.
    'offHand': resolved.weapon?.isLight == true
        ? c.weaponOffHand[resolved.weapon!.id] ?? false
        : null,
    'twoHanded': resolved.weapon?.versatileDice != null
        ? c.weaponTwoHanded[resolved.weapon!.id] ?? false
        : null,
    'attuned': e.attuned,
    'requiresAttunement': item?.requiresAttunement ?? false,
    'magic': (item?.isMagic ?? false) || replica,
    // Precio de catálogo por unidad de `quantity` y lo que se ofrece al
    // vender (la mitad, `suggestedSalePriceCp`).
    'costCp': resolved.costCp,
    'salePriceCp': InventoryOps.suggestedSalePriceCp(e, repo),
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

/// La cuenta del diálogo de comprar o vender (`TradeDialog` de Flutter), con
/// las mismas funciones que después aplican `buy` y `sell`: el precio por
/// unidad sale de lo que se escribió en po, pp y pc; al comprar, qué monedas
/// salen, el vuelto y cuánto falta si no alcanza; al vender, cómo queda la
/// bolsa. Los montos van en cobre y ya escritos con [labelsJson].
String trade(String requestJson, String labelsJson) {
  final r = jsonDecode(requestJson) as Map<String, dynamic>;
  final labels = (jsonDecode(labelsJson) as Map).cast<String, String>();
  Map<String, int> ints(Object? m) => {
        for (final e in ((m as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      };
  final coins = ints(r['coins']);
  final unitCp = CoinOps.totalCp(ints(r['price']));
  final total = unitCp * (r['quantity'] as num).toInt();
  final buying = r['buying'] == true;
  final plan = buying ? CoinOps.plan(coins, total) : null;
  final after = buying ? (plan?.purse ?? coins) : CoinOps.receive(coins, total);
  final purse = CoinOps.totalCp(coins);
  String amount(int cp) => CoinOps.formatAmount(cp, labels: labels);
  String list(Map<String, int> m) => CoinOps.formatCoins(m, labels: labels);
  return jsonEncode({
    'unitCp': unitCp,
    'totalCp': total,
    'total': amount(total),
    'purseCp': purse,
    'purse': amount(purse),
    'short': buying && plan == null ? amount(total - purse) : null,
    'spent': plan == null ? '' : list(plan.spent),
    'change': plan == null ? '' : list(plan.change),
    'after': amount(CoinOps.totalCp(after)),
    'afterCoins': list(after),
  });
}

/// Una subida de nivel en curso (`LevelUp` del motor): con las decisiones
/// juntadas hasta ahora ([draftJson], `LevelUpDraft.fromJson`) devuelve lo que
/// el asistente muestra —clases, subclases y dotes con lo que les falta, si la
/// mejora está completa, los rasgos que se ganan, lo que obliga a elegir y
/// todavía se elige en Flutter (`open`)— y el personaje tal como quedaría
/// (`character`), para que la pantalla compare las dos fichas. Confirmar es la
/// acción `levelUp` de [act].
String levelUp(String characterJson, String catalogJson, String draftJson) {
  final up = LevelUp(
    Character.fromJson(jsonDecode(characterJson) as Map<String, dynamic>),
    _repoPara(catalogJson),
    LevelUpDraft.fromJson(jsonDecode(draftJson) as Map<String, dynamic>),
  );
  Map<String, dynamic>? choice(AbilityScoreChoiceEffect? e) => e == null
      ? null
      : {
          'amount': e.amount,
          'max': e.max,
          'allowed': [for (final a in e.allowed) a.name],
        };
  final open = up.open;
  return jsonEncode({
    'newLevel': up.newLevel,
    'newClassLevel': up.newClassLevel,
    'hitDie': up.hitDie,
    'averageHp': averageHitDie(up.hitDie),
    'hpGain': up.hpGain,
    // Lo que sube el máximo con cada opción, para las dos tarjetas del paso.
    'hpIfAverage': up.hpIncreaseWith(averageHitDie(up.hitDie)),
    'hpIfRoll': up.draft.hpRoll == null ? null : up.hpIncreaseWith(up.hpGain),
    'hpRange': [up.hpIncreaseWith(1), up.hpIncreaseWith(up.hitDie)],
    'isAsi': up.isAsi,
    'needsSubclass': up.needsSubclass,
    'asiComplete': up.asiComplete,
    'complete': up.complete,
    'unmetMulticlass': up.unmetMulticlass,
    'classOptions': [
      for (final o in up.classOptions)
        {
          'id': o.klass.id,
          'name': o.klass.name,
          'hitDie': o.klass.hitDie,
          'unmet': o.unmet,
        },
    ],
    'subclassOptions': [
      for (final s in up.subclassOptions)
        {
          'id': s.id,
          'name': s.name,
          'description': s.description,
          'homebrew': s.source == ContentSource.homebrew,
        },
    ],
    'featOptions': up.isAsi
        ? [
            for (final o in up.featOptions)
              {
                'id': o.feat.id,
                'name': o.feat.name,
                'category': o.feat.category,
                'description': o.feat.description,
                'homebrew': o.feat.source == ContentSource.homebrew,
                'unmet': o.unmet,
                'abilityChoice': choice(o.feat.effects
                    .whereType<AbilityScoreChoiceEffect>()
                    .firstOrNull),
              },
          ]
        : const [],
    'featAbilityChoice': choice(up.featAbilityChoice),
    'gainedFeatures': [
      for (final f in up.gainedFeatures)
        {'name': f.name, 'description': f.description},
    ],
    // Los cupos de elección de rasgo, con sus opciones (lo elegido nunca va
    // como inelegible) y lo que ya traía el personaje: el cliente muestra los
    // que tienen algo sin elegir o se pueden revisar.
    'featureSlots': [
      for (final f in up.featureSlots)
        {
          'groupId': f.slot.groupId,
          'name': f.slot.name,
          'count': f.slot.count,
          'replaceable': f.slot.replaceable,
          'chosen': f.chosen,
          'original': f.original,
          'options': [
            for (final o in f.options)
              {
                'id': o.feat.id,
                'name': o.feat.name,
                'repeatable': o.feat.repeatable,
                // Para el panel de detalle: las opciones de un rasgo (una
                // invocación) no son dotes del catálogo y el Códice no las
                // conoce. Su texto, como en `featSummary`: la descripción si
                // la hay, si no la de sus rasgos.
                'description': o.feat.description.isNotEmpty
                    ? o.feat.description
                    : [
                        for (final e in o.feat.effects)
                          if (e is PassiveTraitEffect) e.description,
                      ].join(' '),
                'homebrew': o.feat.source == ContentSource.homebrew,
                'unmet': o.unmet,
              },
          ],
        },
    ],
    'proficiencySlots': [
      for (final p in up.proficiencySlots)
        {
          'groupId': p.slot.groupId,
          'name': p.slot.name,
          'count': p.slot.count,
          'expertise': p.slot.expertise,
          'chosen': p.chosen,
          'options': [
            for (final id in p.slot.options)
              {
                'id': id,
                'label': p.slot.skills.contains(id)
                    ? Skill.labelFor(id)
                    : toolProficiencyLabel(id),
                'locked': p.locked.contains(id),
              },
          ],
        },
    ],
    // Los cupos de conjuros que concede un rasgo: ya traen sus opciones y lo
    // elegido revalidado.
    'spellSlots': [
      for (final slot in up.after.spellChoiceSlots)
        {
          'groupId': slot.groupId,
          'name': slot.name,
          'count': slot.count,
          'replaceable': slot.replaceable,
          'grantsSpells': slot.grantsSpells,
          'chosen': slot.chosen,
          'options': [
            for (final id in slot.options)
              if (up.repo.spell(id) case final sp?)
                {'id': id, 'name': sp.name, 'level': sp.level},
          ],
        },
    ],
    // Los trucos y conjuros de la clase que sube (`LevelUp.classSpells`), o
    // null si no lanza.
    'classSpells': switch (up.classSpellcasting) {
      null => null,
      final cs => () {
          final o = LevelUp.classSpells(up.built, up.after, up.repo, cs.sc,
              classId: cs.classId);
          return {
            'cantripsKnown': cs.sc.cantripsKnown,
            'preparedCount': cs.sc.preparedCount,
            'prepared': cs.sc.preparation == SpellPreparation.prepared,
            'cantrips': [
              for (final sp in o.cantrips) {'id': sp.id, 'name': sp.name},
            ],
            'spells': [
              for (final sp in o.spells)
                {'id': sp.id, 'name': sp.name, 'level': sp.level},
            ],
            'chosenCantrips': o.chosenCantrips,
            'chosenSpells': o.chosenSpells,
            'grantedCantrips': o.grantedCantrips,
            'grantedSpells': o.grantedSpells,
          };
        }(),
    },
    'open': {
      'features': open.features,
      'proficiencies': open.proficiencies,
      'spellChoices': open.spellChoices,
      'classSpells': open.classSpells,
    },
    'character': up.built.toJson(),
  });
}

/// Una tirada de un dado de [sides] caras (la de PG al subir de nivel): la
/// hace el motor, como el dado de golpe del paso 4.
int rollDie(int sides) => Dice().rollHitDie(sides);

/// [cp] partido en oro, plata y cobre (`CoinOps.changeFor`): los tres campos
/// del precio en el diálogo de comprar o vender.
String coinParts(int cp) => jsonEncode(CoinOps.changeFor(cp));

/// Un monto en cobre escrito para leer («7 po 5 pp», `CoinOps.formatAmount`).
String formatAmountFor(int cp, String labelsJson) => CoinOps.formatAmount(
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

/// Una acción de partida sobre la ficha propia (daño, un espacio, un
/// descanso…) → `{character, outcome}`. Es `SheetActions.apply`: la ficha que
/// vuelve ya está migrada y con el `schemaVersion` actual, y es lo que el
/// cliente guarda tal cual. Ver las acciones en `sheet_actions.dart`.
///
/// Las tiradas (el dado de golpe, la recarga al amanecer) las hace el motor,
/// como en Flutter; [seed] las fija y sirve solo para la prueba de paridad.
String act(
  String characterJson,
  String catalogJson,
  String actionJson, [
  int? seed,
]) {
  final character = Character.fromJson(
    jsonDecode(characterJson) as Map<String, dynamic>,
  );
  return jsonEncode(
    SheetActions.apply(
      character,
      _repoPara(catalogJson),
      jsonDecode(actionJson) as Map<String, dynamic>,
      dice: seed == null ? null : Dice(Random(seed)),
    ).toJson(),
  );
}

/// El creador de personajes (`CreationDraft` del motor): aplica [actionJson]
/// (vacío o `{}` para solo leer) al borrador [draftJson] con sus podas, y
/// devuelve `CreationDraft.viewJson`: el borrador nuevo, lo que falta y lo
/// que deciden las reglas en cada paso. Las acciones están en
/// `CreationDraft.apply`. [seed] fija la tirada de 4d6 en la prueba de
/// paridad.
String creation(
  String catalogJson,
  String draftJson,
  String actionJson, [
  int? seed,
]) {
  final repo = _repoPara(catalogJson);
  final draft = CreationDraft.fromJson(
    repo,
    jsonDecode(draftJson) as Map<String, dynamic>,
  );
  final action = actionJson.isEmpty ? null : jsonDecode(actionJson);
  if (action is Map<String, dynamic> && action.isNotEmpty) {
    draft.apply(action, dice: seed == null ? null : Dice(Random(seed)));
  }
  return jsonEncode(draft.viewJson());
}

void main() {
  final motor = JSObject();
  motor['creation'] = creation.toJS;
  motor['act'] = act.toJS;
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
  motor['trade'] = trade.toJS;
  motor['levelUp'] = levelUp.toJS;
  motor['rollDie'] = rollDie.toJS;
  motor['coinParts'] = coinParts.toJS;
  motor['formatAmount'] = formatAmountFor.toJS;
  motor['abilityModifier'] = abilityModifierOf.toJS;
  motor['bestiary'] = bestiary.toJS;
  motor['npcs'] = npcs.toJS;
  motor['encounter'] = encounter.toJS;
  motor['musicSource'] = musicSource.toJS;
  globalContext['dndEngine'] = motor;
}
