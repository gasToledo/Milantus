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
import 'package:dnd_engine/homebrew_references.dart';
import 'package:dnd_engine/homebrew_transfer.dart' as transfer;

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

/// Lo que la ficha deja elegir o revisar (`choicesView`): las advertencias y
/// los cupos con sus opciones, para los avisos y la pantalla de elecciones.
String choicesViewJs(String characterJson, String catalogJson) => jsonEncode(
      choicesView(
        Character.fromJson(jsonDecode(characterJson) as Map<String, dynamic>),
        _repoPara(catalogJson),
      ),
    );

/// Ficha (JSON de `Character`) + catálogo → `ComputedSheet.toJson()` completo.
/// `Character.fromJson` ya migra: una ficha vieja entra igual que en el
/// servidor.
String compute(String characterJson, String catalogJson) {
  final character = Character.fromJson(
    jsonDecode(characterJson) as Map<String, dynamic>,
  );
  final repo = _repoPara(catalogJson);
  final sheet = CharacterCompiler(repo).compile(character);
  // Primero la forma y después el Cansancio, como en Flutter, la ficha del
  // miembro y el MCP: sin lo segundo /v2 mostraba descansado a quien no lo
  // está, y sin lo primero mostraba al druida con la CA de humano en forma de
  // oso.
  return jsonEncode(
    applyExhaustion(
      withWildShape(sheet, character, repo),
      character.combat.exhaustion,
    ).toJson(),
  );
}

/// El prompt de retrato de la ficha, del motor: el cliente no arma frases ni
/// nombres en inglés. `includeWeapon` en false lo deja sin el arma (Azure
/// rechaza el prompt si nombra un arma).
String portraitPromptJs(
  String characterJson,
  String catalogJson,
  String style,
  String extraText,
  bool includeWeapon,
) =>
    buildPortraitPrompt(
      character: Character.fromJson(
        jsonDecode(characterJson) as Map<String, dynamic>,
      ),
      repo: _repoPara(catalogJson),
      style: style,
      extraText: extraText,
      includeWeapon: includeWeapon,
    );

/// Los estilos predeterminados de retrato (sus ids, que son lo que se guarda
/// en los ajustes), como lista JSON.
String portraitStylesJs() => jsonEncode(portraitStyles);

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
    // El texto del objeto, la misma fuente que `_itemInfo` de Flutter.
    'description': item?.description ?? '',
    'homebrew': source == ContentSource.homebrew,
    // Lo creó un rasgo (el arma de pacto): al cambiarla sale de la mochila.
    'createdByFeature': e.origin?.startsWith('effect-target:') == true,
    'replica': replica,
    // Una plantilla que pide base y no la tiene se equipa pero no ataca.
    'needsBase': item?.baseItemKind != null && e.baseItemId == null,
  };
}

/// Si el personaje todavía puede subir de nivel (`Character.canLevelUp`).
bool canLevelUp(String characterJson) => Character.fromJson(
      jsonDecode(characterJson) as Map<String, dynamic>,
    ).canLevelUp;

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
      'masteryRule' => weaponMasteries[id]?.description ?? '',
      'damageType' => DamageType.labelFor(id),
      'skill' => Skill.labelFor(id),
      'ability' =>
        Ability.values.where((a) => a.name == id).firstOrNull?.abbr ?? id,
      'language' => Language.labelFor(id),
      // Qué mide la característica: el texto que Flutter muestra en su ayuda.
      'abilityRule' =>
        Ability.values.where((a) => a.name == id).firstOrNull?.description ??
            '',
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

