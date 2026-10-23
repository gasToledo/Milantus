import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n_context.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';

/// El nombre del sitio, igual en los dos idiomas. Va aparte de los textos
/// porque los mensajes lo reciben como parámetro.
const musicSiteName = 'YouTube'; // l10n-ignore: nombre de marca

/// «Video de YouTube», «Lista de YouTube»: lo que el DM pegó, en palabras.
String musicKindLabel(AppLocalizations l10n, MusicSource source) =>
    switch (source.kind) {
      MusicKind.playlist => l10n.dmMusicKindYoutubePlaylist,
      MusicKind.video => l10n.dmMusicKindYoutubeVideo,
    };

/// Crea una escena nueva o edita [current]. Devuelve `null` si se cancela.
Future<MusicScene?> showMusicSceneDialog(
  BuildContext context, {
  MusicScene? current,
}) => showDialog<MusicScene>(
  context: context,
  builder: (_) => _MusicSceneDialog(current: current),
);

class _MusicSceneDialog extends StatefulWidget {
  final MusicScene? current;

  const _MusicSceneDialog({this.current});

  @override
  State<_MusicSceneDialog> createState() => _MusicSceneDialogState();
}

class _MusicSceneDialogState extends State<_MusicSceneDialog> {
  late final _name = TextEditingController(text: widget.current?.name);
  late final _url = TextEditingController(text: widget.current?.url);
  late bool _offerOnCombat = widget.current?.offerOnCombat ?? false;

  /// Como en el editor de campaña: los errores aparecen recién al intentar
  /// guardar, y se apagan solos al corregir.
  String? _nameError;
  String? _urlError;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final url = _url.text.trim();
    // Un enlace que no se reconoce no se guarda: fallaría en la mesa, que es
    // el peor momento para enterarse.
    final source = MusicSource.parse(url);
    setState(() {
      _nameError = name.isEmpty ? l10n.dmMusicSceneNameRequired : null;
      _urlError = source == null ? l10n.dmMusicUnsupportedUrl : null;
    });
    if (_nameError != null || _urlError != null) return;
    final current = widget.current;
    Navigator.of(context).pop(
      current == null
          ? MusicScene(
              id: 'scene-${DateTime.now().microsecondsSinceEpoch}',
              name: name,
              url: url,
              offerOnCombat: _offerOnCombat,
            )
          : current.copyWith(
              name: name,
              url: url,
              offerOnCombat: _offerOnCombat,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = MusicSource.parse(_url.text);
    return AppDialog(
      title: widget.current == null
          ? l10n.dmMusicNewScene
          : l10n.dmMusicEditScene,
      width: 480,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('music-scene-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.dmMusicSceneName,
              border: const OutlineInputBorder(),
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('music-scene-url'),
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.dmMusicSceneUrl,
              border: const OutlineInputBorder(),
              errorText: _urlError,
              // Lo que se reconoció, antes de guardar: confirma que el enlace
              // es el que el DM cree que pegó.
              helperText: source == null ? null : musicKindLabel(l10n, source),
              helperStyle: TextStyle(color: context.palette.verdant),
            ),
            // Se redibuja en cada tecla para mostrar el tipo detectado.
            onChanged: (_) => setState(() => _urlError = null),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('music-scene-offer'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dmMusicOfferOnCombat),
            value: _offerOnCombat,
            onChanged: (v) => setState(() => _offerOnCombat = v),
          ),
        ],
      ),
      actions: [
        DialogAction(
          l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(l10n.commonSave, primary: true, onPressed: _save),
      ],
    );
  }
}
