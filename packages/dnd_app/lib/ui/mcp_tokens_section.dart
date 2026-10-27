import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../api/api_client.dart';
import '../api/api_models.dart';
import '../l10n/l10n_context.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// El comando que conecta Claude Code a esta cuenta. Se arma con el origen
/// de la página: es el mismo servidor que atiende `/mcp`.
String mcpConnectCommand(String origin, String secret) =>
    'claude mcp add --transport http milantus $origin/mcp ' // l10n-ignore: comando de terminal, no texto de la interfaz
    '--header "Authorization: Bearer $secret"';

/// Los tokens personales con que Claude Code entra al Modo DM: crearlos,
/// ver cuándo se usaron y revocarlos. Va como filas de un grupo de Ajustes.
class McpTokensSection extends StatefulWidget {
  final ApiClient api;

  const McpTokensSection({super.key, required this.api});

  @override
  State<McpTokensSection> createState() => _McpTokensSectionState();
}

class _McpTokensSectionState extends State<McpTokensSection> {
  List<ApiTokenInfo>? _tokens;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final tokens = await widget.api.listApiTokens();
      if (mounted) setState(() => _tokens = tokens);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await showTextPromptDialog(
      context,
      title: l10n.mcpTokenNameTitle,
      label: l10n.mcpTokenNameLabel,
      textCapitalization: TextCapitalization.sentences,
    );
    if (name == null || !mounted) return;
    try {
      final (token, secret) = await widget.api.createApiToken(name);
      if (!mounted) return;
      setState(() => _tokens = [token, ...?_tokens]);
      await showDialog<void>(
        context: context,
        builder: (_) => _CreatedDialog(
          command: mcpConnectCommand(
            // No `Uri.base.origin`: lanza fuera de http, y los tests corren
            // desde `file:`.
            '${Uri.base.scheme}://${Uri.base.authority}',
            secret,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        failureMessage(l10n.mcpTokenCreateError, error),
        tone: AppMessageTone.error,
      );
    }
  }

  Future<void> _revoke(ApiTokenInfo token) async {
    final l10n = context.l10n;
    try {
      await widget.api.revokeApiToken(token.id);
      if (mounted) {
        setState(
          () => _tokens = [
            for (final t in _tokens ?? const <ApiTokenInfo>[])
              if (t.id != token.id) t,
          ],
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        failureMessage(l10n.mcpTokenRevokeError, error),
        tone: AppMessageTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final l10n = context.l10n;
    final tokens = _tokens;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            AppErrorView(
              message: failureMessage(l10n.mcpTokensLoadError, _error!),
              onRetry: _load,
            )
          else if (tokens == null)
            AppBusyLabel(l10n.mcpTokensLoading)
          else if (tokens.isEmpty)
            Text(
              l10n.mcpTokensEmpty,
              style: TextStyle(fontSize: 13, color: pal.textMuted),
            )
          else
            for (final t in tokens)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: const TextStyle(fontSize: 14)),
                        Text(
                          t.lastUsedAt == null
                              ? l10n.mcpTokenUnused(
                                  date.format(t.expiresAt.toLocal()),
                                )
                              : l10n.mcpTokenUsed(
                                  date.format(t.lastUsedAt!.toLocal()),
                                  date.format(t.expiresAt.toLocal()),
                                ),
                          style: TextStyle(fontSize: 12, color: pal.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.mcpTokenRevoke(t.name),
                    onPressed: () => _revoke(t),
                    icon: Icon(Icons.link_off, color: pal.crimson, size: 20),
                  ),
                ],
              ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.mcpTokenCreate),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatedDialog extends StatefulWidget {
  final String command;
  const _CreatedDialog({required this.command});

  @override
  State<_CreatedDialog> createState() => _CreatedDialogState();
}

class _CreatedDialogState extends State<_CreatedDialog> {
  bool _copied = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final l10n = context.l10n;
    return AppDialog(
      title: l10n.mcpTokenCreatedTitle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.mcpTokenCreatedNote, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.plaque,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              widget.command,
              key: const ValueKey('mcp-command'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _error ?? (_copied ? l10n.mcpCommandCopied : ''),
                  style: TextStyle(
                    fontSize: 12,
                    color: _error != null ? pal.crimson : pal.textMuted,
                  ),
                ),
              ),
              TextButton.icon(
                // Mismo cuidado que el código de compartir: el aviso va en el
                // diálogo, y el navegador puede negar el portapapeles.
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: widget.command),
                    );
                    if (mounted) setState(() => _copied = true);
                  } catch (_) {
                    if (mounted) setState(() => _error = l10n.mcpCopyFailed);
                  }
                },
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                label: Text(l10n.commonCopy),
              ),
            ],
          ),
        ],
      ),
      actions: [
        DialogAction(
          l10n.commonClose,
          primary: true,
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
