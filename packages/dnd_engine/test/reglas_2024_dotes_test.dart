import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Dotes y el estilo Defensa contra el PHB 2024. Cada caso fija la regla:
/// el bono de Defensa solo con armadura, los puntos de Suerte, y las
/// elecciones que el texto de la dote pide y el catálogo no preguntaba.
void main() {
  late ContentRepository repo;
  late CharacterCompiler compiler;

  setUpAll(() async {
    repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    compiler = CharacterCompiler(repo);
  });

  Character pj({
    String raceId = 'human',
    String? lineageId,
    String classId = 'fighter',
    int level = 1,
    int dexterity = 14,
    int wisdom = 10,
    int constitution = 10,
    int intelligence = 10,
    int charisma = 10,
    String backgroundId = 'soldier',
    String? subclassId,
    List<String>? classHistory,
    List<String> featIds = const [],
    Map<String, List<String>> featureChoices = const {},
    Map<String, List<String>> proficiencyChoices = const {},
    Map<String, List<String>> spellChoices = const {},
    List<String> chosenSkills = const [],
    List<String> cantripIds = const [],
    List<InventoryEntry> inventory = const [],
  }) =>
      Character(
        id: 'dotes',
        name: 'Prueba',
        raceId: raceId,
        lineageId: lineageId,
        classId: classId,
        subclassId: subclassId,
        backgroundId: backgroundId,
        classHistory: classHistory,
        level: level,
        assignedScores: {
          for (final a in Ability.values)
            a: switch (a) {
              Ability.dexterity => dexterity,
              Ability.wisdom => wisdom,
              Ability.constitution => constitution,
              Ability.intelligence => intelligence,
              Ability.charisma => charisma,
              _ => 10,
            },
        },
        hpPerLevel: List.filled(
          classHistory?.length ?? level,
          8,
        ),
        featIds: featIds,
        featureChoices: featureChoices,
        proficiencyChoices: proficiencyChoices,
        spellChoices: spellChoices,
        chosenSkills: chosenSkills,
        cantripIds: cantripIds,
        inventory: inventory,
      );

  InventoryEntry puesto(String id) =>
      InventoryEntry(entryId: id, itemId: id, equipped: true);

  Armor pieza(String category) =>
      repo.armor.values.firstWhere((a) => a.category == category);

  ComputedSheet ficha(Character c) => compiler.compile(c);

  group('Estilo Defensa', () {
    Character conEstilo({
      String classId = 'fighter',
      int wisdom = 10,
      int constitution = 10,
      List<InventoryEntry> inventory = const [],
    }) =>
        pj(
          classId: classId,
          wisdom: wisdom,
          constitution: constitution,
          featureChoices: const {
            'fighting-style': ['fs-defense'],
          },
          inventory: inventory,
        );

    test('sin armadura no suma, ni con Defensa sin Armadura', () {
      final monje = ficha(conEstilo(classId: 'monk', wisdom: 16));
      final barbaro = ficha(conEstilo(classId: 'barbarian', constitution: 16));
      // 10 + DES 14 (+2) + SAB 16 (+3), y lo mismo con CON en vez de SAB.
      expect(monje.armorClass, 15);
      expect(barbaro.armorClass, 15);

      final sinEstilo = ficha(pj(classId: 'monk', wisdom: 16));
      expect(monje.armorClass, sinEstilo.armorClass);
    });

    test('suma 1 con armadura ligera, media o pesada', () {
      final dex = 2;
      for (final category in ['light', 'medium', 'heavy']) {
        final armor = pieza(category);
        final con = ficha(conEstilo(inventory: [puesto(armor.id)]));
        final sin = ficha(pj(inventory: [puesto(armor.id)]));
        expect(con.armorClass, armor.armorClassFor(dex) + 1, reason: armor.id);
        expect(con.armorClass, sin.armorClass + 1, reason: armor.id);
      }
    });

    test('el escudo solo no cuenta como armadura', () {
      final escudo = pieza('shield');
      final solo = ficha(conEstilo(inventory: [puesto(escudo.id)]));
      final sin = ficha(pj(inventory: [puesto(escudo.id)]));
      // 10 + DES (+2) + escudo. El estilo no entra.
      expect(solo.armorClass, 12 + escudo.baseAc);
      expect(solo.armorClass, sin.armorClass);

      final barbaro = ficha(conEstilo(
        classId: 'barbarian',
        constitution: 16,
        inventory: [puesto(escudo.id)],
      ));
      // El Bárbaro conserva Defensa sin Armadura con escudo, y el estilo no.
      expect(barbaro.armorClass, 15 + escudo.baseAc);
    });

    test('un bono de CA incondicional sigue sin armadura', () {
      InventoryEntry capa() => const InventoryEntry(
            entryId: 'capa',
            itemId: 'capa-de-proteccion',
            equipped: true,
            attuned: true,
          );
      final conCapa = ficha(conEstilo(inventory: [capa()]));
      final sinCapa = ficha(conEstilo());
      // La capa suma siempre; Defensa, no.
      expect(conCapa.armorClass, sinCapa.armorClass + 1);

      final cuero = pieza('light');
      final ambas = ficha(conEstilo(inventory: [puesto(cuero.id), capa()]));
      expect(ambas.armorClass, cuero.armorClassFor(2) + 2);
    });
  });

  group('Afortunado', () {
    CharacterResource suerte(ComputedSheet s) =>
        s.resources.singleWhere((r) => r.id == 'luck');

    test('los puntos de suerte son el bonificador del nivel total', () {
      final nivel1 = ficha(pj(level: 1, featIds: const ['lucky']));
      expect(suerte(nivel1).max, nivel1.proficiencyBonus);
      expect(nivel1.proficiencyBonus, 2);
      expect(suerte(nivel1).recharge, RechargeOn.longRest);

      // Un nivel de Guerrero y cuatro de Mago: el bono es del nivel 5, no
      // del nivel de la clase que no tiene la dote.
      final multi = ficha(pj(
        classId: 'wizard',
        classHistory: const [
          'fighter',
          'wizard',
          'wizard',
          'wizard',
          'wizard',
        ],
        featIds: const ['lucky'],
      ));
      expect(multi.proficiencyBonus, 3);
      expect(suerte(multi).max, 3);
    });

    test('la creación lo muestra cuando el trasfondo da la dote', () {
      final draft = CreationDraft(repo)
        ..raceId = 'human'
        ..classId = 'fighter'
        ..backgroundId = 'wayfarer';
      final s = draft.previewSheet;
      expect(suerte(s).max, s.proficiencyBonus);
    });

    test('sin la dote no hay recurso', () {
      expect(ficha(pj()).resources.where((r) => r.id == 'luck'), isEmpty);
    });
  });

  group('Influencia Feérica y Sombría', () {
    SpellChoiceSlot cupo(ComputedSheet s, String groupId) =>
        s.spellChoiceSlots.singleWhere((slot) => slot.groupId == groupId);

    test('Paso Brumoso y un conjuro de nivel 1 de esas escuelas', () {
      final mago = pj(
        classId: 'wizard',
        level: 4,
        intelligence: 16,
        charisma: 10,
        featIds: const ['fey-touched-charisma'],
      );
      final sinElegir = ficha(mago);
      final slot = cupo(sinElegir, 'fey-touched-charisma:spell');
      expect(slot.count, 1);
      expect(slot.pending, 1);

      final escuelas = {
        for (final id in slot.options) repo.spell(id)!.school,
      };
      expect(escuelas, {'Adivinación', 'Encantamiento'});
      for (final id in slot.options) {
        expect(repo.spell(id)!.level, 1, reason: id);
      }
      expect(slot.options, isNot(contains('misty-step')));

      final paso = sinElegir.innateSpells.singleWhere(
        (s) => s.spellId == 'misty-step',
      );
      // La aptitud es la de la dote, no la de la clase.
      expect(paso.ability, Ability.charisma);
      expect(paso.use, InnateSpellUse.oncePerLongRest);
      expect(paso.freeUses, 1);
      expect(sinElegir.alwaysPreparedSpellIds, contains('misty-step'));
      expect(
        sinElegir.resources
            .singleWhere((r) => r.id == innateSpellResourceId('misty-step'))
            .recharge,
        RechargeOn.longRest,
      );

      final elegido = slot.options.first;
      final con = ficha(mago.copyWith(spellChoices: {
        'fey-touched-charisma:spell': [elegido],
      }));
      final extra = con.innateSpells.singleWhere((s) => s.spellId == elegido);
      expect(extra.ability, Ability.charisma);
      expect(extra.use, InnateSpellUse.oncePerLongRest);
      expect(con.alwaysPreparedSpellIds, containsAll(['misty-step', elegido]));
      expect(cupo(con, 'fey-touched-charisma:spell').pending, 0);
    });

    test('el mismo conjuro por dos fuentes es una fila con los usos sumados',
        () {
      final s = ficha(pj(
        raceId: 'elf',
        lineageId: 'elf-high',
        classId: 'wizard',
        level: 5,
        charisma: 16,
        featIds: const ['fey-touched-charisma'],
      ));

      final paso = s.innateSpells.singleWhere((i) => i.spellId == 'misty-step');
      expect(paso.freeUses, 2);
      final recurso = s.resources
          .singleWhere((r) => r.id == innateSpellResourceId('misty-step'));
      expect(recurso.max, 2);
      expect(recurso.recharge, RechargeOn.longRest);
    });

    test('Invisibilidad y un conjuro de Ilusión o Nigromancia', () {
      final s = ficha(pj(
        classId: 'wizard',
        level: 4,
        wisdom: 16,
        featIds: const ['shadow-touched-wisdom'],
      ));
      final slot = cupo(s, 'shadow-touched-wisdom:spell');
      expect(
        {for (final id in slot.options) repo.spell(id)!.school},
        {'Ilusionismo', 'Nigromancia'},
      );
      final invis = s.innateSpells.singleWhere(
        (spell) => spell.spellId == 'invisibility',
      );
      expect(invis.ability, Ability.wisdom);
      expect(invis.use, InnateSpellUse.oncePerLongRest);
      expect(s.alwaysPreparedSpellIds, contains('invisibility'));
    });

    test('una ficha guardada sin la elección carga', () {
      final cruda = <String, dynamic>{
        'schemaVersion': 24,
        'id': 'vieja',
        'name': 'Vieja',
        'raceId': 'human',
        'classId': 'wizard',
        'backgroundId': 'sage',
        'level': 4,
        'assignedScores': {
          for (final a in Ability.values) a.name: 12,
        },
        'hpPerLevel': [6, 4, 4, 4],
        'featIds': ['fey-touched-wisdom', 'shadow-touched-charisma'],
      };
      final cargada = Character.fromJson(cruda);
      final s = ficha(cargada);
      expect(cupo(s, 'fey-touched-wisdom:spell').pending, 1);
      expect(cupo(s, 'shadow-touched-charisma:spell').pending, 1);
      expect(
        s.innateSpells.map((spell) => spell.spellId),
        containsAll(['misty-step', 'invisibility']),
      );
    });
  });

  group('Telequinético y Telepático', () {
    test('concede Mano de Mago con la aptitud de la dote', () {
      final mago = pj(
        classId: 'wizard',
        level: 4,
        intelligence: 16,
        cantripIds: const ['mage-hand'],
        featIds: const ['telekinetic-intelligence'],
      );
      final yaLaSabe = ficha(mago);
      final mano = yaLaSabe.innateSpells.singleWhere(
        (s) => s.spellId == 'mage-hand',
      );
      expect(mano.ability, Ability.intelligence);
      expect(mano.use, InnateSpellUse.atWill);
      expect(mano.freeUses, 0);
      // El truco de clase sigue: la dote no lo reemplaza, lo enseña.
      expect(mago.cantripIds, contains('mage-hand'));
    });

    test('Detectar Pensamientos una vez por descanso largo, y la telepatía',
        () {
      final s = ficha(pj(
        classId: 'fighter',
        level: 4,
        charisma: 16,
        featIds: const ['telepathic-charisma'],
      ));
      expect(s.senses[Sense.telepathy], 60);
      final detectar = s.innateSpells.singleWhere(
        (spell) => spell.spellId == 'detect-thoughts',
      );
      expect(detectar.ability, Ability.charisma);
      expect(detectar.use, InnateSpellUse.oncePerLongRest);
      expect(s.alwaysPreparedSpellIds, contains('detect-thoughts'));
    });
  });

  group('Experto en Habilidades', () {
    test('competencia nueva y pericia, incluso en esa misma', () {
      final base = pj(
        level: 4,
        dexterity: 14,
        chosenSkills: const ['athletics'],
        featIds: const ['skill-expert-dexterity'],
      );
      final vacio = ficha(base);
      final competencia = vacio.proficiencyChoiceSlots.singleWhere(
        (s) => s.groupId == 'skill-expert-dexterity:skill',
      );
      final pericia = vacio.expertiseChoiceSlots.singleWhere(
        (s) => s.groupId == 'skill-expert-dexterity:expertise',
      );
      expect(competencia.count, 1);
      expect(competencia.options, contains('stealth'));
      // Sin la competencia nueva, Sigilo todavía no se puede elegir de pericia.
      expect(pericia.skills, contains('athletics'));
      expect(pericia.skills, isNot(contains('stealth')));

      final con = ficha(base.copyWith(proficiencyChoices: const {
        'skill-expert-dexterity:skill': ['stealth'],
        'skill-expert-dexterity:expertise': ['stealth'],
      }));
      expect(con.skillProficiencies, contains('stealth'));
      expect(con.expertiseSkills, contains('stealth'));
      expect(con.expertiseSkills, isNot(contains('athletics')));
      expect(
        con.skillModifier('stealth'),
        con.abilityModifiers[Ability.dexterity]! + con.proficiencyBonus * 2,
      );
      expect(
        con.skillModifier('athletics'),
        con.abilityModifiers[Ability.strength]! + con.proficiencyBonus,
      );
    });

    test('la subida de nivel pide las dos elecciones', () {
      final guerrero = pj(
        level: 3,
        subclassId: 'champion',
        chosenSkills: const ['athletics'],
        featureChoices: const {
          'fighting-style': ['fs-archery'],
        },
      );
      final sin = LevelUp(
        guerrero,
        repo,
        const LevelUpDraft(
          classId: 'fighter',
          asiFeat: true,
          featId: 'skill-expert-strength',
        ),
      );
      expect(sin.isAsi, isTrue);
      expect(
        sin.proficiencySlots.map((s) => s.slot.groupId),
        containsAll([
          'skill-expert-strength:skill',
          'skill-expert-strength:expertise',
        ]),
      );
      expect(sin.open.proficiencies, 2);

      final con = LevelUp(
        guerrero,
        repo,
        const LevelUpDraft(
          classId: 'fighter',
          asiFeat: true,
          featId: 'skill-expert-strength',
          proficiencyPicks: {
            'skill-expert-strength:skill': ['stealth'],
            'skill-expert-strength:expertise': ['stealth'],
          },
        ),
      );
      expect(con.open.proficiencies, 0);
      expect(con.after.expertiseSkills, contains('stealth'));
    });
  });

  group('Don de la Resistencia a Energías', () {
    Character nivel18() => pj(
          level: 18,
          subclassId: 'champion',
          // Campeón, desde nivel 7, pide dos estilos. Sin el segundo el cupo
          // del don se mezcla con ese pendiente.
          featureChoices: const {
            'fighting-style': ['fs-archery', 'fs-defense'],
          },
        );

    test('dos resistencias, y se pueden cambiar', () {
      final sin = LevelUp(
        nivel18(),
        repo,
        const LevelUpDraft(
          classId: 'fighter',
          asiFeat: true,
          featId: 'boon-of-energy-resistance',
          abilityA: Ability.constitution,
        ),
      );
      final slot = sin.featureSlots.singleWhere(
        (s) => s.slot.groupId == 'boon-of-energy-resistance',
      );
      expect(slot.slot.count, 2);
      expect(slot.slot.replaceable, isTrue);
      expect(slot.options.map((o) => o.feat.id), [
        'acid',
        'cold',
        'fire',
        'lightning',
        'necrotic',
        'poison',
        'psychic',
        'radiant',
        'thunder',
      ]);
      expect(sin.open.features, 2);
      expect(sin.after.resistances, isNot(contains('fire')));

      final con = LevelUp(
        nivel18(),
        repo,
        const LevelUpDraft(
          classId: 'fighter',
          asiFeat: true,
          featId: 'boon-of-energy-resistance',
          abilityA: Ability.constitution,
          featurePicks: {
            'boon-of-energy-resistance': ['fire', 'cold'],
          },
        ),
      );
      expect(con.open.features, 0);
      expect(con.after.resistances, containsAll(['fire', 'cold']));
      expect(con.after.resistances, isNot(contains('poison')));

      final cambiadas = ficha(con.built.copyWith(featureChoices: {
        ...con.built.featureChoices,
        'boon-of-energy-resistance': ['poison', 'thunder'],
      }));
      expect(cambiadas.resistances, containsAll(['poison', 'thunder']));
      expect(cambiadas.resistances, isNot(contains('fire')));
      expect(cambiadas.resistances, isNot(contains('cold')));
    });

    test('una ficha de nivel 19 sin la elección carga', () {
      final cruda = <String, dynamic>{
        'schemaVersion': 24,
        'id': 'vieja',
        'name': 'Vieja',
        'raceId': 'human',
        'classId': 'fighter',
        'subclassId': 'champion',
        'backgroundId': 'soldier',
        'level': 19,
        'assignedScores': {
          for (final a in Ability.values) a.name: 10,
        },
        'hpPerLevel': List.filled(19, 6),
        'featIds': ['boon-of-energy-resistance'],
      };
      final s = ficha(Character.fromJson(cruda));
      expect(
        s.featureChoiceSlots.map((slot) => slot.groupId),
        contains('boon-of-energy-resistance'),
      );
      expect(s.resistances, isNot(contains('fire')));
    });
  });

  group('la subida de nivel pide el conjuro de la dote', () {
    test('Influencia Feérica deja el cupo abierto hasta elegirlo', () {
      final guerrero = pj(
        level: 3,
        subclassId: 'champion',
        featureChoices: const {
          'fighting-style': ['fs-archery'],
        },
      );
      final sin = LevelUp(
        guerrero,
        repo,
        const LevelUpDraft(
          classId: 'fighter',
          asiFeat: true,
          featId: 'fey-touched-wisdom',
        ),
      );
      final slot = sin.after.spellChoiceSlots.singleWhere(
        (s) => s.groupId == 'fey-touched-wisdom:spell',
      );
      expect(slot.pending, 1);
      expect(sin.open.spellChoices, greaterThan(0));

      final id = slot.options.first;
      final con = LevelUp(
        guerrero,
        repo,
        LevelUpDraft(
          classId: 'fighter',
          asiFeat: true,
          featId: 'fey-touched-wisdom',
          spellPicks: {
            'fey-touched-wisdom:spell': [id],
          },
        ),
      );
      expect(
        con.after.spellChoiceSlots
            .singleWhere((s) => s.groupId == 'fey-touched-wisdom:spell')
            .pending,
        0,
      );
      expect(con.after.alwaysPreparedSpellIds, contains(id));
      expect(
        con.after.innateSpells.map((s) => s.spellId),
        containsAll(['misty-step', id]),
      );
    });
  });
}
