import 'ability.dart';
import 'chapter.dart';
import 'content_language.dart';
import 'data_version.dart';
import 'skill.dart';

/// Un texto que sirve para identificar o nombrar algo: presente y no en blanco.
String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

List<Object?> _list(Object? value) => value is List ? value : const [];

/// De qué tipo es una nota de un hito.
enum ScriptNoteKind {
  readAloud,
  lore,
  secret,
  check,
  reaction,
  idea;

  /// Si tiene sentido mostrársela a los jugadores. Las demás son herramientas
  /// del DM: una tirada o una reacción no son algo que la mesa lea.
  bool get shareable => this == readAloud || this == lore || this == secret;
}

/// La Tirada que pide una nota: «SAB (Perspicacia) · CD 14».
///
/// Característica y habilidad son **independientes**: en 2024 se puede pedir
/// FUE (Intimidación), así que no se validan entre sí.
class ScriptCheck {
  final Ability ability;
  final Skill? skill;

  /// De 1 a 30.
  final int dc;

  const ScriptCheck({required this.ability, this.skill, required this.dc});

  String get label {
    final what =
        skill == null ? ability.abbr : '${ability.abbr} (${skill!.label})';
    return '$what · ${localized('CD', 'DC')} $dc';
  }

  Map<String, dynamic> toJson() => {
        'ability': ability.code,
        if (skill != null) 'skill': skill!.id,
        'dc': dc,
      };

  static ScriptCheck? tryFromJson(Object? source) {
    if (source is! Map) return null;
    final ability =
        Ability.values.where((a) => a.code == source['ability']).firstOrNull;
    final dc = source['dc'];
    if (ability == null || dc is! int || dc < 1 || dc > 30) return null;
    final rawSkill = source['skill'];
    final skill = rawSkill is String ? Skill.fromId(rawSkill) : null;
    // Una habilidad que no se entiende invalida la tirada entera: sacarla
    // cambiaría lo que el DM pidió.
    if (rawSkill != null && skill == null) return null;
    return ScriptCheck(ability: ability, skill: skill, dc: dc);
  }
}

/// Una nota preparada dentro de un hito.
///
/// No dice si ya se compartió con los jugadores: el guion se reusa entre
/// campañas y compartir pasa en una sola (ver `ScriptProgress.shared`).
class ScriptNote {
  final String id;
  final ScriptNoteKind kind;

  /// Puede estar vacío: «Leer en voz alta» no lleva título.
  final String title;
  final String body;

  /// Solo en las notas de tipo [ScriptNoteKind.check].
  final ScriptCheck? check;

  const ScriptNote({
    required this.id,
    required this.kind,
    this.title = '',
    this.body = '',
    ScriptCheck? check,
  }) : check = kind == ScriptNoteKind.check ? check : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        if (check != null) 'check': check!.toJson(),
      };

  static ScriptNote? tryFromJson(Object? source) {
    if (source is! Map) return null;
    final id = _text(source['id']);
    final kind = ScriptNoteKind.values
        .where((k) => k.name == source['kind'])
        .firstOrNull;
    if (id == null || kind == null) return null;
    final title = source['title'];
    final body = source['body'];
    return ScriptNote(
      id: id,
      kind: kind,
      title: title is String ? title : '',
      body: body is String ? body : '',
      check: ScriptCheck.tryFromJson(source['check']),
    );
  }
}

/// Una fila del combate preparado.
class ScriptCreature {
  final String creatureId;

  /// El nombre del momento de elegirla, como `ChapterItem.name`.
  final String name;

  /// Al menos 1.
  final int count;
  final bool homebrew;

  const ScriptCreature({
    required this.creatureId,
    required this.name,
    this.count = 1,
    this.homebrew = false,
  });

  Map<String, dynamic> toJson() => {
        'creatureId': creatureId,
        'name': name,
        'count': count,
        'homebrew': homebrew,
      };

  static ScriptCreature? tryFromJson(Object? source) {
    if (source is! Map) return null;
    final creatureId = _text(source['creatureId']);
    final name = _text(source['name']);
    if (creatureId == null || name == null) return null;
    final count = source['count'];
    return ScriptCreature(
      creatureId: creatureId,
      name: name,
      count: count is int && count > 1 ? count : 1,
      homebrew: source['homebrew'] == true,
    );
  }
}

/// Algo que el hito tiene a mano: un PNJ, un escenario, música, un objeto o un
/// combate preparado.
///
/// El nombre se guarda para poder mostrar el vínculo aunque lo referido no
/// exista en la campaña (la música vive en la campaña y el guion no). El motor
/// **no** resuelve si existe.
sealed class ScriptLink {
  /// Del vínculo, no de lo referido: es con lo que se lo quita.
  final String id;

