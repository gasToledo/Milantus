part of '../dashboard_screen.dart';

extension _DashboardContent on _DashboardScreenState {
  // --------------------------------------------------------------------------
  // Contenido: encabezado + grilla
  // --------------------------------------------------------------------------

  Widget _content(BuildContext context) {
    if (_showSettings) {
      return SettingsView(
        settingsController: _settingsController,
        theme: widget.theme,
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final margin = _rosterMargin(box.maxWidth);
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final all = controller.characters;
            final list = _visible(all);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, all, margin),
                Expanded(
                  child: all.isEmpty
                      // "Todavía no creaste ninguno" y "ninguno coincide con lo
                      // que buscaste" son situaciones distintas y piden acciones
                      // distintas: la primera, empezar; la segunda, corregir la
                      // búsqueda.
                      ? AppEmptyState(
                          icon: Icons.shield_outlined,
                          message: context.l10n.rosterEmpty,
                          actions: [
                            FilledButton.icon(
                              onPressed: _openWizard,
                              icon: const Icon(Icons.add, size: 20),
                              label: Text(context.l10n.rosterCreate),
                            ),
                            OutlinedButton.icon(
                              onPressed: _import,
                              icon: const Icon(Icons.download, size: 20),
                              label: Text(context.l10n.importBackupTitle),
                            ),
                            TextButton.icon(
                              onPressed: _tryExample,
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 20,
                              ),
                              label: Text(context.l10n.rosterTryExample),
                            ),
                          ],
                        )
                      : list.isEmpty
                      ? AppEmptyState(
                          icon: Icons.search_off,
                          message: context.l10n.rosterNoMatch(_query),
                          actions: [
                            OutlinedButton.icon(
                              onPressed: () {
                                _searchCtrl.clear();
                                _updateState(() => _query = '');
                              },
                              icon: const Icon(Icons.close, size: 20),
                              label: Text(context.l10n.rosterClearSearch),
                            ),
                          ],
                        )
                      : _grid(list, margin),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _header(BuildContext context, List<Character> all, double margin) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(margin, 26, margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.rosterTitle,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 28,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rosterSummary(all),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              // El único botón primario del encabezado: importar y el resto
              // viven en el panel lateral o en el estado vacío.
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _openWizard,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(context.l10n.rosterCreate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _toolbar(context),
        ],
      ),
    );
  }

  /// «4 personajes · 1 caído»: el recuento del roster y, solo si hay alguno,
  /// cuántos están sin PG. Sin caídos no se menciona el estado — un «0 caídos»
  /// permanente no informa nada.
  String _rosterSummary(List<Character> all) {
    final fallen = all.where(_isFallen).length;
    final total = context.l10n.rosterCount(all.length);
    if (fallen == 0) return total;
    return '$total · ${context.l10n.rosterFallen(fallen)}';
  }

