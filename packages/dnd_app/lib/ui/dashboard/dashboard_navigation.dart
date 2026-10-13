part of '../dashboard_screen.dart';

extension _DashboardNavigation on _DashboardScreenState {
  /// El panel del Modo Jugador: el marco es [AppSidebar], el mismo del Modo
  /// DM, y acá va solo la navegación propia.
  Widget _sidebar(BuildContext context, {bool inDrawer = false}) {
    // Desde el panel colapsado, navegar debe cerrar el Drawer primero.
    void run(VoidCallback action) {
      if (inDrawer) Navigator.of(context).pop();
      action();
    }

    return AppSidebar(
      mode: AppMode.player,
      // El Modo DM es una pantalla encima de esta: entrar es abrir una puerta,
      // y al volver no queda ningún estado prendido que recordar.
      onModeChanged: (_) => run(_openDmMode),
      api: controller.api,
      account: widget.account,
      appVersion: widget.appVersion,
      settingsActive: _showSettings,
      onOpenSettings: () => run(() => _updateState(() => _showSettings = true)),
      inDrawer: inDrawer,
      navigation: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          appNavItem(
            context,
            icon: Icons.groups,
            label: context.l10n.navCharacters,
            active: !_showSettings,
            onTap: () => run(() => _updateState(() => _showSettings = false)),
          ),
          appNavItem(
            context,
            icon: Icons.menu_book_outlined,
            label: context.l10n.navCodex,
            onTap: () => run(_openCodex),
          ),
          // Homebrew no está acá: crear contenido es trabajo del DM y se abre
          // desde el Modo DM.
          appNavItem(
            context,
            icon: Icons.import_export,
            label: context.l10n.transferTitle,
            onTap: () => run(_transferDialog),
          ),
        ],
      ),
    );
  }
}
