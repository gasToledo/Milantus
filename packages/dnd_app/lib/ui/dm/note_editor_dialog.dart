import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../theme/app_widgets.dart';
import '../../l10n/l10n_context.dart';

/// Escribir o corregir una nota del Cuaderno.
///
/// Devuelve la nota con los campos cargados, o `null` si se canceló. No guarda
/// nada: quien la abre decide si es alta o edición, igual que
/// `showChapterEditorDialog`.
///
/// El capítulo se elige acá adentro y arranca en el que esté en marcha. Es lo
/// que habilita preparar un capítulo que todavía no se jugó sin salir del
/// cuaderno.
Future<Note?> showNoteEditorDialog(
  BuildContext context, {
  required Note current,
  required List<Chapter> chapters,
  required String title,
}) {
  return showDialog<Note>(
    context: context,
    builder: (ctx) =>
        _NoteEditorDialog(current: current, chapters: chapters, title: title),
  );
}

class _NoteEditorDialog extends StatefulWidget {
  final Note current;
  final List<Chapter> chapters;
  final String title;

  const _NoteEditorDialog({
    required this.current,
    required this.chapters,
    required this.title,
  });

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.current.title,
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.current.body,
  );
  late String _chapterId = widget.current.chapterId;

  /// Mismo patrón que los editores de campaña y capítulo. Antes «Guardar» se
  /// apagaba sin título: se veía que no se podía, pero no por qué, y un botón
  /// gris al lado de un campo vacío no siempre se asocia con ese campo.
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    // Misma regla que hace cumplir el servidor: sin título no se guarda.
    if (title.isEmpty) {
      setState(() => _titleError = context.l10n.dmNoteTitleRequired);
      return;
    }
    Navigator.of(context).pop(
      widget.current.copyWith(
        chapterId: _chapterId,
        title: title,
        body: _body.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      width: 460,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _chapterId,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.l10n.dmChapter),
            items: [
              for (final chapter in widget.chapters)
                DropdownMenuItem(
                  value: chapter.id,
                  child: Text(
                    '${chapter.name} · ${chapter.state.localized(context)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _chapterId = v ?? _chapterId),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.diaryTitleLabel,
              // El título es campo aparte y no la primera línea del texto
              // porque es lo que se ve con la nota plegada y al buscar.
              helperText: context.l10n.dmNoteTitleHelper,
              errorText: _titleError,
            ),
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: context.l10n.invNoteTitle,
              alignLabelWithHint: true,
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
