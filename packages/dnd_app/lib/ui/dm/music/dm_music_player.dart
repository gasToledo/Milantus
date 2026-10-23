import 'dart:math' as math;

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n_context.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';
import '../../../web/browser.dart' as browser;
import '../../../web/music_embed.dart';
import 'music_scene_dialog.dart';

/// Qué suena y cómo se ve el reproductor del Modo DM.
///
/// Vive en la pantalla del Modo DM y no en una sección: cambiar de sección no
/// lo toca, y salir del Modo DM lo descarta junto con el embebido, que es lo
/// que corta la música.
class DmMusicController extends ChangeNotifier {
  MusicScene? _scene;
  MusicSource? _source;
  MusicEmbedController? _embed;
  bool _expanded = false;
  bool _showList = true;
  List<MusicScene> _offer = const [];

  MusicScene? get scene => _scene;
  MusicSource? get source => _source;
  MusicEmbedController? get embed => _embed;
  bool get expanded => _expanded;
  bool get showList => _showList || _scene == null;
  List<MusicScene> get offer => _offer;
  bool get playing => _embed?.playing ?? false;

  /// Pone [scene]. La misma que ya estaba se reanuda en vez de recargarse.
  void play(MusicScene scene) {
    final source = MusicSource.parse(scene.url);
    if (source == null) return;
    _offer = const [];
    _expanded = true;
    if (_scene?.id == scene.id && _source?.embedUrl == source.embedUrl) {
      _scene = scene;
      _embed?.play();
    } else {
      _embed?.dispose();
      _scene = scene;
      _source = source;
      _embed = MusicEmbedController()..addListener(notifyListeners);
      // Con algo sonando, la lista se pliega: lo que importa es el video.
      _showList = false;
    }
    notifyListeners();
  }

  void pause() => _embed?.pause();

  void stop() {
    _embed?.dispose();
    _embed = null;
    _scene = null;
    _source = null;
    notifyListeners();
  }

  void expand() {
    _expanded = true;
    notifyListeners();
  }

  /// YouTube exige su reproductor a la vista: minimizado, se pausa. Spotify
  /// no, y sigue sonando.
  void minimize() {
    if (_source?.site == MusicSite.youtube) _embed?.pause();
    _expanded = false;
    notifyListeners();
  }

  void toggleList() {
    _showList = !_showList;
    notifyListeners();
  }

  /// Al iniciar un combate: pregunta por las escenas marcadas, salvo que ya
  /// suene una de ellas. Nunca cambia la música sola.
  void offerCombat(List<MusicScene> scenes) {
    final marked = [
      for (final s in scenes)
        if (s.offerOnCombat) s,
    ];
    if (marked.isEmpty || marked.any((s) => s.id == _scene?.id)) return;
    _offer = marked;
    notifyListeners();
  }

  void dismissOffer() {
    _offer = const [];
    notifyListeners();
  }

  /// La campaña cambió sus escenas: la que suena se actualiza o se corta si
  /// la borraron, y la oferta deja afuera las que ya no están.
  void syncScenes(List<MusicScene> scenes) {
    final current = _scene;
    if (current != null) {
      final now = scenes.where((s) => s.id == current.id).firstOrNull;
      if (now == null) {
        stop();
      } else if (now.url != current.url) {
        play(now);
      } else {
        _scene = now;
      }
    }
    _offer = [
      for (final s in _offer)
        if (scenes.any((n) => n.id == s.id && n.offerOnCombat)) s,
    ];
  }

  @override
  void dispose() {
    _embed?.dispose();
    super.dispose();
  }
}

/// El reproductor flotante del Modo DM, para poner encima del contenido en un
/// `Stack` que ocupa todo el cuerpo.
///
/// El embebido va siempre en el mismo lugar del árbol y solo cambia su
/// rectángulo: mover un iframe de padre lo recarga, y la música se cortaría
/// al minimizar o desplegar.
class DmMusicPlayer extends StatelessWidget {
  final DmMusicController controller;
  final Campaign campaign;

