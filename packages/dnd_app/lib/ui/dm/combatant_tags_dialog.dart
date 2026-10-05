import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../conditions.dart';
import '../../l10n/l10n_context.dart';

/// Qué le está pasando a un combatiente, para que el DM no se olvide a mitad
/// de una ronda.
///
/// Las 14 condiciones del libro se ofrecen como atajo, pero el tag es **texto
/// libre**: la mitad de lo que hay que recordar en un combate no es una
/// condición oficial. «Envenenado» sale de la lista; «marcado por el pícaro» y
/// «concentrando en Bendición» hay que poder escribirlos.
///
/// Devuelve la lista final, o `null` si se canceló. Normalizar —sin repetidos,
/// sin vacíos— es responsabilidad de `Encounter.withTags`, no de acá.
Future<List<String>?> showCombatantTagsDialog(
  BuildContext context, {
  required String name,
  required List<String> current,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _TagsDialog(name: name, current: current),
  );
}

class _TagsDialog extends StatefulWidget {
  final String name;
  final List<String> current;

  const _TagsDialog({required this.name, required this.current});

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late final List<String> _tags = [...widget.current];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Las condiciones oficiales se comparan por su etiqueta y no por su id:
  /// los tags guardan la etiqueta en español, y un tag escrito a mano que diga
  /// «Envenenado» —o «Poisoned»— es el mismo que el del atajo (ver
  /// [conditionForTag]).
  bool _has(ConditionInfo condition) =>
      _tags.any((t) => conditionForTag(t) == condition);

  void _toggle(ConditionInfo condition) => setState(() {
    if (_has(condition)) {
      _tags.removeWhere((t) => conditionForTag(t) == condition);
    } else {
      // Siempre la española, en cualquier idioma: es lo que reconocen los
      // combates guardados y lo que se muestra traducido.
      _tags.add(condition.labelEs);
    }
  });

  void _addTyped() {
    final text = _controller.text.trim();
    // Escribir el nombre de una condición es marcarla: se guarda igual que
    // desde el atajo, en español.
    final condition = conditionForTag(text);
    final repeated = condition != null
        ? _has(condition)
        : _tags.any((t) => t.toLowerCase() == text.toLowerCase());
    if (text.isEmpty || repeated) {
      _controller.clear();
      return;
    }
    setState(() => _tags.add(condition?.labelEs ?? text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    // Lo escrito a mano va aparte: las condiciones oficiales ya se ven
    // marcadas abajo, y repetirlas acá haría que cada una apareciera dos veces.
    final libres = [
      for (final tag in _tags)
        if (conditionForTag(tag) == null) tag,
    ];

    return AppDialog(
      title: context.l10n.dmEffectsOf(widget.name),
      width: 460,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.l10n.dmNoteEffect,
                    hintText: context.l10n.dmNoteEffectHint,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addTyped(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: context.l10n.wildShapeAddForms,
                onPressed: _addTyped,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (libres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in libres)
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    deleteButtonTooltipMessage: context.l10n.dmRemoveTag(tag),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Eyebrow(context.l10n.dmBookConditions),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final condition in conditions.values)
                Tooltip(
                  message: condition.description,
                  waitDuration: const Duration(milliseconds: 400),
                  child: FilterChip(
                    label: Text(condition.label),
                    selected: _has(condition),
                    onSelected: (_) => _toggle(condition),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.dmEffectsArePrivate,
            style: TextStyle(fontSize: 12, color: pal.textMuted),
          ),
        ],
      ),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          context.l10n.commonSave,
          primary: true,
          onPressed: () => Navigator.of(context).pop(_tags),
        ),
      ],
    );
  }
}
