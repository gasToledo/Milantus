part of 'app.dart';

// --- Reparto de objetos al cerrar un capítulo, y la bandeja del jugador ---
//
// El DM decide a quién le toca cada objeto, pero **no escribe ninguna ficha**:
// deja un regalo en la bandeja del jugador (`item_grants`) y un aviso, y el
// jugador lo agrega a su mochila cuando lo acepta. La frontera de `modo-dm.md`
// se mantiene porque el último paso, el que toca la ficha, es de su dueño.

/// Un objeto repartido a un miembro, con el documento de homebrew si lo es.
class _AllocatedItem {
  final ChapterItem item;

  /// Copia del documento del homebrew **del DM**, leída por el servidor: nunca
  /// viene del pedido. `null` para un objeto del catálogo oficial.
  final Map<String, dynamic>? homebrewDocument;

  const _AllocatedItem(this.item, this.homebrewDocument);

  /// Lo que se guarda en `item_grants.item`.
  Map<String, dynamic> toStoredJson() => {
    'category': item.category,
    'itemId': item.itemId,
    'name': item.name,
    if (item.baseItemId != null) 'baseItemId': item.baseItemId,
    'quantity': item.quantity,
    'homebrewDocument': ?homebrewDocument,
  };
}

class _MemberAllocation {
  final List<_AllocatedItem> items = [];
  final List<String> free = [];
}

class _Allocations {
  final Map<String, _MemberAllocation> byMember;
  final List<String> unionFree;
  final List<ChapterItem> unionCatalog;

  const _Allocations(this.byMember, this.unionFree, this.unionCatalog);
}

/// Lee un objeto del pedido y resuelve su documento si es de homebrew. Lo usan
/// el reparto al cerrar un capítulo y «Dar objeto» desde la Mesa, para que las
/// dos validen igual. [ownHomebrew] lee el homebrew de la cuenta del DM, una
/// sola vez y solo si hace falta. Un error es un 400.
Future<_AllocatedItem> _allocatedItem(
  Object? rawItem,
  Future<Map<String, List<Map<String, dynamic>>>> Function() ownHomebrew,
) async {
  final item = ChapterItem.tryFromJson(rawItem);
  if (item == null) throw const FormatException('Objeto inválido.');
  Map<String, dynamic>? document;
  if (item.homebrew) {
    // Nunca se confía en un documento del pedido: se busca en el homebrew de
    // quien reparte, por categoría e id.
    document = (await ownHomebrew())[item.category]
        ?.where((d) => d['id'] == item.itemId)
        .firstOrNull;
    if (document == null) {
      throw FormatException(
        'El objeto propio «${item.name}» no está en tu homebrew.',
      );
    }
  }
  return _AllocatedItem(item, document);
}

/// Valida `allocations` contra la mesa y el homebrew del DM. Cualquier error es
/// un 400 y se detecta antes de escribir nada.
Future<_Allocations> _parseAllocations(
  Object? raw, {
  required List<CampaignMember> members,
  required HomebrewRepository homebrew,
  required String dmUserId,
}) async {
  if (raw is! List) {
    throw const FormatException('"allocations" debe ser una lista.');
  }
  final memberIds = {for (final m in members) m.memberId};
  // El homebrew se lee una sola vez y solo si hace falta.
  Map<String, List<Map<String, dynamic>>>? own;
  final byMember = <String, _MemberAllocation>{};
  final unionCatalog = <String, ChapterItem>{};
  final unionFree = <String>[];

  for (final entry in raw) {
    if (entry is! Map) {
      throw const FormatException('Cada reparto debe ser un objeto.');
    }
    final memberId = entry['memberId'];
    if (memberId is! String || !memberIds.contains(memberId)) {
      throw const FormatException(
        'Un personaje del reparto no está en la mesa de la campaña.',
      );
    }
    final mine = byMember.putIfAbsent(memberId, _MemberAllocation.new);

    for (final rawItem in (entry['items'] as List? ?? const [])) {
      final allocated = await _allocatedItem(rawItem, () async {
        return own ??= await homebrew.listForUser(dmUserId);
      });
      final item = allocated.item;
      mine.items.add(allocated);
      // La unión se arma sin repetidos: el mismo objeto a dos personajes es una
      // sola línea del capítulo.
      unionCatalog.putIfAbsent(
        '${item.category}/${item.itemId}/${item.baseItemId}',
        () => item,
      );
    }
    for (final text in (entry['freeItems'] as List? ?? const [])) {
      if (text is! String) {
        throw const FormatException('Los objetos libres deben ser texto.');
      }
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      mine.free.add(trimmed);
      if (!unionFree.contains(trimmed)) unionFree.add(trimmed);
    }
  }
  return _Allocations(byMember, unionFree, unionCatalog.values.toList());
}

