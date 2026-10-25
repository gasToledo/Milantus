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
          const SidebarBrand(),
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

/// La marca en lo alto de todo panel lateral: el sello, el nombre y el
/// subtítulo. Es la misma en el menú principal y en las pantallas de adentro
/// (ficha, Códice, creación), para que el panel se reconozca como uno solo.
class SidebarBrand extends StatelessWidget {
  const SidebarBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
      child: Row(
        children: [
          // 38 ocupa lo mismo que ocupaba el rombo de 26 girado (su
          // diagonal), así el nombre no se corre de lugar.
          CustomPaint(
            size: const Size.square(38),
            painter: _SealPainter(
              gold: pal.gold,
              background: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '$appName\n'),
                  // El subtítulo va más chico a propósito: a 17 no entra en
                  // los 236 de ancho del panel y parte la palabra, mientras
                  // que el nombre sí tiene que leerse como el título.
                  TextSpan(
                    text: context.l10n.appTagline,
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El sello de Milantus: doble aro con un rombo en cada punto cardinal y la M
/// angulosa. Es el mismo dibujo que el favicon y los íconos de la PWA en su
/// versión de cabecera, y se pinta a mano en vez de ser una imagen para que
/// siga al oro de cada tema.
///
/// Las coordenadas son las del boceto, sobre un lienzo de 120. A este tamaño
/// el rombo que el sello grande lleva bajo la M no se vería y se omite.
class _SealPainter extends CustomPainter {
  final Color gold;

  /// El color del panel: los rombos llevan un filete de este color para que
  /// corten el aro en vez de apoyarse encima.
  final Color background;

  const _SealPainter({required this.gold, required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    final stroke = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    canvas.drawCircle(const Offset(60, 60), 53, stroke..strokeWidth = 5);

    final cut = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()..color = gold;
    for (final (x, y) in const [
      (60.0, 7.0),
      (113.0, 60.0),
      (60.0, 113.0),
      (7.0, 60.0),
    ]) {
      final rombo = Path()
        ..moveTo(x, y - 7)
        ..lineTo(x + 7, y)
        ..lineTo(x, y + 7)
        ..lineTo(x - 7, y)
        ..close();
      canvas
        ..drawPath(rombo, cut)
        ..drawPath(rombo, fill);
    }

    // Esquinas vivas y remate cuadrado: es lo que la separa de una M de
    // fuente, y lo que la hace del sello y no de cualquier monograma.
    final m = Path()
      ..moveTo(37, 82)
      ..lineTo(37, 38)
      ..lineTo(60, 62)
      ..lineTo(83, 38)
      ..lineTo(83, 82);
    canvas.drawPath(
      m,
      stroke
        ..strokeWidth = 9
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.gold != gold || old.background != background;
}

/// La parte que scrollea de un panel lateral.
///
/// La barra queda a la vista siempre que haya más de lo que entra: en una
/// notebook el último ítem salía cortado al pie y se leía como el final de la
/// lista, no como algo que sigue. Sin barra a la vista, la rueda era la única
/// pista.
class SidebarList extends StatefulWidget {
  final List<Widget> children;

  const SidebarList({super.key, required this.children});

  @override
  State<SidebarList> createState() => _SidebarListState();
}

class _SidebarListState extends State<SidebarList> {
  // Propio y no el primario: en web de escritorio un `ListView` no toma el
  // `PrimaryScrollController`, y una barra sin controlador no tiene qué medir.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scroll,
    thumbVisibility: true,
    child: ListView(
      controller: _scroll,
      // El margen es para la barra: encima del ítem tapaba los contadores.
      padding: const EdgeInsets.only(right: 10),
      children: widget.children,
    ),
  );
}

/// El «volver» de una pantalla de adentro.
///
/// Ocupa el lugar que en el menú principal tiene el interruptor de modo, con
/// la misma forma: así la salida está siempre en el mismo sitio del panel, se
/// esté donde se esté.
class SidebarBackButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const SidebarBackButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.arrow_back, size: 16, color: pal.gold),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        backgroundColor: pal.plaque,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: pal.hairline),
        minimumSize: const Size.fromHeight(40),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}

/// El pie liviano de una pantalla de adentro: la versión y, si la pantalla
/// tiene algo que decir de sí (la ficha, su cartel de guardado), [leading].
///
/// No repite el pie del menú principal —Ajustes, la cuenta, «Cerrar
/// sesión»— a propósito: la ficha ya tiene ocho ítems propios, y con ese pie
/// encima no entra en una ventana de laptop. Todo eso queda a un «volver».
///
/// La versión sale del canal de sugerencias, que el arranque ya deja a mano
/// para todas las rutas; en un test suelto no hay canal y no se muestra.
class SidebarLightFooter extends StatelessWidget {
  final Widget? leading;

  const SidebarLightFooter({super.key, this.leading});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final version = FeedbackScope.of(context)?.appVersion;
    if (leading == null && version == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 17, color: pal.hairline),
        Row(
          children: [
            Expanded(child: leading ?? const SizedBox.shrink()),
            if (version != null)
              Text(
                'v$version',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.3,
                  color: pal.gold,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// El título de la barra de arriba en ventana angosta, donde el panel lateral
/// vive en el cajón y su [SidebarBrand] no está a la vista. Es el mismo en el
/// Modo Jugador y en el Modo DM: la barra es del menú principal, no del modo.
class AppBarBrandTitle extends StatelessWidget {
  const AppBarBrandTitle({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Sin el sello, en el celular el logo solo aparecía al abrir el cajón.
      // 30 es lo que entra junto a las dos líneas sin agrandar la barra.
      CustomPaint(
        size: const Size.square(30),
        painter: _SealPainter(
          gold: context.palette.gold,
          background: Theme.of(context).colorScheme.surface,
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(appName),
            Text(
              context.l10n.appTagline,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.3,
                color: context.palette.gold,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
