import 'package:dnd_server/src/repositories/repository_transaction_runner.dart';

import 'in_memory_campaign_repository.dart';
import 'in_memory_chapter_repository.dart';
import 'in_memory_character_repository.dart';
import 'in_memory_encounter_repository.dart';
import 'in_memory_event_repository.dart';
import 'in_memory_homebrew_repository.dart';
import 'in_memory_level_up_repository.dart';
import 'in_memory_npc_repository.dart';

class InMemoryRepositoryTransactionRunner
    implements RepositoryTransactionRunner {
  final InMemoryCharacterRepository characters;
  final InMemoryCampaignRepository campaigns;
  final InMemoryChapterRepository chapters;
  final InMemoryEventRepository events;
  final InMemoryNpcRepository npcs;
  final InMemoryEncounterRepository encounters;
  final InMemoryHomebrewRepository homebrew;
  final InMemoryLevelUpRepository levelUps;
  int runCount = 0;

  InMemoryRepositoryTransactionRunner({
    required this.characters,
    required this.campaigns,
    required this.chapters,
    required this.events,
    required this.npcs,
    required this.encounters,
    required this.homebrew,
    required this.levelUps,
  });

  @override
  Future<T> run<T>(
    Future<T> Function(TransactionRepositories repositories) operation,
  ) async {
    runCount++;
    final characterSnapshot = characters.snapshot();
    final campaignSnapshot = campaigns.snapshot();
    final chapterSnapshot = chapters.snapshot();
    final eventSnapshot = events.snapshot();
    final npcSnapshot = npcs.snapshot();
    final encounterSnapshot = encounters.snapshot();
    final homebrewSnapshot = homebrew.snapshot();
    final levelUpSnapshot = levelUps.snapshot();
    try {
      return await operation(
        TransactionRepositories(
          characters: characters,
          campaigns: campaigns,
          chapters: chapters,
          events: events,
          npcs: npcs,
          encounters: encounters,
          homebrew: homebrew,
          levelUps: levelUps,
        ),
      );
    } catch (_) {
      characters.restore(characterSnapshot);
      campaigns.restore(campaignSnapshot);
      chapters.restore(chapterSnapshot);
      events.restore(eventSnapshot);
      npcs.restore(npcSnapshot);
      encounters.restore(encounterSnapshot);
      homebrew.restore(homebrewSnapshot);
      levelUps.restore(levelUpSnapshot);
      rethrow;
    }
  }
}
