import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_widgets.dart';
import '../l10n/l10n_context.dart';

/// Editor de trucos y conjuros preparados/conocidos. Se abre desde la ficha:
/// un lanzador preparado (Mago) re-prepara tras cada descanso largo, así que la
/// selección no queda congelada en la creación.
class SpellEditScreen extends StatefulWidget {
  final Character character;
  final ContentRepository repo;
  final Spellcasting spellcasting;
  final String? classId;
  final void Function(List<String> cantrips, List<String> spells) onSave;

  const SpellEditScreen({
    super.key,
    required this.character,
    required this.repo,
    required this.spellcasting,
    this.classId,
    required this.onSave,
  });

  @override
  State<SpellEditScreen> createState() => _SpellEditScreenState();
}

class _SpellEditScreenState extends State<SpellEditScreen> {
  late final ComputedSheet _sheet = CharacterCompiler(
    widget.repo,
  ).compile(widget.character);

  /// Qué se ofrece, qué ya concede un rasgo (y por eso no ocupa cupo) y lo
  /// elegido sin lo concedido lo decide el motor (`LevelUp.classSpells`), el
  /// mismo que usa el cliente React.
  late final _options = LevelUp.classSpells(
    widget.character,
    _sheet,
    widget.repo,
    widget.spellcasting,
    classId: widget.classId,
  );

  /// La clase cuyos conjuros se editan, para el título.
  String get _classId => widget.classId ?? widget.character.classId;

  late final Set<String> _cantrips = {..._options.chosenCantrips};
  late final Set<String> _spells = {..._options.chosenSpells};

  Spellcasting get _sc => widget.spellcasting;
  bool get _prepared => _sc.preparation == SpellPreparation.prepared;

  int get _maxSlotLevel =>
      _sc.slotsByLevel.keys.fold<int>(0, (m, l) => l > m ? l : m);

  /// El mismo diálogo que la ficha: elegir un conjuro sin poder leerlo obligaba
  /// a buscar qué hace afuera de la aplicación.
  void _showSpell(String id) {
    if (widget.repo.spell(id) case final spell?) {
      showSpellDetailsDialog(context, spell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cantrips = _options.cantrips;
    final grantedCantrips = _options.grantedCantrips.isNotEmpty;
    final leveled = _options.spells;
    final grantedLeveledNames = _options.grantedSpells;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.classId == null
              ? context.l10n.spellEditTitle
              : context.l10n.spellEditTitleClass(
                  widget.repo.characterClass(_classId)?.name ?? _classId,
                ),
        ),
      ),
      body: PageBody(
        children: [
          if (_sc.cantripsKnown > 0) ...[
            Eyebrow(
              context.l10n.spellEditCantrips(
                _cantrips.length,
                _sc.cantripsKnown,
              ),
            ),
            if (grantedCantrips) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.spellEditGrantedCantrips,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            CappedChipSelect(
              options: {for (final s in cantrips) s.id: s.name},
              selected: _cantrips,
              max: _sc.cantripsKnown,
              onChanged: () => setState(() {}),
              onInfo: _showSpell,
            ),
            const SizedBox(height: 20),
          ],
          Eyebrow(
            _prepared
                ? context.l10n.spellEditPrepared(
                    _spells.length,
                    _sc.preparedCount,
                  )
                : context.l10n.spellEditKnown(_spells.length),
          ),
          Text(
            context.l10n.spellEditUpTo(_maxSlotLevel),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (grantedLeveledNames.isNotEmpty)
            Text(
              context.l10n.equipGrantedLeveled(grantedLeveledNames.join(', ')),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 6),
          CappedChipSelect(
            options: {
              for (final s in leveled)
                s.id: context.l10n.equipLevelShort(s.name, s.level),
            },
            selected: _spells,
            max: _prepared ? _sc.preparedCount : 9999,
            onChanged: () => setState(() {}),
            onInfo: _showSpell,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () {
              widget.onSave(_cantrips.toList(), _spells.toList());
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check),
            label: Text(context.l10n.commonSave),
          ),
        ),
      ),
    );
  }
}
