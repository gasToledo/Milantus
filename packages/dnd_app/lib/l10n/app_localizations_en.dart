// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Milantus — Adventure Companion';

  @override
  String languageSelectorLabel(String name) {
    return 'Language: $name';
  }

  @override
  String get languageSelectorTooltip => 'Change language';

  @override
  String get settingsLoadError => 'Couldn\'t load the settings';

  @override
  String get settingsSaveError => 'Couldn\'t save the settings';

  @override
  String get settingsTitle => 'Settings · Image generation';

  @override
  String get settingsLoading => 'Loading settings…';

  @override
  String get settingsNoProviders =>
      'This server has no image generation provider set up. You can still upload your own portrait from the character sheet.';

  @override
  String get settingsProviderLabel => 'Portrait provider:';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonUndo => 'Undo';

  @override
  String get saveStateFailed => 'Not saved';

  @override
  String get saveStateSaved => 'Saved';

  @override
  String saveStateLabel(String state) {
    return 'Save status: $state';
  }

  @override
  String get commonUse => 'Use';

  @override
  String get commonRestore => 'Restore';

  @override
  String get commonRange => 'Range';

  @override
  String get themeLight => 'Light theme';

  @override
  String get themeSystem => 'Follow the system theme';

  @override
  String get themeDark => 'Dark theme';

  @override
  String get errorShowDetails => 'Show details';

  @override
  String get renameTitle => 'Edit name';

  @override
  String get renameLabel => 'Character name';

  @override
  String armorClassLabel(Object value) {
    return 'Armor Class: $value';
  }

  @override
  String abilityTile(String name, String mod, Object score) {
    return '$name: modifier $mod, score $score';
  }

  @override
  String abilityTileProficient(String name, String mod, Object score) {
    return '$name: modifier $mod, score $score, proficient in saving throws';
  }

  @override
  String abilityScoreShort(Object score) {
    return 'Score $score';
  }

  @override
  String get saveShort => 'SAVE';

  @override
  String saveShortValue(String bonus) {
    return 'SAVE $bonus';
  }

  @override
  String emblemLabel(String name) {
    return 'Emblem of $name';
  }

  @override
  String portraitLabel(String name) {
    return 'Portrait of $name';
  }

  @override
  String helpWhatItDoes(String name) {
    return 'See what $name does';
  }

  @override
  String usesAvailable(int filled, int max) {
    return '$filled of $max uses available';
  }

  @override
  String get sourceHomebrew => 'Custom';

  @override
  String sourceBadgeLabel(String source) {
    return 'Source: $source';
  }

  @override
  String get innateAtWill => 'at will';

  @override
  String get innateOncePerLongRest => 'once per long rest';

  @override
  String get innateOncePerShortRest => 'once per short rest';

  @override
  String get innateProficiencyBonus =>
      'a number of times equal to your proficiency bonus';

  @override
  String get innateAbilityModifier =>
      'a number of times equal to the ability modifier';

  @override
  String effectProficiency(String name) {
    return 'Proficiency: $name';
  }

  @override
  String effectSave(String ability) {
    return 'Saving throw: $ability';
  }

  @override
  String effectSaves(String parts) {
    return 'Saving throws $parts';
  }

  @override
  String effectModOf(String ability) {
    return '+ $ability mod.';
  }

  @override
  String get effectProficiencyBonusPart => '+ proficiency bonus';

  @override
  String effectLanguage(String name) {
    return 'Language: $name';
  }

  @override
  String effectResistance(String name) {
    return 'Resistance: $name';
  }

  @override
  String effectImmunity(String name) {
    return 'Immunity: $name';
  }

  @override
  String effectDarkvision(Object range) {
    return 'Darkvision: $range ft.';
  }

  @override
  String effectSpeedBonus(Object feet) {
    return 'Speed +$feet ft.';
  }

  @override
  String effectSpeedSet(Object feet) {
    return 'Speed = $feet ft.';
  }

  @override
  String effectAcBonus(Object amount) {
    return 'AC +$amount';
  }

  @override
  String effectInitiative(String parts) {
    return 'Initiative $parts';
  }

  @override
  String effectMaxHpPerLevel(Object perLevel) {
    return 'Max HP +$perLevel per level';
  }

  @override
  String effectMaxHpFlat(Object amount) {
    return 'Max HP +$amount';
  }

  @override
  String effectPassive(String name) {
    return 'Passive: $name';
  }

  @override
  String effectWeaponMastery(Object count) {
    return 'Weapon Mastery: $count';
  }

  @override
  String effectExtraAttack(Object extra) {
    return 'Extra Attack +$extra';
  }

  @override
  String effectFeat(String name) {
    return 'Feat: $name';
  }

  @override
  String get effectFeatChoice => 'your choice';

  @override
  String effectSpell(String name, String use) {
    return 'Spell: $name ($use)';
  }

  @override
  String effectAlwaysPrepared(String name) {
    return 'Always prepared: $name';
  }

  @override
  String effectAddedToList(String name) {
    return 'Added to your list: $name';
  }

  @override
  String get spellActionAction => 'Action';

  @override
  String get spellActionBonus => 'Bonus Action';

  @override
  String get spellActionReaction => 'Reaction';

  @override
  String get spellCantrip => 'Cantrip';

  @override
  String spellLevel(Object level) {
    return 'Level $level';
  }

  @override
  String get spellCastingTime => 'Casting Time';

  @override
  String get spellComponents => 'Components';

  @override
  String get spellDuration => 'Duration';

  @override
  String creatureSpellWith(String name) {
    return 'With $name';
  }

  @override
  String get creatureActions => 'Actions';

  @override
  String get creatureBonusActions => 'Bonus Actions';

  @override
  String get creatureReactions => 'Reactions';

  @override
  String get creatureLegendaryActions => 'Legendary Actions';

  @override
  String creatureLegendaryActionsPerRound(Object uses) {
    return 'Legendary Actions · $uses per round';
  }

  @override
  String get creatureAcShort => 'AC';

  @override
  String get hitPoints => 'Hit Points';

  @override
  String get hitPointsShort => 'HP';

  @override
  String hitPointsLabel(Object value) {
    return 'Hit Points: $value';
  }

  @override
  String get initiative => 'Initiative';

  @override
  String get challengeRating => 'Challenge Rating';

  @override
  String get challengeRatingShort => 'CR';

  @override
  String challengeRatingSemantics(String value) {
    return 'Challenge Rating: $value';
  }

  @override
  String get passivePerceptionShort => 'Pass. Perc.';

  @override
  String passivePerceptionLabel(Object value) {
    return 'Passive Perception: $value';
  }

  @override
  String get creatureSpeed => 'Speed';

  @override
  String get creatureSkills => 'Skills';

  @override
  String get creatureSenses => 'Senses';

  @override
  String get creatureLanguages => 'Languages';

  @override
  String get creatureDefenses => 'Defenses';

  @override
  String get creatureTraits => 'Traits';

  @override
  String get creatureToHit => 'To Hit';

  @override
  String get creatureDamage => 'Damage';

  @override
  String creatureSpellSaveDc(Object dc) {
    return 'DC $dc';
  }

  @override
  String creatureSpellAttack(String bonus) {
    return 'Attack $bonus';
  }

  @override
  String get creatureAtWill => 'At will';

  @override
  String creatureUsesPerDay(Object uses) {
    return '$uses/day each';
  }

  @override
  String creatureCastAtLevel(Object level) {
    return 'Cast at level $level';
  }

  @override
  String get commonCannotUndo => 'This can\'t be undone.';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonImport => 'Import';

  @override
  String commonLevel(Object level) {
    return 'Level $level';
  }

  @override
  String get transferTitle => 'Import / Export';

  @override
  String get transferImport => 'Import…';

  @override
  String get transferExportBackup => 'Export full backup';

  @override
  String deleteCharacterTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get exportingCharacter => 'Exporting character…';

  @override
  String get exportCharacterError => 'Couldn\'t export the character';

  @override
  String get creatingBackup => 'Creating backup…';

  @override
  String get backupError => 'Couldn\'t create the backup';

  @override
  String get importPickTitle => 'Choose a backup (.zip)';

  @override
  String get importBackupTitle => 'Import backup';

  @override
  String importBackupBody(String fileName) {
    return 'This will add the characters (and the homebrew and preferences, if the backup includes them) from \"$fileName\" to this account. Existing characters are left untouched; a repeated ID is saved as a new copy.';
  }

  @override
  String get importingBackup => 'Importing backup…';

  @override
  String importDone(int characters, int images) {
    String _temp0 = intl.Intl.pluralLogic(
      characters,
      locale: localeName,
      other: '$characters characters',
      one: '1 character',
    );
    String _temp1 = intl.Intl.pluralLogic(
      images,
      locale: localeName,
      other: '$images images',
      one: '1 image',
    );
    return 'Imported $_temp0 and $_temp1.';
  }

  @override
  String get importError => 'Couldn\'t import';

  @override
  String get operationBusy => 'An operation is already in progress.';

  @override
  String get rosterEmpty =>
      'There are no characters in this account yet.\nCreate the first one, bring in the ones you already had, or see what a sheet looks like with a sample character.';

  @override
  String get rosterCreate => 'Create character';

  @override
  String get rosterTryExample => 'Try a sample character';

  @override
  String rosterNoMatch(String query) {
    return 'No character matches \"$query\".\nSearch looks at name, class and species.';
  }

  @override
  String get rosterClearSearch => 'Clear search';

  @override
  String get rosterTitle => 'My characters';

  @override
  String rosterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: '1 character',
    );
    return '$_temp0';
  }

  @override
  String rosterFallen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count down',
      one: '1 down',
    );
    return '$_temp0';
  }

  @override
  String get rosterSearchHint => 'Search by name, class or species…';

  @override
  String get rosterSort => 'Sort';

  @override
  String get sortManual => 'Manual';

  @override
  String get sortRecent => 'Most recent';

  @override
  String get sortName => 'Name';

  @override
  String get sortLevel => 'Level';

  @override
  String get sortClass => 'Class';

  @override
  String get sortSaveError => 'Couldn\'t save the order of your characters';

  @override
  String get sortManualHint =>
      'Manual order: use \"Move earlier\" and \"Move later\" in each card\'s menu, or drag it onto another one.';

  @override
  String get saveLatestError => 'Couldn\'t save your latest changes';

  @override
  String get sessionExpiredTitle => 'Your session has ended';

  @override
  String get sessionExpiredBody =>
      'The changes that couldn\'t be saved yet are still on screen. Sign in again to keep editing.';

  @override
  String get sessionSignIn => 'Sign in';

  @override
  String get appTagline => 'Adventure Companion';

  @override
  String get navCharacters => 'Characters';

  @override
  String get navCodex => 'Codex';

  @override
  String get dmModeButton => 'DM Mode';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get signOutError => 'Couldn\'t sign out';

  @override
  String get characterFallenBadge => 'DOWN';

  @override
  String get hpLabelFallen => 'NO HIT POINTS';

  @override
  String get hpLabelCritical => 'CRITICAL HP';

  @override
  String get hpLabelNormal => 'HIT POINTS';

  @override
  String cardActionsTooltip(String name) {
    return 'Actions for $name';
  }

  @override
  String get cardFavorite => 'Mark as favorite';

  @override
  String get cardUnfavorite => 'Remove from favorites';

  @override
  String get cardMoveBefore => 'Move earlier';

  @override
  String get cardMoveAfter => 'Move later';

  @override
  String get cardRename => 'Rename';

  @override
  String get cardExport => 'Export';

  @override
  String get statSpeedShort => 'SPD';

  @override
  String get unitFeetSuffix => ' ft.';

  @override
  String statSpeedLabel(Object speed) {
    return 'Speed: $speed ft.';
  }

  @override
  String get statInitiativeShort => 'INIT';

  @override
  String statInitiativeLabel(String bonus) {
    return 'Initiative: $bonus';
  }

  @override
  String get tabCharacter => 'Character';

  @override
  String get tabCombat => 'Combat';

  @override
  String get tabInventory => 'Inventory';

  @override
  String get tabCampaign => 'Campaign';

  @override
  String get tabJournal => 'Journal';

  @override
  String sheetHeaderTitle(String name, Object level) {
    return '$name · Level $level';
  }

  @override
  String get levelUpAction => 'Level up';

  @override
  String get levelMaxReached => 'Max level';

  @override
  String get portraitClose => 'Close portrait';

  @override
  String get navBackToNpc => 'Back to the NPC';

  @override
  String sheetClassSummary(String summary, Object level) {
    return '$summary · level $level';
  }

  @override
  String get navPortrait => 'Portrait';

  @override
  String get navShare => 'Share';

  @override
  String get turnNext => 'Get ready, you\'re up next.';

  @override
  String get turnActive => 'It\'s your turn.';

  @override
  String get commonExpand => 'Expand';

  @override
  String get commonCollapse => 'Collapse';

  @override
  String get campaignStateActive => 'In progress';

  @override
  String get campaignStatePaused => 'Paused';

  @override
  String get campaignStateFinished => 'Finished';

  @override
  String get campaignsLoadError => 'Couldn\'t read your campaigns.';

  @override
  String get campaignsLoading => 'Loading your campaigns…';

  @override
  String get campaignEmpty =>
      'This character isn\'t in any campaign yet.\nShare it with your DM and what you play will show up here.';

  @override
  String campaignPartyAlso(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names are also at the table.',
      one: '$names is also at the table.',
    );
    return '$_temp0';
  }

  @override
  String get campaignNoChapter => 'No chapter';

  @override
  String get campaignBattles => 'Battles';

  @override
  String roundsCount(int rounds) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds rounds',
      one: '1 round',
    );
    return '$_temp0';
  }

  @override
  String get campaignNoBattles => 'They haven\'t fought any yet.';

  @override
  String get battleAlone => 'Alone';

  @override
  String battleWith(String names) {
    return 'With $names';
  }

  @override
  String get battleGeneric => 'A fight';

  @override
  String battleAgainst(String names) {
    return 'Against $names';
  }

  @override
  String get enemyOne => 'an enemy';

  @override
  String enemiesCount(Object count) {
    return '$count enemies';
  }

  @override
  String get battleNoEnemies => 'no enemies';

  @override
  String get battleNoneDown => 'none went down';

  @override
  String get battleOneDown => 'it went down';

  @override
  String get battleAllDown => 'all went down';

  @override
  String battleSomeDown(Object down, Object total) {
    return '$down of $total went down';
  }

  @override
  String get campaignClosedChapters => 'Closed chapters';

  @override
  String get campaignNoClosedChapters =>
      'They haven\'t closed any yet. When they do, what was handed out will be noted here.';

  @override
  String get campaignNoRewards => 'No rewards';

  @override
  String campaignYouTook(String grants) {
    return 'You took $grants';
  }

  @override
  String listAnd(String head, String last) {
    return '$head and $last';
  }

  @override
  String get commonBack => 'Back';

  @override
  String hpMaxSuffix(Object max) {
    return '/ $max HP';
  }

  @override
  String get deathSaves => 'Death saves';

  @override
  String get combatAmount => 'Amount';

  @override
  String get combatHeal => 'Heal';

  @override
  String get combatTempHp => 'Temp HP';

  @override
  String get combatStabilized => 'Stabilized!';

  @override
  String get combatSuccessPlus => '+Success';

  @override
  String get combatCharacterDied => 'The character has died.';

  @override
  String get combatFailurePlus => '+Failure';

  @override
  String get combatNoArmor => 'No armor';

  @override
  String get combatShield => 'shield';

  @override
  String get combatDefense => 'Defense';

  @override
  String combatResistances(String list) {
    return 'Resistances: $list';
  }

  @override
  String combatImmunities(String list) {
    return 'Immunities: $list';
  }

  @override
  String get shortRestNoRestore =>
      'Short rest. It doesn\'t heal HP: spend Hit Dice to heal.';

  @override
  String shortRestRestored(String list) {
    return 'Short rest: you regained $list. To heal, spend Hit Dice.';
  }

  @override
  String get longRestBase => 'HP restored to max and resources recharged';

  @override
  String longRestExhaustion(Object level) {
    return 'exhaustion down to level $level';
  }

  @override
  String get longRestInspiration => 'you gained Heroic Inspiration';

  @override
  String longRestItemsRecharged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count magic items regained charges',
      one: '1 magic item regained charges',
    );
    return '$_temp0';
  }

  @override
  String longRestSummary(String list) {
    return 'Long rest: $list.';
  }

  @override
  String get combatResourcesTitle => 'Resources and rests';

  @override
  String get combatRestExplainer =>
      'A short rest doesn\'t heal HP: it recharges short-rest resources. To heal, spend Hit Dice.';

  @override
  String get restShort => 'Short rest';

  @override
  String get restLong => 'Long rest';

  @override
  String combatHitDie(Object left, Object total) {
    return 'Hit Die ($left/$total)';
  }

  @override
  String saveDc(Object dc) {
    return 'DC $dc';
  }

  @override
  String saveDcAbility(Object dc, String ability) {
    return 'DC $dc $ability';
  }

  @override
  String combatPointsOf(Object left, Object max) {
    return '$left of $max points';
  }

  @override
  String get verbSpend => 'spend';

  @override
  String get verbRecover => 'recover';

  @override
  String combatPointsPrompt(String verb, Object limit) {
    return 'Points to $verb (up to $limit)';
  }

  @override
  String get combatAttacks => 'Attacks';

  @override
  String combatMastery(String name) {
    return 'Mastery: $name';
  }

  @override
  String combatRangeValue(String range) {
    return 'Range $range';
  }

  @override
  String get combatOffHand => 'Off hand';

  @override
  String wildShapeAs(String name) {
    return 'Transformed into $name';
  }

  @override
  String get wildShapeTitle => 'Wild Shape';

  @override
  String get wildShapeAddForms => 'Add forms';

  @override
  String get wildShapeNoForms => 'You haven\'t added any forms yet.';

  @override
  String creatureLine3(String kind, Object ac, String speed) {
    return '$kind · AC $ac · $speed';
  }

  @override
  String creatureLine2(String kind, Object ac) {
    return '$kind · AC $ac';
  }

  @override
  String get wildShapeTransform => 'Transform';

  @override
  String wildShapeDone(String name, Object level) {
    return 'You transformed into $name: +$level temporary HP.';
  }

  @override
  String get wildShapeNoUses => 'You have no Wild Shape uses left.';

  @override
  String wildShapeKnownTitle(Object chosen, Object total) {
    return 'Known forms ($chosen/$total)';
  }

  @override
  String get companionsTitle => 'Companions';

  @override
  String get companionHpAmount => 'HP amount';

  @override
  String get companionSummon => 'Summon';

  @override
  String get companionSummonAnother => 'Summon another';

  @override
  String get companionNone => 'None summoned.';

  @override
  String get companionSummonAnyway => 'Summon anyway';

  @override
  String get companionLimitOneTitle => 'You already have one in play';

  @override
  String get companionLimitMaxTitle => 'You\'ve reached the maximum';

  @override
  String companionLimitOneBody(String going) {
    return 'Summoning another one makes $going disappear, along with whatever hit points it has.';
  }

  @override
  String companionLimitMaxBody(Object max, String going) {
    return 'You already have $max. Summoning another one makes the oldest, $going, disappear.';
  }

  @override
  String get companionPickForm => 'Choose the form';

  @override
  String companionNoSlots(Object level) {
    return 'You have no spell slots of level $level or higher left.';
  }

  @override
  String get companionHowSummon => 'How to summon it';

  @override
  String get companionNoSlotSpend => 'Without spending a slot';

  @override
  String companionFreeLeft(String name, Object left, Object max) {
    return '$name: $left of $max left';
  }

  @override
  String companionSlotsAvailable(Object left, Object total) {
    return '$left of $total available';
  }

  @override
  String companionNoteSlot(Object level) {
    return 'you spent a level $level slot';
  }

  @override
  String companionNoteFree(String name) {
    return 'without spending a slot, thanks to $name';
  }

  @override
  String get companionNoteBroke => 'you lost your previous concentration';

  @override
  String get companionNoteConcentrating => 'you\'re now concentrating on it';

  @override
  String companionSummoned(String name) {
    return '$name summoned.';
  }

  @override
  String companionSummonedNotes(String name, String notes) {
    return '$name summoned: $notes.';
  }

  @override
  String get companionGone => 'This creature is no longer in the catalog.';

  @override
  String get companionDismiss => 'Dismiss';

  @override
  String acValue(Object value) {
    return 'AC $value';
  }

  @override
  String companionSlotLevel(Object level) {
    return 'Level $level slot';
  }

  @override
  String get concentration => 'Concentration';

  @override
  String hpFraction(Object current, Object max) {
    return '$current / $max HP';
  }

  @override
  String companionDestroyed(String name) {
    return '$name was destroyed.';
  }

  @override
  String get savesTitle => 'Saving throws';

  @override
  String get exhaustion => 'Exhaustion';

  @override
  String exhaustionRules(Object max) {
    return 'Each level subtracts 2 from ability checks, saving throws, attack rolls and initiative, and 5 feet from speed. At level $max the character dies.\n\nThe sheet already applies the penalty to all of its numbers: do not subtract it again. It also affects death saves, even though those carry no number.\n\nA long rest lowers it by one level.';
  }

  @override
  String get combatState => 'Status';

  @override
  String exhaustionPenalty(Object rolls, Object feet) {
    return '−$rolls to rolls · −$feet ft.';
  }

  @override
  String get exhaustionLower => 'Lower exhaustion by one level';

  @override
  String get exhaustionRaise => 'Raise exhaustion by one level';

  @override
  String exhaustionDeath(Object max) {
    return 'Exhaustion level $max: your character dies.';
  }

  @override
  String exhaustionNote(Object max) {
    return 'Level $max: your character dies. The sheet doesn\'t apply it or touch your HP — that decision is up to the table.';
  }

  @override
  String get inspirationUse =>
      'Reroll a die right after rolling it and keep the new result';

  @override
  String get inspirationLongRest => 'You regain it when you finish a long rest';

  @override
  String get inspirationGrant => 'Mark it when the DM gives it to you';

  @override
  String get inspirationSpend => 'Spend Heroic Inspiration';

  @override
  String get inspirationMark => 'Mark that you have it';

  @override
  String get heroicInspiration => 'Heroic Inspiration';

  @override
  String get inspirationHave => 'YOU HAVE IT';

  @override
  String get inspirationSpent => 'SPENT';

  @override
  String get conditionsTitle => 'Conditions';

  @override
  String combatHitDieHealed(Object hp) {
    return 'You recovered $hp HP (Hit Die)';
  }

  @override
  String wildShapeUses(Object left, Object max) {
    return 'Uses: $left of $max';
  }

  @override
  String wildShapeForms(Object chosen, Object total) {
    return 'Forms: $chosen of $total';
  }

  @override
  String exhaustionLevelOf(Object level, Object max) {
    return 'Exhaustion: level $level of $max';
  }

  @override
  String get replaceProficiency => 'Replaceable proficiency';

  @override
  String get replaceChoice => 'Replaceable choice';

  @override
  String get replaceSpells => 'Replaceable spells';

  @override
  String get sheetWarnings => 'Warnings';

  @override
  String get sheetResolve => 'Resolve';

  @override
  String get replaceableNoticeBody =>
      'This feature lets you change the choice you already made.';

  @override
  String get sheetChange => 'Change';

  @override
  String get pickExpertiseTitle => 'Choose Expertise';

  @override
  String get pickProficienciesTitle => 'Choose proficiencies';

  @override
  String get pickProficienciesHint =>
      'Options you already have from another source are locked. Expertise slots work the other way around: only skills you are already proficient in are offered, and you double the bonus in them.';

  @override
  String get pickSizeTitle => 'Choose size';

  @override
  String get pickSizeHint =>
      'This species covers bodies of different sizes: choose your character\'s.';

  @override
  String get pickLineageTitle => 'Choose lineage';

  @override
  String get pickLineageHint =>
      'The lineage decides which traits the species gives.';

  @override
  String get pickSpellAbilityTitle => 'Choose spellcasting ability';

  @override
  String get pickLineageSpellAbilityHint =>
      'It\'s used for the save DC and attack rolls of the lineage\'s spells.';

  @override
  String pickFeatSpellAbilityTitle(String name) {
    return 'Spellcasting ability for $name';
  }

  @override
  String get pickFeatSpellAbilityHint =>
      'It\'s used for the save DC and attack rolls of this feat\'s spells.';

  @override
  String get pickFeaturesTitle => 'Choose features';

  @override
  String get pickNoOptions => 'No options available yet.';

  @override
  String get pickSpellsTitle => 'Choose spells';

  @override
  String get pickKnownSpellHint =>
      'Choose one you already know: it isn\'t added to your spells, it adds the bonus to its damage.';

  @override
  String get pickNoSpells => 'No spells available for this feature.';

  @override
  String get pickLanguagesTitle => 'Choose languages';

  @override
  String pickLanguagesIntro(String language) {
    return 'Every character knows $language, which does not use up a choice.';
  }

  @override
  String pickLanguagesOrigin(Object chosen, Object total) {
    return 'From your origin ($chosen/$total)';
  }

  @override
  String get identityAlignment => 'Alignment';

  @override
  String get identityCreatureType => 'Creature type';

  @override
  String get identitySize => 'Size';

  @override
  String get identityBackground => 'Background';

  @override
  String get identityTrait => 'Trait';

  @override
  String get identityTitle => 'Identity';

  @override
  String get abilitiesTitle => 'Abilities';

  @override
  String get abilitiesHintLead => 'The big number is the modifier. ';

  @override
  String get abilitiesHintTail =>
      ' marks proficient saving throws; tap a plaque to see where it comes from.';

  @override
  String get unarmoredTitle => 'Unarmored Defense';

  @override
  String get unarmoredFormula => 'AC formula';

  @override
  String get proficienciesTitle => 'Proficiencies';

  @override
  String get armorUpper => 'ARMOR';

  @override
  String get passivePerception => 'Passive Perception';

  @override
  String get darkvision => 'Darkvision';

  @override
  String get skillsLegendProficient => 'Proficient';

  @override
  String get skillsLegendExpertise => 'Expertise · doubled bonus';

  @override
  String get skillExpertiseBadge => 'EXPERTISE';

  @override
  String get traitsAndFeatsTitle => 'Features and feats';

  @override
  String get statArmor => 'Armor';

  @override
  String exhaustionSpeed(Object feet) {
    return 'Exhaustion −$feet ft.';
  }

  @override
  String get statProficiency => 'Proficiency';

  @override
  String get breakdownWhereFrom => 'Where it comes from';

  @override
  String get breakdownDexModifier => 'Dexterity modifier';

  @override
  String get breakdownOtherTrait => 'Another feature';

  @override
  String exhaustionLevel(Object level) {
    return 'Exhaustion level $level';
  }

  @override
  String get breakdownAssigned => 'Assigned at creation';

  @override
  String get breakdownScore => 'Score';

  @override
  String get breakdownModifier => 'Modifier';

  @override
  String get breakdownWhatToRoll => 'What you roll with this';

  @override
  String get breakdownSave => 'Saving throw';

  @override
  String get breakdownSaveProficient => 'Saving throw (proficient)';

  @override
  String breakdownSkillExpertise(String skill) {
    return '$skill (expertise)';
  }

  @override
  String breakdownIncludes(String amount, String source) {
    return 'includes $amount from $source';
  }

  @override
  String get breakdownAbilityChecks => 'Ability checks';

  @override
  String breakdownExhaustion(Object penalty, Object level) {
    return 'includes −$penalty from exhaustion level $level';
  }

  @override
  String get breakdownSpellAttack => 'Spell attack';

  @override
  String get breakdownSaveDc => 'Save DC';

  @override
  String breakdownFooter(Object bonus, Object level, String check) {
    return 'Proficiency +$bonus at level $level, already included above. Only skills you are proficient in are listed: the rest roll with the ability check ($check).';
  }

  @override
  String get commonAdd => 'Add';

  @override
  String get commonBuy => 'Buy';

  @override
  String get commonSell => 'Sell';

  @override
  String get commonBag => 'Bag';

  @override
  String get kindWeapon => 'Weapon';

  @override
  String get kindArmor => 'Armor';

  @override
  String get kindAmmunition => 'Ammunition';

  @override
  String get kindFocus => 'Focus';

  @override
  String get kindMagicItem => 'Magic item';

  @override
  String get kindTool => 'Tool';

  @override
  String get kindContainer => 'Container';

  @override
  String get kindPack => 'Pack';

  @override
  String get kindGear => 'Gear';

  @override
  String get kindShield => 'Shield';

  @override
  String get groupWeapons => 'Weapons';

  @override
  String get groupArmor => 'Armor';

  @override
  String get groupFocuses => 'Focuses';

  @override
  String get groupMagicItems => 'Magic items';

  @override
  String get groupTools => 'Tools';

  @override
  String get groupContainers => 'Containers';

  @override
  String get groupPacks => 'Packs';

  @override
  String get catalogNotInCatalog => 'Not in the catalog';

  @override
  String get filterAll => 'All';

  @override
  String get filterEquipped => 'Equipped';

  @override
  String get filterMagic => 'Magic';

  @override
  String get coinCopper => 'copper';

  @override
  String get coinSilver => 'silver';

  @override
  String get coinElectrum => 'electrum';

  @override
  String get coinGold => 'gold';

  @override
  String get coinPlatinum => 'platinum';

  @override
  String get coinAbbrCopper => 'cp';

  @override
  String get coinAbbrSilver => 'sp';

  @override
  String get coinAbbrElectrum => 'ep';

  @override
  String get coinAbbrGold => 'gp';

  @override
  String get coinAbbrPlatinum => 'pp';

  @override
  String catalogBundleOf(Object size) {
    return 'pack of $size';
  }

  @override
  String get catalogAttunement => 'attunement';

  @override
  String catalogMissing(String amount) {
    return '$amount short';
  }

  @override
  String catalogShortBy(String amount) {
    return 'Short by $amount';
  }

  @override
  String get catalogAddTitle => 'Add item';

  @override
  String get catalogSearchHint => 'Search items…';

  @override
  String get catalogNoMatches => 'No matches.';

  @override
  String catalogAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added to your pack.',
      one: '1 item added to your pack.',
    );
    return '$_temp0';
  }

  @override
  String get tradeUnitBundle => 'pack';

  @override
  String get tradeUnitItem => 'unit';

  @override
  String tradeBundles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs',
      one: '1 pack',
    );
    return '$_temp0';
  }

  @override
  String tradeUnitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return '$_temp0';
  }

  @override
  String get tradeQuantity => 'Quantity';

  @override
  String tradeTotalUnits(Object count) {
    return '$count in total';
  }

  @override
  String tradeLeft(Object count) {
    return '$count left';
  }

  @override
  String get tradeOneLess => 'One less';

  @override
  String get tradeOneMore => 'One more';

  @override
  String tradeBuyPrice(String unit) {
    return 'Price per $unit';
  }

  @override
  String tradeSellPrice(String unit) {
    return 'You get paid per $unit';
  }

  @override
  String tradeCatalogPrice(String price) {
    return 'Catalog: $price';
  }

  @override
  String tradeSuggested(String price) {
    return 'Suggested: half the catalog price, $price.';
  }

  @override
  String get tradeBackCatalog => 'Back to the catalog price';

  @override
  String get tradeBackSuggested => 'Back to the suggested price';

  @override
  String get tradeTotalBuy => 'TOTAL';

  @override
  String get tradeTotalSell => 'YOU GET';

  @override
  String tradeShort(String amount) {
    return 'You are short $amount. If the DM gives it to you or lets you have it on credit, close this and use \"Add\".';
  }

  @override
  String tradePaidFrom(String coins) {
    return 'Paid from your bag: $coins.';
  }

  @override
  String tradeChange(String coins) {
    return 'You get back $coins.';
  }

  @override
  String tradeBagAfter(String amount) {
    return 'Your bag will hold $amount.';
  }

  @override
  String tradeBagAfterCoins(String amount, String coins) {
    return 'Your bag will hold $amount ($coins).';
  }

  @override
  String get commonDone => 'Done';

  @override
  String get invCoins => 'Coins';

  @override
  String get invCoinsEquals => 'Worth ';

  @override
  String get invCoinsWeigh => ' gp · weigh ';

  @override
  String invCoinLabel(String name, String abbr) {
    return '$name coins ($abbr)';
  }

  @override
  String get invLoad => 'Load';

  @override
  String invLoadPercent(Object percent) {
    return '$percent% of capacity';
  }

  @override
  String invLoadItems(String weight) {
    return 'Items $weight lb';
  }

  @override
  String invLoadCoins(String weight) {
    return 'Coins $weight lb';
  }

  @override
  String get invOverCapacity =>
      'You\'re over your carrying capacity. In 2024 there\'s no rules penalty: it\'s a warning, not a block.';

  @override
  String get invAttunementUpper => 'ATTUNEMENT';

  @override
  String get invAttunementHint =>
      'You attune from each item\'s menu; here you can see how many slots are left and what they\'re taken by.';

  @override
  String get invAttuneSlotFree => 'Free attunement slot';

  @override
  String invAttunedName(String name) {
    return '$name — attuned';
  }

  @override
  String get invSlotFree => 'Free slot';

  @override
  String get invTitle => 'Inventory';

  @override
  String get invEmpty => 'Your pack is empty.';

  @override
  String invPlansButton(Object chosen, Object total) {
    return 'Blueprints and replicas ($chosen/$total)';
  }

  @override
  String get invSearchHint => 'Search your pack…';

  @override
  String get invNoMatches => 'No item matches that filter.';

  @override
  String get invHeadItem => 'ITEM';

  @override
  String get invHeadQty => 'QTY';

  @override
  String get invHeadEquipped => 'EQUIPPED';

  @override
  String get invHeadWeight => 'WEIGHT';

  @override
  String get invNoWeight => 'No weight';

  @override
  String invRemoveOne(String name) {
    return 'Remove one $name';
  }

  @override
  String invAddOne(String name) {
    return 'Add one $name';
  }

  @override
  String invCharges(Object left) {
    return '$left charges';
  }

  @override
  String invChargesOf(Object left, Object max) {
    return 'Charges $left/$max';
  }

  @override
  String invSpendCharge(String name) {
    return 'Spend a charge of $name';
  }

  @override
  String invRecoverCharge(String name) {
    return 'Recover a charge of $name';
  }

  @override
  String get invSeeWhatItDoes => 'See what it does';

  @override
  String get invAttuned => 'Attuned';

  @override
  String get invReplica => 'Replica';

  @override
  String get invNotEquippable => 'Can\'t be equipped';

  @override
  String get invEquipped => 'Equipped';

  @override
  String get invExactQuantity => 'Exact quantity…';

  @override
  String get invNote => 'Note…';

  @override
  String get invUnattune => 'Remove attunement';

  @override
  String get invAttune => 'Attune';

  @override
  String get invTwoHanded => 'Two-handed';

  @override
  String get invTransmute => 'Transmute replica…';

  @override
  String get invSellMenu => 'Sell…';

  @override
  String get invRemove => 'Remove';

  @override
  String invBundlesOf(Object size) {
    return 'Packs of $size';
  }

  @override
  String get invUnits => 'Units';

  @override
  String get invNoteTitle => 'Note';

  @override
  String get invNoteLabel => 'What it says, where it came from, what it is for';

  @override
  String invRemoved(String name) {
    return 'You removed $name.';
  }

  @override
  String get invTransmuteInto => 'Transmute into';

  @override
  String get invCatalogHint =>
      'Adding is free and lets you keep adding; buying pays from your bag.';

  @override
  String invBuyTitle(String name) {
    return 'Buy $name';
  }

  @override
  String invBought(Object quantity, String name, String amount) {
    return 'You bought $quantity × $name for $amount.';
  }

  @override
  String invSellTitle(String name) {
    return 'Sell $name';
  }

  @override
  String invSellDetail(Object quantity, String price) {
    return 'You have $quantity · catalog $price';
  }

  @override
  String invSold(Object quantity, String name, String amount) {
    return 'You sold $quantity × $name for $amount.';
  }

  @override
  String get invTargetHint =>
      'Choose a copy from your pack or create one of those the feature allows.';

  @override
  String get invInPack => 'In your pack';

  @override
  String get invNoEligible => 'There are no eligible copies.';

  @override
  String get invCreatedByFeature => 'Created by this feature';

  @override
  String get invCreateWeapon => 'Create weapon';

  @override
  String get invAddAndEquip => 'Add and equip';

  @override
  String get invClearLink => 'Clear link';

  @override
  String invPlansIntro(int count, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active active replicas',
      one: '1 active replica',
    );
    return 'You choose $count blueprints. Then you decide which one to replicate: you can have $_temp0 at a time.';
  }

  @override
  String get invActiveReplicas => 'Active replicas';

  @override
  String invPlansMissing(Object count) {
    return '$count still to choose.';
  }

  @override
  String get invPickBlueprint => 'Choose a blueprint so you can replicate it.';

  @override
  String invReplicaSlotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free slots left.',
      one: '1 free slot left.',
    );
    return '$_temp0';
  }

  @override
  String get invReplicaNoSlots =>
      'No free slots: remove a replica to create another.';

  @override
  String invRemoveReplica(String name) {
    return 'Remove the replica of $name';
  }

  @override
  String invCreateReplica(String name) {
    return 'Create a replica of $name';
  }

  @override
  String get invNoReplicaSlots => 'No replica slots left';

  @override
  String get invPickBase => 'Choose the base item';

  @override
  String invRangeHint(String range) {
    return 'range $range';
  }

  @override
  String get invTwoHandedMounted => 'requires two hands unless mounted';

  @override
  String get invTwoHandedHint => 'requires two hands';

  @override
  String get commonEdit => 'Edit';

  @override
  String get diaryImportMd => 'Import a .md file';

  @override
  String get diaryExportMd => 'Export as .md';

  @override
  String get diaryFinishEditing => 'Finish editing';

  @override
  String get diaryEditBackground => 'Edit the background';

  @override
  String get diaryBackgroundHint =>
      'Where they come from, what they left behind, who they owe…';

  @override
  String get diaryMarkdownHint =>
      'Markdown is supported: # for headings, **bold**, *italic* and - for bullets.';

  @override
  String get diaryUnknownOrigin => 'Unknown origin';

  @override
  String diaryUnknownOriginBody(String name) {
    return 'Nobody has written where $name comes from yet. You can write it here, or bring in a .md file you already have.';
  }

  @override
  String get diaryWriteBackground => 'Write the background';

  @override
  String get diaryImportMdShort => 'Import .md';

  @override
  String get diaryPickMd => 'Choose a .md file';

  @override
  String get diaryOpenError => 'Couldn\'t open the file';

  @override
  String get diaryReplaceTitle => 'Replace the background';

  @override
  String get diaryReplaceBody =>
      'What\'s written now is lost and replaced by the file\'s content. There\'s no way to recover it.';

  @override
  String get diaryReplace => 'Replace';

  @override
  String get diaryNotUtf8 => 'The file doesn\'t look like UTF-8 text.';

  @override
  String get diaryImported => 'Background imported.';

  @override
  String get diaryFileSuffix => 'background';

  @override
  String get diaryFileFallback => 'character';

  @override
  String get diaryEntries => 'Entries';

  @override
  String get diaryAddEntryTooltip => 'Add an entry';

  @override
  String diaryEmpty(String name) {
    return '$name\'s journal is still blank.\nAdd art, a short story, a quirk — whatever you like about this character.';
  }

  @override
  String get diaryAddEntry => 'Add entry';

  @override
  String diaryDeleted(String title) {
    return 'You deleted \"$title\".';
  }

  @override
  String diaryDeleteBody(String title) {
    return '\"$title\" is leaving the journal.';
  }

  @override
  String diaryDeleteBodyImage(String title) {
    return '\"$title\" is leaving the journal, and the image you uploaded is deleted with it. There is no way to recover it.';
  }

  @override
  String get diaryUntitled => 'Untitled';

  @override
  String get diaryDragHint => 'Press and hold to reorder';

  @override
  String get diaryNoImage => 'No image.';

  @override
  String get diaryKindText => 'Text';

  @override
  String get diaryKindImage => 'Image';

  @override
  String get diaryKindLink => 'Link';

  @override
  String diaryEditedOn(String date, String edited) {
    return '$date · edited $edited';
  }

  @override
  String get diaryEntryNoImage => 'This entry doesn\'t have an image.';

  @override
  String get diarySeeFullImage => 'See the full image';

  @override
  String get diaryImageGone => 'The image is no longer in storage.';

  @override
  String get diaryDeleteTitle => 'Delete the entry';

  @override
  String get diaryPickImage => 'Choose an image';

  @override
  String get diaryUploadError => 'Couldn\'t upload the image';

  @override
  String get diaryNewEntry => 'New entry';

  @override
  String get diaryEditEntry => 'Edit entry';

  @override
  String get diaryTitleLabel => 'Title';

  @override
  String get diaryEntryType => 'Entry type';

  @override
  String get diaryBodyHint => 'Whatever you want to tell about this character…';

  @override
  String get diaryUploading => 'Uploading the image…';

  @override
  String get diaryChooseImage => 'Choose image';

  @override
  String get diaryChangeImage => 'Change image';

  @override
  String get diaryImageFormats =>
      'PNG, JPEG or WEBP. Same size limit as portraits.';

  @override
  String get spellsTitle => 'Spells';

  @override
  String get spellsPrepare => 'Prepare';

  @override
  String get spellsSaveDcShort => 'SAVE DC';

  @override
  String spellsSaveDcSemantics(Object dc) {
    return 'Difficulty class of saving throws against your spells: $dc';
  }

  @override
  String get spellsAttackUpper => 'ATTACK';

  @override
  String get spellsAbilityUpper => 'ABILITY';

  @override
  String spellsAbilitySemantics(String name) {
    return 'Spellcasting ability: $name';
  }

  @override
  String spellsPrepared(Object count, Object max) {
    return 'Prepared: $count / $max';
  }

  @override
  String spellsKnown(Object count) {
    return 'Known: $count';
  }

  @override
  String spellsCantrips(Object count, Object max) {
    return 'Cantrips: $count / $max';
  }

  @override
  String get spellsSources => 'Spellcasting sources';

  @override
  String spellsSourcePrepared(Object level, String ability) {
    return 'Level $level · $ability · prepared';
  }

  @override
  String spellsSourceKnown(Object level, String ability) {
    return 'Level $level · $ability · known';
  }

  @override
  String get spellsFromFeatures => 'Spells from features';

  @override
  String spellsWildShapeBlock(String name) {
    return 'You can\'t cast spells in $name form.';
  }

  @override
  String spellsConcentratingOn(String spell) {
    return 'Concentrating on $spell';
  }

  @override
  String get spellsEndConcentration => 'End';

  @override
  String get spellsSlots => 'Spell slots';

  @override
  String get spellsPactSlots => 'Pact slots';

  @override
  String get spellsCantripsTitle => 'Cantrips';

  @override
  String get spellsAlwaysPrepared => 'Always prepared';

  @override
  String get spellsAlwaysPreparedHint =>
      'A feature grants them and they take no slot: you cast them with your spell slots like any prepared spell.';

  @override
  String get spellsPreparedTitle => 'Prepared spells';

  @override
  String get spellsKnownTitle => 'Known spells';

  @override
  String get spellsNoneChosen =>
      'You haven\'t chosen any spells yet. Edit when you level up or create the character.';

  @override
  String get spellsUseLongRest => '1/long rest';

  @override
  String get spellsUseShortRest => '1/short rest';

  @override
  String get spellsUseProficiency => 'Proficiency/long rest';

  @override
  String spellsUseAbilityMod(Object uses, String ability) {
    return '$uses/long rest ($ability)';
  }

  @override
  String get spellsSwapTooltip => 'Change after a long rest';

  @override
  String get spellsConcentrate => 'Concentrate';

  @override
  String get spellsCutTitle => 'Break concentration';

  @override
  String spellsCutBody(String spell, String previous, int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'go',
      one: 'goes',
    );
    return 'Concentrating on $spell ends $previous, and $names $_temp0 with it.';
  }

  @override
  String get spellsCurrentConcentration => 'your current concentration';

  @override
  String get spellsConcentrateAnyway => 'Concentrate anyway';

  @override
  String spellsSwitched(String spell, String previous) {
    return 'You\'re now concentrating on $spell: you dropped $previous.';
  }

  @override
  String spellsSwitchedDeps(
    String spell,
    String previous,
    int count,
    String names,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'go',
      one: 'goes',
    );
    return 'You\'re now concentrating on $spell: you dropped $previous, and $names $_temp0 with it.';
  }

  @override
  String spellsSwapTitle(String name) {
    return 'Swap $name';
  }

  @override
  String spellsSwapBody(String lists) {
    return 'After finishing a long rest you can swap it for another cantrip from $lists.';
  }

  @override
  String get spellsSwapOriginal => 'The feature\'s own';

  @override
  String spellsListOf(String name) {
    return 'the $name list';
  }

  @override
  String listOr(String head, String last) {
    return '$head or $last';
  }

  @override
  String get spellsSpendSlot => 'Spend slot';

  @override
  String get spellsRecoverSlot => 'Recover slot';

  @override
  String get spellsWithCharacter => 'With this character';

  @override
  String spellsCastWith(String ability, String mod, String attack, Object dc) {
    return 'You cast with $ability ($mod). Spell attack $attack · save DC $dc.';
  }

  @override
  String spellsDamageBonus(String bonus, String sources) {
    return '$bonus damage ($sources)';
  }

  @override
  String get stepSpecies => 'Species';

  @override
  String get stepClass => 'Class';

  @override
  String get stepBackground => 'Background';

  @override
  String get stepScores => 'Scores';

  @override
  String get stepProficiencies => 'Proficiencies';

  @override
  String get stepEquipment => 'Equipment';

  @override
  String get stepDetails => 'Details';

  @override
  String get stepSummary => 'Summary';

  @override
  String get pendingPickSpecies => 'Choose a species.';

  @override
  String get pendingPickLineage => 'Choose a species lineage.';

  @override
  String get pendingPickLineageAbility =>
      'Choose the lineage spellcasting ability.';

  @override
  String get pendingPickSize => 'Choose the size of the species.';

  @override
  String get pendingPickClass => 'Choose a class.';

  @override
  String pendingSlotProgress(String name, Object chosen, Object total) {
    return '$name: $chosen/$total.';
  }

  @override
  String pendingWeaponMastery(Object chosen, Object total) {
    return 'Weapon Mastery: $chosen/$total.';
  }

  @override
  String get pendingPickBackground => 'Choose a background.';

  @override
  String pendingPickFeatAbility(String name) {
    return 'Choose the spellcasting ability for $name.';
  }

  @override
  String get pendingSpread => 'Assign the +2 and the +1 to abilities.';

  @override
  String pendingAssignScores(Object count) {
    return 'Assign all 6 abilities ($count/6).';
  }

  @override
  String pendingClassSkills(Object chosen, Object total) {
    return 'Class skills: $chosen/$total.';
  }

  @override
  String pendingSpeciesSkills(Object chosen, Object total) {
    return 'Species skills: $chosen/$total.';
  }

  @override
  String get pendingPickOriginFeat => 'Choose an origin feat.';

  @override
  String pendingProficiencies(Object count) {
    return 'Pending proficiencies: $count.';
  }

  @override
  String pendingExpertise(Object count) {
    return 'Pending expertise: $count.';
  }

  @override
  String pendingLanguages(Object chosen, Object total) {
    return 'Languages: $chosen/$total.';
  }

  @override
  String pendingLanguageChoices(Object count) {
    return 'Pending languages from features: $count.';
  }

  @override
  String get pendingClassEquipment => 'Choose the class equipment.';

  @override
  String get pendingBackgroundEquipment => 'Choose the background equipment.';

  @override
  String get pendingEquipmentChoices => 'Finish the inner equipment choices.';

  @override
  String pendingOverspent(String amount) {
    return 'Your purchases exceed the starting gold by $amount.';
  }

  @override
  String pendingSpellChoices(Object count) {
    return 'Spells to choose: $count.';
  }

  @override
  String pendingCantrips(Object chosen, Object total) {
    return 'Cantrips: $chosen/$total.';
  }

  @override
  String pendingSpells(Object chosen, Object total) {
    return 'Spells: $chosen/$total.';
  }

  @override
  String get characterUnnamed => 'Unnamed';

  @override
  String get wizardCreateNpc => 'Create NPC';

  @override
  String get wizardDiscardNpc => 'Discard this NPC?';

  @override
  String get wizardDiscardCharacter => 'Discard this character?';

  @override
  String get wizardDiscardBody =>
      'The choices you made in the wizard will be lost.';

  @override
  String get wizardKeepCreating => 'Keep creating';

  @override
  String get wizardDiscard => 'Discard';

  @override
  String get wizardProgress => 'Progress';

  @override
  String wizardStepOf(Object step, Object total) {
    return 'Step $step of $total';
  }

  @override
  String wizardStepSemantics(String name, Object step, Object total) {
    return '$name, step $step of $total';
  }

  @override
  String get wizardFinishPrevious => 'Finish the previous steps';

  @override
  String get wizardProgressSemantics => 'Creation progress';

  @override
  String get wizardBack => 'Back';

  @override
  String wizardMissing(String item) {
    return 'Missing: $item';
  }

  @override
  String wizardMissingMore(String first, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'things',
      one: 'thing',
    );
    return 'Missing: $first (and $count more $_temp0).';
  }

  @override
  String get wizardNext => 'Next';

  @override
  String get detailsEmblem => 'Emblem';

  @override
  String detailsEmblemBody(String klass) {
    return 'Until you give them a portrait, your character uses the $klass emblem.';
  }

  @override
  String get detailsYourClass => 'their class';

  @override
  String get detailsPortraitLater =>
      'You can generate or choose a portrait later, from the character sheet.';

  @override
  String get detailsName => 'Name';

  @override
  String get detailsUndefined => 'Undefined';

  @override
  String get detailsTrait => 'Personality trait';

  @override
  String get detailsTraitHint =>
      'A line that defines them. E.g. \"Never leaves a debt unpaid.\"';

  @override
  String get weaponSimple => 'Simple';

  @override
  String get weaponMartial => 'Martial';

  @override
  String get weaponUnarmed => 'No weapon (fists)';

  @override
  String get weaponSearchHint => 'Search weapons…';

  @override
  String get summaryEquipped => 'equipped';

  @override
  String get summaryTitle => 'Review and confirm';

  @override
  String summaryLine(String species, String klass, String background) {
    return '$species · $klass · $background · Level 1';
  }

  @override
  String get summaryInCombat => 'In combat';

  @override
  String get summaryFeats => 'Feats';

  @override
  String get identityCreatureTypeShort => 'Type';

  @override
  String get pickSpeciesHint => 'Choose a species to see its details.';

  @override
  String get factToChoose => 'to choose';

  @override
  String feetValue(Object feet) {
    return '$feet ft.';
  }

  @override
  String factChoose(Object count) {
    return '$count to choose';
  }

  @override
  String get raceLineageTitle => 'Species lineage';

  @override
  String get raceLineageRequired =>
      'This species requires you to choose a lineage.';

  @override
  String get raceLineageLevel1 => 'What it gives you at level 1';

  @override
  String get speciesSpellAbility => 'Spellcasting ability';

  @override
  String get pickClassHint => 'Choose a class to see its details.';

  @override
  String get factHitDie => 'Hit Die';

  @override
  String classChooseCount(String name, Object count) {
    return '$name (choose $count)';
  }

  @override
  String classWeaponMasteryTitle(Object count) {
    return 'Weapon Mastery (choose $count)';
  }

  @override
  String classWeaponMasteryBody(String klass) {
    return 'You know the weapon well enough to squeeze an extra effect out of it every time you hit — topple, slow, graze — at no cost. Only weapons $klass is proficient with.';
  }

  @override
  String get pickBackgroundHint => 'Choose a background to see its details.';

  @override
  String get factOriginFeat => 'Origin feat';

  @override
  String get bgOriginFeatGives => 'What its origin feat gives you';

  @override
  String get bgFeatAbilityHint =>
      'It\'s used for the save DC and attack rolls of the feat\'s spells.';

  @override
  String get bgAbilityIncrease => 'Ability increase';

  @override
  String bgEachPlusOne(String list) {
    return 'Each of $list gets +1.';
  }

  @override
  String get aptHelpTitle => 'What is a proficiency';

  @override
  String get aptHelpBody =>
      'Being proficient in something lets you add your proficiency bonus when you roll with it: a skill, a weapon, a tool or a saving throw. Here you choose yours from those offered by your class, species and background; the ones you already get appear locked.';

  @override
  String get aptClassSkills => 'Class skills';

  @override
  String get aptSpeciesSkills => 'Species skills';

  @override
  String get aptGrantedByBackground =>
      'Your background already gives you these:';

  @override
  String creationChosen(Object count, Object total) {
    return '$count / $total chosen';
  }

  @override
  String creationChosenM(Object count, Object total) {
    return '$count / $total chosen';
  }

  @override
  String get creationNotChosen => 'not chosen';

  @override
  String get creationOneChosen => '1 chosen';

  @override
  String aptOriginFeatNote(String species) {
    return 'In 2024, level 1 feats come from your origin: $species grants you one of your choice.';
  }

  @override
  String get aptProfChoices => 'Proficiencies of your choice';

  @override
  String aptFeatChoose(String name, Object count) {
    return '$name: choose $count';
  }

  @override
  String get aptExpertise => 'Expertise';

  @override
  String get aptExpertiseHint =>
      'Doubles your proficiency bonus in the chosen skill.';

  @override
  String get scoresMethod => 'Method';

  @override
  String get scoresHelpTitle => 'Which method suits you?';

  @override
  String get scoresHelpBody =>
      'All four generate the six ability scores of the character, with different amounts of luck. The standard array hands out fixed, balanced values: it is the short path. Rolling 4d6 draws them at random. Point buy lets you build them with a budget. Writing them in works if you have already decided them.';

  @override
  String get scoresStandardArray => 'Standard array';

  @override
  String get scoresRoll4d6 => 'Roll 4d6';

  @override
  String get scoresPointBuy => 'Point buy';

  @override
  String get scoresManual => 'Enter manually';

  @override
  String scoresManualHelp(Object min, Object max) {
    return 'Enter the base score of each ability ($min to $max), not counting the background increase. If one falls outside the usual generation range (3 to 18) the sheet will flag it as a warning, but it will not stop you from continuing.';
  }

  @override
  String scoresSuggested(String klass) {
    return 'Suggested assignment for $klass';
  }

  @override
  String get scoresUseSuggested => 'Use this assignment';

  @override
  String get scoresUnassigned => 'Unassigned values';

  @override
  String get scoresNoneLeft => 'None: all 6 are in.';

  @override
  String get scoresRollAgain => 'Roll again';

  @override
  String get scoresClear => 'Clear';

  @override
  String get scoresPointsLeft => 'Points left';

  @override
  String scoresOfBudget(Object left, Object budget) {
    return '$left of $budget';
  }

  @override
  String get scoresBudgetDone => 'Budget complete.';

  @override
  String get scoresOneUnspent =>
      'You have 1 point left unspent: if you continue, it is lost.';

  @override
  String scoresUnspent(Object count) {
    return 'You have $count points left unspent: if you continue, they are lost.';
  }

  @override
  String scoresAllStartAt(Object min) {
    return 'All start at $min: raise the ones you care about with \"+\".';
  }

  @override
  String scoresCostNote(Object min, Object max) {
    return 'Each ability goes from $min to $max. The last two steps cost double: 14 is worth 7 points and 15 is worth 9, not 6 and 7.';
  }

  @override
  String scoresLower(String ability) {
    return 'Lower $ability';
  }

  @override
  String scoresRaise(String ability) {
    return 'Raise $ability';
  }

  @override
  String scoresAtMax(Object spent) {
    return 'at max · spent $spent';
  }

  @override
  String scoresNextCost(Object cost, Object spent) {
    return 'raising costs $cost · spent $spent';
  }

  @override
  String get scoresUnassignedShort => 'unassigned';

  @override
  String scoresBase(Object score) {
    return 'base $score';
  }

  @override
  String get scoresPickValue => 'Choose a value';

  @override
  String get scoresModEmpty => 'MOD —';

  @override
  String scoresMod(String value) {
    return 'MOD $value';
  }

  @override
  String get scoresValue => 'Value';

  @override
  String scoresTaken(String abilities) {
    return 'in $abilities';
  }

  @override
  String scoresTakenFree(String abilities, int free) {
    String _temp0 = intl.Intl.pluralLogic(
      free,
      locale: localeName,
      other: '$free left',
      one: '1 left',
    );
    return 'in $abilities · $_temp0';
  }

  @override
  String get wordOr => 'or';

  @override
  String get equipReceivedTitle => 'Worn equipment';

  @override
  String get equipStartingTitle => 'Starting equipment';

  @override
  String get equipPickClassItem => 'Choose an item from the class equipment';

  @override
  String get equipPickBackgroundItem =>
      'Choose an item from the background equipment';

  @override
  String get equipNoStartingClass => 'This class has no starting equipment.';

  @override
  String get equipNoStartingBackground =>
      'This background has no starting equipment.';

  @override
  String get equipOptionClass => 'Class option';

  @override
  String get equipOptionBackground => 'Background option';

  @override
  String get equipOrOther => 'or another';

  @override
  String get equipShopTitle => 'Buy equipment';

  @override
  String get equipLeftShort => 'Left';

  @override
  String get equipShopHint =>
      'Each tap adds one to your purchases. You adjust the quantity in the step\'s list.';

  @override
  String get equipPurchases => 'Purchases';

  @override
  String get equipPickFirst =>
      'First choose your equipment options: the gold to spend comes from them.';

  @override
  String equipLeft(String amount) {
    return '$amount left';
  }

  @override
  String get equipNoGold => 'The options you chose don\'t bring gold to spend.';

  @override
  String get equipGoldExplainer =>
      'What you don\'t get in your pack you buy with the starting gold, at the book price. Whatever is left stays in your bag.';

  @override
  String get equipStartingGold => 'Starting gold';

  @override
  String get equipInPurchases => 'In purchases';

  @override
  String get equipShortLabel => 'Short';

  @override
  String get equipYouHaveLeft => 'You have left';

  @override
  String get equipOverspent =>
      'Your purchases exceed the starting gold: remove something or choose another equipment option.';

  @override
  String get equipBuyItems => 'Buy items';

  @override
  String equipOneLess(String name) {
    return 'One fewer $name';
  }

  @override
  String equipOneMore(String name) {
    return 'One more $name';
  }

  @override
  String equipRemovePurchase(String name) {
    return 'Remove $name from purchases';
  }

  @override
  String get equipTapPiece => 'Tap a piece to take it off or put it on.';

  @override
  String get equipNothingToWear =>
      'The chosen pack has nothing to wear or wield.';

  @override
  String get equipGrip => 'How you wield them';

  @override
  String get equipOffHandNote =>
      'The off-hand attack is a Bonus Action and doesn\'t add your modifier to damage, except with the Two-Weapon Fighting style.';

  @override
  String get equipOffHandShort => 'Off hand';

  @override
  String get equipNoSpellsTitle => 'Your class doesn\'t cast spells';

  @override
  String get equipNoSpellsBody =>
      'You trust steel and cunning. Move on to the next step.';

  @override
  String get equipNoPreparedSlot => 'They don\'t take a prepared slot.';

  @override
  String equipCantripSuffix(String name) {
    return '$name (cantrip)';
  }

  @override
  String equipLevelShort(String name, Object level) {
    return '$name (Lv $level)';
  }

  @override
  String equipCasterLine(Object dc, String attack, String ability) {
    return 'Save DC $dc · Spell attack $attack ($ability)';
  }

  @override
  String get equipMagicTitle => 'How your magic works';

  @override
  String get equipMagicCantrips =>
      'Cantrips can always be cast and cost nothing.';

  @override
  String get equipMagicPrepared =>
      'Prepared spells are the ones you leave ready to use; you can change them when you rest.';

  @override
  String get equipMagicKnown =>
      'Known spells are the ones you learned and that stay available to cast.';

  @override
  String get equipMagicSlots =>
      'Every time you cast one you spend a spell slot, which is a separate resource: slots say how many times you can cast, not how many spells you have.';

  @override
  String equipGrantedCantripOne(String name) {
    return 'You already have $name from another feature: it takes no class cantrip slot.';
  }

  @override
  String equipGrantedCantripMany(String names) {
    return 'You already have $names from other features: they take no class cantrip slots.';
  }

  @override
  String equipGrantedLeveled(String names) {
    return 'You already have $names always prepared from another feature: it takes no slot.';
  }

  @override
  String equipMaxLevel(Object level) {
    return 'You can prepare spells up to level $level.';
  }

  @override
  String get wordAnd => 'and';

  @override
  String get luStepSubclass => 'Subclass';

  @override
  String get luStepAsi => 'Improvement or feat';

  @override
  String get luStepChoices => 'Choices';

  @override
  String get luStepSpellChoices => 'Spell choices';

  @override
  String get luStepReview => 'Review';

  @override
  String get luPendingHp => 'Roll the die or choose the average to continue.';

  @override
  String get luPendingSubclass => 'Choose a subclass to continue.';

  @override
  String get luPendingImprove => 'Complete the ability score improvement.';

  @override
  String get luPendingFeat => 'Choose a feat to continue.';

  @override
  String get luPendingFeatAbility =>
      'Choose which ability the feat\'s +1 goes to.';

  @override
  String luPendingChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You are missing $count choices to continue.',
      one: 'You are missing one choice to continue.',
    );
    return '$_temp0';
  }

  @override
  String luPendingExpertise(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Choose $count skills for your Expertise.',
      one: 'Choose a skill for your Expertise.',
    );
    return '$_temp0';
  }

  @override
  String luPendingProficiency(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You are missing $count proficiencies to continue.',
      one: 'You are missing one proficiency to continue.',
    );
    return '$_temp0';
  }

  @override
  String luPendingSpellChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You still need to choose $count spells to continue.',
      one: 'You still need to choose one spell to continue.',
    );
    return '$_temp0';
  }

  @override
  String get luOneCantrip => 'one cantrip';

  @override
  String luCantrips(Object count) {
    return '$count cantrips';
  }

  @override
  String get luOneSpell => 'one spell';

  @override
  String luSpells(Object count) {
    return '$count spells';
  }

  @override
  String luPendingClassSpells(String parts) {
    return 'You still need to choose $parts to continue.';
  }

  @override
  String luTitle(Object level) {
    return 'Level up to $level';
  }

  @override
  String get luStatAttacks => 'Attacks/action';

  @override
  String get luStatMasteries => 'Masteries';

  @override
  String get luStatDarkvision => 'Darkvision';

  @override
  String get luSummaryTitle => 'Level up';

  @override
  String luHpMax(Object hp) {
    return '+$hp max HP';
  }

  @override
  String get luHpCurrent => 'Your current HP goes up by the same amount.';

  @override
  String get luNewProficiencies => 'New proficiencies';

  @override
  String luSavShort(String ability) {
    return 'Save $ability';
  }

  @override
  String get luNewFeatures => 'Class features gained';

  @override
  String get luAlsoGain => 'You also gain';

  @override
  String get luNewResources => 'New resources';

  @override
  String luResourceLine(Object max, String recharge) {
    return 'Uses: $max · recharge: $recharge';
  }

  @override
  String get restShortLower => 'short rest';

  @override
  String get restLongLower => 'long rest';

  @override
  String get luNewCompanions => 'New companions';

  @override
  String get luCompanionOne => 'Summoned from the Combat tab.';

  @override
  String luCompanionMany(Object count) {
    return '$count forms to choose from, in the Combat tab.';
  }

  @override
  String luFormsMore(Object count) {
    return '$count more forms';
  }

  @override
  String get luFormsNote => 'Add the new ones from the Combat tab.';

  @override
  String get luDone => 'Done!';

  @override
  String luLeveled(Object level) {
    return 'You reached level $level!';
  }

  @override
  String get luConfirm => 'Confirm';

  @override
  String luConfirmLevel(Object level) {
    return 'Confirm level $level';
  }

  @override
  String get luContinue => 'Continue';

  @override
  String luGrants(String list) {
    return 'Grants: $list';
  }

  @override
  String get luRepeatable => 'Can be taken more than once.';

  @override
  String luLevelCount(Object level, Object count) {
    return 'Lv $level  ×$count';
  }

  @override
  String get luComplete =>
      'They are already complete. Tap a chosen one to release it so you can change it.';

  @override
  String luRemoveOne(String name) {
    return 'Remove one of $name';
  }

  @override
  String get luNoExpertiseTargets =>
      'You have no proficiencies to apply Expertise to.';

  @override
  String get luNoProficiencies => 'No proficiencies are left for this feature.';

  @override
  String get luChooseEyebrow => 'Your choice';

  @override
  String get luSubclassIntroTitle => 'Your path within the class';

  @override
  String get luSubclassIntroBody =>
      'The subclass defines new features and decisions for the coming levels. Review each option before continuing.';

  @override
  String get luAsiIntroTitle => 'Improve your character';

  @override
  String get luAsiIntroBody =>
      'Raise your ability scores or choose a feat. The decision is previewed before it changes the sheet.';

  @override
  String get luChoicesIntroTitle => 'Your choices this level';

  @override
  String get luChoicesIntroBody =>
      'Some features let you choose among several options. You can review them here before confirming the level up.';

  @override
  String get luProfBodyExpertise =>
      'You double your proficiency bonus in the skills you choose. Only skills you are already proficient in are offered.';

  @override
  String get luProfBody =>
      'What you already have from another source is locked, so you don\'t spend the slot on something you already can do. Expertise slots work the other way around: only skills you are already proficient in are offered.';

  @override
  String get luAlwaysPreparedTitle => 'Spells that are always prepared';

  @override
  String get luAlwaysPreparedBody =>
      'These spells take no prepared slot and can\'t be unchecked from the editor. The pool is already filtered by what the feature allows.';

  @override
  String get luMagicEyebrow => 'Magic';

  @override
  String luYourSpellsAt(Object level) {
    return 'Your spells at level $level';
  }

  @override
  String get luMagicBody =>
      'Review your slots and the number of prepared spells. You can update your selection without leaving the level up.';

  @override
  String get luClassOfLevel => 'Class for this level';

  @override
  String get luClassHelper =>
      'You can continue with your current class or start a new one.';

  @override
  String get luWhichClass => 'Which class do you advance in?';

  @override
  String luClassLevelLine(Object level, String name, Object die) {
    return 'Level $level $name · d$die Hit Die';
  }

  @override
  String luMulticlassReq(String requirement) {
    return 'You don\'t meet the multiclass requirement: $requirement. The table can allow it.';
  }

  @override
  String luOverviewHp(Object die) {
    return 'You choose the average or roll your d$die; Constitution is added automatically.';
  }

  @override
  String get luTagYouChoose => 'YOUR CHOICE';

  @override
  String get luTagOptional => 'OPTIONAL';

  @override
  String get luTagAuto => 'AUTOMATIC';

  @override
  String get luFeatureChoicesTitle => 'Feature choices';

  @override
  String get luFeatureChoicesBody =>
      'A feature from this level lets you choose among several options.';

  @override
  String get luChooseSubclass => 'Choose subclass';

  @override
  String get luChooseSubclassBody =>
      'Defines the character\'s specialization and future features.';

  @override
  String get luAsiCardBody =>
      'Distribute an ability score improvement or take a feat.';

  @override
  String get luReviewSpells => 'Review spells';

  @override
  String get luReviewSpellsBody =>
      'Check your slots and update your prepared spells.';

  @override
  String get luLevelUpper => 'LEVEL';

  @override
  String luCharacterLevels(String name, Object level) {
    return '$name reaches level $level';
  }

  @override
  String get luOverviewIntro =>
      'First we\'ll review what changes automatically and then settle your decisions.';

  @override
  String get luOverviewHelp =>
      'Only the steps that apply to this character at this level appear, so the list is different each time. Nothing is saved to the sheet until you confirm the level up, so you can redo any choice before finishing.';

  @override
  String get luAutoChanges => 'Automatic changes';

  @override
  String get luDecisions => 'Decisions for this level up';

  @override
  String get luMoreHpTitle => 'More hit points';

  @override
  String luMoreHpBody(Object die) {
    return 'Choose the safe average or roll your d$die Hit Die. Constitution is added automatically.';
  }

  @override
  String luHitDie(Object die) {
    return 'Hit Die d$die';
  }

  @override
  String get luNoResult => 'No result yet.';

  @override
  String luBaseGain(Object hp) {
    return 'Base gain for the level: +$hp HP.';
  }

  @override
  String get luHpMaxTitle => 'Max HP';

  @override
  String get luRollToSee => 'Roll the die to see the math.';

  @override
  String luHpDie(Object hp) {
    return '+$hp from the die';
  }

  @override
  String luHpCon(String value) {
    return '$value from Constitution';
  }

  @override
  String luHpFeatures(String value) {
    return '$value from your features';
  }

  @override
  String luHpTotal(String parts, String total) {
    return '$parts = $total HP.';
  }

  @override
  String get luHpRecalc =>
      'If you raise Constitution later, it is recalculated.';

  @override
  String luAverage(Object value) {
    return 'Average ($value)';
  }

  @override
  String get luRoll => 'Roll';

  @override
  String get luRollDie => 'Roll the die';

  @override
  String get luRollAgain => 'Roll again';

  @override
  String get luChosenEarlier => 'Chosen at earlier levels';

  @override
  String get luChangeOrKeep => 'You can change them or leave them as they are.';

  @override
  String get luAutoEyebrow => 'Automatic';

  @override
  String luFeaturesAt(Object level) {
    return 'Features gained at level $level';
  }

  @override
  String get luFeaturesBody =>
      'These features come from your class and subclass. They will apply automatically when you confirm the level up.';

  @override
  String get luResource => 'Resource';

  @override
  String get luClassResource => 'Class resource';

  @override
  String get luReviewMaxHp => 'Maximum hit points';

  @override
  String luReviewHpNote(Object hp) {
    return '+$hp this level up';
  }

  @override
  String get luReviewProfBonus => 'Proficiency bonus';

  @override
  String get luReviewProfBonusNote => 'Applies to all relevant proficiencies';

  @override
  String get luReviewSlotsNote => 'Per spell level';

  @override
  String get luReviewPreparedNote => 'Repertoire capacity';

  @override
  String get luReviewCantripsNote => 'Cast without spending slots';

  @override
  String get luReviewAttacks => 'Attacks per action';

  @override
  String get luReviewExtraAttack => 'Extra Attack';

  @override
  String get luReviewMasteries => 'Weapon Masteries';

  @override
  String get luReviewMasteriesNote => 'Available options';

  @override
  String get luReviewSubclassNote => 'New specialization';

  @override
  String get luFeat => 'Feat';

  @override
  String get luReviewFeatNote => 'New capability';

  @override
  String get luReviewImproveNote => 'Permanent improvement';

  @override
  String get luReviewChosenSpells => 'Chosen cantrips and spells';

  @override
  String get luReviewChosenNote => 'Updated selection';

  @override
  String get luFinalEyebrow => 'Final review';

  @override
  String luFinalTitle(String name) {
    return 'This is how $name ends up';
  }

  @override
  String get luFinalBody =>
      'Review the changes before writing them to the sheet. You can go back to any available step from the top bar.';

  @override
  String get luIncorporated => 'Features added';

  @override
  String luSlotLine(Object level, Object count) {
    return 'Lv$level ×$count';
  }

  @override
  String luSubclassAt(Object level) {
    return 'Subclass (level $level)';
  }

  @override
  String luSpellsEyebrow(Object level) {
    return 'Spells at level $level';
  }

  @override
  String luPrepare(Object count) {
    return 'You prepare $count spells';
  }

  @override
  String luCantripsOf(Object chosen, Object total) {
    return 'Cantrips: $chosen of $total';
  }

  @override
  String luMissingCantrips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You still need to choose $count cantrips.',
      one: 'You still need to choose one cantrip.',
    );
    return '$_temp0';
  }

  @override
  String luPreparedOf(Object chosen, Object total) {
    return 'Prepared: $chosen of $total';
  }

  @override
  String luMissingPrepare(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You still need to prepare $count spells.',
      one: 'You still need to prepare one spell.',
    );
    return '$_temp0';
  }

  @override
  String get luSpellsUpdated => 'Spells updated';

  @override
  String get luPrepareSpells => 'Prepare spells';

  @override
  String luAsiAt(Object level) {
    return 'Ability score improvement (level $level)';
  }

  @override
  String get luImproveAbilities => 'Improve abilities';

  @override
  String get luTakeFeat => 'Take a feat';

  @override
  String luFeatRaises(Object amount) {
    return 'The feat raises an ability (+$amount)';
  }

  @override
  String luFeatCap(Object max) {
    return 'This feat goes up to $max, not to 20 like a normal improvement.';
  }

  @override
  String get luPlusTwo => '+2 to one';

  @override
  String get luPlusOneTwo => '+1 to two';

  @override
  String get luPickOneAbility => 'Choose an ability to add 2 points to.';

  @override
  String get luPickTwoAbilities =>
      'Choose two different abilities to add 1 point to each.';

  @override
  String get luNoFeats => 'No feats are left.';

  @override
  String get luSearchFeat => 'Search feats';

  @override
  String get luNameOrEffect => 'Name or effect';

  @override
  String luAvailable(Object count) {
    return '$count available';
  }

  @override
  String luNoFeatMatch(String query) {
    return 'No feat matches \"$query\".';
  }

  @override
  String get luPickFeatTitle => 'Choose a feat';

  @override
  String get luPickFeatBody =>
      'Each feat changes how the character plays. Select one to review its full effect.';

  @override
  String get catRaces => 'Species';

  @override
  String get catLineages => 'Lineages';

  @override
  String get catClasses => 'Classes';

  @override
  String get catSubclasses => 'Subclasses';

  @override
  String get catBackgrounds => 'Backgrounds';

  @override
  String get catFeats => 'Feats';

  @override
  String get codexGroupCharacter => 'Character';

  @override
  String get codexGroupGear => 'Magic and gear';

  @override
  String get codexSearchTitle => 'Codex · Search';

  @override
  String codexSectionTitle(String section) {
    return 'Codex · $section';
  }

  @override
  String get codexCategoriesTooltip => 'Codex categories';

  @override
  String get codexSearchAll => 'Search the whole Codex';

  @override
  String get codexHome => 'Home';

  @override
  String get codexIntro =>
      'All the game content to read, without creating a character or editing anything. Your homebrew shows up mixed in with the rest, with its source badge.';

  @override
  String codexNoMatch(String query) {
    return 'Nothing in the Codex matches \"$query\".';
  }

  @override
  String codexSeeAll(Object count, String category) {
    return 'See all $count matches in $category';
  }

  @override
  String get codexPickEntry => 'Choose an entry to read it.';

  @override
  String codexSearchIn(String category) {
    return 'Search $category';
  }

  @override
  String get codexNothingMatches => 'Nothing matches what you searched for.';

  @override
  String get codexClearFilters => 'Clear filters';

  @override
  String get codexBackToList => 'Back to the list';

  @override
  String codexLineageOf(String race) {
    return '$race lineage';
  }

  @override
  String codexLevelN(Object level) {
    return 'level $level';
  }

  @override
  String codexPickAny(Object count) {
    return 'choose $count, any';
  }

  @override
  String codexPickFrom(Object count, String list) {
    return 'choose $count from $list';
  }

  @override
  String codexSubclassOf(String klass) {
    return '$klass subclass';
  }

  @override
  String get commonYes => 'Yes';

  @override
  String get codexCategory => 'Category';

  @override
  String get codexRequirements => 'Requirements';

  @override
  String get codexRepeatable => 'Repeatable';

  @override
  String codexRitual(String time) {
    return '$time or ritual';
  }

  @override
  String codexConcentration(String duration) {
    return 'Concentration, $duration';
  }

  @override
  String get codexCanPrepare => 'Can be prepared by';

  @override
  String codexRarityAttune(String rarity) {
    return '$rarity · attunement';
  }

  @override
  String get codexRarity => 'Rarity';

  @override
  String get codexAttunement => 'Attunement';

  @override
  String get codexRequires => 'Required';

  @override
  String get codexNotRequired => 'Not required';

  @override
  String get codexCharges => 'Charges';

  @override
  String get codexWeight => 'Weight';

  @override
  String get codexPrice => 'Price';

  @override
  String get codexMastery => 'Mastery';

  @override
  String get codexProperties => 'Properties';

  @override
  String codexAcDex(Object ac) {
    return '$ac + DEX mod.';
  }

  @override
  String codexAcDexMax(Object ac, Object max) {
    return '$ac + DEX mod. (max $max)';
  }

  @override
  String codexArmorSubtitle(String category, String ac) {
    return '$category · AC $ac';
  }

  @override
  String get codexStrength => 'Strength';

  @override
  String get codexStealth => 'Stealth';

  @override
  String get codexDisadvantage => 'Disadvantage';

  @override
  String get codexPackOf => 'Pack of';

  @override
  String codexPrereqFeat(String category) {
    return 'a $category feat';
  }

  @override
  String get codexPrereqCast => 'spellcasting';

  @override
  String codexPrereqProf(String proficiency) {
    return 'proficiency: $proficiency';
  }

  @override
  String get styleDigitalFantasy => 'Digital fantasy art';

  @override
  String get styleClassicOil => 'Classic oil painting';

  @override
  String get styleComic => 'Comic illustration';

  @override
  String get styleCinematic => 'Cinematic realism';

  @override
  String get styleWatercolor => 'Watercolor';

  @override
  String get stylePixelArt => 'Pixel art';

  @override
  String get stylePencilSketch => 'Pencil sketch';

  @override
  String get styleCustom => 'Custom';

  @override
  String get portraitDefaultError =>
      'Couldn\'t set it as the default, but it works for this session.';

  @override
  String get portraitOffline =>
      'No connection to the server. Generation needs a network.';

  @override
  String portraitGenerateError(String message) {
    return 'Couldn\'t generate: $message';
  }

  @override
  String get portraitGenerateFailed => 'Couldn\'t generate';

  @override
  String get portraitPickReference => 'Choose a reference image';

  @override
  String get portraitReferenceError => 'Couldn\'t choose the reference image';

  @override
  String get portraitPickImage => 'Choose a portrait image';

  @override
  String get portraitImportError => 'Couldn\'t import the image';

  @override
  String get portraitSaveError => 'Couldn\'t save the portrait';

  @override
  String get portraitSaved => 'Portrait saved.';

  @override
  String get portraitRestored => 'Portrait restored.';

  @override
  String get portraitDeleteTitle => 'Delete portrait';

  @override
  String get portraitDeleteBody =>
      'The portrait is deleted forever and cannot be recovered.';

  @override
  String get portraitDeleteError => 'Couldn\'t delete the portrait';

  @override
  String get portraitDeleted => 'Portrait deleted.';

  @override
  String get portraitBackToThis => 'Go back to this portrait';

  @override
  String get portraitDeleteThis => 'Delete this portrait';

  @override
  String get portraitCurrent => 'Current portrait';

  @override
  String portraitPrevious(Object index) {
    return 'Previous portrait $index';
  }

  @override
  String get portraitLoadingSettings => 'Loading settings…';

  @override
  String get portraitUseThis => 'Use this portrait';

  @override
  String get portraitSavedTitle => 'Saved portraits';

  @override
  String get portraitSummoning => 'SUMMONING';

  @override
  String get portraitBaseDescription => 'BASE DESCRIPTION · AUTOMATIC';

  @override
  String get portraitUsedPrompt => 'PROMPT USED';

  @override
  String get portraitGenerateAi => 'Generate with AI';

  @override
  String get portraitUpload => 'Upload image';

  @override
  String get portraitNoProviders =>
      'This server has no generation provider set up. You can still upload your own portrait.';

  @override
  String get portraitEngine => 'Generation engine';

  @override
  String get portraitStyle => 'Style';

  @override
  String get portraitCustomStyle => 'Custom style';

  @override
  String get portraitExtraDetails => 'Extra details';

  @override
  String get portraitAppearance => 'Appearance';

  @override
  String get portraitDetailsHint => 'Hair color, scars, attitude…';

  @override
  String get portraitReference => 'Reference image · optional';

  @override
  String get portraitChooseImage => 'Choose image…';

  @override
  String get portraitRemoveReference => 'Remove reference';

  @override
  String get portraitGenerating => 'Generating…';

  @override
  String get portraitGenerate => 'Generate';

  @override
  String get portraitGenerateAgain => 'Generate again';

  @override
  String get portraitFreeNote =>
      'The free service can take up to ~1 min and generates 2 variants one at a time. If a rate-limit error (429) appears, wait a few seconds and try again.';

  @override
  String get portraitImporting => 'Importing…';

  @override
  String get portraitImportTitle => 'Import an image from a file';

  @override
  String get portraitImportHint => 'Tap to choose it. PNG, JPG or WEBP.';

  @override
  String get portraitImportNote =>
      'The image becomes the character portrait. You can generate with AI again whenever you like.';

  @override
  String get portraitAcceptsReference => 'Accepts a reference';

  @override
  String get portraitTextOnly => 'Text only';

  @override
  String get portraitPickStyle => 'Choose style';

  @override
  String get spellEditTitle => 'Edit spells';

  @override
  String spellEditTitleClass(String klass) {
    return 'Edit spells · $klass';
  }

  @override
  String spellEditCantrips(Object count, Object max) {
    return 'Cantrips ($count/$max)';
  }

  @override
  String get spellEditGrantedCantrips =>
      'The cantrips you already have from another feature don\'t show up here: they take no class cantrip slot.';

  @override
  String spellEditPrepared(Object count, Object max) {
    return 'Prepared spells ($count/$max)';
  }

  @override
  String spellEditKnown(Object count) {
    return 'Known spells ($count)';
  }

  @override
  String spellEditUpTo(Object level) {
    return 'Up to level $level.';
  }

  @override
  String get hbSimple => 'Simple';

  @override
  String get hbMartial => 'Martial';

  @override
  String get hbNoMastery => 'No mastery';

  @override
  String get hbLight => 'Light';

  @override
  String get hbMedium => 'Medium';

  @override
  String get hbHeavy => 'Heavy';

  @override
  String get hbMundane => 'Mundane';

  @override
  String get hbFeatOrigin => 'Origin';

  @override
  String get hbFeatGeneral => 'General';

  @override
  String get hbFeatFighting => 'Fighting style';

  @override
  String get hbFeatDragonmark => 'Dragonmark';

  @override
  String get hbFeatEpic => 'Epic boon';

  @override
  String get sizeSmall => 'Small';

  @override
  String get sizeMedium => 'Medium';

  @override
  String get sizeLarge => 'Large';

  @override
  String get catItems => 'Items';

  @override
  String get catCreatures => 'Creatures';

  @override
  String get hbAddWeapon => 'Add weapon';

  @override
  String get hbAddArmor => 'Add armor';

  @override
  String get hbAddFeat => 'Add feat';

  @override
  String get hbAddSpecies => 'Add species';

  @override
  String get hbAddBackground => 'Add background';

  @override
  String get hbAddSpell => 'Add spell';

  @override
  String get hbAddCreature => 'Add creature';

  @override
  String hbSaved(String name) {
    return '\"$name\" was saved.';
  }

  @override
  String get hbNoChanges => 'No changes were saved.';

  @override
  String get hbSaveError => 'Couldn\'t save the homebrew content';

  @override
  String get hbNothingToExport => 'There is no homebrew content to export.';

  @override
  String hbExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return 'Homebrew exported ($_temp0).';
  }

  @override
  String get hbPickFile => 'Choose a homebrew file (.json)';

  @override
  String get hbOverwriteTitle => 'Overwrite homebrew';

  @override
  String hbOverwriteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries in the file share',
      one: '1 entry in the file shares',
    );
    return '$_temp0 an ID with content you already have. Importing will replace them. Continue?';
  }

  @override
  String get hbOverwrite => 'Overwrite';

  @override
  String hbImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count homebrew entries imported.',
      one: '1 homebrew entry imported.',
    );
    return '$_temp0';
  }

  @override
  String get hbImportError => 'Couldn\'t import the homebrew';

  @override
  String hbLoadIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries could not be loaded',
      one: '1 entry could not be loaded',
    );
    return '$_temp0';
  }

  @override
  String hbSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They were skipped',
      one: 'It was skipped',
    );
    return '$_temp0 on startup. The rest of your homebrew is intact.';
  }

  @override
  String get hbDeleteInvalid => 'Delete invalid entry';

  @override
  String get hbCategoriesTooltip => 'Homebrew categories';

  @override
  String get hbTitleSearch => 'Homebrew · Search';

  @override
  String hbTitleSection(String section) {
    return 'Homebrew · $section';
  }

  @override
  String get hbSearch => 'Search';

  @override
  String get hbMatches => 'Matches';

  @override
  String get hbYourContent => 'Your content';

  @override
  String get hbImportFile => 'Import file';

  @override
  String get hbExportAll => 'Export all';

  @override
  String hbNoMatch(String query) {
    return 'Nothing in your content matches \"$query\".';
  }

  @override
  String hbResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String hbFor(String query) {
    return 'for \"$query\"';
  }

  @override
  String get hbWorkshop => 'Your workshop';

  @override
  String hbWorkshopIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries of your own',
      one: '1 entry of your own',
    );
    return '$_temp0. Everything you create here is added to the catalog: it shows up in character creation and on the sheets, just like the official content.';
  }

  @override
  String get hbCategories => 'Categories';

  @override
  String get hbNothingYet => 'Nothing yet.';

  @override
  String get hbWorkshopEmpty => 'Your workshop is empty';

  @override
  String get hbWorkshopEmptyBody =>
      'Homebrew is content of your own: a weapon, a spell, a creature. It is saved to your account and added to the catalog, next to the official one. Weapons, armor, items, spells, feats, species and backgrounds show up in character creation and on the sheets; creatures, in the Bestiary and in Combat.';

  @override
  String get hbStartWeapon => 'Start with a weapon';

  @override
  String get hbImportAFile => 'Import a file';

  @override
  String get hbDuplicateFromCatalog => 'Duplicate from the catalog';

  @override
  String hbNothingIn(String category) {
    return 'You haven\'t added anything to $category yet.';
  }

  @override
  String hbDuplicateTitle(String title) {
    return 'Duplicate $title';
  }

  @override
  String hbDeleteTooltip(String title) {
    return 'Delete $title';
  }

  @override
  String get hbEffects => 'Effects';

  @override
  String get hbRitual => 'Ritual';

  @override
  String get hbAvailableToCharacters => 'Available to characters';

  @override
  String get hbKindWeapon => 'the weapon';

  @override
  String get hbKindArmor => 'the armor';

  @override
  String get hbKindItem => 'the item';

  @override
  String get hbKindFeat => 'the feat';

  @override
  String get hbKindSpecies => 'the species';

  @override
  String get hbKindBackground => 'the background';

  @override
  String get hbKindSpell => 'the spell';

  @override
  String get hbKindCreature => 'the creature';

  @override
  String hbDeleteTitle(String kind, String name) {
    return 'Delete $kind \"$name\"?';
  }

  @override
  String get hbNoUsers => 'None of your sheets is using it.';

  @override
  String hbUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sheets use it:',
      one: '1 sheet uses it:',
    );
    return '$_temp0';
  }

  @override
  String hbUsersWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They will be left with a warning on their sheets.',
      one: 'It will be left with a warning on its sheet.',
    );
    return '$_temp0';
  }

  @override
  String hbDeleted(String name) {
    return '$name was deleted.';
  }

  @override
  String hbDuplicateDialog(String category) {
    return 'Duplicate $category';
  }

  @override
  String get hbSearchCatalog => 'Search the catalog';

  @override
  String hbCatalogNoMatch(String query) {
    return 'Nothing in the catalog matches \"$query\".';
  }

  @override
  String get hbLeaveTitle => 'Leave without saving?';

  @override
  String hbLeaveBody(String title) {
    return 'What you wrote in \"$title\" will be lost.';
  }

  @override
  String get hbKeepEditing => 'Keep editing';

  @override
  String get hbLeave => 'Leave without saving';

  @override
  String get hbFixFields =>
      'Nothing was saved: check the fields marked in red.';

  @override
  String get hbOptionalRule => 'The rest is optional';

  @override
  String get hbAlreadyChosen => 'What you already chose';

  @override
  String get hbNoNameYet => 'No name yet';

  @override
  String get hbGrantsNothing => 'It grants nothing yet.';

  @override
  String get hbDiceRequired => 'Enter a die, for example 1d8.';

  @override
  String get hbDiceInvalid =>
      'Invalid die format: something like 1d8 is expected.';

  @override
  String get hbNumberRequired => 'Enter a number.';

  @override
  String get hbIntInvalid => 'It has to be a whole number.';

  @override
  String hbRange(Object min, Object max) {
    return 'It has to be between $min and $max.';
  }

  @override
  String get hbWeightRequired => 'Enter a weight, 0 if it does not count.';

  @override
  String get hbNumberInvalid => 'It has to be a number.';

  @override
  String get hbNegative => 'It can\'t be negative.';

  @override
  String get hbDamageType => 'Damage type';

  @override
  String hbUnknownValue(String value) {
    return '$value (unknown)';
  }

  @override
  String get hbRangeLongMin => 'It can\'t be less than the normal range.';

  @override
  String get hbNoMasteryRule =>
      'It adds nothing for someone with the Weapon Mastery feature.';

  @override
  String get hbNoRange => 'No range';

  @override
  String hbRangeFeet(String normal, String long) {
    return '$normal/$long ft.';
  }

  @override
  String get hbProperty => 'Property';

  @override
  String get hbNone => 'none';

  @override
  String get hbNoMasteryLower => 'no mastery';

  @override
  String get hbPreviewTitle => 'How it looks in your list';

  @override
  String get hbWeaponHint =>
      'Tap the category, the damage type, a property or the mastery to see what it does.';

  @override
  String get hbReqWeaponName => 'Enter the weapon name.';

  @override
  String get hbDamageDie => 'Damage die';

  @override
  String get hbVersatile => 'Versatile die (e.g. 1d10)';

  @override
  String get hbRangeNormal => 'Normal range (ft.)';

  @override
  String get hbRangeLong => 'Long range (ft.)';

  @override
  String get hbMasteryMagic => 'Mastery and magic';

  @override
  String get hbMagicBonus => 'Magic bonus (+0 to +3)';

  @override
  String get hbLegendWeapon => 'Description (the weapon\'s legend)';

  @override
  String get hbEconomy => 'Economy';

  @override
  String get hbNotSet => 'not filled in';

  @override
  String get hbWeightLabel => 'Weight in pounds (0 if it does not count)';

  @override
  String get hbPriceLabel => 'Price in copper pieces (1 gp = 100)';

  @override
  String get hbLegend => 'Legend';

  @override
  String get hbLoaded => 'filled in';

  @override
  String get hbArmorBaseAc => 'Base AC';

  @override
  String get hbNotFilled => 'Not filled in';

  @override
  String get hbDexterity => 'Dexterity';

  @override
  String get hbAddsDex => 'Adds Dexterity';

  @override
  String get hbNoDex => 'No Dexterity';

  @override
  String get hbDexCap => 'Dexterity cap';

  @override
  String get hbNoCap => 'No cap';

  @override
  String hbUpTo(String cap) {
    return 'Up to +$cap';
  }

  @override
  String get hbDemand => 'Requirement';

  @override
  String get hbNoStrReq => 'No Strength requirement';

  @override
  String hbStrength(String score) {
    return 'Strength $score';
  }

  @override
  String get hbStealthDisadv => 'Stealth disadvantage';

  @override
  String get hbNoStealthDisadv => 'No Stealth disadvantage';

  @override
  String get hbNoDexLower => 'no Dexterity';

  @override
  String get hbFullDex => 'full Dexterity';

  @override
  String hbUpToLower(String cap) {
    return 'up to +$cap';
  }

  @override
  String get hbOnSheet => 'On the sheet';

  @override
  String hbAcWithDex(Object dex) {
    return 'AC with DEX +$dex';
  }

  @override
  String get hbArmorHint =>
      'Tap the category, the AC or how Dexterity is added to see what changes.';

  @override
  String get hbReqArmorName => 'Enter the armor name.';

  @override
  String get hbShieldAc => 'AC it adds';

  @override
  String get hbHowDex => 'How Dexterity is added';

  @override
  String get hbAddsDexMod => 'Adds DEX modifier';

  @override
  String get hbDexCapLabel => 'DEX cap (empty = no cap)';

  @override
  String get hbDemands => 'Requirements';

  @override
  String get hbStrReqLabel => 'Strength requirement (optional)';

  @override
  String get hbStealthLabel => 'Disadvantage on Stealth';

  @override
  String get hbLegendArmor => 'Description (the armor\'s legend)';

  @override
  String get hbNoneCap => 'None';

  @override
  String get hbMagic => 'Magic';

  @override
  String get hbNoAttunement => 'No attunement';

  @override
  String get hbEffect => 'Effect';

  @override
  String get hbBaseItem => 'Base item';

  @override
  String hbBonusValue(String value) {
    return 'Bonus $value';
  }

  @override
  String hbMoreEffects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more effects',
      one: '1 more effect',
    );
    return '$_temp0';
  }

  @override
  String get hbNoneM => 'none';

  @override
  String get hbItem => 'Item';

  @override
  String get hbItemHint =>
      'Tap the category, the rarity or an effect to see what the item does on the sheet.';

  @override
  String get hbReqItemName => 'Enter the item name.';

  @override
  String get hbWeightShort => 'Weight (lb)';

  @override
  String get hbPriceCp => 'Price (cp)';

  @override
  String get hbMundaneLower => 'mundane';

  @override
  String get hbRequiresAttunement => 'Requires attunement';

  @override
  String get hbOnlyMagicAttune => 'Only magic items can be attuned.';

  @override
  String get hbEffectsEquipped => 'Effects while equipped';

  @override
  String get hbAcBonusLabel => 'Armor Class bonus';

  @override
  String get hbResistances => 'Resistances';

  @override
  String get hbOtherEffects => 'Other effects';

  @override
  String get hbMagicBonusShort => 'Magic bonus';

  @override
  String get hbAllowedBases => 'Allowed bases';

  @override
  String get hbAnyBase => 'If you mark none, any from the chosen family works.';

  @override
  String get hbOnlyMarked => 'Only what you mark here can be used.';

  @override
  String get hbDescription => 'Description';

  @override
  String get hbRepetition => 'Repetition';

  @override
  String get hbOnce => 'Only once';

  @override
  String get hbFeatPreview => 'How the player sees it';

  @override
  String get hbFeatNoDescription =>
      'Without a description the player only sees what it grants. A line saying what makes it different helps to choose it.';

  @override
  String get hbFeatHint => 'Tap the category to see who can take the feat.';

  @override
  String get hbReqFeatName => 'Enter the feat name.';

  @override
  String get hbFeatDistinct => 'What makes it different';

  @override
  String get hbGrants => 'What it grants';

  @override
  String get hbPrereqRepeat => 'Prerequisites and repetition';

  @override
  String get hbNoPrereq => 'no prerequisites';

  @override
  String get hbWithPrereq => 'with prerequisites';

  @override
  String get hbRepeatableLower => 'repeatable';

  @override
  String get hbOnceLower => 'once';

  @override
  String get hbRepeatSwitch => 'Can be taken more than once';

  @override
  String get hbKeepPrereq => 'Keeps the prerequisite of the original feat.';

  @override
  String hbEffectsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count effects',
      one: '1 effect',
      zero: 'no effects',
    );
    return '$_temp0';
  }

  @override
  String get hbNoType => 'No type';

  @override
  String get hbAmongWhichChooses => 'What it chooses from';

  @override
  String get hbSizeToChoose => 'Size to choose';

  @override
  String hbAmongAll(Object count) {
    return '$count from all';
  }

  @override
  String hbAmongN(Object count, Object n) {
    return '$count from $n';
  }

  @override
  String get hbRacePreview => 'How it will look when creating a character';

  @override
  String get hbRaceHint =>
      'Tap the type, size, speed or skills to see what they imply.';

  @override
  String get hbReqRaceName => 'Enter the species name.';

  @override
  String get hbSpeedFeet => 'Speed (ft.)';

  @override
  String get hbPresentation => 'Presentation';

  @override
  String get hbTaglineLower => 'tagline';

  @override
  String get hbDescriptionLower => 'description';

  @override
  String get hbTaglineLabel => 'Tagline (one line, shown when choosing it)';

  @override
  String get hbHowMany => 'How many it chooses';

  @override
  String get hbAmongWhich => 'Among which';

  @override
  String hbOnlySize(String size) {
    return 'only $size';
  }

  @override
  String get hbAllThree => 'The three of the increase';

  @override
  String get hbNoOriginFeat => 'No origin feat';

  @override
  String get hbNoneF => 'None';

  @override
  String get hbIncrease => 'Increase';

  @override
  String get hbBgHint =>
      'Tap the abilities or the origin feat to see what they give the character.';

  @override
  String get hbReqBgName => 'Enter the background name.';

  @override
  String get hbThreeAbilities => 'Choose exactly three abilities.';

  @override
  String get hbPick3 => 'Abilities · choose 3';

  @override
  String get hbNoneParen => '(none)';

  @override
  String get hbTaglineLabelM => 'Tagline (one line, shown when choosing it)';

  @override
  String get hbExtraEffects => 'Additional effects';

  @override
  String get classWizard => 'Wizard';

  @override
  String get classSorcerer => 'Sorcerer';

  @override
  String get classCleric => 'Cleric';

  @override
  String get classDruid => 'Druid';

  @override
  String get classBard => 'Bard';

  @override
  String get classWarlock => 'Warlock';

  @override
  String get classPaladin => 'Paladin';

  @override
  String get classRanger => 'Ranger';

  @override
  String get classArtificer => 'Artificer';

  @override
  String get compVerbal => 'Verbal';

  @override
  String get compSomatic => 'Somatic';

  @override
  String get compMaterial => 'Material';

  @override
  String get hbSchool => 'School';

  @override
  String get hbCastingTime => 'Casting time';

  @override
  String get hbClassLists => 'Class lists';

  @override
  String get hbComponent => 'Component';

  @override
  String get hbSpell => 'Spell';

  @override
  String get hbSpellPreview => 'How it will look on the sheet';

  @override
  String get hbSpellHint =>
      'Tap the level, school, casting time or a component to see what it implies.';

  @override
  String get hbReqSpellName => 'Enter the spell name.';

  @override
  String get hbNoSchool => 'No school';

  @override
  String get hbRangeExample => 'Range (e.g. 60 feet)';

  @override
  String get hbMaterialExample => 'Material (e.g. a pinch of ash)';

  @override
  String get hbConcRitual => 'Concentration and ritual';

  @override
  String get hbConcentrationLower => 'concentration';

  @override
  String get hbRitualLower => 'ritual';

  @override
  String get hbSpellDoes => 'What the spell does';

  @override
  String get hbHitDice => 'Hit Dice';

  @override
  String get hbHitDiceRule =>
      'With hit dice filled in, when you add it to a combat you can ask that each copy roll its own.';

  @override
  String get hbChallenge => 'Challenge';

  @override
  String get hbNoCr => 'No CR';

  @override
  String hbCrValue(String value) {
    return 'CR $value';
  }

  @override
  String get hbOutOfCombat => 'Outside combat';

  @override
  String get hbAlsoCharacters => 'Also for characters';

  @override
  String get hbOnlyYourCombats => 'Only in your combats';

  @override
  String get hbAvailableRule =>
      'Today only the Wild Shape pool looks at it: a beast with a challenge rating can show up among the druid\'s forms. Turned off, the creature lives only in your combats.';

  @override
  String get hbAttackBonus => 'Attack bonus';

  @override
  String get hbWhenUsed => 'When it is used';

  @override
  String get hbCreature => 'Creature';

  @override
  String get hbCreaturePreview => 'How it will look in the Bestiary';

  @override
  String get hbCreatureHint =>
      'Tap the type, the size or an action to see what changes at the table.';

  @override
  String get hbReqCreatureName => 'Enter the creature name.';

  @override
  String get hbSpeedHint => 'e.g. 30 ft., fly 60 ft.';

  @override
  String hbWillRead(String kind) {
    return 'It will read \"$kind\".';
  }

  @override
  String get hbHitDiceOptional => 'Hit Dice (optional)';

  @override
  String get hbDiceExample => 'e.g. 2d6 + 2';

  @override
  String get hbProfile => 'Profile';

  @override
  String get hbCrExample => 'e.g. 1/4 or 5';

  @override
  String get hbInitHint => 'Empty: the DEX mod.';

  @override
  String get hbPassiveOptional => 'Passive Perception (optional)';

  @override
  String get hbPerRound => 'Per round';

  @override
  String get hbSensesHint => 'e.g. darkvision 60 ft.';

  @override
  String get hbDefenses => 'Resistances, immunities and vulnerabilities';

  @override
  String get hbNoTraits => 'no traits';

  @override
  String get hbTrait => 'Trait';

  @override
  String get hbReqTraitName => 'Enter the trait name.';

  @override
  String get hbAddTrait => 'Add trait';

  @override
  String hbActionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions',
      one: '1 action',
      zero: 'no actions',
    );
    return '$_temp0';
  }

  @override
  String get hbAddAction => 'Add action';

  @override
  String get hbAlsoCharactersLower => 'also for characters';

  @override
  String get hbOnlyYourCombatsLower => 'only in your combats';

  @override
  String get hbAvailableSwitch => 'Available in character building';

  @override
  String get hbReqActionName => 'Enter the action name.';

  @override
  String get hbAttackBonusLabel => 'Attack bonus (empty = not an attack)';

  @override
  String get hbReachLabel => 'Reach (e.g. 5 ft.)';

  @override
  String get hbDamageLabel => 'Damage (e.g. 1d8 + 3)';

  @override
  String get hbNoDamage => 'No damage';

  @override
  String get hbActionDescription =>
      'Description (what happens besides the damage)';

  @override
  String get hbCrInvalid =>
      'A number or a fraction is expected, like 1/4 or 5.';

  @override
  String get hbHitDiceInvalid =>
      'Invalid format: something like 2d6 + 2 is expected.';

  @override
  String get effNone => 'No effects.';

  @override
  String get effRemove => 'Remove effect';

  @override
  String get effAdd => 'Add effect';

  @override
  String get effKindAbilityBonus => 'Ability score bonus';

  @override
  String get effKindSetAbility => 'Set an ability score';

  @override
  String get effKindHpPerLevel => 'Max HP per level';

  @override
  String get effKindHpFlat => 'Max HP, once';

  @override
  String get effKindAcBonus => 'AC bonus';

  @override
  String get effKindInitiative => 'Initiative bonus';

  @override
  String get effKindSpeedBonus => 'Speed bonus';

  @override
  String get effKindSetSpeed => 'Set speed';

  @override
  String get effKindSkillProf => 'Skill proficiency';

  @override
  String get effKindSaveProf => 'Saving throw proficiency';

  @override
  String get effKindSaveBonus => 'Saving throw bonus';

  @override
  String get effKindWeaponProf => 'Weapon proficiency';

  @override
  String get effKindArmorProf => 'Armor proficiency';

  @override
  String get effKindToolProf => 'Tool proficiency';

  @override
  String get effLanguage => 'Language';

  @override
  String get effKindResistance => 'Damage resistance';

  @override
  String get effKindImmunity => 'Damage immunity';

  @override
  String get effKindGrantSpell => 'Grant a spell';

  @override
  String get effKindAlwaysPrepared => 'Always-prepared spell';

  @override
  String get effKindSpellList => 'Add a spell to your list';

  @override
  String get effKindGrantFeat => 'Grant a feat';

  @override
  String get effKindPassive => 'Passive feature';

  @override
  String get effUnitFeet => 'Feet';

  @override
  String get effUnitRangeFeet => 'Range in feet';

  @override
  String get effUnitValue => 'Value';

  @override
  String get effAddsProfBonus => 'Adds the proficiency bonus';

  @override
  String get effSkill => 'Skill';

  @override
  String get effHowUsed => 'How it is used';

  @override
  String get effCastAbility => 'Ability to cast it';

  @override
  String get effPlayerChoice => 'Player\'s choice';

  @override
  String get effTraitName => 'Trait name';

  @override
  String effSpellLevel(String name, Object level) {
    return '$name (level $level)';
  }

  @override
  String get effAbility => 'Ability';

  @override
  String get dmCampaignNameRequired => 'Enter a name to save it.';

  @override
  String get dmCampaignName => 'Campaign name';

  @override
  String get dmPremise => 'Premise';

  @override
  String get dmPremiseHint => 'The conflict that sets this story in motion…';

  @override
  String get dmNoteTitleRequired => 'Enter a title to save it.';

  @override
  String get dmChapter => 'Chapter';

  @override
  String get dmNoteTitleHelper =>
      'This is what shows in the list and in search.';

  @override
  String get dmChapterNameRequired => 'Enter a name to save it.';

  @override
  String get dmChapterName => 'Chapter name';

  @override
  String get dmChapterGoal => 'Chapter goal';

  @override
  String get dmChapterGoalHint => 'What the table should achieve or discover…';

  @override
  String get dmChapterGoalHelper =>
      'A short guide; the story goes in the Notebook.';

  @override
  String get dmOnCloseCarry => 'On closing, they take';

  @override
  String get dmOneLevel => 'One level';

  @override
  String get dmLevelUpNote => 'Each player levels up on their own sheet.';

  @override
  String get dmGoldEach => 'Gold for each character';

  @override
  String get dmGoldHelper => 'Already split: the app does not divide the loot.';

  @override
  String get dmItems => 'Items';

  @override
  String get dmItemsHint => 'One per line…';

  @override
  String get dmItemsHelper => 'Each player adds them to their own inventory.';

  @override
  String dmEffectsOf(String name) {
    return 'Effects on $name';
  }

  @override
  String get dmNoteEffect => 'Note an effect';

  @override
  String get dmNoteEffectHint => 'Marked by the rogue…';

  @override
  String dmRemoveTag(String tag) {
    return 'Remove “$tag”';
  }

  @override
  String get dmBookConditions => 'Conditions from the rulebook';

  @override
  String get dmEffectsArePrivate =>
      'Effects are yours: nothing is sent to the player, tell them at the table.';

  @override
  String get dmRollInitiative => 'Roll initiative';

  @override
  String get dmPlayers => 'Players';

  @override
  String get dmNoPlayers => 'No players.';

  @override
  String get dmMonstersAndNpcs => 'Monsters and NPCs';

  @override
  String get dmNoMonstersOrNpcs => 'No monsters or NPCs.';

  @override
  String get dmRoundOneStarts => 'Confirming starts round 1.';

  @override
  String dmInitiativeMissing(String names) {
    return 'Initiative is missing for $names. If someone did not show up, remove them from combat: when they arrive they join with their roll.';
  }

  @override
  String get dmStart => 'Start';

  @override
  String evtLinked(String character, String campaign) {
    return '$character joined the campaign $campaign.';
  }

  @override
  String evtUnlinkedByDm(String character, String campaign) {
    return '$character is no longer part of $campaign.';
  }

  @override
  String evtUnlinkedByOwner(String character, String campaign) {
    return '$character left your campaign $campaign.';
  }

  @override
  String evtDeletedByOwner(String character, String campaign) {
    return '$character is no longer available in $campaign.';
  }

  @override
  String evtInspiration(String campaign, String character) {
    return 'The DM granted you Heroic Inspiration in $campaign. Mark it on the sheet for $character.';
  }

  @override
  String evtChapterDone(String character, String chapter, String campaign) {
    return '$character finished the chapter $chapter in $campaign.';
  }

  @override
  String evtTakes(String rewards) {
    return 'They get $rewards.';
  }

  @override
  String get evtCanLevelUp => 'You can level up.';

  @override
  String get evtSomeCharacter => 'A character';

  @override
  String get evtSomeChapter => 'A chapter';

  @override
  String get evtSomeCampaign => 'A campaign';

  @override
  String evtQuoted(String text) {
    return '“$text”';
  }

  @override
  String get sideAlly => 'Ally';

  @override
  String get sideEnemy => 'Enemy';

  @override
  String get sideNeutral => 'Neutral';

  @override
  String get kindPlayer => 'Player';

  @override
  String get kindMonster => 'Monster';

  @override
  String get kindNpc => 'NPC';

  @override
  String get npcKindNone => 'No stats';

  @override
  String get npcKindBlock => 'Custom stat block';

  @override
  String get npcKindCharacter => 'Character sheet';

  @override
  String get npcAlive => 'Alive';

  @override
  String get npcDead => 'Dead';

  @override
  String get npcUnknown => 'Unknown';

  @override
  String npcBlockLine(String base, String ac, String hp) {
    return '$base · AC $ac · HP $hp';
  }

  @override
  String npcCharacterLine(String classes) {
    return 'Character sheet · $classes';
  }

  @override
  String get npcNew => 'New NPC';

  @override
  String get npcWhichSheet => 'Which sheet does it use?';

  @override
  String get npcNewNone => 'NPC without stats';

  @override
  String get npcNewBlock => 'NPC with a stat block';

  @override
  String get npcNewCharacter => 'Playable character';

  @override
  String get npcNewNoneHint =>
      'Just a name, background and notes. The innkeeper, the mayor.';

  @override
  String get npcNewBlockHint =>
      'A stat block of its own like the bestiary ones: copy a creature’s and tweak it, or start empty.';

  @override
  String get npcNewCharacterHint =>
      'Goes through the character creator: species, class, levels and feats. A background’s villain.';

  @override
  String get npcStartFromCreature => 'Start from a creature (optional)';

  @override
  String get npcEmptyBlock => 'Empty block';

  @override
  String get npcFillLater => 'You fill it in later.';

  @override
  String npcAcHp(String ac, String hp) {
    return 'AC $ac · HP $hp';
  }

  @override
  String get npcTypeFixed =>
      'The type can’t be changed later: it defines what it is edited with.';

  @override
  String get npcContinueToCreator => 'Continue to the creator';

  @override
  String get npcCreate => 'Create';

  @override
  String get shareStop => 'Stop sharing';

  @override
  String shareStopBody(String campaign, String character) {
    return 'The DM of “$campaign” can no longer see $character. Your sheet is not touched.';
  }

  @override
  String shareStopped(String campaign) {
    return 'No longer shared with $campaign.';
  }

  @override
  String shareTitle(String name) {
    return 'Share $name';
  }

  @override
  String get shareIntro =>
      'Generate a code and give it to your DM. They paste it into their campaign and see your sheet; they can never edit it.';

  @override
  String get shareGenerating => 'Generating…';

  @override
  String get shareGenerate => 'Generate code';

  @override
  String get shareSharedWith => 'Shared with';

  @override
  String get shareCodeNote => 'Works only once and expires in 24 hours.';

  @override
  String get shareCopied => 'Code copied.';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonSearching => 'Searching…';

  @override
  String get shareNone => 'You have not shared it with any campaign yet.';

  @override
  String shareStopWith(String campaign) {
    return 'Stop sharing with $campaign';
  }

  @override
  String get dmAddToCombat => 'Add to combat';

  @override
  String get dmBestiary => 'Bestiary';

  @override
  String get dmAddShort => 'Add';

  @override
  String get dmSearchBestiary => 'Search the bestiary';

  @override
  String get dmDeadHere => 'Dead in this campaign';

  @override
  String get dmAlsoJoinsCampaign =>
      'adding it also brings it into the campaign';

  @override
  String get dmAlreadyInCombat => 'Already in combat';

  @override
  String get dmSearchNpcs => 'Search NPCs';

  @override
  String get dmInThisCampaign => 'In this campaign';

  @override
  String get dmNoneDot => 'None.';

  @override
  String get dmFromLibrary => 'From your library · not in this campaign';

  @override
  String get dmLoadingLibrary => 'Loading your library…';

  @override
  String dmDeadNote(String name) {
    return '$name is dead in this campaign. Adding them to combat does not change that.';
  }

  @override
  String get dmRevive => 'Came back: mark as alive again';

  @override
  String get dmWhichSide => 'Which side does it fight on?';

  @override
  String get dmSide => 'Side';

  @override
  String get dmStatlessSide =>
      'Without stats it has no HP to lose: it joins as neutral, with its turn, and counts for no side.';

  @override
  String get dmNoDefaultSide =>
      'No default: the same NPC can be an ally today and an enemy next session. A neutral has a turn and can take sides during combat.';

  @override
  String get dmOneFewer => 'One copy fewer';

  @override
  String get dmOneMore => 'One more copy';

  @override
  String get dmRollEachHp => 'Roll HP for each one';

  @override
  String dmEachRolls(Object formula) {
    return 'Each copy rolls $formula on its own.';
  }

  @override
  String dmAllStartWith(Object hp) {
    return 'All start with $hp, the book average.';
  }

  @override
  String dmAddToCombatOf(String campaign) {
    return 'Add to the combat of $campaign';
  }

  @override
  String get chapterStatePlanned => 'Coming up';

  @override
  String get chapterStateActive => 'Underway';

  @override
  String get chapterStateCompleted => 'Completed';

  @override
  String dmAddedToCombat(String what, String campaign) {
    return 'You added $what to the combat of $campaign.';
  }

  @override
  String get dmAddToCombatFailed => 'Could not add to combat';

  @override
  String get dmPickCreature => 'Pick a creature to see its profile.';

  @override
  String get dmAny => 'Any';

  @override
  String get dmSearchCreature => 'Search creature';

  @override
  String get dmAllTypes => 'All types';

  @override
  String get dmCrFrom => 'CR from';

  @override
  String get dmCrTo => 'CR to';

  @override
  String get dmNoCreatureMatches =>
      'No creature matches what you searched for.';

  @override
  String get dmCreateCampaignFirst =>
      'To add it to a combat, create a campaign first.';

  @override
  String get dmChaptersReadFail => 'The chapters could not be read.';

  @override
  String get dmChaptersLoading => 'Loading the chapters…';

  @override
  String get dmChaptersEmpty =>
      'You have not split this campaign into chapters yet. They help you keep track of where the story is.';

  @override
  String dmCloseChapterBody(String name) {
    return '“$name” becomes completed and every player at the table gets a notice.';
  }

  @override
  String dmCloseChapterBodyRewards(String name, String rewards) {
    return '“$name” becomes completed and every player at the table gets a notice, saying they take $rewards. Each one writes that down on their own sheet: the app does not apply it to anyone.';
  }

  @override
  String get dmCloseChapter => 'Close chapter';

  @override
  String get dmDeleteChapter => 'Delete chapter';

  @override
  String dmDeleteChapterBody(String name) {
    return '“$name” and everything you wrote in it will be deleted. Players are not sent anything.';
  }

  @override
  String get dmLevelsUp => 'Levels up';

  @override
  String dmGoalLine(String goal) {
    return 'Goal: $goal';
  }

  @override
  String dmRewardsTook(String rewards) {
    return 'They took $rewards';
  }

  @override
  String dmRewardsTake(String rewards) {
    return 'They take $rewards';
  }

  @override
  String get dmViewInNotebook => 'View in Notebook';

  @override
  String get dmNotebookReadFail => 'The notebook could not be read.';

  @override
  String get dmNotebookLoading => 'Loading the notebook…';

  @override
  String get dmNotebookNeedsChapter =>
      'The notebook is organised by chapter, so you need to create one first. From Chapters.';

  @override
  String get dmSearchNotebook => 'Search the notebook';

  @override
  String get dmNoChapter => 'No chapter';

  @override
  String get dmLooseFights => 'Combats played with no chapter underway.';

  @override
  String get dmDeleteNote => 'Delete note';

  @override
  String dmDeleteNoteBody(String title) {
    return '“$title” will be deleted. This can’t be undone.';
  }

  @override
  String get dmCombat => 'Combat';

  @override
  String dmCombatAgainst(String enemies) {
    return 'Combat against $enemies';
  }

  @override
  String dmDistributed(String grants) {
    return '$grants was handed out.';
  }

  @override
  String get dmNothingNoted => 'Nothing has been noted in this chapter yet.';

  @override
  String get dmNoEntries => 'No entries';

  @override
  String dmNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String dmFightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count combats',
      one: '1 combat',
    );
    return '$_temp0';
  }

  @override
  String get dmNoteActions => 'Note actions';

  @override
  String dmRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '1 round',
    );
    return '$_temp0';
  }

  @override
  String get dmToday => 'today';

  @override
  String get dmYesterday => 'yesterday';

  @override
  String dmDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get dmTheTable => 'The table';

  @override
  String dmLogAllies(String names) {
    return 'Allies: $names.';
  }

  @override
  String dmLogNeutrals(String names) {
    return 'Neutrals: $names.';
  }

  @override
  String dmLogNoEnemies(String who) {
    return '$who fought with no enemies loaded.';
  }

  @override
  String get dmLogNoneFell => 'No enemy fell.';

  @override
  String get dmLogAllFell => 'All the enemies fell.';

  @override
  String dmLogSomeFell(int defeated, int total) {
    return '$defeated of $total enemies fell.';
  }

  @override
  String dmLogAgainst(String who, String against, String fell) {
    return '$who against $against. $fell';
  }

  @override
  String get dmSheetReadFail => 'The sheet could not be read.';

  @override
  String get dmSheetGone =>
      'You can no longer see this sheet. The link may have been cut.';

  @override
  String get dmSheetLoading => 'Loading the sheet…';

  @override
  String get dmAbbrInit => 'Init';

  @override
  String get dmAbbrSpeed => 'Spd';

  @override
  String get dmAbbrPerception => 'Perc.';

  @override
  String get dmActiveConditions => 'Active conditions';

  @override
  String get dmProficientSkills => 'Proficient skills';

  @override
  String get dmNoneDotF => 'None.';

  @override
  String get dmNoAttacks => 'No attacks loaded.';

  @override
  String get dmNpcsReadFail => 'The campaign’s NPCs could not be read.';

  @override
  String get dmNpcsLoading => 'Loading the NPCs…';

  @override
  String get dmNpcsEmpty =>
      'This campaign has no NPCs yet. Bring some from your library or create a new one.';

  @override
  String get dmBringFromLibrary => 'Bring from library';

  @override
  String get dmTagsCaps => 'TAGS';

  @override
  String get dmNoNpcWithTag => 'No NPC in this campaign has that tag.';

  @override
  String get dmClearFilter => 'Clear filter';

  @override
  String dmStatusOf(String name) {
    return 'Status of $name';
  }

  @override
  String dmActionsOf(String name) {
    return 'Actions for $name';
  }

  @override
  String get dmOpenSheet => 'Open sheet';

  @override
  String get dmRemoveFromCampaign => 'Remove from this campaign';

  @override
  String get dmRemoveFromCampaignNote =>
      'Stays in your library and your other campaigns.';

  @override
  String get dmLibraryReadFail => 'Your NPC library could not be read.';

  @override
  String get dmLibraryLoading => 'Loading your NPCs…';

  @override
  String get dmLibraryEmpty =>
      'Your NPC library is empty. Create the first one or import one: another DM’s, or a character a player exported.';

  @override
  String get dmNoNpcMatches => 'No NPC matches the filters.';

  @override
  String get dmNpcLibrary => 'NPC library';

  @override
  String dmLibraryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters · shared across your campaigns',
      one: '1 character · shared across your campaigns',
    );
    return '$_temp0';
  }

  @override
  String get dmImportNpc => 'Import NPC';

  @override
  String get dmSearchByName => 'Search by name';

  @override
  String get dmAllF => 'All';

  @override
  String get dmNoCampaign => 'No campaign';

  @override
  String get dmNoCampaignYet => 'No campaign yet';

  @override
  String get dmShowName => 'Show the name';

  @override
  String get dmHideName => 'Hide the name';

  @override
  String get npcExportTitle => 'Export NPC';

  @override
  String get npcExportWhatTravels => 'What goes in the file';

  @override
  String get npcExportAlways =>
      'Name, portrait, appearance and “how they speak”';

  @override
  String get npcExportNone => 'Its type: no stats';

  @override
  String get npcExportBlock => 'Its stat block';

  @override
  String get npcExportCharacter =>
      'Its character sheet and the homebrew it uses';

  @override
  String get npcTagsWord => 'Tags';

  @override
  String get npcNotesWord => 'Notes';

  @override
  String get npcNotesNote => 'They belong to your tables.';

  @override
  String get npcExportNever =>
      'Which campaigns it is in, and whether it lives or died in each, never travels. Whoever imports it gets their own copy: what changes later does not reach you.';

  @override
  String get npcDownloadZip => 'Download .zip';

  @override
  String get npcPickFile => 'Choose the NPC or character file';

  @override
  String get npcNewerVersion =>
      'The file comes from a newer version of the app.';

  @override
  String get npcImportedHomebrewLate =>
      'The NPC was imported, but its homebrew only shows up after reloading the page.';

  @override
  String npcPortraitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portraits',
      one: '1 portrait',
    );
    return '$_temp0';
  }

  @override
  String get npcBackgroundLower => 'background';

  @override
  String npcNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String npcHomebrewList(String names) {
    return 'homebrew: $names';
  }

  @override
  String npcCannotImport(String missing) {
    return 'It can’t be imported: its sheet uses content this installation does not have ($missing).';
  }

  @override
  String get npcAlsoAddToCampaign => 'Also add it to a campaign (optional)';

  @override
  String get npcNoCampaignOption => 'None: it stays without a campaign';

  @override
  String get npcImportNeverReplaces =>
      'Importing never replaces anything: if you already have an NPC with that name, you keep both.';

  @override
  String get npcImporting => 'Importing…';

  @override
  String get npcSaveFailed => 'The change could not be saved';

  @override
  String get npcEditName => 'Edit name';

  @override
  String get npcNameLabel => 'NPC name';

  @override
  String get npcNewNote => 'New note';

  @override
  String get npcAddToCampaign => 'Add to a campaign';

  @override
  String get npcInAllCampaigns => 'It is already in all your campaigns.';

  @override
  String get npcDeleteBodyLibrary =>
      'It is deleted from your library, along with its sheet, background, notes and portraits. This cannot be undone.';

  @override
  String npcDeleteBodyCampaigns(String campaigns) {
    return 'It is deleted from your library and from $campaigns, along with its sheet, background, notes and portraits. This cannot be undone.';
  }

  @override
  String npcDeleteTitle(String name) {
    return 'Delete $name';
  }

  @override
  String get npcDeletePastBattles =>
      'Past battles still name it in the Notebook. If it is in an open combat, its row keeps the name but has no profile.';

  @override
  String get npcDeleteJustUnlink =>
      'Just want to take it out of a campaign? Use “Remove from this campaign” from that campaign’s NPC list.';

  @override
  String get npcDelete => 'Delete NPC';

  @override
  String npcDeleted(String name) {
    return '$name was deleted.';
  }

  @override
  String get npcDeleteFailed => 'The NPC could not be deleted';

  @override
  String get npcShowTable => 'Show to the table';

  @override
  String get npcMoreActions => 'More actions';

  @override
  String get npcExport => 'Export';

  @override
  String get npcReadFail => 'The NPC could not be read.';

  @override
  String get npcLoading => 'Loading the NPC…';

  @override
  String get npcGone => 'This NPC no longer exists.';

  @override
  String get npcSpeech => 'How they speak';

  @override
  String get npcSpeechHint => 'One or two lines to play them';

  @override
  String get npcSpeechEmpty => 'How they speak is not written down yet.';

  @override
  String get npcNoBackground => 'No background.';

  @override
  String get npcPortrait => 'Portrait';

  @override
  String npcRemoveTag(String tag) {
    return 'Remove “$tag”';
  }

  @override
  String get npcTagWord => 'Tag';

  @override
  String npcEditTitle(String title) {
    return 'Edit $title';
  }

  @override
  String get npcAddNote => 'Add note';

  @override
  String get npcNoNotes => 'No notes.';

  @override
  String get npcStats => 'Stats';

  @override
  String get npcNoStatsNote =>
      'No stats. In combat it joins as neutral, with a turn and no HP.';

  @override
  String get npcBlockTitle => 'Stat block';

  @override
  String npcBasedOn(String name) {
    return 'based on $name';
  }

  @override
  String get dmAbbrHp => 'HP';

  @override
  String get npcEditBlock => 'Edit stat block';

  @override
  String get npcBlockCopyNote =>
      'It is a copy: if the bestiary creature changes, this block is not touched.';

  @override
  String get npcSheetTitle => 'Sheet';

  @override
  String get npcSheetReadFail => 'Its sheet could not be read.';

  @override
  String get npcOpenFullSheet => 'Open full sheet';

  @override
  String get npcFullSheetNote =>
      'Name, portrait, background and notes are edited here; the full sheet is for stats, equipment and levels.';

  @override
  String get npcInCampaigns => 'In your campaigns';

  @override
  String get npcNoCampaignsYet => 'It is not in any campaign yet.';

  @override
  String npcStatusIn(String campaign) {
    return 'Status in $campaign';
  }

  @override
  String get npcAddToAnother => 'Add to another campaign';

  @override
  String get npcAddTag => 'Add tag';

  @override
  String get encReadFail => 'The combat could not be read.';

  @override
  String get encLoading => 'Loading the combat…';

  @override
  String get encNone => 'There is no combat in progress.';

  @override
  String get encEmptyOrder =>
      'There is nobody in the order yet. Add players or a monster to get started.';

  @override
  String get encPreparing => 'Setting up the combat';

  @override
  String get encPreparingNote =>
      'Nobody has rolled initiative yet, and nothing shows up on the players’ sheets.';

  @override
  String get encRound => 'Round';

  @override
  String encTurnOf(int turn, int total) {
    return 'Turn $turn of $total';
  }

  @override
  String encStandingSemantics(String what, int up, int total) {
    return '$what: $up of $total standing';
  }

  @override
  String get encStanding => 'Standing';

  @override
  String get encAllies => 'Allies';

  @override
  String get encEnemies => 'Enemies';

  @override
  String encNeutralsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neutrals',
      one: '1 neutral',
    );
    return '$_temp0';
  }

  @override
  String get encAmountExplain =>
      'This is the number the damage and heal buttons of any row apply. It holds for the whole combat.';

  @override
  String get encDamageOrHeal => 'Damage or healing';

  @override
  String encSetAmount(int n) {
    return 'Set $n';
  }

  @override
  String get encDiscard => 'Discard combat';

  @override
  String get encFinish => 'End combat';

  @override
  String get encDiscardTitle => 'Discard the combat?';

  @override
  String get encDiscardBody =>
      'It has not started yet: what you set up is deleted and no record is kept.';

  @override
  String get encDiscardShort => 'Discard';

  @override
  String encInitiativeOf(String name) {
    return 'Initiative of $name';
  }

  @override
  String get encWhatTheyGot => 'What they got';

  @override
  String get encCombatant => 'Combatant';

  @override
  String get encEffects => 'Effects';

  @override
  String get encDamageHeal => 'Damage or heal';

  @override
  String get encOfTurn => 'This turn';

  @override
  String get encNobodyTurn => 'It is nobody’s turn yet.';

  @override
  String encPlayerTurn(String name) {
    return 'It is $name’s turn, and their sheet is kept by whoever plays them.';
  }

  @override
  String encNoProfile(String name) {
    return 'There is no profile loaded for $name.';
  }

  @override
  String get encTurnNow => 'Up now';

  @override
  String encSideOf(String name) {
    return 'Side of $name';
  }

  @override
  String get encNeutralNoStats => 'Neutral · no stats';

  @override
  String encBackgroundOf(String name) {
    return 'Background of $name';
  }

  @override
  String get encConvertToNpc => 'Convert to NPC';

  @override
  String get encNoEffects =>
      'Nobody has effects noted. They are noted from each combatant’s row.';

  @override
  String encRemoveEffect(String tag, String name) {
    return 'Remove “$tag” from $name';
  }

  @override
  String get encNobodyStanding => 'Nobody is left standing.';

  @override
  String get encNoEnemyStanding => 'No enemy is left standing.';

  @override
  String get encNoAllyStanding => 'No ally is left standing.';

  @override
  String get encWrapUp => 'Shall we wrap up the encounter?';

  @override
  String get encNotInCombat => 'Not in the combat yet';

  @override
  String get encJoinedLate => 'Joined late';

  @override
  String get encAddAll => 'Add everyone';

  @override
  String get encAddToInitiative => 'Add to the initiative';

  @override
  String get encWhatTheyRolled => 'What they rolled at the table';

  @override
  String get encCloseExplain =>
      'The turn order is deleted in both cases. If you end it, a light record of what happened is kept (no HP or damage: each player tracks that on their own sheet). If you discard it, nothing is kept, as if it had never started.';

  @override
  String get encAnyDied => 'Did any of them die?';

  @override
  String get encFellNote =>
      'They were left at 0 HP. Those you mark become dead in this campaign when you end and save.';

  @override
  String get encDiscardNoSave => 'Discard without saving';

  @override
  String get encFinishAndSave => 'End and save';

  @override
  String get encSkips => 'Skips';

  @override
  String get encTurnWord => 'Turn';

  @override
  String get encActed => 'Acted';

  @override
  String get encFixInitiative => 'Fix initiative';

  @override
  String get encDownMeta => 'Down · skips their turn';

  @override
  String get encFixedNeutral => 'No stats: fixed neutral';

  @override
  String get encConvertToNpcEllipsis => 'Convert to NPC…';

  @override
  String encPlayerMeta(String race, String klass, int level) {
    return '$race · $klass · lv $level';
  }

  @override
  String get encBloodied => 'BLOODIED';

  @override
  String get encOnTheirSheet => 'on their sheet';

  @override
  String get encHurt => 'Damage';

  @override
  String get encHeal => 'Heal';

  @override
  String get encRemoveFromCombat => 'Remove from combat';

  @override
  String get dmNewCampaign => 'New campaign';

  @override
  String get dmEditCampaign => 'Edit campaign';

  @override
  String get dmDeleteCampaign => 'Delete campaign';

  @override
  String dmDeleteCampaignBody(String name) {
    return '“$name” is deleted along with its chapters, the Notebook notes, the open combat and the combat history. This cannot be undone.\n\nThe characters players shared with it are released, and their sheets remain their owners’. NPCs stay in your library.';
  }

  @override
  String get dmHomebrew => 'Homebrew';

  @override
  String get dmFinishedGroup => 'Finished';

  @override
  String get dmCurrentCampaign => 'Current campaign';

  @override
  String get dmTable => 'Table';

  @override
  String get dmChapters => 'Chapters';

  @override
  String get dmNotebook => 'Notebook';

  @override
  String get dmPlayerMode => 'Player Mode';

  @override
  String get dmCampaignsLoadFail => 'Your campaigns could not be loaded.';

  @override
  String get dmOffline => 'There is no connection to the server.';

  @override
  String get dmOfflineHint =>
      'Your campaigns are safe; they just can’t be read right now.';

  @override
  String get dmCampaignsLoading => 'Loading campaigns…';

  @override
  String get dmOnbTitle => 'Set up your first table';

  @override
  String get dmOnbBody =>
      'You are not running any campaign yet. This space gathers what you need before and during the game.';

  @override
  String get dmOnb1Title => 'Create the campaign';

  @override
  String get dmOnb1Detail => 'Name the table and sum up its premise.';

  @override
  String get dmOnb2Title => 'Add the characters';

  @override
  String get dmOnb2Detail =>
      'Each player shares their sheet with you through a code.';

  @override
  String get dmOnb3Title => 'Run the session';

  @override
  String get dmOnb3Detail =>
      'Organise chapters and keep the combat initiative.';

  @override
  String get dmCreateCampaign => 'Create campaign';

  @override
  String get dmAddMember => 'Add character';

  @override
  String get dmMemberCodeLabel => 'Code the player gave you';

  @override
  String dmMemberAdded(String name, String campaign) {
    return '$name joined $campaign.';
  }

  @override
  String get dmRemoveMember => 'Remove character';

  @override
  String dmRemoveMemberBody(String name, String campaign) {
    return '$name leaves “$campaign” and you stop seeing their sheet. The character still belongs to its owner and is not touched; it can return with a new code.';
  }

  @override
  String dmMemberLeft(String name) {
    return '$name left the table.';
  }

  @override
  String dmInspirationSent(String name) {
    return 'We notified $name. They mark it on their sheet.';
  }

  @override
  String get dmWriteNote => 'Write note';

  @override
  String get dmEditNote => 'Edit note';

  @override
  String get dmNewChapter => 'New chapter';

  @override
  String get dmEditChapter => 'Edit chapter';

  @override
  String dmChapterClosed(String name) {
    return '“$name” was closed. Players get a notice.';
  }

  @override
  String get dmSaveCombatFailed => 'The combat could not be saved';

  @override
  String get dmNoProfileToCopy =>
      'There is no profile of that creature to copy.';

  @override
  String dmNowNpc(String name) {
    return '$name is now an NPC in your library and in this campaign.';
  }

  @override
  String get dmCombatPreparing => 'Combat being set up';

  @override
  String dmCombatRound(int round) {
    return 'Combat · round $round';
  }

  @override
  String get dmCampaignActions => 'Campaign actions';

  @override
  String get dmAddingMember => 'Adding character…';

  @override
  String get dmSetUpCombat => 'Set up combat';

  @override
  String get dmNextTurn => 'Next turn';

  @override
  String get dmTableLoading => 'Loading the table…';

  @override
  String get dmNobodyShared => 'Nobody has shared their character yet.';

  @override
  String dmCharactersAtTable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters at the table',
      one: '1 character at the table',
    );
    return '$_temp0';
  }

  @override
  String get dmTableReadFail => 'The table could not be read.';

  @override
  String get dmTableEmpty =>
      'Ask each player to open their character, tap Share and give you the code.';

  @override
  String dmHpSemantics(int current, int max) {
    return 'Hit points: $current of $max';
  }

  @override
  String dmHpShort(int current, int max) {
    return 'HP $current/$max';
  }

  @override
  String get dmGrantInspiration => 'Grant Heroic Inspiration';

  @override
  String get dmRemoveFromTable => 'Remove from the table';

  @override
  String get dmAllNpcsInCampaign =>
      'All your NPCs are already in this campaign, or you have not created any yet.';

  @override
  String dmAddCount(int count) {
    return 'Add $count';
  }

  @override
  String get bootThemeSaveFailed =>
      'The theme changed, but the preference could not be saved.';

  @override
  String get bootLoading => 'Loading data…';

  @override
  String get bootFailed => 'The app could not start.';

  @override
  String get bootFailedHint =>
      'It is usually a momentary connection problem. Try again; if it keeps happening, reload the page.';

  @override
  String get bootOffline => 'Could not connect to the server.';

  @override
  String get bootOfflineHint =>
      'Your characters are safe: they could not be read, but nothing was lost. Check your connection and try again.';

  @override
  String invItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String invShownOf(Object shown, Object total) {
    return '$shown of $total';
  }

  @override
  String luClassFeatures(Object count) {
    return '$count class features';
  }

  @override
  String get luUnchanged => 'UNCHANGED';

  @override
  String equipCostPerBundle(String cost, Object size) {
    return '$cost per pack of $size';
  }

  @override
  String equipCostEach(String cost) {
    return '$cost each';
  }

  @override
  String sheetSubclassAtLevel(Object level) {
    return 'subclass at level $level';
  }

  @override
  String codexEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String bestiaryCreatureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count creatures',
      one: '1 creature',
    );
    return '$_temp0';
  }

  @override
  String npcCountTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count NPCs',
      one: '1 NPC',
    );
    return '$_temp0';
  }

  @override
  String npcCountAlive(int count) {
    return '$count alive';
  }

  @override
  String npcCountDead(int count) {
    return '$count dead';
  }

  @override
  String npcCountUnknown(int count) {
    return '$count unknown';
  }

  @override
  String get creatureLegendaryAction => 'Legendary Action';
}