/// Los trucos y conjuros de una clase como los lee el cliente: el editor de la
/// subida de nivel y el de la ficha ([spellEdit]) comparten forma.
Map<String, dynamic> _classSpellsMap(
  Spellcasting sc,
  ({
    List<Spell> cantrips,
    List<Spell> spells,
    List<String> chosenCantrips,
    List<String> chosenSpells,
    List<String> grantedCantrips,
    List<String> grantedSpells,
  }) o,
) =>
    {
      'cantripsKnown': sc.cantripsKnown,
      'preparedCount': sc.preparedCount,
      'prepared': sc.preparation == SpellPreparation.prepared,
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

/// El editor de conjuros de la ficha para [classId] (`LevelUp.classSpells`),
/// con la forma de `levelUp.classSpells`, o `null` si esa clase no lanza. Sin
/// bloques de lanzamiento (ficha monoclase) la clase es la principal.
String spellEdit(String characterJson, String catalogJson, String classId) {
  final c = Character.fromJson(
    jsonDecode(characterJson) as Map<String, dynamic>,
  );
  final repo = _repoPara(catalogJson);
  final sheet = CharacterCompiler(repo).compile(c);
  final blocks = sheet.spellcastingBlocks;
  final sc = blocks.isEmpty
      ? (classId == c.classId ? sheet.spellcasting : null)
      : blocks.where((b) => b.classId == classId).firstOrNull?.spellcasting;
  if (sc == null) return jsonEncode(null);
  return jsonEncode(
    _classSpellsMap(
      sc,
      LevelUp.classSpells(c, sheet, repo, sc,
          classId: blocks.isEmpty ? null : classId),
    ),
  );
}

/// Los planos del Artífice (`sheet.itemChoiceSlots`) con lo que la pantalla
/// necesita, o `null` si la ficha no tiene cupo: `{groupId, name, count,
/// maxActive, options, chosen, replicas}`. `options` va por
/// `compareContentNames`; `chosen` es lo que la ficha guarda, **incluido lo que
/// quedó fuera de las opciones** (si no, no habría cómo sacarlo); `replicas`
/// son las réplicas de la mochila con el nombre de su base.
String magicItemPlans(String characterJson, String catalogJson) {
  final c = Character.fromJson(
    jsonDecode(characterJson) as Map<String, dynamic>,
  );
  final repo = _repoPara(catalogJson);
  final slot = CharacterCompiler(repo).compile(c).itemChoiceSlots.firstOrNull;
  if (slot == null) return jsonEncode(null);
  final options = [
    for (final item in slot.optionItemIds.map(repo.item).nonNulls) item,
  ]..sort((a, b) => compareContentNames(a.name, b.name));
  return jsonEncode({
    'groupId': slot.groupId,
    'name': slot.name,
    'count': slot.count,
    'maxActive': slot.maxActive,
    'options': [
      for (final item in options)
        {
          'id': item.id,
          'name': item.name,
          'rarity': item.rarity,
          'requiresAttunement': item.requiresAttunement,
          'baseItemKind': item.baseItemKind,
        },
    ],
    'chosen': [
      for (final id in c.magicItemChoices)
        {'id': id, 'name': repo.item(id)?.name ?? id},
    ],
    'replicas': [
      for (final e in c.inventory)
        if (e.origin?.startsWith('artificer:replicate-magic-item:') == true)
          {
            'itemId': e.itemId,
            'entryId': e.entryId,
            'name': repo.item(e.itemId)?.name ?? e.itemId,
            'baseName': e.baseItemId == null
                ? null
                : repo.catalogEntry(e.baseItemId!)?.name ?? e.baseItemId,
          },
    ],
  });
}

/// Los objetos base entre los que se elige para replicar [itemId]
/// (`InventoryOps.magicBaseOptions`): `[{id, name}]`, vacío si el plano no
/// pide base.
String magicBaseOptions(String catalogJson, String itemId) {
  final repo = _repoPara(catalogJson);
  final item = repo.item(itemId);
  return jsonEncode([
    if (item != null)
      for (final id in InventoryOps.magicBaseOptions(item, repo))
        {'id': id, 'name': repo.catalogEntry(id)?.name ?? id},
  ]);
}

/// Los trucos entre los que se puede cambiar el innato [granted]
/// (`LevelUp.innateCantripOptions`): `[{id, name, school}]`, vacío si ese
/// truco no existe o no es reemplazable.
String innateCantripOptions(
  String characterJson,
  String catalogJson,
  String granted,
) {
  final c = Character.fromJson(
    jsonDecode(characterJson) as Map<String, dynamic>,
  );
  final repo = _repoPara(catalogJson);
  final innate = CharacterCompiler(repo)
      .compile(c)
      .innateSpells
      .where((s) => s.grantedSpellId == granted && s.isReplaceable)
      .firstOrNull;
  return jsonEncode([
    if (innate != null)
      for (final sp in LevelUp.innateCantripOptions(repo, innate))
        {'id': sp.id, 'name': sp.name, 'school': sp.school},
  ]);
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
      final cs => _classSpellsMap(
          cs.sc,
          LevelUp.classSpells(up.built, up.after, up.repo, cs.sc,
              classId: cs.classId),
        ),
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
      for (final c in _repoPara(catalogJson).creaturesSorted) _bestiaryRow(c),
    ]);

/// La fila del Bestiario de una criatura: la misma para el listado y para la
/// vista previa del editor de bloques, que muestra el borrador con lo que
/// derivaría el motor si ya estuviera en el catálogo.
Map<String, dynamic> _bestiaryRow(Creature c) => {
      'id': c.id,
      'kind': c.displayKind,
      'type': c.creatureType?.id,
      'typeLabel': c.creatureType?.label,
      'cr': c.cr,
      'crText': c.challengeRatingText,
      'initiative': c.initiativeModifier,
      'passivePerception': c.passivePerceptionValue,
      'meleeReach': [for (final a in c.actions) a.isMeleeReach],
    };

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

/// Lo que la ficha de un PNJ a importar usa y este catálogo no tiene
/// (`missingOfficialContent`). `sheetJson` puede ser `null`.
String npcImportMissing(
  String? sheetJson,
  String homebrewJson,
  String catalogJson,
) {
  final sheet = sheetJson == null
      ? null
      : Character.fromJson(
          (jsonDecode(sheetJson) as Map).cast<String, dynamic>());
  final raw = jsonDecode(homebrewJson) as Map;
  return jsonEncode(missingOfficialContent(
    sheet,
    {
      for (final e in raw.entries)
        '${e.key}': [
          for (final doc in (e.value as List? ?? const []))
            if (doc is Map) doc.cast<String, dynamic>(),
        ],
    },
    _repoPara(catalogJson),
  ));
}

/// El documento de un PNJ nuevo (`Npc.draft`), listo para `POST /api/npcs`.
/// [baseCreatureId] vacío es un bloque vacío; un id que no está en el catálogo
/// es un error y no un bloque vacío: el DM eligió otra cosa.
String newNpc(
  String catalogJson,
  String name,
  String kind,
  String baseCreatureId,
) {
  final repo = _repoPara(catalogJson);
  final base = baseCreatureId.isEmpty ? null : repo.creature(baseCreatureId);
  if (baseCreatureId.isNotEmpty && base == null) {
    throw FormatException('No existe la criatura "$baseCreatureId".');
  }
  return jsonEncode(
    Npc.draft(
      name: name,
      kind: NpcSheetKind.fromJson(kind),
      base: base,
    ).toJson(),
  );
}

/// Aplica una edición a un PNJ (`NpcEdits`) y devuelve el documento migrado, listo
/// para `PUT /api/npcs/<id>`. No lee el catálogo: nada de esto es una regla del juego.
String npcEdit(String npcJson, String actionJson) => jsonEncode(
      NpcEdits.apply(
        Npc.fromJson((jsonDecode(npcJson) as Map).cast<String, dynamic>()),
        (jsonDecode(actionJson) as Map).cast<String, dynamic>(),
      ).toJson(),
    );