  /// Búsqueda, orden y estado del guardado en una sola región, como pide §8.3.
  ///
  /// El buscador es lo que crece con el ancho disponible; los controles de al
  /// lado conservan su tamaño. Cuando no queda ancho para las dos cosas, el
  /// buscador pasa a su propia línea en vez de comprimirse hasta perder el
  /// texto de ayuda.
  Widget _toolbar(BuildContext context) {
    final pal = context.palette;
    final search = SizedBox(height: 40, child: _searchField(pal));
    final controls = [
      _sortButton(context),
      Container(width: 1, height: 24, color: pal.hairline),
      SaveStatusIndicator(controller: controller),
      if (_activeOperation != null)
        AppBusyLabel(_activeOperation!, indicatorSize: 16),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: pal.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  search,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: controls,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: search),
                  for (final control in controls) ...[
                    const SizedBox(width: 12),
                    control,
                  ],
                ],
              ),
      ),
    );
  }

  Widget _searchField(AppPalette pal) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => _updateState(() => _query = v),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: pal.plaque,
        // El buscador también filtra por especie desde que `_visible` la mira:
        // decir solo "nombre o clase" escondía media función.
        hintText: context.l10n.rosterSearchHint,
        hintStyle: TextStyle(fontSize: 13, color: pal.textMuted),
        prefixIcon: Icon(Icons.search, size: 19, color: pal.textMuted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.rosterClearSearch,
                icon: Icon(Icons.close, size: 16, color: pal.textMuted),
                onPressed: () {
                  _searchCtrl.clear();
                  _updateState(() => _query = '');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: border(pal.hairline),
        enabledBorder: border(pal.hairline),
        focusedBorder: border(pal.gold),
      ),
    );
  }

  Widget _sortButton(BuildContext context) {
    final pal = context.palette;
    return PopupMenuButton<_SortMode>(
      tooltip: context.l10n.rosterSort,
      initialValue: _sort,
      onSelected: _selectSort,
      itemBuilder: (_) => [
        for (final m in _SortMode.values)
          PopupMenuItem(value: m, child: Text(m.label(context.l10n))),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pal.plaque,
          border: Border.all(color: pal.hairline),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: pal.textMuted),
            const SizedBox(width: 7),
            Text(
              _sort.label(context.l10n),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: pal.textMuted),
          ],
        ),
      ),
    );
  }

  /// Margen lateral de todo el roster (encabezado, buscador y grilla).
  ///
  /// Una sola cuenta para las tres piezas: antes el título iba a 32 y la
  /// grilla a 16 en teléfono, y las tarjetas sobresalían del panel de
  /// búsqueda. Se decide por el ancho que le queda al contenido (con el panel
  /// lateral ya descontado), no por la ventana.
  double _rosterMargin(double width) => width < 560 ? 16.0 : 32.0;

  Widget _grid(List<Character> list, double horizontalPadding) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Misma cuenta de columnas que hacía el delegado de la grilla, ahora
        // explícita: el ancho real de una tarjeta no se sabe sin repetirla, y
        // con el ancho ya resuelto la tarjeta se escala en proporción.
        final available = constraints.maxWidth - horizontalPadding * 2;
        final columns = (available / _kCardMaxExtent).ceil().clamp(1, 99);
        final cardWidth = (available - _kCardSpacing * (columns - 1)) / columns;
        final scale = (cardWidth / _kCardBaseWidth).clamp(1.0, 1.3);
        final rows = (list.length / columns).ceil();

        // Filas con alto intrínseco y no `mainAxisExtent`: un alto fijo se
        // calibraba para un contenido que cambia con el ancho (las pastillas de
        // nivel y trasfondo envuelven, el texto escala), así que sobraban
        // decenas de píxeles bajo la fila CA/VEL/INIC. Cada fila mide a su
        // tarjeta más alta y las demás se estiran a ese alto.
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            32,
          ),
          itemCount: rows,
          itemBuilder: (context, row) {
            return Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : _kCardSpacing),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < columns; col++) ...[
                      if (col > 0) const SizedBox(width: _kCardSpacing),
                      Expanded(
                        // La última fila incompleta deja huecos del mismo
                        // ancho para que las tarjetas no se ensanchen.
                        child: row * columns + col < list.length
                            ? _cardAt(
                                list,
                                row * columns + col,
                                cardWidth,
                                scale,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _cardAt(List<Character> list, int i, double cardWidth, double scale) {
    final c = list[i];
    final card = _CharacterCard(
      character: c,
      sheet: _sheetOf(c),
      repo: repo,
      scale: scale,
      isFavorite: _isFavorite(c),
      onTap: () => _openSheet(c),
      onToggleFavorite: () => _toggleFavorite(c),
      // En los extremos no hay a dónde mover: la opción queda deshabilitada,
      // no escondida, para que la lista de acciones no cambie de forma según
      // dónde esté la tarjeta.
      onMoveBefore: i == 0 ? null : () => _moveBy(c, -1, list),
      onMoveAfter: i == list.length - 1 ? null : () => _moveBy(c, 1, list),
      onRename: () => _renameCharacter(c),
      onExport: () => _exportCharacter(c),
      onRebuild: () => _confirmRebuild(c),
      onDelete: () => _confirmDelete(c),
    );
    return _ReorderableCard(
      id: c.id,
      onDropped: (draggedId) => _reorder(draggedId, c.id, list),
      cardWidth: cardWidth,
      child: card,
    );
  }
}
