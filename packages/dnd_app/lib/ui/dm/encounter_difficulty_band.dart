import 'dart:math';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_models.dart';
import '../../l10n/l10n_context.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// Ancho a partir del cual el veredicto, la regla y los PX van en una línea.
const double _kBandRowWidth = 620;

/// Ancho de regla a partir del cual los umbrales se rotulan debajo de su
/// marca. Con menos, «Moderada» y «Alta» se pisan en las mesas de nivel bajo
/// —a nivel 1 están a un 20 % de la regla— y pasan a una leyenda aparte.
const double _kTickLabelsWidth = 360;

/// El VD con el que un combatiente entra en la cuenta de dificultad, o null
/// si no tiene: un jugador, un PNJ con ficha de personaje o sin estadísticas.
///
/// El de un PNJ sale de **su** bloque y no de la criatura de base: el bloque
/// es una copia que el DM pudo haber editado.
num? combatantChallengeRating(
  Combatant combatant,
  CampaignNpcEntry? npc,
  ContentRepository repo,
) {
  if (combatant.kind == CombatantKind.player) return null;
  if (npc != null) return npc.sheet != null ? null : npc.npc.block?.cr;
  final id = combatant.creatureId;
  return id == null ? null : repo.creature(id)?.cr;
}

/// Junta lo que el motor necesita para decir la dificultad de [encounter].
///
/// Acá solo se resuelve de dónde sale cada número —el nivel de una ficha, el
/// VD de un perfil—; la regla es de `encounterDifficulty`.
///
/// Cuenta a quienes **entraron al combate**, no a la mesa entera: si un
/// jugador faltó esa noche, el presupuesto es el de los que vinieron.
EncounterDifficulty encounterDifficultyOf(
  Encounter encounter, {
  required List<CampaignMember> members,
  required List<CampaignNpcEntry> npcs,
  required ContentRepository repo,
}) {
  final party = <int>[];
  final enemies = <num?>[];
  final allies = <num?>[];
  for (final c in encounter.combatants) {
    if (c.side == CombatantSide.neutral) continue;
    if (c.kind == CombatantKind.player) {
      final member = members.where((m) => m.memberId == c.memberId).firstOrNull;
      if (member != null) party.add(member.character.totalLevel);
      continue;
    }
    final npc = c.npcId == null
        ? null
        : npcs.where((e) => e.npc.id == c.npcId).firstOrNull;
    final sheet = npc?.sheet;
    // Un PNJ aliado con ficha es un personaje más del lado de la mesa. Como
    // enemigo no tiene VD que sumar: queda en la lista sin valor, y la banda
    // avisa que está fuera de la cuenta.
    if (sheet != null && c.side == CombatantSide.ally) {
      party.add(sheet.totalLevel);
      continue;
    }
    (c.side == CombatantSide.ally ? allies : enemies).add(
      combatantChallengeRating(c, npc, repo),
    );
  }
  return encounterDifficulty(
    partyLevels: party,
    enemyCrs: enemies,
    allyCrs: allies,
  );
}

/// Un número de PX con el separador de miles del idioma de la interfaz.
String formatXp(BuildContext context, int xp) => NumberFormat.decimalPattern(
  Localizations.localeOf(context).toString(),
).format(xp);

/// Qué tan difícil es el combate que se está armando.
///
/// Va sobre `plaque`, como la barra de arriba: es un dato que la app calculó,
/// no algo que el DM edite. Solo «Extrema» cambia de color; las otras tres
/// son dificultades que el DM elige a propósito y ninguna es una alarma.
class EncounterDifficultyBand extends StatelessWidget {
  final EncounterDifficulty difficulty;

