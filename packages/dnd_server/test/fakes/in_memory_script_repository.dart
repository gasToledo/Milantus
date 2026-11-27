import 'package:dnd_engine/dnd_engine.dart';
import 'package:dnd_server/src/repositories/id_allocation.dart';
import 'package:dnd_server/src/repositories/script_repository.dart';

/// Doble de [ScriptRepository] en memoria para las pruebas HTTP.
///
/// ponytail: no reproduce las cascadas de campaña y capítulo, porque ninguna
/// prueba las ejercita; si una lo hace, engancharse a `onChapterDeleted` como
/// `InMemoryNoteRepository`.
class InMemoryScriptRepository implements ScriptRepository {
  /// Guiones por `(dmUserId, id)`.
  final Map<(String, String), Script> _scripts = {};

  /// Guion y progreso por `(dmUserId, campaignId, chapterId)`.
  final Map<(String, String, String), (String, ScriptProgress)> _chapters = {};
  int _generatedIdCounter = 0;

  int _campaignsUsing(String dmUserId, String scriptId) => {
    for (final MapEntry(:key, :value) in _chapters.entries)
      if (key.$1 == dmUserId && value.$1 == scriptId) key.$2,
  }.length;

  StoredScript _stored(String dmUserId, Script script) => StoredScript(
    script: script,
    campaigns: _campaignsUsing(dmUserId, script.id),
  );

  @override
  Future<List<StoredScript>> listForDm(String dmUserId) async =>
      [
        for (final MapEntry(:key, :value) in _scripts.entries)
          if (key.$1 == dmUserId) _stored(dmUserId, value),
      ]..sort(
        (a, b) =>
            a.script.name.toLowerCase().compareTo(b.script.name.toLowerCase()),
      );

  @override
  Future<StoredScript?> find(String dmUserId, String id) async {
    final script = _scripts[(dmUserId, id)];
    return script == null ? null : _stored(dmUserId, script);
  }

  @override
  Future<Script> create(String dmUserId, Script script) async {
    final id = resolveStorageId(
      requestedId: script.id,
      existingIds: {
        for (final key in _scripts.keys)
          if (key.$1 == dmUserId) key.$2,
      },
      fallbackId: () => 'generated-${_generatedIdCounter++}',
    );
    return _scripts[(dmUserId, id)] = script.copyWith(id: id);
  }

  @override
  Future<bool> save(String dmUserId, Script script) async {
    if (!_scripts.containsKey((dmUserId, script.id))) return false;
    _scripts[(dmUserId, script.id)] = script;
    return true;
  }

  @override
  Future<void> delete(String dmUserId, String id) async {
    _scripts.remove((dmUserId, id));
    _chapters.removeWhere((key, value) => key.$1 == dmUserId && value.$1 == id);
  }

  @override
  Future<ChapterScript?> forChapter(
    String dmUserId,
    String campaignId,
    String chapterId,
  ) async {
    final entry = _chapters[(dmUserId, campaignId, chapterId)];
    if (entry == null) return null;
    return ChapterScript(
      script: _scripts[(dmUserId, entry.$1)]!,
      progress: entry.$2,
      campaigns: _campaignsUsing(dmUserId, entry.$1),
    );
  }

  @override
  Future<void> attach(
    String dmUserId,
    String campaignId,
    String chapterId,
    String scriptId, {
    ScriptProgress progress = const ScriptProgress(),
  }) async {
    // La foránea hacia `scripts` de la tabla real.
    if (!_scripts.containsKey((dmUserId, scriptId))) {
      throw StateError('El guion "$scriptId" no es de esta cuenta.');
    }
    _chapters[(dmUserId, campaignId, chapterId)] = (scriptId, progress);
  }

  @override
  Future<bool> saveProgress(
    String dmUserId,
    String campaignId,
    String chapterId,
    ScriptProgress progress,
  ) async {
    final key = (dmUserId, campaignId, chapterId);
    final entry = _chapters[key];
    if (entry == null) return false;
    _chapters[key] = (entry.$1, progress);
    return true;
  }

  @override
  Future<void> detach(
    String dmUserId,
    String campaignId,
    String chapterId,
  ) async {
    _chapters.remove((dmUserId, campaignId, chapterId));
  }
}
