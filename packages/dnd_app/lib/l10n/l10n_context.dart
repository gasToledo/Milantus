import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.guardar` en vez de `AppLocalizations.of(context).guardar`: es
/// lo que más se escribe en la interfaz, y el segundo obliga a partir cada
/// `Text(...)` en dos renglones.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// El nombre de la aplicación. Es una marca: no se traduce ni va al catálogo.
const appName = 'Milantus';

/// El estado de un capítulo, en el idioma activo.
extension ChapterStateL10n on ChapterState {
  String localized(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      ChapterState.planned => l10n.chapterStatePlanned,
      ChapterState.active => l10n.chapterStateActive,
      ChapterState.completed => l10n.chapterStateCompleted,
    };
  }
}

/// El bando de un combatiente, en el idioma activo.
extension CombatantSideL10n on CombatantSide {
  String text(AppLocalizations l10n) => switch (this) {
    CombatantSide.ally => l10n.sideAlly,
    CombatantSide.enemy => l10n.sideEnemy,
    CombatantSide.neutral => l10n.sideNeutral,
  };
}

/// Qué clase de combatiente es, en el idioma activo.
extension CombatantKindL10n on CombatantKind {
  String text(AppLocalizations l10n) => switch (this) {
    CombatantKind.player => l10n.kindPlayer,
    CombatantKind.monster => l10n.kindMonster,
    CombatantKind.npc => l10n.kindNpc,
  };
}

/// Qué ficha lleva un PNJ, en el idioma activo.
extension NpcSheetKindL10n on NpcSheetKind {
  String text(AppLocalizations l10n) => switch (this) {
    NpcSheetKind.none => l10n.npcKindNone,
    NpcSheetKind.block => l10n.npcKindBlock,
    NpcSheetKind.character => l10n.npcKindCharacter,
  };
}

/// Cuándo se usa una acción de criatura, en el idioma activo.
extension CreatureActionKindL10n on CreatureActionKind {
  String text(AppLocalizations l10n) => switch (this) {
    CreatureActionKind.action => l10n.spellActionAction,
    CreatureActionKind.bonus => l10n.spellActionBonus,
    CreatureActionKind.reaction => l10n.spellActionReaction,
    CreatureActionKind.legendary => l10n.creatureLegendaryAction,
  };
}

/// Si un PNJ sigue vivo, en el idioma activo.
extension NpcStatusL10n on NpcStatus {
  String text(AppLocalizations l10n) => switch (this) {
    NpcStatus.alive => l10n.npcAlive,
    NpcStatus.dead => l10n.npcDead,
    NpcStatus.unknown => l10n.npcUnknown,
  };
}

/// Las etiquetas de enums del engine que son puramente de interfaz. Van acá y
/// no en el engine porque el engine no habla ningún idioma en particular (el
/// `label` en español que traen es lo que la fase 2 va a reemplazar).
extension CampaignStateL10n on CampaignState {
  String localized(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      CampaignState.active => l10n.campaignStateActive,
      CampaignState.paused => l10n.campaignStatePaused,
      CampaignState.finished => l10n.campaignStateFinished,
    };
  }
}