/// El prompt de retrato de un PNJ **sin ficha** (`none` o `block`). No lleva ficha
/// ni arma: un PNJ con ficha de personaje usa `portraitPrompt` con su ficha, y
/// sin ficha no hay arma que nombrar. Nunca lee trasfondo, notas ni voz
/// (`buildNpcPortraitPrompt`); lo único libre es `extraText`, su apariencia.
String npcPortraitPrompt(
  String npcJson,
  String catalogJson,
  String style,
  String extraText,
) =>
    buildNpcPortraitPrompt(
      npc: Npc.fromJson((jsonDecode(npcJson) as Map).cast<String, dynamic>()),
      repo: _repoPara(catalogJson),
      style: style,
      extraText: extraText,
    );

/// El bloque de un PNJ de bloque, o uno vacío si no lo tiene.
String npcBlock(String npcJson) {
  final npc =
      Npc.fromJson((jsonDecode(npcJson) as Map).cast<String, dynamic>());
  return jsonEncode((npc.block ?? Npc.emptyBlock(npc.name)).toJson());
}

Creature _criatura(String json) =>
    Creature.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

/// El formulario (todo texto) de una criatura: `CreatureDraft.formOf`.
String creatureForm(String creatureJson) =>
    jsonEncode(CreatureDraft.formOf(_criatura(creatureJson)));

/// El borrador de un formulario sobre su criatura de partida: la criatura
/// armada, su fila del Bestiario para la vista previa y los errores por campo.
String creatureDraft(String creatureJson, String formJson) {
  final form = (jsonDecode(formJson) as Map).cast<String, dynamic>();
  final built = CreatureDraft.build(_criatura(creatureJson), form);
  return jsonEncode({
    'creature': built.toJson(),
    'row': _bestiaryRow(built),
    'errors': CreatureDraft.errors(form),
  });
}

/// Las opciones de los desplegables del editor de bloques, con su rótulo en el
/// idioma de `setLanguage`.
String creatureFormOptions() => jsonEncode({
      'types': [
        for (final t in CreatureType.values) {'id': t.id, 'label': t.label},
      ],
      'sizes': [
        for (final s in CreatureSize.values) {'id': s.id, 'label': s.label},
      ],
      'kinds': [
        for (final k in CreatureActionKind.values)
          {'id': k.id, 'label': k.label},
      ],
      'damageTypes': [
        for (final d in DamageType.values) {'id': d.id, 'label': d.label},
      ],
    });

/// Los textos de regla que los formularios del Homebrew explican al tocar un
/// campo (el panel de reglas de Flutter): los del glosario del motor, en el
/// idioma de `setLanguage`. Los `String get` viajan como texto y los `Map`
/// como objeto por id; así ninguna regla se escribe del lado del cliente.
String homebrewRules() => jsonEncode({
      'damageTypeRule': damageTypeRule,
      'damageTypes': {
        for (final d in DamageType.values)
          d.id: {'label': d.label, 'description': d.description},
      },
      'weaponCategory': weaponCategoryRules,
      'weaponRange': weaponRangeRule,
      'weaponMasteryRule': weaponMasteryRule,
      'weaponMasteries': {
        for (final e in weaponMasteries.entries)
          e.key: {'name': e.value.name, 'description': e.value.description},
      },
      'weaponProperties': {
        for (final e in weaponProperties.entries)
          e.key: {'name': e.value.name, 'description': e.value.description},
      },
      'armorCategory': armorCategoryRules,
      'armorTraining': armorTrainingRule,
      'armorBaseAc': armorBaseAcRule,
      'shieldBaseAc': shieldBaseAcRule,
      'armorAddDex': armorAddDexRule,
      'armorMaxDex': armorMaxDexRule,
      'armorStrength': armorStrengthRule,
      'armorStealth': armorStealthRule,
      'spellCantrip': spellCantripRule,
      'spellLevel': [for (var l = 1; l <= 9; l++) spellLevelRule(l)],
      'spellSchool': spellSchoolRules,
      'spellSchoolNote': spellSchoolNote,
      'spellCastingTime': spellCastingTimeRules,
      'spellLongCasting': spellLongCastingRule,
      'spellComponent': spellComponentRules,
      'spellConcentration': spellConcentrationRule,
      'spellRitual': spellRitualRule,
      'spellClasses': spellClassesRule,
      'featCategory': featCategoryRules,
      'featRepeatable': featRepeatableRule,
      'raceCreatureType': raceCreatureTypeRule,
      'raceSize': raceSizeRules,
      'size': sizeRule,
      'raceSpeed': raceSpeedRule,
      'raceSkillCount': raceSkillCountRule,
      'raceSkillFrom': raceSkillFromRule,
      'raceSizeOptions': raceSizeOptionsRule,
      'skillProficiency': skillProficiencyRule,
      'toolProficiency': toolProficiencyRule,
      'backgroundAbilities': backgroundAbilitiesRule,
      'backgroundOriginFeat': backgroundOriginFeatRule,
      'itemCategory': itemCategoryRules,
      'itemCategoryNote': itemCategoryNote,
      'itemMundane': itemMundaneRule,
      'itemRarity': itemRarityRule,
      'itemAttunement': itemAttunementRule,
      'itemAcBonus': itemAcBonusRule,
      'itemResistance': itemResistanceRule,
      'itemBase': itemBaseRule,
      'itemMagicBonus': itemMagicBonusRule,
      'creatureType': creatureTypeRule,
      'creatureBeastNote': creatureBeastNote,
      'creatureSize': creatureSizeRules,
      'creatureCr': creatureCrRule,
      'creatureAttackBonus': creatureAttackBonusRule,
      'creatureActionKind': creatureActionKindRules,
    });

Feat _dote(String json) =>
    Feat.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

/// El formulario (todo texto) de una dote: `FeatDraft.formOf`.
String featForm(String featJson) =>
    jsonEncode(FeatDraft.formOf(_dote(featJson)));

