part of '../sheet_screen.dart';

// ---------------------------------------------------------------- Widgets

// El visor de retrato a pantalla completa vive en `ui/portrait_viewer.dart`:
// lo comparten el encabezado de la ficha y las tarjetas del Diario.

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// Las fuentes de unas ventajas, sin repetir: dos rasgos que dan la misma
/// ventaja se nombran una vez cada uno.
String _advantageSources(
  BuildContext context,
  Iterable<Advantage> advantages,
) => advantages
    .map((v) => v.source.isEmpty ? context.l10n.breakdownOtherTrait : v.source)
    .toSet()
    .join(', ');

/// «VENTAJA» al lado del nombre de una salvación o habilidad, con quién la da
/// en el tooltip: en la mesa la pregunta es siempre «¿y eso de dónde sale?».
Widget _advantageTag(BuildContext context, List<Advantage> advantages) =>
    Tooltip(
      message: context.l10n.advantageFrom(
        _advantageSources(context, advantages),
      ),
      child: OutlinedTag(context.l10n.advantageTag),
    );

/// Lo que cambia un estado activo, en una línea: «Resistencia a contundente,
/// perforante, cortante · +2 al daño con FUE · Ventaja en FUE · Sin
/// conjuros ni concentración». Todo sale de la ficha (`ActiveMode`): la
/// pantalla solo lo pone en palabras.
String _activeModeSummary(BuildContext context, ActiveMode m) {
  final l10n = context.l10n;
  final types = m.resistances
      .map(DamageType.labelFor)
      .map((label) => localized(label.toLowerCase(), label))
      .toList();
  final abilities = {
    for (final v in m.advantages) ...v.abilities,
  }.map((a) => a.abbr).toList();
  return [
    if (types.isNotEmpty) l10n.modeResistance(types.join(', ')),
    if (m.damageAbility case final ability? when m.damageBonus > 0)
      l10n.modeDamage(m.damageBonus, ability.abbr),
    if (abilities.isNotEmpty) l10n.modeAdvantage(abilities.join(', ')),
    if (m.noSpellcasting) l10n.modeNoSpells,
  ].join(' · ');
}

/// Una ventaja que no cabe en una fila —contra un estado, contra conjuros, en
/// las salvaciones de muerte— dicha en una frase. Los estados salen del
/// glosario del motor, que ya está en los dos idiomas.
String _conditionalAdvantageText(BuildContext context, Advantage v) {
  final l10n = context.l10n;
  // En español el estado va en minúscula dentro de la frase («contra
  // envenenado»); en inglés 2024 los estados se escriben con mayúscula.
  final conditions = v.conditions
      .map(DamageType.labelFor)
      .map((label) => localized(label.toLowerCase(), label))
      .join(', ');
  final text = switch (v) {
    Advantage(roll: AdvantageRoll.deathSave) => l10n.advantageDeathSaves,
    Advantage(vsSpells: true) => l10n.advantageSavesVsSpells,
    Advantage(roll: AdvantageRoll.abilityCheck) => l10n.advantageChecksToEnd(
      conditions,
    ),
    _ => l10n.advantageSavesAgainst(conditions),
  };
  return '$text · ${_advantageSources(context, [v])}';
}
