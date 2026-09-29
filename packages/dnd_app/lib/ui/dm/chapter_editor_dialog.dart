import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../l10n/l10n_context.dart';

/// Editor de un capítulo: nombre, objetivo y qué reparte al cerrarse.
///
/// Es un diálogo propio y no `showTextPromptDialog` porque ese resuelve un solo
/// campo y acá hacen falta varios. Devuelve el capítulo con los cambios, o `null`
/// si se canceló.
///
/// Sirve para crear y para editar: [current] es el capítulo que se está
/// tocando, y quien llama decide si mandarlo a `createChapter` o a
/// `upsertChapter`. El **estado no se edita acá** — se cambia con las acciones
/// de la lista (Empezar, Cerrar), que son las que tienen consecuencias.
Future<Chapter?> showChapterEditorDialog(
  BuildContext context, {
  required Chapter current,
  required String title,
}) {
  return showDialog<Chapter>(
    context: context,
    builder: (context) => _ChapterEditorDialog(current: current, title: title),
  );
}

class _ChapterEditorDialog extends StatefulWidget {
  final Chapter current;
  final String title;

  const _ChapterEditorDialog({required this.current, required this.title});

  @override
  State<_ChapterEditorDialog> createState() => _ChapterEditorDialogState();
}

class _ChapterEditorDialogState extends State<_ChapterEditorDialog> {
  late final _nameController = TextEditingController(text: widget.current.name);
  late final _summaryController = TextEditingController(
    text: widget.current.summary,
  );
  late final _goldController = TextEditingController(
    text: widget.current.grantsGold > 0 ? '${widget.current.grantsGold}' : '',
  );
  // Un ítem por línea: es la forma más corta de escribir una lista corta a
  // mano, sin un botón de "agregar" por cada renglón.
  late final _itemsController = TextEditingController(
    text: widget.current.grantsItems.join('\n'),
  );
  late bool _grantsLevel = widget.current.grantsLevel;

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _goldController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  /// Se enciende en el primer intento de guardar sin nombre, igual que la
  /// validación de los formularios homebrew: marcar en rojo un campo que
  /// todavía se está tipeando es ruido, pero un botón que no hace nada y no
  /// dice por qué se lee como que la app se colgó.
  String? _nameError;

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.l10n.dmChapterNameRequired);
      return;
    }
    Navigator.of(context).pop(
      widget.current.copyWith(
        name: name,
        summary: _summaryController.text.trim(),
        grantsLevel: _grantsLevel,
        grantsGold: int.tryParse(_goldController.text.trim()) ?? 0,
        grantsItems: [
          for (final line in _itemsController.text.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return AppDialog(
      title: widget.title,
      width: 420,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.l10n.dmChapterName,
              border: const OutlineInputBorder(),
              errorText: _nameError,
            ),
            // El rojo se apaga solo al escribir: dejarlo puesto mientras ya
            // se está corrigiendo es regañar de más.
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _summaryController,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: context.l10n.dmChapterGoal,
              hintText: context.l10n.dmChapterGoalHint,
              helperText: context.l10n.dmChapterGoalHelper,
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Lo que sigue es lo que se reparte al cerrar, y nada de esto lo
          // aplica la app: al cerrar el capítulo solo se les avisa. Ni el
          // nivel ni la bolsa ni el inventario de un personaje los toca
          // nadie que no sea su jugador, así que conviene que el DM sepa
          // que está escribiendo un aviso y no una ficha.
          Eyebrow(context.l10n.dmOnCloseCarry),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _grantsLevel,
            onChanged: (value) => setState(() => _grantsLevel = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.l10n.dmOneLevel),
            subtitle: Text(
              context.l10n.dmLevelUpNote,
              style: TextStyle(fontSize: 12, color: pal.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _goldController,
            keyboardType: TextInputType.number,
            // Solo dígitos: así el campo no puede producir oro negativo y
            // no hace falta ningún mensaje de error explicándolo.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: context.l10n.dmGoldEach,
              hintText: '0',
              helperText: context.l10n.dmGoldHelper,
              suffixText: context.l10n.coinAbbrGold,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _itemsController,
            minLines: 2,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.dmItems,
              hintText: context.l10n.dmItemsHint,
              helperText: context.l10n.dmItemsHelper,
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(context.l10n.commonSave, primary: true, onPressed: _save),
      ],
    );
  }
}
