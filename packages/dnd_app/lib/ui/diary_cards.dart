import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/l10n_context.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../web/browser.dart' as browser;
import 'portrait_image.dart';
import 'portrait_viewer.dart';

// Las dos tarjetas del Diario —el trasfondo y las entradas— como widgets
// propios y no como métodos de la ficha, porque las usan dos pantallas: la
// pestaña Diario del personaje y la pantalla del PNJ del Modo DM (que las usa
// para su Trasfondo y sus Notas). Lo que cambia de un lado al otro entra por
// parámetro; el resto —grilla, modales, markdown, importar un .md— es el mismo
// código, para que una mejora del Diario llegue sola a las notas del PNJ.
//
// Nada de acá es una regla: no llega al `ComputedSheet` ni cambia un número.

/// El marco de una tarjeta: ícono, título y acción a la derecha, con el cuerpo
/// abajo. La ficha pasa el suyo (`sheetCard`, que además se pliega); quien no
/// pasa nada recibe [diaryCardShell].
typedef DiaryCardShell =
    Widget Function({
      required IconData icon,
      required String title,
      Widget? trailing,
      required Widget child,
    });

/// Marco por defecto: el mismo encabezado que `sheetCard`, sin plegado. La
/// pantalla del PNJ no pliega sus tarjetas, y un encabezado que parece un botón
/// pero no hace nada sería peor que uno quieto.
Widget diaryCardShell({
  required IconData icon,
  required String title,
  Widget? trailing,
  required Widget child,
}) => Builder(
  builder: (context) {
    final pal = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: pal.hairline)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: pal.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  },
);

/// Techo de alto de la tarjeta de Trasfondo.
///
/// Es el mismo que ya usan los pickers de arma (§8 de la guía de diseño) y no
/// un número nuevo: el problema es idéntico —contenido que puede crecer sin
/// fin dentro de una tarjeta— y conviene que se resuelva con la misma medida.
const double _kBackgroundMaxHeight = 300;

/// El enlace de una entrada, pero **solo si se puede abrir**: `http` o
/// `https`, y con host.
///
/// Lo escribe el jugador a mano en un campo de texto libre, así que un
/// `javascript:` pegado ahí se ejecutaría en el origen de la propia aplicación
/// si se navegara sin mirar. Exigir autoridad (`//host`) descarta además las
/// formas sin host, que no llevan a ninguna parte.
///
/// Lo que no pasa el filtro no se ofrece para abrir: se muestra como texto,
/// que es lo honesto y encima deja copiarlo.
Uri? _openableLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasAuthority) return null;
  return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
}

void _snack(BuildContext context, String msg) =>
    showAppMessage(context, msg, duration: const Duration(seconds: 2));

// ------------------------------------------------------------- Trasfondo

/// La tarjeta del trasfondo: lectura con markdown, editor, importar y exportar
/// un `.md`.
///
/// El **trasfondo está siempre** —aunque esté vacío, donde dice «Origen
/// desconocido»— porque todo personaje viene de algún lado.
///
/// El estado de edición y el controlador del campo son de la tarjeta, no de
/// quien la usa: el texto viaja por [onChanged].
class DiaryBackgroundCard extends StatefulWidget {
  /// El trasfondo guardado. Si cambia desde afuera (una relectura, un
  /// «deshacer») y no se está escribiendo, el campo lo adopta.
  final String value;

  /// Se llama con **cada tecla** y con el contenido de un `.md` importado.
  /// Quien guarde en red tiene que espaciar los guardados: acá no se hace.
  final ValueChanged<String> onChanged;

  /// De quién es el trasfondo, para «Todavía nadie escribió de dónde viene X»
  /// y para el nombre del archivo que se baja.
  final String ownerName;

  final DiaryCardShell shell;

  const DiaryBackgroundCard({
    super.key,
    required this.value,
    required this.onChanged,
    required this.ownerName,
    this.shell = diaryCardShell,
  });

  @override
  State<DiaryBackgroundCard> createState() => _DiaryBackgroundCardState();
}

class _DiaryBackgroundCardState extends State<DiaryBackgroundCard> {
  // Controlador propio: sobrevive a las reconstrucciones y evita el footgun de
  // TextFormField(initialValue:), que ignora cambios posteriores.
  late final _ctrl = TextEditingController(text: widget.value);

  /// Arranca en lectura: el Diario se abre para leerlo, y el lápiz es el que
  /// pide escribir.
  bool _editing = false;