  /// Aplica [change] a las escenas **tal como están guardadas en ese
  /// momento** y guarda el resultado. Se pasa el cambio y no la lista: un
  /// «Deshacer» que llega segundos después no puede partir de la lista que se
  /// veía al borrar.
  final Future<void> Function(
    List<MusicScene> Function(List<MusicScene> current) change,
  )
  updateScenes;

  /// Ventana angosta: barra al pie y hoja desde abajo.
  final bool narrow;

  const DmMusicPlayer({
    super.key,
    required this.controller,
    required this.campaign,
    required this.updateScenes,
    required this.narrow,
  });

  /// El alto que la barra minimizada ocupa al pie en ventana angosta, para que
  /// la pantalla lo reserve y no tape el último contenido.
  static const double narrowBarReserve = 76;

  static const double _cardWidth = 388;
  static const double _margin = 24;
  static const double _pad = 14;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final source = controller.source;
        final embedVisible =
            controller.expanded &&
            source != null &&
            !(controller.embed?.unembeddable ?? false);
        // YouTube pide al menos 200 × 200 a la vista; 16:9 en el ancho que
        // haya, nunca por debajo de 200 de alto.
        final embedWidth = narrow
            ? box.maxWidth - 2 * 16
            : _cardWidth - 2 * _pad - 2;
        final embedHeight = source?.site == MusicSite.spotify
            ? 80.0
            : math.max(200.0, embedWidth * 9 / 16);
        final chrome = _chrome(context, embedVisible ? embedHeight : 0);
        return Stack(
          children: [
            if (narrow)
              Positioned(
                left: controller.expanded ? 0 : 12,
                right: controller.expanded ? 0 : 12,
                bottom: controller.expanded ? 0 : 12,
                child: chrome,
              )
            else
              Positioned(right: _margin, bottom: _margin, child: chrome),
            if (source != null && controller.embed != null)
              Positioned(
                key: const ValueKey('music-embed'),
                right: embedVisible
                    ? (narrow ? 16 : _margin + 1 + _pad)
                    : (narrow ? 12 : _margin),
                bottom: embedVisible
                    ? (narrow ? 16 : _margin + 1 + _pad)
                    : (narrow ? 12 : _margin),
                // Fuera de la vista no se desmonta: queda en un punto, para
                // que Spotify siga sonando y YouTube conserve su pausa.
                width: embedVisible ? embedWidth : 1,
                height: embedVisible ? embedHeight : 1,
                child: IgnorePointer(
                  ignoring: !embedVisible,
                  child: musicEmbedView(source, controller.embed!),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _chrome(BuildContext context, double embedSpace) {
    final offer = controller.offer;
    final body = controller.expanded
        ? _card(context, embedSpace)
        : _bar(context);
    if (offer.isEmpty) return body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [_offerCard(context, offer), const SizedBox(height: 8), body],
    );
  }

  BoxDecoration _surface(BuildContext context, {double radius = 12}) =>
      BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.palette.hairline),
        borderRadius: BorderRadius.circular(radius),
      );

  // ------------------------------------------------------------ Minimizado

  Widget _bar(BuildContext context) {
    final l10n = context.l10n;
    final pal = context.palette;
    final scene = controller.scene;
    final source = controller.source;
    if (scene == null || source == null) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          key: const ValueKey('music-open'),
          onPressed: controller.expand,
          icon: Icon(Icons.music_note_outlined, size: 18, color: pal.gold),
          label: Text(l10n.dmMusic),
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            side: BorderSide(color: pal.hairline),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      );
    }
    final playing = controller.playing;
    return Container(
      key: const ValueKey('music-bar'),
      constraints: BoxConstraints(maxWidth: narrow ? double.infinity : 360),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: _surface(context, radius: 20),
      child: Row(
        mainAxisSize: narrow ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 18,
            color: playing ? pal.gold : pal.textMuted,
          ),
          const SizedBox(width: 10),
          Flexible(
            fit: narrow ? FlexFit.tight : FlexFit.loose,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  playing
                      ? musicSiteName(source.site)
                      : '${musicSiteName(source.site)} · ${l10n.dmMusicPausedTag}',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('music-bar-toggle'),
            tooltip: playing ? l10n.dmMusicPause : l10n.dmMusicResume,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            color: pal.gold,
            // YouTube no puede sonar escondido: reproducir lo despliega.
            onPressed: playing
                ? controller.pause
                : () => controller.play(scene),
          ),
          IconButton(
            tooltip: l10n.commonExpand,
            icon: const Icon(Icons.expand_less),
            onPressed: controller.expand,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Desplegado

  Widget _card(BuildContext context, double embedSpace) {
    final l10n = context.l10n;
    final pal = context.palette;
    final scene = controller.scene;
    final source = controller.source;
    final unembeddable = controller.embed?.unembeddable ?? false;
    final pad = narrow ? 16.0 : _pad;
    return Container(
      key: const ValueKey('music-card'),
      width: narrow ? null : _cardWidth,
      decoration: narrow
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: pal.hairline)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            )
          : _surface(context),
      padding: EdgeInsets.fromLTRB(pad, pad - 4, pad, pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(l10n.dmMusic),
                    if (scene != null)
                      Text(
                        scene.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 17,
                        ),
                      ),
                  ],
                ),
              ),
              if (scene != null)
                IconButton(
                  key: const ValueKey('music-toggle-list'),
                  tooltip: l10n.dmMusicScenes,
                  icon: const Icon(Icons.queue_music),
                  color: controller.showList ? pal.gold : null,
                  onPressed: controller.toggleList,
                ),
              IconButton(
                key: const ValueKey('music-minimize'),
                tooltip: l10n.dmMusicMinimize,
                icon: const Icon(Icons.expand_more),
                onPressed: controller.minimize,
              ),
            ],
          ),
          if (unembeddable && source != null && scene != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.dmMusicUnembeddable(musicSiteName(source.site)),
              style: TextStyle(color: pal.crimson),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => browser.openInNewTab(source.pageUrl),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(l10n.dmMusicOpenIn(musicSiteName(source.site))),
                ),
                OutlinedButton(
                  onPressed: () => _edit(context, scene),
                  child: Text(l10n.dmMusicChangeLink),
                ),
              ],
            ),
          ],
          if (controller.showList) ...[
            const SizedBox(height: 10),
            _sceneList(context),
          ],
          if (embedSpace > 0) SizedBox(height: embedSpace + 12),
        ],
      ),
    );
  }

  Widget _sceneList(BuildContext context) {
    final l10n = context.l10n;
    final pal = context.palette;
    final scenes = campaign.musicScenes;
    final newScene = OutlinedButton.icon(
      key: const ValueKey('music-new-scene'),
      onPressed: () => _create(context),
      icon: Icon(Icons.add, size: 18, color: pal.gold),
      label: Text(l10n.dmMusicNewScene),
    );
    if (scenes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.dmMusicEmpty, style: TextStyle(color: pal.textMuted)),
          const SizedBox(height: 12),
          newScene,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(l10n.dmMusicScenes),
        // Con muchas escenas la lista scrollea sola y no empuja la tarjeta
        // fuera de la pantalla de una notebook.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 248),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final (i, s) in scenes.indexed) _sceneRow(context, i, s),
            ],
          ),
        ),
        const SizedBox(height: 6),
        newScene,
      ],
    );
  }

  Widget _sceneRow(BuildContext context, int index, MusicScene scene) {
    final l10n = context.l10n;
    final pal = context.palette;
    final source = MusicSource.parse(scene.url);
    final current = controller.scene?.id == scene.id;
    final playing = current && controller.playing;
    return Container(
      key: ValueKey('music-scene-${scene.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: current ? pal.goldSoft : pal.plaque,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: current ? pal.gold : null,
                  ),
                ),
                Text(
                  [
                    if (source != null) musicKindLabel(l10n, source),
                    if (scene.offerOnCombat) l10n.dmMusicOnCombatTag,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('music-play-${scene.id}'),
            tooltip: playing ? l10n.dmMusicPause : l10n.dmMusicResume,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            color: current ? pal.gold : null,
            onPressed: source == null
                ? null
                : playing
                ? controller.pause
                : () => controller.play(scene),
          ),
          PopupMenuButton<_SceneAction>(
            key: ValueKey('music-menu-${scene.id}'),
            tooltip: l10n.commonEdit,
            onSelected: (action) => switch (action) {
              _SceneAction.edit => _edit(context, scene),
              _SceneAction.offer => updateScenes(
                (current) => [
                  for (final s in current)
                    s.id == scene.id
                        ? s.copyWith(offerOnCombat: !s.offerOnCombat)
                        : s,
                ],
              ),
              _SceneAction.up => _moveUp(scene.id),
              _SceneAction.open => browser.openInNewTab(source!.pageUrl),
              _SceneAction.delete => _delete(context, index, scene),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SceneAction.edit,
                child: Text(l10n.commonEdit),
              ),
              CheckedPopupMenuItem(
                value: _SceneAction.offer,
                checked: scene.offerOnCombat,
                child: Text(l10n.dmMusicOfferOnCombat),
              ),
              PopupMenuItem(
                value: _SceneAction.up,
                enabled: index > 0,
                child: Text(l10n.dmMusicMoveUp),
              ),
              if (source != null)
                PopupMenuItem(
                  value: _SceneAction.open,
                  child: Text(l10n.dmMusicOpenIn(musicSiteName(source.site))),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                key: ValueKey('music-delete-${scene.id}'),
                value: _SceneAction.delete,
                child: Text(
                  l10n.commonDelete,
                  style: TextStyle(color: pal.crimson),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Oferta

  Widget _offerCard(BuildContext context, List<MusicScene> offer) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('music-offer'),
      width: narrow ? double.infinity : _cardWidth,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: _surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Eyebrow(l10n.dmMusicCombatStarted),
          Text(
            offer.length == 1
                ? l10n.dmMusicOfferOne(offer.single.name)
                : l10n.dmMusicOfferMany,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 17),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in offer)
                FilledButton.icon(
                  key: ValueKey('music-offer-${s.id}'),
                  onPressed: () => controller.play(s),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  // Con una sola, «Poner» alcanza: el nombre ya está arriba.
                  label: Text(offer.length == 1 ? l10n.dmMusicPlay : s.name),
                ),
              OutlinedButton(
                key: const ValueKey('music-offer-dismiss'),
                onPressed: controller.dismissOffer,
                child: Text(l10n.dmMusicNotNow),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Escrituras

  Future<void> _create(BuildContext context) async {
    final scene = await showMusicSceneDialog(context);
    if (scene == null) return;
    await updateScenes((current) => [...current, scene]);
  }

  Future<void> _edit(BuildContext context, MusicScene scene) async {
    final edited = await showMusicSceneDialog(context, current: scene);
    if (edited == null) return;
    await updateScenes(
      (current) => [for (final s in current) s.id == edited.id ? edited : s],
    );
  }

  Future<void> _moveUp(String id) => updateScenes((current) {
    final scenes = [...current];
    final index = scenes.indexWhere((s) => s.id == id);
    if (index > 0) scenes.insert(index - 1, scenes.removeAt(index));
    return scenes;
  });

  /// Sin confirmación: una escena se rehace en segundos, y «Deshacer» la
  /// devuelve a su lugar.
  Future<void> _delete(
    BuildContext context,
    int index,
    MusicScene removed,
  ) async {
    final l10n = context.l10n;
    await updateScenes(
      (current) => [
        for (final s in current)
          if (s.id != removed.id) s,
      ],
    );
    if (!context.mounted) return;
    showAppMessage(
      context,
      l10n.dmMusicDeleted(removed.name),
      onUndo: () => updateScenes(
        (current) => current.any((s) => s.id == removed.id)
            ? current
            : ([...current]..insert(math.min(index, current.length), removed)),
      ),
    );
  }
}

enum _SceneAction { edit, offer, up, open, delete }
