import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/widgets.dart';

import 'music_embed.dart';

/// Fuera del navegador no hay reproductor que embeber: los tests ven el lugar
/// que ocupa y nada más.
Widget musicEmbedView(MusicSource source, MusicEmbedController controller) =>
    const SizedBox.expand();
