import '../domain/content.dart';

/// Cuentas con el monedero del personaje (`Character.coins`).
///
/// Todo en piezas de cobre, igual que los precios del catálogo: con oro
/// decimal, pagar 5 pc cuarenta veces deja un resto de redondeo.
///
/// Las funciones son puras y devuelven monederos nuevos con la forma que
/// guarda la ficha: solo las denominaciones con alguna moneda.
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
  static Map<String, int>? pay(Map<String, int> coins, int costCp) {
    if (costCp <= 0) return _normalize(coins);
    if (totalCp(coins) < costCp) return null;

    final purse = {for (final k in coinDenominations) k: coins[k] ?? 0};
    var missing = costCp;
    for (final k in spendOrder) {
      final value = coinValueCp[k]!;
      final take =
          [purse[k]!, missing ~/ value].reduce((a, b) => a < b ? a : b);
      purse[k] = purse[k]! - take;
      missing -= take * value;
    }
    if (missing > 0) {
      final broken = coinDenominations
          .where((k) => purse[k]! > 0 && coinValueCp[k]! >= missing)
          .reduce((a, b) => coinValueCp[a]! <= coinValueCp[b]! ? a : b);
      purse[broken] = purse[broken]! - 1;
      for (final e in changeFor(coinValueCp[broken]! - missing).entries) {
        purse[e.key] = purse[e.key]! + e.value;
      }
    }
    return _normalize(purse);
  }

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