// --- Bandeja del jugador ---

Future<Response> _listItemGrantsHandler(
  Request request,
  CharacterRepository characters,
  ItemGrantRepository itemGrants,
) async {
  final id = requireSafePathSegment(
    request.params['id']!,
    label: 'id de personaje',
  );
  if (!await characters.exists(request.userId, id)) {
    return _notFound('character_not_found');
  }
  final grants = await itemGrants.listFor(request.userId, id);
  // Sin el documento: el cliente solo necesita saber qué es y de dónde viene.
  return _jsonOk({
    'grants': [for (final g in grants) g.toPublicJson()],
  });
}

/// El jugador acepta un regalo. Si es de homebrew, se le crea **su copia** del
/// documento en su cuenta (con consentimiento: acepta él, y es contenido que el
/// DM eligió darle), y el cliente agrega el objeto a la mochila con esa copia.
///
/// No borra la fila: si agregar el objeto a la ficha falla, el regalo sigue
/// ahí para reintentar. La fila se saca recién con `DELETE`, y reclamar dos
/// veces no duplica la copia porque su id sale del regalo.
Future<Response> _claimItemGrantHandler(
  Request request,
  ItemGrantRepository itemGrants,
  HomebrewRepository homebrew,
) async {
  final id = request.params['id']!;
  if (!isUuid(id)) return _notFound('item_grant_not_found');
  final grant = await itemGrants.find(request.userId, id);
  if (grant == null) return _notFound('item_grant_not_found');

  var itemId = grant.item['itemId'] as String;
  final document = grant.item['homebrewDocument'];
  if (document is Map) {
    // ponytail: cada regalo de homebrew crea su propia copia en la cuenta del
    // jugador, sin deduplicar: dos regalos de la misma «Hoja del Cuervo» son
    // dos entradas. Sirve mientras se reparta de a poco; si molesta, buscar una
    // copia previa por contenido (o por el id de origen) antes de crear.
    itemId = 'regalo-$id';
    await homebrew.upsert(
      request.userId,
      grant.item['category'] as String,
      itemId,
      {...document.cast<String, dynamic>(), 'id': itemId},
    );
  }
  return _jsonOk({
    'itemId': itemId,
    'baseItemId': grant.item['baseItemId'],
    'quantity': grant.item['quantity'] ?? 1,
  });
}

Future<Response> _resolveItemGrantHandler(
  Request request,
  ItemGrantRepository itemGrants,
) async {
  final id = request.params['id']!;
  if (!isUuid(id) || !await itemGrants.delete(request.userId, id)) {
    return _notFound('item_grant_not_found');
  }
  return _jsonOk({'status': 'ok'});
}

/// Da objetos a un personaje de la mesa **fuera de un capítulo** (`chapterName`
/// vacío). Deja los regalos en la bandeja del jugador y un aviso; la ficha no se
/// toca. La autorización es la de Inspiración Heroica: `campaigns.find` y
/// `findMember` con la cuenta de quien pide, y lo ajeno responde como lo
/// inexistente. Sin texto libre: solo se entrega lo que existe.
Future<Response> _giveItemsHandler(
  Request request,
  RepositoryTransactionRunner transactions,
) async {
  final campaignId = requireSafePathSegment(
    request.params['id']!,
    label: 'id de campaña',
  );
  final memberId = requireSafePathSegment(
    request.params['memberId']!,
    label: 'id de vínculo',
  );
  final body = await _readOptionalJsonBody(request);
  final raw = body['items'];
  if (raw is! List || raw.isEmpty) {
    throw const FormatException('"items" debe ser una lista con objetos.');
  }
  return transactions.run((repositories) async {
    final campaign = await repositories.campaigns.find(
      request.userId,
      campaignId,
    );
    if (campaign == null) return _notFound('campaign_not_found');
    final member = await repositories.campaigns.findMember(
      dmUserId: request.userId,
      campaignId: campaignId,
      memberId: memberId,
    );
    if (member == null) return _notFound('character_not_found');

    Map<String, List<Map<String, dynamic>>>? own;
    final items = [
      for (final rawItem in raw)
        await _allocatedItem(rawItem, () async {
          return own ??= await repositories.homebrew.listForUser(
            request.userId,
          );
        }),
    ];
    await repositories.itemGrants.addAll(
      member.ownerUserId,
      member.character.id,
      campaign.name,
      '',
      [for (final item in items) item.toStoredJson()],
    );
    await repositories.events.append(member.ownerUserId, 'item_granted', {
      'characterName': member.character.name,
      'campaignName': campaign.name,
      'grantsItems': [for (final item in items) item.item.label],
      'hasGrants': true,
    });
    return _jsonOk({'status': 'ok'});
  });
}
