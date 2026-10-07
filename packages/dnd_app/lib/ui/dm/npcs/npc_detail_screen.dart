import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../api/api_exception.dart';
import '../../../api/api_models.dart';
import '../../../data/characters_controller.dart';
import '../../../data/settings_service.dart';
import '../../../homebrew/homebrew_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';
import '../../portrait_screen.dart';
import '../../sheet_screen.dart';
import 'npc_shared.dart';
import 'npc_table_view.dart';
import 'npc_transfer.dart';
import '../../../l10n/l10n_context.dart';

/// La ficha de un PNJ: quién es, cómo habla, qué se sabe de él, con qué pelea
/// y cómo está en cada campaña.
///
/// Es del DM y de nadie más: ningún dato de esta pantalla viaja a un jugador.
/// El trasfondo y las notas tampoco viajan al generador de retratos (ver
/// `buildNpcPortraitPrompt`).
class NpcDetailScreen extends StatefulWidget {
  final ApiClient api;
  final ContentRepository repo;
  final String npcId;
  final List<Campaign> campaigns;

  /// Los tags que ya usa la biblioteca, para sugerirlos.
  final List<String> knownTags;
  final AppThemeController? theme;
  final SettingsController? settingsController;

  const NpcDetailScreen({
    super.key,
    required this.api,
    required this.repo,
    required this.npcId,
    required this.campaigns,
    this.knownTags = const [],
    this.theme,
    this.settingsController,
  });

  @override
  State<NpcDetailScreen> createState() => _NpcDetailScreenState();
}

enum _NpcMenuAction { export, delete }