  const ScriptLink(this.id);

  Map<String, dynamic> toJson();

  static ScriptLink? tryFromJson(Object? source) {
    if (source is! Map) return null;
    final id = _text(source['id']);
    if (id == null) return null;
    if (source['type'] == 'item') {
      final item = ChapterItem.tryFromJson(source['item']);
      return item == null ? null : ItemLink(id: id, item: item);
    }
    final name = _text(source['name']);
    if (name == null) return null;
    switch (source['type']) {
      case 'npc':
        final npcId = _text(source['npcId']);
        return npcId == null ? null : NpcLink(id: id, npcId: npcId, name: name);
      case 'scenario':
        final scenarioId = _text(source['scenarioId']);
        return scenarioId == null
            ? null
            : ScenarioLink(id: id, scenarioId: scenarioId, name: name);
      case 'music':
        final sceneId = _text(source['sceneId']);
        return sceneId == null
            ? null
            : MusicLink(id: id, sceneId: sceneId, name: name);
      case 'encounter':
        final creatures = [
          for (final raw in _list(source['creatures']))
            if (ScriptCreature.tryFromJson(raw) case final creature?) creature,
        ];
        return creatures.isEmpty
            ? null
            : EncounterLink(id: id, name: name, creatures: creatures);
      default:
        return null;
    }
  }
}

final class NpcLink extends ScriptLink {
  final String npcId;
  final String name;

  const NpcLink({required String id, required this.npcId, required this.name})
      : super(id);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'npc', 'id': id, 'npcId': npcId, 'name': name};
}

final class ScenarioLink extends ScriptLink {
  final String scenarioId;
  final String name;

  const ScenarioLink({
    required String id,
    required this.scenarioId,
    required this.name,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'scenario', 'id': id, 'scenarioId': scenarioId, 'name': name};
}

final class MusicLink extends ScriptLink {
  final String sceneId;
  final String name;

  const MusicLink(
      {required String id, required this.sceneId, required this.name})
      : super(id);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'music', 'id': id, 'sceneId': sceneId, 'name': name};
}

final class ItemLink extends ScriptLink {
  final ChapterItem item;

  const ItemLink({required String id, required this.item}) : super(id);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'item', 'id': id, 'item': item.toJson()};
}

final class EncounterLink extends ScriptLink {
  final String name;
  final List<ScriptCreature> creatures;

  const EncounterLink({
    required String id,
    required this.name,
    required this.creatures,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'encounter',
        'id': id,
        'name': name,
        'creatures': [for (final c in creatures) c.toJson()],
      };
}

/// Un punto de la historia: lo que tiene que pasar y lo que el DM preparó para
/// cuando pase.
class Milestone {
  final String id;
  final String title;
  final String description;

  /// Solo tiene sentido en un camino de una bifurcación: «Si aceptan».
  final String condition;

  /// Solo en un camino: «Termina acá».
  final bool endsHere;
  final List<ScriptLink> links;
  final List<ScriptNote> notes;

  const Milestone({
    required this.id,
    this.title = '',
    this.description = '',
    this.condition = '',
    this.endsHere = false,
    this.links = const [],
    this.notes = const [],
  });

  Milestone copyWith({
    String? title,
    String? description,
    String? condition,
    bool? endsHere,
    List<ScriptLink>? links,
    List<ScriptNote>? notes,
  }) =>
      Milestone(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        condition: condition ?? this.condition,
        endsHere: endsHere ?? this.endsHere,
        links: links ?? this.links,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'condition': condition,
        'endsHere': endsHere,
        'links': [for (final link in links) link.toJson()],
        'notes': [for (final note in notes) note.toJson()],
      };

  static Milestone? tryFromJson(Object? source) {
    if (source is! Map) return null;
    final id = _text(source['id']);
    if (id == null) return null;
    String text(String key) {
      final value = source[key];
      return value is String ? value : '';
    }

    return Milestone(
      id: id,
      title: text('title'),
      description: text('description'),
      condition: text('condition'),
      endsHere: source['endsHere'] == true,
      links: [
        for (final raw in _list(source['links']))
          if (ScriptLink.tryFromJson(raw) case final link?) link,
      ],
      notes: [
        for (final raw in _list(source['notes']))
          if (ScriptNote.tryFromJson(raw) case final note?) note,
      ],
    );
  }
}

/// Un paso de la línea del guion: un hito suelto o una bifurcación.
sealed class ScriptStep {
  String get id;

