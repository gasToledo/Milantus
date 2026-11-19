import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';

import 'package:dnd_server/src/repositories/scenario_repository.dart';

import 'in_memory_campaign_repository.dart';
import 'in_memory_npc_repository.dart';

class InMemoryScenarioRepository implements ScenarioRepository {
  final InMemoryCampaignRepository campaigns;
  final InMemoryNpcRepository npcs;
  final _entries = <(String, String), (StoredScenario, Uint8List?)>{};
  int _nextId = 0;

  InMemoryScenarioRepository(this.campaigns, this.npcs);

  @override
  Future<List<StoredScenario>> listForDm(String userId) async => [
    for (final entry in _entries.entries)
      if (entry.key.$1 == userId) entry.value.$1,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<StoredScenario?> find(String userId, String id) async =>
      _entries[(userId, id)]?.$1;

  @override
  Future<StoredScenario> create(String userId, ScenarioDraft draft) async {
    final suffix = (++_nextId).toRadixString(16).padLeft(12, '0');
    return _write(userId, '00000000-0000-4000-8000-$suffix', draft);
  }

  @override
  Future<StoredScenario?> save(
    String userId,
    String id,
    ScenarioDraft draft,
  ) async =>
      _entries.containsKey((userId, id)) ? _write(userId, id, draft) : null;

  StoredScenario _write(String userId, String id, ScenarioDraft draft) {
    final old = _entries[(userId, id)];
    final image = draft.imageChanged ? draft.image : old?.$2;
    final scenario = StoredScenario(
      id: id,
      name: draft.name,
      description: draft.description,
      characterKeys: draft.characterKeys ?? old?.$1.characterKeys ?? const [],
      hasImage: image != null,
      updatedAt: DateTime.now().toUtc(),
    );
    _entries[(userId, id)] = (scenario, image);
    return scenario;
  }

  @override
  Future<bool> delete(String userId, String id) async =>
      _entries.remove((userId, id)) != null;

  @override
  Future<Uint8List?> readImage(String userId, String id) async =>
      _entries[(userId, id)]?.$2;

  @override
  Future<List<ScenarioCharacter>> listCharacters(String userId) async => [
    for (final entry in await npcs.listForDm(userId))
      (
        key: 'npc:' + entry.npc.id,
        name: entry.npc.name,
        campaignId: null,
        campaignName: null,
        portraitKey: entry.npc.sheetKind == NpcSheetKind.character
            ? entry.sheet?.portraitPaths.firstOrNull
            : entry.npc.portraitPaths.firstOrNull,
        campaigns: [
          for (final link in entry.campaigns)
            (id: link.campaignId, name: link.campaignName),
        ],
      ),
    for (final campaign in await campaigns.listForDm(userId))
      for (final member in await campaigns.listMembers(userId, campaign.id))
        (
          key: 'member:' + member.memberId,
          name: member.character.name,
          campaignId: campaign.id,
          campaignName: campaign.name,
          portraitKey: member.character.portraitPaths.firstOrNull,
          campaigns: [(id: campaign.id, name: campaign.name)],
        ),
  ];
}
