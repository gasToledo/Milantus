import '../domain/script.dart';

enum MilestoneState { reached, current, pending, notTaken }

/// Hasta dónde llegó un capítulo en su guion.
///
/// No lleva `schemaVersion`: el servidor lo guarda en columnas y este JSON es
/// solo el transporte.
class ScriptProgress {
  /// Ids de los hitos alcanzados.
  final Set<String> reached;

  /// Id de bifurcación → id del camino elegido.
  final Map<String, String> chosen;

  /// Ids de las notas compartidas con los jugadores. Vive acá y no en la nota
  /// porque el guion se reusa entre campañas y compartir pasa en una sola.
  final Set<String> shared;

  const ScriptProgress({
    this.reached = const {},
    this.chosen = const {},
    this.shared = const {},
  });

  Map<String, dynamic> toJson() => {
        'reached': [...reached],
        'chosen': chosen,
        'shared': [...shared],
      };

  factory ScriptProgress.fromJson(Map<String, dynamic> j) {
    Set<String> ids(Object? value) =>
        value is List ? value.whereType<String>().toSet() : {};
    final chosen = j['chosen'];
    return ScriptProgress(
      reached: ids(j['reached']),
      chosen: {
        if (chosen is Map)
          for (final entry in chosen.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      },
      shared: ids(j['shared']),
    );
  }
}

/// Cómo se ve un guion con su progreso. Los ids del progreso que ya no están en
/// el guion se ignoran: el guion se pudo editar.
class ScriptView {
  /// Un estado por cada hito del guion.
  final Map<String, MilestoneState> states;

  /// El hito «Ahora».
  final String? currentId;

  /// La bifurcación que toca elegir, con todo lo anterior alcanzado.
  final String? awaitingFork;
  final bool finished;

  /// El hito que estampa el Registro: el actual, o el último alcanzado.
  final String? activeId;

  /// Id de nota → rótulo de su tirada.
  final Map<String, String> checkLabels;

  /// Las compartidas que todavía existen.
  final Set<String> shared;

  const ScriptView({
    required this.states,
    this.currentId,
    this.awaitingFork,
    this.finished = false,
    this.activeId,
    this.checkLabels = const {},
    this.shared = const {},
  });

