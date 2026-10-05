import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../l10n/l10n_context.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// Lo que hace falta para mandar una sugerencia, una vez que hay sesión.
class FeedbackChannel {
  final ApiClient api;

  /// El correo de la cuenta, para decirle a quien escribe a dónde le llega la
  /// respuesta. El servidor lo toma de la sesión, no de acá.
  final String? email;
  final String? appVersion;

  const FeedbackChannel({required this.api, this.email, this.appVersion});
}

/// Desde qué pantalla se abrió el diálogo. Viaja con el mensaje por su nombre:
/// es un dato para quien lee el correo, no texto de la interfaz.
enum FeedbackOrigin { dashboard, errorView }

enum FeedbackKind { idea, bug }

/// Da el [FeedbackChannel] a quien lo necesite. Va por encima de
/// `MaterialApp` (lo monta `DndApp`) y no del dashboard porque las vistas de
/// error también aparecen en rutas empujadas al `Navigator` (la ficha, el Modo
/// DM): hermanas del dashboard, no hijas.
///
/// Vale `null` mientras arranca la app: sin sesión no hay a nombre de quién
/// escribir, y «Reportar este error» no aparece.
class FeedbackScope extends InheritedNotifier<ValueNotifier<FeedbackChannel?>> {
  const FeedbackScope({
    super.key,
    required ValueNotifier<FeedbackChannel?> super.notifier,
    required super.child,
  });

  static FeedbackChannel? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FeedbackScope>()
      ?.notifier
      ?.value;

  /// Para quien escribe el canal (el arranque), sin suscribirse a sus cambios.
  static ValueNotifier<FeedbackChannel?>? notifierOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FeedbackScope>()?.notifier;
}

/// Abre el diálogo y, si el mensaje salió, lo confirma con un cartel.
/// [errorDetail] viaja tal cual en el correo: es el texto técnico que la
/// vista de error muestra en «Ver detalles».
Future<void> showFeedbackDialog(
  BuildContext context, {
  required FeedbackOrigin origin,
  FeedbackKind initialKind = FeedbackKind.idea,
  String? errorDetail,
}) async {
  final channel = FeedbackScope.of(context);
  if (channel == null) return;
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _FeedbackDialog(
      channel: channel,
      origin: origin,
      initialKind: initialKind,
      errorDetail: errorDetail,
    ),
  );
  if (sent == true && context.mounted) {
    showAppMessage(
      context,
      context.l10n.feedbackSent,
      tone: AppMessageTone.success,
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  final FeedbackChannel channel;
  final FeedbackOrigin origin;
  final FeedbackKind initialKind;
  final String? errorDetail;

  const _FeedbackDialog({
    required this.channel,
    required this.origin,
    required this.initialKind,
    this.errorDetail,
  });

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  late var _kind = widget.initialKind;
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  /// El mismo tope que acepta el servidor: cortar acá evita escribir un
  /// mensaje largo para enterarse recién al enviarlo de que no entra.
  static const _maxChars = 5000;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// Lo que la app sabe y el servidor no. Se lee al enviar, no al abrir: si
  /// alguien cambia el tema con el diálogo abierto, vale el del momento.
  Map<String, String> _context() {
    // La ventana entera y no el espacio del padre: es lo que hace falta para
    // reproducir un error de layout alrededor del corte de 900 px.
    final size = MediaQuery.sizeOf(context);
    return {
      'version': ?widget.channel.appVersion,
      'language': Localizations.localeOf(context).languageCode,
      'theme': Theme.of(context).brightness.name,
      'viewport': '${size.width.round()}x${size.height.round()}',
      'origin': widget.origin.name,
      'errorDetail': ?widget.errorDetail,
    };
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.channel.api.sendFeedback(
        kind: _kind.name,
        message: _message.text.trim(),
        context: _context(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // El diálogo queda abierto con el texto intacto: perder lo escrito por
      // un corte de red es la forma más rápida de que nadie vuelva a escribir.
      if (mounted) {
        setState(() {
          _sending = false;
          // El motivo viene traducido del código del servidor (ver
          // `ApiClient._errorFrom`), así que va en los dos idiomas.
          _error = failureMessage(context.l10n.feedbackSendError, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final canSend = !_sending && _message.text.trim().isNotEmpty;
    return AppDialog(
      title: l10n.feedbackTitle,
      icon: Icons.feedback_outlined,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (kind, icon, label) in [
                (
                  FeedbackKind.idea,
                  Icons.lightbulb_outline,
                  l10n.feedbackKindIdea,
                ),
                (
                  FeedbackKind.bug,
                  Icons.bug_report_outlined,
                  l10n.feedbackKindBug,
                ),
              ])
                ChoiceChip(
                  key: ValueKey('feedback-kind-${kind.name}'),
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  selected: _kind == kind,
                  onSelected: _sending
                      ? null
                      : (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('feedback-message'),
            controller: _message,
            enabled: !_sending,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            inputFormatters: [LengthLimitingTextInputFormatter(_maxChars)],
            decoration: InputDecoration(
              labelText: l10n.feedbackMessageLabel,
              alignLabelWithHint: true,
              hintText: switch (_kind) {
                FeedbackKind.idea => l10n.feedbackHintIdea,
                FeedbackKind.bug => l10n.feedbackHintBug,
              },
            ),
          ),
          if (widget.channel.email case final email?) ...[
            const SizedBox(height: 12),
            Text(
              l10n.feedbackReplyTo(email),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(fontSize: 13, color: context.palette.crimson),
              ),
            ),
          ],
        ],
      ),
      actions: [
        DialogAction(
          l10n.commonCancel,
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          keyHint: 'Esc',
        ),
        DialogAction(
          l10n.feedbackSend,
          onPressed: canSend ? _send : null,
          primary: true,
        ),
      ],
    );
  }
}
