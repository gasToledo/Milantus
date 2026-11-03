import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

const _scores = {
  Ability.strength: 10,
  Ability.dexterity: 14,
  Ability.constitution: 14,
  Ability.intelligence: 10,
  Ability.wisdom: 16,
  Ability.charisma: 16,
};

void main() {
  late ContentRepository repo;
  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
  });

  Character monje({CombatState? combat}) => Character(
        id: 'monje',
        name: 'Monje',
        raceId: 'human',
        classId: 'monk',
        backgroundId: 'sage',
        level: 6,
        assignedScores: _scores,
        hpPerLevel: List.filled(6, 5),
        combat: combat,
      );

  SheetActionResult act(Character c, Map<String, dynamic> action) =>
      SheetActions.apply(c, repo, action, dice: Dice(Random(7)));

  test('la acción no toca la ficha de entrada y la nueva se relee igual', () {
    final c = monje(combat: CombatState(currentHp: 20, tempHp: 3));

    final r = act(c, {'type': 'damage', 'amount': 5});

    expect(c.combat.currentHp, 20);
    expect(c.combat.tempHp, 3);
    expect(r.character.combat.currentHp, 18);
    expect(r.character.combat.tempHp, 0);
    final json = r.character.toJson();
    expect(json['schemaVersion'], Character.currentSchemaVersion);
    expect(Character.fromJson(json).toJson(), json);
  });

  test('gastar o recuperar de una reserva no se sale de cero y el máximo', () {
    final c = monje();
    final focus = CharacterCompiler(repo)
        .compile(c)
        .resources
        .firstWhere((r) => r.id == 'focus_points');

    final gastado = act(c, {
      'type': 'spendResource',
      'resource': focus.key,
      'amount': focus.max + 5,
    }).character;
    expect(gastado.combat.resourceUsage[focus.key], focus.max);

    final recuperado = act(gastado, {
      'type': 'recoverResource',
      'resource': focus.key,
      'amount': focus.max + 5,
    }).character;
    expect(recuperado.combat.resourceUsage[focus.key], 0);
  });

  test('el espacio de pacto se gasta de su tabla y no pasa del máximo', () {
    final brujo = Character(
      id: 'brujo',
      name: 'Brujo',
      raceId: 'human',
      classId: 'warlock',
      backgroundId: 'sage',
      level: 3,
      assignedScores: _scores,
      hpPerLevel: const [8, 5, 5],
    );
    final pacto = CharacterCompiler(repo).compile(brujo).pactSlotsByLevel;
    final nivel = pacto.keys.single;

    var c = brujo;
    for (var i = 0; i <= pacto[nivel]!; i++) {
      c = act(c, {'type': 'spendSlot', 'level': nivel, 'pact': true}).character;
    }

    expect(c.combat.pactSlotsUsed[nivel], pacto[nivel]);
    expect(c.combat.spellSlotsUsed, isEmpty);
  });

  test('el descanso largo cura, baja el cansancio y recarga los objetos', () {
    final c = Character(
      id: 'guerrera',
      name: 'Guerrera',
      raceId: 'human',
      classId: 'fighter',
      backgroundId: 'soldier',
      level: 2,
      assignedScores: _scores,
      hpPerLevel: const [10, 6],
      inventory: const [
        InventoryEntry(
          entryId: 'baston',
          itemId: 'baston-de-curacion',
          charges: 9,
        ),
      ],
      combat: CombatState(currentHp: 1, exhaustion: 2),
    );
    final sheet = CharacterCompiler(repo).compile(c);

    final r = act(c, {'type': 'longRest'});

    expect(r.character.combat.currentHp, sheet.maxHp);
    expect(r.character.inventory.single.charges,
        repo.item('baston-de-curacion')!.maxCharges);
    expect(r.outcome, {
      'exhaustion': 1,
      // El humano la gana al descansar (Ingenioso).
      'inspirationGained': sheet.heroicInspirationOnLongRest,
      'itemsRecharged': 1,
    });
  });

  test(
      'concentrarse en otro conjuro despide a los compañeros que dependían '
      'de la concentración, y repetir el mismo no', () {
    CombatState combat() => CombatState(
          concentratingOn: 'Hallar corcel',
          companions: [
            CompanionInstance(
              optionId: 'corcel',
              creatureId: 'warhorse',
              concentration: true,
            ),
          ],
        );

    final mismo = act(monje(combat: combat()),
        {'type': 'concentrate', 'spell': 'Hallar corcel'});
    expect(mismo.character.combat.companions, hasLength(1));

    final otro = act(
        monje(combat: combat()), {'type': 'concentrate', 'spell': 'Bendecir'});
    expect(otro.character.combat.concentratingOn, 'Bendecir');
    expect(otro.character.combat.companions, isEmpty);
    expect(otro.outcome['dismissed'], [repo.creature('warhorse')!.name]);

    final fin = act(otro.character, {'type': 'endConcentration'});
    expect(fin.character.combat.concentratingOn, isNull);
  });

  test('la mano secundaria es una sola y se marca por el arma de base', () {
    final c = monje().copyWith(inventory: const [
      InventoryEntry(entryId: 'daga', itemId: 'dagger', equipped: true),
      InventoryEntry(entryId: 'hacha', itemId: 'handaxe', equipped: true),
    ]);

    final daga = act(c, {'type': 'offHand', 'entry': 'daga'}).character;
    expect(daga.weaponOffHand, {'dagger': true});
    final hacha = act(daga, {'type': 'offHand', 'entry': 'hacha'}).character;
    expect(hacha.weaponOffHand, {'handaxe': true});
    expect(
        act(hacha, {'type': 'offHand', 'entry': 'hacha'})
            .character
            .weaponOffHand,
        isEmpty);
  });

  test('cantidad, cargas y monedas escritas a mano no se salen de rango', () {
    final max = repo.item('baston-de-curacion')!.maxCharges!;
    final c = monje().copyWith(inventory: const [
      InventoryEntry(entryId: 'baston', itemId: 'baston-de-curacion'),
    ]);
    InventoryEntry baston(Map<String, dynamic> a) =>
        act(c, {...a, 'entry': 'baston'}).character.inventory.single;

    expect(baston({'type': 'setQuantity', 'value': 0}).quantity, 1);
    expect(baston({'type': 'setCharges', 'value': max + 3}).charges, max);
    expect(baston({'type': 'setCharges', 'value': -1}).charges, 0);
    expect(
      act(c, {
        'type': 'setCoins',
        'coins': {'gp': 12, 'sp': 0, 'cp': -2},
      }).character.coins,
      {'gp': 12},
    );
  });

  test('comprar sin fondos devuelve la ficha intacta y lo dice', () {
    final c = monje().copyWith(coins: const {'cp': 1});

    final r = act(c, {
      'type': 'buy',
      'item': 'dagger',
      'quantity': 1,
      'unitPriceCp': 200,
      'at': '2026-10-30',
    });

    expect(r.outcome['paid'], isFalse);
    expect(r.character.toJson(), c.toJson());
  });

  group('objeto base', () {
    const plantilla = 'arma-de-advertencia';

    test('una plantilla no entra sin su base, ni gratis ni pagando', () {
      final c = monje().copyWith(coins: const {'gp': 10000});
      final gratis = act(c, {'type': 'addItem', 'item': plantilla});
      final comprada = act(c, {
        'type': 'buy',
        'item': plantilla,
        'quantity': 1,
        'unitPriceCp': 100,
        'at': '2026-11-02',
      });

      expect(gratis.outcome['added'], isFalse);
      expect(gratis.character.toJson(), c.toJson());
      expect(comprada.outcome['paid'], isFalse);
      expect(comprada.character.toJson(), c.toJson());
    });

    test('con su base entra y da un ataque', () {
      final c = monje().copyWith(coins: const {'gp': 10000});
      final r = act(c, {
        'type': 'buy',
        'item': plantilla,
        'quantity': 1,
        'unitPriceCp': 100,
        'at': '2026-11-02',
        'base': 'longsword',
      });
      expect(r.outcome['paid'], isTrue);
      final entry = r.character.inventory.last.entryId;
      final equipada = act(r.character, {
        'type': 'equip',
        'entry': entry,
        'value': true,
      }).character;

      final ataques = CharacterCompiler(repo).compile(equipada).attacks;
      expect(ataques.map((a) => a.weaponId), contains(entry));
    });

    test('un objeto común no admite base', () {
      final r = act(
          monje(), {'type': 'addItem', 'item': 'dagger', 'base': 'longsword'});
      expect(r.outcome['added'], isFalse);
    });

    test('una armadura que recibe su base desplaza a la que estaba puesta', () {
      const puesta = InventoryEntry(
        entryId: 'puesta',
        itemId: 'leather',
        equipped: true,
      );
      const sinBase = InventoryEntry(
        entryId: 'magica',
        itemId: 'armadura-1',
        equipped: true,
      );
      final r = act(
        monje().copyWith(inventory: const [puesta, sinBase]),
        {'type': 'setItemBase', 'entry': 'magica', 'base': 'chain-mail'},
      ).character;

      final magica = r.inventory.singleWhere((e) => e.entryId == 'magica');
      expect(magica.baseItemId, 'chain-mail');
      expect(r.inventory.singleWhere((e) => e.entryId == 'puesta').equipped,
          isFalse);
    });

    test('una línea con base o que no la admite no cambia', () {
      const conBase = InventoryEntry(
        entryId: 'con',
        itemId: 'arma-1',
        baseItemId: 'dagger',
      );
      const comun = InventoryEntry(entryId: 'comun', itemId: 'dagger');
      final c = monje().copyWith(inventory: const [conBase, comun]);

      for (final entry in ['con', 'comun', 'no-existe']) {
        final r = act(
            c, {'type': 'setItemBase', 'entry': entry, 'base': 'longsword'});
        expect(r.character.toJson(), c.toJson());
      }
    });
  });

  group('estados, cansancio y modos activos', () {
    Character barbaro({CombatState? combat}) => Character(
          id: 'barbaro',
          name: 'Bárbaro',
          raceId: 'human',
          classId: 'barbarian',
          backgroundId: 'soldier',
          level: 3,
          assignedScores: _scores,
          hpPerLevel: const [12, 7, 7],
          combat: combat ?? CombatState(currentHp: 20),
        );

    test('un estado que incapacita termina la Furia y la concentración', () {
      final furiosa = act(barbaro(), {'type': 'activateMode', 'mode': 'rage'});
      expect(furiosa.outcome['activated'], isTrue);
      expect(furiosa.character.combat.activeModes, contains('rage'));

      final c = furiosa.character.copyWith(
        combat: CombatState.fromJson(
          (furiosa.character.combat..concentratingOn = 'Bendición').toJson(),
        ),
      );
      final aturdida = act(c, {
        'type': 'setCondition',
        'condition': 'stunned',
        'value': true,
      });
      expect(aturdida.character.combat.conditions, contains('stunned'));
      expect(aturdida.character.combat.activeModes, isEmpty);
      expect(aturdida.character.combat.concentratingOn, isNull);

      // Uno que no incapacita no corta nada.
      final envenenada = act(furiosa.character, {
        'type': 'setCondition',
        'condition': 'poisoned',
        'value': true,
      });
      expect(envenenada.character.combat.activeModes, contains('rage'));
    });

    test('el cansancio no se sale de 0 a 6 y avisa en el máximo', () {
      final c = barbaro();
      final tope = act(c, {'type': 'setExhaustion', 'value': 9});
      expect(tope.character.combat.exhaustion, maxExhaustionLevel);
      expect(tope.outcome['died'], isTrue);
      expect(
        act(c, {'type': 'setExhaustion', 'value': -2})
            .character
            .combat
            .exhaustion,
        0,
      );
    });

    test('sin usos la Furia no se activa y la ficha vuelve intacta', () {
      final sheet = CharacterCompiler(repo).compile(barbaro());
      final rage = sheet.resources.firstWhere((r) => r.id == 'rage');
      final c = barbaro(
        combat: CombatState(currentHp: 20, resourceUsage: {rage.key: rage.max}),
      );

      final r = act(c, {'type': 'activateMode', 'mode': 'rage'});

      expect(r.outcome['activated'], isFalse);
      expect(r.character.toJson(), c.toJson());
    });

    test('terminar la Furia no devuelve el uso', () {
      final on = act(barbaro(), {'type': 'activateMode', 'mode': 'rage'});
      final off = act(on.character, {'type': 'deactivateMode', 'mode': 'rage'});
      expect(off.character.combat.activeModes, isEmpty);
      expect(off.character.combat.resourceUsage,
          on.character.combat.resourceUsage);
    });
  });

  group('conjuros de la ficha', () {
    Character clerigo() => Character(
          id: 'clerigo',
          name: 'Clérigo',
          raceId: 'human',
          classId: 'cleric',
          backgroundId: 'hermit',
          level: 3,
          assignedScores: _scores,
          hpPerLevel: const [8, 5, 5],
          cantripIds: const ['guidance'],
          spellIds: const ['bless'],
        );
    Character altoElfo() => Character(
          id: 'elfo',
          name: 'Elfo',
          raceId: 'elf',
          lineageId: 'elf-high',
          speciesSpellcastingAbility: Ability.intelligence,
          classId: 'wizard',
          backgroundId: 'sage',
          level: 3,
          assignedScores: _scores,
          hpPerLevel: const [6, 4, 4],
        );

    test('setClassSpells deja lo elegido y vacía las listas planas', () {
      final r = act(clerigo(), {
        'type': 'setClassSpells',
        'classId': 'cleric',
        'cantrips': ['sacred-flame'],
        'spells': ['cure-wounds', 'bless'],
      }).character;

      expect(r.cantripIdsFor('cleric'), ['sacred-flame']);
      expect(r.spellIdsFor('cleric'), ['cure-wounds', 'bless']);
      expect(r.cantripIds, isEmpty);
      expect(r.spellIds, isEmpty);
    });

    test('setClassSpells con una clase ajena no toca la ficha', () {
      final c = clerigo();
      final r = act(c, {
        'type': 'setClassSpells',
        'classId': 'wizard',
        'cantrips': ['fire-bolt'],
        'spells': const <String>[],
      }).character;

      expect(r.toJson(), c.toJson());
    });

    test('el truco innato cambia, y volver al original borra la entrada', () {
      final c = altoElfo();
      final innate = CharacterCompiler(repo)
          .compile(c)
          .innateSpells
          .firstWhere((s) => s.isReplaceable);
      final options = LevelUp.innateCantripOptions(repo, innate);
      final other = options.firstWhere((o) => o.id != innate.grantedSpellId);
      expect(options.first.id, innate.grantedSpellId);

      Map<String, dynamic> swap(String spell) => {
            'type': 'setInnateCantrip',
            'granted': innate.grantedSpellId,
            'spell': spell,
          };
      final changed = act(c, swap(other.id)).character;
      expect(changed.innateCantripChoices, {innate.grantedSpellId: other.id});

      final back = act(changed, swap(innate.grantedSpellId)).character;
      expect(back.innateCantripChoices, isEmpty);
    });

    test('un truco fuera de las opciones o no reemplazable no toca nada', () {
      final c = altoElfo();
      final innate = CharacterCompiler(repo)
          .compile(c)
          .innateSpells
          .firstWhere((s) => s.isReplaceable);
      final fuera = repo.spellsForList('cleric').firstWhere(
            (s) =>
                s.level == innate.level &&
                !LevelUp.innateCantripOptions(repo, innate)
                    .any((o) => o.id == s.id),
          );

      for (final action in [
        {
          'type': 'setInnateCantrip',
          'granted': innate.grantedSpellId,
          'spell': fuera.id,
        },
        {
          'type': 'setInnateCantrip',
          'granted': 'no-es-innato',
          'spell': innate.grantedSpellId,
        },
      ]) {
        expect(act(c, action).character.toJson(), c.toJson());
      }
    });
  });

  test('una acción desconocida no devuelve una ficha', () {
    expect(
      () => act(monje(), {'type': 'fly'}),
      throwsFormatException,
    );
  });

  group('arma de pacto', () {
    Character brujo({List<InventoryEntry> inventory = const []}) => Character(
          id: 'brujo',
          name: 'Brujo',
          raceId: 'human',
          classId: 'warlock',
          backgroundId: 'sage',
          level: 1,
          assignedScores: _scores,
          featureChoices: const {
            'warlock-invocation': ['pact-of-the-blade'],
          },
          hpPerLevel: const [8],
          inventory: inventory,
        );
    TargetChoiceSlot slotOf(Character c) =>
        CharacterCompiler(repo).compile(c).targetChoiceSlots.single;

    test('crear vincula el arma del catálogo y cambiarla se lleva la anterior',
        () {
      final slot = slotOf(brujo());
      final first = slot.creatableWeaponIds.first;
      final second = slot.creatableWeaponIds.last;

      final a = act(brujo(), {
        'type': 'createEffectTarget',
        'group': slot.groupId,
        'weapon': first
      });
      final linked = slotOf(a.character);
      expect(linked.chosenEntryIds, hasLength(1));
      expect(
        a.character.inventory.single.itemId,
        repo.weapon(first)!.id,
      );

      final b = act(a.character, {
        'type': 'createEffectTarget',
        'group': slot.groupId,
        'weapon': second
      });
      expect(b.character.inventory, hasLength(1));
      expect(b.character.inventory.single.itemId, repo.weapon(second)!.id);

      final cleared = act(
          b.character, {'type': 'clearEffectTargets', 'group': slot.groupId});
      expect(cleared.character.inventory, isEmpty);
      expect(slotOf(cleared.character).chosenEntryIds, isEmpty);
    });

    test('vincular un ejemplar de la mochila no lo crea ni lo borra', () {
      final c = act(brujo(), {
        'type': 'createEffectTarget',
        'group': 'pact-weapon',
        'weapon': slotOf(brujo()).creatableWeaponIds.first,
      }).character;
      final entry = c.inventory.single.entryId;
      final r = act(c,
          {'type': 'setEffectTarget', 'group': 'pact-weapon', 'entry': entry});
      expect(r.character.toJson(), c.toJson());
    });

    test('lo no elegible, un grupo ajeno o nada que limpiar dejan la ficha',
        () {
      final c = brujo(inventory: const [
        InventoryEntry(entryId: 'mundano', itemId: 'rapier'),
      ]);
      final intacta = c.toJson();
      for (final action in [
        {'type': 'setEffectTarget', 'group': 'pact-weapon', 'entry': 'mundano'},
        {'type': 'setEffectTarget', 'group': 'pact-weapon', 'entry': 'nope'},
        {
          'type': 'createEffectTarget',
          'group': 'pact-weapon',
          'weapon': 'no-existe'
        },
        {'type': 'createEffectTarget', 'group': 'otro', 'weapon': 'rapier'},
        {'type': 'clearEffectTargets', 'group': 'pact-weapon'},
        {'type': 'clearEffectTargets', 'group': 'otro'},
      ]) {
        expect(act(c, action).character.toJson(), intacta, reason: '$action');
      }
    });
  });

  group('planos y réplicas del Artífice', () {
    Character artifice({List<String> planes = const []}) => Character(
          id: 'artifice',
          name: 'Artífice',
          raceId: 'human',
          classId: 'artificer',
          backgroundId: 'sage',
          level: 14,
          assignedScores: _scores,
          hpPerLevel: List.filled(14, 6),
          magicItemChoices: planes,
        );
    ItemChoiceSlot cupo(Character c) =>
        CharacterCompiler(repo).compile(c).itemChoiceSlots.single;
    // Los planos salen del cupo y no de ids transcriptos: sin base y con base.
    String sinBase(ItemChoiceSlot s, [int n = 0]) => s.optionItemIds
        .where((id) => repo.item(id)!.baseItemKind == null)
        .elementAt(n);
    String conBase(ItemChoiceSlot s) => s.optionItemIds
        .firstWhere((id) => repo.item(id)!.baseItemKind == 'weapon');

    Map<String, dynamic> plan(String id, bool on) =>
        {'type': 'setMagicItemPlan', 'item': id, 'value': on};

    test('marcar y desmarcar un plano; sacar uno que tenía réplica se la lleva',
        () {
      final slot = cupo(artifice());
      final id = sinBase(slot);

      final marcado = act(artifice(), plan(id, true));
      expect(marcado.character.magicItemChoices, [id]);
      expect(marcado.outcome['removedReplica'], isFalse);

      final replicado =
          act(marcado.character, {'type': 'replicateItem', 'item': id});
      expect(replicado.outcome['created'], isTrue);
      expect(replicado.character.inventory.single.itemId, id);

      final sacado = act(replicado.character, plan(id, false));
      expect(sacado.character.magicItemChoices, isEmpty);
      expect(sacado.character.inventory, isEmpty);
      expect(sacado.outcome['removedReplica'], isTrue);

      final sinReplica = act(marcado.character, plan(id, false));
      expect(sinReplica.outcome['removedReplica'], isFalse);
    });

    test(
        'un plano fuera de las opciones, repetido o con el cupo lleno no toca '
        'la ficha', () {
      final slot = cupo(artifice());
      final llenos = [
        for (var i = 0; i < slot.count; i++) sinBase(slot, i),
      ];
      final lleno = artifice(planes: llenos);
      final extra = sinBase(slot, slot.count);

      for (final (c, accion) in [
        (artifice(), plan('longsword', true)),
        (artifice(planes: [llenos.first]), plan(llenos.first, true)),
        (lleno, plan(extra, true)),
        (artifice(), plan(sinBase(slot), false)),
      ]) {
        expect(act(c, accion).character.toJson(), c.toJson(),
            reason: '$accion');
      }
    });

    test('la réplica respeta plano elegido, base de la plantilla y cupo', () {
      final slot = cupo(artifice());
      final base = conBase(slot);
      final c = artifice(planes: [base, sinBase(slot)]);
      // La base válida sale de las opciones de la plantilla, no de un id fijo.
      final valida =
          InventoryOps.magicBaseOptions(repo.item(base)!, repo).first;

      // Sin base, o con una que no es de su tipo, no se crea.
      for (final malo in [null, 'plate']) {
        final r = act(c, {'type': 'replicateItem', 'item': base, 'base': malo});
        expect(r.outcome['created'], isFalse);
        expect(r.character.toJson(), c.toJson());
      }
      // Un plano que no se eligió tampoco.
      final ajeno = act(c, {'type': 'replicateItem', 'item': sinBase(slot, 3)});
      expect(ajeno.outcome['created'], isFalse);
      expect(ajeno.character.toJson(), c.toJson());

      final ok =
          act(c, {'type': 'replicateItem', 'item': base, 'base': valida});
      expect(ok.outcome['created'], isTrue);
      expect(ok.character.inventory.single.baseItemId, valida);

      // El mismo plano dos veces: la segunda no entra.
      final dos = act(ok.character,
          {'type': 'replicateItem', 'item': base, 'base': valida});
      expect(dos.outcome['created'], isFalse);
    });

    test('con todos los cupos de réplica ocupados no se crea otra', () {
      final slot = cupo(artifice());
      final planes = [
        for (var i = 0; i <= slot.maxActive; i++) sinBase(slot, i),
      ];
      var c = artifice(planes: planes);
      for (final id in planes.take(slot.maxActive)) {
        c = act(c, {'type': 'replicateItem', 'item': id}).character;
      }
      expect(c.inventory, hasLength(slot.maxActive));
      final r = act(c, {'type': 'replicateItem', 'item': planes.last});
      expect(r.outcome['created'], isFalse);
      expect(r.character.toJson(), c.toJson());
    });

    test('transmutar cambia el plano de la réplica y no admite uno no elegido',
        () {
      final slot = cupo(artifice());
      final a = sinBase(slot);
      final b = sinBase(slot, 1);
      var c = artifice(planes: [a, b]);
      c = act(c, {'type': 'replicateItem', 'item': a}).character;
      final entry = c.inventory.single.entryId;

      final t = act(c, {'type': 'transmuteReplica', 'entry': entry, 'item': b});
      expect(t.character.inventory.single.itemId, b);
      expect(t.character.inventory.single.origin,
          'artificer:replicate-magic-item:$b');

      final ajeno = act(c, {
        'type': 'transmuteReplica',
        'entry': entry,
        'item': sinBase(slot, 3),
      });
      expect(ajeno.character.toJson(), c.toJson());
    });

    test('sin cupo de planos las tres acciones dejan la ficha como estaba', () {
      final c = monje();
      for (final accion in [
        plan('anteojos-de-la-noche', true),
        {'type': 'replicateItem', 'item': 'anteojos-de-la-noche'},
        {'type': 'transmuteReplica', 'entry': 'x', 'item': 'manifold-tool'},
      ]) {
        expect(act(c, accion).character.toJson(), c.toJson(),
            reason: '$accion');
      }
    });
  });
}