  factory ScriptView.of(Script script, ScriptProgress progress) {
    final states = <String, MilestoneState>{};
    String? currentId;
    String? awaitingFork;
    String? lastReached;
    // `blocked`: ya apareció lo que falta, así que lo que sigue está pendiente.
    // `ended`: un camino alcanzado terminó el guion.
    var blocked = false;
    var ended = false;

    void visit(Milestone m) {
      if (blocked) {
        states[m.id] = MilestoneState.pending;
      } else if (progress.reached.contains(m.id)) {
        states[m.id] = MilestoneState.reached;
        lastReached = m.id;
      } else {
        states[m.id] = MilestoneState.current;
        currentId = m.id;
        blocked = true;
      }
    }

    void fill(Iterable<Milestone> milestones, MilestoneState state) {
      for (final m in milestones) {
        states[m.id] = state;
      }
    }

    for (final step in script.steps) {
      if (ended) {
        fill(step.milestones, MilestoneState.notTaken);
        continue;
      }
      switch (step) {
        case MilestoneStep():
          visit(step.milestone);
        case ForkStep():
          final choice = progress.chosen[step.id];
          if (step.paths.any((p) => p.id == choice)) {
            for (final path in step.paths) {
              if (path.id != choice) {
                states[path.id] = MilestoneState.notTaken;
                continue;
              }
              visit(path);
              ended =
                  path.endsHere && states[path.id] == MilestoneState.reached;
            }
          } else {
            if (!blocked) awaitingFork = step.id;
            blocked = true;
            fill(step.paths, MilestoneState.pending);
          }
      }
    }

    final notes = [for (final m in script.milestones) ...m.notes];
    return ScriptView(
      states: states,
      currentId: currentId,
      awaitingFork: awaitingFork,
      finished:
          currentId == null && awaitingFork == null && lastReached != null,
      activeId: currentId ?? lastReached,
      checkLabels: {
        for (final note in notes)
          if (note.check != null) note.id: note.check!.label,
      },
      shared: {
        for (final note in notes)
          if (progress.shared.contains(note.id)) note.id,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'states': {
          for (final entry in states.entries) entry.key: entry.value.name,
        },
        'currentId': currentId,
        'awaitingFork': awaitingFork,
        'finished': finished,
        'activeId': activeId,
        'checkLabels': checkLabels,
        'shared': [...shared],
      };
}

/// Lo que se hace con el progreso mientras se juega. No muta la entrada, y toda
/// precondición rota lanza `FormatException`. El Registro no se toca acá: volver
/// atrás no mueve lo anotado.
///
/// - `reach` con `milestone` (el actual) y, solo si el paso siguiente es una
///   bifurcación, `path`. Sin hito actual pero con una bifurcación esperando,
///   va solo `path`.
/// - `goBack` con `milestone`, un hito alcanzado o un camino no tomado de una
///   bifurcación: pasa a ser el actual. Lo que quedó no tomado detrás de un
///   «Termina acá» no es destino válido: para seguir más allá se vuelve a la
///   bifurcación y se elige otro camino, o se le saca la marca al hito.
///   Deshacer el final desde acá sería una escritura que nadie pidió.
/// - `markShared` con `note`, que tiene que poder compartirse.
class ScriptProgressOps {
  const ScriptProgressOps._();

  static ScriptProgress apply(
    Script script,
    ScriptProgress progress,
    Map<String, dynamic> action,
  ) =>
      switch (action['type']) {
        'reach' => _reach(script, progress, action),
        'goBack' => _goBack(script, progress, action['milestone']),
        'markShared' => _markShared(script, progress, action['note']),
        _ => throw FormatException(
            'Acción de progreso desconocida: ${action['type']}',
          ),
      };

  static ScriptProgress _reach(
    Script script,
    ScriptProgress progress,
    Map<String, dynamic> action,
  ) {
    final view = ScriptView.of(script, progress);
    final milestone = action['milestone'];
    final path = action['path'];
    final current = view.currentId;
    if (milestone != current ||
        (current == null && view.awaitingFork == null)) {
      throw FormatException('El hito "$milestone" no es el actual.');
    }
    // La bifurcación a elegir: la que ya está esperando, o la que sigue al
    // hito que se alcanza.
    final index = script.steps.indexWhere(
      (s) => current == null
          ? s.id == view.awaitingFork
          : s.milestones.any((m) => m.id == current),
    );
    final target = current == null ? index : index + 1;
    final fork = target < script.steps.length ? script.steps[target] : null;
    if (fork is ForkStep
        ? !fork.paths.any((p) => p.id == path)
        : path != null) {
      throw FormatException('El camino "$path" no corresponde.');
    }
    return ScriptProgress(
      reached: {...progress.reached, if (current != null) current},
      chosen: {
        ...progress.chosen,
        if (fork is ForkStep) fork.id: path as String,
      },
      shared: progress.shared,
    );
  }

  static ScriptProgress _goBack(
    Script script,
    ScriptProgress progress,
    Object? milestone,
  ) {
    final state = ScriptView.of(script, progress).states[milestone];
    if (state != MilestoneState.reached && state != MilestoneState.notTaken) {
      throw FormatException('No se puede volver al hito "$milestone".');
    }
    final index = script.steps.indexWhere(
      (s) => s.milestones.any((m) => m.id == milestone),
    );
    final step = script.steps[index];
    final after = {
      ...script.milestones.map((m) => m.id).skipWhile((id) => id != milestone),
    };
    final later = {for (final s in script.steps.skip(index + 1)) s.id};
    final result = ScriptProgress(
      reached: progress.reached.difference(after),
      chosen: {
        for (final entry in progress.chosen.entries)
          if (!later.contains(entry.key)) entry.key: entry.value,
        if (step is ForkStep) step.id: milestone as String,
      },
      shared: progress.shared,
    );
    // Lo que quedó detrás de un «Termina acá» no puede ser el actual sin
    // deshacer ese final: para eso se vuelve al camino que lo terminó.
    if (ScriptView.of(script, result).currentId != milestone) {
      throw FormatException('No se puede volver al hito "$milestone".');
    }
    return result;
  }

  static ScriptProgress _markShared(
    Script script,
    ScriptProgress progress,
    Object? note,
  ) {
    final found = script.milestones
        .expand((m) => m.notes)
        .where((n) => n.id == note)
        .firstOrNull;
    if (found == null || !found.kind.shareable) {
      throw FormatException('La nota "$note" no se puede compartir.');
    }
    return ScriptProgress(
      reached: progress.reached,
      chosen: progress.chosen,
      shared: {...progress.shared, found.id},
    );
  }
}
