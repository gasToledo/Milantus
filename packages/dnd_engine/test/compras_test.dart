import 'package:dnd_engine/dnd_engine.dart';
import 'package:test/test.dart';

/// Comprar y vender con las monedas de la ficha. Hasta acá el diálogo de
/// agregar objeto mostraba el precio y no descontaba nada.
void main() {
  group('Pagar con cambio mínimo', () {
    test('con la moneda justa no rompe nada', () {
      expect(CoinOps.pay({'gp': 5}, 300), {'gp': 2});
      expect(CoinOps.pay({'gp': 1, 'sp': 10}, 150), {'sp': 5});
    });

    test('rompe una sola moneda y el vuelto vuelve en oro, plata y cobre', () {
      // El ejemplo de la charla: 3 po con solo platino y cobre.
      expect(CoinOps.pay({'pp': 1, 'cp': 3}, 300), {'cp': 3, 'gp': 7});
      expect(CoinOps.pay({'gp': 1}, 5), {'cp': 5, 'sp': 9});
    });

    test('rompe la moneda más chica que alcance, no la más grande', () {
      // Sobran un electro y un platino: se rompe el electro.
      expect(
        CoinOps.pay({'ep': 2, 'pp': 1}, 70),
        {'sp': 3, 'pp': 1},
      );
    });

    test('el electro y el platino se tocan al final', () {
      expect(CoinOps.pay({'gp': 3, 'pp': 1}, 200), {'gp': 1, 'pp': 1});
    });

    test('si no alcanza no paga', () {
      expect(CoinOps.pay({'gp': 2, 'sp': 9}, 300), isNull);
      expect(CoinOps.pay(const {}, 1), isNull);
    });

    test('nunca crea ni pierde valor', () {
      const monederos = [
        {'cp': 7, 'sp': 3, 'ep': 1, 'gp': 2, 'pp': 1},
        {'pp': 2},
        {'ep': 5, 'cp': 1},
        {'sp': 40},
      ];
      for (final m in monederos) {
        final total = CoinOps.totalCp(m);
        for (var precio = 0; precio <= total; precio += 7) {
          final despues = CoinOps.pay(m, precio);
          expect(despues, isNotNull, reason: '$m, $precio');
          expect(CoinOps.totalCp(despues!), total - precio,
              reason: '$m, $precio');
          expect(despues.values.every((n) => n > 0), isTrue,
              reason: 'guarda denominaciones vacías: $despues');
        }
      }
    });

    test('al romper una moneda grande no se gasta de más en monedas chicas',
        () {
      // Sin devolver lo sobrante: 12 po, 8 pp y 30 pc gastados, se rompía el
      // platino y volvían 8 po 1 pp. Con el platino y 4 po 7 pp 30 pc alcanza
      // justo y no hay vuelto.
      final p = CoinOps.plan({'pp': 1, 'gp': 12, 'sp': 8, 'cp': 30}, 1500)!;
      expect(p.change, isEmpty);
      expect(p.purse, {'gp': 8, 'sp': 1});
    });

    test('el desglose dice qué sale y cuál es el vuelto', () {
      final p = CoinOps.plan({'pp': 1, 'cp': 3}, 300)!;
      expect(p.spent, {'pp': 1});
      expect(p.change, {'gp': 7});
      expect(p.purse, CoinOps.pay({'pp': 1, 'cp': 3}, 300));
      expect(CoinOps.plan({'gp': 2}, 300), isNull);
    });

    test('los montos se leen en oro, plata y cobre', () {
      expect(CoinOps.formatAmount(750), '7 po 5 pp');
      expect(CoinOps.formatAmount(0), '0 pc');
      expect(CoinOps.formatCoins({'gp': 3, 'pp': 1, 'cp': 0}), '1 ppt, 3 po');
    });

    test('cobrar suma en oro, plata y cobre', () {
      expect(CoinOps.receive({'gp': 1}, 255), {'cp': 5, 'sp': 5, 'gp': 3});
    });
  });

  group('Comprar y vender', () {
    late ContentRepository repo;
    final hoy = DateTime(2026, 9, 28);

    setUpAll(() async {
      repo = await ContentRepository.loadFromDirectory('lib/assets/srd_2024');
    });

    Character conMonedas(Map<String, int> coins) => Character(
          id: 'c',
          name: 'Prueba',
          raceId: 'human',
          classId: 'fighter',
          backgroundId: 'soldier',
          assignedScores: {for (final a in Ability.values) a: 10},
          hpPerLevel: const [10],
          coins: coins,
        );

    String cuentas(Character c) => c.diary
        .singleWhere((e) => e.entryId == InventoryOps.ledgerEntryId)
        .body;

    test('comprar descuenta el precio de catálogo y anota en Cuentas', () {
      final espada = repo.weapon('longsword')!;
      final antes = conMonedas({'gp': 50});
      final despues = InventoryOps.buy(antes, 'longsword', repo, at: hoy)!;

      expect(CoinOps.totalCp(despues.coins),
          CoinOps.totalCp(antes.coins) - espada.costCp);
      expect(despues.inventory.single.itemId, 'longsword');
      expect(cuentas(despues),
          '28/09/2026 · Compra: 1 × ${espada.name} · ${formatCost(espada.costCp)}');
      expect(despues.diary.single.title, 'Cuentas');
    });

    test('sin fondos no compra', () {
      expect(
        InventoryOps.buy(conMonedas({'cp': 1}), 'longsword', repo, at: hoy),
        isNull,
      );
    });

    test('el precio se puede corregir y la munición se compra por paquete', () {
      final flechas = repo.item('arrows')!;
      expect(flechas.bundleSize, greaterThan(1));
      final despues = InventoryOps.buy(
        conMonedas({'gp': 10}),
        'arrows',
        repo,
        quantity: 3,
        unitPriceCp: 50,
        at: hoy,
      )!;
      expect(CoinOps.totalCp(despues.coins), 1000 - 150);
      expect(despues.inventory.single.quantity, 3);
      expect(cuentas(despues),
          contains('3 × ${flechas.name} (paquete de ${flechas.bundleSize})'));
    });

    test('vender cobra lo acordado y suma otra línea a Cuentas', () {
      final comprado = InventoryOps.buy(
        conMonedas({'gp': 50}),
        'longsword',
        repo,
        quantity: 2,
        at: hoy,
      )!;
      final entrada = comprado.inventory.single;
      final mitad = InventoryOps.suggestedSalePriceCp(entrada, repo);
      expect(mitad, repo.weapon('longsword')!.costCp ~/ 2);

      final vendido = InventoryOps.sell(
        comprado,
        entrada.entryId,
        repo,
        unitPriceCp: mitad,
        at: hoy,
      );
      expect(vendido.inventory.single.quantity, 1);
      expect(CoinOps.totalCp(vendido.coins),
          CoinOps.totalCp(comprado.coins) + mitad);
      final lineas = cuentas(vendido).split('\n');
      expect(lineas, hasLength(2));
      expect(lineas.last, startsWith('28/09/2026 · Venta: 1 × '));
    });

    test('vender más de lo que hay vende lo que hay', () {
      final comprado =
          InventoryOps.buy(conMonedas({'gp': 50}), 'longsword', repo, at: hoy)!;
      final vendido = InventoryOps.sell(
        comprado,
        comprado.inventory.single.entryId,
        repo,
        quantity: 9,
        unitPriceCp: 100,
        at: hoy,
      );
      expect(vendido.inventory, isEmpty);
      expect(CoinOps.totalCp(vendido.coins),
          CoinOps.totalCp(comprado.coins) + 100);
    });
  });
}
