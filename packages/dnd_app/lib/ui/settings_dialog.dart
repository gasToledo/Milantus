import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_models.dart';
import '../data/settings_service.dart';
import '../theme/app_widgets.dart';
import '../l10n/l10n_context.dart';

/// Selecciona el proveedor de retratos entre los ofrecidos por
/// `GET /api/portraits/providers`. Las credenciales quedan en el servidor.
class SettingsDialog extends StatefulWidget {
  final ApiClient api;
  final SettingsController? settingsController;

  const SettingsDialog({super.key, required this.api, this.settingsController});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final SettingsController _settingsController =
      widget.settingsController ??
      SettingsController(widget.api, AppSettings());

  List<PortraitProviderInfo> _providers = [];
  String? _providerId;

  bool _loaded = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _loadError = null;
    });
    try {
      final settings = widget.settingsController == null
          ? await _settingsController.load()
          : _settingsController.settings;
      final providers = await widget.api.listPortraitProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _providerId = providers.any((p) => p.id == settings.imageProvider)
            ? settings.imageProvider
            : providers.firstOrNull?.id;
        _loaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _loadError = failureMessage(context.l10n.settingsLoadError, error),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || _providerId == null) return;
    setState(() => _saving = true);
    try {
      await _settingsController.update((settings) {
        settings.imageProvider = _providerId!;
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        failureMessage(context.l10n.settingsSaveError, error),
        tone: AppMessageTone.error,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El alto lo acota el propio molde y el ancho angosto también, así que acá
    // no hace falta medir la ventana.
    return AppDialog(
      title: context.l10n.settingsTitle,
      content: !_loaded && _loadError == null
          ? SizedBox(
              height: 80,
              child: Center(child: AppBusyLabel(context.l10n.settingsLoading)),
            )
          : _loadError != null
          ? _errorContent()
          : _formContent(),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        // Guardando, la celda queda deshabilitada y lo dice el rótulo: en una
        // barra de celdas no entra el spinner de `AppBusyLabel`, y el texto es
        // lo que informa de todos modos.
        DialogAction(
          _saving ? context.l10n.commonSaving : context.l10n.commonSave,
          primary: true,
          onPressed: _loaded && !_saving && _providerId != null ? _save : null,
        ),
      ],
    );
  }

  Widget _errorContent() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _loadError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.commonRetry),
      ),
    ],
  );

  Widget _formContent() {
    if (_providers.isEmpty) {
      return Text(context.l10n.settingsNoProviders);
    }
    return SingleChildScrollView(
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.settingsProviderLabel),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _providerId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _providers
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _providerId = v ?? _providerId),
            ),
          ],
        ),
      ),
    );
  }
}
