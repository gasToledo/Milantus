import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

void main() {
  const check = ScriptCheck(ability: Ability.wisdom, dc: 14);
  const fork = {
    'type': 'addFork',
    'id': 'b',
    'paths': ['x', 'y']
  };

  Script edit(Script script, List<Map<String, dynamic>> actions) =>
      actions.fold(script, ScriptEdits.apply);

  Map<String, dynamic> add(String id) =>
      {'type': 'addMilestone', 'id': id, 'title': id};

  /// a → (x | y) → z
  final script = edit(
    Script.draft(id: 'g', name: 'La mina'),
    [add('a'), fork, add('z')],
  );

  ScriptProgress act(ScriptProgress p, Map<String, dynamic> action,
          [Script? s]) =>
      ScriptProgressOps.apply(s ?? script, p, action);

  test('una versión futura se rechaza y migrar no muta la entrada', () {
    final source = <String, dynamic>{'id': 'g', 'name': 'La mina'};
    Script.migrateJson(source);
    expect(source, {'id': 'g', 'name': 'La mina'});
    expect(
      () => Script.fromJson({
        ...source,
        'schemaVersion': Script.currentSchemaVersion + 1,
      }),
      throwsA(isA<UnsupportedDataVersionException>()),
    );
  });

  test('un guion completo va y vuelve igual por JSON', () {
    final full = Script(
      id: 'g',
      name: 'La mina',
      steps: [
        MilestoneStep(Milestone(
          id: 'a',
          title: 'La entrada',
          description: 'Oscura. ',
          notes: [
            for (final kind in ScriptNoteKind.values)
              ScriptNote(
                id: 'n-${kind.name}',
                kind: kind,
                title: kind.name,
                body: 'texto',
                check: check,
              ),
          ],
          links: const [
            NpcLink(id: 'l1', npcId: 'p', name: 'Bruna'),
            ScenarioLink(id: 'l2', scenarioId: 'e', name: 'La boca'),
            MusicLink(id: 'l3', sceneId: 'm', name: 'Tensión'),
            ItemLink(
              id: 'l4',
              item: ChapterItem(category: 'items', itemId: 'i', name: 'Soga'),
            ),
            EncounterLink(
              id: 'l5',
              name: 'Emboscada',
              creatures: [
                ScriptCreature(creatureId: 'c', name: 'Goblin', count: 3),
              ],
            ),
          ],
        )),
        ForkStep(id: 'b', paths: const [
          Milestone(id: 'x', condition: 'Si aceptan', endsHere: true),
          Milestone(id: 'y'),
        ]),
      ],
    );
    final read = Script.fromJson(full.toJson());
    expect(read.toJson(), full.toJson());
    expect(read.milestone('a')!.links, hasLength(5));
    expect(read.milestone('a')!.notes, hasLength(ScriptNoteKind.values.length));
  });

  test(
      'una bifurcación con un solo camino se lee como hito y un id repetido '
      'se descarta', () {
    final read = Script.fromJson({
      'id': 'g',
      'steps': [
        {
          'type': 'fork',
          'id': 'b',
          'paths': [
            {'id': 'x'},
            {'title': 'sin id'},
          ],
        },
        {'type': 'milestone', 'id': 'x', 'title': 'repetido'},
      ],
    });
    expect(read.steps.single, isA<MilestoneStep>());
    expect(read.steps.single.id, 'x');
    expect(read.milestone('x')!.title, isEmpty);
  });

  test('una bifurcación va de 2 a 4 caminos y un id en uso lanza', () {
    Map<String, dynamic> path(String id) =>
        {'type': 'addPath', 'fork': 'b', 'id': id};
    final full = edit(script, [path('p3'), path('p4'), path('p5')]);
    expect((full.steps[1] as ForkStep).paths, hasLength(ForkStep.maxPaths));
    final same = edit(script, [
      {'type': 'removePath', 'fork': 'b', 'path': 'x'},
    ]);
    expect((same.steps[1] as ForkStep).paths, hasLength(ForkStep.minPaths));
    expect(() => edit(script, [add('x')]), throwsFormatException);
  });

  test('en línea recta hay alcanzados, un solo actual y el resto pendiente',
      () {
    final line = edit(
      Script.draft(id: 'g', name: 'g'),
      [add('a'), add('b'), add('c')],
    );
    final view = ScriptView.of(line, const ScriptProgress(reached: {'a'}));
    expect(view.states, {
      'a': MilestoneState.reached,
      'b': MilestoneState.current,
      'c': MilestoneState.pending,
    });
  });

  test('el camino no elegido no se toma, y «Termina acá» cierra el guion', () {
    final ending = edit(script, [
      {'type': 'setMilestone', 'milestone': 'x', 'endsHere': true},
    ]);
    final view = ScriptView.of(
      ending,
      const ScriptProgress(reached: {'a', 'x'}, chosen: {'b': 'x'}),
    );
    expect(view.states['y'], MilestoneState.notTaken);
    expect(view.states['z'], MilestoneState.notTaken);
    expect(view.finished, isTrue);
  });

  test('al terminar, el hito activo es el último alcanzado', () {
    final view = ScriptView.of(
      script,
      const ScriptProgress(reached: {'a', 'y', 'z'}, chosen: {'b': 'y'}),
    );
    expect(view.finished, isTrue);
    expect(view.activeId, 'z');
  });

  test('alcanzar el hito previo a una bifurcación obliga a elegir camino', () {
    const start = ScriptProgress();
    expect(
      () => act(start, {'type': 'reach', 'milestone': 'a'}),
      throwsFormatException,
    );
    final next = act(start, {'type': 'reach', 'milestone': 'a', 'path': 'y'});
    expect(next.chosen, {'b': 'y'});
    expect(ScriptView.of(script, next).currentId, 'y');
  });

  test('volver a un camino no tomado cambia la elección y limpia lo posterior',
      () {
    final two = edit(script, [
      {
        'type': 'addFork',
        'id': 'b2',
        'paths': ['v', 'w']
      },
    ]);
    final back = act(
      const ScriptProgress(
        reached: {'a', 'x', 'z', 'v'},
        chosen: {'b': 'x', 'b2': 'v'},
      ),
      {'type': 'goBack', 'milestone': 'y'},
      two,
    );
    expect(back.chosen, {'b': 'y'});
    expect(back.reached, {'a', 'x'});
    expect(ScriptView.of(two, back).currentId, 'y');
    // Detrás de un final alcanzado no se vuelve: habría que deshacerlo.
    final ending = edit(script, [
      {'type': 'setMilestone', 'milestone': 'x', 'endsHere': true},
    ]);
    expect(
      () => act(
        const ScriptProgress(reached: {'a', 'x'}, chosen: {'b': 'x'}),
        {'type': 'goBack', 'milestone': 'z'},
        ending,
      ),
      throwsFormatException,
    );
  });

  test('se comparte un Lore, pero no una Tirada', () {
    Map<String, dynamic> save(String id, String kind) => {
          'type': 'saveNote',
          'milestone': 'a',
          'note': {'id': id, 'kind': kind},
        };
    final noted = edit(script, [save('t', 'check'), save('l', 'lore')]);
    Map<String, dynamic> share(String id) => {'type': 'markShared', 'note': id};
    expect(
      () => act(const ScriptProgress(), share('t'), noted),
      throwsFormatException,
    );
    expect(act(const ScriptProgress(), share('l'), noted).shared, {'l'});
  });

  test('el rótulo de una tirada nombra la habilidad solo si la hay', () {
    const skilled = ScriptCheck(
      ability: Ability.wisdom,
      skill: Skill.insight,
      dc: 14,
    );
    expect(check.label, '${Ability.wisdom.abbr} · CD 14');
    expect(
      skilled.label,
      '${Ability.wisdom.abbr} (${Skill.insight.label}) · CD 14',
    );
  });
}