  const EncounterDifficultyBand({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final l10n = context.l10n;
    final d = difficulty;
    final tier = d.tier;
    final color = tier == EncounterTier.extreme ? pal.crimson : pal.gold;

    final notices = [
      if (d.manyCreatures)
        (
          l10n.encDifficultyManyTitle,
          l10n.encDifficultyManyBody(d.enemies, d.characters),
        ),
      if (d.powerfulCr case final cr?)
        (
          l10n.encDifficultyPowerfulTitle,
          l10n.encDifficultyPowerfulBody(
            challengeRatingLabel(cr),
            d.lowestLevel,
          ),
        ),
      if (d.uncountedEnemies > 0)
        (
          l10n.encDifficultyUncountedTitle,
          l10n.encDifficultyUncountedBody(d.uncountedEnemies),
        ),
    ];

    // Sin dificultad que decir, el lugar de la regla lo ocupa qué falta.
    final middle = tier == null
        ? Text(
            d.characters == 0
                ? l10n.encDifficultyNoParty
                : l10n.encDifficultyNoEnemies,
            style: TextStyle(fontSize: 13, color: pal.textMuted),
          )
        : _BudgetTrack(difficulty: d, color: color);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: pal.plaque,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final verdict = _verdict(context, tier, color);
              final xp = _xp(context, tier);
              if (box.maxWidth >= _kBandRowWidth) {
                return Row(
                  children: [
                    SizedBox(width: 176, child: verdict),
                    const SizedBox(width: 24),
                    Expanded(child: middle),
                    if (xp != null) ...[
                      const SizedBox(width: 24),
                      SizedBox(width: 176, child: xp),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: verdict),
                      if (xp != null) ...[
                        const SizedBox(width: 12),
                        Flexible(child: xp),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  middle,
                ],
              );
            },
          ),
          for (final (title, body) in notices) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: pal.hairline),
            const SizedBox(height: 10),
            _notice(context, title, body),
          ],
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text, {TextAlign? align}) => Text(
    text.toUpperCase(),
    textAlign: align,
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w500,
      color: context.palette.textMuted,
    ),
  );

  Widget _verdict(BuildContext context, EncounterTier? tier, Color color) {
    final pal = context.palette;
    final l10n = context.l10n;
    final d = difficulty;
    final party = d.characters == 0
        ? null
        : d.lowestLevel == d.highestLevel
        ? l10n.encDifficultyPartySame(d.characters, d.lowestLevel)
        : l10n.encDifficultyPartyMixed(
            d.characters,
            d.lowestLevel,
            d.highestLevel,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(context, l10n.encDifficulty),
        if (tier != null)
          Text(
            tierLabel(l10n, tier),
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              height: 1.3,
              color: color,
            ),
          ),
        if (party != null)
          Padding(
            padding: EdgeInsets.only(top: tier == null ? 4 : 0),
            child: Text(
              party,
              style: TextStyle(fontSize: 12, color: pal.textMuted),
            ),
          ),
      ],
    );
  }

  /// Los PX de enfrente, o null si no hay enemigos que contar.
  Widget? _xp(BuildContext context, EncounterTier? tier) {
    final pal = context.palette;
    final l10n = context.l10n;
    final d = difficulty;
    if (d.enemies == 0) return null;
    final net = d.allyXp > 0;
    final muted = TextStyle(fontSize: 12, color: pal.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(
          context,
          net ? l10n.encDifficultyNetXp : l10n.encDifficultyEnemyXp,
          align: TextAlign.end,
        ),
        Text(
          formatXp(context, d.netXp),
          style: const TextStyle(
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (tier != null)
          Text(
            tier == EncounterTier.extreme
                ? l10n.encDifficultyOver(formatXp(context, -d.remainingXp))
                : l10n.encDifficultyLeft(
                    formatXp(context, d.remainingXp),
                    tierLabel(l10n, tier),
                  ),
            textAlign: TextAlign.end,
            style: muted,
          ),
        if (net)
          Text(
            l10n.encDifficultyBreakdown(
              formatXp(context, d.enemyXp),
              formatXp(context, d.allyXp),
            ),
            textAlign: TextAlign.end,
            style: muted,
          ),
      ],
    );
  }

  Widget _notice(BuildContext context, String title, String body) {
    final pal = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.warning_amber_rounded, size: 16, color: pal.gold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: body,
                  style: TextStyle(color: pal.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// El nombre de una dificultad, como se lee en la banda.
String tierLabel(AppLocalizations l10n, EncounterTier tier) => switch (tier) {
  EncounterTier.low => l10n.encDifficultyLow,
  EncounterTier.moderate => l10n.encDifficultyModerate,
  EncounterTier.high => l10n.encDifficultyHigh,
  EncounterTier.extreme => l10n.encDifficultyExtreme,
};

/// La regla del presupuesto: cuánto se lleva gastado y dónde cae cada techo.
class _BudgetTrack extends StatelessWidget {
  final EncounterDifficulty difficulty;
  final Color color;

  const _BudgetTrack({required this.difficulty, required this.color});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final l10n = context.l10n;
    final d = difficulty;
    // La regla sigue un cuarto más allá del techo alto: sin ese tramo,
    // «Extrema» no tendría dónde verse pasada.
    final scale = d.highBudget * 1.25;
    final budgets = [
      (l10n.encDifficultyLow, d.lowBudget),
      (l10n.encDifficultyModerate, d.moderateBudget),
      (l10n.encDifficultyHigh, d.highBudget),
    ];

    Widget tickLabel(String name, int xp, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: TextStyle(fontSize: 10.5, color: pal.textMuted)),
        Text(
          formatXp(context, xp),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return Semantics(
      label: l10n.encDifficultyTrack(
        formatXp(context, d.netXp),
        formatXp(context, d.lowBudget),
        formatXp(context, d.moderateBudget),
        formatXp(context, d.highBudget),
      ),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final under = width >= _kTickLabelsWidth;
            double at(int xp) => width * xp / scale;

            final rule = SizedBox(
              height: under ? 52 : 20,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 6,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pal.goldSoft,
                        border: Border.all(color: pal.hairline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 6,
                    height: 8,
                    width: min(width, at(d.netXp)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  for (final (_, xp) in budgets)
                    Positioned(
                      left: at(xp),
                      top: 0,
                      width: 1,
                      height: 20,
                      child: ColoredBox(color: pal.textMuted),
                    ),
                  if (under) ...[
                    // «Baja» va a la izquierda de su marca y las otras dos a
                    // la derecha: centradas se pisan cuando los techos bajo y
                    // moderado quedan cerca.
                    Positioned(
                      right: width - at(d.lowBudget) + 5,
                      top: 22,
                      child: tickLabel(
                        budgets[0].$1,
                        budgets[0].$2,
                        CrossAxisAlignment.end,
                      ),
                    ),
                    for (final (name, xp) in budgets.skip(1))
                      Positioned(
                        left: at(xp) + 5,
                        top: 22,
                        child: tickLabel(name, xp, CrossAxisAlignment.start),
                      ),
                  ],
                ],
              ),
            );
            if (under) return rule;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rule,
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (name, xp) in budgets)
                      tickLabel(name, xp, CrossAxisAlignment.start),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
