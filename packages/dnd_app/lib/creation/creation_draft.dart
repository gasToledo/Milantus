import 'package:dnd_engine/dnd_engine.dart';
import '../l10n/l10n_context.dart';

/// Pasos del wizard de creación, en orden. El borrador y lo que falta en cada
/// parte viven en el motor (`CreationDraft`, `CreationSection`); acá solo se
/// decide cómo se agrupan en pantallas: Equipo junta los conjuros y el equipo.
enum CreationStep {
  raza,
  clase,
  trasfondo,
  puntuaciones,
  aptitudes,
  equipo,
  detalles,
  resumen;

  String label(AppLocalizations l10n) => switch (this) {
    CreationStep.raza => l10n.stepSpecies,
    CreationStep.clase => l10n.stepClass,
    CreationStep.trasfondo => l10n.stepBackground,
    CreationStep.puntuaciones => l10n.stepScores,
    CreationStep.aptitudes => l10n.stepProficiencies,
    CreationStep.equipo => l10n.stepEquipment,
    CreationStep.detalles => l10n.stepDetails,
    CreationStep.resumen => l10n.stepSummary,
  };

  /// Las partes del borrador que cubre el paso. Equipo pone primero el
  /// equipo: es lo que se ve arriba del paso.
  List<CreationSection> get sections => switch (this) {
    CreationStep.raza => const [CreationSection.species],
    CreationStep.clase => const [CreationSection.characterClass],
    CreationStep.trasfondo => const [CreationSection.background],
    CreationStep.puntuaciones => const [CreationSection.scores],
    CreationStep.aptitudes => const [CreationSection.proficiencies],
    CreationStep.equipo => const [
      CreationSection.equipment,
      CreationSection.spells,
    ],
    CreationStep.detalles || CreationStep.resumen => const [],
  };
}

/// El texto de lo que falta. El motor dice qué y cuánto; el idioma es de acá.
String pendingText(
  CreationPending p,
  AppLocalizations l10n,
) => switch (p.kind) {
  CreationPendingKind.pickSpecies => l10n.pendingPickSpecies,
  CreationPendingKind.pickLineage => l10n.pendingPickLineage,
  CreationPendingKind.pickLineageAbility => l10n.pendingPickLineageAbility,
  CreationPendingKind.pickSize => l10n.pendingPickSize,
  CreationPendingKind.pickClass => l10n.pendingPickClass,
  CreationPendingKind.featureChoice => l10n.pendingSlotProgress(
    p.name,
    p.have,
    p.need,
  ),
  CreationPendingKind.weaponMastery => l10n.pendingWeaponMastery(
    p.have,
    p.need,
  ),
  CreationPendingKind.pickBackground => l10n.pendingPickBackground,
  CreationPendingKind.pickFeatAbility => l10n.pendingPickFeatAbility(p.name),
  CreationPendingKind.spread => l10n.pendingSpread,
  CreationPendingKind.assignScores => l10n.pendingAssignScores(p.have),
  CreationPendingKind.classSkills => l10n.pendingClassSkills(p.have, p.need),
  CreationPendingKind.speciesSkills => l10n.pendingSpeciesSkills(
    p.have,
    p.need,
  ),
  CreationPendingKind.originFeat => l10n.pendingPickOriginFeat,
  CreationPendingKind.proficiencies => l10n.pendingProficiencies(p.need),
  CreationPendingKind.expertise => l10n.pendingExpertise(p.need),
  CreationPendingKind.languages => l10n.pendingLanguages(p.have, p.need),
  CreationPendingKind.languageChoices => l10n.pendingLanguageChoices(p.need),
  CreationPendingKind.spellChoices => l10n.pendingSpellChoices(p.need),
  CreationPendingKind.cantrips => l10n.pendingCantrips(p.have, p.need),
  CreationPendingKind.spells => l10n.pendingSpells(p.have, p.need),
  CreationPendingKind.classEquipment => l10n.pendingClassEquipment,
  CreationPendingKind.backgroundEquipment => l10n.pendingBackgroundEquipment,
  CreationPendingKind.equipmentChoices => l10n.pendingEquipmentChoices,
  CreationPendingKind.overspent => l10n.pendingOverspent(l10n.amount(p.need)),
};

extension CreationDraftSteps on CreationDraft {
  /// Elecciones obligatorias que faltan en [step], ya en texto. Lista vacía =
  /// el paso está completo y se puede avanzar.
  List<String> pendingFor(CreationStep step, AppLocalizations l10n) => [
    for (final section in step.sections)
      for (final p in pendingIn(section)) pendingText(p, l10n),
  ];

  bool _complete(CreationStep step) =>
      step.sections.every((s) => pendingIn(s).isEmpty);

  /// Primer paso incompleto (o el último si está todo listo). El wizard lo usa
  /// para no dejar al usuario varado en un paso que dejó de ser alcanzable.
  CreationStep get firstIncompleteStep {
    for (final s in CreationStep.values) {
      if (!_complete(s)) return s;
    }
    return CreationStep.values.last;
  }

  /// Se puede entrar a [step] solo si todos los anteriores están completos.
  /// Así el stepper sirve para volver, pero nunca para saltear validaciones.
  bool canGoTo(CreationStep step) {
    for (final s in CreationStep.values) {
      if (s.index >= step.index) break;
      if (!_complete(s)) return false;
    }
    return true;
  }
}
