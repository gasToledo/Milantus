import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_models.dart';
import '../l10n/l10n_context.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../web/browser.dart' as browser;
import 'feedback.dart';

/// Los dos sombreros de una misma cuenta. No es un rol ni un permiso: cualquier
/// cuenta entra a los dos, y quien dirige una mesa puede ser jugador en otra.
enum AppMode { player, dm }

/// El marco del panel lateral, compartido por el Modo Jugador y el Modo DM.
///
/// Antes cada modo armaba el suyo, y el del DM había perdido la marca, la
/// cuenta, «Cerrar sesión» y la versión: quien solo dirige se quedaba sin
/// forma de salir de su cuenta sin pasar por una pantalla que no usa. Ahora lo
/// único que cambia entre los dos es [navigation]; lo de arriba y lo de abajo
/// es lo mismo.
class AppSidebar extends StatelessWidget {
  final AppMode mode;
  final ValueChanged<AppMode> onModeChanged;

  /// La navegación propia del modo. Ocupa el alto que sobra: si puede no
  /// entrar (la del DM, con sus campañas), tiene que traer su propio scroll.
  final Widget navigation;

  final ApiClient api;
  final AccountInfo? account;
  final String? appVersion;
  final bool settingsActive;
  final VoidCallback onOpenSettings;

  /// En el cajón de una ventana angosta no hay ancho fijo: lo da el `Drawer`.
  final bool inDrawer;

  const AppSidebar({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.navigation,
    required this.api,
    required this.account,
    required this.appVersion,
    required this.settingsActive,
    required this.onOpenSettings,
    this.inDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: inDrawer ? null : 236,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: pal.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
            child: Row(
              children: [
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: pal.gold,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '$appName\n'),
                        // El subtítulo va más chico a propósito: a 17 no
                        // entra en los 236 de ancho del panel y parte la
                        // palabra, mientras que el nombre sí tiene que
                        // leerse como el título.
                        TextSpan(
                          text: l10n.appTagline,
                          style: TextStyle(
                            color: pal.gold,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      height: 1.25,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Arriba y a la vista, no un botón al pie: son dos modos de la misma
          // cuenta y ninguno es «la pantalla de adentro» del otro. Las claves
          // van en los rótulos porque `ButtonSegment` no acepta una.
          Semantics(
            label: l10n.modeSwitchLabel,
            container: true,
            child: SegmentedButton<AppMode>(
              segments: [
                ButtonSegment(
                  value: AppMode.player,
                  label: Text(
                    l10n.modePlayer,
                    key: const ValueKey('exit-dm-mode'),
                  ),
                ),
                ButtonSegment(
                  value: AppMode.dm,
                  label: Text(
                    l10n.modeDm,
                    key: const ValueKey('dm-mode-button'),
                  ),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (picked) {
                if (picked.first != mode) onModeChanged(picked.first);
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: navigation),
          Divider(height: 17, color: pal.hairline),
          appNavItem(
            context,
            icon: Icons.settings_outlined,
            label: l10n.settingsTitle,
            active: settingsActive,
            onTap: onOpenSettings,
          ),
          // Último ítem a propósito: es una salida para quien prueba la
          // aplicación, no una sección más de lo mismo.
          appNavItem(
            context,
            icon: Icons.feedback_outlined,
            label: l10n.feedbackButton,
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              showFeedbackDialog(context, origin: FeedbackOrigin.dashboard);
            },
          ),
          _accountFooter(context),
          // Null solo en tests, donde no se resuelve `PackageInfo`.
          if (appVersion case final version?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'v$version',
                key: const ValueKey('app-version'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.3,
                  color: pal.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Con qué cuenta se entró, y cómo salir de ella.
  ///
  /// Los datos son los que afirmó el proveedor OIDC (ver `AccountInfo`), así
  /// que pueden faltar: sin nombre ni correo queda solo el botón de salir, que
  /// es lo que de verdad no puede faltar.
  Widget _accountFooter(BuildContext context) {
    final account = this.account;
    if (account == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final pal = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account.name case final name?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                key: const ValueKey('account-name'),
                // El panel mide 236: un nombre largo tiene que recortarse, no
                // empujar el resto del pie fuera de la pantalla.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
            ),
          if (account.email case final email?)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 1, 8, 0),
              child: Text(
                email,
                key: const ValueKey('account-email'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          // En carmesí: es el color que la paleta ya usa para lo que resta
          // (daño, PG), así que marca la acción destructiva sin meter un rojo
          // ajeno al resto. El borde va atenuado para que no grite.
          OutlinedButton(
            key: const ValueKey('logout-button'),
            onPressed: () => _logout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: pal.crimson,
              side: BorderSide(color: pal.crimson.withAlpha(110)),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(context.l10n.accountSignOut),
          ),
        ],
      ),
    );
  }

  /// Cierra la sesión del servidor y navega a donde este indique. Ese destino
  /// es el cierre de sesión del proveedor: sin pasar por ahí, su cookie de SSO
  /// sigue viva y el próximo login entra sin pedir credenciales. Si el
  /// servidor no lo pudo calcular, se vuelve a la raíz, que redirige al login.
  Future<void> _logout(BuildContext context) async {
    try {
      final logoutUrl = await api.logout();
      browser.redirectTo(logoutUrl ?? '/');
    } catch (e) {
      // Sin esto, un fallo acá no se ve: la página no cambia y no aparece
      // nada, así que quien quiso salir se queda creyendo que salió.
      if (context.mounted) {
        showAppMessage(
          context,
          failureMessage(context.l10n.signOutError, e),
          tone: AppMessageTone.error,
        );
      }
    }
  }
}
