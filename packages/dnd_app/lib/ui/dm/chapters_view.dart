import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../l10n/l10n_context.dart';

/// Los capítulos de una campaña: lo que se jugó, lo que se está jugando y lo
/// que viene.
///
/// Sin estado propio y totalmente controlada, igual que `EncounterView`: el
/// dueño del estado es `_CampaignDetailState`, que ya carga y recarga la lista.
/// Acá solo se pinta y se piden las acciones.
class ChaptersView extends StatelessWidget {
  final List<Chapter>? chapters;
  final bool loading;
  final Object? error;

  final VoidCallback onRetry;
  final VoidCallback onCreate;
  final void Function(Chapter chapter) onEdit;
  final void Function(Chapter chapter) onStart;
  final void Function(Chapter chapter) onClose;
  final void Function(Chapter chapter) onDelete;
  final void Function(Chapter chapter) onOpenNotebook;

  const ChaptersView({
    super.key,
    required this.chapters,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onCreate,
    required this.onEdit,
    required this.onStart,
    required this.onClose,
    required this.onDelete,
    required this.onOpenNotebook,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return AppErrorView(
        message: context.l10n.dmChaptersReadFail,
        details: '$error',
        onRetry: onRetry,
      );
    }
    if (loading) {
      return Center(child: AppBusyLabel(context.l10n.dmChaptersLoading));
    }
    final all = chapters ?? const <Chapter>[];
    if (all.isEmpty) {
      return AppEmptyState(
        icon: Icons.auto_stories_outlined,
        message: context.l10n.dmChaptersEmpty,
        actions: const [],
      );
    }

    // Agrupados en el orden en que le importan al DM: lo que está pasando,
    // lo que viene, y al final lo ya jugado. Dentro de cada grupo, el orden
    // de alta que devuelve el servidor.
    List<Chapter> of(ChapterState state) => [
      for (final c in all)
        if (c.state == state) c,
    ];
    final active = of(ChapterState.active);
    final planned = of(ChapterState.planned);
    final completed = of(ChapterState.completed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        for (final group in [
          (state: ChapterState.active, items: active),
          (state: ChapterState.planned, items: planned),
          (state: ChapterState.completed, items: completed),
        ])
          if (group.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Eyebrow(group.state.localized(context)),
            const SizedBox(height: 8),
            CardGrid(
              children: [
                for (final chapter in group.items)
                  _ChapterCard(
                    chapter: chapter,
                    onEdit: () => onEdit(chapter),
                    onStart: () => onStart(chapter),
                    onClose: () => _confirmClose(context, chapter),
                    onDelete: () => _confirmDelete(context, chapter),
                    onOpenNotebook: () => onOpenNotebook(chapter),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  /// Qué va a pasar al cerrar, dicho antes de que pase.
  ///
  /// Insiste en que la app no aplica nada porque es la única acción del Modo
  /// DM que le escribe algo a otra cuenta, y lo que le escribe es un aviso:
  /// el nivel, el oro y los ítems los anota cada jugador en su ficha.
  static String _closeMessage(Chapter chapter, AppLocalizations l10n) =>
      chapter.grantsLabel.isEmpty
      ? l10n.dmCloseChapterBody(chapter.name)
      : l10n.dmCloseChapterBodyRewards(chapter.name, chapter.grantsLabel);

  Future<void> _confirmClose(BuildContext context, Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: context.l10n.dmCloseChapter,
        content: Text(_closeMessage(chapter, context.l10n)),
        actions: [
          DialogAction(
            context.l10n.commonCancel,
            keyHint: 'Esc',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          DialogAction(
            context.l10n.dmCloseChapter,
            primary: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) onClose(chapter);
  }

  Future<void> _confirmDelete(BuildContext context, Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: context.palette.crimson,
        title: context.l10n.dmDeleteChapter,
        content: Text(context.l10n.dmDeleteChapterBody(chapter.name)),
        actions: [
          DialogAction(
            context.l10n.commonCancel,
            keyHint: 'Esc',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          DialogAction(
            context.l10n.dmDeleteChapter,
            primary: true,
            color: context.palette.crimson,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete(chapter);
  }
}

enum _ChapterMenuAction { edit, delete }

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onOpenNotebook;

  const _ChapterCard({
    required this.chapter,
    required this.onEdit,
    required this.onStart,
    required this.onClose,
    required this.onDelete,
    required this.onOpenNotebook,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final isActive = chapter.state == ChapterState.active;
    final isDone = chapter.state == ChapterState.completed;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: isActive ? pal.gold : pal.hairline,
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  chapter.name,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    // Lo ya jugado se apaga: sigue estando, pero no compite
                    // con lo que está pasando ahora.
                    color: isDone ? pal.textMuted : null,
                  ),
                ),
              ),
              if (chapter.grantsLevel) ...[
                const SizedBox(width: 8),
                GoldPill(context.l10n.dmLevelsUp),
              ],
              PopupMenuButton<_ChapterMenuAction>(
                tooltip: context.l10n.dmChapterActions,
                // Compacto para que no agrande la fila del título.
                padding: EdgeInsets.zero,
                onSelected: (action) => switch (action) {
                  _ChapterMenuAction.edit => onEdit(),
                  _ChapterMenuAction.delete => onDelete(),
                },
                itemBuilder: (context) => [
                  if (!isDone)
                    PopupMenuItem(
                      value: _ChapterMenuAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(context.l10n.commonEdit),
                      ),
                    ),
                  PopupMenuItem(
                    value: _ChapterMenuAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: pal.crimson),
                      title: Text(
                        context.l10n.commonDelete,
                        style: TextStyle(color: pal.crimson),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (chapter.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.dmGoalLine(chapter.summary),
              style: TextStyle(
                fontSize: 13,
                color: isDone ? pal.textMuted : null,
              ),
            ),
          ],
          if (chapter.grantsRewards) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 6),
                  child: Icon(
                    Icons.savings_outlined,
                    size: 15,
                    color: isDone ? pal.textMuted : pal.gold,
                  ),
                ),
                Expanded(
                  child: Text(
                    // En pasado si ya se cerró: el aviso ya salió.
                    isDone
                        ? context.l10n.dmRewardsTook(chapter.rewardsLabel)
                        : context.l10n.dmRewardsTake(chapter.rewardsLabel),
                    style: TextStyle(fontSize: 13, color: pal.textMuted),
                  ),
                ),
              ],
            ),
          ],
          // En la grilla la fila se iguala a la tarjeta más alta: los botones
          // van al pie para quedar alineados con los de al lado.
          const Spacer(),
          const SizedBox(height: 12),
          // Un solo primario según el estado, y al lado la salida al
          // Cuaderno; editar y borrar viven en el menú «⋯» del título.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (chapter.state == ChapterState.planned)
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(context.l10n.dmStart),
                ),
              if (isActive)
                FilledButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.done_all),
                  label: Text(context.l10n.dmCloseChapter),
                ),
              TextButton.icon(
                onPressed: onOpenNotebook,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(context.l10n.dmViewInNotebook),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