  /// Los hitos del paso, en orden de lectura.
  List<Milestone> get milestones;

  Map<String, dynamic> toJson();
}

final class MilestoneStep extends ScriptStep {
  final Milestone milestone;

  MilestoneStep(this.milestone);

  @override
  String get id => milestone.id;

  @override
  List<Milestone> get milestones => [milestone];

  @override
  Map<String, dynamic> toJson() => {'type': 'milestone', ...milestone.toJson()};
}

/// De 2 a 4 caminos alternativos, cada uno un solo hito.
final class ForkStep extends ScriptStep {
  static const int minPaths = 2;
  static const int maxPaths = 4;

  @override
  final String id;
  final List<Milestone> paths;

  ForkStep({required this.id, required this.paths});

  @override
  List<Milestone> get milestones => paths;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'fork',
        'id': id,
        'paths': [for (final path in paths) path.toJson()],
      };
}

/// El guion de un capítulo: la línea de hitos y bifurcaciones que prepara el DM.
///
/// Vive en la Biblioteca de la cuenta y se reusa entre campañas, así que **no**
/// guarda nada de lo que pasó en una mesa: eso es `ScriptProgress`. **Nunca lo
/// ve un jugador.** Los ids de todo los manda el cliente; el motor no genera.
class Script {
  /// Mismo contrato que `Chapter.currentSchemaVersion`.
  static const int currentSchemaVersion = 1;

  final String id;
  final String name;
  final List<ScriptStep> steps;

  /// Mismo contrato que `Note.updatedAt`: lo manda la base.
  final DateTime? updatedAt;

  const Script({
    required this.id,
    required this.name,
    this.steps = const [],
    this.updatedAt,
  });

  factory Script.draft({required String id, required String name}) =>
      Script(id: id, name: name);

  /// Cambiar el [id] conserva los de los pasos: así un capítulo puede pasar a
  /// una copia del guion sin perder su progreso.
  Script copyWith({String? id, String? name, List<ScriptStep>? steps}) =>
      Script(
        id: id ?? this.id,
        name: name ?? this.name,
        steps: steps ?? this.steps,
        updatedAt: updatedAt,
      );

  Iterable<Milestone> get milestones => steps.expand((s) => s.milestones);

  Milestone? milestone(String id) =>
      milestones.where((m) => m.id == id).firstOrNull;

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'name': name,
        'steps': [for (final step in steps) step.toJson()],
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  /// Único borde por el que entra algo escrito afuera: lo que no se puede leer
  /// se descarta en vez de rechazar el guion entero, como en `Chapter`.
  factory Script.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    // Pasos, hitos, notas y vínculos comparten el espacio de ids: gana el
    // primero que se lee.
    final seen = <String>{};
    Milestone? read(Object? raw) {
      final m = Milestone.tryFromJson(raw);
      if (m == null || !seen.add(m.id)) return null;
      return m.copyWith(
        links: [
          for (final link in m.links)
            if (seen.add(link.id)) link,
        ],
        notes: [
          for (final note in m.notes)
            if (seen.add(note.id)) note,
        ],
      );
    }

    final steps = <ScriptStep>[];
    for (final raw in _list(j['steps'])) {
      if (raw is! Map) continue;
      if (raw['type'] == 'milestone') {
        if (read(raw) case final m?) steps.add(MilestoneStep(m));
      } else if (raw['type'] == 'fork') {
        final id = _text(raw['id']);
        if (id == null || !seen.add(id)) continue;
        final paths = <Milestone>[];
        for (final rawPath in _list(raw['paths'])) {
          if (paths.length == ForkStep.maxPaths) break;
          if (read(rawPath) case final m?) paths.add(m);
        }
        if (paths.length >= ForkStep.minPaths) {
          steps.add(ForkStep(id: id, paths: paths));
        } else {
          // La bifurcación no queda: su id se libera, y el camino que haya se
          // conserva como hito para no perder lo escrito.
          seen.remove(id);
          if (paths.isNotEmpty) steps.add(MilestoneStep(paths.single));
        }
      }
    }
    return Script(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      steps: steps,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión del guion debe ser un entero positivo.',
      );
    }
    return value;
  }

  /// Mismo contrato que `Chapter.migrateJson`: no muta la entrada, y rechaza
  /// una versión futura.
  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    final version = schemaVersionOf(source);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'guion',
        found: version,
        supported: currentSchemaVersion,
      );
    }
    return Map<String, dynamic>.from(source)
      ..['schemaVersion'] = currentSchemaVersion;
  }
}