class _NpcDetailScreenState extends State<NpcDetailScreen> {
  NpcEntry? _entry;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entry = await widget.api.getNpc(widget.npcId);
      if (!mounted) return;
      setState(() {
        _entry = entry;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _report(Object error, [String? what]) {
    if (!mounted) return;
    showAppMessage(
      context,
      failureMessage(what ?? context.l10n.npcSaveFailed, error),
      tone: AppMessageTone.error,
    );
  }

  /// Guarda el documento entero, como el resto del Modo DM: no hay rutas finas
  /// por campo que puedan desincronizarse.
  Future<void> _save(Npc updated) async {
    final entry = _entry;
    if (entry == null) return;
    setState(
      () => _entry = NpcEntry(
        npc: updated,
        campaigns: entry.campaigns,
        sheet: entry.sheet,
      ),
    );
    try {
      await widget.api.updateNpc(updated);
    } catch (error) {
      _report(error);
      await _load();
    }
  }

  Future<void> _editText({
    required String title,
    required String label,
    required String current,
    required Npc Function(String value) apply,
    int maxLines = 1,
    bool allowEmpty = true,
  }) async {
    final value = await showTextPromptDialog(
      context,
      title: title,
      label: label,
      current: current,
      maxLines: maxLines,
      allowEmpty: allowEmpty,
      textCapitalization: TextCapitalization.sentences,
    );
    if (value == null || !mounted) return;
    await _save(apply(value.trim()));
  }

  /// El nombre se edita solo acá y, si tiene ficha de personaje, se le copia:
  /// la biblioteca busca por el del PNJ y la ficha muestra el suyo, y dos
  /// lápices terminaban en dos nombres distintos para el mismo personaje.
  Future<void> _rename(NpcEntry entry) async {
    final value = await showTextPromptDialog(
      context,
      title: context.l10n.npcEditName,
      label: context.l10n.npcNameLabel,
      current: entry.npc.name,
      allowEmpty: false,
      textCapitalization: TextCapitalization.words,
    );
    if (value == null || !mounted) return;
    final name = value.trim();
    try {
      await widget.api.updateNpc(entry.npc.copyWith(name: name));
      final sheet = entry.sheet;
      if (sheet != null) {
        await widget.api.upsertCharacter(sheet.copyWith(name: name));
      }
    } catch (error) {
      _report(error);
    }
    // Se relee entero y no se parchea el estado: la ficha que abre «Abrir
    // ficha completa» tiene que ser la renombrada, o su autoguardado
    // devolvería el nombre viejo.
    if (mounted) await _load();
  }

  Future<void> _addTag(Npc npc) async {
    var known = widget.knownTags;
    if (known.isEmpty) {
      // Los tags de toda la biblioteca, para sugerirlos. Si no se pueden leer
      // se sigue sin sugerencias: no es motivo para no dejar escribir uno.
      try {
        known = Npc.normalizeTags([
          for (final entry in await widget.api.listNpcs()) ...entry.npc.tags,
        ]);
      } on ApiException {
        known = const [];
      }
      if (!mounted) return;
    }
    final suggestions = [
      for (final tag in known)
        if (!npc.hasTag(tag)) tag,
    ];
    final tag = await showDialog<String>(
      context: context,
      builder: (_) => _TagDialog(suggestions: suggestions),
    );
    if (tag == null || tag.trim().isEmpty || !mounted) return;
    await _save(npc.copyWith(tags: [...npc.tags, tag.trim()]));
  }

  Future<void> _addNote(Npc npc) async {
    final text = await showTextPromptDialog(
      context,
      title: context.l10n.npcNewNote,
      label: context.l10n.invNoteTitle,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    await _save(
      npc.copyWith(
        notes: [
          NpcNote(
            id: 'nota-${DateTime.now().microsecondsSinceEpoch}',
            date: DateTime.now(),
            text: text.trim(),
          ),
          ...npc.notes,
        ],
      ),
    );
  }

  Future<void> _editBlock(Npc npc) async {
    final edited = await Navigator.of(context).push<Creature>(
      MaterialPageRoute(
        builder: (_) => CreatureForm(repo: widget.repo, initial: npc.block),
      ),
    );
    if (edited == null || !mounted) return;
    await _save(npc.copyWith(block: edited));
  }

  /// La ficha completa de un PNJ con ficha de personaje, con la misma pantalla
  /// que un jugador. Guarda por la ruta de personajes, que no le cambia el
  /// tipo a la fila: sigue siendo la ficha de un PNJ.
  Future<void> _openSheet(Character sheet) async {
    final controller = CharactersController(widget.api)..characters.add(sheet);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SheetScreen(
          character: sheet,
          repo: widget.repo,
          controller: controller,
          settingsController: widget.settingsController,
          theme: widget.theme ?? AppThemeController(),
          npcMode: true,
        ),
      ),
    );
    await controller.flush();
    controller.dispose();
    if (mounted) await _load();
  }

  Future<void> _setStatus(String campaignId, NpcStatus status) async {
    try {
      await widget.api.linkCampaignNpc(
        campaignId,
        widget.npcId,
        status: status,
      );
      await _load();
    } catch (error) {
      _report(error);
    }
  }

  Future<void> _linkToCampaign(NpcEntry entry) async {
    final options = [
      for (final c in widget.campaigns)
        if (!entry.isIn(c.id)) c,
    ];
    final picked = await showDialog<Campaign>(
      context: context,
      builder: (ctx) => AppDialog(
        title: context.l10n.npcAddToCampaign,
        content: options.isEmpty
            ? Text(context.l10n.npcInAllCampaigns)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in options)
                    ListTile(
                      title: Text(c.name),
                      onTap: () => Navigator.of(ctx).pop(c),
                    ),
                ],
              ),
        actions: [
          DialogAction(
            context.l10n.commonCancel,
            keyHint: 'Esc',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await widget.api.linkCampaignNpc(picked.id, widget.npcId);
      await _load();
    } catch (error) {
      _report(error);
    }
  }

  Future<void> _delete(NpcEntry entry) async {
    final pal = context.palette;
    final campaigns = entry.campaigns.map((c) => c.campaignName).join(', ');
    final deleteBody = entry.campaigns.isEmpty
        ? context.l10n.npcDeleteBodyLibrary
        : context.l10n.npcDeleteBodyCampaigns(campaigns);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: pal.crimson,
        title: context.l10n.npcDeleteTitle(entry.npc.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deleteBody),
            const SizedBox(height: 10),
            Text(
              context.l10n.npcDeletePastBattles,
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.npcDeleteJustUnlink,
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            ),
          ],
        ),
        actions: [
          DialogAction(
            context.l10n.commonCancel,
            keyHint: 'Esc',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          DialogAction(
            context.l10n.npcDelete,
            primary: true,
            color: pal.crimson,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.deleteNpc(entry.npc.id);
      if (!mounted) return;
      showAppMessage(
        context,
        context.l10n.npcDeleted(entry.npc.name),
        tone: AppMessageTone.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      _report(error, context.l10n.npcDeleteFailed);
    }
  }

  Future<void> _openPortrait(NpcEntry entry) async {
    final sheet = entry.sheet;
    if (entry.npc.sheetKind == NpcSheetKind.character && sheet != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PortraitScreen(
            character: sheet,
            repo: widget.repo,
            api: widget.api,
            settingsController: widget.settingsController,
            onUpdated: (updated) => widget.api.upsertCharacter(updated),
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PortraitScreen.forNpc(
            npc: entry.npc,
            repo: widget.repo,
            api: widget.api,
            settingsController: widget.settingsController,
            onNpcUpdated: (updated) => widget.api.updateNpc(updated),
          ),
        ),
      );
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(
        // Sin el nombre: ya encabeza la pantalla, más grande y con su lápiz.
        title: Text(context.l10n.kindNpc),
        actions: [
          if (entry != null) ...[
            IconButton(
              tooltip: context.l10n.npcShowTable,
              icon: const Icon(Icons.co_present_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NpcTableViewScreen(
                    name: entry.npc.name,
                    portraitKey: npcPortraitKey(entry.npc, entry.sheet),
                  ),
                ),
              ),
            ),
            PopupMenuButton<_NpcMenuAction>(
              tooltip: context.l10n.npcMoreActions,
              onSelected: (action) => switch (action) {
                _NpcMenuAction.export => exportNpcFlow(
                  context,
                  api: widget.api,
                  entry: entry,
                ),
                _NpcMenuAction.delete => _delete(entry),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _NpcMenuAction.export,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(context.l10n.npcExport),
                  ),
                ),
                PopupMenuItem(
                  value: _NpcMenuAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: context.palette.crimson,
                    ),
                    title: Text(
                      context.l10n.npcDelete,
                      style: TextStyle(color: context.palette.crimson),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return AppErrorView(
        message: context.l10n.npcReadFail,
        details: '$_error',
        onRetry: _load,
      );
    }
    final entry = _entry;
    if (entry == null) {
      return _loading
          ? Center(child: AppBusyLabel(context.l10n.npcLoading))
          : AppEmptyState(
              icon: Icons.person_off_outlined,
              message: context.l10n.npcGone,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.commonBack),
                ),
              ],
            );
    }
    final npc = entry.npc;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final left = [
          _identity(context, entry),
          _card(
            context,
            title: context.l10n.npcSpeech,
            onEdit: () => _editText(
              title: context.l10n.npcSpeech,
              label: context.l10n.npcSpeechHint,
              current: npc.speech,
              maxLines: 3,
              apply: (v) => npc.copyWith(speech: v),
            ),
            child: _prose(context, npc.speech, context.l10n.npcSpeechEmpty),
          ),
          _card(
            context,
            title: context.l10n.stepBackground,
            onEdit: () => _editText(
              title: context.l10n.stepBackground,
              label: context.l10n.stepBackground,
              current: npc.background,
              maxLines: 10,
              apply: (v) => npc.copyWith(background: v),
            ),
            child: _prose(
              context,
              npc.background,
              context.l10n.npcNoBackground,
            ),
          ),
          _notes(context, npc),
        ];
        final right = [_stats(context, entry), _campaigns(context, entry)];
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  const SizedBox(width: 16),
                  SizedBox(width: 360, child: Column(children: right)),
                ],
              )
            else ...[
              ...left,
              ...right,
            ],
          ],
        );
      },
    );
  }

  Widget _identity(BuildContext context, NpcEntry entry) {
    final pal = context.palette;
    final npc = entry.npc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // La única puerta al retrato, también para un PNJ con ficha: la
          // ficha completa ya no ofrece la suya. El ícono sobre el aro es lo
          // que avisa que el medallón se toca.
          Tooltip(
            message: context.l10n.npcPortrait,
            child: InkWell(
              onTap: () => _openPortrait(entry),
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  Medallion(
                    portraitKey: npcPortraitKey(npc, entry.sheet),
                    name: npc.name,
                    size: 76,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: pal.hairline),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 14,
                        color: pal.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        npc.name,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 28,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.npcEditName,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _rename(entry),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GoldPill(
                      npcTypeLine(npc, entry.sheet, widget.repo, context.l10n),
                    ),
                    for (final tag in npc.tags)
                      InputChip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          color: pal.textMuted,
                        ),
                        onDeleted: () => _save(
                          npc.copyWith(
                            tags: [
                              for (final t in npc.tags)
                                if (t != tag) t,
                            ],
                          ),
                        ),
                        deleteButtonTooltipMessage: context.l10n.npcRemoveTag(
                          tag,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => _addTag(npc),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(context.l10n.npcTagWord),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prose(BuildContext context, String text, String empty) => Text(
    text.isEmpty ? empty : text,
    style: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: text.isEmpty ? context.palette.textMuted : null,
      fontStyle: text.isEmpty ? FontStyle.italic : null,
    ),
  );

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
    VoidCallback? onEdit,
    Widget? trailing,
  }) {
    final pal = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 17),
                ),
              ),
              ?trailing,
              if (onEdit != null)
                IconButton(
                  tooltip: context.l10n.npcEditTitle(title.toLowerCase()),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _notes(BuildContext context, Npc npc) {
    final pal = context.palette;
    return _card(
      context,
      title: context.l10n.npcNotesWord,
      trailing: TextButton.icon(
        onPressed: () => _addNote(npc),
        icon: const Icon(Icons.add, size: 16),
        label: Text(context.l10n.npcAddNote),
      ),
      child: npc.notes.isEmpty
          ? _prose(context, '', context.l10n.npcNoNotes)
          : Column(
              children: [
                for (final note in npc.notes)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: pal.plaque,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(note.date.toLocal()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pal.textMuted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(note.text),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.dmDeleteNote,
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _save(
                            npc.copyWith(
                              notes: [
                                for (final n in npc.notes)
                                  if (n.id != note.id) n,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _stats(BuildContext context, NpcEntry entry) {
    final pal = context.palette;
    final npc = entry.npc;
    switch (npc.sheetKind) {
      case NpcSheetKind.none:
        return _card(
          context,
          title: context.l10n.npcStats,
          child: _prose(context, '', context.l10n.npcNoStatsNote),
        );
      case NpcSheetKind.block:
        final block = npc.block ?? emptyNpcBlock(npc.name);
        final baseName = npcBaseName(npc, widget.repo);
        return _card(
          context,
          title: context.l10n.npcBlockTitle,
          trailing: baseName == null
              ? null
              : Text(
                  context.l10n.npcBasedOn(baseName),
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatPlaque(
                      label: context.l10n.creatureAcShort,
                      value: block.ac,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatPlaque(
                      label: context.l10n.dmAbbrHp,
                      value: block.hp,
                      valueColor: pal.crimson,
                    ),
                  ),
                  if (block.cr != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatPlaque(
                        label: context.l10n.challengeRatingShort,
                        value: challengeRatingLabel(block.cr!),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              for (final action in block.actions.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${action.name}. ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: [
                            if (action.attackBonus != null)
                              '+${action.attackBonus}',
                            if (action.damage != null) action.damage!,
                          ].join(' · '),
                          style: TextStyle(color: pal.textMuted),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _editBlock(npc),
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.l10n.npcEditBlock),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.npcBlockCopyNote,
                style: TextStyle(fontSize: 11.5, color: pal.textMuted),
              ),
            ],
          ),
        );
      case NpcSheetKind.character:
        final sheet = entry.sheet;
        return _card(
          context,
          title: context.l10n.npcSheetTitle,
          child: sheet == null
              ? _prose(context, '', context.l10n.npcSheetReadFail)
              // Especie, clase y nivel ya están en la pill bajo el nombre; acá
              // solo va lo que se hace con la ficha.
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openSheet(sheet),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(context.l10n.npcOpenFullSheet),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.npcFullSheetNote,
                      style: TextStyle(fontSize: 11.5, color: pal.textMuted),
                    ),
                  ],
                ),
        );
    }
  }

  Widget _campaigns(BuildContext context, NpcEntry entry) {
    return _card(
      context,
      title: context.l10n.npcInCampaigns,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.campaigns.isEmpty)
            _prose(context, '', context.l10n.npcNoCampaignsYet),
          for (final link in entry.campaigns)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(link.campaignName),
                  const SizedBox(height: 6),
                  NpcStatusSelector(
                    status: link.status,
                    semanticLabel: context.l10n.npcStatusIn(link.campaignName),
                    onChanged: (s) => _setStatus(link.campaignId, s),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _linkToCampaign(entry),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.npcAddToAnother),
          ),
        ],
      ),
    );
  }
}

/// Un tag nuevo, con los que ya existen en la biblioteca como atajo: así
/// «Waterdeep» no termina escrito de tres formas.
class _TagDialog extends StatefulWidget {
  final List<String> suggestions;
  const _TagDialog({required this.suggestions});

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final matching = [
      for (final tag in widget.suggestions)
        if (tag.toLowerCase().contains(query)) tag,
    ];
    return AppDialog(
      title: context.l10n.npcAddTag,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(labelText: context.l10n.npcTagWord),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          if (matching.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in matching)
                  ActionChip(
                    label: Text(tag),
                    onPressed: () => Navigator.of(context).pop(tag),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          context.l10n.commonAdd,
          primary: true,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