  @override
  void didUpdateWidget(DiaryBackgroundCard old) {
    super.didUpdateWidget(old);
    if (!_editing && widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final vacio = _ctrl.text.trim().isEmpty;
    return widget.shell(
      icon: Icons.auto_stories_outlined,
      title: context.l10n.identityBackground,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.l10n.diaryImportMd,
            onPressed: _import,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            color: pal.textMuted,
          ),
          IconButton(
            tooltip: context.l10n.diaryExportMd,
            // Sin trasfondo no hay archivo que bajar, y un botón que descarga
            // un archivo vacío es peor que uno apagado.
            onPressed: vacio ? null : _export,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            color: pal.textMuted,
          ),
          IconButton(
            tooltip: _editing
                ? context.l10n.diaryFinishEditing
                : context.l10n.diaryEditBackground,
            onPressed: () => setState(() => _editing = !_editing),
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined, size: 18),
            color: pal.gold,
          ),
        ],
      ),
      // Un trasfondo largo estiraba la tarjeta hasta empujar las entradas
      // fuera de la pantalla: lo que sobra scrollea acá adentro.
      //
      // `ConstrainedBox` y no un alto fijo: con dos renglones escritos, una
      // caja de 300 px dejaría un hueco vacío del mismo tamaño. Crece con el
      // texto hasta el techo y recién ahí scrollea.
      //
      // El techo vale igual en lectura y en edición. Si solo lo llevara la
      // lectura, tocar el lápiz haría saltar la tarjeta de 300 px a lo que
      // midiera el texto entero.
      //
      // Un scroll adentro del `ListView` de la ficha es legal **porque el alto
      // está acotado**; el que revienta es el que se queda sin alto (por eso
      // la grilla de entradas se arma con filas y no con un `GridView`).
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _kBackgroundMaxHeight),
        child: SingleChildScrollView(
          key: const ValueKey('trasfondo-scroll'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: _editing
                ? _editor()
                : vacio
                ? _empty()
                : MarkdownText(_ctrl.text),
          ),
        ),
      ),
    );
  }

  Widget _editor() {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          minLines: 10,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: context.l10n.diaryBackgroundHint,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          // Se escribe sobre el mismo documento y se autoguarda a cada tecla,
          // igual que hacían las notas: producir un `Character` nuevo por cada
          // tecla recompilaría la ficha entera mientras alguien escribe.
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.diaryMarkdownHint,
          style: TextStyle(fontSize: 12, color: pal.textMuted),
        ),
      ],
    );
  }

  /// El trasfondo vacío **no esconde la tarjeta**: dice que no se sabe de dónde
  /// viene, que es una afirmación sobre el personaje y no sobre la aplicación.
  Widget _empty() {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diaryUnknownOrigin,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: pal.textMuted,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          context.l10n.diaryUnknownOriginBody(widget.ownerName),
          style: TextStyle(fontSize: 13, height: 1.5, color: pal.textMuted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(context.l10n.diaryWriteBackground),
            ),
            OutlinedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: Text(context.l10n.diaryImportMdShort),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _import() async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md'],
        withData: true,
        dialogTitle: context.l10n.diaryPickMd,
      );
    } catch (e) {
      if (mounted) {
        _snack(context, failureMessage(context.l10n.diaryOpenError, e));
      }
      return;
    }
    final bytes = picked?.files.singleOrNull?.bytes;
    if (bytes == null || !mounted) return; // el usuario canceló

    // Reemplazar un trasfondo ya escrito es destructivo y no se puede deshacer,
    // así que se pregunta. Con la tarjeta vacía no hay nada que perder.
    if (_ctrl.text.trim().isNotEmpty) {
      final pal = context.palette;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AppDialog(
          icon: Icons.warning_amber_rounded,
          iconColor: pal.crimson,
          title: context.l10n.diaryReplaceTitle,
          content: Text(context.l10n.diaryReplaceBody),
          actions: [
            DialogAction(
              context.l10n.commonCancel,
              keyHint: 'Esc',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            DialogAction(
              context.l10n.diaryReplace,
              primary: true,
              color: pal.crimson,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final String texto;
    try {
      texto = utf8.decode(bytes);
    } catch (_) {
      // Un .md no es cualquier cosa renombrada: si no es UTF-8, meterlo en la
      // ficha dejaría el trasfondo ilegible y guardado.
      _snack(context, context.l10n.diaryNotUtf8);
      return;
    }
    // Adopta el texto, lo pone en el campo y vuelve a lectura para que se vea
    // ya renderizado.
    setState(() {
      _ctrl.text = texto;
      _editing = false;
    });
    widget.onChanged(texto);
    _snack(context, context.l10n.diaryImported);
  }

  void _export() {
    browser.downloadBytes(
      utf8.encode(_ctrl.text),
      fileName:
          '${_fileSlug(widget.ownerName)}-${context.l10n.diaryFileSuffix}.md',
      mimeType: 'text/markdown',
    );
  }

  /// Nombre de archivo sin acentos raros ni separadores: lo que se baja tiene
  /// que poder guardarse en cualquier sistema de archivos.
  String _fileSlug(String name) {
    final limpio = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final recortado = limpio.replaceAll(RegExp(r'^-+|-+$'), '');
    return recortado.isEmpty ? context.l10n.diaryFileFallback : recortado;
  }
}

// -------------------------------------------------------------- Entradas

/// Resultado del editor: la entrada guardada, o el pedido de borrarla.
typedef _DiaryEditResult = ({DiaryEntry? entrada, bool borrar});

/// La tarjeta de entradas: una grilla de tarjetas con arte, historias cortas o
/// enlaces, que se acomodan arrastrando, sin orden impuesto por la fecha.
class DiaryEntriesCard extends StatefulWidget {
  final List<DiaryEntry> entries;

  /// Recibe la lista entera nueva (alta, edición, borrado, reorden o el
  /// «deshacer» de un borrado).
  final ValueChanged<List<DiaryEntry>> onChanged;

  /// Texto del estado vacío. Lo pone quien usa la tarjeta: el del Diario de la
  /// ficha habla de «este personaje», y en las notas de un PNJ sonaba ajeno.
  final String emptyMessage;

  final String title;

  /// Sube los bytes de una imagen al almacén y devuelve su clave. Lo pone quien
  /// usa la tarjeta porque la clave tiene que quedar bajo el id del dueño
  /// (personaje o PNJ): así la cascada de borrar al dueño se la lleva.
  final Future<String> Function(Uint8List bytes) uploadImage;

  /// Borra del almacén la imagen de una entrada que se eliminó.
  final Future<void> Function(String key) deleteImage;

  final DiaryCardShell shell;

  const DiaryEntriesCard({
    super.key,
    required this.entries,
    required this.onChanged,
    required this.emptyMessage,
    required this.title,
    required this.uploadImage,
    required this.deleteImage,
    this.shell = diaryCardShell,
  });

  @override
  State<DiaryEntriesCard> createState() => _DiaryEntriesCardState();
}

class _DiaryEntriesCardState extends State<DiaryEntriesCard> {
  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final entradas = widget.entries;
    return widget.shell(
      icon: Icons.grid_view_outlined,
      title: widget.title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entradas.isEmpty ? '—' : '${entradas.length}',
            style: TextStyle(
              fontSize: 12,
              color: pal.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            tooltip: context.l10n.diaryAddEntryTooltip,
            onPressed: () => _editEntry(null),
            icon: const Icon(Icons.add, size: 19),
            color: pal.gold,
          ),
        ],
      ),
      child: entradas.isEmpty
          ? AppEmptyState(
              icon: Icons.photo_library_outlined,
              message: widget.emptyMessage,
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _editEntry(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.diaryAddEntry),
                ),
              ],
            )
          : Padding(padding: const EdgeInsets.all(16), child: _grid(entradas)),
    );
  }

  /// La grilla, armada a mano con filas y no con un `GridView`: esto vive
  /// adentro de un `ListView`, y un scroll del mismo eje adentro de otro se
  /// queda sin alto y revienta al dibujar.
  Widget _grid(List<DiaryEntry> entradas) {
    return LayoutBuilder(
      builder: (context, box) {
        final columnas = box.maxWidth >= 760
            ? 3
            : box.maxWidth >= 520
            ? 2
            : 1;
        final filas = <Widget>[];
        for (var i = 0; i < entradas.length; i += columnas) {
          final fila = entradas.skip(i).take(columnas).toList();
          filas.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columnas; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  Expanded(
                    child: c < fila.length
                        // Alto fijo para que las tarjetas de una fila midan lo
                        // mismo sin pedir `IntrinsicHeight`, que mide dos veces
                        // cada hijo.
                        ? SizedBox(height: 236, child: _slot(fila[c]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              filas[i],
            ],
          ],
        );
      },
    );
  }

  /// Una tarjeta arrastrable. Mismo trato que el roster del dashboard: el
  /// arrastre arranca con **pulsación larga** —la tarjeta entera ya es un
  /// botón, y en pantalla táctil desplazar la grilla no puede terminar
  /// reordenando el diario—, el hueco queda al 30 % y el destino se marca con
  /// filete oro de 2 px.
  Widget _slot(DiaryEntry entrada) {
    return _DiaryDragSlot(
      id: entrada.entryId,
      onDropped: (fromId) => _move(fromId, entrada.entryId),
      child: _card(entrada),
    );
  }

  Widget _card(DiaryEntry e) {
    final pal = context.palette;
    final icono = _entryIcon(e.kind);
    return Material(
      color: pal.plaque,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(e),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, size: 14, color: pal.gold),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      e.title.isEmpty ? context.l10n.diaryUntitled : e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Expanded(child: _preview(e)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dates(e),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: pal.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: pal.textMuted.withValues(alpha: 0.75),
                    semanticLabel: context.l10n.diaryDragHint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(DiaryEntry e) {
    final pal = context.palette;
    switch (e.kind) {
      case DiaryEntryKind.image:
        final key = e.imageKey;
        if (key == null) {
          return Text(
            context.l10n.diaryNoImage,
            style: TextStyle(fontSize: 12.5, color: pal.textMuted),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.expand(
            child: Image.network(
              PortraitImage.urlFor(key, width: 512),
              fit: BoxFit.cover,
              // Una imagen borrada del almacén no puede romper la pestaña.
              errorBuilder: (_, _, _) => ColoredBox(
                color: pal.hairline.withValues(alpha: 0.25),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 22,
                    color: pal.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      case DiaryEntryKind.link:
        // El oro dice «esto es un enlace». Uno que no se va a poder abrir se
        // pinta como el resto del texto: si no, la tarjeta promete algo que el
        // modal después no cumple.
        return Text(
          e.body,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: _openableLink(e.body) == null ? pal.textMuted : pal.gold,
          ),
        );
      case DiaryEntryKind.text:
        return Text(
          e.body,
          maxLines: 7,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: pal.textMuted),
        );
    }
  }

  /// «12/3», o «12/3 · editada 2/4» cuando se tocó después. Sin fecha —la
  /// entrada que vino de las notas viejas— no se inventa ninguna.
  String _dates(DiaryEntry e) {
    final creada = e.createdAt;
    if (creada == null) return '';
    final tocada = e.updatedAt;
    final base = _shortDate(creada);
    if (tocada == null || !tocada.isAfter(creada)) return base;
    return context.l10n.diaryEditedOn(base, _shortDate(tocada));
  }

  // Día y mes en el orden del idioma: «28/9» en español, «9/28» en inglés.
  // Armado a mano salía «28/09» también en inglés, donde se lee al revés.
  String _shortDate(DateTime d) =>
      DateFormat.Md(Localizations.localeOf(context).toString()).format(d);

  void _move(String fromId, String toId) {
    if (fromId == toId) return;
    final lista = [...widget.entries];
    final desde = lista.indexWhere((e) => e.entryId == fromId);
    final hasta = lista.indexWhere((e) => e.entryId == toId);
    if (desde < 0 || hasta < 0) return;
    lista.insert(hasta, lista.removeAt(desde));
    widget.onChanged(lista);
  }

  // ----------------------------------------------------------- Los modales

  /// Modo lectura. Editar sale de acá y no de la grilla: la tarjeta es chica y
  /// un lápiz ahí competiría con el toque que abre la entrada.
  Future<void> _open(DiaryEntry e) async {
    final pal = context.palette;
    final icono = _entryIcon(e.kind);
    final editar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icono,
        title: e.title.isEmpty ? context.l10n.diaryUntitled : e.title,
        // 560 y no 480: el cuerpo puede ser una imagen, que con la medida de
        // lectura de un párrafo queda innecesariamente chica.
        width: 560,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_dates(e) case final fechas when fechas.isNotEmpty) ...[
              Text(
                fechas,
                style: TextStyle(
                  fontSize: 12,
                  color: pal.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _body(e),
          ],
        ),
        actions: [
          DialogAction(
            context.l10n.commonClose,
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            context.l10n.commonEdit,
            primary: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (editar == true && mounted) await _editEntry(e);
  }

  Widget _body(DiaryEntry e) {
    final pal = context.palette;
    switch (e.kind) {
      case DiaryEntryKind.image:
        final key = e.imageKey;
        if (key == null) return Text(context.l10n.diaryEntryNoImage);
        // Reusa el visor del retrato: misma clave, mismo almacén, y ya trae
        // zoom, arrastre y cierre con Escape. Se abre **encima** del diálogo,
        // así que cerrarlo devuelve a la entrada en vez de a la grilla.
        return Semantics(
          button: true,
          label: context.l10n.diarySeeFullImage,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const ValueKey('entrada-imagen'),
              onTap: () => showPortraitViewer(context, key),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  PortraitImage.urlFor(key),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(context.l10n.diaryImageGone),
                ),
              ),
            ),
          ),
        );
      case DiaryEntryKind.link:
        final link = _openableLink(e.body);
        if (link == null) {
          // No se finge que es un enlace lo que no se va a poder abrir: queda
          // como texto, y seleccionable para poder copiarlo a mano.
          return readingWidth(
            SelectableText(
              e.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: pal.textMuted,
              ),
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => browser.openInNewTab(link.toString()),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      e.body,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: pal.gold,
                        decoration: TextDecoration.underline,
                        decorationColor: pal.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new, size: 15, color: pal.gold),
                ],
              ),
            ),
          ),
        );
      // A medida de lectura: en escritorio la entrada ocupaba 1100 px por
      // renglón, el doble de lo que se lee cómodo.
      case DiaryEntryKind.text:
        return readingWidth(
          SelectableText(
            e.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
    }
  }

  /// Alta y edición. [existente] en null es una entrada nueva.
  Future<void> _editEntry(DiaryEntry? existente) async {
    final resultado = await showDialog<_DiaryEditResult>(
      context: context,
      builder: (ctx) =>
          _DiaryEntryDialog(entry: existente, uploadImage: widget.uploadImage),
    );
    if (resultado == null || !mounted) return;

    if (resultado.borrar && existente != null) {
      await _delete(existente);
      return;
    }
    final guardada = resultado.entrada;
    if (guardada == null) return;

    final lista = [...widget.entries];
    final i = lista.indexWhere((e) => e.entryId == guardada.entryId);
    if (i >= 0) {
      lista[i] = guardada;
    } else {
      lista.add(guardada);
    }
    widget.onChanged(lista);
  }

  Future<void> _delete(DiaryEntry e) async {
    final pal = context.palette;
    final tieneImagen = e.kind == DiaryEntryKind.image && e.imageKey != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: pal.crimson,
        title: context.l10n.diaryDeleteTitle,
        content: Text(
          // Con imagen no hay vuelta atrás: el blob se borra del servidor y no se
          // puede reponer. Sin imagen sí, así que decirlo igual sería asustar de
          // más por algo que el cartel de después deshace.
          tieneImagen
              ? context.l10n.diaryDeleteBodyImage(
                  e.title.isEmpty ? context.l10n.diaryUntitled : e.title,
                )
              : context.l10n.diaryDeleteBody(
                  e.title.isEmpty ? context.l10n.diaryUntitled : e.title,
                ),
        ),
        actions: [
          DialogAction(
            context.l10n.commonCancel,
            keyHint: 'Esc',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          DialogAction(
            context.l10n.commonDelete,
            primary: true,
            color: pal.crimson,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final antes = widget.entries;
    widget.onChanged([
      for (final otra in antes)
        if (otra.entryId != e.entryId) otra,
    ]);
    final key = e.imageKey;
    if (key == null) {
      // Solo acá se ofrece deshacer: la entrada vive entera en el documento del
      // dueño, así que volver es poner de nuevo la lista de antes. Con imagen
      // no, porque el blob ya se fue y volvería rota.
      showAppMessage(
        context,
        context.l10n.diaryDeleted(
          e.title.isEmpty ? context.l10n.diaryUntitled : e.title,
        ),
        onUndo: () => widget.onChanged(antes),
      );
      return;
    }
    try {
      await widget.deleteImage(key);
    } catch (_) {
      // La entrada ya se fue del documento, que es lo que se pidió. Un blob que
      // queda es basura barata: la cascada de borrar al dueño se lo lleva.
    }
  }
}

/// Envoltorio que hace arrastrable una tarjeta del diario para reordenarla.
///
/// Copia deliberada del que usa el roster del dashboard (`dashboard_widgets`):
/// soltar sobre otra tarjeta la mueve a esa posición, y eso es todo lo que hace
/// falta acá tampoco. Se escribe de nuevo en vez de compartirse porque aquel
/// mide celdas de una grilla con ancho propio y este vive en una fila elástica.
class _DiaryDragSlot extends StatefulWidget {
  final String id;
  final void Function(String fromId) onDropped;
  final Widget child;

  const _DiaryDragSlot({
    required this.id,
    required this.onDropped,
    required this.child,
  });

  @override
  State<_DiaryDragSlot> createState() => _DiaryDragSlotState();
}

class _DiaryDragSlotState extends State<_DiaryDragSlot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.id,
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onDropped(details.data);
      },
      onMove: (_) {
        if (!_hovering) setState(() => _hovering = true);
      },
      onLeave: (_) => setState(() => _hovering = false),
      builder: (context, candidate, rejected) => LongPressDraggable<String>(
        data: widget.id,
        // La fila reparte el ancho: sin acotar el feedback, la tarjeta
        // arrastrada se dibuja sin restricciones y revienta.
        feedback: SizedBox(
          width: 300,
          height: 236,
          child: Opacity(opacity: 0.85, child: widget.child),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? pal.gold : Colors.transparent,
              width: 2,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// El editor de una entrada, con su propio estado.
///
/// Widget con estado y no un `AppDialog` armado en línea por lo mismo que
/// `showTextPromptDialog`: los controladores tienen que vivir exactamente lo
/// que vive el diálogo.
class _DiaryEntryDialog extends StatefulWidget {
  final DiaryEntry? entry;
  final Future<String> Function(Uint8List bytes) uploadImage;

  const _DiaryEntryDialog({required this.entry, required this.uploadImage});

  @override
  State<_DiaryEntryDialog> createState() => _DiaryEntryDialogState();
}

class _DiaryEntryDialogState extends State<_DiaryEntryDialog> {
  late final _titleCtrl = TextEditingController(
    text: widget.entry?.title ?? '',
  );
  late final _bodyCtrl = TextEditingController(text: widget.entry?.body ?? '');
  late DiaryEntryKind _kind = widget.entry?.kind ?? DiaryEntryKind.text;
  late String? _imageKey = widget.entry?.imageKey;

  bool _subiendo = false;
  String? _error;

  /// Como en los retratos, un GIF se anima en la entrada abierta y queda
  /// quieto en la grilla, que pide la miniatura estática del servidor.
  static const _extensiones = ['png', 'jpg', 'jpeg', 'webp', 'gif'];

  bool get _puedeGuardar =>
      !_subiendo &&
      _titleCtrl.text.trim().isNotEmpty &&
      (_kind != DiaryEntryKind.image || _imageKey != null);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    setState(() {
      _subiendo = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensiones,
        withData: true,
        dialogTitle: context.l10n.diaryPickImage,
      );
      final bytes = picked?.files.singleOrNull?.bytes;
      if (bytes == null) return; // el usuario canceló
      // Reusa el almacén de retratos: ya valida tipo y tamaño, y el borrado del
      // dueño ya se lleva sus imágenes.
      //
      // ponytail: cambiar la imagen de una entrada deja la anterior en el
      // almacén. Se la lleva la cascada al borrar al dueño; si alguna vez
      // molesta el espacio, borrarla acá es una línea.
      final key = await widget.uploadImage(bytes);
      if (mounted) setState(() => _imageKey = key);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = failureMessage(context.l10n.diaryUploadError, e),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  void _guardar() {
    final ahora = DateTime.now();
    final previa = widget.entry;
    final entrada =
        (previa ??
                DiaryEntry(
                  entryId: 'diary-${ahora.microsecondsSinceEpoch}',
                  createdAt: ahora,
                ))
            .copyWith(
              kind: _kind,
              title: _titleCtrl.text.trim(),
              body: _kind == DiaryEntryKind.image ? '' : _bodyCtrl.text.trim(),
              imageKey: _kind == DiaryEntryKind.image ? _imageKey : null,
              // La fecha de modificación solo tiene sentido si hubo una anterior:
              // en una entrada nueva las dos serían la misma y la tarjeta diría
              // «editada» de algo recién escrito.
              updatedAt: previa == null ? null : ahora,
            );
    Navigator.pop(context, (entrada: entrada, borrar: false));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final esNueva = widget.entry == null;
    return AppDialog(
      icon: esNueva ? Icons.add : Icons.edit_outlined,
      title: esNueva ? context.l10n.diaryNewEntry : context.l10n.diaryEditEntry,
      width: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.diaryTitleLabel,
              border: const OutlineInputBorder(),
            ),
            // El botón de guardar depende de que haya título.
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Eyebrow(context.l10n.diaryEntryType),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in DiaryEntryKind.values)
                ChoiceChip(
                  label: Text(switch (kind) {
                    DiaryEntryKind.text => context.l10n.diaryKindText,
                    DiaryEntryKind.image => context.l10n.diaryKindImage,
                    DiaryEntryKind.link => context.l10n.diaryKindLink,
                  }),
                  avatar: Icon(_entryIcon(kind), size: 16),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_kind == DiaryEntryKind.image)
            ..._imagenControles(pal)
          else
            TextField(
              controller: _bodyCtrl,
              minLines: _kind == DiaryEntryKind.link ? 1 : 5,
              maxLines: _kind == DiaryEntryKind.link ? 1 : null,
              keyboardType: _kind == DiaryEntryKind.link
                  ? TextInputType.url
                  : TextInputType.multiline,
              decoration: InputDecoration(
                labelText: _kind == DiaryEntryKind.link
                    ? context.l10n.diaryKindLink
                    : context.l10n.diaryKindText,
                hintText: _kind == DiaryEntryKind.link
                    ? 'https://…'
                    : context.l10n.diaryBodyHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          if (_error case final mensaje?) ...[
            const SizedBox(height: 12),
            Text(mensaje, style: TextStyle(fontSize: 12.5, color: pal.crimson)),
          ],
        ],
      ),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.pop(context),
        ),
        if (!esNueva)
          DialogAction(
            context.l10n.commonDelete,
            color: pal.crimson,
            // El borrado lo confirma la tarjeta: este diálogo solo lo pide.
            onPressed: () =>
                Navigator.pop(context, (entrada: null, borrar: true)),
          ),
        DialogAction(
          context.l10n.commonSave,
          primary: true,
          onPressed: _puedeGuardar ? _guardar : null,
        ),
      ],
    );
  }

  List<Widget> _imagenControles(AppPalette pal) {
    final key = _imageKey;
    return [
      if (key != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            PortraitImage.urlFor(key, width: 512),
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_subiendo)
        AppBusyLabel(context.l10n.diaryUploading)
      else
        OutlinedButton.icon(
          onPressed: _elegirImagen,
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: Text(
            key == null
                ? context.l10n.diaryChooseImage
                : context.l10n.diaryChangeImage,
          ),
        ),
      const SizedBox(height: 10),
      Text(
        context.l10n.diaryImageFormats,
        style: TextStyle(fontSize: 12, color: pal.textMuted),
      ),
    ];
  }
}

/// Markdown del trasfondo y de las notas del cuaderno, con lo que un texto
/// de mesa usa y nada más.
///
/// ponytail: subconjunto a mano en vez de una dependencia. Entiende títulos
/// (`#`, `##`, `###`), viñetas (`-`, `*`), párrafos separados por una línea en
/// blanco, **negrita** e *itálica* dentro de la línea, y `@Nombre` cuando
/// quien lo usa pasa [mentions]. No entiende enlaces,
/// código, citas, tablas ni listas anidadas: el día que haga falta alguna de
/// esas, la salida es `flutter_markdown_plus` y tirar esta clase.
///
/// `flutter_markdown` está discontinuado, así que sumarlo hoy sería estrenar
/// deuda en vez de evitarla.
class MarkdownText extends StatelessWidget {
  final String source;

  /// Nombres que se enlazan cuando van después de una `@`. Los usa el
  /// cuaderno para los PNJ de la campaña; el trasfondo no menciona a nadie.
  final List<String> mentions;

  /// Lo que se dibuja en lugar de cada mención, con el nombre tal como está
  /// en [mentions].
  final Widget Function(String name)? mentionBuilder;

  const MarkdownText(
    this.source, {
    super.key,
    this.mentions = const [],
    this.mentionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final cuerpo = Theme.of(context).colorScheme.onSurfaceVariant;
    // Títulos y negrita van en el color pleno: con el apagado del cuerpo y
    // apenas más tamaño o peso, en el tema oscuro casi no se distinguían.
    final fuerte = Theme.of(context).colorScheme.onSurface;
    final bloques = <Widget>[];

    void separar() {
      if (bloques.isNotEmpty) bloques.add(const SizedBox(height: 10));
    }

    final parrafo = <String>[];
    void cerrarParrafo() {
      if (parrafo.isEmpty) return;
      separar();
      bloques.add(
        Text.rich(
          _inline(parrafo.join(' '), fuerte),
          style: TextStyle(fontSize: 14, height: 1.65, color: cuerpo),
        ),
      );
      parrafo.clear();
    }

    for (final cruda in source.split('\n')) {
      final linea = cruda.trimRight();
      final limpia = linea.trimLeft();

      if (limpia.isEmpty) {
        cerrarParrafo();
        continue;
      }
      if (limpia.startsWith('### ') ||
          limpia.startsWith('## ') ||
          limpia.startsWith('# ')) {
        cerrarParrafo();
        final nivel = limpia.startsWith('### ')
            ? 3
            : limpia.startsWith('## ')
            ? 2
            : 1;
        separar();
        bloques.add(
          Text(
            limpia.substring(nivel + 1).trim(),
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: switch (nivel) {
                1 => 20,
                2 => 17,
                _ => 15,
              },
              fontWeight: nivel == 3 ? FontWeight.w600 : FontWeight.w700,
              color: fuerte,
            ),
          ),
        );
        continue;
      }
      if (limpia.startsWith('- ') || limpia.startsWith('* ')) {
        cerrarParrafo();
        separar();
        bloques.add(
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 9),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: pal.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _inline(limpia.substring(2).trim(), fuerte),
                    style: TextStyle(fontSize: 14, height: 1.55, color: cuerpo),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      parrafo.add(limpia);
    }
    cerrarParrafo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bloques,
    );
  }

  /// `**negrita**` e `*itálica*`. Un asterisco suelto se deja tal cual: en un
  /// trasfondo es más probable que sea puntuación que un énfasis a medio
  /// escribir.
  TextSpan _inline(String texto, Color color) {
    final hijos = <InlineSpan>[];
    final patron = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    var cursor = 0;
    for (final m in patron.allMatches(texto)) {
      if (m.start > cursor) {
        hijos.addAll(_conMenciones(texto.substring(cursor, m.start), null));
      }
      final negrita = m.group(1);
      hijos.addAll(
        _conMenciones(
          negrita ?? m.group(2)!,
          negrita != null
              ? TextStyle(fontWeight: FontWeight.w700, color: color)
              : const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
      cursor = m.end;
    }
    if (cursor < texto.length) {
      hijos.addAll(_conMenciones(texto.substring(cursor), null));
    }
    return TextSpan(children: hijos);
  }

  /// Corta [texto] en cada `@` seguida de uno de [mentions].
  ///
  /// Sin delimitador de cierre: se toma el nombre **más largo** que siga a la
  /// `@`, así «@Mirra la Tabernera» no se queda en «Mirra» si existen las
  /// dos. Una `@` que no coincide con nadie queda como texto.
  ///
  /// Sin distinguir mayúsculas ni tildes, como el buscador: «@Ines» es Inés.
  /// Plegar no cambia el largo, así que el corte se hace sobre el original.
  List<InlineSpan> _conMenciones(String texto, TextStyle? style) {
    final builder = mentionBuilder;
    if (builder == null || mentions.isEmpty || !texto.contains('@')) {
      return [TextSpan(text: texto, style: style)];
    }
    // El nombre guardado con un espacio de más al final no coincidiría nunca
    // con «@Nombre,»: se compara recortado y se le pasa al builder el
    // original, que es por el que lo busca quien lo usa.
    final nombres = [
      for (final n in mentions)
        if (n.trim().isNotEmpty) (original: n, clave: foldForSearch(n.trim())),
    ]..sort((a, b) => b.clave.length - a.clave.length);
    final letra = RegExp(r'[\p{L}\p{N}]', unicode: true);
    final hijos = <InlineSpan>[];
    var suelto = 0;
    var arroba = texto.indexOf('@');
    while (arroba >= 0) {
      final resto = foldForSearch(texto.substring(arroba + 1));
      final nombre = nombres.where((n) {
        if (!resto.startsWith(n.clave)) return false;
        // Que el nombre termine ahí: «@Mirraela» no es Mirra.
        return resto.length == n.clave.length ||
            !letra.hasMatch(resto[n.clave.length]);
      }).firstOrNull;
      if (nombre == null) {
        arroba = texto.indexOf('@', arroba + 1);
        continue;
      }
      if (arroba > suelto) {
        hijos.add(
          TextSpan(text: texto.substring(suelto, arroba), style: style),
        );
      }
      hijos.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: builder(nombre.original),
        ),
      );
      suelto = arroba + 1 + nombre.clave.length;
      arroba = texto.indexOf('@', suelto);
    }
    if (suelto < texto.length) {
      hijos.add(TextSpan(text: texto.substring(suelto), style: style));
    }
    return hijos;
  }
}

/// El ícono de cada tipo de entrada, igual en la tarjeta y en el selector del
/// editor: un tipo nuevo se suma en un solo lugar.
IconData _entryIcon(DiaryEntryKind kind) => switch (kind) {
  DiaryEntryKind.text => Icons.notes,
  DiaryEntryKind.image => Icons.image_outlined,
  DiaryEntryKind.link => Icons.link,
};
