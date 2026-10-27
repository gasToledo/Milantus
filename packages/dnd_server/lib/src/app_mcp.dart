part of 'app.dart';

/// Lo que el MCP necesita además de los repositorios.
class McpDependencies {
  final McpTokenVerifier verifier;

  /// `sub` de Zitadel → cuenta, la misma función del login web.
  final Future<String> Function(String subject) resolveAccount;
  final McpAuditRepository audit;

  /// El catálogo SRD, cargado una vez al arrancar. El homebrew de cada cuenta
  /// se le suma en cada llamada que lo necesita.
  final ContentRepository content;
  final Uri publicBaseUrl;
  final Uri issuer;
  final String projectId;

  const McpDependencies({
    required this.verifier,
    required this.resolveAccount,
    required this.audit,
    required this.content,
    required this.publicBaseUrl,
    required this.issuer,
    required this.projectId,
  });
}

/// Las herramientas del MCP. Llaman a los repositorios con la cuenta del
/// token, así que la autorización es la del `WHERE` de siempre: lo ajeno no
/// aparece, y responde igual que lo que no existe.
///
/// Ninguna calcula una regla: la ficha sale de `CharacterCompiler` y los
/// cambios de combate, de `CombatOps`, igual que en la app.
List<McpTool> _mcpTools({
  required McpDependencies mcp,
  required CharacterRepository characters,
  required CampaignRepository campaigns,
  required ChapterRepository chapters,
  required NoteRepository notes,
  required EncounterRepository encounters,
  required EventRepository events,
  required NpcRepository npcs,
  required RepositoryTransactionRunner transactions,
  required HomebrewRepository homebrew,
}) {
  /// El catálogo de la cuenta: el oficial más su homebrew, que pisa lo
  /// oficial con el mismo id, como en la app.
  Future<ContentRepository> contentFor(String userId) async {
    final own = await homebrew.listForUser(userId);
    List<Map<String, dynamic>> of(String c) => own[c] ?? const [];
    return ContentRepository()
      ..addAll(mcp.content)
      ..addAll(
        ContentRepository.fromJsonPacks(
          weapons: of('weapons'),
          armor: of('armor'),
          items: of('items'),
          feats: of('feats'),
          races: of('races'),
          backgrounds: of('backgrounds'),
          spells: of('spells'),
          creatures: of('creatures'),
        ),
      );
  }

  Future<Character> ownCharacter(String userId, McpArgs args) async {
    final id = requireSafePathSegment(args.str('personajeId'));
    final c = await characters.find(userId, id);
    if (c == null) throw const McpToolError('Personaje no encontrado.');
    return c;
  }

  /// La ficha como la ve la app: compilada, con la Forma Salvaje y el
  /// Cansancio encima, en ese orden (ver `sheet_screen.dart`).
  ComputedSheet sheetOf(Character c, ContentRepository repo) {
    final base = CharacterCompiler(repo).compile(c);
    final beastId = c.combat.wildShapeCreatureId;
    final beast = beastId == null ? null : repo.creature(beastId);
    return applyExhaustion(
      beast == null ? base : applyWildShape(base, beast),
      c.combat.exhaustion,
    );
  }

  Map<String, dynamic> hpOf(Character c, ComputedSheet s) => {
    'pgActuales': c.combat.currentHp,
    'pgMaximos': s.maxHp,
    'pgTemporales': c.combat.tempHp,
    'condiciones': c.combat.conditions.toList(),
    'cansancio': c.combat.exhaustion,
  };

  /// Guarda un cambio de combate de un personaje propio. `upsert` lleva la
  /// cuenta en la clave: no hay forma de escribir la ficha de otra.
  ///
  /// ponytail: pisa el documento entero, como la app. Si la ficha está
  /// abierta en el navegador, el próximo guardado de la app pisa este cambio;
  /// si molesta, versionar el documento y rechazar el guardado viejo.
  Future<McpResult> saveCombat(
    String userId,
    Character c,
    ComputedSheet s,
    String summary,
  ) async {
    await characters.upsert(userId, c);
    return McpResult({'personajeId': c.id, ...hpOf(c, s)}, summary);
  }

  Future<Campaign> ownCampaign(String userId, String id) async {
    final campaign = await campaigns.find(userId, requireSafePathSegment(id));
    if (campaign == null) throw const McpToolError('Campaña no encontrada.');
    return campaign;
  }

  Map<String, dynamic> str(String description, [Iterable<String>? values]) => {
    'type': 'string',
    'description': description,
    if (values != null) 'enum': values.toList(),
  };

  final personajeId = str('Id del personaje, de listar_personajes.');
  final campanaId = str('Id de la campaña, de listar_campanas.');
  const npcTexts = {
    'apariencia': 'appearance',
    'formaDeHablar': 'speech',
    'trasfondo': 'background',
  };
  final npcProps = {
    'apariencia': str('Cómo se ve.'),
    'formaDeHablar': str('Cómo habla.'),
    'trasfondo': str('Historia y motivaciones.'),
    'etiquetas': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'Etiquetas libres: aliado, tabernero, Neverwinter…',
    },
  };

  const catalogKinds = [
    'conjuros',
    'criaturas',
    'objetos_magicos',
    'dotes',
    'clases',
    'especies',
  ];

  return [
    McpTool(
      name: 'listar_personajes',
      title: 'Listar personajes',
      description:
          'Los personajes jugadores de la cuenta, con nivel y especie. Usala '
          'para conseguir el personajeId que piden las demás herramientas.',
      properties: {'cursor': mcpCursorProperty},
      scope: McpScope.lectura,
      run: (who, args) async {
        final all = await characters.listForUser(who.userId);
        final page = mcpPage([
          for (final s in all)
            {
              'id': s.character.id,
              'nombre': s.character.name,
              'nivel': s.character.totalLevel,
              'especie': s.character.raceId,
            },
        ], args);
        return McpResult(page, '${all.length} personajes.');
      },
    ),
    McpTool(
      name: 'ver_personaje',
      title: 'Ver ficha',
      description:
          'La ficha calculada de un personaje propio: CA, PG, velocidad, '
          'características, salvaciones, ataques, recursos con sus usos y '
          'conjuros. Los números ya vienen calculados por Milantus.',
      properties: {'personajeId': personajeId},
      required: ['personajeId'],
      scope: McpScope.lectura,
      run: (who, args) async {
        final c = await ownCharacter(who.userId, args);
        final s = sheetOf(c, await contentFor(who.userId));
        return McpResult(
          {
            'id': c.id,
            'nombre': c.name,
            'nivel': s.level,
            'clases': s.classLevels,
            'especie': c.raceId,
            'ca': s.armorClass,
            ...hpOf(c, s),
            'velocidad': s.speed,
            'iniciativa': s.initiative,
            'bonoCompetencia': s.proficiencyBonus,
            'caracteristicas': {
              for (final a in Ability.values)
                a.name: {
                  'puntuacion': s.abilityScores[a],
                  'modificador': s.abilityModifiers[a],
                  'salvacion': s.savingThrow(a),
                },
            },
            'percepcionPasiva': s.passivePerception,
            'ataques': [for (final a in s.attacks) a.toJson()],
            'recursos': [
              for (final r in s.resources)
                {...r.toJson(), 'usados': c.combat.resourceUsage[r.key] ?? 0},
            ],
            if (s.spellcasting != null) 'conjuros': s.spellcasting!.toJson(),
          },
          '${c.name}, nivel ${s.level}: CA ${s.armorClass}, PG ${c.combat.currentHp}/${s.maxHp}.',
        );
      },
    ),
    McpTool(
      name: 'listar_campanas',
      title: 'Listar campañas',
      description:
          'Las campañas que la cuenta dirige (rol «dm») y aquellas en que '
          'juega con alguno de sus personajes (rol «jugador»).',
      properties: {'cursor': mcpCursorProperty},
      scope: McpScope.lectura,
      run: (who, args) async {
        final items = <Map<String, dynamic>>[
          for (final c in await campaigns.listForDm(who.userId))
            {
              'id': c.id,
              'nombre': c.name,
              'estado': c.state.toJson(),
              'rol': 'dm',
            },
        ];
        for (final s in await characters.listForUser(who.userId)) {
          for (final p in await campaigns.listPlayerCampaignProjection(
            ownerUserId: who.userId,
            characterId: s.character.id,
          )) {
            items.add({
              'id': p.campaign.id,
              'nombre': p.campaign.name,
              'estado': p.campaign.state.toJson(),
              'rol': 'jugador',
              'personajeId': s.character.id,
            });
          }
        }
        return McpResult(mcpPage(items, args), '${items.length} campañas.');
      },
    ),
    McpTool(
      name: 'ver_campana',
      title: 'Ver campaña',
      description:
          'Una campaña. Si la dirige la cuenta, la vista del DM: capítulos, '
          'jugadores, cuaderno y PNJ. Si juega en ella, pasá también el '
          'personajeId y devuelve lo que ve ese jugador.',
      properties: {
        'campanaId': campanaId,
        'personajeId': str('Solo como jugador: el personaje con que juega.'),
      },
      required: ['campanaId'],
      scope: McpScope.lectura,
      run: (who, args) async {
        final id = requireSafePathSegment(args.str('campanaId'));
        final own = await campaigns.find(who.userId, id);
        if (own != null) {
          final members = await campaigns.listMembers(who.userId, id);
          final npcList = await npcs.listForCampaign(who.userId, id);
          return McpResult({
            'rol': 'dm',
            'campana': own.toJson(),
            'capitulos': [
              for (final c in await chapters.listFor(who.userId, id))
                c.toJson(),
            ],
            // Como el handler de miembros: campo por campo, sin la cuenta
            // dueña de cada personaje.
            'jugadores': [
              for (final m in members)
                {'nombre': m.character.name, 'nivel': m.character.totalLevel},
            ],
            'notas': [
              for (final n in await notes.listFor(who.userId, id)) n.toJson(),
            ],
            'pnj': [
              for (final e in npcList)
                {
                  'id': e.npc.id,
                  'nombre': e.npc.name,
                  'estado': e.status.toJson(),
                },
            ],
          }, '${own.name}: ${members.length} jugadores.');
        }
        final characterId = args.optStr('personajeId');
        if (characterId == null) {
          throw const McpToolError('Campaña no encontrada.');
        }
        final projections = await campaigns.listPlayerCampaignProjection(
          ownerUserId: who.userId,
          characterId: requireSafePathSegment(characterId),
        );
        final p = projections.where((p) => p.campaign.id == id).firstOrNull;
        if (p == null) throw const McpToolError('Campaña no encontrada.');
        // La misma poda que `_listPlayerCampaignsHandler`.
        return McpResult({
          'rol': 'jugador',
          'campana': p.campaign.playerView(),
          'grupo': p.party,
          'capitulos': [
            for (final c in p.chapters)
              if (c.state == ChapterState.completed) _playerChapterJson(c),
          ],
          'batallas': [for (final l in p.battles) l.playerView().toJson()],
        }, '${p.campaign.name}, como jugador.');
      },
    ),
    McpTool(
      name: 'ver_encuentro',
      title: 'Ver combate',
      description:
          'El combate en curso. Como DM, pasá campanaId y devuelve el '
          'encuentro entero con su iniciativa. Como jugador, pasá personajeId '
          'y devuelve lo que ese jugador ve del turno.',
      properties: {'campanaId': campanaId, 'personajeId': personajeId},
      scope: McpScope.lectura,
      run: (who, args) async {
        if (args.has('campanaId') == args.has('personajeId')) {
          throw const McpToolError('Pasá campanaId o personajeId, uno solo.');
        }
        if (args.has('campanaId')) {
          final id = requireSafePathSegment(args.str('campanaId'));
          final encounter = await encounters.find(who.userId, id);
          if (encounter == null) {
            throw const McpToolError('No hay ningún combate en curso.');
          }
          return McpResult({
            'encuentro': encounter.toJson(),
          }, 'Combate en curso.');
        }
        final c = await ownCharacter(who.userId, args);
        final turn = await encounters.turnFor(
          userId: who.userId,
          characterId: c.id,
        );
        return McpResult({'turno': turn.toJson()}, 'Turno de ${c.name}.');
      },
    ),
    McpTool(
      name: 'buscar_catalogo',
      title: 'Buscar en el catálogo',
      description:
          'Busca en el catálogo SRD 2024 más el homebrew de la cuenta. Con '
          'texto filtra por nombre; con id devuelve la entrada completa.',
      properties: {
        'tipo': str('Qué buscar.', catalogKinds),
        'texto': str('Parte del nombre, sin importar mayúsculas.'),
        'id': str('Id exacto, para ver la entrada completa.'),
        'cursor': mcpCursorProperty,
      },
      required: ['tipo'],
      scope: McpScope.lectura,
      run: (who, args) async {
        final kind = args.oneOf('tipo', catalogKinds);
        final repo = await contentFor(who.userId);
        final Map<
          String,
          ({
            String name,
            Map<String, dynamic> Function() full,
            Map<String, dynamic> extra,
          })
        >
        all = switch (kind) {
          'conjuros' => {
            for (final e in repo.spells.values)
              e.id: (
                name: e.name,
                full: e.toJson,
                extra: {'nivel': e.level, 'escuela': e.school},
              ),
          },
          'criaturas' => {
            for (final e in repo.creatures.values)
              e.id: (name: e.name, full: e.toJson, extra: const {}),
          },
          'objetos_magicos' => {
            for (final e in repo.items.values)
              if (e.rarity != null)
                e.id: (
                  name: e.name,
                  full: e.toJson,
                  extra: {'rareza': e.rarity},
                ),
          },
          'dotes' => {
            for (final e in repo.feats.values)
              e.id: (name: e.name, full: e.toJson, extra: const {}),
          },
          'clases' => {
            for (final e in repo.classes.values)
              e.id: (
                name: e.name,
                // La clase no se serializa entera: es lo único del catálogo
                // que no se carga como homebrew.
                full: () => {
                  'id': e.id,
                  'name': e.name,
                  'hitDie': e.hitDie,
                  'savingThrows': [for (final a in e.savingThrows) a.name],
                },
                extra: const {},
              ),
          },
          _ => {
            for (final e in repo.races.values)
              e.id: (name: e.name, full: e.toJson, extra: const {}),
          },
        };
        final id = args.optStr('id');
        if (id != null) {
          final entry = all[id];
          if (entry == null)
            throw const McpToolError('No está en el catálogo.');
          return McpResult({'entrada': entry.full()}, entry.name);
        }
        final text = args.optStr('texto')?.toLowerCase();
        final hits = [
          for (final e in all.entries)
            if (text == null || e.value.name.toLowerCase().contains(text))
              {'id': e.key, 'nombre': e.value.name, ...e.value.extra},
        ]..sort((a, b) => '${a['nombre']}'.compareTo('${b['nombre']}'));
        return McpResult(mcpPage(hits, args), '${hits.length} resultados.');
      },
    ),
    McpTool(
      name: 'listar_homebrew',
      title: 'Listar homebrew',
      description: 'El contenido propio de la cuenta, por categoría.',
      properties: {
        'categoria': str('Solo esta categoría.', homebrewCategories),
        'cursor': mcpCursorProperty,
      },
      scope: McpScope.lectura,
      run: (who, args) async {
        final only = args.has('categoria')
            ? args.oneOf('categoria', homebrewCategories)
            : null;
        final own = await homebrew.listForUser(who.userId);
        final items = [
          for (final e in own.entries)
            if (only == null || e.key == only)
              for (final d in e.value)
                {'categoria': e.key, 'id': d['id'], 'nombre': d['name']},
        ];
        return McpResult(mcpPage(items, args), '${items.length} entradas.');
      },
    ),
    McpTool(
      name: 'listar_pnj',
      title: 'Listar PNJ',
      description:
          'Los PNJ de la biblioteca del DM, con las campañas en que están.',
      properties: {'cursor': mcpCursorProperty},
      scope: McpScope.lectura,
      run: (who, args) async {
        final all = await npcs.listForDm(who.userId);
        final items = [for (final s in all) _storedNpcJson(s)];
        return McpResult(mcpPage(items, args), '${all.length} PNJ.');
      },
    ),
    McpTool(
      name: 'ver_eventos',
      title: 'Ver avisos',
      description:
          'Los avisos pendientes de la cuenta: subidas de nivel, oro, objetos '
          'o Inspiración que otorgó un DM, y novedades de las campañas. No '
          'los marca como vistos.',
      properties: const {},
      scope: McpScope.lectura,
      run: (who, args) async {
        final pending = await events.listUnseen(who.userId);
        return McpResult({
          'eventos': [for (final e in pending) e.toJson()],
        }, '${pending.length} avisos.');
      },
    ),
    McpTool(
      name: 'aplicar_dano_o_curacion',
      title: 'Daño o curación',
      description:
          'Aplica daño, curación o PG temporales a un personaje propio, con '
          'las mismas reglas de la ficha (los temporales absorben primero, a '
          '0 PG queda inconsciente).',
      properties: {
        'personajeId': personajeId,
        'tipo': str('Qué aplicar.', ['dano', 'curacion', 'pg_temporales']),
        'cantidad': {'type': 'integer', 'minimum': 0},
      },
      required: ['personajeId', 'tipo', 'cantidad'],
      scope: McpScope.escritura,
      destructive: true,
      idempotent: false,
      run: (who, args) async {
        final kind = args.oneOf('tipo', ['dano', 'curacion', 'pg_temporales']);
        final amount = args.integer('cantidad');
        final c = await ownCharacter(who.userId, args);
        final s = sheetOf(c, await contentFor(who.userId));
        switch (kind) {
          case 'dano':
            CombatOps.applyDamage(c.combat, amount, sheet: s);
          case 'curacion':
            CombatOps.applyHealing(c.combat, s.maxHp, amount);
          default:
            CombatOps.setTempHp(c.combat, amount);
        }
        return saveCombat(
          who.userId,
          c,
          s,
          '${c.name}: ${c.combat.currentHp}/${s.maxHp} PG.',
        );
      },
    ),
    McpTool(
      name: 'gestionar_condicion',
      title: 'Condición',
      description: 'Pone o saca una condición a un personaje propio.',
      properties: {
        'personajeId': personajeId,
        'condicion': str('Id de la condición.', conditionIds),
        'activa': {'type': 'boolean', 'description': 'true la pone.'},
      },
      required: ['personajeId', 'condicion', 'activa'],
      scope: McpScope.escritura,
      run: (who, args) async {
        final id = args.oneOf('condicion', conditionIds);
        final on = args.boolean('activa');
        final c = await ownCharacter(who.userId, args);
        final s = sheetOf(c, await contentFor(who.userId));
        CombatOps.setCondition(c.combat, id, on, sheet: s);
        return saveCombat(
          who.userId,
          c,
          s,
          '${c.name}: $id ${on ? 'sí' : 'no'}.',
        );
      },
    ),
    McpTool(
      name: 'descanso',
      title: 'Descanso',
      description:
          'Un descanso corto o largo de un personaje propio, como el botón de '
          'la ficha: recupera PG, recursos y espacios según la regla.',
      properties: {
        'personajeId': personajeId,
        'tipo': str('Qué descanso.', ['corto', 'largo']),
      },
      required: ['personajeId', 'tipo'],
      scope: McpScope.escritura,
      destructive: true,
      idempotent: false,
      run: (who, args) async {
        final kind = args.oneOf('tipo', ['corto', 'largo']);
        final c = await ownCharacter(who.userId, args);
        final s = sheetOf(c, await contentFor(who.userId));
        if (kind == 'corto') {
          CombatOps.shortRest(
            c.combat,
            s.resources,
            spellcasting: s.spellcasting,
          );
        } else {
          CombatOps.longRest(
            c.combat,
            s.maxHp,
            s.resources,
            c.totalLevel,
            // ponytail: los compañeros quedan con los PG que tienen; su
            // máximo lo arma hoy la ficha de la app. Si hace falta, pasar ese
            // cálculo al engine y usarlo acá.
            companionMaxHp: (i) => i.currentHp,
            grantsHeroicInspiration: s.heroicInspirationOnLongRest,
          );
        }
        return saveCombat(
          who.userId,
          c,
          s,
          '${c.name}: descanso $kind, ${c.combat.currentHp}/${s.maxHp} PG.',
        );
      },
    ),
    McpTool(
      name: 'crear_nota',
      title: 'Crear nota',
      description:
          'Agrega una nota al cuaderno de una campaña que dirige la cuenta, '
          'dentro de uno de sus capítulos (ver_campana los lista).',
      properties: {
        'campanaId': campanaId,
        'capituloId': str('Id del capítulo.'),
        'titulo': str('Título.'),
        'texto': str('Texto de la nota.'),
      },
      required: ['campanaId', 'capituloId', 'titulo'],
      scope: McpScope.escritura,
      idempotent: false,
      run: (who, args) async {
        final campaign = await ownCampaign(who.userId, args.str('campanaId'));
        final note = await _validateNote(
          Note(
            id: 'note-${DateTime.now().microsecondsSinceEpoch}',
            chapterId: args.str('capituloId'),
            title: args.str('titulo'),
            body: args.optStr('texto') ?? '',
            updatedAt: DateTime.now().toUtc(),
          ),
          chapters,
          who.userId,
          campaign.id,
        );
        final stored = await notes.create(who.userId, campaign.id, note);
        return McpResult({'id': stored.id}, 'Nota «${stored.title}» creada.');
      },
    ),
    McpTool(
      name: 'crear_pnj',
      title: 'Crear PNJ',
      description:
          'Crea un PNJ narrativo (sin estadísticas) en la biblioteca del DM. '
          'Con campanaId lo suma también a esa campaña. El bloque de '
          'estadísticas se elige después en la app.',
      properties: {
        'nombre': str('Nombre.'),
        ...npcProps,
        'campanaId': campanaId,
      },
      required: ['nombre'],
      scope: McpScope.escritura,
      idempotent: false,
      run: (who, args) async {
        final campaignId = args.optStr('campanaId');
        // Se comprueba antes de crear: un PNJ no tiene que quedar suelto en
        // la biblioteca porque la campaña era ajena.
        if (campaignId != null) await ownCampaign(who.userId, campaignId);
        final stored = await _insertNpc(
          transactions,
          who.userId,
          Npc(
            id: 'npc',
            name: args.str('nombre'),
            sheetKind: NpcSheetKind.none,
            appearance: args.optStr('apariencia') ?? '',
            speech: args.optStr('formaDeHablar') ?? '',
            background: args.optStr('trasfondo') ?? '',
            tags: args.optStrList('etiquetas') ?? const [],
          ),
          null,
        );
        if (campaignId != null) {
          await npcs.link(who.userId, campaignId, stored.npc.id);
        }
        return McpResult({'id': stored.npc.id}, '${stored.npc.name} creado.');
      },
    ),
    McpTool(
      name: 'actualizar_pnj',
      title: 'Actualizar PNJ',
      description:
          'Cambia el nombre o los datos narrativos de un PNJ de la '
          'biblioteca. Solo se tocan los campos que se pasan.',
      properties: {
        'pnjId': str('Id del PNJ, de listar_pnj.'),
        'nombre': str('Nombre.'),
        ...npcProps,
      },
      required: ['pnjId'],
      scope: McpScope.escritura,
      run: (who, args) async {
        final id = requireSafePathSegment(args.str('pnjId'));
        final current = await npcs.find(who.userId, id);
        if (current == null) throw const McpToolError('PNJ no encontrado.');
        final doc = current.npc.toJson();
        if (args.has('nombre')) doc['name'] = args.str('nombre');
        for (final e in npcTexts.entries) {
          if (args.has(e.key)) doc[e.value] = args.optStr(e.key) ?? '';
        }
        if (args.has('etiquetas')) doc['tags'] = args.optStrList('etiquetas');
        final npc = await _updateNpc(npcs, who.userId, Npc.fromJson(doc));
        if (npc == null) throw const McpToolError('PNJ no encontrado.');
        return McpResult({'id': npc.id}, '${npc.name} actualizado.');
      },
    ),
    McpTool(
      name: 'crear_homebrew',
      title: 'Crear homebrew',
      description:
          'Crea una entrada homebrew de la cuenta (arma, armadura, objeto, '
          'dote, especie, trasfondo, conjuro o criatura). El documento sigue '
          'el mismo esquema que el catálogo, con "source": "homebrew"; los '
          'efectos se validan con el motor antes de guardar. Usá '
          'buscar_catalogo con id para ver un ejemplo del esquema.',
      properties: {
        'categoria': str('Categoría.', homebrewCategories),
        'documento': {
          'type': 'object',
          'description': 'La entrada, con id propio y "source": "homebrew".',
        },
      },
      required: ['categoria', 'documento'],
      scope: McpScope.escritura,
      idempotent: false,
      run: (who, args) async {
        final category = args.oneOf('categoria', homebrewCategories);
        final doc = validateHomebrewDocument(category, args.obj('documento'));
        final id = doc['id'] as String;
        final own = await homebrew.listForUser(who.userId);
        if ((own[category] ?? const []).any((d) => d['id'] == id)) {
          throw McpToolError('Ya hay una entrada «$id» en $category.');
        }
        await homebrew.upsert(who.userId, category, id, doc);
        return McpResult({'id': id}, '${doc['name'] ?? id} creado.');
      },
    ),
  ];
}
