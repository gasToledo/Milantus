import '../domain/content.dart';

/// Cuentas con el monedero del personaje (`Character.coins`).
///
/// Todo en piezas de cobre, igual que los precios del catálogo: con oro
/// decimal, pagar 5 pc cuarenta veces deja un resto de redondeo.
///
/// Las funciones son puras y devuelven monederos nuevos con la forma que
/// guarda la ficha: solo las denominaciones con alguna moneda.
/// Un pago desglosado. Ver [CoinOps.plan].
typedef CoinPayment = ({
  Map<String, int> spent,
  Map<String, int> change,
  Map<String, int> purse,
});

class CoinOps {
  CoinOps._();

  /// Orden en que se gastan las monedas: primero las de uso diario y al final
  /// las raras. El electro y el platino casi nadie los quiere cambiar, así que
  /// se tocan solo cuando lo demás no alcanza.
  static const spendOrder = ['gp', 'sp', 'cp', 'ep', 'pp'];

  /// Valor del monedero en cobre.
  static int totalCp(Map<String, int> coins) => coins.entries.fold(
        0,
        (sum, e) => sum + e.value * (coinValueCp[e.key] ?? 0),
      );

  /// Paga [costCp] tocando el monedero lo menos posible, o null si no alcanza.
  ///
  /// Gasta monedas enteras en [spendOrder] sin pasarse del precio. Si todavía
  /// falta, rompe **una sola** moneda (la más chica que cubra lo que falta) y
  /// el vuelto vuelve en oro, plata y cobre ([changeFor]). Esa moneda siempre
  /// existe: si sobró alguna de una denominación, es porque lo que faltaba ya
  /// era menor que su valor, y si no sobró ninguna, el total no alcanzaba.
  static Map<String, int>? pay(Map<String, int> coins, int costCp) =>
      plan(coins, costCp)?.purse;

  /// El pago de [pay] desglosado: qué monedas salen, cuál es el vuelto y cómo
  /// queda el monedero. Existe para que el diálogo de compra muestre «sale 1
  /// ppt, te vuelven 7 po» con la misma cuenta que después se aplica, en vez
  /// de rehacerla del lado de la pantalla.
  static CoinPayment? plan(Map<String, int> coins, int costCp) {
    if (costCp <= 0) {
      return (spent: const {}, change: const {}, purse: _normalize(coins));
    }
    if (totalCp(coins) < costCp) return null;

    final purse = {for (final k in coinDenominations) k: coins[k] ?? 0};
    final spent = <String, int>{};
    var missing = costCp;
    for (final k in spendOrder) {
      final value = coinValueCp[k]!;
      final take =
          [purse[k]!, missing ~/ value].reduce((a, b) => a < b ? a : b);
      purse[k] = purse[k]! - take;
      missing -= take * value;
      if (take > 0) spent[k] = take;
    }
    var change = const <String, int>{};
    if (missing > 0) {
      final broken = coinDenominations
          .where((k) => purse[k]! > 0 && coinValueCp[k]! >= missing)
          .reduce((a, b) => coinValueCp[a]! <= coinValueCp[b]! ? a : b);
      final brokenValue = coinValueCp[broken]!;
      purse[broken] = purse[broken]! - 1;
      spent[broken] = (spent[broken] ?? 0) + 1;
      // Con la moneda grande rota, parte de lo chico que ya se había gastado
      // sobra: se devuelve a la bolsa, de lo más valioso a lo menos, hasta
      // donde alcanza el vuelto. Sin esto, pagar 3 po con 1 ppt y 3 pc
      // gastaba los 3 pc y los devolvía en el vuelto.
      var slack = brokenValue - missing;
      final refundable = spendOrder
          .where((k) => coinValueCp[k]! < brokenValue && spent.containsKey(k))
          .toList()
        ..sort((a, b) => coinValueCp[b]!.compareTo(coinValueCp[a]!));
      for (final k in refundable) {
        final back = [spent[k]!, slack ~/ coinValueCp[k]!]
            .reduce((a, b) => a < b ? a : b);
        spent[k] = spent[k]! - back;
        if (spent[k] == 0) spent.remove(k);
        purse[k] = purse[k]! + back;
        slack -= back * coinValueCp[k]!;
      }
      change = changeFor(slack);
      for (final e in change.entries) {
        purse[e.key] = purse[e.key]! + e.value;
      }
    }
    return (spent: spent, change: change, purse: _normalize(purse));
  }

  /// Un monto en la menor cantidad de monedas de oro, plata y cobre, para
  /// leer: 750 → «7 po 5 pp». Distinto de `formatCost`, que expresa un precio
  /// de tabla en una sola denominación («75 pp»): un total se cuenta en la
  /// mano como se cobra.
  static String formatAmount(int cp) {
    if (cp <= 0) return '0 ${coinLabels['cp']}';
    return [
      for (final e in changeFor(cp).entries) '${e.value} ${coinLabels[e.key]}',
    ].join(' ');
  }

  /// Monedas sueltas de mayor a menor: «1 ppt, 3 po».
  static String formatCoins(Map<String, int> coins) => [
        for (final k in coinDenominations.reversed)
          if ((coins[k] ?? 0) > 0) '${coins[k]} ${coinLabels[k]}',
      ].join(', ');

  /// Suma [amountCp] al monedero, en oro, plata y cobre.
  static Map<String, int> receive(Map<String, int> coins, int amountCp) {
    final purse = {for (final k in coinDenominations) k: coins[k] ?? 0};
    for (final e in changeFor(amountCp).entries) {
      purse[e.key] = purse[e.key]! + e.value;
    }
    return _normalize(purse);
  }

  /// [amountCp] en la menor cantidad de monedas de oro, plata y cobre.
  ///
  /// Sin electro ni platino por lo mismo que `formatCost`: un vendedor da el
  /// vuelto en las monedas en que cotiza, y nadie espera recibir electro.
  static Map<String, int> changeFor(int amountCp) {
    final out = <String, int>{};
    var left = amountCp;
    for (final k in const ['gp', 'sp', 'cp']) {
      final value = coinValueCp[k]!;
      if (left >= value) {
        out[k] = left ~/ value;
        left %= value;
      }
    }
    return out;
  }

  static Map<String, int> _normalize(Map<String, int> coins) => {
        for (final k in coinDenominations)
          if ((coins[k] ?? 0) > 0) k: coins[k]!,
      };
}