/// La dote armada con un formulario sobre su dote de partida, y los errores por
/// campo. Nunca lanza por datos inválidos: también alimenta la vista previa.
String featDraft(String featJson, String formJson) {
  final form = (jsonDecode(formJson) as Map).cast<String, dynamic>();
  return jsonEncode({
    'feat': FeatDraft.build(_dote(featJson), form).toJson(),
    'errors': FeatDraft.errors(form),
  });
}

/// La plantilla de «Nueva dote» (`FeatDraft.empty`).
String featNew() => jsonEncode(FeatDraft.empty().toJson());

Race _especie(String json) =>
    Race.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

/// El formulario (todo texto) de una especie: `RaceDraft.formOf`.
String raceForm(String raceJson) =>
    jsonEncode(RaceDraft.formOf(_especie(raceJson)));

/// La especie armada con un formulario sobre su especie de partida, y los
/// errores por campo. Nunca lanza por datos inválidos: alimenta la vista previa.
String raceDraft(String raceJson, String formJson) {
  final form = (jsonDecode(formJson) as Map).cast<String, dynamic>();
  return jsonEncode({
    'race': RaceDraft.build(_especie(raceJson), form).toJson(),
    'errors': RaceDraft.errors(form),
  });
}

/// La plantilla de «Nueva especie» (`RaceDraft.empty`).
String raceNew() => jsonEncode(RaceDraft.empty().toJson());

Background _trasfondo(String json) =>
    Background.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

/// El formulario (todo texto) de un trasfondo: `BackgroundDraft.formOf`.
String backgroundForm(String backgroundJson) =>
    jsonEncode(BackgroundDraft.formOf(_trasfondo(backgroundJson)));

/// El trasfondo armado con un formulario sobre su trasfondo de partida, y los
/// errores por campo (ver [raceDraft]).
String backgroundDraft(String backgroundJson, String formJson) {
  final form = (jsonDecode(formJson) as Map).cast<String, dynamic>();
  return jsonEncode({
    'background':
        BackgroundDraft.build(_trasfondo(backgroundJson), form).toJson(),
    'errors': BackgroundDraft.errors(form),
  });
}

/// La plantilla de «Nuevo trasfondo» (`BackgroundDraft.empty`).
String backgroundNew() => jsonEncode(BackgroundDraft.empty().toJson());

Weapon _arma(String json) =>
    Weapon.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

/// El formulario (todo texto) de un arma: `WeaponDraft.formOf`.
String weaponForm(String weaponJson) =>
    jsonEncode(WeaponDraft.formOf(_arma(weaponJson)));

/// El arma armada con un formulario sobre su arma de partida, y los errores por
/// campo (ver [raceDraft]).
String weaponDraft(String weaponJson, String formJson) {
  final form = (jsonDecode(formJson) as Map).cast<String, dynamic>();
  return jsonEncode({
    'weapon': WeaponDraft.build(_arma(weaponJson), form).toJson(),
    'errors': WeaponDraft.errors(form),
  });
}

/// La plantilla de «Nueva arma» (`WeaponDraft.empty`).
String weaponNew() => jsonEncode(WeaponDraft.empty().toJson());

Armor _armadura(String json) =>
    Armor.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

/// El formulario (todo texto) de una armadura: `ArmorDraft.formOf`.
String armorForm(String armorJson) =>
    jsonEncode(ArmorDraft.formOf(_armadura(armorJson)));

/// La armadura armada con un formulario, sus errores por campo y la CA de
/// ejemplo que la ficha le daría (`ArmorDraft.acExamples`, vacía en un escudo).
String armorDraft(String armorJson, String formJson) {
  final form = (jsonDecode(formJson) as Map).cast<String, dynamic>();
  final built = ArmorDraft.build(_armadura(armorJson), form);
  return jsonEncode({
    'armor': built.toJson(),
    'errors': ArmorDraft.errors(form),
    'acExamples': [
      for (final e in ArmorDraft.acExamples(built)) {'dex': e.dex, 'ac': e.ac},
    ],
  });
}

/// La plantilla de «Nueva armadura» (`ArmorDraft.empty`).
String armorNew() => jsonEncode(ArmorDraft.empty().toJson());

/// El formulario con la categoría nueva y la Destreza repuesta
/// (`ArmorDraft.withCategory`).
String armorWithCategory(String formJson, String category) {
  final form = (jsonDecode(formJson) as Map).cast<String, dynamic>();
  return jsonEncode(ArmorDraft.withCategory(form, category));
}

Item _objeto(String json) =>
    Item.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

Map<String, dynamic> _formulario(String json) =>
    (jsonDecode(json) as Map).cast<String, dynamic>();

/// El formulario (todo texto) de un objeto: `ItemDraft.formOf`.
String itemForm(String itemJson) =>
    jsonEncode(ItemDraft.formOf(_objeto(itemJson)));

/// El objeto armado con un formulario sobre su objeto de partida, y los errores
/// por campo (ver [raceDraft]).
String itemDraft(String itemJson, String formJson) {
  final form = _formulario(formJson);
  return jsonEncode({
    'item': ItemDraft.build(_objeto(itemJson), form).toJson(),
    'errors': ItemDraft.errors(form),
  });
}

/// La plantilla de «Nuevo objeto» (`ItemDraft.empty`).
String itemNew() => jsonEncode(ItemDraft.empty().toJson());

/// El formulario con la rareza nueva (`ItemDraft.withRarity`): sin rareza, sin
/// sintonización.
String itemWithRarity(String formJson, String rarity) =>
    jsonEncode(ItemDraft.withRarity(_formulario(formJson), rarity));

/// El formulario con la familia de objeto base nueva y las bases vaciadas
/// (`ItemDraft.withBaseKind`).
String itemWithBaseKind(String formJson, String kind) =>
    jsonEncode(ItemDraft.withBaseKind(_formulario(formJson), kind));

