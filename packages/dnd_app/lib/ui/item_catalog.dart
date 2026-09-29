import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../l10n/l10n_context.dart';

/// El catálogo de objetos y el diálogo de Comprar/Vender, compartidos por la
/// ficha (Inventario) y la creación de personaje (paso Equipo).

/// Filtro que muestra todas las familias.
///
/// l10n-ignore: es un identificador de filtro, no texto: el texto visible sale
/// de [itemFilterText].
const itemFilterAll = 'Todos';

/// La familia con la que se agrupa y rotula un objeto. Los mágicos del
/// catálogo traen la categoría `magic`, pero en el homebrew lo mágico lo da la
/// rareza y la categoría es la del formulario: un amuleto con rareza se
/// rotulaba «Equipo» y quedaba entre las mochilas.
String? itemFamily(Item? item) =>
    item == null ? null : (item.isMagic ? 'magic' : item.category);

/// Identificador de la familia. La comparten la fila y el buscador para que el
/// jugador lea lo mismo en los dos lados.
///
/// l10n-ignore: son identificadores (claves de agrupación) que hoy coinciden
/// con el texto en español, no texto para la persona: lo visible sale de
/// [itemKindText] y [itemGroupTitle].
String itemKindLabel(String kind, String? category) => switch (kind) {
  'weapon' => 'Arma',
  'armor' => 'Armadura',
  _ => switch (category) {
    'tool' => 'Herramienta',
    'ammunition' => 'Munición',
    'focus' => 'Canalizador',
    'pack' => 'Paquete',
    'container' => 'Contenedor',
    'magic' => 'Objeto mágico',
    _ => 'Equipo',
  },
};

/// Orden en que se muestran las familias.
///
/// El orden no es alfabético: primero lo que se empuña, después lo que se
/// gasta, y al final lo que solo se lleva encima. Una familia que no esté acá
/// —homebrew con una categoría nueva— va al fondo con su propio nombre, en vez
/// de desaparecer.
///
/// l10n-ignore: identificadores, no texto (ver [itemKindLabel]).
const itemGroupOrder = <String>[
  'Arma',
  'Armadura',
  'Munición',
  'Canalizador',
  'Objeto mágico',
  'Herramienta',
  'Contenedor',
  'Paquete',
  'Equipo',
];

/// El texto visible de una familia, en singular, por su identificador. Una
/// familia desconocida (homebrew) se muestra con su propio nombre.
///
/// l10n-ignore: los patrones son identificadores de familia, no texto.
String itemKindText(AppLocalizations l10n, String kind) => switch (kind) {
  'Arma' => l10n.kindWeapon,
  'Armadura' => l10n.kindArmor,
  'Munición' => l10n.kindAmmunition,
  'Canalizador' => l10n.kindFocus,
  'Objeto mágico' => l10n.kindMagicItem,
  'Herramienta' => l10n.kindTool,
  'Contenedor' => l10n.kindContainer,
  'Paquete' => l10n.kindPack,
  'Equipo' => l10n.kindGear,
  _ => kind,
};

/// El título de un grupo de la mochila, en plural, por el identificador de la
/// familia.
///
/// l10n-ignore: los patrones son identificadores de familia, no texto.
String itemGroupTitle(AppLocalizations l10n, String kind) => switch (kind) {
  'Arma' => l10n.groupWeapons,
  'Armadura' => l10n.groupArmor,
  'Munición' => l10n.kindAmmunition,
  'Canalizador' => l10n.groupFocuses,
  'Objeto mágico' => l10n.groupMagicItems,
  'Herramienta' => l10n.groupTools,
  'Contenedor' => l10n.groupContainers,
  'Paquete' => l10n.groupPacks,
  'Equipo' => l10n.kindGear,
  'No está en el catálogo' => l10n.catalogNotInCatalog,
  _ => kind,
};

