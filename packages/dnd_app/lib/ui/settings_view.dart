import 'package:flutter/material.dart';

import '../data/settings_service.dart';
import '../l10n/l10n_context.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'app_sidebar.dart';

/// Ancho a partir del cual el control de una fila va al lado de su rótulo.
const double _kRowBesideWidth = 520;

/// Los ajustes de la cuenta, como una sección más del área de contenido.
///
/// Se abre igual desde el Modo Jugador y desde el Modo DM. El proveedor de
/// retratos no está acá: se elige en la pantalla de retratos, donde se usa.
///
/// No tiene botón de guardar: cada cambio se guarda al tocarlo, como en la
/// ficha, y el cartel de arriba dice si llegó. Con un «Guardar» al pie,
/// cambiar de sección sin tocarlo perdía lo elegido sin avisar.
class SettingsView extends StatefulWidget {
  final SettingsController settingsController;
  final AppThemeController theme;

  const SettingsView({
    super.key,
    required this.settingsController,
    required this.theme,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

enum _SaveState { idle, saving, saved }

class _SettingsViewState extends State<SettingsView> {
  AppSettings get _settings => widget.settingsController.settings;

  _SaveState _save = _SaveState.idle;

  /// Aplica [mutate] en pantalla y lo guarda. Si el guardado falla se dice:
  /// lo elegido queda a la vista hasta la próxima carga, nunca se pierde en
  /// silencio.
  Future<void> _update(void Function(AppSettings settings) mutate) async {
    setState(() => _save = _SaveState.saving);
    try {
      await widget.settingsController.update(mutate);
      if (mounted) setState(() => _save = _SaveState.saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _save = _SaveState.idle);
      showAppMessage(
        context,
        failureMessage(context.l10n.settingsSaveError, error),
        tone: AppMessageTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _page(context, box.maxWidth < 600 ? 12 : 24),
  );

  Widget _page(BuildContext context, double side) {
    final pal = context.palette;
    final l10n = context.l10n;
    return ListView(
      // En un teléfono el margen se achica: el interruptor de modo, con sus
      // dos rótulos, no entra en el ancho que dejan 24 de cada lado.
      padding: EdgeInsets.fromLTRB(side, 24, side, 32),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsTitle,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.settingsSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: pal.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _saveStatus(context),
                  ],
                ),
                const SizedBox(height: 20),
                _group(context, l10n.settingsGeneral, [
                  _row(
                    context,
                    title: l10n.settingsStartMode,
                    hint: l10n.settingsStartModeHint,
                    control: SegmentedButton<AppMode>(
                      segments: [
                        ButtonSegment(
                          value: AppMode.player,
                          label: Text(l10n.dmPlayerMode),
                        ),
                        ButtonSegment(
                          value: AppMode.dm,
                          label: Text(l10n.dmModeButton),
                        ),
                      ],
                      selected: {
                        _settings.startsInDmMode ? AppMode.dm : AppMode.player,
                      },
                      showSelectedIcon: false,
                      onSelectionChanged: (picked) => _update(
                        (s) => s.startsInDmMode = picked.first == AppMode.dm,
                      ),
                    ),
                  ),
                  // El tema y el idioma se guardan por su propio controlador:
                  // son los mismos que usa la ficha, y cambian al instante.
                  _row(
                    context,
                    title: l10n.settingsTheme,
                    control: ThemeModeSelector(controller: widget.theme),
                  ),
                  _row(
                    context,
                    title: l10n.settingsLanguage,
                    control: const LanguageSelector(),
                  ),
                ]),
                const SizedBox(height: 20),
                _group(context, l10n.dmModeButton, [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
                    value: _settings.showEncounterDifficulty,
                    onChanged: (v) =>
                        _update((s) => s.showEncounterDifficulty = v),
                    title: Text(
                      l10n.settingsShowDifficulty,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      l10n.settingsShowDifficultyHint,
                      style: TextStyle(fontSize: 12, color: pal.textMuted),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveStatus(BuildContext context) {
    final pal = context.palette;
    final l10n = context.l10n;
    return switch (_save) {
      _SaveState.idle => const SizedBox.shrink(),
      _SaveState.saving => Text(
        l10n.commonSaving,
        style: TextStyle(fontSize: 12, color: pal.textMuted),
      ),
      _SaveState.saved => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: pal.verdant),
          const SizedBox(width: 6),
          Text(
            l10n.settingsSaved,
            style: TextStyle(fontSize: 12, color: pal.verdant),
          ),
        ],
      ),
    };
  }

  Widget _group(BuildContext context, String label, List<Widget> rows) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
              color: pal.textMuted,
            ),
          ),
        ),
        // `Material` y no un `Container` con color: el interruptor pinta su
        // tinta sobre el `Material` más cercano, y un fondo intermedio la tapa.
        Material(
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: pal.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) Divider(height: 1, color: pal.hairline),
                row,
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Una fila de ajuste: el rótulo con su explicación y el control. Con ancho
  /// van lado a lado; sin él, el control baja entero a su propia línea.
  Widget _row(
    BuildContext context, {
    required String title,
    String? hint,
    required Widget control,
  }) {
    final pal = context.palette;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 14)),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint, style: TextStyle(fontSize: 12, color: pal.textMuted)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= _kRowBesideWidth
            ? Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 24),
                  SizedBox(width: 260, child: control),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [text, const SizedBox(height: 10), control],
              ),
      ),
    );
  }
}
