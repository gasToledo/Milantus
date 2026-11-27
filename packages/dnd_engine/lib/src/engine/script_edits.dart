import '../domain/script.dart';

/// Lo que se le puede escribir a un guion, como `NpcEdits` a un PNJ. No muta la
/// entrada.
///
/// - `setName` con `name`, recortado. Vacío deja el guion como estaba.
/// - `addMilestone` con `id`, `title` y, si hay, `after` (id del paso al que
///   sigue; sin él va al final).
/// - `addFork` con `id`, `paths` (dos ids) y, si hay, `after`.
/// - `addPath` con `fork` e `id`. Con cuatro caminos deja igual.
/// - `removeStep` con `step`: un hito o una bifurcación entera.
/// - `removePath` con `fork` y `path`. Con dos deja igual: para borrar la
///   bifurcación está `removeStep`.
/// - `moveStep` con `step` y `to`, el índice destino, acotado al rango.
/// - `setMilestone` con `milestone` y los que vengan de `title` (recortado),
///   `description`, `condition` (tal cual, como `setBackground`) y `endsHere`.
/// - `saveNote` con `milestone` y `note`: reemplaza por id en su lugar o agrega
///   al final. Una nota ilegible deja igual.
/// - `removeNote` con `milestone` y `note` (id).
/// - `saveLink` y `removeLink`, igual con `link`.
///
/// Lanza `FormatException` ante lo que es un error del cliente y no del DM: una
/// acción desconocida, un id nuevo que ya está en uso, o un paso, bifurcación o
/// hito que no existe.
class ScriptEdits {
  const ScriptEdits._();

  static Script apply(Script script, Map<String, dynamic> action) {
    final steps = script.steps;
    switch (action['type']) {
      case 'setName':
        final name = (action['name'] as String? ?? '').trim();
        return name.isEmpty ? script : script.copyWith(name: name);
      case 'addMilestone':
        return _insert(
          script,
          MilestoneStep(
            Milestone(
              id: _newId(script, action['id']),
              title: (action['title'] as String? ?? '').trim(),
            ),
          ),
          action['after'],
        );
      case 'addFork':
        final raw = action['paths'];
        final id = _newId(script, action['id']);
        final paths = [
          if (raw is List)
            for (final path in raw) _newId(script, path),
        ];
        if (paths.length != ForkStep.minPaths ||
            {id, ...paths}.length != paths.length + 1) {
          throw const FormatException(
            'Una bifurcación nace con dos caminos de ids distintos.',
          );
        }
        return _insert(
          script,
          ForkStep(id: id, paths: [for (final p in paths) Milestone(id: p)]),
          action['after'],
        );
      case 'addPath':
        final fork = _fork(script, action['fork']);
        final id = _newId(script, action['id']);
        if (fork.paths.length >= ForkStep.maxPaths) return script;
        return _replace(
          script,
          ForkStep(id: fork.id, paths: [...fork.paths, Milestone(id: id)]),
        );
      case 'removeStep':
        final index = _stepIndex(script, action['step']);
        return script.copyWith(steps: [...steps]..removeAt(index));
      case 'removePath':
        final fork = _fork(script, action['fork']);
        if (fork.paths.length <= ForkStep.minPaths) return script;
        return _replace(
          script,
          ForkStep(
            id: fork.id,
            paths: [
              for (final p in fork.paths)
                if (p.id != action['path']) p,
            ],
          ),
        );
      case 'moveStep':
        final index = _stepIndex(script, action['step']);
        final to = (action['to'] as int).clamp(0, steps.length - 1);
        final moved = [...steps]..removeAt(index);
        return script.copyWith(steps: moved..insert(to, steps[index]));
      case 'setMilestone':
        return _editMilestone(
          script,
          action['milestone'],
          (m) => m.copyWith(
            title: (action['title'] as String?)?.trim(),
            description: action['description'] as String?,
            condition: action['condition'] as String?,
            endsHere: action['endsHere'] as bool?,
          ),
        );
      case 'saveNote':
        final note = ScriptNote.tryFromJson(action['note']);
        return _editMilestone(script, action['milestone'], (m) {
          if (note == null) return m;
          final exists = m.notes.any((n) => n.id == note.id);
          if (!exists) _newId(script, note.id);
          return m.copyWith(
            notes: [
              for (final n in m.notes) n.id == note.id ? note : n,
              if (!exists) note,
            ],
          );
        });
      case 'removeNote':
        return _editMilestone(
          script,
          action['milestone'],
          (m) => m.copyWith(
            notes: [
              for (final n in m.notes)
                if (n.id != action['note']) n,
            ],
          ),
        );
      case 'saveLink':
        final link = ScriptLink.tryFromJson(action['link']);
        return _editMilestone(script, action['milestone'], (m) {
          if (link == null) return m;
          final exists = m.links.any((l) => l.id == link.id);
          if (!exists) _newId(script, link.id);
          return m.copyWith(
            links: [
              for (final l in m.links) l.id == link.id ? link : l,
              if (!exists) link,
            ],
          );
        });
      case 'removeLink':
        return _editMilestone(
          script,
          action['milestone'],
          (m) => m.copyWith(
            links: [
              for (final l in m.links)
                if (l.id != action['link']) l,
            ],
          ),
        );
      default:
        throw FormatException('Acción de guion desconocida: ${action['type']}');
    }
  }

  /// [id] si está libre en todo el guion. Uno en blanco tampoco sirve: al
  /// releer el documento se descartaría lo recién creado.
  static String _newId(Script script, Object? id) {
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Falta el id.');
    }
    final used = [
      for (final step in script.steps) step.id,
      for (final m in script.milestones) ...[
        m.id,
        for (final note in m.notes) note.id,
        for (final link in m.links) link.id,
      ],
    ];
    if (used.contains(id)) {
      throw FormatException('El id "$id" ya está en el guion.');
    }
    return id;
  }

  static int _stepIndex(Script script, Object? id) {
    final index = script.steps.indexWhere((s) => s.id == id);
    if (index < 0) throw FormatException('No existe el paso "$id".');
    return index;
  }

  static ForkStep _fork(Script script, Object? id) {
    final step = script.steps[_stepIndex(script, id)];
    if (step is! ForkStep) {
      throw FormatException('El paso "$id" no es una bifurcación.');
    }
    return step;
  }

  static Script _insert(Script script, ScriptStep step, Object? after) {
    final at =
        after == null ? script.steps.length : _stepIndex(script, after) + 1;
    return script.copyWith(steps: [...script.steps]..insert(at, step));
  }

  static Script _replace(Script script, ScriptStep step) => script.copyWith(
        steps: [for (final s in script.steps) s.id == step.id ? step : s],
      );

  static Script _editMilestone(
    Script script,
    Object? id,
    Milestone Function(Milestone) edit,
  ) {
    final current = id is String ? script.milestone(id) : null;
    if (current == null) throw FormatException('No existe el hito "$id".');
    final edited = edit(current);
    Milestone swap(Milestone m) => m.id == id ? edited : m;
    return script.copyWith(
      steps: [
        for (final step in script.steps)
          switch (step) {
            MilestoneStep() => MilestoneStep(swap(step.milestone)),
            ForkStep() => ForkStep(
                id: step.id,
                paths: [for (final p in step.paths) swap(p)],
              ),
          },
      ],
    );
  }
}