/// Las bases que puede tomar una familia de objeto base, del catálogo
/// **fusionado** y por nombre (`ItemDraft.baseOptions`).
String itemBaseOptions(String kind, String catalogJson) => jsonEncode([
      for (final o in ItemDraft.baseOptions(kind, _repoPara(catalogJson)))
        {'id': o.id, 'name': o.name},
    ]);

Spell _conjuro(String json) =>
    Spell.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());

/// El formulario (todo texto) de un conjuro: `SpellDraft.formOf`.
String spellForm(String spellJson) =>
    jsonEncode(SpellDraft.formOf(_conjuro(spellJson)));

/// El conjuro armado con un formulario sobre su conjuro de partida, y los
/// errores por campo (ver [raceDraft]).
String spellDraft(String spellJson, String formJson) {
  final form = _formulario(formJson);
  return jsonEncode({
    'spell': SpellDraft.build(_conjuro(spellJson), form).toJson(),
    'errors': SpellDraft.errors(form),
  });
}

/// La plantilla de «Nuevo conjuro» (`SpellDraft.empty`).
String spellNew() => jsonEncode(SpellDraft.empty().toJson());

/// Los componentes de un conjuro con su nombre `(es, en)`, en el orden de la
/// línea guardada.
const _spellComponentLabels = <String, (String, String)>{
  'V': ('Verbal', 'Verbal'),
  'S': ('Somático', 'Somatic'),
  'M': ('Material', 'Material'),
};

/// Las familias de objeto base con su rótulo `(es, en)`. «Ninguno» no está: lo
/// pone el cliente, que es quien decide cómo se ofrece.
const _baseItemKindLabels = <String, (String, String)>{
  'weapon': ('Arma', 'Weapon'),
  'armor': ('Armadura', 'Armor'),
  'shield': ('Escudo', 'Shield'),
};

/// Las categorías de arma y de armadura con su rótulo corto `(es, en)`, en el
/// orden en que se ofrecen. Los ids son los guardados.
const _weaponCategoryLabels = <String, (String, String)>{
  'simple': ('Sencilla', 'Simple'),
  'martial': ('Marcial', 'Martial'),
};
const _armorCategoryLabels = <String, (String, String)>{
  'light': ('Ligera', 'Light'),
  'medium': ('Media', 'Medium'),
  'heavy': ('Pesada', 'Heavy'),
  'shield': ('Escudo', 'Shield'),
};

/// Las opciones cerradas de los formularios de especie y trasfondo, con su
/// rótulo en el idioma de `setLanguage`. Las dotes salen del catálogo
/// **fusionado** (`catalogJson`), así que incluyen las propias.
String homebrewFormOptions(String catalogJson) {
  final repo = _repoPara(catalogJson);
  final skills = sortedByName(
    [for (final s in Skill.values) (id: s.id, label: s.label)],
    (o) => o.label,
  );
  return jsonEncode({
    // El id es el valor guardado (`Race.size`); el rótulo, el del idioma.
    'sizes': [
      for (final s in RaceDraft.sizes)
        {'id': s, 'label': vocabularyLabel(VocabularyField.size, s)},
    ],
    'skills': [
      for (final s in skills) {'id': s.id, 'label': s.label},
    ],
    'tools': [
      for (final id in toolProficiencyIds)
        {'id': id, 'label': toolProficiencyLabel(id)},
    ],
    'abilities': [
      for (final a in Ability.values) {'id': a.name, 'label': a.abbr},
    ],
    'originFeats': [
      for (final f in repo.featsSorted)
        if (BackgroundDraft.originFeatCategories.contains(f.category))
          {'id': f.id, 'name': f.name},
    ],
    // Armas y armaduras: el rótulo del idioma y el orden en que se ofrecen.
    'weaponCategories': [
      for (final e in _weaponCategoryLabels.entries)
        {'id': e.key, 'label': localized(e.value.$1, e.value.$2)},
    ],
    'armorCategories': [
      for (final e in _armorCategoryLabels.entries)
        {'id': e.key, 'label': localized(e.value.$1, e.value.$2)},
    ],
    'weaponProperties': [
      for (final p in weaponProperties.values) {'id': p.id, 'label': p.name},
    ],
    'masteries': [
      for (final m in weaponMasteries.values) {'id': m.id, 'label': m.name},
    ],
    'damageTypes': [
      for (final d in DamageType.values) {'id': d.id, 'label': d.label},
    ],
    // Objetos: las familias que se ofrecen (sin `magic`: lo que hace mágico a un
    // objeto es tener rareza), las rarezas de la más común a la más rara (sin
    // «mundano», que es no tener) y las familias de objeto base.
    'itemCategories': [
      for (final e in itemCategoryLabels.entries)
        {'id': e.key, 'label': e.value},
    ],
    'rarities': [
      for (final e in itemRarityLabels.entries) {'id': e.key, 'label': e.value},
    ],
    'baseItemKinds': [
      for (final e in _baseItemKindLabels.entries)
        {'id': e.key, 'label': localized(e.value.$1, e.value.$2)},
    ],
    // Conjuros: los valores guardados son los del catálogo (en español); el
    // rótulo es el del idioma. «Sin escuela» lo antepone el cliente.
    'spellLevels': [
      for (var n = 0; n <= 9; n++)
        {
          'id': '$n',
          'label': n == 0
              ? localized('Truco', 'Cantrip')
              : localized('Nivel $n', 'Level $n'),
        },
    ],
    'spellSchools': [
      for (final s in spellSchoolRules.keys)
        {'id': s, 'label': vocabularyLabel(VocabularyField.school, s)},
    ],
    'castingTimes': [
      for (final t in SpellDraft.castingTimes)
        {'id': t, 'label': vocabularyLabel(VocabularyField.castingTime, t)},
    ],
    // El nombre de cada clase sale del catálogo, en el idioma activo.
    'spellClasses': [
      for (final id in SpellDraft.classIds)
        {'id': id, 'label': repo.characterClass(id)?.name ?? id},
    ],
    'spellComponents': [
      for (final e in _spellComponentLabels.entries)
        {'id': e.key, 'label': localized(e.value.$1, e.value.$2)},
    ],
  });
}