/// El texto de una píldora de filtro: «Todos», «Equipados», «Mágicos» o una
/// familia.
///
/// l10n-ignore: los patrones son identificadores de filtro, no texto.
String itemFilterText(AppLocalizations l10n, String filter) => switch (filter) {
  itemFilterAll => l10n.filterAll,
  'Equipados' => l10n.filterEquipped,
  'Mágicos' => l10n.filterMagic,
  _ => itemGroupTitle(l10n, filter),
};

/// Nombre largo de cada denominación. La abreviatura sola («PE») es un rótulo
/// de formulario: en la mesa nadie recuerda cuál es electro y cuál platino.
String coinName(AppLocalizations l10n, String key) => switch (key) {
  'cp' => l10n.coinCopper,
  'sp' => l10n.coinSilver,
  'ep' => l10n.coinElectrum,
  'gp' => l10n.coinGold,
  'pp' => l10n.coinPlatinum,
  _ => key,
};

/// Buscador sobre los tres catálogos que pueden entrar en la mochila.
///
/// Muestra la categoría al lado del nombre porque los ids son distintos pero
/// los nombres no siempre: el SRD traduce *Pole* y *Rod* como "Vara".
///
/// Los tres desplegables de antes (tipo, rareza, sintonización) ocupaban media
/// pantalla para filtrar una lista que casi siempre cabe entera: quedaron
/// reducidos a las mismas familias con que se agrupa la mochila, en píldoras.
/// El peso viaja al lado del precio, que es lo que decide si el objeto entra.
///
/// Lo usan la ficha y la creación. En la ficha cada fila tiene «Agregar»
/// (botín, gratis) y «Comprar» (abre el diálogo de pago). En la creación solo
/// se compra, sin diálogo: cada toque suma uno a la lista del paso, que es
/// reversible hasta terminar el personaje.
class ItemCatalogDialog extends StatefulWidget {
  final ContentRepository repo;

  /// Null usa «Agregar objeto».
  final String? title;

  /// Lo que se puede gastar ahora, en cobre. Función y no valor porque el
  /// diálogo sigue abierto mientras la ficha o el borrador cambian debajo.
  /// Puede ser negativo en la creación, si las compras superan el oro.
  final int Function() purseCp;

  /// Rótulo de la píldora de arriba: «Bolsa» en la ficha, «Quedan» en la
  /// creación.
  final String? purseLabel;

  /// Null quita «Agregar»: en la creación todo se compra.
  final ValueChanged<String>? onAdd;

  /// «Comprar». Devuelve si hay que cerrar el catálogo: la ficha lo cierra
  /// para que el cartel con «Deshacer» quede a mano; la creación no.
  final Future<bool> Function(CatalogRow row) onBuy;

  /// Cuántos de cada objeto hay ya en la lista, para marcarlo en la fila.
  final int Function(String itemId)? countOf;

  /// Texto al pie, antes de agregar nada.
  final String hint;

  /// False esconde los objetos mágicos. En la creación no se compran: el oro
  /// de partida no llega ni al más barato, y una Armadura de placas de
  /// etereidad a 200000 po entre las mochilas solo estorba.
  final bool includeMagic;

  const ItemCatalogDialog({
    super.key,
    required this.repo,
    required this.purseCp,
    required this.onBuy,
    this.title,
    this.purseLabel,
    this.onAdd,
    this.countOf,
    this.hint = '',
    this.includeMagic = true,
  });

  @override
  State<ItemCatalogDialog> createState() => _ItemCatalogDialogState();
}

typedef CatalogRow = ({
  String id,
  String name,
  String family,
  String detail,
  double weight,
  int costCp,
});

class _ItemCatalogDialogState extends State<ItemCatalogDialog> {
  String _query = '';
  String _family = itemFilterAll;
  int _added = 0;

