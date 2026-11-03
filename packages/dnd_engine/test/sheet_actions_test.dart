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

  group('compañeros', () {
    Character lanzador(
      String classId,
      int level, {
      List<String> spells = const [],
      List<String>? history,
      CombatState? combat,
    }) =>
        Character(
          id: classId,
          name: classId,
          raceId: 'human',
          classId: classId,
          backgroundId: 'sage',
          level: level,
          classHistory: history ?? const [],
          assignedScores: _scores,
          hpPerLevel: List.filled(history?.length ?? level, 5),
          spellIds: spells,
          combat: combat,
        );

    CompanionOption opcion(Character c, String id) => CharacterCompiler(repo)
        .compile(c)
        .companions
        .firstWhere((o) => o.id == id);

    Map<String, dynamic> invocar(
      CompanionOption o, {
      int? level,
      bool pact = false,
      bool free = false,
    }) =>
        {
          'type': 'summonCompanion',
          'option': o.id,
          'creature': o.forms.first.id,
          if (level != null) 'level': level,
          if (pact) 'pact': true,
          if (free) 'free': true,
        };

    test('un espacio se gasta y los PG salen del nivel elegido', () {
      final c = lanzador('artificer', 11, spells: ['homunculus-servant']);
      final o = opcion(c, 'homunculus-servant');
      final sheet = CharacterCompiler(repo).compile(c);
      final nivel = o.minSpellLevel + 1;
      expect(sheet.normalSpellSlotsByLevel[nivel], greaterThan(0));

      final r = act(c, invocar(o, level: nivel));

      expect(r.outcome['summoned'], isTrue);
      expect(r.outcome['spentSlot'], nivel);
      expect(r.character.combat.spellSlotsUsed[nivel], 1);
      final i = r.character.combat.companions.single;
      expect(i.spellLevel, nivel);
      expect(
        i.currentHp,
        resolveCreatureInt(o.forms.first.hp,
            CombatOps.companionVars(sheet, spellLevel: nivel)),
      );
    });

    test('bajo el nivel mínimo o sin espacios se rechaza y la ficha no cambia',
        () {
      final c = lanzador('artificer', 11, spells: ['homunculus-servant']);
      final o = opcion(c, 'homunculus-servant');
      final nivel = o.minSpellLevel;
      final agotado = c.copyWith(
        combat: CombatState(
          spellSlotsUsed: {
            nivel: CharacterCompiler(repo)
                .compile(c)
                .normalSpellSlotsByLevel[nivel]!,
          },
        ),
      );

      for (final (ficha, level) in [(c, nivel - 1), (agotado, nivel)]) {
        final r = act(ficha, invocar(o, level: level));
        expect(r.outcome['summoned'], isFalse, reason: '$level');
        expect(r.character.toJson(), ficha.toJson(), reason: '$level');
      }
    });

    test('Artífice 5 y Brujo 3 pagan con el espacio de pacto', () {
      final c = lanzador(
        'artificer',
        8,
        spells: ['homunculus-servant'],
        history: [...List.filled(5, 'artificer'), ...List.filled(3, 'warlock')],
      );
      final sheet = CharacterCompiler(repo).compile(c);
      final o = opcion(c, 'homunculus-servant');
      final nivel = sheet.pactSlotsByLevel.keys.single;
      expect(nivel, greaterThanOrEqualTo(o.minSpellLevel));

      final r = act(c, invocar(o, level: nivel, pact: true));

      expect(r.outcome['summoned'], isTrue);
      expect(r.character.combat.pactSlotsUsed[nivel], 1);
      expect(r.character.combat.spellSlotsUsed, isEmpty);
    });

    test('el Paladín usa el Corcel Fiel gratis, sin espacio y hasta agotarlo',
        () {
      final c = lanzador('paladin', 5);
      final o = opcion(c, 'otherworldly-steed');
      final recurso = CharacterCompiler(repo)
          .compile(c)
          .resources
          .firstWhere((r) => r.id == innateSpellResourceId('find-steed'));

      final r = act(c, invocar(o, free: true));

      expect(r.outcome['summoned'], isTrue);
      expect(r.outcome['freeName'], recurso.name);
      expect(r.outcome['spentSlot'], isNull);
      expect(r.character.combat.resourceUsage[recurso.key], 1);
      expect(r.character.combat.spellSlotsUsed, isEmpty);
      expect(r.character.combat.companions.single.spellLevel, o.minSpellLevel);

      final otra = act(r.character, invocar(o, free: true));
      expect(otra.outcome['summoned'], isFalse);
      expect(otra.character.toJson(), r.character.toJson());
    });

    test('un conjuro de concentración corta la anterior y despide a la suya',
        () {
      final c = lanzador(
        'wizard',
        11,
        spells: ['summon-dragon', 'summon-undead'],
      );
      final previo = opcion(c, 'summon-undead');
      final o = opcion(c, 'summon-dragon');
      final enJuego = c.copyWith(
        combat: CombatState(
          concentratingOn: 'Invocar muerto viviente',
          companions: [
            CompanionInstance(
              optionId: previo.id,
              creatureId: previo.forms.first.id,
              spellLevel: previo.minSpellLevel,
              concentration: true,
              currentHp: 10,
            ),
          ],
        ),
      );

      final r = act(enJuego, invocar(o, level: o.minSpellLevel));

      expect(r.outcome['concentrates'], isTrue);
      expect(r.outcome['brokeConcentration'], isTrue);
      expect(r.outcome['dismissed'], [previo.forms.first.name]);
      expect(r.character.combat.concentratingOn,
          repo.spell('summon-dragon')!.name);
      expect(r.character.combat.companions.single.optionId, o.id);
      expect(r.character.combat.companions.single.concentration, isTrue);
    });

    test('con el máximo lleno la nueva invocación reemplaza a la más vieja',
        () {
      final c = lanzador('wizard', 3, spells: ['find-familiar']);
      final o = opcion(c, 'familiar');
      expect(o.maxActive, 1);
      final otra = o.forms.last.id;

      final r1 = act(c, invocar(o));
      final r2 = act(r1.character, {
        'type': 'summonCompanion',
        'option': o.id,
        'creature': otra,
      });

      expect(r2.character.combat.companions.single.creatureId, otra);
    });

    test('el daño que lo deja en 0 lo destruye; un índice ajeno no toca nada',
        () {
      final c = lanzador('wizard', 3, spells: ['find-familiar']);
      final o = opcion(c, 'familiar');
      final invocado = act(c, invocar(o)).character;
      final hp = invocado.combat.companions.single.currentHp;

      final herido = act(invocado, {
        'type': 'damageCompanion',
        'index': 0,
        'amount': hp - 1,
      });
      expect(herido.outcome['destroyed'], isFalse);
      expect(herido.character.combat.companions.single.currentHp, 1);

      final muerto = act(herido.character, {
        'type': 'damageCompanion',
        'index': 0,
        'amount': 5,
      });
      expect(muerto.outcome['destroyed'], isTrue);
      expect(muerto.character.combat.companions, isEmpty);

      for (final type in [
        'damageCompanion',
        'healCompanion',
        'companionTempHp',
        'dismissCompanion',
        'setCompanionCondition',
      ]) {
        final r = act(invocado, {
          'type': type,
          'index': 3,
          'amount': 5,
          'condition': 'prone',
          'value': true,
        });
        expect(r.character.toJson(), invocado.toJson(), reason: type);
      }
    });

    test('curar, PG temporales, estados y despedir', () {
      final c = lanzador('wizard', 3, spells: ['find-familiar']);
      final o = opcion(c, 'familiar');
      // Una forma con PG de sobra: el murciélago tiene 1 y cae al primer golpe.
      final vars = CombatOps.companionVars(CharacterCompiler(repo).compile(c));
      final grande =
          o.forms.firstWhere((f) => resolveCreatureInt(f.hp, vars) > 3);
      var f = act(c, {...invocar(o), 'creature': grande.id}).character;
      final max = f.combat.companions.single.currentHp;

      f = act(f, {'type': 'damageCompanion', 'index': 0, 'amount': 1})
          .character;
      f = act(f, {'type': 'healCompanion', 'index': 0, 'amount': 50}).character;
      expect(f.combat.companions.single.currentHp, max);

      f = act(f, {'type': 'companionTempHp', 'index': 0, 'amount': 4})
          .character;
      expect(f.combat.companions.single.tempHp, 4);

      f = act(f, {
        'type': 'setCompanionCondition',
        'index': 0,
        'condition': 'stunned',
        'value': true,
      }).character;
      expect(f.combat.companions.single.conditions, {'stunned'});
      f = act(f, {
        'type': 'setCompanionCondition',
        'index': 0,
        'condition': 'stunned',
        'value': false,
      }).character;
      expect(f.combat.companions.single.conditions, isEmpty);

      final fuera = act(f, {'type': 'dismissCompanion', 'index': 0});
      expect(fuera.character.combat.companions, isEmpty);
      expect(fuera.outcome['name'], grande.name);
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

  group('Forma Salvaje', () {
    Character druida({
      List<String> formas = const [],
      CombatState? combat,
      List<String>? historial,
    }) =>
        Character(
          id: 'druida',
          name: 'Druida',
          raceId: 'human',
          classId: 'druid',
          backgroundId: 'sage',
          level: historial?.length ?? 8,
          classHistory: historial ?? const [],
          assignedScores: _scores,
          hpPerLevel: List.filled(historial?.length ?? 8, 5),
          wildShapeForms: formas,
          combat: combat,
        );
    WildShapeSlot cupo(Character c) =>
        CharacterCompiler(repo).compile(c).wildShape!;
    CharacterResource recurso(Character c) => CharacterCompiler(repo)
        .compile(c)
        .resources
        .firstWhere((r) => r.id == 'wild_shape');
    Map<String, dynamic> entrar(String id) =>
        {'type': 'enterWildShape', 'creature': id};
    Map<String, dynamic> anotar(String id, bool on) =>
        {'type': 'setWildShapeForm', 'creature': id, 'value': on};

    test('entrar gasta un uso, aplica los temporales y deja la forma marcada',
        () {
      final base = druida();
      final lobo = cupo(base).options.first.id;
      final c = druida(formas: [lobo], combat: CombatState(currentHp: 20));

      final r = act(c, entrar(lobo));

      final res = recurso(c);
      expect(r.outcome['entered'], isTrue);
      expect(r.outcome['tempHp'], c.level);
      expect(r.character.combat.wildShapeCreatureId, lobo);
      expect(r.character.combat.resourceUsage[res.key], 1);
      expect(r.character.combat.tempHp, c.level);
    });

    test('sin usos o con una forma no anotada se rechaza y la ficha no cambia',
        () {
      final lobo = cupo(druida()).options.first.id;
      final otra = cupo(druida()).options.last.id;
      final res = recurso(druida());
      final sinUsos = druida(
        formas: [lobo],
        combat: CombatState(resourceUsage: {res.key: res.max}),
      );
      final sinAnotar = druida(formas: [lobo]);

      for (final (c, id) in [(sinUsos, lobo), (sinAnotar, otra)]) {
        final r = act(c, entrar(id));
        expect(r.outcome['entered'], isFalse);
        expect(r.character.toJson(), c.toJson());
      }
    });

    test(
        'un multiclase gasta en la clave de la ficha y los temporales son el '
        'nivel de Druida', () {
      final historial = ['druid', 'druid', 'druid', 'druid', 'wizard'];
      final lobo = cupo(druida(historial: historial)).options.first.id;
      final c = druida(formas: [lobo], historial: historial);
      final res = recurso(c);
      expect(res.key, isNot(res.id));

      final primera = act(c, entrar(lobo));
      expect(primera.outcome['tempHp'], 4);
      expect(primera.character.combat.resourceUsage[res.key], 1);
      expect(
          primera.character.combat.resourceUsage.containsKey(res.id), isFalse);

      // Con los usos agotados, la segunda vez ya no entra.
      final agotado = c.copyWith(
        combat: CombatState(resourceUsage: {res.key: res.max}),
      );
      expect(act(agotado, entrar(lobo)).outcome['entered'], isFalse);
    });

    test('anotar respeta el cupo y las opciones, y sacar quita lo que sobra',
        () {
      final base = druida();
      final slot = cupo(base);
      final ids = [for (final b in slot.options.take(slot.count)) b.id];

      var c = base;
      for (final id in ids) {
        c = act(c, anotar(id, true)).character;
      }
      expect(c.wildShapeForms, ids);

      // Lleno, repetido, o fuera del pozo: no escribe.
      final extra = slot.options.firstWhere((b) => !ids.contains(b.id)).id;
      for (final accion in [
        anotar(extra, true),
        anotar(ids.first, true),
        anotar('no-existe', true),
      ]) {
        expect(act(c, accion).character.toJson(), c.toJson(),
            reason: '$accion');
      }

      // Sacar vale aunque la forma ya no califique.
      final vieja = c.copyWith(wildShapeForms: [...ids, 'no-existe']);
      expect(
          act(vieja, anotar('no-existe', false)).character.wildShapeForms, ids);
      expect(act(c, anotar(ids.first, false)).character.wildShapeForms,
          ids.skip(1));
    });

    test('transformado, el dado de golpe cura con la CON de la bestia', () {
      final lobo = repo.creature(cupo(druida()).options.first.id)!;
      final c = druida(
        formas: [lobo.id],
        combat: CombatState(currentHp: 1, wildShapeCreatureId: lobo.id),
      );
      final hoja = CharacterCompiler(repo).compile(c);
      final tirada = Dice(Random(7)).rollHitDie(hoja.hitDie);

      final r = act(c, {'type': 'spendHitDie'});

      expect(
          r.outcome['healed'],
          (tirada + lobo.abilityModifierFor(Ability.constitution))
              .clamp(0, 1 << 30));
    });
  });

  group('elecciones', () {
    Character brujo() => Character(
          id: 'brujo',
          name: 'Brujo',
          raceId: 'human',
          classId: 'warlock',
          backgroundId: 'sage',
          level: 5,
          assignedScores: _scores,
          hpPerLevel: List.filled(5, 6),
        );

    List<Map<String, dynamic>> lista(Object? l) =>
        (l as List).cast<Map<String, dynamic>>();
    Map<String, dynamic> primero(Character c, String clave) =>
        lista(choicesView(c, repo)[clave]).first;
    List<String> opciones(Map<String, dynamic> g, bool Function(Map) donde) => [
          for (final o in lista(g['options']))
            if (donde(o)) o['id'] as String,
        ];
    Map<String, dynamic> eleccion(
      String type,
      String group,
      String id, {
      bool value = true,
    }) =>
        {'type': type, 'group': group, 'id': id, 'value': value};

    test('agregar respeta el cupo y las opciones', () {
      var c = brujo();
      final g = primero(c, 'features');
      final libres = opciones(g, (o) => o['unmet'] == null);
      final count = g['count'] as int;
      expect(libres.length, greaterThan(count));

      for (final id in libres.take(count + 1)) {
        c = act(c, eleccion('setFeatureChoice', g['groupId'], id)).character;
      }
      expect(c.featureChoices[g['groupId']], libres.take(count));

      final fuera = act(c, eleccion('setFeatureChoice', g['groupId'], 'nada'));
      expect(fuera.character.toJson(), c.toJson());
    });

    test('una opción con requisito sin cumplir se rechaza', () {
      final c = brujo();
      final g = primero(c, 'features');
      final bloqueada = opciones(g, (o) => o['unmet'] != null).first;

      final r = act(c, eleccion('setFeatureChoice', g['groupId'], bloqueada));

      expect(r.character.featureChoices[g['groupId']] ?? const [], isEmpty);
    });

    test('sacar vale con el cupo lleno y los demás grupos se conservan', () {
      var c = brujo();
      final g = primero(c, 'features');
      final libres = opciones(g, (o) => o['unmet'] == null);
      final count = g['count'] as int;
      c = c.copyWith(featureChoices: {
        'otro-grupo': ['x'],
        g['groupId']: libres.take(count).toList(),
      });

      final r = act(
        c,
        eleccion('setFeatureChoice', g['groupId'], libres.first, value: false),
      );

      expect(
          r.character.featureChoices[g['groupId']], libres.take(count).skip(1));
      expect(r.character.featureChoices['otro-grupo'], ['x']);
    });

    test('un grupo que la ficha no tiene deja todo intacto', () {
      final c = brujo();
      for (final type in [
        'setFeatureChoice',
        'setProficiencyChoice',
        'setSpellChoice',
        'setLanguage',
      ]) {
        final r = act(c, eleccion(type, 'no-existe', 'x'));
        expect(r.character.toJson(), c.toJson(), reason: type);
      }
    });

    test('las competencias bloquean lo que el personaje ya tiene', () {
      final c = Character(
        id: 'h',
        name: 'H',
        raceId: 'human',
        classId: 'fighter',
        backgroundId: 'sage',
        level: 1,
        featIds: const ['skilled'],
        assignedScores: _scores,
        hpPerLevel: const [10],
      );
      final g = primero(c, 'proficiencies');
      final tenidas = opciones(g, (o) => o['locked'] == true);
      final libres = opciones(g, (o) => o['locked'] != true);
      expect(tenidas, isNotEmpty);

      final rechazada = act(
        c,
        eleccion('setProficiencyChoice', g['groupId'], tenidas.first),
      );
      expect(
          rechazada.character.proficiencyChoices[g['groupId']] ?? [], isEmpty);

      final ok = act(
        c,
        eleccion('setProficiencyChoice', g['groupId'], libres.first),
      );
      expect(ok.character.proficiencyChoices[g['groupId']], [libres.first]);
      expect(ok.character.chosenProficiencies, isEmpty);
      expect(primero(ok.character, 'proficiencies')['pending'],
          (g['count'] as int) - 1);
    });

    test('los conjuros y los idiomas respetan su cupo', () {
      var c = brujo();
      final g = primero(c, 'spells');
      final id = lista(g['options']).first['id'] as String;
      final r = act(c, eleccion('setSpellChoice', g['groupId'], id));
      expect(r.character.spellChoices[g['groupId']], [id]);

      // Origen: tope de dos, y solo de los estándar.
      for (final lang in ['draconic', 'elvish', 'orc', 'abyssal']) {
        c = act(c, {'type': 'setLanguage', 'id': lang, 'value': true})
            .character;
      }
      expect(c.languages, ['draconic', 'elvish']);
      c = act(c, {'type': 'setLanguage', 'id': 'draconic', 'value': false})
          .character;
      expect(c.languages, ['elvish']);
    });

    test('setLineage no toca la aptitud mágica y rechaza lo ajeno', () {
      final elfa = Character(
        id: 'e',
        name: 'E',
        raceId: 'elf',
        classId: 'druid',
        backgroundId: 'sage',
        level: 1,
        speciesSpellcastingAbility: Ability.wisdom,
        assignedScores: _scores,
        hpPerLevel: const [8],
      );
      final r = act(elfa, {'type': 'setLineage', 'lineage': 'elf-high'});
      expect(r.character.lineageId, 'elf-high');
      expect(r.character.speciesSpellcastingAbility, Ability.wisdom);

      final ajeno = act(r.character, {'type': 'setLineage', 'lineage': 'nada'});
      expect(ajeno.character.lineageId, 'elf-high');

      final aptitud = act(
        r.character,
        {'type': 'setSpeciesAbility', 'ability': 'strength'},
      );
      expect(aptitud.character.speciesSpellcastingAbility, Ability.wisdom);
    });

    test('setUnarmoredDefense rechaza una clase fuera de las opciones', () {
      final c = Character(
        id: 'm',
        name: 'M',
        raceId: 'human',
        classId: 'monk',
        backgroundId: 'soldier',
        classHistory: const ['monk', 'barbarian'],
        assignedScores: {for (final a in Ability.values) a: 14},
        hpPerLevel: const [8, 8],
      );
      final formulas =
          CharacterCompiler(repo).compile(c).unarmoredDefenseOptions;
      expect(formulas.length, greaterThan(1));

      final otra = formulas.last.classId!;
      final r = act(c, {'type': 'setUnarmoredDefense', 'classId': otra});
      expect(r.character.unarmoredDefenseClassId, otra);

      final fuera =
          act(c, {'type': 'setUnarmoredDefense', 'classId': 'wizard'});
      expect(fuera.character.unarmoredDefenseClassId, isNull);
    });

    test('choicesView cuenta lo pendiente y lo reemplazable', () {
      final c = brujo();
      final v = choicesView(c, repo);
      final g = primero(c, 'features');

      expect(g['pending'], g['count']);
      expect(g['replaceable'], isTrue);
      // Con todo pendiente nada está completo: no hay nada que reemplazar.
      expect(v['replaceable'], isFalse);
      expect(
        lista(v['warnings']).map((w) => w['code']),
        contains('feature_choice_pending'),
      );

      final libres = opciones(g, (o) => o['unmet'] == null);
      final lleno = c.copyWith(featureChoices: {
        g['groupId']: libres.take(g['count'] as int).toList(),
      });
      expect(choicesView(lleno, repo)['replaceable'], isTrue);
      expect(primero(lleno, 'features')['pending'], 0);
    });
  });

  group('diario', () {
    Map<String, dynamic> guardar(String id, String titulo, String at,
            {String kind = 'text', String body = '', String? imageKey}) =>
        {
          'type': 'saveDiaryEntry',
          'entry': id,
          'kind': kind,
          'title': titulo,
          'body': body,
          'imageKey': imageKey,
          'at': at,
        };

    List<String> ids(Character c) => [for (final e in c.diary) e.entryId];

    test('el trasfondo se guarda tal cual, sin recortar', () {
      final r = act(monje(), {'type': 'setBackground', 'text': '  hola \n'});
      expect(r.character.background, '  hola \n');
    });

    test('alta con createdAt y sin updatedAt, y edición que lo conserva', () {
      final alta = act(monje(),
          guardar('a', '  Manía ', '2026-03-12T10:00:00Z', body: ' texto '));
      expect(alta.outcome['saved'], isTrue);
      final e = alta.character.diary.single;
      expect(e.title, 'Manía');
      expect(e.body, 'texto');
      expect(e.createdAt, DateTime.parse('2026-03-12T10:00:00Z'));
      expect(e.updatedAt, isNull);

      final edicion = act(alta.character,
          guardar('a', 'Manía 2', '2026-04-02T10:00:00Z', body: 'otro'));
      final f = edicion.character.diary.single;
      expect(f.title, 'Manía 2');
      expect(f.createdAt, e.createdAt);
      expect(f.updatedAt, DateTime.parse('2026-04-02T10:00:00Z'));
    });

    test('sin título, o imagen sin clave, la ficha queda intacta', () {
      final c = monje();
      final sinTitulo = act(c, guardar('a', '   ', '2026-03-12T10:00:00Z'));
      expect(sinTitulo.outcome['saved'], isFalse);
      expect(sinTitulo.character.diary, isEmpty);

      final sinClave =
          act(c, guardar('a', 'Mapa', '2026-03-12T10:00:00Z', kind: 'image'));
      expect(sinClave.outcome['saved'], isFalse);
      expect(sinClave.character.diary, isEmpty);
    });

    test('la imagen no lleva cuerpo y los otros tipos no llevan clave', () {
      final img = act(
          monje(),
          guardar('a', 'Mapa', '2026-03-12T10:00:00Z',
              kind: 'image', body: 'sobra', imageKey: 'k1'));
      expect(img.character.diary.single.body, '');
      expect(img.character.diary.single.imageKey, 'k1');

      final texto = act(
          img.character,
          guardar('a', 'Mapa', '2026-03-13T10:00:00Z',
              body: 'ahora texto', imageKey: 'k1'));
      expect(texto.character.diary.single.imageKey, isNull);
      expect(texto.character.diary.single.body, 'ahora texto');
    });

    test('borrar saca solo esa entrada, y un id que no existe no toca nada',
        () {
      var c = monje();
      for (final id in ['a', 'b', 'c']) {
        c = act(c, guardar(id, id, '2026-03-12T10:00:00Z')).character;
      }
      final sin = act(c, {'type': 'removeDiaryEntry', 'entry': 'b'}).character;
      expect(ids(sin), ['a', 'c']);
      final igual =
          act(c, {'type': 'removeDiaryEntry', 'entry': 'zzz'}).character;
      expect(ids(igual), ['a', 'b', 'c']);
    });

    test('mover reinserta en el lugar del destino; ids malos no mueven', () {
      var c = monje();
      for (final id in ['a', 'b', 'c', 'd']) {
        c = act(c, guardar(id, id, '2026-03-12T10:00:00Z')).character;
      }
      Character mover(String from, String to) =>
          act(c, {'type': 'moveDiaryEntry', 'entry': from, 'to': to}).character;
      expect(ids(mover('a', 'c')), ['b', 'c', 'a', 'd']);
      expect(ids(mover('d', 'b')), ['a', 'd', 'b', 'c']);
      expect(ids(mover('a', 'a')), ['a', 'b', 'c', 'd']);
      expect(ids(mover('a', 'zzz')), ['a', 'b', 'c', 'd']);
      expect(ids(mover('zzz', 'a')), ['a', 'b', 'c', 'd']);
    });
  });
}