/// Los tipos de efecto que el editor ofrece, con sus campos y las opciones de
/// cada uno sacadas del catálogo fusionado (`EffectDraft.kinds`).
String effectKinds(String catalogJson) =>
    jsonEncode(EffectDraft.kinds(_repoPara(catalogJson)));

/// Arma un efecto con los valores del diálogo: `{ok: true, effect}` o
/// `{ok: false, field, error}` si falta algo (`EffectDraft.build`).
String effectBuild(String kindId, String valuesJson) {
  final kind = EffectKind.byId(kindId);
  if (kind == null) {
    throw ArgumentError('Tipo de efecto desconocido: "$kindId"');
  }
  final values = (jsonDecode(valuesJson) as Map).cast<String, Object?>();
  try {
    return jsonEncode({
      'ok': true,
      'effect': EffectDraft.build(kind, values).toJson(),
    });
  } on EffectFieldError catch (e) {
    return jsonEncode({'ok': false, 'field': e.field, 'error': e.code});
  }
}

/// Las partes de cada efecto de la lista, alineadas con la entrada: `parts` es
/// null cuando el motor no lo describe (`effectParts`).
String effectPartsJs(String effectsJson, String catalogJson) {
  final repo = _repoPara(catalogJson);
  return jsonEncode([
    for (final raw in (jsonDecode(effectsJson) as List))
      {
        'type': (raw as Map)['type'],
        'parts':
            effectParts(Effect.fromJson(raw.cast<String, dynamic>()), repo),
      },
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
/// caído, si está maltrecho y sus PG de la fuente que corresponde. Los PG
/// temporales (`temp`) de un jugador entran en [playersHpJson] (opcional, 0 si
/// falta) porque viven en su ficha; los del resto salen del encuentro.
String encounter(String encounterJson, String playersHpJson) {
  final e = Encounter.fromJson(
      (jsonDecode(encounterJson) as Map).cast<String, dynamic>());
  final players = {
    for (final MapEntry(:key, :value)
        in (jsonDecode(playersHpJson) as Map).cast<String, Map>().entries)
      key: (
        current: value['current'] as int,
        max: value['max'] as int,
        temp: value['temp'] as int? ?? 0,
      ),
  };
  final current = e.current;
  final standing =
      e.standing({for (final p in players.entries) p.key: p.value.current});
  ({int current, int max})? hpOf(Combatant c) => c.kind == CombatantKind.player
      ? switch (players[c.memberId]) {
          final p? => (current: p.current, max: p.max),
          null => null,
        }
      : c.maxHp > 0
          ? (current: c.currentHp, max: c.maxHp)
          : null;
  int tempOf(Combatant c) => c.kind == CombatantKind.player
      ? players[c.memberId]?.temp ?? 0
      : c.tempHp;
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
            'temp': tempOf(c),
          },
    ],
  });
}

/// Contador de los ids sin semilla: dart2js da milisegundos y dos ids pedidos
/// en el mismo milisegundo chocarían.
int _contadorIds = 0;

Map<String, EncounterNpc> _npcsPorId(String npcEntriesJson) => {
      for (final raw
          in (jsonDecode(npcEntriesJson) as List).cast<Map<String, dynamic>>())
        if (EncounterNpc.fromEntry(raw) case final e) e.npc.id: e,
    };

/// Una acción sobre el combate de la campaña (`EncounterActions`): entra el
/// documento (`'null'` si no hay combate abierto) y la acción, y sale el
/// encuentro listo para `PUT .../encounter`, o `null` si no hay nada que
/// guardar. Con [seed] las tiradas y los ids son deterministas (`prefijo-n`,
/// con `n` desde 0 en cada llamada); sirve para la prueba de paridad.
String encounterAct(
  String catalogJson,
  String encounterJson,
  String actionJson, [
  int? seed,
]) {
  final current = jsonDecode(encounterJson);
  var n = 0;
  final result = EncounterActions.apply(
    current == null
        ? null
        : Encounter.fromJson((current as Map).cast<String, dynamic>()),
    _repoPara(catalogJson),
    (jsonDecode(actionJson) as Map).cast<String, dynamic>(),
    newId: seed == null
        ? (p) => '$p-${DateTime.now().microsecondsSinceEpoch}-${_contadorIds++}'
        : (p) => '$p-${n++}',
    random: seed == null ? null : Random(seed),
  );
  return jsonEncode(result?.toJson());
}

/// Lo que la planilla del combate y la banda de dificultad muestran, resuelto
/// (`encounterDetails`). [membersJson] es `{memberId: {level, armorClass}}`;
/// [npcEntriesJson], la lista cruda de PNJ de la campaña o de la biblioteca.
String encounterDetailsJs(
  String catalogJson,
  String encounterJson,
  String membersJson,
  String npcEntriesJson,
) =>
    jsonEncode(
      encounterDetails(
        Encounter.fromJson(
            (jsonDecode(encounterJson) as Map).cast<String, dynamic>()),
        members: {
          for (final MapEntry(:key, :value)
              in (jsonDecode(membersJson) as Map).cast<String, Map>().entries)
            key: (
              level: value['level'] as int,
              armorClass: value['armorClass'] as int,
            ),
        },
        npcs: _npcsPorId(npcEntriesJson),
        repo: _repoPara(catalogJson),
      ),
    );

/// La iniciativa propuesta para cada combatiente (`suggestInitiatives`).
String encounterInitiatives(
  String catalogJson,
  String encounterJson,
  String npcEntriesJson, [
  int? seed,
]) =>
    jsonEncode(
      suggestInitiatives(
        Encounter.fromJson(
            (jsonDecode(encounterJson) as Map).cast<String, dynamic>()),
        npcs: _npcsPorId(npcEntriesJson),
        repo: _repoPara(catalogJson),
        random: seed == null ? null : Random(seed),
      ),
    );

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