  List<CatalogRow> get _all {
    final repo = widget.repo;
    return [
      for (final w in repo.weaponsSorted)
        (
          id: w.id,
          name: w.name,
          family: itemKindLabel('weapon', null),
          detail: itemKindText(context.l10n, itemKindLabel('weapon', null)),
          weight: w.weight,
          costCp: w.costCp,
        ),
      for (final a in repo.armorSorted)
        (
          id: a.id,
          name: a.name,
          family: itemKindLabel('armor', null),
          detail: a.isShield
              ? context.l10n.kindShield
              : itemKindText(context.l10n, itemKindLabel('armor', null)),
          weight: a.weight,
          costCp: a.costCp,
        ),
      for (final i in repo.itemsSorted)
        if (widget.includeMagic || !i.isMagic)
          (
            id: i.id,
            name: i.name,
            family: itemKindLabel('item', itemFamily(i)),
            detail: [
              itemKindText(context.l10n, itemKindLabel('item', itemFamily(i))),
              if (i.bundleSize > 1) context.l10n.catalogBundleOf(i.bundleSize),
              if (i.requiresAttunement) context.l10n.catalogAttunement,
            ].join(' · '),
            weight: i.weight,
            costCp: i.costCp,
          ),
    ];
  }

  /// Una fila del catálogo con sus dos salidas: «Agregar» es botín o regalo y
  /// no cuesta nada; «Comprar» paga de la bolsa. Lo que no alcanza deshabilita
  /// «Comprar» y dice cuánto falta, en vez de dejar tocar para enterarse.
  ///
  /// Angosta, los botones bajan a una segunda línea: al lado del nombre, del
  /// peso y del precio no quedaba lugar para leer el objeto.
  Widget _catalogRow(
    CatalogRow e, {
    required int purseCp,
    required Color muted,
  }) {
    final pal = context.palette;
    final missing = e.costCp - purseCp;
    final weight = e.weight == 0 ? '—' : '${formatPounds(e.weight)} lb';
    final count = widget.countOf?.call(e.id) ?? 0;
    final onAdd = widget.onAdd;
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '×$count',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: pal.gold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        if (onAdd != null) ...[
          TextButton(
            key: ValueKey('add-${e.id}'),
            onPressed: () {
              onAdd(e.id);
              setState(() => _added++);
            },
            child: Text(context.l10n.commonAdd),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton(
          key: ValueKey('buy-${e.id}'),
          style: OutlinedButton.styleFrom(
            foregroundColor: pal.gold,
            side: BorderSide(color: missing > 0 ? pal.hairline : pal.gold),
          ),
          onPressed: missing > 0
              ? null
              : () async {
                  final bought = await widget.onBuy(e);
                  if (!mounted) return;
                  if (bought) {
                    Navigator.pop(context);
                  } else {
                    setState(() {});
                  }
                },
          child: Text(context.l10n.commonBuy),
        ),
      ],
    );
    final cost = Text(
      context.l10n.cost(e.costCp),
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 12.5,
        color: pal.gold,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 460;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              [
                e.detail,
                // Angosto, sin la columna que lo alinee, la raya de «sin
                // peso» quedaba suelta entre los datos.
                if (narrow && e.weight > 0) weight,
                if (missing > 0)
                  context.l10n.catalogMissing(context.l10n.amount(missing)),
              ].join(' · '),
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ],
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(child: info),
                        SizedBox(width: 66, child: cost),
                      ],
                    ),
                    buttons,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: info),
                    SizedBox(
                      width: 60,
                      child: Text(
                        weight,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ),
                    SizedBox(width: 66, child: cost),
                    const SizedBox(width: 10),
                    buttons,
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final all = _all;
    final needle = _query.trim().toLowerCase();
    final matches = [
      for (final e in all)
        if ((needle.isEmpty || e.name.toLowerCase().contains(needle)) &&
            (_family == itemFilterAll || e.family == _family))
          e,
    ];
    // Solo las familias que existen en el catálogo cargado: con homebrew, una
    // píldora fija dejaría fuera categorías nuevas y ofrecería vacías.
    final families = {for (final e in all) e.family};

    final purseCp = widget.purseCp();

    return AppDialog(
      title: widget.title ?? context.l10n.catalogAddTitle,
      // Lo que hay para gastar, para saber qué se puede comprar sin cerrar.
      titleTrailing: GoldPill(
        purseCp < 0
            ? context.l10n.catalogShortBy(context.l10n.amount(-purseCp))
            : '${widget.purseLabel ?? context.l10n.commonBag} ${context.l10n.amount(purseCp)}',
      ),
      width: 560,
      scrollable: false,
      content: SizedBox(
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: context.l10n.catalogSearchHint,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                final chips = [
                  for (final family in [
                    itemFilterAll,
                    ...itemGroupOrder.where(families.contains),
                    ...families.where((f) => !itemGroupOrder.contains(f)),
                  ])
                    ChoiceChip(
                      label: Text(itemFilterText(context.l10n, family)),
                      selected: _family == family,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _family = family),
                    ),
                ];
                // En un teléfono las píldoras envueltas ocupaban cuatro
                // renglones, la mitad del diálogo, y de la lista quedaban dos
                // filas: ahí van en un solo renglón que se desliza.
                if (box.maxWidth < 460) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (i, chip) in chips.indexed) ...[
                          if (i > 0) const SizedBox(width: 6),
                          chip,
                        ],
                      ],
                    ),
                  );
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                );
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: matches.isEmpty
                  ? Center(child: Text(context.l10n.catalogNoMatches))
                  : ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: pal.hairline),
                      itemBuilder: (_, i) => _catalogRow(
                        matches[i],
                        purseCp: purseCp,
                        muted: muted,
                      ),
                    ),
            ),
            // El contador vive abajo del cuerpo: el pie es una fila de celdas
            // que se tocan y un texto ahí se lee como un botón muerto.
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _added == 0 ? widget.hint : context.l10n.catalogAdded(_added),
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        DialogAction(
          context.l10n.commonClose,
          primary: true,
          keyHint: 'Esc',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// Lo que se acordó en «Comprar» o «Vender»: cuántas unidades (paquetes, en
/// la munición) y a qué precio cada una, en cobre.
typedef Trade = ({int quantity, int unitCp, int totalCp});

/// Comprar y vender comparten el diálogo: cantidad, precio en po · pp · pc y
/// cómo queda la bolsa. La cuenta no vive acá: el pago sale de
/// [CoinOps.plan], el mismo que después aplica `InventoryOps.buy`, así lo que
/// se muestra es lo que pasa.
class TradeDialog extends StatefulWidget {
  final bool buying;
  final String title;
  final String detail;
  final int bundleSize;

  /// El precio de partida por unidad: el de catálogo al comprar, la mitad al
  /// vender. Se puede corregir; el botón de volver lo repone.
  final int catalogCp;

  /// Tope de la cantidad al vender (lo que hay). Null al comprar.
  final int? maxQuantity;
  final Map<String, int> coins;

  const TradeDialog({
    super.key,
    required this.buying,
    required this.title,
    required this.detail,
    required this.bundleSize,
    required this.catalogCp,
    required this.coins,
    this.maxQuantity,
  });

  @override
  State<TradeDialog> createState() => _TradeDialogState();
}

class _TradeDialogState extends State<TradeDialog> {
  int _quantity = 1;

  /// Tres campos y no número + moneda: la mitad de 15 po son 7 po 5 pp, y con
  /// una sola moneda eso solo se escribía «75 pp».
  late final Map<String, TextEditingController> _price = {
    for (final k in const ['gp', 'sp', 'cp']) k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _setPrice(widget.catalogCp);
  }

  @override
  void dispose() {
    for (final c in _price.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setPrice(int cp) {
    final parts = CoinOps.changeFor(cp);
    for (final k in _price.keys) {
      _price[k]!.text = '${parts[k] ?? 0}';
    }
  }

  int get _unitCp {
    var cp = 0;
    for (final e in _price.entries) {
      final n = int.tryParse(e.value.text.trim()) ?? 0;
      if (n > 0) cp += n * coinValueCp[e.key]!;
    }
    return cp;
  }

  String get _unitWord => widget.bundleSize > 1
      ? context.l10n.tradeUnitBundle
      : context.l10n.tradeUnitItem;

  String _units(int n) => widget.bundleSize > 1
      ? context.l10n.tradeBundles(n)
      : context.l10n.tradeUnitsCount(n);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final unit = _unitCp;
    final total = unit * _quantity;
    final plan = widget.buying ? CoinOps.plan(widget.coins, total) : null;
    final after = widget.buying
        ? (plan?.purse ?? widget.coins)
        : CoinOps.receive(widget.coins, total);
    final short = widget.buying && plan == null;
    final max = widget.maxQuantity;
    final afterCoins = context.l10n.coins(after);

    Widget eyebrow(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w500,
          color: pal.textMuted,
        ),
      ),
    );

    return AppDialog(
      title: widget.title,
      width: 480,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.detail, style: TextStyle(fontSize: 12.5, color: muted)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    eyebrow(context.l10n.tradeQuantity),
                    Text(
                      [
                        _units(_quantity),
                        if (widget.bundleSize > 1)
                          context.l10n.tradeTotalUnits(
                            _quantity * widget.bundleSize,
                          ),
                        if (max != null)
                          context.l10n.tradeLeft(max - _quantity),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: context.l10n.tradeOneLess,
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: context.l10n.tradeOneMore,
                onPressed: max == null || _quantity < max
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 18),
          eyebrow(
            widget.buying
                ? context.l10n.tradeBuyPrice(_unitWord)
                : context.l10n.tradeSellPrice(_unitWord),
          ),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [for (final k in _price.keys) _priceField(k)],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.buying
                      ? context.l10n.tradeCatalogPrice(
                          context.l10n.cost(widget.catalogCp),
                        )
                      : context.l10n.tradeSuggested(
                          context.l10n.amount(widget.catalogCp),
                        ),
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ),
              if (unit != widget.catalogCp)
                TextButton(
                  onPressed: () => setState(() => _setPrice(widget.catalogCp)),
                  child: Text(
                    widget.buying
                        ? context.l10n.tradeBackCatalog
                        : context.l10n.tradeBackSuggested,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.plaque,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.buying
                            ? context.l10n.tradeTotalBuy
                            : context.l10n.tradeTotalSell,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w500,
                          color: pal.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      context.l10n.amount(total),
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 24,
                        color: pal.gold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (short)
                  Text(
                    context.l10n.tradeShort(
                      context.l10n.amount(
                        total - CoinOps.totalCp(widget.coins),
                      ),
                    ),
                    style: TextStyle(fontSize: 13, color: pal.crimson),
                  )
                else ...[
                  if (plan != null && plan.spent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        [
                          context.l10n.tradePaidFrom(
                            context.l10n.coins(plan.spent),
                          ),
                          if (plan.change.isNotEmpty)
                            context.l10n.tradeChange(
                              context.l10n.coins(plan.change),
                            ),
                        ].join(' '),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  Text(
                    afterCoins.isEmpty
                        ? context.l10n.tradeBagAfter(
                            context.l10n.amount(CoinOps.totalCp(after)),
                          )
                        : context.l10n.tradeBagAfterCoins(
                            context.l10n.amount(CoinOps.totalCp(after)),
                            afterCoins,
                          ),
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        DialogAction(
          context.l10n.commonCancel,
          keyHint: 'Esc',
          onPressed: () => Navigator.pop(context),
        ),
        DialogAction(
          widget.buying ? context.l10n.commonBuy : context.l10n.commonSell,
          primary: true,
          onPressed: short
              ? null
              : () => Navigator.pop<Trade>(context, (
                  quantity: _quantity,
                  unitCp: unit,
                  totalCp: total,
                )),
        ),
      ],
    );
  }

  /// Un campo por moneda, con su abreviatura y su nombre, como en la bolsa
  /// de la ficha: el precio se lee como plata en la mano.
  Widget _priceField(String key) {
    final pal = context.palette;
    return SizedBox(
      width: 100,
      child: TextField(
        key: ValueKey('price-$key'),
        controller: _price[key],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.end,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: pal.plaque,
          labelText:
              '${coinAbbr(context.l10n, key).toUpperCase()} · ${coinName(context.l10n, key)}',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
