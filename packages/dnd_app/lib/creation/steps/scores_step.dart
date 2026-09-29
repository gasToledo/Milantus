part of '../creation_wizard.dart';

class _ScoresStep extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _ScoresStep({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final unassigned = _unassignedValues(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.scoresMethod),
        const SizedBox(height: 10),
        // Los cuatro botones no se leen como cuatro formas de hacer lo mismo
        // si no sabés que las puntuaciones se generan. Va antes de los botones
        // porque es lo que hace falta para elegir uno.
        AppHelpCallout(
          icon: Icons.casino_outlined,
          title: context.l10n.scoresHelpTitle,
          message: context.l10n.scoresHelpBody,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MethodTab(
              icon: Icons.view_list,
              label: context.l10n.scoresStandardArray,
              selected: draft.scoreMethod == ScoreMethod.standardArray,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.standardArray);
                onChanged();
              },
            ),
            _MethodTab(
              icon: Icons.casino,
              label: context.l10n.scoresRoll4d6,
              selected: draft.scoreMethod == ScoreMethod.roll4d6,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.roll4d6);
                onChanged();
              },
            ),
            _MethodTab(
              icon: Icons.calculate,
              label: context.l10n.scoresPointBuy,
              selected: draft.scoreMethod == ScoreMethod.pointBuy,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.pointBuy);
                onChanged();
              },
            ),
            _MethodTab(
              icon: Icons.keyboard,
              label: context.l10n.scoresManual,
              selected: draft.scoreMethod == ScoreMethod.manual,
              onTap: () {
                draft.applyScoreMethod(ScoreMethod.manual);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Reemplaza a `_PoolBar` en modo manual: ahí no hay pool que repartir.
        if (draft.scoreMethod == ScoreMethod.manual)
          AppHelpCallout(
            icon: Icons.keyboard,
            message: context.l10n.scoresManualHelp(
              manualScoreMin,
              manualScoreMax,
            ),
          )
        else if (draft.scoreMethod == ScoreMethod.pointBuy)
          _PointBuyBar(draft: draft, onChanged: onChanged)
        else
          _PoolBar(draft: draft, unassigned: unassigned, onChanged: onChanged),
        // Quien llega por primera vez no sabe que a un mago le conviene la
        // Inteligencia; la tabla del SRD lo dice por clase, y aplicarla es un
        // toque en vez de seis desplegables.
        if (draft.suggestedScores case final suggested
            when suggested.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppHelpCallout(
            icon: Icons.lightbulb_outline,
            title: context.l10n.scoresSuggested(draft.klass!.name),
            message: [
              for (final a in Ability.values) '${a.abbr} ${suggested[a]}',
            ].join(' · '),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                draft.applySuggestedScores();
                onChanged();
              },
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: Text(context.l10n.scoresUseSuggested),
            ),
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 780
                ? 3
                : box.maxWidth >= 520
                ? 2
                : 1;
            final w = (box.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final a in Ability.values)
                  SizedBox(
                    width: w,
                    child: _ScoreCard(
                      draft: draft,
                      ability: a,
                      onChanged: onChanged,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Valores del pool que todavía no fueron asignados a ninguna característica.
List<int> _unassignedValues(CreationDraft draft) {
  final remaining = List.of(draft.pool);
  for (final v in draft.assignedScores.values) {
    remaining.remove(v);
  }
  return remaining..sort((a, b) => b.compareTo(a));
}

/// Pestaña de método de puntuación.
class _MethodTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? pal.goldSoft : scheme.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? pal.gold : pal.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? pal.gold : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? pal.gold : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra con los valores que quedan sin asignar y las acciones del pool.
class _PoolBar extends StatelessWidget {
  final CreationDraft draft;
  final List<int> unassigned;
  final VoidCallback onChanged;
  const _PoolBar({
    required this.draft,
    required this.unassigned,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            context.l10n.scoresUnassigned,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
          if (unassigned.isEmpty)
            Text(
              context.l10n.scoresNoneLeft,
              style: TextStyle(fontSize: 12, color: pal.textMuted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final v in unassigned) GoldPill('$v')],
            ),
          if (draft.scoreMethod == ScoreMethod.roll4d6)
            OutlinedButton.icon(
              onPressed: () {
                draft.applyScoreMethod(ScoreMethod.roll4d6);
                onChanged();
              },
              icon: const Icon(Icons.casino, size: 18),
              label: Text(context.l10n.scoresRollAgain),
            ),
          if (draft.assignedScores.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                draft.clearScores();
                onChanged();
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(context.l10n.scoresClear),
            ),
        ],
      ),
    );
  }
}

/// Reemplaza a `_PoolBar` en compra de puntos: acá no hay valores que repartir
/// sino un presupuesto que se gasta. Muestra lo que queda y avisa cuando el
/// reparto todavía tiene puntos sin usar, que es un error fácil de cometer
/// porque el paso deja avanzar igual (seis puntuaciones válidas ya están).
class _PointBuyBar extends StatelessWidget {
  final CreationDraft draft;
  final VoidCallback onChanged;
  const _PointBuyBar({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final remaining = draft.pointsRemaining;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                context.l10n.scoresPointsLeft,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
              GoldPill(context.l10n.scoresOfBudget(remaining, pointBuyBudget)),
              if (remaining == 0)
                Text(
                  context.l10n.scoresBudgetDone,
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              if (draft.pointsSpent > 0)
                TextButton.icon(
                  onPressed: () {
                    draft.clearScores();
                    onChanged();
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(context.l10n.scoresClear),
                ),
            ],
          ),
          // Todas arrancan en 8 y el paso ya deja avanzar: sin esto se podía
          // seguir con los 27 puntos sin tocar. Avisa y no bloquea, porque
          // guardarse puntos es cosa de la mesa.
          if (remaining > 0 && draft.pointsSpent > 0) ...[
            const SizedBox(height: 8),
            Text(
              remaining == 1
                  ? context.l10n.scoresOneUnspent
                  : context.l10n.scoresUnspent(remaining),
              style: TextStyle(fontSize: 12, color: pal.crimson),
            ),
          ] else if (remaining == pointBuyBudget) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.scoresAllStartAt(pointBuyMin),
              style: TextStyle(fontSize: 12, color: pal.crimson),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.l10n.scoresCostNote(pointBuyMin, pointBuyMax),
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Reemplaza al combo de valores en compra de puntos. El coste del próximo
/// escalón va a la vista porque no es lineal: sin eso, subir de 13 a 14 parece
/// costar lo mismo que de 9 a 10.
class _PointBuyStepper extends StatelessWidget {
  final CreationDraft draft;
  final Ability ability;
  final VoidCallback onChanged;
  const _PointBuyStepper({
    required this.draft,
    required this.ability,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final value = draft.assignedScores[ability] ?? pointBuyMin;
    final canRaise = draft.canRaisePointBuy(ability);
    final canLower = draft.canLowerPointBuy(ability);
    final nextCost = value < pointBuyMax
        ? pointBuyCost(value + 1)! - pointBuyCost(value)!
        : null;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: pal.plaque,
            border: Border.all(color: pal.hairline),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: canLower
                    ? () {
                        draft.stepPointBuy(ability, -1);
                        onChanged();
                      }
                    : null,
                icon: const Icon(Icons.remove, size: 18),
                tooltip: context.l10n.scoresLower(ability.abbr),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: canRaise
                    ? () {
                        draft.stepPointBuy(ability, 1);
                        onChanged();
                      }
                    : null,
                icon: const Icon(Icons.add, size: 18),
                tooltip: context.l10n.scoresRaise(ability.abbr),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          nextCost == null
              ? context.l10n.scoresAtMax(pointBuyCost(value) ?? 0)
              : context.l10n.scoresNextCost(nextCost, pointBuyCost(value) ?? 0),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: pal.textMuted),
        ),
      ],
    );
  }
}

/// Tarjeta de una característica: total grande, aumento del trasfondo,
/// selector de valor y modificador resultante.
class _ScoreCard extends StatelessWidget {
  final CreationDraft draft;
  final Ability ability;
  final VoidCallback onChanged;
  const _ScoreCard({
    required this.draft,
    required this.ability,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final assigned = draft.assignedScores[ability];
    // Se ofrecen todos los valores del pool: elegir uno ya tomado por otra
    // característica las intercambia (draft.assignScore), así siempre se puede
    // reordenar aunque estén las 6 asignadas.
    //
    // Una entrada por valor *distinto*, no por copia: DropdownButton exige que
    // como mucho un ítem coincida con el valor seleccionado, así que las copias
    // repetidas de una tirada 4d6 se distinguen por etiqueta (ver _valueLabel).
    final items = draft.pool.toSet().toList()..sort((a, b) => b.compareTo(a));
    final holders = draft.holdersExcept(ability);
    final spread = draft.abilitySpread[ability] ?? 0;
    final total = draft.previewScore(ability);
    final mod = abilityModifier(total);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // El tooltip va solo sobre el rótulo y se abre hacia arriba:
              // envolviendo el `Expanded` ocupaba la fila entera y, abierto
              // hacia abajo, tapaba el valor que se estaba eligiendo. El nombre
              // completo va a la vista: «FUE» a secas no lo dice.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: ability.description,
                    preferBelow: false,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text.rich(
                      TextSpan(
                        text: ability.abbr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                            text: '  ${ability.label}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: pal.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (spread > 0)
                Text(
                  '+$spread',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pal.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            assigned == null ? '—' : '$total',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 40,
              height: 1,
              color: assigned == null ? pal.textMuted : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            assigned == null
                ? context.l10n.scoresUnassignedShort
                : context.l10n.scoresBase(assigned),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: pal.textMuted),
          ),
          const SizedBox(height: 10),
          if (draft.scoreMethod == ScoreMethod.manual)
            _ManualScoreField(
              key: ValueKey('manual-${ability.name}'),
              initial: assigned,
              onSubmit: (v) {
                draft.setManualScore(ability, v);
                onChanged();
              },
            )
          else if (draft.scoreMethod == ScoreMethod.pointBuy)
            _PointBuyStepper(
              draft: draft,
              ability: ability,
              onChanged: onChanged,
            )
          else
            DropdownButtonFormField<int>(
              initialValue: assigned,
              isExpanded: true,
              // Por defecto Flutter fuerza 48 px por ítem: con 6 valores el menú
              // tapaba media pantalla. En null cada ítem se ajusta a su contenido.
              itemHeight: null,
              menuMaxHeight: 300,
              borderRadius: BorderRadius.circular(10),
              hint: Text(
                context.l10n.scoresPickValue,
                style: TextStyle(fontSize: 13, color: pal.textMuted),
              ),
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
              icon: Icon(Icons.expand_more, size: 18, color: pal.textMuted),
              decoration: InputDecoration(
                filled: true,
                fillColor: pal.plaque,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: pal.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: pal.hairline),
                ),
              ),
              // El botón cerrado dibuja solo el número: reutilizar el ítem del
              // menú (con su padding y su etiqueta) es lo que recortaba el texto.
              selectedItemBuilder: (context) => [
                for (final v in items)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$v', style: const TextStyle(fontSize: 14)),
                  ),
              ],
              items: [
                for (final v in items)
                  DropdownMenuItem(
                    value: v,
                    child: _ValueOption(
                      value: v,
                      holders: holders[v] ?? const [],
                      free: draft.freeCopiesOf(v, ability),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                draft.assignScore(ability, v);
                onChanged();
              },
            ),
          const SizedBox(height: 10),
          Text(
            assigned == null
                ? context.l10n.scoresModEmpty
                : context.l10n.scoresMod(_signedMod(mod)),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: assigned == null ? pal.textMuted : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de puntuación escrita a mano. Mantiene su propio controlador para no
/// reconstruir el texto mientras se tipea.
class _ManualScoreField extends StatefulWidget {
  final int? initial;
  final ValueChanged<int?> onSubmit;
  const _ManualScoreField({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  @override
  State<_ManualScoreField> createState() => _ManualScoreFieldState();
}

class _ManualScoreFieldState extends State<_ManualScoreField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      style: TextStyle(fontSize: 14, color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: context.l10n.scoresValue,
        hintStyle: TextStyle(fontSize: 13, color: pal.textMuted),
        filled: true,
        fillColor: pal.plaque,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: pal.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: pal.hairline),
        ),
      ),
      onChanged: (text) {
        final v = int.tryParse(text);
        // Un valor a medio escribir (p. ej. "0" camino a "10") no debe borrar
        // lo ya asignado ni contarse como característica completa.
        if (text.isEmpty) {
          widget.onSubmit(null);
        } else if (v != null && v >= manualScoreMin && v <= manualScoreMax) {
          widget.onSubmit(v);
        }
      },
    );
  }
}

/// Una opción del combo de valores. Distingue los ya tomados con color **y**
/// con texto ("14 · en DES"): el color solo no alcanza para daltónicos y,
/// sobre todo, no dice *dónde* quedó la otra copia de un valor repetido.
class _ValueOption extends StatelessWidget {
  final int value;
  final List<Ability> holders;
  final int free;
  const _ValueOption({
    required this.value,
    required this.holders,
    required this.free,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final taken = holders.isNotEmpty;
    final note = !taken
        ? null
        : free > 0
        ? context.l10n.scoresTakenFree(
            holders.map((a) => a.abbr).join(", "),
            free,
          )
        : context.l10n.scoresTaken(holders.map((a) => a.abbr).join(", "));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: free > 0 ? FontWeight.w600 : FontWeight.normal,
              color: free > 0 ? scheme.onSurface : pal.textMuted,
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: pal.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _signedMod(int v) => v >= 0 ? '+$v' : '$v';

/// Encabezado de sección con rombo dorado y contador a la derecha.