/// Los compañeros de la ficha para leerlos (`companionsView`): `{options,
/// instances, orphans}`. Las acciones sobre ellos son las de [act].
String companionsViewJs(String characterJson, String catalogJson) => jsonEncode(
      companionsView(
        Character.fromJson(jsonDecode(characterJson) as Map<String, dynamic>),
        _repoPara(catalogJson),
      ),
    );

/// Cómo se vería una forma invocada con un espacio de [level]
/// (`companionPreview`): `{profile, row}`, o `null` si no existe.
String companionPreviewJs(
  String characterJson,
  String catalogJson,
  String option,
  String creature,
  int level,
) =>
    jsonEncode(
      companionPreview(
        Character.fromJson(jsonDecode(characterJson) as Map<String, dynamic>),
        _repoPara(catalogJson),
        option,
        creature,
        level,
      ),
    );

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

/// Confirma el creador: el personaje listo para guardar, con su id y los PG al
/// máximo. Lanza si falta algo (`CreationDraft.confirm`). [unnamed] es el nombre
/// si no se escribió ninguno, en el idioma del cliente. [replacingJson] (vacío
/// si no hay) es el personaje que se rehace: conserva su id, retratos y diario.
/// `Character.fromJson` lo migra, igual que en [act].
String creationConfirm(
  String catalogJson,
  String draftJson,
  String unnamed, [
  String replacingJson = '',
]) =>
    jsonEncode(
      CreationDraft.fromJson(
        _repoPara(catalogJson),
        jsonDecode(draftJson) as Map<String, dynamic>,
      )
          .confirm(
            unnamed: unnamed,
            replacing: replacingJson.isEmpty
                ? null
                : Character.fromJson(
                    jsonDecode(replacingJson) as Map<String, dynamic>,
                  ),
          )
          .toJson(),
    );

/// Una ronda del Quiz: `(personaje | null, catálogo, semilla)` → lista de
/// `QuizQuestion.toJson()`. Sin personaje, la de reglas generales. Como
/// `compute`, el cliente pasa el JSON y el motor arma las preguntas: la UI no
/// sabe de dónde salen.
String quizRoundJs(String? characterJson, String catalogJson, int seed) =>
    jsonEncode([
      for (final q in quizRound(
        characterJson == null
            ? null
            : Character.fromJson(
                jsonDecode(characterJson) as Map<String, dynamic>),
        _repoPara(catalogJson),
        seed: seed,
      ))
        q.toJson(),
    ]);

/// El personaje de ejemplo de la cuenta vacía ([demoSagan]).
String demoCharacter() => jsonEncode(demoSagan().toJson());

/// El archivo `dnd_homebrew` de [contentJson] (`{categoría: [documento]}`):
/// `{"fileName", "text"}`. [nowIso] es la hora de la exportación (ISO 8601); el
/// motor no lee el reloj, así que un mismo instante da el mismo archivo.
String homebrewExport(String contentJson, String nowIso) {
  final raw = (jsonDecode(contentJson) as Map).cast<String, dynamic>();
  final content = {
    for (final c in transfer.homebrewCategories)
      c: [
        for (final doc in (raw[c] as List? ?? const []))
          (doc as Map).cast<String, dynamic>(),
      ],
  };
  final now = DateTime.parse(nowIso);
  return jsonEncode({
    'fileName': transfer.homebrewExportFileName(now),
    'text': jsonEncode(transfer.homebrewExportEnvelope(content, now)),
  });
}

/// Lee y valida un archivo de homebrew a importar contra el catálogo
/// **fusionado** (el oficial más lo propio): `{"ok": true, "content",
/// "counts", "names", "collisions"}`, o `{"ok": false, "error"}` con el mensaje
/// del motor. Los choques son las entradas del archivo que pisan homebrew
/// propio (origen `homebrew` en ese catálogo). Nada se escribe.
String homebrewImportCheck(String text, String catalogJson) {
  final noEsHomebrew = jsonEncode({
    'ok': false,
    'error': localized(
      'El archivo no es una exportación de homebrew válida.',
      'The file isn’t a valid homebrew export.',
    ),
  });
  // Un archivo que ni siquiera es JSON diría el error del parser de Dart
  // («Unexpected character…»), que no le sirve a nadie: es lo mismo que cualquier
  // otro archivo que no es un homebrew.
  try {
    jsonDecode(text);
  } on FormatException {
    return noEsHomebrew;
  }
  try {
    final content = transfer.parseHomebrewImport(text);
    final repo = _repoPara(catalogJson);
    transfer.validateHomebrewInventoryIds(content, repo);
    Set<String> propios<T>(Map<String, T> m, ContentSource Function(T) src) => {
          for (final e in m.entries)
            if (src(e.value) == ContentSource.homebrew) e.key,
        };
    final ownIds = {
      'weapons': propios(repo.weapons, (e) => e.source),
      'armor': propios(repo.armor, (e) => e.source),
      'items': propios(repo.items, (e) => e.source),
      'feats': propios(repo.feats, (e) => e.source),
      'races': propios(repo.races, (e) => e.source),
      'backgrounds': propios(repo.backgrounds, (e) => e.source),
      'spells': propios(repo.spells, (e) => e.source),
      'creatures': propios(repo.creatures, (e) => e.source),
    };
    return jsonEncode({
      'ok': true,
      'content': content,
      'counts': {for (final e in content.entries) e.key: e.value.length},
      'names': {
        for (final e in content.entries)
          e.key: [for (final d in e.value) '${d['name'] ?? d['id']}'],
      },
      'collisions': transfer.countHomebrewCollisions(content, ownIds),
    });
  } on FormatException catch (e) {
    return jsonEncode({'ok': false, 'error': e.message});
  } on UnsupportedDataVersionException catch (e) {
    return jsonEncode({'ok': false, 'error': e.toString()});
  } on TypeError catch (_) {
    // Un `content` que no es lista de objetos: el archivo está dañado.
    return noEsHomebrew;
  }
}

