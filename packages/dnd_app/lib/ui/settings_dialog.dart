import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_models.dart';
import '../data/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../l10n/l10n_context.dart';

/// Los ajustes de la cuenta: el proveedor de retratos, entre los ofrecidos por
/// `GET /api/portraits/providers` (las credenciales quedan en el servidor), y
/// si el Modo DM muestra la dificultad del encuentro.
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
  bool _showDifficulty = true;

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
        _showDifficulty = settings.showEncounterDifficulty;
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _settingsController.update((settings) {
        // Sin proveedores en el servidor no hay nada que elegir, pero el
        // resto de los ajustes se guarda igual.
        if (_providerId case final id?) settings.imageProvider = id;
        settings.showEncounterDifficulty = _showDifficulty;
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
          onPressed: _loaded && !_saving ? _save : null,
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
    final pal = context.palette;
    return SingleChildScrollView(
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._providerFields(),
            const SizedBox(height: 16),
            Divider(height: 1, color: pal.hairline),
            // Un interruptor y no una pestaña propia del Modo DM: es la única
            // preferencia del DM. Cuando haya varias, se mudan juntas.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showDifficulty,
              onChanged: (v) => setState(() => _showDifficulty = v),
              title: Text(context.l10n.settingsShowDifficulty),
              subtitle: Text(
                context.l10n.settingsShowDifficultyHint,
                style: TextStyle(fontSize: 12, color: pal.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _providerFields() {
    if (_providers.isEmpty) {
      return [Text(context.l10n.settingsNoProviders)];
    }
    return [
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
    ];
  }
}