/// El bloque vacío de una criatura propia (`Npc.emptyBlock`), para el
/// formulario de «Nueva criatura».
String homebrewNewCreature() => jsonEncode(Npc.emptyBlock('').toJson());

/// El id nuevo de un homebrew a partir de su nombre (`homebrewId`).
String homebrewIdFor(String name) => transfer.homebrewId(name);

/// Una copia propia de [json] con id y nombre nuevos (`homebrewCopy`).
String homebrewCopyJs(String json) => jsonEncode(
      transfer.homebrewCopy((jsonDecode(json) as Map).cast<String, dynamic>()),
    );

/// Los ids de las fichas de [charactersJson] (lista de documentos) que mencionan
/// [contentId] (`charactersUsing`): lo que el diálogo de borrar nombra. Una
/// ficha de una versión que este motor no entiende no se puede leer y no se
/// cuenta, como en la lista de Mis personajes.
String charactersUsingJs(String contentId, String charactersJson) {
  final characters = <Character>[];
  for (final raw in (jsonDecode(charactersJson) as List)) {
    try {
      characters.add(Character.fromJson((raw as Map).cast<String, dynamic>()));
    } on Object {
      continue;
    }
  }
  return jsonEncode([
    for (final c in charactersUsing(contentId, characters)) c.id,
  ]);
}

void main() {
  final motor = JSObject();
  motor['homebrewExport'] = homebrewExport.toJS;
  motor['homebrewImportCheck'] = homebrewImportCheck.toJS;
  motor['homebrewNewCreature'] = homebrewNewCreature.toJS;
  motor['homebrewId'] = homebrewIdFor.toJS;
  motor['homebrewCopy'] = homebrewCopyJs.toJS;
  motor['charactersUsing'] = charactersUsingJs.toJS;
  motor['creationConfirm'] = creationConfirm.toJS;
  motor['creation'] = creation.toJS;
  motor['demoCharacter'] = demoCharacter.toJS;
  motor['quizRound'] = quizRoundJs.toJS;
  motor['act'] = act.toJS;
  motor['companionsView'] = companionsViewJs.toJS;
  motor['companionPreview'] = companionPreviewJs.toJS;
  motor['spellEdit'] = spellEdit.toJS;
  motor['innateCantripOptions'] = innateCantripOptions.toJS;
  motor['magicItemPlans'] = magicItemPlans.toJS;
  motor['magicBaseOptions'] = magicBaseOptions.toJS;
  motor['compute'] = compute.toJS;
  motor['choicesView'] = choicesViewJs.toJS;
  motor['portraitPrompt'] = portraitPromptJs.toJS;
  motor['portraitStyles'] = portraitStylesJs.toJS;
  motor['migrateCharacter'] = migrateCharacter.toJS;
  motor['setLanguage'] = setLanguage.toJS;
  motor['applyTranslation'] = applyTranslation.toJS;
  motor['vocabularyLabel'] = vocabularyLabelFor.toJS;
  motor['inventory'] = inventory.toJS;
  motor['chapterGrants'] = chapterGrants.toJS;
  motor['canLevelUp'] = canLevelUp.toJS;
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
  motor['npcImportMissing'] = npcImportMissing.toJS;
  motor['newNpc'] = newNpc.toJS;
  motor['npcEdit'] = npcEdit.toJS;
  motor['npcPortraitPrompt'] = npcPortraitPrompt.toJS;
  motor['npcBlock'] = npcBlock.toJS;
  motor['creatureForm'] = creatureForm.toJS;
  motor['creatureDraft'] = creatureDraft.toJS;
  motor['creatureFormOptions'] = creatureFormOptions.toJS;
  motor['featForm'] = featForm.toJS;
  motor['featDraft'] = featDraft.toJS;
  motor['featNew'] = featNew.toJS;
  motor['raceForm'] = raceForm.toJS;
  motor['raceDraft'] = raceDraft.toJS;
  motor['raceNew'] = raceNew.toJS;
  motor['backgroundForm'] = backgroundForm.toJS;
  motor['backgroundDraft'] = backgroundDraft.toJS;
  motor['backgroundNew'] = backgroundNew.toJS;
  motor['weaponForm'] = weaponForm.toJS;
  motor['weaponDraft'] = weaponDraft.toJS;
  motor['weaponNew'] = weaponNew.toJS;
  motor['armorForm'] = armorForm.toJS;
  motor['armorDraft'] = armorDraft.toJS;
  motor['armorNew'] = armorNew.toJS;
  motor['armorWithCategory'] = armorWithCategory.toJS;
  motor['itemForm'] = itemForm.toJS;
  motor['itemDraft'] = itemDraft.toJS;
  motor['itemNew'] = itemNew.toJS;
  motor['itemWithRarity'] = itemWithRarity.toJS;
  motor['itemWithBaseKind'] = itemWithBaseKind.toJS;
  motor['itemBaseOptions'] = itemBaseOptions.toJS;
  motor['spellForm'] = spellForm.toJS;
  motor['spellDraft'] = spellDraft.toJS;
  motor['spellNew'] = spellNew.toJS;
  motor['homebrewFormOptions'] = homebrewFormOptions.toJS;
  motor['homebrewRules'] = homebrewRules.toJS;
  motor['effectKinds'] = effectKinds.toJS;
  motor['effectBuild'] = effectBuild.toJS;
  motor['effectParts'] = effectPartsJs.toJS;
  motor['encounter'] = encounter.toJS;
  motor['encounterAct'] = encounterAct.toJS;
  motor['encounterDetails'] = encounterDetailsJs.toJS;
  motor['encounterInitiatives'] = encounterInitiatives.toJS;
  motor['musicSource'] = musicSource.toJS;
  globalContext['dndEngine'] = motor;
}
